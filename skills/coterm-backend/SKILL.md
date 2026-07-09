---
name: coterm-backend
description: "Backend TypeScript and Cloud VM development rules for coterm. Use when editing web/app/api, web/services, backend scripts, Cloud VM lifecycle, provider integrations, Postgres, Stack Auth pricing gates, migrations, or provider image build scripts."
---

# coterm Backend

Use this skill for backend TypeScript, Cloud VM, provider, database, auth, rate-limit, retry, timeout, or telemetry work.

## Core rules

- Default backend TypeScript to Effect under `web/app/api/**`, `web/services/**`, and backend scripts that touch providers, databases, auth, rate limits, retries, timeouts, or telemetry.
- Keep Next route handlers thin: parse the request, run one Effect program at the boundary, map typed errors to HTTP responses, and treat unexpected defects separately.
- Use plain TypeScript only for trivial data shapes, constants, config files, frontend React code, or small glue where Effect would add ceremony without improving failure handling.
- Cloud VM backend logic must stay in Vercel route handlers and Effect services backed by Postgres.
- Do not reintroduce Rivet or a raw actor protocol for Cloud VM unless a later architecture doc explicitly changes the control plane.
- Production and staging Cloud VM Postgres use the Vercel Marketplace AWS Aurora PostgreSQL OIDC/RDS IAM path.
- Runtime env names are `COTERM_DB_DRIVER=aws-rds-iam`, `AWS_ROLE_ARN`, `AWS_REGION`, `PGHOST`, `PGPORT`, `PGUSER`, and `PGDATABASE`.
- Run production/staging migrations with `bun db:migrate:aws-rds-iam`; never run Drizzle migrations from Vercel build or route startup.
- Local development keeps using the `COTERM_PORT`-derived Docker Postgres path from `bun dev`.
- Cloud VM create pricing gates should use Stack Auth team payment items when enabled.
- Postgres remains the source of truth for VM lifecycle, active VM limits, idempotency, and usage events.

## Secrets

Cloud VM build, test, and local dev scripts use provider secrets from `~/.secrets/coterm.env`.

- `E2B_API_KEY`
- `FREESTYLE_API_KEY`
- R2 upload vars used by `web/scripts/build-cloud-vm-images.ts` when creating Freestyle snapshots

Load them with:

```bash
set -a
source ~/.secrets/coterm.env
set +a
```

`~/.secrets/coterm-dev.env` is for local Stack/web env and does not contain the provider build keys. `bun dev` sources `~/.secrets/coterm.env` first when present, then `~/.secrets/coterm-dev.env` so Coterm-specific Stack settings override broader coterm secrets. The web dev loader still accepts the legacy `~/.secret/coterm.env` and `~/.secrets/coterm.env` paths while machines migrate.

## Detailed references

- Read [references/effect-boundaries.md](references/effect-boundaries.md) when shaping route handlers, services, typed errors, retries, or dependency injection.
- Read [references/cloud-vm-control-plane.md](references/cloud-vm-control-plane.md) when touching VM lifecycle, migrations, Postgres, provider idempotency, or pricing gates.
