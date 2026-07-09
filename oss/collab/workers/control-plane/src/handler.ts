import {
  type CollabAuthProvider,
  normalizeSessionCode,
  nowSeconds,
  type Principal,
} from "@mosaic-oss/collab-auth";
import type { InviteRecord } from "./invite-store";
import { HttpRelayClient, type RelayClient } from "./relay-client";

const GRANT_TTL_SECONDS = 15 * 60;

interface InviteStoreStub {
  put(record: InviteRecord): Promise<void>;
  list(): Promise<InviteRecord[]>;
  remove(room: string): Promise<boolean>;
  removeMany(rooms: readonly string[]): Promise<void>;
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
    return json({ ok: true, service: "mosaic-collaboration-control-plane" });
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
    if (typeof body.code === "string" && body.code.trim() !== "") {
      room = normalizeSessionCode(body.code);
      if (room === null) return json({ error: "invalid_session_code" }, 400);
    } else {
      if (!entitlements.codesEnabled) return json({ error: "codes_disabled" }, 403);
      room = await relay.preCreateRoom(relayURL);
      if (room === null) return json({ error: "relay_unavailable" }, 502);
    }

    const session = await provider.mintSessionDescriptor({
      room,
      ownerUserId: principal.userId,
      orgId,
      code: room,
      relayURL,
      createdAt: nowSeconds(),
    });
    const grant = await mintGrant(provider, room, principal, orgId);
    return json({ session, room, code: room, relayURL, grant, entitlements });
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
