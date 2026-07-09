// Interactive two-user demo: simulate a shared terminal over the relay.
//
// HOST pre-creates a room, opens a shared terminal, and streams high-frequency
// terminal.output byte frames (like a real PTY tee). GUEST joins, mirrors the
// bytes (decoding base64) and prints the reconstructed stream, then sends a
// terminal.input back — exactly the collaboration data path, minus the app UI.
//
//   bun scripts/demo-two-clients.ts
//
// Env (same as smoke-e2e):
//   COTERM_COLLAB_CONTROL_URL         (default http://localhost:8788)
//   COTERM_COLLABORATION_RELAY_URL    (default http://localhost:8787)
//   COLLAB_AUTH_SECRET                (default dev-secret; used to mint tokens)

import { nowSeconds, signCotermToken } from "../packages/collab-auth/src/index";

const controlURL = (process.env.COTERM_COLLAB_CONTROL_URL ?? "http://localhost:8788").replace(/\/+$/, "");
const relayURL = (process.env.COTERM_COLLABORATION_RELAY_URL ?? "http://localhost:8787").replace(/\/+$/, "");
const secret = process.env.COLLAB_AUTH_SECRET ?? "dev-secret";
const OUTPUT_FRAMES = Number(process.env.DEMO_FRAMES ?? "40");

function fail(message: string): never {
  throw new Error(message);
}

async function token(userId: string): Promise<string> {
  return signCotermToken({ kind: "access", userId, teamIds: [], selectedTeamId: null, exp: nowSeconds() + 900 }, secret);
}

