import {
  bearerToken,
  type NativeSessionClaims,
  principalFromClaims,
} from "./common";
import { base64urlDecodeToBytes, base64urlEncodeBytes, decodeCotermPayload } from "./hmac";
import type {
  CollabAuthProvider,
  DirectoryMember,
  Entitlements,
  GrantClaims,
  Principal,
  RelayConnectDecision,
  SessionDescriptorClaims,
} from "./types";

const DEFAULT_ENTITLEMENTS: Entitlements = {
  plan: "hobby",
  directorySharing: false,
  codesEnabled: true,
};

// Unsigned descriptor/grant prefix (parallel to `cotermv1` but with no
// signature). This keeps local noauth mode behind the control-plane grant path,
// but it is not a security boundary. Production self-host deployments should
// use hmac.
const UNSIGNED_PREFIX = "cotermv0";

export interface NoAuthProviderOptions {
  entitlements?: Entitlements;
}

/// Open provider: identity is best-effort — decoded from the client's `cotermv1`
/// bearer token (without verifying its signature) or from a `?userId=` /
/// `x-coterm-user-id` fallback. Relay connects still require a control-plane
/// grant; use hmac for a real security boundary.
export class NoAuthProvider implements CollabAuthProvider {
  private readonly entitlements: Entitlements;

  constructor(options: NoAuthProviderOptions = {}) {
    this.entitlements = options.entitlements ?? DEFAULT_ENTITLEMENTS;
  }

  async authenticateRequest(request: Request): Promise<Principal | null> {
    const token = bearerToken(request);
    if (token) {
      const claims = decodeCotermPayload<NativeSessionClaims>(token);
      const principal = claims ? principalFromClaims(claims) : null;
      if (principal) return principal;
    }
    const url = new URL(request.url);
    const userId =
      url.searchParams.get("userId") ??
      url.searchParams.get("userID") ??
      request.headers.get("x-coterm-user-id") ??
      "anon";
    const orgId =
      url.searchParams.get("orgId") ??
      url.searchParams.get("teamId") ??
      request.headers.get("x-coterm-team-id");
    return {
      userId,
      displayName: null,
      imageURL: null,
      orgIds: orgId ? [orgId] : [],
      selectedOrgId: orgId ?? null,
    };
  }

  sessionExpiryMs(): number | null {
    return null;
  }

  async resolveEntitlements(): Promise<Entitlements> {
    return { ...this.entitlements };
  }

  async resolveDirectory(): Promise<DirectoryMember[]> {
    return [];
  }

  async mintSessionDescriptor(claims: SessionDescriptorClaims): Promise<string> {
    const payload = base64urlEncodeBytes(new TextEncoder().encode(JSON.stringify(claims)));
    return `${UNSIGNED_PREFIX}.${payload}.`;
  }

  async verifySessionDescriptor(token: string): Promise<SessionDescriptorClaims | null> {
    const parts = token.split(".");
    if (parts.length < 2 || (parts[0] !== UNSIGNED_PREFIX && parts[0] !== "cotermv1")) return null;
    try {
      const json = new TextDecoder().decode(base64urlDecodeToBytes(parts[1]));
      return JSON.parse(json) as SessionDescriptorClaims;
    } catch {
      // Fall back to decoding a real cotermv1 payload if one was supplied.
      return decodeCotermPayload<SessionDescriptorClaims>(token);
    }
  }

  async mintGrant(claims: GrantClaims): Promise<string> {
    const payload = base64urlEncodeBytes(
      new TextEncoder().encode(JSON.stringify({ ...claims, t: "grant" })),
    );
    return `${UNSIGNED_PREFIX}.${payload}.`;
  }

  async verifyGrant(token: string): Promise<GrantClaims | null> {
    const parts = token.split(".");
    if (parts.length < 2 || parts[0] !== UNSIGNED_PREFIX) return null;
    try {
      const json = new TextDecoder().decode(base64urlDecodeToBytes(parts[1]));
      const claims = JSON.parse(json) as GrantClaims & { t?: string };
      return claims.t === "grant" ? claims : null;
    } catch {
      return null;
    }
  }

  async authorizeRelayConnect(input: { room: string; grant: string | null }): Promise<RelayConnectDecision> {
    if (!input.grant) return { ok: false, reason: "missing_grant" };
    const claims = await this.verifyGrant(input.grant);
    if (claims === null) return { ok: false, reason: "invalid_grant" };
    if (claims.exp <= Math.floor(Date.now() / 1000)) return { ok: false, reason: "grant_expired" };
    if (claims.room !== input.room) return { ok: false, reason: "room_mismatch" };
    return { ok: true, claims };
  }
}
