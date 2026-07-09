// Full-chain smoke across all three workers (run scripts/dev-all.sh first):
//   create (control-plane) → connect (relay, grant-gated) → invite → inbox WS
//   nudge → reconcile → join. Exercises the byte-compat relay frames end to end.
//
//   bun scripts/smoke-e2e.ts
//
// Env:
//   MOSAIC_COLLAB_CONTROL_URL  (default http://localhost:8788)
//   MOSAIC_COLLABORATION_RELAY_URL (default http://localhost:8787)
//   COLLAB_AUTH_MODE           (default noauth)
//   COLLAB_AUTH_SECRET         (default dev-secret — used to mint client tokens)

import { signMosaicToken, nowSeconds } from "../packages/collab-auth/src/index";

const controlURL = (process.env.MOSAIC_COLLAB_CONTROL_URL ?? "http://localhost:8788").replace(/\/+$/, "");
const relayURL = (process.env.MOSAIC_COLLABORATION_RELAY_URL ?? "http://localhost:8787").replace(/\/+$/, "");
const secret = process.env.COLLAB_AUTH_SECRET ?? "dev-secret";
const timeoutMs = Number(process.env.MOSAIC_COLLAB_SMOKE_TIMEOUT_MS ?? "10000");

function fail(message: string): never {
  throw new Error(message);
}

async function token(userId: string): Promise<string> {
  // A mosaicv1 access token: verified in hmac mode, decoded (unverified) in noauth.
  return signMosaicToken(
    { kind: "access", userId, teamIds: [], selectedTeamId: null, exp: nowSeconds() + 900 },
    secret,
  );
}

