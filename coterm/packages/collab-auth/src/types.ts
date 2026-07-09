// Pluggable auth surface shared by the relay, control-plane, and presence workers.
//
// The upstream mosaic server pushed all authorization to a closed "www" service
// (Clerk + Stripe + Stack Auth). This open-source port replaces that with a single
// provider interface + two built-in implementations:
//   - HmacAuthProvider  — verifies mosaicv1 HMAC tokens and mints/verifies signed
//                          join grants + session descriptors with a shared secret.
//   - NoAuthProvider    — knowing the session code is the only gate (the relay's
//                          actual Phase-1 threat model), identity is best-effort.

/// The authenticated (or best-effort) caller identity for control-plane + presence.
/// `orgIds` maps to the presence worker's notion of `teamIds`.
export interface Principal {
  userId: string;
  displayName?: string | null;
  imageURL?: string | null;
  orgIds: readonly string[];
  selectedOrgId?: string | null;
}

/// Shape the Swift client decodes from GET /api/collab/entitlements.
export interface Entitlements {
  plan: string;
  directorySharing: boolean;
  codesEnabled: boolean;
}

/// A shareable teammate for GET /api/collab/org-directory.
export interface DirectoryMember {
  userId: string;
  label: string;
  role?: string;
}

/// Claims inside a short-lived relay join grant. Opaque to the client; minted by
/// the control-plane, verified by the relay before the WebSocket upgrade.
export interface GrantClaims {
  room: string;
  userId: string;
  participantID?: string;
  orgId?: string | null;
  iat: number; // epoch seconds
  exp: number; // epoch seconds
}

/// Claims inside a signed `session` descriptor. Opaque to the client; the client
/// holds it and passes it back on invite/join/withdraw so the owner never needs a
/// server-side descriptor store.
export interface SessionDescriptorClaims {
  room: string;
  ownerUserId: string;
  orgId: string;
  code?: string | null;
  relayURL?: string | null;
  createdAt: number; // epoch seconds
}

export type RelayConnectDecision =
  | { ok: true; claims: GrantClaims | null }
  | { ok: false; reason: string };

export interface CollabAuthProvider {
  /// Identify the caller of a control-plane or presence request. Returns null when
  /// the request is unauthenticated in a mode that requires auth.
  authenticateRequest(request: Request): Promise<Principal | null>;

  /// Epoch-ms expiry of the request's credential, used to bound the presence
  /// subscribe deadline. null → caller falls back to its own max age.
  sessionExpiryMs(request: Request): number | null;

  /// Entitlements for an org/team (plan gating). Static in the OSS defaults.
  resolveEntitlements(principal: Principal, orgId: string): Promise<Entitlements>;

  /// Directory of shareable teammates for an org/team. Empty by default.
  resolveDirectory(principal: Principal, orgId: string): Promise<DirectoryMember[]>;

  /// Sign a session descriptor (control-plane) and verify it (invite/join/withdraw).
  mintSessionDescriptor(claims: SessionDescriptorClaims): Promise<string>;
  verifySessionDescriptor(token: string): Promise<SessionDescriptorClaims | null>;

  /// Mint a relay join grant (control-plane) and verify it (relay).
  mintGrant(claims: GrantClaims): Promise<string>;
  verifyGrant(token: string): Promise<GrantClaims | null>;

  /// Gate the relay WebSocket upgrade: does `grant` authorize joining `room`?
  authorizeRelayConnect(input: {
    room: string;
    grant: string | null;
  }): Promise<RelayConnectDecision>;
}