async function api(path: string, userId: string, body?: unknown): Promise<Record<string, unknown>> {
  const headers: Record<string, string> = { authorization: `Bearer ${await token(userId)}` };
  if (body !== undefined) headers["content-type"] = "application/json";
  const response = await fetch(`${controlURL}${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) fail(`${path} → ${response.status} ${await response.text()}`);
  return (await response.json()) as Record<string, unknown>;
}

async function preCreateRoom(): Promise<{ code: string; shareSecret: string | null }> {
  const r = await fetch(`${relayURL}/v1/collaboration/sessions`, { method: "POST" });
  if (!r.ok) fail(`relay pre-create → ${r.status}`);
  const body = (await r.json()) as { sessionCode: string; shareSecret?: string };
  return { code: body.sessionCode, shareSecret: body.shareSecret ?? null };
}

function wsURL(room: string, peerID: string, grant: string | null): string {
  const url = new URL(`${relayURL}/v1/collaboration/sessions/${room}/connect`);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.searchParams.set("peerID", peerID);
  url.searchParams.set("participantID", peerID);
  url.searchParams.set("displayName", peerID);
  url.searchParams.set("color", "#34C759");
  if (grant) url.searchParams.set("grant", grant);
  return url.href;
}

class Peer {
  private socket: WebSocket;
  onFrame: (f: Record<string, unknown>) => void = () => {};
  constructor(url: string) {
    this.socket = new WebSocket(url);
    this.socket.addEventListener("message", (e) => {
      try { this.onFrame(JSON.parse(String(e.data)) as Record<string, unknown>); } catch { /* ignore */ }
    });
  }
  open(): Promise<void> {
    if (this.socket.readyState === WebSocket.OPEN) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error("ws open timeout")), 8000);
      this.socket.addEventListener("open", () => { clearTimeout(t); resolve(); }, { once: true });
      this.socket.addEventListener("error", () => { clearTimeout(t); reject(new Error("ws error")); }, { once: true });
    });
  }
  send(f: Record<string, unknown>): void { this.socket.send(JSON.stringify(f)); }
  close(): void { this.socket.close(1000, "demo done"); }
}

const b64 = (s: string): string => Buffer.from(s, "utf8").toString("base64");
const unb64 = (s: string): string => Buffer.from(s, "base64").toString("utf8");
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

async function main(): Promise<void> {
  const precreated = await preCreateRoom();
  const room = precreated.code;
  const created = await api("/api/collab/sessions", "host", {
    orgId: "demo",
    code: room,
    relayURL,
    ...(precreated.shareSecret ? { shareSecret: precreated.shareSecret } : {}),
  });
  const shareSecret = created.shareSecret as string;
  const hostGrant = (created.grant as string) || null;
  const pending = await api("/api/collab/join", "guest", { code: room, shareSecret });
  const requestId = pending.requestId as string;
  await api("/api/collab/join-requests/approve", "host", { requestId });
  const claimed = await api("/api/collab/join-requests/claim", "guest", { room, requestId });
  const guestGrant = (claimed.grant as string) || null;
  console.log(`room = ${room}`);

  const terminalID = `${room}:terminal:00000000-0000-0000-0000-000000000000:11111111-1111-1111-1111-111111111111`;

  const host = new Peer(wsURL(room, "host", hostGrant));
  const guest = new Peer(wsURL(room, "guest", guestGrant));

  let received = 0;
  let bytes = 0;
  const startByFrame = new Map<number, number>();
  const latencies: number[] = [];
  let mirrored = "";
  const done = Promise.withResolvers<void>();

  guest.onFrame = (f) => {
    if (f.type === "terminal.output") {
      received += 1;
      const chunk = unb64(String(f.dataBase64));
      mirrored += chunk;
      bytes += chunk.length;
      const seq = Number(f.sequence);
      const t0 = startByFrame.get(seq);
      if (t0 !== undefined) latencies.push(Date.now() - t0);
      if (received === OUTPUT_FRAMES) {
        // Guest types something back into the host's authoritative PTY.
        guest.send({ type: "terminal.input", terminalID, inputID: "i1", dataBase64: b64("echo hi from guest\n"), fromPeerID: "guest" });
        done.resolve();
      }
    }
  };

  let guestInput = "";
  host.onFrame = (f) => {
    if (f.type === "terminal.input") guestInput = unb64(String(f.dataBase64));
  };

  await host.open();
  await guest.open();
  await sleep(150); // let both see session.joined

  // Host announces the shared terminal, then streams output at ~1ms cadence.
  host.send({ type: "terminal.open", terminalID, descriptor: { workspaceID: "00000000-0000-0000-0000-000000000000", surfaceID: "11111111-1111-1111-1111-111111111111", title: "demo" }, fromPeerID: "host" });

  const t0 = Date.now();
  for (let i = 0; i < OUTPUT_FRAMES; i += 1) {
    const seq = i + 1;
    startByFrame.set(seq, Date.now());
    host.send({ type: "terminal.output", terminalID, sequence: seq, dataBase64: b64(`line ${seq}\r\n`), fromPeerID: "host", caretPeerID: "host" });
    await sleep(1);
  }

  await Promise.race([done.promise, sleep(5000)]);
  const wall = Date.now() - t0;

  await sleep(100); // let the guest's input reach the host
  host.close();
  guest.close();

  const avg = latencies.length ? (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(2) : "n/a";
  const p95 = latencies.length ? [...latencies].sort((a, b) => a - b)[Math.floor(latencies.length * 0.95)] : "n/a";
  console.log("─".repeat(48));
  console.log(`host streamed : ${OUTPUT_FRAMES} terminal.output frames`);
  console.log(`guest mirrored: ${received} frames, ${bytes} bytes in ${wall}ms`);
  console.log(`relay latency : avg ${avg}ms, p95 ${p95}ms`);
  console.log(`guest→host input received by host: ${JSON.stringify(guestInput)}`);
  console.log("─".repeat(48));
  console.log("mirrored terminal content (first 3 lines):");
  console.log(mirrored.split("\r\n").slice(0, 3).map((l) => `  ${l}`).join("\n"));

  if (received !== OUTPUT_FRAMES) fail(`guest only mirrored ${received}/${OUTPUT_FRAMES} frames`);
  if (guestInput !== "echo hi from guest\n") fail("host did not receive guest input");
  console.log("\nDEMO OK — two users shared a terminal in real time.");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
