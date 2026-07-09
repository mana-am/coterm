import {
  type CollabAuthProvider,
  normalizeSessionCode,
  nowSeconds,
  type Principal,
} from "@coterm/collab-auth";
import type { InviteRecord, JoinApprovalRequest, RoomRecord } from "./invite-store";
import { HttpRelayClient, type RelayClient } from "./relay-client";

const GRANT_TTL_SECONDS = 15 * 60;

interface InviteStoreStub {
  put(record: InviteRecord): Promise<void>;
  list(): Promise<InviteRecord[]>;
  remove(room: string): Promise<boolean>;
  removeMany(rooms: readonly string[]): Promise<void>;
  putRoom(record: RoomRecord): Promise<void>;
  getRoom(room: string): Promise<RoomRecord | null>;
  putJoinRequest(record: JoinApprovalRequest): Promise<void>;
  getJoinRequest(requestId: string): Promise<JoinApprovalRequest | null>;
  listJoinRequests(): Promise<JoinApprovalRequest[]>;
}

interface InviteStoreNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): InviteStoreStub;
}

export interface ControlPlaneEnv {
  INVITE_STORE: InviteStoreNamespace;
  COLLAB_RELAY_URL?: string;
  COLLAB_AUTH_MODE?: string;
  COLLAB_AUTH_SECRET?: string;
}

export interface ControlPlaneDeps {
  relay?: RelayClient;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function inviteStore(env: ControlPlaneEnv, userId: string): InviteStoreStub {
  return env.INVITE_STORE.get(env.INVITE_STORE.idFromName(userId));
}

function roomStore(env: ControlPlaneEnv, room: string): InviteStoreStub {
  return env.INVITE_STORE.get(env.INVITE_STORE.idFromName(`room:${room}`));
}

function resolveOrgId(explicit: unknown, principal: Principal): string {
  if (typeof explicit === "string" && explicit.trim() !== "") return explicit;
  if (principal.selectedOrgId) return principal.selectedOrgId;
  if (principal.orgIds.length > 0) return principal.orgIds[0];
  return principal.userId; // personal workspace
}

async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await request.json();
    return body !== null && typeof body === "object" ? (body as Record<string, unknown>) : {};
  } catch {
    return null;
  }
}

