import {
  bearerToken,
  type NativeSessionClaims,
  principalFromClaims,
} from "./common";
import { base64urlDecodeToBytes, base64urlEncodeBytes, decodeMosaicPayload } from "./hmac";
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

// Unsigned descriptor prefix (parallel to `mosaicv1` but with no signature). Used
// only in noauth mode where the code is the sole gate.
const UNSIGNED_PREFIX = "mosaicv0";

export interface NoAuthProviderOptions {
  entitlements?: Entitlements;
}

/// Open provider: knowing the session code is the only gate. Identity is
/// best-effort — decoded from the client's `mosaicv1` bearer token (without
/// verifying its signature) or from a `?userId=` / `x-mosaic-user-id` fallback.
export class NoAuthProvider implements CollabAuthProvider {
  private readonly entitlements: Entitlements;

  constructor(options: NoAuthProviderOptions = {}) {
    this.entitlements = options.entitlements ?? DEFAULT_ENTITLEMENTS;
  }

  async authenticateRequest(request: Request): Promise<Principal | null> {
    const token = bearerToken(request);
    if (token) {
      const claims = decodeMosaicPayload<NativeSessionClaims>(token);
      const principal = claims ? principalFromClaims(claims) : null;
      if (principal) return principal;
    }
    const url = new URL(request.url);
    const userId =
      url.searchParams.get("userId") ??
      url.searchParams.get("userID") ??
      request.headers.get("x-mosaic-user-id") ??
      "anon";
    const orgId =
      url.searchParams.get("orgId") ??
      url.searchParams.get("teamId") ??
      request.headers.get("x-mosaic-team-id");
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
    if (parts.length < 2 || (parts[0] !== UNSIGNED_PREFIX && parts[0] !== "mosaicv1")) return null;
    try {
      const json = new TextDecoder().decode(base64urlDecodeToBytes(parts[1]));
      return JSON.parse(json) as SessionDescriptorClaims;
    } catch {
      // Fall back to decoding a real mosaicv1 payload if one was supplied.
      return decodeMosaicPayload<SessionDescriptorClaims>(token);
    }
  }

  async mintGrant(_claims: GrantClaims): Promise<string> {
    return "";
  }

  async verifyGrant(): Promise<GrantClaims | null> {
    return null;
  }

  async authorizeRelayConnect(): Promise<RelayConnectDecision> {
    // Fail open: the session code is the gate.
    return { ok: true, claims: null };
  }
}
