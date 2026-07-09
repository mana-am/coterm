# Self-host Workers

This directory contains the active self-host collaboration backend:

- `relay`: WebSocket relay for collaboration and preview sharing.
- `control-plane`: session creation, grants, auth modes, and relay URL wiring.
- `presence`: self-hosted presence for the open-source collaboration stack.

Deploy from the `coterm/` package:

```bash
bun run deploy:self-host
```

Use `workers/presence` only for the separate root team/device presence service,
and use `workers/collaboration` only for the legacy hosted Phase 1 relay.
