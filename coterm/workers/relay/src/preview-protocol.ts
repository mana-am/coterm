export interface PreviewTarget {
  scheme: "http";
  host: "127.0.0.1" | "localhost";
  port: number;
  basePath: string;
}

export interface PreviewMetadata {
  previewId: string;
  room: string;
  target: PreviewTarget;
  hostTokenHash: string;
  viewerTokenHash: string;
  createdAt: string;
  lastSeenAt: string;
}

export interface PreviewCreateRequest {
  previewId: string;
  room: string;
  target: PreviewTarget;
  hostToken: string;
  viewerToken: string;
}

export interface PreviewHttpRequestFrame {
  type: "preview.http.request";
  requestId: string;
  method: string;
  path: string;
  query: string;
  headers: Record<string, string>;
  bodyBase64: string | null;
}

export interface PreviewHttpResponseHeadFrame {
  type: "preview.http.response.head";
  requestId: string;
  status: number;
  headers: Record<string, string>;
}

export interface PreviewHttpResponseChunkFrame {
  type: "preview.http.response.chunk";
  requestId: string;
  bodyBase64: string;
}

export interface PreviewHttpResponseEndFrame {
  type: "preview.http.response.end";
  requestId: string;
}

export interface PreviewHttpResponseErrorFrame {
  type: "preview.http.response.error";
  requestId: string;
  message: string;
}

export type PreviewHostFrame =
  | PreviewHttpResponseHeadFrame
  | PreviewHttpResponseChunkFrame
  | PreviewHttpResponseEndFrame
  | PreviewHttpResponseErrorFrame;

export const PREVIEW_MAX_REQUEST_BODY_BYTES = 10 * 1024 * 1024;
export const PREVIEW_MAX_RESPONSE_BODY_BYTES = 50 * 1024 * 1024;
export const PREVIEW_REQUEST_TIMEOUT_MS = 20_000;
export const PREVIEW_IDLE_GRACE_MS = 10 * 60_000;

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,}$/;

export function normalizePreviewId(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  return /^p_[A-Za-z0-9]{8,64}$/.test(trimmed) ? trimmed : null;
}

export function normalizeToken(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  return TOKEN_PATTERN.test(trimmed) ? trimmed : null;
}

export function parsePreviewTarget(value: unknown): PreviewTarget | null {
  if (typeof value !== "object" || value === null) return null;
  const record = value as Record<string, unknown>;
  const scheme = typeof record.scheme === "string" ? record.scheme.trim().toLowerCase() : "http";
  const host = typeof record.host === "string" ? record.host.trim().toLowerCase() : "127.0.0.1";
  const port = typeof record.port === "number"
    ? record.port
    : typeof record.port === "string"
      ? Number(record.port)
      : NaN;
  const basePath = typeof record.basePath === "string"
    ? normalizeBasePath(record.basePath)
    : typeof record.path === "string"
      ? normalizeBasePath(record.path)
      : "/";
  if (scheme !== "http") return null;
  if (host !== "127.0.0.1" && host !== "localhost") return null;
  if (!Number.isInteger(port) || port < 1 || port > 65535) return null;
  return { scheme, host: host as PreviewTarget["host"], port, basePath };
}

function normalizeBasePath(value: string): string {
  const trimmed = value.trim();
  if (trimmed === "" || trimmed === "/") return "/";
  return trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function tokenMatchesHash(token: string, hash: string): Promise<boolean> {
  return await sha256Hex(token) === hash;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

export function filterRequestHeaders(headers: Headers): Record<string, string> {
  const blocked = new Set([
    "connection",
    "content-length",
    "host",
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

export function filterResponseHeaders(headers: Record<string, string>): Headers {
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
  const out = new Headers();
  for (const [key, value] of Object.entries(headers)) {
    if (!blocked.has(key.toLowerCase())) out.set(key, value);
  }
  return out;
}
