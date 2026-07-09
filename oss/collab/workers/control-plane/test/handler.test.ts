import { beforeEach, describe, expect, test } from "bun:test";
import { HmacAuthProvider, nowSeconds, signMosaicToken } from "@mosaic-oss/collab-auth";
import { controlPlaneFetch, type ControlPlaneEnv } from "../src/handler";
import type { InviteRecord } from "../src/invite-store";
import type { RelayClient } from "../src/relay-client";

const SECRET = "control-plane-secret";
const RELAY_URL = "http://relay.local";

// In-memory invite store namespace mirroring the DO RPC surface.
class FakeInviteStore {
  invites = new Map<string, InviteRecord>();
  async put(record: InviteRecord) {
    this.invites.set(record.room, record);
  }
  async list() {
    return [...this.invites.values()].sort((a, b) =>
      a.createdAt < b.createdAt ? 1 : a.createdAt > b.createdAt ? -1 : 0,
    );
  }
  async remove(room: string) {
    return this.invites.delete(room);
  }
  async removeMany(rooms: readonly string[]) {
    for (const r of rooms) this.invites.delete(r);
  }
}

class FakeInviteNamespace {
  stores = new Map<string, FakeInviteStore>();
  idFromName(name: string) {
    return name;
  }
  get(id: string) {
    let store = this.stores.get(id);
    if (!store) {
      store = new FakeInviteStore();
      this.stores.set(id, store);
    }
    return store;
  }
}

class FakeRelay implements RelayClient {
  deadRooms = new Set<string>();
  notifyCalls: Array<{ relayURL: string; inviteeUserId: string }> = [];
  preCreatedCode = "ROOM1234";
  async preCreateRoom() {
    return this.preCreatedCode;
  }
  async probeRoom(_relayURL: string, room: string) {
    return !this.deadRooms.has(room);
  }
  async notifyInbox(relayURL: string, inviteeUserId: string) {
    this.notifyCalls.push({ relayURL, inviteeUserId });
    return 1;
  }
}

let namespace: FakeInviteNamespace;
let relay: FakeRelay;
let provider: HmacAuthProvider;
let env: ControlPlaneEnv;

beforeEach(() => {
  namespace = new FakeInviteNamespace();
  relay = new FakeRelay();
  provider = new HmacAuthProvider({ secret: SECRET });
  env = { INVITE_STORE: namespace, COLLAB_RELAY_URL: RELAY_URL, COLLAB_AUTH_MODE: "hmac", COLLAB_AUTH_SECRET: SECRET };
});

async function accessToken(userId: string, teamIds: string[] = []): Promise<string> {
  return signMosaicToken(
    { kind: "access", userId, teamIds, selectedTeamId: teamIds[0] ?? null, exp: nowSeconds() + 900 },
    SECRET,
  );
}

function req(path: string, init: RequestInit & { token?: string } = {}): Request {
  const headers = new Headers(init.headers);
  if (init.token) headers.set("authorization", `Bearer ${init.token}`);
  if (init.body) headers.set("content-type", "application/json");
  return new Request(`http://cp.local${path}`, { ...init, headers });
}

function call(request: Request): Promise<Response> {
  return controlPlaneFetch(request, env, provider, { relay });
}

describe("auth", () => {
  test("rejects unauthenticated requests in hmac mode", async () => {
    const response = await call(req("/api/collab/inbox", { method: "GET" }));
    expect(response.status).toBe(401);
  });

  test("healthz needs no auth", async () => {
    const response = await call(req("/healthz", { method: "GET" }));
    expect(response.status).toBe(200);
  });
});

describe("entitlements", () => {
  test("returns hobby defaults", async () => {
    const response = await call(req("/api/collab/entitlements?orgId=org1", { method: "GET", token: await accessToken("u1", ["org1"]) }));
    const body = (await response.json()) as { plan: string; directorySharing: boolean; codesEnabled: boolean };
    expect(body).toEqual({ plan: "hobby", directorySharing: false, codesEnabled: true });
  });
});

describe("sessions", () => {
  test("creates a session with all six response fields and a code-shaped room", async () => {
    const response = await call(req("/api/collab/sessions", { method: "POST", token: await accessToken("owner", ["org1"]), body: JSON.stringify({ orgId: "org1" }) }));
    const body = (await response.json()) as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(["code", "entitlements", "grant", "relayURL", "room", "session"]);
    expect(body.room).toBe("ROOM1234");
    expect(body.code).toBe("ROOM1234");
    expect(body.relayURL).toBe(RELAY_URL);
    // The minted grant must authorize connecting to that room.
    const decision = await provider.authorizeRelayConnect({ room: "ROOM1234", grant: body.grant as string });
    expect(decision).toMatchObject({ ok: true });
    // The session descriptor must verify and name the owner.
    const desc = await provider.verifySessionDescriptor(body.session as string);
    expect(desc?.ownerUserId).toBe("owner");
  });

  test("honors a client-supplied code", async () => {
    const response = await call(req("/api/collab/sessions", { method: "POST", token: await accessToken("owner"), body: JSON.stringify({ orgId: "org1", code: "abcd-1234" }) }));
    const body = (await response.json()) as { room: string };
    expect(body.room).toBe("ABCD1234");
  });
});

