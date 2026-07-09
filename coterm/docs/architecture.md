# Architecture

Coterm is three Cloudflare Workers plus a shared auth package. All state lives in
Durable Objects — there is no external database.

```
                       ┌──────────────────────────────┐
   client A ───wss────►│  relay                        │◄───wss─── client B
   (host)              │  CollaborationSessionObject   │           (guest)
     │  REST           │   · one DO per session code   │
     ▼                 │   · in-memory peer fan-out     │
┌──────────────┐  REST │   · terminal recipient filter  │
│ control-plane│──────►│  CollaborationInboxObject      │
│ /api/collab/*│       │   · one DO per user (nudges)   │
│ InviteStore  │       │  CollaborationSessionIndexObj  │
│              │       │  PreviewSessionObject          │
└──────────────┘       └──────────────────────────────┘
        ▲
        │ REST (Bearer)
   client (any)              presence: TeamPresence DO (one per team)
```

Preview sharing is also self-hosted:

```text
guest browser -> relay PreviewSessionObject -> host outbound WebSocket -> host localhost
```

The host machine never accepts inbound connections.

## Components

### `workers/relay` — realtime relay
- **CollaborationSessionObject** — one Durable Object per session code. Accepts
  peer WebSocket upgrades, fans out frames to the other peers, and injects
  `fromPeerID` / `receivedAt`. Heartbeat timeout 30s; empty rooms self-delete
  after a 10-minute idle grace (freeing the short code).
- **CollaborationInboxObject** — one DO per user; holds live inbox sockets and
  pushes lightweight "check your inbox" nudges. Stores no invite content.
- **CollaborationSessionIndexObject** — a singleton directory of codes for admin.
- **PreviewSessionObject** — one DO per shared local web preview. It accepts the
  host's outbound WebSocket and proxies guest HTTP requests to the host's
  `127.0.0.1:<port>` target. It is intentionally not a general LAN proxy.
- Frames are opaque: the relay only requires a string `type` and forwards the
  rest. `terminal.*` frames may carry `recipientParticipantIDs` for targeted
  delivery; everything else broadcasts to all other peers.

### `workers/control-plane` — REST control plane
- Serves `/api/collab/{entitlements,sessions,org-directory,invite,inbox,
  inbox/reconcile,withdraw,join}`.
- **InviteStoreObject** — one DO per invitee, holding their authoritative invite
  list (keyed by room). Withdraw/reconcile mutate one user's list under the DO's
  single-writer gate.
- Mints signed session descriptors + short-lived join grants (hmac mode).

### `workers/presence` — presence + sync
- **TeamPresence** — one DO per team. Device/cursor presence (online/offline/
  seen/routes) plus a generic `sync/v1` substrate (devices list, per-user
  paired-host backup). Uses WebSocket hibernation.

### `packages/collab-auth` — pluggable auth
- `CollabAuthProvider` interface with two built-ins: `HmacAuthProvider` (shared
  secret, `cotermv1` tokens + room-bound grants) and `NoAuthProvider` (session
  code is the only gate). Swap in your own IdP by implementing the interface.

## Wire protocol (summary)

- **Connect:** `wss://<relay>/v1/collaboration/sessions/<code>/connect?peerID=&participantID=&displayName=&color=&imageURL=&grant=`
- **Relay control frames:** `session.joined`, `peer.joined`, `peer.update`,
  `peer.left`, `inbox.invite`.
- **App frames (forwarded opaquely):** `document.update` / `document.snapshot`
  (CRDT), `presence.update`, and the `terminal.*` family (`open`, `output`
  (base64 PTY bytes + sequence), `input`, `render_grid`, `dimensions`, `pointer`,
  `selection`, `close`), plus `agent.room.*`.
- **Auth token:** `cotermv1.<base64url(JSON claims)>.<HMAC-SHA256>`.

See `CONTRIBUTING.md` for the list of strings that must not change (wire
compatibility).

## Data flow: sharing a terminal

1. Host pre-creates a room on the relay and `POST /api/collab/sessions` →
   `{ session, room, grant, relayURL }`.
2. Host connects `…/<room>/connect?…&grant=…`; relay verifies the grant and
   emits `session.joined`.
3. A copied share token contains the short room code plus a high-entropy secret.
   A guest can use it only to create a pending join request; the owner must
   approve before the control-plane returns a relay grant.
4. Host streams `terminal.output` frames (raw PTY bytes, base64) → relay fans out
   to peers → guest replays them into a mirror surface.
5. Guest keystrokes travel back as `terminal.input` to the host's authoritative
   PTY. Only the host runs a real terminal; guests mirror + send input.
