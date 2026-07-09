// Thin HTTP client for the relay worker's public endpoints. Injectable so the
// control-plane handler can be unit-tested without a live relay.

export interface RelayClient {
  /// POST /v1/collaboration/sessions → pre-create a fresh session code (room).
  preCreateRoom(relayURL: string): Promise<{ room: string; shareSecret: string | null } | null>;
  /// GET /v1/collaboration/sessions/:room/metadata → is the room still live?
  probeRoom(relayURL: string, room: string): Promise<boolean>;
  /// POST /v1/collaboration/inbox/notify → nudge an invitee's live inbox sockets.
  notifyInbox(relayURL: string, inviteeUserId: string): Promise<number>;
}

function joinURL(base: string, path: string): string {
  const trimmed = base.replace(/\/+$/, "");
  return `${trimmed}${path}`;
}

export class HttpRelayClient implements RelayClient {
  constructor(private readonly fetchFn: typeof fetch = fetch) {}

  async preCreateRoom(relayURL: string): Promise<{ room: string; shareSecret: string | null } | null> {
    try {
      const response = await this.fetchFn(joinURL(relayURL, "/v1/collaboration/sessions"), {
        method: "POST",
      });
      if (!response.ok) return null;
      const body = (await response.json()) as { sessionCode?: unknown; shareSecret?: unknown };
      return typeof body.sessionCode === "string"
        ? {
            room: body.sessionCode,
            shareSecret: typeof body.shareSecret === "string" ? body.shareSecret : null,
          }
        : null;
    } catch {
      return null;
    }
  }

  async probeRoom(relayURL: string, room: string): Promise<boolean> {
    try {
      const response = await this.fetchFn(
        joinURL(relayURL, `/v1/collaboration/sessions/${encodeURIComponent(room)}/metadata`),
        { method: "GET" },
      );
      if (!response.ok) return true; // fail open: don't prune on a probe error
      const body = (await response.json()) as { active?: unknown };
      return body.active !== false;
    } catch {
      return true; // fail open
    }
  }

  async notifyInbox(relayURL: string, inviteeUserId: string): Promise<number> {
    try {
      const response = await this.fetchFn(joinURL(relayURL, "/v1/collaboration/inbox/notify"), {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ inviteeUserId }),
      });
      if (!response.ok) return 0;
      const body = (await response.json()) as { delivered?: unknown };
      return typeof body.delivered === "number" ? body.delivered : 0;
    } catch {
      return 0;
    }
  }
}
