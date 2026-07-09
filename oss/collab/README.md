# mosaic OSS collaboration server

An open-source, self-hostable, **1:1 port** of the mosaic real-time collaboration
backend — the pieces that let two (or N) users share a live terminal / editor
session. Built for a multiplayer codex + claude-code style experience.

It reproduces the upstream server behavior faithfully (same wire protocol, same
Durable Object model, same timeouts/GC), while replacing the closed
Clerk + Stripe + Stack Auth control plane with a small **pluggable auth
interface** (default: shared-secret HMAC, or fully open "session code only").

## What's here

Three Cloudflare Workers + one shared package:

| Package | Role |
|---|---|
| `packages/collab-auth` | The pluggable `CollabAuthProvider` (HMAC + no-auth impls) + the `mosaicv1` token codec, shared by all three workers. |
| `workers/relay` | The realtime relay — 1:1 port of `workers/collaboration`. WebSocket frame fan-out (terminal PTY bytes, CRDT ops, presence), per-user inbox nudges, session index. Adds one join-grant gate on `/connect`. |
| `workers/control-plane` | The `/api/collab/*` REST surface the client talks to (create session, join, invite, inbox, entitlements). **Reconstructed** — it does not exist in the upstream repo (it lived in a closed www service). Stores invites in a per-user Durable Object. |
| `workers/presence` | Device/cursor presence + the `sync/v1` substrate — port of `workers/presence` with Stack Auth swapped for the provider. |

### Byte-compatibility

The relay forwards app frames opaquely, so the existing mosaic macOS client (and
your own codex/claude clients) can talk to this server unchanged. The parts that
must match the client exactly are all preserved: the `/v1/collaboration/...`
connect URL + query params, the control frames the relay emits (`session.joined`,
`peer.joined`, `peer.update`, `peer.left`, `inbox.invite`), the `fromPeerID` /
`receivedAt` injection on forwarded frames, and the `/api/collab/*` response
shapes. The `mosaicv1` HMAC token is byte-identical to the upstream Node
implementation (cross-checked in `packages/collab-auth/test/hmac.test.ts`).

## Auth modes

Set `COLLAB_AUTH_MODE` on every worker:

- **`noauth`** (default): knowing the session code is the only gate — exactly the
  relay's upstream Phase-1 threat model. Identity is best-effort (decoded from the
  client's bearer token if present, else `?userId=` / `x-mosaic-user-id` / `anon`).
  Zero config. Good for trusted networks and local dev.
- **`hmac`**: the control-plane mints short-lived, room-bound **join grants** and
  signed **session descriptors** with a shared `COLLAB_AUTH_SECRET`; the relay
  verifies the grant before the WebSocket upgrade. The same secret verifies the
  `mosaicv1` access tokens the client sends. **The same secret must be set on all
  three workers.** Generate one with `openssl rand -hex 32`.

Bring your own IdP by implementing `CollabAuthProvider` (see
`packages/collab-auth/src/types.ts`) and wiring it in `factory.ts`.

## End-to-end flow (hmac mode)

```
create  →  POST /api/collab/sessions   → { session (signed), room, grant, relayURL, entitlements }
connect →  wss://relay/v1/collaboration/sessions/<room>/connect?...&grant=<grant>
           relay verifies grant (signature + room binding + exp) → 101, session.joined
invite  →  POST /api/collab/invite { session, inviteeUserId }
           → persists invite in the invitee's InviteStore DO
           → nudges the invitee's live inbox sockets (inbox.invite)
inbox   →  GET  /api/collab/inbox                → { invites: [...] }
reconcile→ POST /api/collab/inbox/reconcile      → probes each room, prunes ended sessions
join    →  POST /api/collab/join { session | code } → fresh room-bound grant
withdraw→  POST /api/collab/withdraw { session, inviteeUserId }
```

## Local development

Requires [Bun](https://bun.sh). From this directory:

```bash
bun install

# Boot all three workers (relay :8787, control-plane :8788, presence :8789).
# Defaults to noauth (zero config):
bun run dev:all

# hmac mode instead:
COLLAB_AUTH_MODE=hmac COLLAB_AUTH_SECRET=$(openssl rand -hex 32) bun run dev:all
```

Then, in another shell:

```bash
# Relay-only smoke (noauth): create → 2 peers → forwarded frame
bun workers/relay/scripts/smoke-relay.ts

# Full chain across all three workers:
bun scripts/smoke-e2e.ts
# hmac: COLLAB_AUTH_SECRET=<same secret> bun scripts/smoke-e2e.ts
```

> **wrangler-dev loopback note:** under `wrangler dev`, workerd cannot fetch
> another local dev server over loopback, so the control-plane's calls to the
> relay (room pre-create, inbox notify, liveness probe) don't reach it locally.
> The e2e mirrors the real mosaic client — it pre-creates the room on the relay
> and passes the `code` — and verifies invites via the authoritative
> `GET /api/collab/inbox`. In production every worker uses a public URL, so all
> cross-worker calls work.

## Tests & typecheck

```bash
bun test                 # all packages (248 tests)
bun run typecheck        # every package
```

## Deploy

Each worker is an independent Cloudflare Worker. From its directory:

```bash
cd workers/relay          # or control-plane / presence
bunx wrangler deploy
# hmac mode: set the shared secret once per worker
echo -n "<secret>" | bunx wrangler secret put COLLAB_AUTH_SECRET
```

Set `COLLAB_AUTH_MODE` and (for the control-plane) `COLLAB_RELAY_URL` /
`COLLAB_AUTH_MODE` in each worker's `wrangler.toml` `[vars]`, and point your
client's relay + API base URLs at the deployed workers.

## What was dropped vs. upstream

| Upstream dependency | Replacement |
|---|---|
| Clerk identity / sign-in | Verify externally-issued `mosaicv1` tokens with a shared secret (hmac), or best-effort identity (noauth). No sign-in UI. |
| Stripe plan gating | Static hobby entitlements (`{plan, directorySharing, codesEnabled}`); no billing. |
| Stack Auth (presence) | `CollabAuthProvider.authenticateRequest`; no `api.stack-auth.com` calls. |
| Org directory from Clerk/Stack | `resolveDirectory` (empty by default; pluggable). |
| Production custom domains | Removed; self-hoster sets their own URLs. |
