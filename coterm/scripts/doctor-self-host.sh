#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT/.coterm-self-host.env"
CONTEXT_FILE="$ROOT/.coterm-self-host.context.json"
RUN_SMOKE="0"
ENV_CONTROL_URL="${COTERM_API_BASE_URL:-}"
ENV_RELAY_URL="${COTERM_COLLABORATION_RELAY_URL:-}"
ENV_PRESENCE_URL="${COTERM_PRESENCE_BASE_URL:-}"
ENV_AUTH_MODE="${COLLAB_AUTH_MODE:-}"
CONTROL_URL=""
RELAY_URL=""
PRESENCE_URL=""
AUTH_MODE=""

usage() {
  cat <<'USAGE'
Usage: bun run doctor:self-host [--smoke] [--config PATH]

Check a Coterm self-hosted collaboration backend.

Default checks:
  - Loads the saved .coterm-self-host.env config when present.
  - Checks relay, control-plane, and presence /healthz endpoints.
  - Warns when the local control-plane wrangler.toml points at a different relay.

Options:
  --smoke        Run the live end-to-end collaboration smoke test after health checks.
  --config PATH  Read client URLs from a different env file.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --smoke)
      RUN_SMOKE="1"
      shift
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

trim_trailing_slash() {
  printf '%s' "$1" | sed -E 's#/*$##'
}

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
  fi
  CONTROL_URL="$(trim_trailing_slash "${ENV_CONTROL_URL:-${COTERM_API_BASE_URL:-}}")"
  RELAY_URL="$(trim_trailing_slash "${ENV_RELAY_URL:-${COTERM_COLLABORATION_RELAY_URL:-}}")"
  PRESENCE_URL="$(trim_trailing_slash "${ENV_PRESENCE_URL:-${COTERM_PRESENCE_BASE_URL:-}}")"
  AUTH_MODE="${ENV_AUTH_MODE:-${COLLAB_AUTH_MODE:-}}"
}

require_url() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Missing $name." >&2
    echo "Run: bun run deploy:self-host" >&2
    echo "Or provide a config file with: bun run doctor:self-host -- --config PATH" >&2
    exit 1
  fi
}

health_check() {
  local label="$1"
  local url="$2"
  local expected="$3"
  local body
  echo "==> Checking ${label}: ${url}/healthz"
  if ! body="$(curl -fsS "${url}/healthz")"; then
    echo "FAIL ${label}: /healthz did not respond." >&2
    return 1
  fi
  if ! printf '%s' "$body" | grep -q "\"service\":\"${expected}\""; then
    echo "FAIL ${label}: expected service ${expected}, got: $body" >&2
    return 1
  fi
  echo "OK ${label}"
}

local_control_plane_relay_url() {
  local file="$ROOT/workers/control-plane/wrangler.toml"
  if [ ! -f "$file" ]; then
    return 0
  fi
  sed -nE 's/^COLLAB_RELAY_URL[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$file" | tail -n 1
}

check_local_config() {
  local configured
  configured="$(local_control_plane_relay_url)"
  if [ -z "$configured" ]; then
    echo "WARN local workers/control-plane/wrangler.toml has no COLLAB_RELAY_URL."
    return 0
  fi
  if [ "$(trim_trailing_slash "$configured")" != "$RELAY_URL" ]; then
    echo "WARN local control-plane COLLAB_RELAY_URL differs from saved relay URL."
    echo "     wrangler.toml: $configured"
    echo "     saved config : $RELAY_URL"
    return 0
  fi
  echo "OK local control-plane COLLAB_RELAY_URL matches saved relay URL."
}

write_context_file() {
  if bun scripts/self-host-context.ts --config "$CONFIG_FILE" --format json --write "$CONTEXT_FILE" >/dev/null; then
    echo "OK self-host agent context written: $CONTEXT_FILE"
  else
    echo "WARN could not write self-host agent context." >&2
  fi
}

run_smoke() {
  if [ "${AUTH_MODE:-noauth}" = "hmac" ] && [ -z "${COLLAB_AUTH_SECRET:-}" ]; then
    echo "Cannot run --smoke for hmac without COLLAB_AUTH_SECRET in the environment." >&2
    echo "Run: COLLAB_AUTH_SECRET=... bun run doctor:self-host -- --smoke" >&2
    exit 1
  fi
  echo
  echo "==> Running live e2e smoke test"
  COLLAB_AUTH_MODE="${AUTH_MODE:-noauth}" \
  COTERM_COLLAB_CONTROL_URL="$CONTROL_URL" \
  COTERM_COLLABORATION_RELAY_URL="$RELAY_URL" \
  bun scripts/smoke-e2e.ts
}

need_command bun
need_command curl
need_command grep
need_command sed

cd "$ROOT"
load_config

require_url "COTERM_API_BASE_URL" "$CONTROL_URL"
require_url "COTERM_COLLABORATION_RELAY_URL" "$RELAY_URL"
require_url "COTERM_PRESENCE_BASE_URL" "$PRESENCE_URL"

echo "Coterm self-host doctor"
echo "Config: $CONFIG_FILE"
echo

health_check "relay" "$RELAY_URL" "coterm-relay"
health_check "control-plane" "$CONTROL_URL" "coterm-control-plane"
health_check "presence" "$PRESENCE_URL" "coterm-presence"
check_local_config
write_context_file

if [ "$RUN_SMOKE" = "1" ]; then
  run_smoke
fi

cat <<EOF

Doctor complete.

Client configuration:
  COTERM_API_BASE_URL=$CONTROL_URL
  COTERM_COLLABORATION_RELAY_URL=$RELAY_URL
  COTERM_PRESENCE_BASE_URL=$PRESENCE_URL

Agent context:
  bun run context:self-host -- --format markdown

Configure a DEBUG client:
  bun run configure:client -- --guest-id <name>
EOF
