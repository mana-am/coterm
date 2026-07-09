import {
  bearerToken,
  claimsExpiryMs,
  type NativeSessionClaims,
  normalizeSessionCode,
  nowSeconds,
  principalFromClaims,
} from "./common";
import { decodeCotermPayload, signCotermToken, verifyCotermToken } from "./hmac";
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

const AUTH_CACHE_MAX_ENTRIES = 1024;

/// Optional hook for supplying a shareable teammate directory (e.g. backed by KV).
export type DirectorySource = (
  principal: Principal,
  orgId: string,
) => Promise<DirectoryMember[]> | DirectoryMember[];

export interface HmacAuthProviderOptions {
  secret: string;
  entitlements?: Entitlements;
  directory?: DirectorySource;
}

// Grant/descriptor envelopes are tagged so a grant can never be replayed as an
// access token and vice versa (access tokens carry `kind`, never `t`).
type GrantEnvelope = GrantClaims & { t: "grant" };
type DescriptorEnvelope = SessionDescriptorClaims & { t: "descriptor" };

interface CacheEntry {
  principal: Principal;
  expMs: number;
}

export class HmacAuthProvider implements CollabAuthProvider {
  private readonly secret: string;
  private readonly entitlements: Entitlements;
  private readonly directory?: DirectorySource;
  private readonly cache = new Map<string, CacheEntry>();

  constructor(options: HmacAuthProviderOptions) {
    if (!options.secret) throw new Error("HmacAuthProvider requires a non-empty secret");
    this.secret = options.secret;
    this.entitlements = options.entitlements ?? DEFAULT_ENTITLEMENTS;
    this.directory = options.directory;
  }

  async authenticateRequest(request: Request): Promise<Principal | null> {
    const token = bearerToken(request);
    if (!token) return null;

    const now = Date.now();
    const cached = this.cache.get(token);
    if (cached) {
      if (cached.expMs > now) return cached.principal;
      this.cache.delete(token);
    }

    const claims = await verifyCotermToken<NativeSessionClaims>(token, this.secret);
    if (claims === null) return null;
    if (claims.kind !== "access") return null; // reject refresh tokens, grants, descriptors
    if (typeof claims.exp === "number" && claims.exp <= nowSeconds()) return null;
    const principal = principalFromClaims(claims);
    if (principal === null) return null;

    const expMs = claimsExpiryMs(claims) ?? now + 60_000;
    this.storeCache(token, { principal, expMs });
    return principal;
  }

  sessionExpiryMs(request: Request): number | null {
    const token = bearerToken(request);
    if (!token) return null;
    const claims = decodeCotermPayload<NativeSessionClaims>(token);
    return claims ? claimsExpiryMs(claims) : null;
  }

  async resolveEntitlements(): Promise<Entitlements> {
    return { ...this.entitlements };
  }

  async resolveDirectory(principal: Principal, orgId: string): Promise<DirectoryMember[]> {
    if (!this.directory) return [];
    return this.directory(principal, orgId);
  }

  async mintSessionDescriptor(claims: SessionDescriptorClaims): Promise<string> {
    const envelope: DescriptorEnvelope = { ...claims, t: "descriptor" };
    return signCotermToken(envelope, this.secret);
  }

  async verifySessionDescriptor(token: string): Promise<SessionDescriptorClaims | null> {
    const envelope = await verifyCotermToken<DescriptorEnvelope>(token, this.secret);
    if (envelope === null || envelope.t !== "descriptor") return null;
    const { t: _t, ...claims } = envelope;
    return claims;
  }

  async mintGrant(claims: GrantClaims): Promise<string> {
    const envelope: GrantEnvelope = { ...claims, t: "grant" };
    return signCotermToken(envelope, this.secret);
  }

  async verifyGrant(token: string): Promise<GrantClaims | null> {
    const envelope = await verifyCotermToken<GrantEnvelope>(token, this.secret);
    if (envelope === null || envelope.t !== "grant") return null;
    const { t: _t, ...claims } = envelope;
    return claims;
  }

  async authorizeRelayConnect(input: {
    room: string;
    grant: string | null;
  }): Promise<RelayConnectDecision> {
    if (!input.grant) return { ok: false, reason: "missing_grant" };
    const claims = await this.verifyGrant(input.grant);
    if (claims === null) return { ok: false, reason: "invalid_grant" };
    if (claims.exp <= nowSeconds()) return { ok: false, reason: "grant_expired" };
    const grantRoom = normalizeSessionCode(claims.room) ?? claims.room;
    if (grantRoom !== input.room) return { ok: false, reason: "room_mismatch" };
    return { ok: true, claims };
  }

  private storeCache(token: string, entry: CacheEntry): void {
    if (this.cache.size >= AUTH_CACHE_MAX_ENTRIES) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) this.cache.delete(oldest);
    }
    this.cache.set(token, entry);
  }
}
