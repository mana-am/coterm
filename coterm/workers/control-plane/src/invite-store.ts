import { DurableObject } from "cloudflare:workers";

/// One persisted invite for an invitee. Mirrors the Swift client's
/// CollaborationIncomingSession shape (plus `room` for keying). Extra keys are
/// ignored by the client's JSONDecoder.
export interface InviteRecord {
  session: string;
  room: string;
  ownerUserId: string;
  ownerName?: string;
  ownerImageURL?: string;
  orgId: string;
  orgName?: string;
  relayURL?: string;
  createdAt: string; // ISO 8601 — the Swift client decodes createdAt as a String
}

export interface RoomRecord {
  room: string;
  ownerUserId: string;
  orgId: string;
  relayURL?: string;
  shareSecret: string;
  createdAt: string;
}

export interface JoinApprovalRequest {
  requestId: string;
  room: string;
  requesterUserId: string;
  requesterName?: string;
  requesterImageURL?: string;
  orgId: string;
  relayURL?: string;
  status: "pending" | "approved" | "denied";
  createdAt: string;
  decidedAt?: string;
  grant?: string;
}

const INVITE_KEY_PREFIX = "invite:";
const ROOM_KEY_PREFIX = "room:";
const JOIN_REQUEST_KEY_PREFIX = "join-request:";

/// One Durable Object per invitee (addressed via idFromName(inviteeUserId)),
/// mirroring the relay's inbox DO. Holds the invitee's authoritative invite list.
/// Keyed by room so a re-invite upserts and a withdraw deletes by room.
export class InviteStoreObject extends DurableObject {
  async put(record: InviteRecord): Promise<void> {
    await this.ctx.storage.put(`${INVITE_KEY_PREFIX}${record.room}`, record);
  }

  async list(): Promise<InviteRecord[]> {
    const entries = await this.ctx.storage.list<InviteRecord>({ prefix: INVITE_KEY_PREFIX });
    // Newest first by createdAt (ISO strings sort lexicographically by time).
    return [...entries.values()].sort((left, right) =>
      left.createdAt < right.createdAt ? 1 : left.createdAt > right.createdAt ? -1 : 0,
    );
  }

  async remove(room: string): Promise<boolean> {
    return this.ctx.storage.delete(`${INVITE_KEY_PREFIX}${room}`);
  }

  async removeMany(rooms: readonly string[]): Promise<void> {
    for (const room of rooms) {
      await this.ctx.storage.delete(`${INVITE_KEY_PREFIX}${room}`);
    }
  }

  async putRoom(record: RoomRecord): Promise<void> {
    await this.ctx.storage.put(`${ROOM_KEY_PREFIX}${record.room}`, record);
  }

  async getRoom(room: string): Promise<RoomRecord | null> {
    return (await this.ctx.storage.get<RoomRecord>(`${ROOM_KEY_PREFIX}${room}`)) ?? null;
  }

  async putJoinRequest(record: JoinApprovalRequest): Promise<void> {
    await this.ctx.storage.put(`${JOIN_REQUEST_KEY_PREFIX}${record.requestId}`, record);
  }

  async getJoinRequest(requestId: string): Promise<JoinApprovalRequest | null> {
    return (await this.ctx.storage.get<JoinApprovalRequest>(`${JOIN_REQUEST_KEY_PREFIX}${requestId}`)) ?? null;
  }

  async listJoinRequests(): Promise<JoinApprovalRequest[]> {
    const entries = await this.ctx.storage.list<JoinApprovalRequest>({ prefix: JOIN_REQUEST_KEY_PREFIX });
    return [...entries.values()].sort((left, right) =>
      left.createdAt < right.createdAt ? 1 : left.createdAt > right.createdAt ? -1 : 0,
    );
  }
}
