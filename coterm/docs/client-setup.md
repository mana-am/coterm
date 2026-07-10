# Pointing a client at your Coterm backend

Coterm speaks the coterm client's wire protocol, so a coterm-compatible client
connects by overriding the self-hosted worker URLs. Identity can be a full
account (the client's normal sign-in) or an **offline guest** (just a chosen
name).

If you used `bun run deploy:self-host`, you already have the values you need.
The script printed them and saved a copy in `coterm/.coterm-self-host.env`.

```bash
cd coterm
bun run deploy:self-host -- --print-config
```

Paste the three printed URLs into Coterm's collaboration configuration, or use
them as environment variables when launching a client from the shell.

For DEBUG Coterm builds, the simplest path is:

```bash
cd coterm
bun run configure:client -- --guest-id alice
```

This writes the saved self-host URLs to `~/.coterm-dev.env`, which DEBUG builds
read even when launched from Finder, Dock, or a tagged app link. Restart the app
after writing the file.

`--guest-id` is optional in current Coterm builds. If it is omitted, Coterm uses
an automatic local guest identity when hosted auth is disabled. Pass `--guest-id`
only when you want a specific display name.

## The URLs

| What | Env var | Value |
|---|---|---|
| Control-plane (REST `/api/collab/*`) | `COTERM_API_BASE_URL` | `https://coterm-control-plane.<sub>.workers.dev` |
| Relay (WebSocket) | `COTERM_COLLABORATION_RELAY_URL` | `https://coterm-relay.<sub>.workers.dev` |
| Presence / sync | `COTERM_PRESENCE_BASE_URL` | `https://coterm-presence.<sub>.workers.dev` |

The client learns the relay URL from the control-plane's responses, but setting
`COTERM_COLLABORATION_RELAY_URL` makes room pre-creation and code-joins point at
your relay from the first call.

## Offline guest mode (no login)

For a self-hosted, account-free experience, Coterm runs collaboration in guest
mode when hosted auth is disabled. The identity is either an automatic local id
or a chosen id (+ optional avatar), and the client skips the browser sign-in.
Optional overrides:

| Env var | Meaning |
|---|---|
| `COTERM_COLLAB_GUEST_ID` | The user's id / display name (optional override) |
| `COTERM_COLLAB_GUEST_AVATAR` | Optional avatar image URL |

In `noauth` backend mode the control-plane reads the id from the client's token
(decoded, not verified) — no secret needed.

### Example (macOS, launched from a shell)

```bash
APP="/path/to/YourClient.app/Contents/MacOS/YourClient"
COTERM_COLLAB_GUEST_ID=alice \
COTERM_API_BASE_URL=https://coterm-control-plane.<sub>.workers.dev \
COTERM_COLLABORATION_RELAY_URL=https://coterm-relay.<sub>.workers.dev \
COTERM_PRESENCE_BASE_URL=https://coterm-presence.<sub>.workers.dev \
"$APP"
```

Two users = two instances (each with a different `COTERM_COLLAB_GUEST_ID`). One
shares a terminal and gets a room code; the other joins by code.

> Env vars only propagate to a shell-launched process. For a Finder/Dock-launched
> DEBUG build, the coterm client also reads `~/.coterm-dev.env` (a simple
> `KEY=value` file) for these overrides.

To preview the file that would be written without changing anything:

```bash
bun run configure:client -- --guest-id alice --print-only
```

To give an agent or script the current self-host state:

```bash
bun run context:self-host -- --format markdown
bun run context:self-host -- --format shell
```

## No client yet?

The repo ships headless clients you can use to test or script against your
backend without a GUI:

```bash
bun scripts/collab-cli.ts host --name alice   # interactive, identity = --name
bun scripts/demo-two-clients.ts               # two simulated users sharing a terminal
```
