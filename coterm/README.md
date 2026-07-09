# Coterm

**Self-hostable, open-source, real-time collaboration for coding-agent terminals.**

Coterm is a free, self-hostable backend for multiplayer terminal / editor
collaboration — the "share a live session with a teammate" experience — that you
run yourself on Cloudflare's free tier instead of paying for a hosted service.

It's a faithful, wire-compatible reimplementation of the collaboration backend
used by the Mosaic/Coterm client (GPL-3.0), so a Coterm-style client can point
at your Coterm deployment unchanged. The realtime
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
| `packages/collab-auth` | Pluggable `CollabAuthProvider` (HMAC + local no-auth) + the `cotermv1` token codec, shared by all three workers. |
| `workers/relay` | Realtime WebSocket relay — session peers, opaque frame fan-out (terminal PTY bytes, CRDT ops, presence), per-user inbox nudges, session index. |
| `workers/control-plane` | The `/api/collab/*` REST surface (create session, join, invite, inbox, entitlements) + a per-user invite-store Durable Object. |
| `workers/presence` | Device / cursor presence + the `sync/v1` substrate. |

State lives entirely in Cloudflare Durable Objects — no database to run.

## Docs

- [Self-hosting guide](docs/self-hosting.md) — deploy, auth modes, custom domains, troubleshooting
- [Client setup](docs/client-setup.md) — point a client at your backend; offline guest mode
- [Preview sharing](docs/preview-sharing.md) — share a local web app through the self-hosted relay
- [Architecture](docs/architecture.md) — components, wire protocol, data flow
- [Contributing](CONTRIBUTING.md) — dev setup + the wire-compatibility rule

## Quick start: self-host on Cloudflare

This is the normal setup path for collaboration. It opens a Cloudflare browser
login once, deploys the three workers for you, checks that they are live, and
prints the three values your Coterm client needs. You do not need to create a
database, keep a server running, or understand the worker order.

Most first deploys are just these commands:

```bash
cd coterm
bun install
bunx wrangler login            # opens Cloudflare login, once
bun run deploy:self-host
```

For a copy-and-paste prompt you can hand to a coding agent, see
[instruction.md](instruction.md).

When it finishes, copy these values into Coterm's collaboration configuration
or keep them in your shell/app environment:

```text
COTERM_API_BASE_URL=...
COTERM_COLLABORATION_RELAY_URL=...
COTERM_PRESENCE_BASE_URL=...
```

Done: collaboration now runs in your Cloudflare account. Coterm does not provide
a hosted collaboration service; self-hosting is the product path.

Useful follow-ups:

```bash
bun run deploy:self-host -- --print-config  # reprint saved client values
bun run doctor:self-host                    # check an existing deployment
bun run context:self-host -- --format markdown
bun run configure:client -- --guest-id alice
```

`configure:client` writes the saved self-host URLs to `~/.coterm-dev.env`, which
DEBUG Coterm builds read even when launched from Finder, Dock, or a tagged app
link. `context:self-host` emits the same non-secret state as text, JSON,
Markdown, or shell exports so coding agents can understand the current backend
without re-discovering Cloudflare.

### Auth modes

Set `COLLAB_AUTH_MODE` on every worker:

- **`hmac`** (default): the control-plane mints short-lived, room-bound join grants signed
  with a shared `COLLAB_AUTH_SECRET` (the **same** secret on all three workers,
  e.g. `openssl rand -hex 32`); the relay verifies the grant before the WebSocket
  upgrade.
- **`noauth`**: local testing only. The relay still requires a control-plane
  grant, but that grant is unsigned and not a security boundary.

For a first deploy, use the default HMAC mode:

```bash
bun run deploy:self-host
```

Bring your own IdP by implementing `CollabAuthProvider`
(`packages/collab-auth/src/types.ts`).

## Local development

```bash
bun run dev:all          # relay :8787, control-plane :8788, presence :8789

# in another shell:
bun workers/relay/scripts/smoke-relay.ts   # relay smoke: create → 2 peers → forwarded frame
bun scripts/smoke-e2e.ts                    # full chain across all three workers
bun scripts/demo-two-clients.ts             # two users sharing a terminal + latency stats
bun scripts/collab-cli.ts host --name alice # interactive CLI: no login, id = --name
bun run preview:host -- --relay https://coterm-relay.<sub>.workers.dev --room ABCD1234 --share-secret "$COTERM_SHARE_SECRET" --port 3000
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

Coterm is open source under **GPL-3.0-or-later**, matching the coterm client it
interoperates with. The relay/presence workers are derived from Mosaic/Coterm
(© emergent.inc, GPL-3.0-or-later); the control plane and auth package are
original code. See `LICENSE` and `NOTICE`.
