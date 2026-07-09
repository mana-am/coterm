# Contributing to Coterm

Thanks for helping build a free, self-hostable collaboration backend.

## Dev setup

Requires [Bun](https://bun.sh) (≥ 1.3).

```bash
bun install
bun test           # 248 tests across all packages
bun run typecheck  # every package
bun run dev:all    # relay :8787, control-plane :8788, presence :8789 (noauth)
```

Handy scripts (run against `dev:all` or a deployed backend):

```bash
bun workers/relay/scripts/smoke-relay.ts     # relay: create → 2 peers → forwarded frame
bun scripts/smoke-e2e.ts                      # full chain across all three workers
bun scripts/demo-two-clients.ts               # two users sharing a terminal + latency
bun scripts/collab-cli.ts host --name alice   # interactive CLI, id = --name
```

## Project layout

```
packages/collab-auth   shared pluggable auth (HMAC + no-auth) + mosaicv1 token codec
workers/relay          realtime WebSocket relay (session peers, frame fan-out, inbox)
workers/control-plane  /api/collab/* REST + per-user invite-store Durable Object
workers/presence       device/cursor presence + sync/v1 substrate
scripts/               dev-all, smoke-e2e, demo, CLI
docs/                  self-hosting, client-setup, architecture
```

## The one hard rule: don't break wire compatibility

Coterm is byte-compatible with the mosaic client. **Do not change** any of these
without a matching client change — they are the wire contract, not implementation
detail:

- HTTP paths: `/v1/collaboration/...`, `/api/collab/...`
- WebSocket frame `type` strings (`session.joined`, `terminal.output`, …)
- The `mosaicv1` token format
- Query param names on the connect URL (`peerID`, `participantID`, `grant`, …)
- Durable Object class names + wrangler `[[migrations]]` tags (renaming a DO
  class without a migration destroys its storage)
- Client-facing env var names the app reads (`MOSAIC_API_BASE_URL`,
  `MOSAIC_COLLABORATION_RELAY_URL`, `MOSAIC_COLLAB_GUEST_ID`, …)

Everything else (package names, worker names, healthz strings, comments,
internal helpers) is fair game.

## Tests

- Every worker has `bun test` unit tests; keep them green.
- Pure logic (fan-out, filtering, token codec, presence state) is unit-tested
  without a live Durable Object — prefer that over integration tests.
- Add/adjust tests with behavior changes.

## Pull requests

1. Branch from `main`.
2. `bun test && bun run typecheck` must pass.
3. Keep changes focused; explain wire-affecting changes explicitly.
4. By contributing you agree your work is licensed under GPL-3.0-or-later.
