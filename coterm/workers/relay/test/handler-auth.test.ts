import { expect, test } from "bun:test";
import { HmacAuthProvider, NoAuthProvider, nowSeconds } from "@coterm/collab-auth";
import { collaborationFetch, type CollaborationWorkerEnv } from "../src/handler";

const SECRET = "relay-gate-secret";

// Minimal session namespace: /connect returns 299 so we can tell routing happened.
class FakeSessionStub {
  createdSessionCode: string;
  fetchRequests: Request[] = [];
  constructor(code: string) {
    this.createdSessionCode = code;
  }
  async create(sessionCode: string, _shareSecret: string) {
    return { metadata: { sessionID: sessionCode, sessionCode }, created: true };
  }
  async fetch(request: Request) {
    this.fetchRequests.push(request);
    return new Response("routed-to-session", { status: 299 });
  }
}

class FakeSessionNamespace {
  stubs = new Map<string, FakeSessionStub>();
  idFromName(name: string) {
    return name;
  }
  get(id: string) {
    let stub = this.stubs.get(id);
    if (!stub) {
      stub = new FakeSessionStub(id);
      this.stubs.set(id, stub);
    }
    return stub;
  }
}

function envWith(namespace: FakeSessionNamespace): CollaborationWorkerEnv {
  return { COLLABORATION_SESSIONS: namespace } satisfies CollaborationWorkerEnv;
}

function connect(code: string, grant?: string): Request {
  const url = new URL(`http://relay.test/v1/collaboration/sessions/${code}/connect`);
  if (grant !== undefined) url.searchParams.set("grant", grant);
  return new Request(url, { method: "GET" });
}

test("noauth provider rejects code-only connect without a grant", async () => {
  const namespace = new FakeSessionNamespace();
  namespace.get("ABCD1234");
  const response = await collaborationFetch(connect("ABCD1234"), envWith(namespace), new NoAuthProvider());
  expect(response.status).toBe(403);
});

test("hmac provider rejects a connect without a grant", async () => {
  const namespace = new FakeSessionNamespace();
  namespace.get("ABCD1234");
  const provider = new HmacAuthProvider({ secret: SECRET });
  const response = await collaborationFetch(connect("ABCD1234"), envWith(namespace), provider);
  const body = (await response.json()) as { error: string; reason: string };
  expect(response.status).toBe(403);
  expect(body.error).toBe("forbidden");
  expect(namespace.stubs.get("ABCD1234")?.fetchRequests).toHaveLength(0);
});

test("hmac provider accepts a valid room-bound grant", async () => {
  const namespace = new FakeSessionNamespace();
  namespace.get("ABCD1234");
  const provider = new HmacAuthProvider({ secret: SECRET });
  const grant = await provider.mintGrant({
    room: "ABCD1234",
    userId: "u1",
    iat: nowSeconds(),
    exp: nowSeconds() + 900,
  });
  const response = await collaborationFetch(connect("ABCD1234", grant), envWith(namespace), provider);
  expect(response.status).toBe(299);
});

test("hmac provider rejects a grant minted for a different room", async () => {
  const namespace = new FakeSessionNamespace();
  namespace.get("ABCD1234");
  const provider = new HmacAuthProvider({ secret: SECRET });
  const grant = await provider.mintGrant({
    room: "ZZZZ9999",
    userId: "u1",
    iat: nowSeconds(),
    exp: nowSeconds() + 900,
  });
  const response = await collaborationFetch(connect("ABCD1234", grant), envWith(namespace), provider);
  expect(response.status).toBe(403);
});

test("grant gate runs after code normalization (malformed code still 400s)", async () => {
  const namespace = new FakeSessionNamespace();
  const provider = new HmacAuthProvider({ secret: SECRET });
  const response = await collaborationFetch(connect("abc"), envWith(namespace), provider);
  const body = (await response.json()) as { error: string };
  expect(response.status).toBe(400);
  expect(body.error).toBe("invalid_session_code");
});
