# Pointing a client at your Coterm backend

Coterm speaks the mosaic client's wire protocol, so a mosaic-compatible client
connects by overriding two URLs. Identity can be a full account (the client's
normal sign-in) or an **offline guest** (just a chosen name).

## The two URLs

| What | Env var | Value |
|---|---|---|
| Control-plane (REST `/api/collab/*`) | `MOSAIC_API_BASE_URL` | `https://coterm-control-plane.<sub>.workers.dev` |
| Relay (WebSocket) | `MOSAIC_COLLABORATION_RELAY_URL` | `https://coterm-relay.<sub>.workers.dev` |

The client learns the relay URL from the control-plane's responses, but setting
`MOSAIC_COLLABORATION_RELAY_URL` makes room pre-creation and code-joins point at
your relay from the first call.

## Offline guest mode (no login)

For a self-hosted, account-free experience, run the client in guest mode: the
identity is a chosen id (+ optional avatar), and the client skips the browser
sign-in. Set:

| Env var | Meaning |
|---|---|
| `MOSAIC_COLLAB_GUEST_ID` | The user's id / display name (required to enable guest mode) |
| `MOSAIC_COLLAB_GUEST_AVATAR` | Optional avatar image URL |

In `noauth` backend mode the control-plane reads the id from the client's token
(decoded, not verified) — no secret needed.

### Example (macOS, launched from a shell)

```bash
APP="/path/to/YourClient.app/Contents/MacOS/YourClient"
MOSAIC_COLLAB_GUEST_ID=alice \
MOSAIC_API_BASE_URL=https://coterm-control-plane.<sub>.workers.dev \
MOSAIC_COLLABORATION_RELAY_URL=https://coterm-relay.<sub>.workers.dev \
"$APP"
```

Two users = two instances (each with a different `MOSAIC_COLLAB_GUEST_ID`). One
shares a terminal and gets a room code; the other joins by code.

> Env vars only propagate to a shell-launched process. For a Finder/Dock-launched
> DEBUG build, the mosaic client also reads `~/.mosaic-dev.env` (a simple
> `KEY=value` file) for these overrides.

## No client yet?

The repo ships headless clients you can use to test or script against your
backend without a GUI:

```bash
bun scripts/collab-cli.ts host --name alice   # interactive, identity = --name
bun scripts/demo-two-clients.ts               # two simulated users sharing a terminal
```
