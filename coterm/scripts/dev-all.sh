#!/usr/bin/env bash
# Boot all three workers locally with `wrangler dev` (miniflare):
#   relay          :8787
#   control-plane  :8788
#   presence       :8789
#
# Defaults to noauth (zero config). For hmac mode, export a shared secret first:
#   export COLLAB_AUTH_MODE=hmac COLLAB_AUTH_SECRET=$(openssl rand -hex 32)
#
# Ctrl-C stops all three.
set -euo pipefail

cd "$(dirname "$0")/.."

AUTH_MODE="${COLLAB_AUTH_MODE:-noauth}"
SECRET_ARG=()
if [[ "$AUTH_MODE" == "hmac" ]]; then
  if [[ -z "${COLLAB_AUTH_SECRET:-}" ]]; then
    echo "hmac mode requires COLLAB_AUTH_SECRET" >&2
    exit 1
  fi
  SECRET_ARG=(--var "COLLAB_AUTH_SECRET:${COLLAB_AUTH_SECRET}")
fi

pids=()
cleanup() {
  echo "stopping workers..."
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM

echo "starting relay on :8787 (mode=$AUTH_MODE)"
bunx wrangler dev --config workers/relay/wrangler.toml --port 8787 \
  --var "COLLAB_AUTH_MODE:${AUTH_MODE}" "${SECRET_ARG[@]}" &
pids+=($!)

echo "starting control-plane on :8788 (mode=$AUTH_MODE)"
bunx wrangler dev --config workers/control-plane/wrangler.toml --port 8788 \
  --var "COLLAB_AUTH_MODE:${AUTH_MODE}" --var "COLLAB_RELAY_URL:http://localhost:8787" "${SECRET_ARG[@]}" &
pids+=($!)

echo "starting presence on :8789 (mode=$AUTH_MODE)"
bunx wrangler dev --config workers/presence/wrangler.toml --port 8789 \
  --var "COLLAB_AUTH_MODE:${AUTH_MODE}" "${SECRET_ARG[@]}" &
pids+=($!)

echo "all workers starting; press Ctrl-C to stop."
wait