describe("invite → inbox → reconcile → withdraw", () => {
  async function createSession(owner: string): Promise<{ session: string; room: string }> {
    const response = await call(req("/api/collab/sessions", { method: "POST", token: await accessToken(owner, ["org1"]), body: JSON.stringify({ orgId: "org1" }) }));
    const body = (await response.json()) as { session: string; room: string };
    return { session: body.session, room: body.room };
  }

  test("invite persists a record and nudges the invitee's inbox", async () => {
    const { session } = await createSession("owner");
    const response = await call(req("/api/collab/invite", { method: "POST", token: await accessToken("owner", ["org1"]), body: JSON.stringify({ session, inviteeUserId: "guest" }) }));
    expect(await response.json() as Record<string, unknown>).toEqual({ ok: true });
    expect(namespace.get("guest").invites.size).toBe(1);
    expect(relay.notifyCalls).toEqual([{ relayURL: RELAY_URL, inviteeUserId: "guest" }]);
  });

  test("a non-owner cannot invite on someone else's session", async () => {
    const { session } = await createSession("owner");
    const response = await call(req("/api/collab/invite", { method: "POST", token: await accessToken("attacker"), body: JSON.stringify({ session, inviteeUserId: "guest" }) }));
    expect(response.status).toBe(403);
  });

  test("inbox lists the invitee's invites", async () => {
    const { session } = await createSession("owner");
    await call(req("/api/collab/invite", { method: "POST", token: await accessToken("owner", ["org1"]), body: JSON.stringify({ session, inviteeUserId: "guest" }) }));
    const response = await call(req("/api/collab/inbox", { method: "GET", token: await accessToken("guest") }));
    const body = (await response.json()) as { invites: InviteRecord[] };
    expect(body.invites).toHaveLength(1);
    expect(body.invites[0].ownerUserId).toBe("owner");
    expect(typeof body.invites[0].createdAt).toBe("string");
  });

  test("reconcile prunes invites whose relay room is gone", async () => {
    const { session, room } = await createSession("owner");
    await call(req("/api/collab/invite", { method: "POST", token: await accessToken("owner", ["org1"]), body: JSON.stringify({ session, inviteeUserId: "guest" }) }));
    relay.deadRooms.add(room);
    const response = await call(req("/api/collab/inbox/reconcile", { method: "POST", token: await accessToken("guest"), body: JSON.stringify({}) }));
    const body = (await response.json()) as { invites: InviteRecord[] };
    expect(body.invites).toHaveLength(0);
    expect(namespace.get("guest").invites.size).toBe(0);
  });

  test("withdraw removes the invite from the invitee's store", async () => {
    const { session } = await createSession("owner");
    await call(req("/api/collab/invite", { method: "POST", token: await accessToken("owner", ["org1"]), body: JSON.stringify({ session, inviteeUserId: "guest" }) }));
    const response = await call(req("/api/collab/withdraw", { method: "POST", token: await accessToken("owner"), body: JSON.stringify({ session, inviteeUserId: "guest" }) }));
    expect(await response.json() as Record<string, unknown>).toEqual({ ok: true });
    expect(namespace.get("guest").invites.size).toBe(0);
  });
});

describe("join", () => {
  test("join by code returns a room-bound grant", async () => {
    const response = await call(req("/api/collab/join", { method: "POST", token: await accessToken("guest"), body: JSON.stringify({ code: "abcd-1234" }) }));
    const body = (await response.json()) as { room: string; code: string; relayURL: string; grant: string };
    expect(body.room).toBe("ABCD1234");
    expect(body.code).toBe("ABCD1234");
    const decision = await provider.authorizeRelayConnect({ room: "ABCD1234", grant: body.grant });
    expect(decision).toMatchObject({ ok: true });
  });

  test("join by descriptor extracts the room from the signed session", async () => {
    const sessionsResponse = await call(req("/api/collab/sessions", { method: "POST", token: await accessToken("owner", ["org1"]), body: JSON.stringify({ orgId: "org1" }) }));
    const { session, room } = (await sessionsResponse.json()) as { session: string; room: string };
    const response = await call(req("/api/collab/join", { method: "POST", token: await accessToken("guest"), body: JSON.stringify({ session }) }));
    const body = (await response.json()) as { room: string; grant: string };
    expect(body.room).toBe(room);
    const decision = await provider.authorizeRelayConnect({ room, grant: body.grant });
    expect(decision).toMatchObject({ ok: true });
  });

  test("join with neither code nor session is a 400", async () => {
    const response = await call(req("/api/collab/join", { method: "POST", token: await accessToken("guest"), body: JSON.stringify({}) }));
    expect(response.status).toBe(400);
  });
});
