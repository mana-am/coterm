#!/usr/bin/env bash
set -euo pipefail

tag="${COTERM_TAG:-swmob}"
repo="${COTERM_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
app="${COTERM_SWAPP:-$HOME/Library/Developer/Xcode/DerivedData/coterm-${tag}/Build/Products/Debug/Coterm DEV ${tag}.app}"
port="${COTERM_PORT:-9300}"
port_range="${COTERM_PORT_RANGE:-10}"
port_end="${COTERM_PORT_END:-$((port + port_range - 1))}"
dev_origin="${COTERM_DEV_ORIGIN:-http://localhost:${port}}"
bin="$app/Contents/MacOS/Coterm DEV"
tag_bundle_id="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
if [[ -z "$tag_bundle_id" ]]; then
  tag_bundle_id="agent"
fi

if [[ ! -x "$bin" ]]; then
  echo "missing tagged app binary: $bin" >&2
  exit 1
fi

exec env \
  COTERM_BUNDLE_ID="coterm.com.emergent.app.debug.${tag_bundle_id}" \
  COTERM_SOCKET_ENABLE=1 \
  COTERM_SOCKET_MODE=allowAll \
  COTERM_SOCKET_PATH="/tmp/coterm-debug-${tag}.sock" \
  COTERMD_UNIX_PATH="$HOME/Library/Application Support/coterm/cotermd-dev-${tag}.sock" \
  COTERM_DEBUG_LOG="/tmp/coterm-debug-${tag}.log" \
  COTERM_API_BASE_URL="$dev_origin" \
  COTERM_AUTH_WWW_ORIGIN="$dev_origin" \
  COTERM_VM_API_BASE_URL="$dev_origin" \
  COTERM_PORT="$port" \
  COTERM_PORT_RANGE="$port_range" \
  COTERM_PORT_END="$port_end" \
  PORT="$port" \
  COTERM_BUNDLED_CLI_PATH="$app/Contents/Resources/bin/coterm" \
  COTERM_SHELL_INTEGRATION_DIR="$app/Contents/Resources/shell-integration" \
  COTERM_REMOTE_DAEMON_ALLOW_LOCAL_BUILD=1 \
  COTERM_REPO_ROOT="$repo" \
  "$bin"
