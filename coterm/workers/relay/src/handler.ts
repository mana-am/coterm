import type { CollabAuthProvider } from "@coterm/collab-auth";
import {
  json,
  normalizeSessionCode,
  randomPreviewId,
  randomSessionCode,
  randomShareSecret,
  type PreviewCreateResponse,
  type SessionCreateResponse,
} from "./protocol";
import {
  normalizePreviewId,
  parsePreviewTarget,
  sha256Hex,
  type PreviewCreateRequest,
} from "./preview-protocol";

interface CollaborationSessionStub {
  create(
    sessionCode: string,
    shareSecret: string,
  ): Promise<{ metadata: { sessionID: string; sessionCode: string }; created: boolean }>;
  fetch(request: Request): Promise<Response>;
}

interface CollaborationSessionIndexStub {
  fetch(request: Request): Promise<Response>;
}

interface CollaborationSessionNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): CollaborationSessionStub;
}

interface CollaborationSessionIndexNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): CollaborationSessionIndexStub;
}

interface CollaborationInboxStub {
  fetch(request: Request): Promise<Response>;
}

interface CollaborationInboxNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): CollaborationInboxStub;
}

interface PreviewSessionStub {
  fetch(request: Request): Promise<Response>;
}

interface PreviewSessionNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): PreviewSessionStub;
}

export interface CollaborationWorkerEnv {
  COLLABORATION_SESSIONS: CollaborationSessionNamespace;
  COLLABORATION_SESSION_INDEX?: CollaborationSessionIndexNamespace;
  COLLABORATION_INBOX?: CollaborationInboxNamespace;
  PREVIEW_SESSIONS?: PreviewSessionNamespace;
  COLLABORATION_ADMIN_TOKEN?: string;
}

const SESSION_INDEX_OBJECT_NAME = "global";

export async function collaborationFetch(
  request: Request,
  env: CollaborationWorkerEnv,
  provider?: CollabAuthProvider,
): Promise<Response> {
  const url = new URL(request.url);

  if (url.pathname === "/healthz") {
    return json({ ok: true, service: "coterm-relay" });
  }

  if (
    url.pathname === "/v1/collaboration/sessions" &&
    request.method === "POST"
  ) {
    const metadata = await createUniqueSession(env);
    await recordIndexedSession(env, metadata);
    return json(metadata, 201);
  }

  if (
    url.pathname === "/v1/collaboration/admin/sessions" &&
    request.method === "GET"
  ) {
    const adminError = requireAdminToken(request, env);
    if (adminError) return adminError;
    return listIndexedSessions(url, env);
  }

  const adminSessionMatch = url.pathname.match(
    /^\/v1\/collaboration\/admin\/sessions\/([^/]+)$/,
  );
  if (adminSessionMatch && request.method === "GET") {
    const adminError = requireAdminToken(request, env);
    if (adminError) return adminError;
    return describeSessionCode(decodeURIComponent(adminSessionMatch[1]), env);
  }

  if (
    url.pathname === "/v1/collaboration/inbox/connect" &&
    request.method === "GET"
  ) {
    return connectInbox(url, request, env);
  }

  if (
    url.pathname === "/v1/collaboration/inbox/notify" &&
    request.method === "POST"
  ) {
    return notifyInbox(request, env);
  }

  if (url.pathname === "/v1/preview/sessions" && request.method === "POST") {
    return createPreviewSession(request, env, url);
  }

  const previewHostMatch = url.pathname.match(/^\/v1\/preview\/sessions\/([^/]+)\/host$/);
  if (previewHostMatch && request.method === "GET") {
    return routePreview(previewHostMatch[1], "/host", request, env);
  }

  const previewMetadataMatch = url.pathname.match(/^\/v1\/preview\/sessions\/([^/]+)\/metadata$/);
  if (previewMetadataMatch && request.method === "GET") {
    return routePreview(previewMetadataMatch[1], "/metadata", request, env);
  }

  const previewProxyMatch = url.pathname.match(/^\/v1\/preview\/sessions\/([^/]+)\/proxy(\/.*)?$/);
  if (previewProxyMatch) {
    return routePreview(previewProxyMatch[1], `/proxy${previewProxyMatch[2] ?? "/"}`, request, env);
  }

  const previewCloseMatch = url.pathname.match(/^\/v1\/preview\/sessions\/([^/]+)$/);
  if (previewCloseMatch && request.method === "DELETE") {
    return routePreview(previewCloseMatch[1], "/close", request, env);
  }

  const metadataMatch = url.pathname.match(
    /^\/v1\/collaboration\/sessions\/([^/]+)\/metadata$/,
  );
  if (metadataMatch && request.method === "GET") {
    return sessionLiveness(decodeURIComponent(metadataMatch[1]), env);
  }

  const match = url.pathname.match(
    /^\/v1\/collaboration\/sessions\/([^/]+)\/connect$/,
  );
  if (match && request.method === "GET") {
    const sessionCode = normalizeSessionCode(decodeURIComponent(match[1]));
    if (!sessionCode) return json({ error: "invalid_session_code" }, 400);
    // The only added gate vs. the upstream relay: verify the join grant before
    // the WebSocket upgrade. NoAuthProvider always passes (session code is the
    // gate); HmacAuthProvider checks the grant's signature, room binding, and exp.
    if (provider) {
      const decision = await provider.authorizeRelayConnect({
        room: sessionCode,
        grant: url.searchParams.get("grant"),
      });
      if (!decision.ok) {
        return json({ error: "forbidden", reason: decision.reason }, 403);
      }
    }
    const stub = env.COLLABORATION_SESSIONS.get(
      env.COLLABORATION_SESSIONS.idFromName(sessionCode),
    );
    return stub.fetch(request);
  }

  const previewCookie = parsePreviewCookie(request.headers.get("cookie"));
  if (previewCookie !== null) {
    const fallbackUrl = new URL(request.url);
    fallbackUrl.searchParams.set("t", previewCookie.token);
    return routePreview(previewCookie.previewId, `/proxy${fallbackUrl.pathname}`, new Request(fallbackUrl, request), env);
  }

  return json({ error: "not_found" }, 404);
}