function randomShareSecret(): string {
  const values = new Uint8Array(32);
  crypto.getRandomValues(values);
  let binary = "";
  for (const value of values) binary += String.fromCharCode(value);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function readShareSecret(body: Record<string, unknown>): string {
  const value = typeof body.shareSecret === "string"
    ? body.shareSecret
    : typeof body.secret === "string"
      ? body.secret
      : "";
  return value.trim();
}

export async function controlPlaneFetch(
  request: Request,
  env: ControlPlaneEnv,
  provider: CollabAuthProvider,
  deps: ControlPlaneDeps = {},
): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const relay = deps.relay ?? new HttpRelayClient();

  if (path === "/healthz") {
    return json({ ok: true, service: "coterm-control-plane" });
  }

  const isCollab = path.startsWith("/api/collab/");
  if (!isCollab) return json({ error: "not_found" }, 404);

  const principal = await provider.authenticateRequest(request);
  if (principal === null) return json({ error: "unauthorized" }, 401);

  // GET /api/collab/entitlements
  if (path === "/api/collab/entitlements" && request.method === "GET") {
    const orgId = resolveOrgId(url.searchParams.get("orgId"), principal);
    return json(await provider.resolveEntitlements(principal, orgId));
  }

  // GET /api/collab/org-directory
  if (path === "/api/collab/org-directory" && request.method === "GET") {
    const orgId = resolveOrgId(url.searchParams.get("orgId"), principal);
    return json({ members: await provider.resolveDirectory(principal, orgId) });
  }

  // GET /api/collab/inbox
  if (path === "/api/collab/inbox" && request.method === "GET") {
    const invites = await inviteStore(env, principal.userId).list();
    return json({ invites });
  }

  // POST /api/collab/sessions
  if (path === "/api/collab/sessions" && request.method === "POST") {
    const body = await readJson(request);
    if (body === null) return json({ error: "invalid_json" }, 400);
    const orgId = resolveOrgId(body.orgId, principal);
    const relayURL = typeof body.relayURL === "string" && body.relayURL.trim() !== ""
      ? body.relayURL
      : env.COLLAB_RELAY_URL ?? "";
    const entitlements = await provider.resolveEntitlements(principal, orgId);

    let room: string | null;
    let shareSecret: string;
    if (typeof body.code === "string" && body.code.trim() !== "") {
      room = normalizeSessionCode(body.code);
      if (room === null) return json({ error: "invalid_session_code" }, 400);
      shareSecret = readShareSecret(body) || randomShareSecret();
    } else {
      if (!entitlements.codesEnabled) return json({ error: "codes_disabled" }, 403);
      const precreated = await relay.preCreateRoom(relayURL);
      if (precreated === null) return json({ error: "relay_unavailable" }, 502);
      room = precreated.room;
      shareSecret = precreated.shareSecret ?? randomShareSecret();
    }

    const session = await provider.mintSessionDescriptor({
      room,
      ownerUserId: principal.userId,
      orgId,
      code: room,
      relayURL,
      shareSecret,
      createdAt: nowSeconds(),
    });
    await roomStore(env, room).putRoom({
      room,
      ownerUserId: principal.userId,
      orgId,
      relayURL,
      shareSecret,
      createdAt: new Date().toISOString(),
    });
    const grant = await mintGrant(provider, room, principal, orgId);
    return json({ session, room, code: room, relayURL, grant, shareSecret, entitlements });
  }

  // POST /api/collab/invite
  if (path === "/api/collab/invite" && request.method === "POST") {
    const body = await readJson(request);
    if (body === null) return json({ error: "invalid_json" }, 400);
    const session = typeof body.session === "string" ? body.session : "";
    const inviteeUserId = typeof body.inviteeUserId === "string" ? body.inviteeUserId.trim() : "";
    if (!session || !inviteeUserId) return json({ error: "invalid_request" }, 400);
    const desc = await provider.verifySessionDescriptor(session);
    if (desc === null) return json({ error: "invalid_session" }, 400);
    if (desc.ownerUserId !== principal.userId) return json({ error: "forbidden" }, 403);
    const relayURL = typeof body.relayURL === "string" && body.relayURL.trim() !== ""
      ? body.relayURL
      : desc.relayURL ?? env.COLLAB_RELAY_URL ?? "";
    const record: InviteRecord = {
      session,
      room: desc.room,
      ownerUserId: principal.userId,
      orgId: desc.orgId,
      relayURL,
      createdAt: new Date().toISOString(),
    };
    if (principal.displayName) record.ownerName = principal.displayName;
    if (principal.imageURL) record.ownerImageURL = principal.imageURL;
    await inviteStore(env, inviteeUserId).put(record);
    if (relayURL) await relay.notifyInbox(relayURL, inviteeUserId);
    return json({ ok: true });
  }

  // POST /api/collab/withdraw
  if (path === "/api/collab/withdraw" && request.method === "POST") {
    const body = await readJson(request);
    if (body === null) return json({ error: "invalid_json" }, 400);
    const session = typeof body.session === "string" ? body.session : "";
    const inviteeUserId = typeof body.inviteeUserId === "string" ? body.inviteeUserId.trim() : "";
    if (!session || !inviteeUserId) return json({ error: "invalid_request" }, 400);
    const desc = await provider.verifySessionDescriptor(session);
    if (desc === null) return json({ error: "invalid_session" }, 400);
    if (desc.ownerUserId !== principal.userId) return json({ error: "forbidden" }, 403);
    await inviteStore(env, inviteeUserId).remove(desc.room);
    return json({ ok: true });
  }

  // POST /api/collab/inbox/reconcile
  if (path === "/api/collab/inbox/reconcile" && request.method === "POST") {
    const invites = await inviteStore(env, principal.userId).list();
    const dead: string[] = [];
    const survivors: InviteRecord[] = [];
    for (const invite of invites) {
      const relayURL = invite.relayURL ?? env.COLLAB_RELAY_URL ?? "";
      const active = relayURL ? await relay.probeRoom(relayURL, invite.room) : true;
      if (active) survivors.push(invite);
      else dead.push(invite.room);
    }
    if (dead.length > 0) await inviteStore(env, principal.userId).removeMany(dead);
    return json({ invites: survivors });
  }

  // GET /api/collab/join-requests
  if (path === "/api/collab/join-requests" && request.method === "GET") {
    const requests = await inviteStore(env, principal.userId).listJoinRequests();
    return json({ requests });
  }

  // POST /api/collab/join-requests/approve
  if (path === "/api/collab/join-requests/approve" && request.method === "POST") {
    const body = await readJson(request);
    if (body === null) return json({ error: "invalid_json" }, 400);
    const requestId = typeof body.requestId === "string" ? body.requestId.trim() : "";
    const approved = body.approved !== false;
    if (!requestId) return json({ error: "invalid_request" }, 400);
    const store = inviteStore(env, principal.userId);
    const pending = await store.getJoinRequest(requestId);
    if (pending === null) return json({ error: "join_request_not_found" }, 404);
    if (pending.status !== "pending") return json({ request: pending });
    const decidedAt = new Date().toISOString();
    const requestRecord: JoinApprovalRequest = approved
      ? {
          ...pending,
          status: "approved",
          decidedAt,
          grant: await mintGrant(
            provider,
            pending.room,
            {
              userId: pending.requesterUserId,
              displayName: pending.requesterName ?? null,
              imageURL: pending.requesterImageURL ?? null,
              orgIds: [pending.orgId],
              selectedOrgId: pending.orgId,
            },
            pending.orgId,
          ),
        }
      : { ...pending, status: "denied", decidedAt };
    await store.putJoinRequest(requestRecord);
    return json({ request: requestRecord });
  }

  // POST /api/collab/join-requests/claim
  if (path === "/api/collab/join-requests/claim" && request.method === "POST") {
    const body = await readJson(request);
    if (body === null) return json({ error: "invalid_json" }, 400);
    const room = typeof body.room === "string" ? normalizeSessionCode(body.room) : null;
    const requestId = typeof body.requestId === "string" ? body.requestId.trim() : "";
    if (room === null || !requestId) return json({ error: "invalid_request" }, 400);
    const roomRecord = await roomStore(env, room).getRoom(room);
    if (roomRecord === null) return json({ error: "session_not_found" }, 404);
    const requestRecord = await inviteStore(env, roomRecord.ownerUserId).getJoinRequest(requestId);
    if (requestRecord === null || requestRecord.requesterUserId !== principal.userId) {
      return json({ error: "join_request_not_found" }, 404);
    }
    if (requestRecord.status === "pending") {
      return json({ status: "pending", requestId, room, code: room, relayURL: requestRecord.relayURL ?? roomRecord.relayURL ?? "" }, 202);
    }
    if (requestRecord.status === "denied") return json({ error: "join_denied" }, 403);
    if (!requestRecord.grant) return json({ error: "grant_unavailable" }, 502);
    return json({
      room,
      code: room,
      relayURL: requestRecord.relayURL ?? roomRecord.relayURL ?? "",
      grant: requestRecord.grant,
    });
  }

  // POST /api/collab/join
  if (path === "/api/collab/join" && request.method === "POST") {
    const body = await readJson(request);
    if (body === null) return json({ error: "invalid_json" }, 400);
    let room: string | null = null;
    let relayURL = env.COLLAB_RELAY_URL ?? "";
    let orgId = resolveOrgId(undefined, principal);

    if (typeof body.code === "string" && body.code.trim() !== "") {
      const entitlements = await provider.resolveEntitlements(principal, orgId);
      if (!entitlements.codesEnabled) return json({ error: "codes_disabled" }, 403);
      room = normalizeSessionCode(body.code);
      if (room === null) return json({ error: "invalid_session_code" }, 400);
      if (typeof body.relayURL === "string" && body.relayURL.trim() !== "") relayURL = body.relayURL;
      const shareSecret = readShareSecret(body);
      if (!shareSecret) return json({ error: "share_secret_required" }, 400);
      const roomRecord = await roomStore(env, room).getRoom(room);
      if (roomRecord === null) return json({ error: "session_not_found" }, 404);
      if (roomRecord.shareSecret !== shareSecret) return json({ error: "invalid_share_secret" }, 403);
      const requestId = crypto.randomUUID();
      const requestRecord: JoinApprovalRequest = {
        requestId,
        room,
        requesterUserId: principal.userId,
        orgId: roomRecord.orgId,
        relayURL: relayURL || roomRecord.relayURL,
        status: "pending",
        createdAt: new Date().toISOString(),
      };
      if (principal.displayName) requestRecord.requesterName = principal.displayName;
      if (principal.imageURL) requestRecord.requesterImageURL = principal.imageURL;
      await inviteStore(env, roomRecord.ownerUserId).putJoinRequest(requestRecord);
      const notifyRelayURL = requestRecord.relayURL ?? roomRecord.relayURL ?? env.COLLAB_RELAY_URL ?? "";
      if (notifyRelayURL) await relay.notifyInbox(notifyRelayURL, roomRecord.ownerUserId);
      return json({ status: "pending", requestId, room, code: room, relayURL: notifyRelayURL }, 202);
    } else if (typeof body.session === "string" && body.session.trim() !== "") {
      const desc = await provider.verifySessionDescriptor(body.session);
      if (desc === null) return json({ error: "invalid_session" }, 400);
      room = desc.room;
      orgId = desc.orgId;
      relayURL = typeof body.relayURL === "string" && body.relayURL.trim() !== ""
        ? body.relayURL
        : desc.relayURL ?? relayURL;
    } else {
      return json({ error: "invalid_request" }, 400);
    }

    const grant = await mintGrant(provider, room, principal, orgId);
    return json({ room, code: room, relayURL, grant });
  }

  return json({ error: "not_found" }, 404);
}

async function mintGrant(
  provider: CollabAuthProvider,
  room: string,
  principal: Principal,
  orgId: string,
): Promise<string> {
  const iat = nowSeconds();
  return provider.mintGrant({
    room,
    userId: principal.userId,
    orgId,
    iat,
    exp: iat + GRANT_TTL_SECONDS,
  });
}
