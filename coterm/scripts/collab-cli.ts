// Minimal interactive collaboration CLI — no login, identity is just --name.
//
//   # terminal 1
//   bun scripts/collab-cli.ts host --name alice
//   → prints a share token, e.g.  Share token: 7QF3K2P9.<secret>
//
//   # terminal 2
//   bun scripts/collab-cli.ts join 7QF3K2P9.<secret> --name bob
//
// Then type lines in either terminal; both sides see each other's messages in
// real time, plus join/leave presence. Ctrl-C to quit.
//
// Env (all optional):
//   COTERM_COLLAB_CONTROL_URL       (default http://localhost:8788)
//   COTERM_COLLABORATION_RELAY_URL  (default http://localhost:8787)
//   COLLAB_AUTH_SECRET              (default dev-secret; used to mint the token)

import { createInterface } from "node:readline";
import { nowSeconds, signCotermToken } from "../packages/collab-auth/src/index";

const controlURL = (process.env.COTERM_COLLAB_CONTROL_URL ?? "http://localhost:8788").replace(/\/+$/, "");
const relayURL = (process.env.COTERM_COLLABORATION_RELAY_URL ?? "http://localhost:8787").replace(/\/+$/, "");
const secret = process.env.COLLAB_AUTH_SECRET ?? "dev-secret";

function usage(): never {
  console.error("usage: collab-cli.ts <host | join <CODE.SECRET>> --name <name>");
  process.exit(1);
}

function parseArgs(): { mode: "host" | "join"; code: string | null; name: string } {
  const args = process.argv.slice(2);
  const nameIndex = args.indexOf("--name");
  const name = nameIndex >= 0 ? args[nameIndex + 1] : "";
  if (!name) usage();
  const mode = args[0];
  if (mode === "host") return { mode: "host", code: null, name };
  if (mode === "join") {
    const code = args[1];
    if (!code || code === "--name") usage();
    return { mode: "join", code, name };
  }
  return usage();
}

async function tokenFor(name: string): Promise<string> {
  return signCotermToken({ kind: "access", userId: name, teamIds: [], selectedTeamId: null, exp: nowSeconds() + 24 * 3600 }, secret);
}

async function api(path: string, name: string, body: unknown): Promise<Record<string, unknown>> {
  const response = await fetch(`${controlURL}${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${await tokenFor(name)}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`${path} → ${response.status} ${await response.text()}`);
  return (await response.json()) as Record<string, unknown>;
}

function parseShareToken(value: string): { code: string; shareSecret: string } {
  const [code, shareSecret] = value.split(".", 2);
  if (!code || !shareSecret) throw new Error("join requires a full CODE.SECRET share token");
  return { code, shareSecret };
}

async function preCreateRoom(): Promise<{ code: string; shareSecret: string | null }> {
  const r = await fetch(`${relayURL}/v1/collaboration/sessions`, { method: "POST" });
  if (!r.ok) throw new Error(`relay pre-create → ${r.status}`);
  const body = (await r.json()) as { sessionCode: string; shareSecret?: string };
  return { code: body.sessionCode, shareSecret: body.shareSecret ?? null };
}

function connectURL(room: string, name: string, grant: string | null): string {
  const url = new URL(`${relayURL}/v1/collaboration/sessions/${room}/connect`);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.searchParams.set("peerID", `${name}-${process.pid}`);
  url.searchParams.set("participantID", name);
  url.searchParams.set("displayName", name);
  url.searchParams.set("color", "#7A5CFF");
  if (grant) url.searchParams.set("grant", grant);
  return url.href;
}

async function main(): Promise<void> {
  const { mode, code, name } = parseArgs();

  let room: string;
  let grant: string | null;
  if (mode === "host") {
    const precreated = await preCreateRoom();
    room = precreated.code;
    const created = await api("/api/collab/sessions", name, {
      orgId: "cli",
      code: room,
      relayURL,
      ...(precreated.shareSecret ? { shareSecret: precreated.shareSecret } : {}),
    });
    const shareSecret = (created.shareSecret as string) || precreated.shareSecret;
    grant = (created.grant as string) || null;
    console.log(`\n  Room code: ${room}`);
    console.log(`  Share token: ${room}.${shareSecret}`);
    console.log(`  Share it:  bun scripts/collab-cli.ts join ${room}.${shareSecret} --name <you>`);
    console.log("  Join requests require owner approval before the guest can connect.\n");
  } else {
    const token = parseShareToken(code ?? "");
    const pending = await api("/api/collab/join", name, token);
    console.log(`\n  Join request ${pending.requestId} is pending for room ${pending.room}.`);
    console.log("  Ask the room owner to approve it, then connect from a Coterm client.\n");
    return;
  }

  const roster = new Map<string, string>(); // peerID → displayName
  const socket = new WebSocket(connectURL(room, name, grant));

  const print = (line: string): void => {
    process.stdout.write(`\r\x1b[K${line}\n${name}> `);
  };

  socket.addEventListener("message", (event) => {
    let frame: Record<string, unknown>;
    try { frame = JSON.parse(String(event.data)) as Record<string, unknown>; } catch { return; }
    switch (frame.type) {
      case "session.joined": {
        const peers = (frame.peers as Array<{ peerID: string; displayName: string }>) ?? [];
        for (const p of peers) roster.set(p.peerID, p.displayName);
        const others = peers.map((p) => p.displayName).filter((n) => n !== name);
        print(`• in room: ${others.length ? others.join(", ") : "(just you)"}`);
        break;
      }
      case "peer.joined": {
        const p = frame.peer as { peerID: string; displayName: string };
        roster.set(p.peerID, p.displayName);
        print(`→ ${p.displayName} joined`);
        break;
      }
      case "peer.left": {
        const dn = roster.get(String(frame.peerID)) ?? "someone";
        roster.delete(String(frame.peerID));
        print(`← ${dn} left`);
        break;
      }
      case "message": {
        print(`${frame.fromName ?? "?"}> ${frame.text}`);
        break;
      }
    }
  });

  socket.addEventListener("close", (e) => {
    console.log(`\n[disconnected: ${e.code} ${e.reason}]`);
    process.exit(0);
  });

  await new Promise<void>((resolve, reject) => {
    socket.addEventListener("open", () => resolve(), { once: true });
    socket.addEventListener("error", () => reject(new Error("ws error")), { once: true });
  });

  // Heartbeat so the relay does not expire us (30s window).
  const heartbeat = setInterval(() => socket.send(JSON.stringify({ type: "peer.heartbeat" })), 10_000);

  const rl = createInterface({ input: process.stdin, output: process.stdout, prompt: `${name}> ` });
  rl.prompt();
  rl.on("line", (line) => {
    const text = line.trim();
    if (text) socket.send(JSON.stringify({ type: "message", text, fromName: name }));
    rl.prompt();
  });
  rl.on("close", () => {
    clearInterval(heartbeat);
    socket.close(1000, "bye");
    process.exit(0);
  });
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
