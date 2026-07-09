#!/usr/bin/env bun

const rawArgs = process.argv.slice(2);
if (rawArgs.includes("--help") || rawArgs.includes("-h")) {
  usage(0);
}
const args = parseArgs(rawArgs);

function usage(code = 1): never {
  const write = code === 0 ? console.log : console.error;
  write(`Usage:
  bun scripts/preview-host.ts --relay URL --room ROOM --share-secret SECRET --port PORT [--host 127.0.0.1] [--base-path /]

Example:
  bun scripts/preview-host.ts \\
    --relay https://coterm-relay.example.workers.dev \\
    --room ABCD1234 \\
    --share-secret "$COTERM_SHARE_SECRET" \\
    --port 3000
`);
  process.exit(code);
}

function parseArgs(values: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!value.startsWith("--")) usage();
    const key = value.slice(2);
    const next = values[index + 1];
    if (!next || next.startsWith("--")) usage();
    out[key] = next;
    index += 1;
  }
  return out;
}

function requireArg(name: string): string {
  const value = args[name]?.trim();
  if (!value) usage();
  return value;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function filteredHeaders(headers: Headers): Record<string, string> {
  const blocked = new Set([
    "connection",
    "content-length",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
  ]);
  const out: Record<string, string> = {};
  for (const [key, value] of headers) {
    if (!blocked.has(key.toLowerCase())) out[key] = value;
  }
  return out;
}

const relayURL = requireArg("relay").replace(/\/+$/, "");
const room = requireArg("room");
const shareSecret = requireArg("share-secret");
const port = Number(requireArg("port"));
const host = args.host?.trim() || "127.0.0.1";
const basePath = args["base-path"]?.trim() || "/";

if (!Number.isInteger(port) || port < 1 || port > 65535) usage();
if (host !== "127.0.0.1" && host !== "localhost") {
  throw new Error("preview host only supports 127.0.0.1 or localhost");
}

const createResponse = await fetch(`${relayURL}/v1/preview/sessions`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    room,
    shareSecret,
    target: { scheme: "http", host, port, basePath },
  }),
});

if (!createResponse.ok) {
  throw new Error(`create preview failed: ${createResponse.status} ${await createResponse.text()}`);
}

const created = await createResponse.json() as {
  previewId: string;
  hostToken: string;
  url: string;
};

const hostURL = new URL(`${relayURL}/v1/preview/sessions/${created.previewId}/host`);
hostURL.protocol = hostURL.protocol === "https:" ? "wss:" : "ws:";
hostURL.searchParams.set("token", created.hostToken);

console.log("Coterm preview online");
console.log(`Preview URL: ${created.url}`);
console.log(`Target: http://${host}:${port}${basePath}`);

const socket = new WebSocket(hostURL.href);

socket.addEventListener("open", () => {
  console.log("Host tunnel connected.");
});

socket.addEventListener("message", (event) => {
  void handleFrame(String(event.data)).catch((error) => {
    console.error(error);
  });
});

socket.addEventListener("close", (event) => {
  console.log(`Host tunnel closed: ${event.code} ${event.reason}`);
  process.exit(0);
});

socket.addEventListener("error", () => {
  console.error("Host tunnel error.");
});

async function handleFrame(raw: string): Promise<void> {
  const frame = JSON.parse(raw) as {
    type: string;
    requestId: string;
    method: string;
    path: string;
    query: string;
    headers: Record<string, string>;
    bodyBase64: string | null;
  };
  if (frame.type !== "preview.http.request") return;
  try {
    const localURL = new URL(`http://${host}:${port}${joinPath(basePath, frame.path)}${frame.query || ""}`);
    const response = await fetch(localURL, {
      method: frame.method,
      headers: frame.headers,
      body: frame.bodyBase64 === null ? undefined : base64ToBytes(frame.bodyBase64),
    });
    socket.send(JSON.stringify({
      type: "preview.http.response.head",
      requestId: frame.requestId,
      status: response.status,
      headers: filteredHeaders(response.headers),
    }));
    const bytes = new Uint8Array(await response.arrayBuffer());
    const chunkSize = 64 * 1024;
    for (let offset = 0; offset < bytes.byteLength; offset += chunkSize) {
      socket.send(JSON.stringify({
        type: "preview.http.response.chunk",
        requestId: frame.requestId,
        bodyBase64: bytesToBase64(bytes.slice(offset, offset + chunkSize)),
      }));
    }
    socket.send(JSON.stringify({
      type: "preview.http.response.end",
      requestId: frame.requestId,
    }));
  } catch (error) {
    socket.send(JSON.stringify({
      type: "preview.http.response.error",
      requestId: frame.requestId,
      message: String(error instanceof Error ? error.message : error),
    }));
  }
}

function joinPath(prefix: string, path: string): string {
  const cleanPrefix = prefix === "/" ? "" : prefix.replace(/\/+$/, "");
  const cleanPath = path.startsWith("/") ? path : `/${path}`;
  return `${cleanPrefix}${cleanPath}`;
}
