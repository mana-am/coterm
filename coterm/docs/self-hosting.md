# Self-hosting Coterm

Coterm runs as three Cloudflare Workers backed by Durable Objects. There is no
database and no server to keep alive — Cloudflare's free tier covers typical
small-team usage.

## Prerequisites

- A Cloudflare account (free plan is enough; Durable Objects with SQLite storage
  are free-tier eligible).
- [Bun](https://bun.sh) ≥ 1.3.
- Wrangler auth: either `bunx wrangler login` (OAuth) **or** set
  `CLOUDFLARE_API_TOKEN` (a token with "Edit Workers" permission). If your token
  can access multiple accounts, also set `CLOUDFLARE_ACCOUNT_ID`.

## Deploy

```bash
cd coterm
bun install

# 1. Relay first — note the printed URL, e.g. https://coterm-relay.<sub>.workers.dev
cd workers/relay && bunx wrangler deploy
```

Set that relay URL in `workers/control-plane/wrangler.toml` under
`[vars] COLLAB_RELAY_URL`, then deploy the rest:

```bash
cd ../control-plane && bunx wrangler deploy
cd ../presence && bunx wrangler deploy
```

Verify:

```bash
curl https://coterm-relay.<sub>.workers.dev/healthz          # {"ok":true,"service":"coterm-relay"}
curl https://coterm-control-plane.<sub>.workers.dev/healthz  # {"ok":true,"service":"coterm-control-plane"}
```

Then run the end-to-end check against your live deployment:

```bash
MOSAIC_COLLAB_CONTROL_URL=https://coterm-control-plane.<sub>.workers.dev \
MOSAIC_COLLABORATION_RELAY_URL=https://coterm-relay.<sub>.workers.dev \
bun scripts/smoke-e2e.ts
```

## Auth modes

Set `COLLAB_AUTH_MODE` in each worker's `wrangler.toml` `[vars]` (must match
across all three):

### `noauth` (default)

Knowing the session code is the only gate. Identity is best-effort (a chosen
name). Zero config — good for trusted groups. This is the same threat model the
upstream relay ships with.

### `hmac`

The control-plane mints short-lived, room-bound join grants; the relay verifies
them before the WebSocket upgrade, and the control-plane verifies client access
tokens. All three workers share one secret:

```bash
SECRET=$(openssl rand -hex 32)
for w in relay control-plane presence; do
  echo -n "$SECRET" | (cd workers/$w && bunx wrangler secret put COLLAB_AUTH_SECRET)
done
# set COLLAB_AUTH_MODE = "hmac" in each wrangler.toml [vars], then redeploy
```

## Custom domains (optional)

Add a route to a worker's `wrangler.toml` to serve it on your own domain:

```toml
[[routes]]
pattern = "relay.example.com"
custom_domain = true
```

## Scaling & cost

- State is in Durable Objects; empty session rooms self-delete after a 10-minute
  idle grace, so you don't accumulate storage.
- The relay forwards frames in-memory and never persists document/terminal
  content.
- For most self-hosters the Cloudflare free tier (100k requests/day, DO included)
  is plenty. Heavy usage may need the $5/mo Workers Paid plan.

## Troubleshooting

- **`more than one account` on deploy** → `export CLOUDFLARE_ACCOUNT_ID=<id>`.
- **Client connects but can't create a session** → check the control-plane's
  `COLLAB_RELAY_URL` points at your deployed relay (not localhost).
- **`403 forbidden` on connect in hmac mode** → the client isn't sending a valid
  grant, or the three workers don't share the same `COLLAB_AUTH_SECRET`.
- **Local `wrangler dev` cross-worker calls fail** → expected; workerd can't
  fetch another local dev server over loopback. Only affects local dev, not
  production. See `README.md`.
