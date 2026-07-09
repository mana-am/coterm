// Presence auth boundary, reimplemented over the pluggable CollabAuthProvider.
//
// The upstream presence worker verified Stack Auth access tokens (src/auth.ts).
// This port keeps the SAME pure team-resolution helpers (resolveTeamId,
// requestedTeamIdFromRequest, cacheDeadline, bearerToken) but swaps Stack for the
// shared provider: `verifyRequest` maps a Principal → AuthedUser, and the subscribe
// deadline reads `provider.sessionExpiryMs`. The DO boundary (it trusts the
// worker-injected x-presence-* headers) is unchanged.

import { type AuthProviderEnv, type CollabAuthProvider, providerFromEnv } from "@coterm/collab-auth";

export type AuthEnv = AuthProviderEnv;

export interface AuthedUser {
  id: string;
  selectedTeamId: string | null;
  teamIds: readonly string[];
}

/** Max cache age carried over from the upstream Stack verifier. */
export const AUTH_CACHE_TTL_MS = 60_000;

/** Cache deadline for a verified credential: short TTL, never past its expiry.
 * Pure for tests. */
export function cacheDeadline(
  nowMs: number,
  tokenExpMs: number | null,
  ttlMs: number = AUTH_CACHE_TTL_MS,
): number {
  const ttlDeadline = nowMs + ttlMs;
  if (tokenExpMs === null) return ttlDeadline;
  return Math.min(ttlDeadline, tokenExpMs);
}

export type TeamResolution =
  | { ok: true; teamId: string }
  | { ok: false; error: "team_not_found" };

/** Resolve the team this request operates on: a requested team must be one the
 * caller belongs to (their own user id counts as the solo team); otherwise
 * default to the selected team, then a sole listed team, then the user id. */
export function resolveTeamId(requested: string | null, user: AuthedUser): TeamResolution {
  if (requested) {
    const isMember = user.teamIds.includes(requested) || requested === user.id;
    if (!isMember) return { ok: false, error: "team_not_found" };
    return { ok: true, teamId: requested };
  }
  const soleTeam = user.teamIds.length === 1 ? user.teamIds[0] : null;
  return { ok: true, teamId: user.selectedTeamId ?? soleTeam ?? user.id };
}

/** Requested team from `X-Coterm-Team-Id` (or legacy billing header) or the
 * `teamId`-family query params. */
export function requestedTeamIdFromRequest(request: Request): string | null {
  const fromHeader =
    normalized(request.headers.get("x-coterm-team-id")) ??
    normalized(request.headers.get("x-coterm-billing-team-id"));
  if (fromHeader) return fromHeader;
  let url: URL;
  try {
    url = new URL(request.url);
  } catch {
    return null;
  }
  return (
    normalized(url.searchParams.get("teamId")) ??
    normalized(url.searchParams.get("team_id")) ??
    normalized(url.searchParams.get("billingTeamId")) ??
    normalized(url.searchParams.get("billing_team_id"))
  );
}

function normalized(value: string | null): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

/** The bearer access token from the Authorization header, or null. */
export function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  if (!header?.toLowerCase().startsWith("bearer ")) return null;
  return normalized(header.slice("bearer ".length));
}

// Memoize the provider per (mode, secret) so the HMAC provider's token cache
// survives across requests within an isolate.
let cachedProvider: CollabAuthProvider | null = null;
let cachedProviderKey: string | null = null;

function getProvider(env: AuthEnv): CollabAuthProvider {
  const key = `${env.COLLAB_AUTH_MODE ?? "noauth"}:${env.COLLAB_AUTH_SECRET ?? ""}`;
  if (cachedProvider === null || cachedProviderKey !== key) {
    cachedProvider = providerFromEnv(env);
    cachedProviderKey = key;
  }
  return cachedProvider;
}

/** Verify the caller and map to the presence AuthedUser shape. Returns null when
 * unauthenticated (hmac mode); noauth mode yields a best-effort identity. */
export async function verifyRequest(request: Request, env: AuthEnv): Promise<AuthedUser | null> {
  const principal = await getProvider(env).authenticateRequest(request);
  if (!principal) return null;
  return {
    id: principal.userId,
    selectedTeamId: principal.selectedOrgId ?? null,
    teamIds: [...principal.orgIds],
  };
}

/** Epoch-ms expiry of the request credential, used to bound the subscribe
 * stream. null → caller falls back to MAX_SUBSCRIBE_AGE_MS. */
export function subscribeExpiryMs(request: Request, env: AuthEnv): number | null {
  return getProvider(env).sessionExpiryMs(request);
}