async function api(path: string, userId: string, body?: unknown): Promise<Record<string, unknown>> {
  const headers: Record<string, string> = { authorization: `Bearer ${await token(userId)}` };
  if (body !== undefined) headers["content-type"] = "application/json";
  const response = await fetch(`${controlURL}${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) fail(`${path} failed: ${response.status} ${await response.text()}`);
  return (await response.json()) as Record<string, unknown>;
}

function relayWsURL(room: string, peerID: string, grant: string | null): string {
  const url = new URL(`${relayURL}/v1/collaboration/sessions/${room}/connect`);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.searchParams.set("peerID", peerID);
  url.searchParams.set("participantID", peerID);
  url.searchParams.set("displayName", `smoke-${peerID}`);
  url.searchParams.set("color", "#7A5CFF");
  if (grant) url.searchParams.set("grant", grant);
  return url.href;
}

class WS {
  private socket: WebSocket;
  private frames: Array<Record<string, unknown>> = [];
  constructor(url: string) {
    this.socket = new WebSocket(url);
    this.socket.addEventListener("message", (event) => {
      try {
        this.frames.push(JSON.parse(String(event.data)) as Record<string, unknown>);
      } catch {
        /* ignore non-JSON */
      }
    });
  }
  open(): Promise<void> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("ws open timeout")), timeoutMs);
      this.socket.addEventListener("open", () => { clearTimeout(timer); resolve(); }, { once: true });
      this.socket.addEventListener("error", () => { clearTimeout(timer); reject(new Error("ws error before open")); }, { once: true });
    });
  }
  send(frame: Record<string, unknown>): void {
    this.socket.send(JSON.stringify(frame));
  }
  waitFor(predicate: (f: Record<string, unknown>) => boolean, description: string): Promise<Record<string, unknown>> {
    const existing = this.frames.find(predicate);
    if (existing) return Promise.resolve(existing);
    return new Promise((resolve, reject) => {
      const timer = setInterval(() => {
        const match = this.frames.find(predicate);
        if (match) { clearInterval(timer); resolve(match); }
      }, 25);
      setTimeout(() => { clearInterval(timer); reject(new Error(`timeout waiting for ${description}`)); }, timeoutMs);
    });
  }
  close(): void {
    this.socket.close(1000, "smoke complete");
  }
}

async function preCreateRoom(): Promise<string> {
  // Mirror the real mosaic client: pre-create the room on the relay, then hand
  // the code to the control-plane. (In local wrangler dev, workerd cannot fetch
  // another local dev server over loopback, so the control-plane's own
  // preCreateRoom fallback is exercised only in production / unit tests.)
  const response = await fetch(`${relayURL}/v1/collaboration/sessions`, { method: "POST" });
  if (!response.ok) fail(`relay pre-create failed: ${response.status}`);
  const body = (await response.json()) as { sessionCode?: string };
  if (!body.sessionCode) fail(`relay pre-create returned no code: ${JSON.stringify(body)}`);
  return body.sessionCode;
}

async function main(): Promise<void> {
  // 1. Owner creates a session (client-precreated room, like the mosaic app).
  const preCode = await preCreateRoom();
  const created = await api("/api/collab/sessions", "owner", { orgId: "smoke", code: preCode, relayURL });
  const room = created.room as string;
  const session = created.session as string;
  const ownerGrant = created.grant as string;
  if (!room || !session || ownerGrant === undefined) fail(`sessions incomplete: ${JSON.stringify(created)}`);

  // 2. Owner connects to the relay with the grant.
  const owner = new WS(relayWsURL(room, "peer-a", ownerGrant || null));
  await owner.open();
  await owner.waitFor((f) => f.type === "session.joined", "owner session.joined");

  // 3. Guest joins (fresh grant) and connects.
  const joined = await api("/api/collab/join", "guest", { code: room });
  const guestGrant = joined.grant as string;
  const guest = new WS(relayWsURL(room, "peer-b", guestGrant || null));
  await guest.open();
  const guestJoined = await guest.waitFor((f) => f.type === "session.joined", "guest session.joined");
  const peers = guestJoined.peers;
  if (!Array.isArray(peers) || peers.length !== 2) fail(`expected 2 peers, got ${JSON.stringify(guestJoined)}`);

  // 4. A document.update from the owner reaches the guest with fromPeerID stamped.
  owner.send({ type: "document.update", documentID: "smoke-doc", updateID: "u", operations: [] });
  const forwarded = await guest.waitFor((f) => f.type === "document.update", "forwarded document.update");
  if (forwarded.fromPeerID !== "peer-a" || forwarded.documentID !== "smoke-doc") {
    fail(`unexpected forwarded frame: ${JSON.stringify(forwarded)}`);
  }

  // 5. Guest opens its inbox channel and gets the initial "connected" nudge.
  const inboxURL = new URL(`${relayURL}/v1/collaboration/inbox/connect`);
  inboxURL.protocol = inboxURL.protocol === "https:" ? "wss:" : "ws:";
  inboxURL.searchParams.set("userID", "guest");
  const inbox = new WS(inboxURL.href);
  await inbox.open();
  await inbox.waitFor((f) => f.type === "inbox.invite", "inbox connected nudge");

  // 6. Owner invites the guest. The real-time WS nudge is best-effort (needs the
  // control-plane to reach the relay inbox DO — a public URL in prod; not
  // reachable over loopback in local wrangler dev), so we don't hard-fail on it.
  await api("/api/collab/invite", "owner", { session, inviteeUserId: "guest", relayURL });
  try {
    await inbox.waitFor((f) => f.type === "inbox.invite" && f.reason === "invite", "invite nudge");
    console.log("  (invite WS nudge delivered)");
  } catch {
    console.log("  (invite WS nudge not delivered locally — expected under wrangler-dev loopback; verifying via GET /inbox)");
  }

  // 7. Guest lists and reconciles its inbox (the authoritative path).
  const list = await api("/api/collab/inbox", "guest");
  const invites = list.invites as unknown[];
  if (!Array.isArray(invites) || invites.length < 1) fail(`inbox empty: ${JSON.stringify(list)}`);
  const reconciled = await api("/api/collab/inbox/reconcile", "guest", {});
  const survivors = reconciled.invites as unknown[];
  if (!Array.isArray(survivors) || survivors.length < 1) fail(`reconcile dropped a live invite: ${JSON.stringify(reconciled)}`);

  owner.close();
  guest.close();
  inbox.close();
  console.log(`e2e smoke OK: room ${room}, control ${controlURL}, relay ${relayURL}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
