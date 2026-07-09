# Coterm

**Self-hostable, open-source, real-time collaboration for coding-agent terminals.**

Coterm is a free, self-hostable backend for multiplayer terminal / editor
collaboration — the "share a live session with a teammate" experience — that you
run yourself on Cloudflare's free tier instead of paying for a hosted service.

It's a faithful, wire-compatible reimplementation of the collaboration backend
used by the [mosaic](https://github.com/emergent-inc/mosaic) client (GPL-3.0), so
a mosaic-style client can point at your Coterm deployment unchanged. The realtime
core (relay, presence) is a 1:1 port; the control plane (session/invite/join) is
reimplemented from the client's observable wire contract, with the closed
Clerk + Stripe + Stack pieces replaced by a small **pluggable auth interface**.

> **Free software, not free hosting.** The code is free and the architecture runs
> on Cloudflare's free tier, so each user self-hosts for ~$0. Nobody has to run a
> paid central service.

## What's inside

Three Cloudflare Workers + one shared package:

| Package | Role |
|---|---|
| `packages/collab-auth` | Pluggable `CollabAuthProvider` (HMAC + no-auth) + the `mosaicv1` token codec, shared by all three workers. |
| `workers/relay` | Realtime WebSocket relay — session peers, opaque frame fan-out (terminal PTY bytes, CRDT ops, presence), per-user inbox nudges, session index. |
| `workers/control-plane` | The `/api/collab/*` REST surface (create session, join, invite, inbox, entitlements) + a per-user invite-store Durable Object. |
| `workers/presence` | Device / cursor presence + the `sync/v1` substrate. |

State lives entirely in Cloudflare Durable Objects — no database to run.

## Docs

- [Self-hosting guide](docs/self-hosting.md) — deploy, auth modes, custom domains, troubleshooting
- [Client setup](docs/client-setup.md) — point a client at your backend; offline guest mode
- [Architecture](docs/architecture.md) — components, wire protocol, data flow
- [Contributing](CONTRIBUTING.md) — dev setup + the wire-compatibility rule

## Quick start: self-host on Cloudflare

Requires [Bun](https://bun.sh) and a (free) Cloudflare account.

```bash
cd coterm
bun install
bunx wrangler login            # browser auth, once

# 1. Deploy the relay, note its printed *.workers.dev URL
cd workers/relay && bunx wrangler deploy
```

Put that relay URL into `workers/control-plane/wrangler.toml` under
`[vars] COLLAB_RELAY_URL`, then:

```bash
cd ../control-plane && bunx wrangler deploy
cd ../presence && bunx wrangler deploy
```

Point your client's API base URL at the control-plane's URL. Done — you're
running your own collaboration backend for free.

### Auth modes

Set `COLLAB_AUTH_MODE` on every worker:

- **`noauth`** (default): knowing the session code is the only gate. Identity is
  best-effort (a chosen name). Zero config — great for trusted groups and getting
  started.
- **`hmac`**: the control-plane mints short-lived, room-bound join grants signed
  with a shared `COLLAB_AUTH_SECRET` (the **same** secret on all three workers,
  e.g. `openssl rand -hex 32`); the relay verifies the grant before the WebSocket
  upgrade.

Bring your own IdP by implementing `CollabAuthProvider`
(`packages/collab-auth/src/types.ts`).

## Local development

```bash
bun run dev:all          # relay :8787, control-plane :8788, presence :8789 (noauth)

# in another shell:
bun workers/relay/scripts/smoke-relay.ts   # relay smoke: create → 2 peers → forwarded frame
bun scripts/smoke-e2e.ts                    # full chain across all three workers
bun scripts/demo-two-clients.ts             # two users sharing a terminal + latency stats
bun scripts/collab-cli.ts host --name alice # interactive CLI: no login, id = --name
```

> Under `wrangler dev`, one local worker cannot fetch another over loopback, so
> the control-plane's calls to the relay don't complete locally; the scripts
> mirror the real client (pre-create the room on the relay, verify via
> `GET /api/collab/inbox`). In production every worker has a public URL, so all
> cross-worker calls work.

## Tests

```bash
bun test           # 248 tests across all packages
bun run typecheck  # every package
```

## License

Coterm is open source under **GPL-3.0-or-later**, matching the mosaic client it
interoperates with. The relay/presence workers are derived from mosaic
(© emergent.inc, GPL-3.0); the control plane and auth package are original code.
See `LICENSE`. This project is not affiliated with or endorsed by emergent.inc,
and "mosaic" is their trademark — Coterm is an independent, rebranded fork.
