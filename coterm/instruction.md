# Coterm Self-Hosted Collaboration Backend Installation

Use this guide to deploy the free, self-hostable Coterm collaboration backend on
Cloudflare Workers. The backend includes the relay, control plane, presence
worker, and shared auth package needed by a Coterm-compatible client.

## Installation

### For Humans

Copy and paste this prompt to your coding agent, such as Claude Code, AmpCode,
Cursor, Codex, or another repository-aware assistant:

```text
Install and configure the Coterm self-hosted collaboration backend by following the instructions here:
https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md

Work in the repository root. Coterm collaboration is self-host only; do not look for an official hosted backend. Read the guide, run `cd coterm && bun install && bunx wrangler login && bun run deploy:self-host`, then summarize the printed client configuration values and any manual DNS steps that remain. If I already deployed, use `bun run deploy:self-host -- --print-config` to reprint the saved values or `bun run doctor:self-host` to diagnose health. To configure a DEBUG Coterm client, run `bun run configure:client -- --guest-id <name>`. To inspect the non-secret agent context, run `bun run context:self-host -- --format markdown`. Use `--smoke` only if I ask for a live smoke test.
```

You can also read the steps below directly. The recommended path is the
one-command deploy script; it keeps the worker order, Durable Object migrations,
and cross-worker URLs aligned.

### For LLM Agents

Fetch this guide and follow it from top to bottom:

```bash
curl -fsSL https://raw.githubusercontent.com/mana-am/coterm/refs/heads/main/coterm/instruction.md
```

If the raw URL is unavailable because the user is working from a local checkout,
read `coterm/instruction.md` directly.

Important: Coterm's collaboration backend is self-host only. Do not search for
or configure an official hosted Coterm backend. Use the user's Cloudflare account
and the one-command deploy script unless the user explicitly asks for a manual
or custom-domain deployment.

Agent checklist:

1. Confirm the user has a Cloudflare account and can complete browser login.
2. Run `cd coterm && bun install && bunx wrangler login && bun run deploy:self-host`.
3. Capture the printed `COTERM_API_BASE_URL`,
   `COTERM_COLLABORATION_RELAY_URL`, and `COTERM_PRESENCE_BASE_URL`.
4. If the user only needs the saved values, run
   `bun run deploy:self-host -- --print-config`.
5. If the user reports a broken deployment, run `bun run doctor:self-host`.
6. If the user wants a DEBUG Coterm app to use the backend without shell env,
   run `bun run configure:client -- --guest-id <name>` and tell them to restart
   the app.
7. If another agent needs current backend state, run
   `bun run context:self-host -- --format markdown` or read
   `.coterm-self-host.context.json`.
8. Do not run `--smoke` unless the user explicitly wants a live end-to-end test.
9. For preview sharing, use the self-hosted relay and `bun run preview:host`;
   do not suggest ngrok, Cloudflare Tunnel, or an official hosted preview
   service as the default path.
10. Return only the client config, auth mode, and remaining manual DNS/client
   steps.

## Prerequisites

- A Cloudflare account.
- Bun installed locally.
- The repository cloned with the `coterm/` directory present.
- Optional but recommended: three custom subdomains, one each for the relay,
  control plane, and presence worker.

## Deploy

From the repository root:

```bash
cd coterm
bun install
bunx wrangler login
bun run deploy:self-host
```

The script prints the three values the user should paste into the client:

```text
COTERM_API_BASE_URL=...
COTERM_COLLABORATION_RELAY_URL=...
COTERM_PRESENCE_BASE_URL=...
```

It also saves those non-secret values to `.coterm-self-host.env`. Reprint them
with:

```bash
bun run deploy:self-host -- --print-config
```

The deploy and doctor scripts also refresh `.coterm-self-host.context.json`, a
non-secret context file for Coterm and coding agents. Print it with:

```bash
bun run context:self-host -- --format markdown
```

Configure a DEBUG Coterm client to use the deployment:

```bash
bun run configure:client -- --guest-id alice
```

That writes the self-host URLs to `~/.coterm-dev.env`; restart the DEBUG app
afterward so it rereads the file.

The default deploy uses HMAC auth. The script generates one shared
`COLLAB_AUTH_SECRET` and installs it on relay, control-plane, and presence.

If the script fails, fall back to the manual deployment below.

To diagnose an existing deployment without redeploying:

```bash
bun run doctor:self-host
```

### Manual fallback

Deploy the relay first:

```bash
cd workers/relay
bunx wrangler deploy
```

Copy the deployed relay URL. Then configure the control plane:

```toml
[vars]
COLLAB_RELAY_URL = "https://YOUR-RELAY-WORKER.workers.dev"
COLLAB_AUTH_MODE = "hmac"
```

Deploy the control plane:

```bash
cd ../control-plane
bunx wrangler deploy
```

Deploy presence:

```bash
cd ../presence
bunx wrangler deploy
```

## Auth Modes

For every real deployment, use `hmac`:

```toml
[vars]
COLLAB_AUTH_MODE = "hmac"
```

Set the same secret on every worker:

```bash
openssl rand -hex 32
bunx wrangler secret put COLLAB_AUTH_SECRET
```

Repeat the secret setup in `workers/relay`, `workers/control-plane`, and
`workers/presence`.

`noauth` is only for local testing. It still requires a control-plane grant, but
the grant is unsigned and is not a security boundary.

## Share and Join Security

Coterm share tokens are intentionally longer than the visible room code. The
short code is only a room lookup key; it is not sufficient to join.

When a user shares a room, Coterm generates:

- a short room code for usability;
- a high-entropy share secret for join requests;
- a short-lived relay grant for the owner.

Guests submit the room code plus share secret to the control-plane. The
control-plane creates a pending request for the room owner. Only after the owner
approves does the guest receive a relay grant. The relay should never accept a
plain room code as authorization.

## Configure the Client

Point the Coterm-compatible client at the deployed workers. Prefer the exact
values printed by `bun run deploy:self-host`.

Recommended production shape:

```text
COTERM_API_BASE_URL=https://collab-api.example.com
COTERM_COLLABORATION_RELAY_URL=https://collab-relay.example.com
COTERM_PRESENCE_BASE_URL=https://collab-presence.example.com
```

## Verify

Run the local tests from `coterm/`:

```bash
bun test
bun run typecheck
```

Run smoke checks against the deployed workers:

```bash
cd workers/relay
bun scripts/smoke-relay.ts

cd ../control-plane
bun scripts/smoke-control.ts

cd ../..
bun scripts/smoke-e2e.ts
```

If a smoke script requires endpoint arguments, inspect the script help or source
and pass the deployed worker URLs explicitly.

## Uninstallation

To remove the self-hosted backend:

1. Remove the Coterm collaboration URLs from your client configuration.
2. In Cloudflare, delete the deployed Workers for relay, control plane, and
   presence.
3. Delete the Durable Object namespaces created by those workers if you no
   longer need stored session, inbox, or presence state.
4. Remove any custom DNS records that pointed at the workers.
5. Delete local secrets or `.dev.vars` files created for this deployment.

If you configured `hmac`, also remove `COLLAB_AUTH_SECRET` from every worker
before deleting the project or sharing the Cloudflare account with others.

## Agent Checklist

When installing for a user, report:

- The deployed relay URL.
- The deployed control-plane URL.
- The deployed presence URL.
- The selected auth mode.
- Whether `COLLAB_AUTH_SECRET` was configured on every worker when using `hmac`.
- Any DNS records the user still needs to add.
- The exact client configuration values the user should paste into Coterm.
