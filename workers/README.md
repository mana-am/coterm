# Root Workers

This directory is not the self-host collaboration backend package. The
self-host stack lives under `coterm/workers/` and is deployed from `coterm/`.

Current root workers:

- `presence`: active team/device presence service used by app integration and
  dev worker workflows.
- `collaboration`: legacy hosted Phase 1 collaboration relay. Keep it for
  compatibility and historical CI/deploy workflows; new self-host collaboration
  and preview-sharing work belongs in `coterm/workers/relay`.

See `docs/repo-map.md` before adding or moving Worker code.
