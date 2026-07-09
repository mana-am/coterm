import type { Principal } from "./types";

/// Access/refresh token claims minted by the upstream `mosaicv1` flow. We only
/// read a subset; unknown fields are ignored.
export interface NativeSessionClaims {
  kind?: "access" | "refresh";
  userId?: unknown;
  displayName?: unknown;
  imageURL?: unknown;
  selectedTeamId?: unknown;
  teamIds?: unknown;
  exp?: unknown;
}

export function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? request.headers.get("Authorization");
  if (!header) return null;
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

/// Session-code normalization mirrored from the relay's protocol.ts so grant
/// room-binding checks use identical canonicalization (uppercase, 4/5/8 alnum).
export function normalizeSessionCode(value: string): string | null {
  const compact = value.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (/^[A-Z0-9]{4}$/.test(compact)) return compact;
  if (/^[A-Z0-9]{5}$/.test(compact)) return compact;
  if (/^[A-Z0-9]{8}$/.test(compact)) return compact;
  return null;
}

/// Map verified/decoded `mosaicv1` claims to a Principal. Returns null when the
/// claims carry no usable userId.
export function principalFromClaims(claims: NativeSessionClaims): Principal | null {
  if (typeof claims.userId !== "string" || claims.userId.trim() === "") return null;
  const teamIds = Array.isArray(claims.teamIds)
    ? claims.teamIds.filter((id): id is string => typeof id === "string" && id.trim() !== "")
    : [];
  return {
    userId: claims.userId,
    displayName: typeof claims.displayName === "string" ? claims.displayName : null,
    imageURL: typeof claims.imageURL === "string" ? claims.imageURL : null,
    orgIds: teamIds,
    selectedOrgId: typeof claims.selectedTeamId === "string" ? claims.selectedTeamId : null,
  };
}

/// Read a token's `exp` (epoch seconds) → epoch ms, or null when absent.
export function claimsExpiryMs(claims: NativeSessionClaims): number | null {
  return typeof claims.exp === "number" && Number.isFinite(claims.exp) ? claims.exp * 1000 : null;
}