function parsePreviewCookie(header: string | null): { previewId: string; token: string } | null {
  if (!header) return null;
  const preview = header
    .split(";")
    .map((part) => part.trim())
    .find((part) => part.startsWith("coterm_preview="));
  if (!preview) return null;
  const value = decodeURIComponent(preview.slice("coterm_preview=".length));
  const separator = value.indexOf(".");
  if (separator < 0) return null;
  const previewId = normalizePreviewId(value.slice(0, separator));
  const token = value.slice(separator + 1);
  return previewId === null || token === "" ? null : { previewId, token };
}

async function createPreviewSession(
  request: Request,
  env: CollaborationWorkerEnv,
  relayURL: URL,
): Promise<Response> {
  if (!env.PREVIEW_SESSIONS) return json({ error: "preview_disabled" }, 404);
  let body: Record<string, unknown>;
  try {
    const parsed = await request.json();
    body = parsed !== null && typeof parsed === "object" ? parsed as Record<string, unknown> : {};
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const room = normalizeSessionCode(typeof body.room === "string" ? body.room : "");
  if (room === null) return json({ error: "invalid_session_code" }, 400);
  const shareSecret = typeof body.shareSecret === "string" ? body.shareSecret.trim() : "";
  if (shareSecret === "") return json({ error: "missing_share_secret" }, 400);
  const target = parsePreviewTarget(body.target);
  if (target === null) return json({ error: "invalid_preview_target" }, 400);
  const verified = await verifySessionShareSecret(env, room, shareSecret);
  if (!verified) return json({ error: "forbidden" }, 403);

  const previewId = randomPreviewId();
  const hostToken = randomShareSecret();
  const viewerToken = randomShareSecret();
  const stub = env.PREVIEW_SESSIONS.get(env.PREVIEW_SESSIONS.idFromName(previewId));
  const createBody: PreviewCreateRequest = { previewId, room, target, hostToken, viewerToken };
  const response = await stub.fetch(new Request("https://coterm-preview.local/create", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(createBody),
  }));
  if (!response.ok) return response;
  const url = new URL(`/v1/preview/sessions/${previewId}/proxy/`, relayURL.origin);
  url.searchParams.set("t", viewerToken);
  const result: PreviewCreateResponse = {
    previewId,
    hostToken,
    viewerToken,
    url: url.href,
  };
  return json(result, 201);
}

async function routePreview(
  rawPreviewId: string,
  internalPath: string,
  request: Request,
  env: CollaborationWorkerEnv,
): Promise<Response> {
  if (!env.PREVIEW_SESSIONS) return json({ error: "preview_disabled" }, 404);
  const previewId = normalizePreviewId(decodeURIComponent(rawPreviewId));
  if (previewId === null) return json({ error: "invalid_preview_id" }, 400);
  const inputUrl = new URL(request.url);
  const routedUrl = new URL(`https://coterm-preview.local${internalPath}${inputUrl.search}`);
  const stub = env.PREVIEW_SESSIONS.get(env.PREVIEW_SESSIONS.idFromName(previewId));
  return stub.fetch(new Request(routedUrl, request));
}

