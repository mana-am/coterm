# Self-hosting Coterm

Self-hosting should feel like connecting Coterm to your own Cloudflare account,
not operating a backend. The one-command path below logs you into Cloudflare,
deploys the relay, control-plane, and presence workers, verifies `/healthz`, and
prints the values to paste into Coterm.

There is no database and no server to keep alive. For typical small-team usage,
Cloudflare's free tier is enough.

## What you will do

1. Install Bun if you do not have it.
2. Log into Cloudflare once in the browser.
3. Run one deploy command.
4. Paste three printed URLs into Coterm's collaboration configuration.

Most users do not need the manual deploy, custom domains, or auth details on a
first setup.

## Prerequisites

- A Cloudflare account (free plan is enough; Durable Objects with SQLite storage
  are free-tier eligible).
- [Bun](https://bun.sh) ≥ 1.3.
- Wrangler auth: either `bunx wrangler login` (OAuth) **or** set
  `CLOUDFLARE_API_TOKEN` (a token with "Edit Workers" permission). If your token
  can access multiple accounts, also set `CLOUDFLARE_ACCOUNT_ID`.

## Deploy

### Fast path

Use this path first. It is designed for users who want collaboration working
quickly without learning the three-worker deployment order.

```bash
cd coterm
bun install
bunx wrangler login            # opens a Cloudflare browser login, once
bun run deploy:self-host
```

The script does the backend work for you:

1. Deploys `coterm-relay`.
2. Writes the deployed relay URL into `workers/control-plane/wrangler.toml` as
   `COLLAB_RELAY_URL`.
3. Deploys `coterm-control-plane` and `coterm-presence`.
4. Checks `/healthz`, saves `.coterm-self-host.env`, and prints the client
   configuration:

```text
COTERM_API_BASE_URL=https://coterm-control-plane.<sub>.workers.dev
COTERM_COLLABORATION_RELAY_URL=https://coterm-relay.<sub>.workers.dev
COTERM_PRESENCE_BASE_URL=https://coterm-presence.<sub>.workers.dev
```

Paste those three values into Coterm's collaboration configuration, or export
them before launching a client from the shell. See [client-setup.md](client-setup.md)
for client examples.

For a stronger shared-secret setup, deploy with HMAC auth:

```bash
bun run deploy:self-host -- --auth hmac
```

That generates one `COLLAB_AUTH_SECRET`, installs it on all three workers, and
sets `COLLAB_AUTH_MODE = "hmac"` in each worker's `wrangler.toml`.

To also run the live collaboration smoke test after deployment:

```bash
bun run deploy:self-host -- --smoke
```

To print the saved client values again later:

```bash
bun run deploy:self-host -- --print-config
```

To check an existing deployment without redeploying:

```bash
bun run doctor:self-host
```

`doctor:self-host` checks the three `/healthz` endpoints and warns if your local
control-plane `wrangler.toml` points at a different relay URL than the saved
client config. It does not create collaboration sessions unless you ask for the
live smoke test:

```bash
bun run doctor:self-host -- --smoke
```

In `hmac` mode, `doctor:self-host -- --smoke` needs `COLLAB_AUTH_SECRET` in the
current shell so it can mint a temporary test token. The deploy script does not
save that secret to disk.

## Configure Coterm

After deploy, write the saved self-host URLs into the DEBUG client override file:

```bash
bun run configure:client -- --guest-id alice
```

That updates `~/.coterm-dev.env` with:

```text
COTERM_API_BASE_URL=...
COTERM_COLLABORATION_RELAY_URL=...
COTERM_PRESENCE_BASE_URL=...
COTERM_COLLAB_GUEST_ID=alice
```

Restart any running DEBUG Coterm app after writing the file. The app reads this
file only in DEBUG builds, so release/TestFlight-style builds still need the
normal in-app or environment configuration path.

For agents and scripts, print or write a non-secret context bundle:

```bash
bun run context:self-host -- --format markdown
bun run context:self-host -- --format shell
bun run context:self-host -- --format json --write .coterm-self-host.context.json
```

The deploy and doctor scripts refresh `.coterm-self-host.context.json`
automatically. The file contains endpoint URLs, auth mode, useful commands, and
agent guidance; it never contains `COLLAB_AUTH_SECRET`.

## If setup stops

Most problems are either lost client values or a half-finished Cloudflare
deploy. Start with:

```bash
bun run deploy:self-host -- --print-config
bun run doctor:self-host
```

The first command reprints the values saved from the last successful deploy. The
second checks the three deployed `/healthz` endpoints and warns when local
configuration points at the wrong relay.

## Preview sharing

Web preview sharing is included in the relay Worker. There is no extra service
to deploy after `bun run deploy:self-host`.

The headless host command can expose a local web app through the self-hosted
relay:

```bash
bun run preview:host -- \
  --relay https://coterm-relay.<sub>.workers.dev \
  --room ABCD1234 \
  --share-secret "$COTERM_SHARE_SECRET" \
  --port 3000
```

The command prints a viewer URL that a collaborator can open in a browser or
Coterm browser surface. See [preview-sharing.md](preview-sharing.md) for the
limits and security model.

### Manual deploy

Use the manual path only if the script fails or you need to wire custom domains
before deploying.

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
curl https://coterm-presence.<sub>.workers.dev/healthz       # {"ok":true,"service":"coterm-presence"}
```

Then run the end-to-end check against your live deployment:

```bash
COTERM_COLLAB_CONTROL_URL=https://coterm-control-plane.<sub>.workers.dev \
COTERM_COLLABORATION_RELAY_URL=https://coterm-relay.<sub>.workers.dev \
bun scripts/smoke-e2e.ts
```

## Auth modes

Set `COLLAB_AUTH_MODE` in each worker's `wrangler.toml` `[vars]` (must match
across all three):

### `hmac` (default)

The control-plane mints short-lived, room-bound join grants; the relay verifies
them before the WebSocket upgrade. Signed account access tokens are verified
with the shared secret. Coterm's self-hosted no-login client may also send a
local `.guest` access token for identity; the control-plane accepts that identity
input, but relay grants and session descriptors are still HMAC-signed by the
backend. All three workers share one secret:

```bash
SECRET=$(openssl rand -hex 32)
for w in relay control-plane presence; do
  echo -n "$SECRET" | (cd workers/$w && bunx wrangler secret put COLLAB_AUTH_SECRET)
done
# set COLLAB_AUTH_MODE = "hmac" in each wrangler.toml [vars], then redeploy
```

### `noauth`

Use only for local testing. The relay still requires a control-plane grant, but
the grant is unsigned and can be forged by anyone who understands the format.
Do not use `noauth` for a shared or public deployment.

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

- **You lost the URLs to paste into Coterm** → run
  `bun run deploy:self-host -- --print-config`.
- **You are not sure what is broken** → run `bun run doctor:self-host`. Add
  `-- --smoke` only when you want to create a temporary live collaboration room.
- **`Could not find the workers.dev URL`** → the deploy may be using only a
  custom domain or Wrangler changed its output. Deploy manually and set the
  printed/custom URL in the client.
- **`more than one account` on deploy** → `export CLOUDFLARE_ACCOUNT_ID=<id>`.
- **Client connects but can't create a session** → check the control-plane's
  `COLLAB_RELAY_URL` points at your deployed relay (not localhost).
- **Client presence does not update** → check `COTERM_PRESENCE_BASE_URL` points
  at the deployed presence worker and `/healthz` returns `coterm-presence`.
- **`403 forbidden` on connect in hmac mode** → the client isn't sending a valid
  grant, or the three workers don't share the same `COLLAB_AUTH_SECRET`.
- **Local `wrangler dev` cross-worker calls fail** → expected; workerd can't
  fetch another local dev server over loopback. Only affects local dev, not
  production. See `README.md`.
