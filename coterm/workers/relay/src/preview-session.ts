import { DurableObject } from "cloudflare:workers";
import { json } from "./protocol";
import {
  base64ToBytes,
  bytesToBase64,
  filterRequestHeaders,
  filterResponseHeaders,
  normalizeToken,
  PREVIEW_IDLE_GRACE_MS,
  PREVIEW_MAX_REQUEST_BODY_BYTES,
  PREVIEW_MAX_RESPONSE_BODY_BYTES,
  PREVIEW_REQUEST_TIMEOUT_MS,
  sha256Hex,
  tokenMatchesHash,
  type PreviewCreateRequest,
  type PreviewHostFrame,
  type PreviewHttpRequestFrame,
  type PreviewMetadata,
} from "./preview-protocol";

const METADATA_KEY = "metadata";
const IDLE_CLEANUP_DUE_AT_KEY = "idleCleanupDueAt";

interface PendingProxyRequest {
  resolve(response: Response): void;
  reject(error: Error): void;
  timeout: ReturnType<typeof setTimeout>;
  chunks: Uint8Array[];
  receivedBytes: number;
  status: number | null;
  headers: Record<string, string>;
}

export class PreviewSessionObject extends DurableObject {
  private metadata: PreviewMetadata | null = null;
  private hostSocket: WebSocket | null = null;
  private pending = new Map<string, PendingProxyRequest>();

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/create" && request.method === "POST") {
      return this.handleCreate(request);
    }
    if (url.pathname === "/host" && request.method === "GET") {
      return this.handleHostConnect(request);
    }
    if (url.pathname === "/metadata" && request.method === "GET") {
      return this.handleMetadata(url);
    }
    if (url.pathname.startsWith("/proxy/")) {
      return this.handleProxy(url, request);
    }
    if (url.pathname === "/close" && request.method === "DELETE") {
      return this.handleClose(url);
    }
    return json({ error: "not_found" }, 404);
  }

  override async alarm(): Promise<void> {
    const metadata = await this.loadMetadata();
    if (metadata === null) return;
    if (this.hostSocket !== null || this.pending.size > 0) {
      await this.ctx.storage.setAlarm(Date.now() + PREVIEW_IDLE_GRACE_MS);
      return;
    }
    const dueAt = await this.ctx.storage.get<number>(IDLE_CLEANUP_DUE_AT_KEY);
    if (dueAt !== undefined && Date.now() >= dueAt) {
      await this.deletePreview();
      return;
    }
    await this.scheduleIdleCleanup();
  }

  private async handleCreate(request: Request): Promise<Response> {
    const existing = await this.loadMetadata();
    if (existing !== null) return json({ error: "preview_exists" }, 409);
    let body: PreviewCreateRequest;
    try {
      body = await request.json() as PreviewCreateRequest;
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    if (!body.previewId || !body.room || !body.hostToken || !body.viewerToken || !body.target) {
      return json({ error: "invalid_request" }, 400);
    }
    const now = new Date().toISOString();
    const metadata: PreviewMetadata = {
      previewId: body.previewId,
      room: body.room,
      target: body.target,
      hostTokenHash: await sha256Hex(body.hostToken),
      viewerTokenHash: await sha256Hex(body.viewerToken),
      createdAt: now,
      lastSeenAt: now,
    };
    await this.ctx.storage.put(METADATA_KEY, metadata);
    this.metadata = metadata;
    await this.scheduleIdleCleanup();
    return json({ ok: true, metadata }, 201);
  }

  private async handleHostConnect(request: Request): Promise<Response> {
    if (request.headers.get("upgrade")?.toLowerCase() !== "websocket") {
      return json({ error: "expected_websocket" }, 426);
    }
    const metadata = await this.loadMetadata();
    if (metadata === null) return json({ error: "preview_not_found" }, 404);
    const url = new URL(request.url);
    const token = normalizeToken(url.searchParams.get("token"));
    if (token === null || !(await tokenMatchesHash(token, metadata.hostTokenHash))) {
      return json({ error: "forbidden" }, 403);
    }

    this.hostSocket?.close(1012, "host replaced");
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    server.accept();
    this.hostSocket = server;
    await this.touch();
    await this.ctx.storage.delete(IDLE_CLEANUP_DUE_AT_KEY);
    server.addEventListener("message", (event) => this.handleHostMessage(event.data));
    server.addEventListener("close", () => this.dropHost("host disconnected"));
    server.addEventListener("error", () => this.dropHost("host error"));
    return new Response(null, { status: 101, webSocket: client });
  }

  private async handleMetadata(url: URL): Promise<Response> {
    const metadata = await this.loadMetadata();
    if (metadata === null) return json({ error: "preview_not_found" }, 404);
    const token = normalizeToken(url.searchParams.get("token") ?? url.searchParams.get("t"));
    if (token === null || !(await tokenMatchesHash(token, metadata.viewerTokenHash))) {
      return json({ error: "forbidden" }, 403);
    }
    return json({
      previewId: metadata.previewId,
      room: metadata.room,
      target: metadata.target,
      hostOnline: this.hostSocket !== null,
      createdAt: metadata.createdAt,
      lastSeenAt: metadata.lastSeenAt,
    });
  }

  private async handleProxy(url: URL, request: Request): Promise<Response> {
    const metadata = await this.loadMetadata();
    if (metadata === null) return json({ error: "preview_not_found" }, 404);
    const token = normalizeToken(url.searchParams.get("token") ?? url.searchParams.get("t"));
    if (token === null || !(await tokenMatchesHash(token, metadata.viewerTokenHash))) {
      return json({ error: "forbidden" }, 403);
    }
    if (this.hostSocket === null) return json({ error: "host_offline" }, 503);

    const body = await this.readRequestBody(request);
    if (body instanceof Response) return body;

    const requestId = crypto.randomUUID();
    const frame: PreviewHttpRequestFrame = {
      type: "preview.http.request",
      requestId,
      method: request.method,
      path: this.proxyPath(url),
      query: this.proxyQuery(url),
      headers: filterRequestHeaders(request.headers),
      bodyBase64: body === null ? null : bytesToBase64(body),
    };
    return this.sendProxyRequest(requestId, frame)
      .then((response) => this.withViewerCookie(response, metadata.previewId, token));
  }

  private async handleClose(url: URL): Promise<Response> {
    const metadata = await this.loadMetadata();
    if (metadata === null) return json({ ok: true, deleted: false });
    const token = normalizeToken(url.searchParams.get("token"));
    if (token === null || !(await tokenMatchesHash(token, metadata.hostTokenHash))) {
      return json({ error: "forbidden" }, 403);
    }
    await this.deletePreview();
    return json({ ok: true, deleted: true });
  }

  private async readRequestBody(request: Request): Promise<Uint8Array | null | Response> {
    if (request.method === "GET" || request.method === "HEAD") return null;
    const bytes = new Uint8Array(await request.arrayBuffer());
    if (bytes.byteLength > PREVIEW_MAX_REQUEST_BODY_BYTES) {
      return json({ error: "request_too_large" }, 413);
    }
    return bytes;
  }

  private sendProxyRequest(requestId: string, frame: PreviewHttpRequestFrame): Promise<Response> {
    return new Promise<Response>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(requestId);
        reject(new Error("preview request timed out"));
      }, PREVIEW_REQUEST_TIMEOUT_MS);
      this.pending.set(requestId, {
        resolve,
        reject,
        timeout,
        chunks: [],
        receivedBytes: 0,
        status: null,
        headers: {},
      });
      this.hostSocket?.send(JSON.stringify(frame));
    }).catch((error) => json({ error: "preview_unavailable", message: String(error?.message ?? error) }, 504));
  }

  private handleHostMessage(message: string | ArrayBuffer): void {
    const frame = this.parseHostFrame(message);
    if (frame === null) {
      this.hostSocket?.close(1003, "invalid preview frame");
      this.dropHost("invalid frame");
      return;
    }
    const pending = this.pending.get(frame.requestId);
    if (!pending) return;
    if (frame.type === "preview.http.response.head") {
      pending.status = frame.status;
      pending.headers = frame.headers;
      return;
    }
    if (frame.type === "preview.http.response.chunk") {
      const chunk = base64ToBytes(frame.bodyBase64);
      pending.receivedBytes += chunk.byteLength;
      if (pending.receivedBytes > PREVIEW_MAX_RESPONSE_BODY_BYTES) {
        this.finishPending(frame.requestId, json({ error: "response_too_large" }, 502));
        return;
      }
      pending.chunks.push(chunk);
      return;
    }
    if (frame.type === "preview.http.response.error") {
      this.failPending(frame.requestId, new Error(frame.message || "host preview error"));
      return;
    }
    const body = this.joinChunks(pending.chunks);
    const arrayBuffer = body.buffer.slice(body.byteOffset, body.byteOffset + body.byteLength) as ArrayBuffer;
    this.finishPending(frame.requestId, new Response(arrayBuffer, {
      status: pending.status ?? 200,
      headers: filterResponseHeaders(pending.headers),
    }));
  }

  private parseHostFrame(message: string | ArrayBuffer): PreviewHostFrame | null {
    const text = typeof message === "string" ? message : new TextDecoder().decode(message);
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return null;
    }
    if (typeof parsed !== "object" || parsed === null) return null;
    const record = parsed as Record<string, unknown>;
    if (typeof record.type !== "string" || typeof record.requestId !== "string") return null;
    if (record.type === "preview.http.response.head") {
      if (typeof record.status !== "number" || typeof record.headers !== "object" || record.headers === null) return null;
      return record as unknown as PreviewHostFrame;
    }
    if (record.type === "preview.http.response.chunk") {
      return typeof record.bodyBase64 === "string" ? record as unknown as PreviewHostFrame : null;
    }
    if (record.type === "preview.http.response.end") return record as unknown as PreviewHostFrame;
    if (record.type === "preview.http.response.error") {
      return typeof record.message === "string" ? record as unknown as PreviewHostFrame : null;
    }
    return null;
  }

  private finishPending(requestId: string, response: Response): void {
    const pending = this.pending.get(requestId);
    if (!pending) return;
    clearTimeout(pending.timeout);
    this.pending.delete(requestId);
    pending.resolve(response);
    this.ctx.waitUntil(this.touch());
  }

  private failPending(requestId: string, error: Error): void {
    const pending = this.pending.get(requestId);
    if (!pending) return;
    clearTimeout(pending.timeout);
    this.pending.delete(requestId);
    pending.reject(error);
  }

  private dropHost(reason: string): void {
    this.hostSocket = null;
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timeout);
      pending.reject(new Error(reason));
      this.pending.delete(requestId);
    }
    this.ctx.waitUntil(this.scheduleIdleCleanup());
  }

  private async loadMetadata(): Promise<PreviewMetadata | null> {
    if (this.metadata !== null) return this.metadata;
    this.metadata = await this.ctx.storage.get<PreviewMetadata>(METADATA_KEY) ?? null;
    return this.metadata;
  }

  private async touch(): Promise<void> {
    const metadata = await this.loadMetadata();
    if (metadata === null) return;
    metadata.lastSeenAt = new Date().toISOString();
    await this.ctx.storage.put(METADATA_KEY, metadata);
  }

  private async scheduleIdleCleanup(): Promise<void> {
    const dueAt = Date.now() + PREVIEW_IDLE_GRACE_MS;
    await this.ctx.storage.put(IDLE_CLEANUP_DUE_AT_KEY, dueAt);
    await this.ctx.storage.setAlarm(dueAt);
  }

  private async deletePreview(): Promise<void> {
    this.hostSocket?.close(1000, "preview closed");
    this.hostSocket = null;
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timeout);
      pending.reject(new Error("preview closed"));
      this.pending.delete(requestId);
    }
    await this.ctx.storage.delete(METADATA_KEY);
    await this.ctx.storage.delete(IDLE_CLEANUP_DUE_AT_KEY);
    this.metadata = null;
  }

  private proxyPath(url: URL): string {
    const rawPath = url.pathname.replace(/^\/proxy/, "") || "/";
    return rawPath.startsWith("/") ? rawPath : `/${rawPath}`;
  }

  private proxyQuery(url: URL): string {
    const query = new URLSearchParams(url.searchParams);
    query.delete("token");
    query.delete("t");
    const value = query.toString();
    return value ? `?${value}` : "";
  }

  private joinChunks(chunks: Uint8Array[]): Uint8Array {
    const total = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);
    const out = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      out.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return out;
  }

  private withViewerCookie(response: Response, previewId: string, token: string): Response {
    const headers = new Headers(response.headers);
    headers.append(
      "set-cookie",
      `coterm_preview=${encodeURIComponent(`${previewId}.${token}`)}; Path=/; HttpOnly; SameSite=Lax; Secure`,
    );
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  }
}