async function verifySessionShareSecret(
  env: CollaborationWorkerEnv,
  room: string,
  shareSecret: string,
): Promise<boolean> {
  const stub = env.COLLABORATION_SESSIONS.get(env.COLLABORATION_SESSIONS.idFromName(room));
  const response = await stub.fetch(new Request("https://coterm-collaboration-session.local/metadata", {
    method: "GET",
  }));
  if (!response.ok) return false;
  const body = await response.json() as { metadata?: { shareSecretHash?: unknown } };
  const expectedHash = typeof body.metadata?.shareSecretHash === "string" ? body.metadata.shareSecretHash : "";
  return expectedHash !== "" && expectedHash === await sha256Hex(shareSecret);
}

// Report whether a session's relay room still exists, so www can prune stale
// directory invites that point at a room whose Durable Object has been idle-swept.
// The room is addressed verbatim (as connect/create do via idFromName): code
// rooms are already normalized uppercase, and org-locked rooms ("org-<hex>")
// are not typeable codes and must not be run through normalizeSessionCode.
async function sessionLiveness(
  room: string,
  env: CollaborationWorkerEnv,
): Promise<Response> {
  const trimmed = room.trim();
  if (trimmed === "" || trimmed.length > 256) {
    return json({ error: "invalid_session_code" }, 400);
  }
  const stub = env.COLLABORATION_SESSIONS.get(
    env.COLLABORATION_SESSIONS.idFromName(trimmed),
  );
  try {
    const response = await stub.fetch(
      new Request("https://coterm-collaboration-session.local/metadata", {
        method: "GET",
      }),
    );
    return json({ active: response.ok });
  } catch {
    // Treat a probe failure as "unknown"; callers fail open rather than prune.
    return json({ error: "liveness_unavailable" }, 502);
  }
}

// Best-effort user identity: the inbox channel only nudges clients to refetch
// authoritative invites from www, so a spoofed userID at worst triggers a
// spurious refetch. Joining still requires an authenticated www grant.
function normalizeUserID(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  if (trimmed === "" || trimmed.length > 256) return null;
  return trimmed;
}

async function connectInbox(
  url: URL,
  request: Request,
  env: CollaborationWorkerEnv,
): Promise<Response> {
  if (!env.COLLABORATION_INBOX) return json({ error: "inbox_disabled" }, 404);
  const userID = normalizeUserID(url.searchParams.get("userID"));
  if (userID === null) return json({ error: "invalid_user" }, 400);
  const stub = env.COLLABORATION_INBOX.get(
    env.COLLABORATION_INBOX.idFromName(userID),
  );
  return stub.fetch(request);
}

async function notifyInbox(
  request: Request,
  env: CollaborationWorkerEnv,
): Promise<Response> {
  if (!env.COLLABORATION_INBOX) return json({ error: "inbox_disabled" }, 404);
  let inviteeUserId: string | null = null;
  let reason = "invite";
  try {
    const body = (await request.json()) as {
      inviteeUserId?: unknown;
      reason?: unknown;
    };
    inviteeUserId = normalizeUserID(
      typeof body?.inviteeUserId === "string" ? body.inviteeUserId : null,
    );
    if (typeof body?.reason === "string" && body.reason.trim() !== "") {
      reason = body.reason;
    }
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (inviteeUserId === null) return json({ error: "invalid_user" }, 400);
  const stub = env.COLLABORATION_INBOX.get(
    env.COLLABORATION_INBOX.idFromName(inviteeUserId),
  );
  const response = await stub.fetch(
    new Request("https://coterm-collaboration-inbox.local/notify", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ reason }),
    }),
  );
  const result = (await response.json()) as { delivered?: number };
  return json({ delivered: result.delivered ?? 0 }, 202);
}

async function createUniqueSession(
  env: CollaborationWorkerEnv,
): Promise<SessionCreateResponse> {
  while (true) {
    const sessionCode = randomSessionCode();
    const shareSecret = randomShareSecret();
    const stub = env.COLLABORATION_SESSIONS.get(
      env.COLLABORATION_SESSIONS.idFromName(sessionCode),
    );
    const result = await stub.create(sessionCode, shareSecret);
    if (result.created) return { ...result.metadata, shareSecret };
  }
}

async function recordIndexedSession(
  env: CollaborationWorkerEnv,
  metadata: SessionCreateResponse,
): Promise<void> {
  if (!env.COLLABORATION_SESSION_INDEX) return;
  const stub = env.COLLABORATION_SESSION_INDEX.get(
    env.COLLABORATION_SESSION_INDEX.idFromName(SESSION_INDEX_OBJECT_NAME),
  );
  try {
    await stub.fetch(
      new Request("https://coterm-collaboration-index.local/sessions", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          sessionID: metadata.sessionID,
          sessionCode: metadata.sessionCode,
        }),
      }),
    );
  } catch (error) {
    console.warn("failed to record collaboration session index", error);
  }
}

function requireAdminToken(
  request: Request,
  env: CollaborationWorkerEnv,
): Response | null {
  const expectedToken = env.COLLABORATION_ADMIN_TOKEN?.trim();
  if (!expectedToken) return json({ error: "admin_index_disabled" }, 404);
  const providedToken = request.headers.get("x-coterm-admin-token")?.trim();
  if (providedToken !== expectedToken) return json({ error: "forbidden" }, 403);
  return null;
}

async function listIndexedSessions(
  url: URL,
  env: CollaborationWorkerEnv,
): Promise<Response> {
  if (!env.COLLABORATION_SESSION_INDEX)
    return json({ error: "admin_index_disabled" }, 404);
  const stub = env.COLLABORATION_SESSION_INDEX.get(
    env.COLLABORATION_SESSION_INDEX.idFromName(SESSION_INDEX_OBJECT_NAME),
  );
  const indexURL = new URL("https://coterm-collaboration-index.local/sessions");
  indexURL.search = url.search;
  const response = await stub.fetch(new Request(indexURL, { method: "GET" }));
  const body = (await response.json()) as {
    sessions?: Array<Record<string, unknown>>;
    cursor?: string | null;
  };
  return json(
    {
      ...body,
      sessions: (body.sessions ?? []).map((session) => {
        const code =
          typeof session.sessionCode === "string"
            ? normalizeSessionCode(session.sessionCode)
            : null;
        return code === null
          ? session
          : {
              ...session,
              durableObjectID: durableObjectIDForSessionCode(env, code),
            };
      }),
    },
    response.status,
  );
}

async function describeSessionCode(
  rawCode: string,
  env: CollaborationWorkerEnv,
): Promise<Response> {
  const sessionCode = normalizeSessionCode(rawCode);
  if (sessionCode === null) return json({ error: "invalid_session_code" }, 400);
  const durableObjectID = durableObjectIDForSessionCode(env, sessionCode);
  const metadataResponse = await sessionMetadataResponse(env, sessionCode);
  const indexed = await indexedSessionRecord(env, sessionCode);
  if (metadataResponse.status === 404) {
    return json({
      sessionCode,
      durableObjectID,
      indexed: indexed !== null,
      active: false,
      metadata: null,
      indexedSession: indexed,
    });
  }
  if (!metadataResponse.ok) {
    return json(
      {
        sessionCode,
        durableObjectID,
        indexed: indexed !== null,
        active: false,
        metadata: null,
        indexedSession: indexed,
        error: "metadata_lookup_failed",
      },
      502,
    );
  }
  const body = (await metadataResponse.json()) as {
    metadata?: SessionCreateResponse;
  };
  return json({
    sessionCode,
    durableObjectID,
    indexed: indexed !== null,
    active: body.metadata !== undefined,
    metadata: body.metadata ?? null,
    indexedSession: indexed,
  });
}

function durableObjectIDForSessionCode(
  env: CollaborationWorkerEnv,
  sessionCode: string,
): string {
  return String(env.COLLABORATION_SESSIONS.idFromName(sessionCode));
}

async function sessionMetadataResponse(
  env: CollaborationWorkerEnv,
  sessionCode: string,
): Promise<Response> {
  const id = env.COLLABORATION_SESSIONS.idFromName(sessionCode);
  const stub = env.COLLABORATION_SESSIONS.get(id);
  return stub.fetch(
    new Request("https://coterm-collaboration-session.local/metadata", {
      method: "GET",
    }),
  );
}

async function indexedSessionRecord(
  env: CollaborationWorkerEnv,
  sessionCode: string,
): Promise<Record<string, unknown> | null> {
  if (!env.COLLABORATION_SESSION_INDEX) return null;
  const stub = env.COLLABORATION_SESSION_INDEX.get(
    env.COLLABORATION_SESSION_INDEX.idFromName(SESSION_INDEX_OBJECT_NAME),
  );
  const response = await stub.fetch(
    new Request("https://coterm-collaboration-index.local/sessions?limit=500", {
      method: "GET",
    }),
  );
  if (!response.ok) return null;
  const body = (await response.json()) as {
    sessions?: Array<Record<string, unknown>>;
  };
  return (
    (body.sessions ?? []).find(
      (session) => session.sessionCode === sessionCode,
    ) ?? null
  );
}
