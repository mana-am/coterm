#!/usr/bin/env bash
# Regression test: the tag-bound debug CLI helper scrubs ambient coterm env and
# routes commands through the tagged socket and tagged bundled CLI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TAG="Debug_Helper.Test"
TAG_SLUG="debug-helper-test"
TAG_BUNDLE_ID="debug.helper.test"
SOCKET_PATH="/tmp/coterm-debug-${TAG_SLUG}.sock"
TMP_DIR="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
  rm -f "$SOCKET_PATH"
}
trap cleanup EXIT

FAKE_HOME="$TMP_DIR/home"
FAKE_CLI_DIR="$FAKE_HOME/Library/Developer/Xcode/DerivedData/coterm-${TAG_SLUG}/Build/Products/Debug/Coterm DEV ${TAG_SLUG}.app/Contents/Resources/bin"
FAKE_CLI="$FAKE_CLI_DIR/coterm"
mkdir -p "$FAKE_CLI_DIR"
cat > "$FAKE_CLI" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "env" ]]; then
  env | sort
  exit 0
fi
printf 'fake coterm argv:'
printf ' %q' "$@"
printf '\n'
EOF
chmod +x "$FAKE_CLI"

rm -f "$SOCKET_PATH"
python3 - "$SOCKET_PATH" <<'PY' >/dev/null 2>&1 &
import os
import socket
import sys
import time

path = sys.argv[1]
try:
    os.unlink(path)
except FileNotFoundError:
    pass

sock = socket.socket(socket.AF_UNIX)
sock.bind(path)
sock.listen(1)
time.sleep(60)
PY
SERVER_PID="$!"

for _ in {1..100}; do
  if [[ -S "$SOCKET_PATH" ]]; then
    break
  fi
  sleep 0.05
done

if [[ ! -S "$SOCKET_PATH" ]]; then
  echo "FAIL: test socket was not created at $SOCKET_PATH"
  exit 1
fi

OUTPUT="$(
  HOME="$FAKE_HOME" \
  COTERM_TAG="$TAG" \
  COTERM_SOCKET="/tmp/main-coterm-legacy.sock" \
  COTERM_SOCKET_PATH="/tmp/main-coterm.sock" \
  COTERM_SOCKET_PASSWORD="main-secret" \
  COTERM_BUNDLE_ID="cc.coterm.app" \
  COTERM_BUNDLED_CLI_PATH="/Applications/Coterm.app/Contents/Resources/bin/coterm" \
  COTERM_WORKSPACE_ID="main-workspace" \
  COTERM_TAB_ID="main-tab" \
  COTERM_SURFACE_ID="main-surface" \
  COTERM_PANEL_ID="main-panel" \
  COTERMD_UNIX_PATH="/tmp/main-cotermd.sock" \
  COTERM_DEBUG_LOG="/tmp/main-coterm.log" \
  "$ROOT_DIR/scripts/coterm-debug-cli.sh" env
)"

require_line() {
  local expected="$1"
  if ! grep -Fxq "$expected" <<<"$OUTPUT"; then
    echo "FAIL: expected env line not found: $expected"
    echo "$OUTPUT"
    exit 1
  fi
}

reject_prefix() {
  local prefix="$1"
  if grep -Eq "^${prefix}=" <<<"$OUTPUT"; then
    echo "FAIL: unexpected env line with prefix: $prefix"
    echo "$OUTPUT"
    exit 1
  fi
}

require_line "COTERM_SOCKET_PATH=$SOCKET_PATH"
require_line "COTERM_TAG=$TAG_SLUG"
require_line "COTERM_BUNDLE_ID=cc.coterm.app.debug.${TAG_BUNDLE_ID}"
require_line "COTERM_BUNDLED_CLI_PATH=$FAKE_CLI"

reject_prefix "COTERM_SOCKET"
reject_prefix "COTERM_SOCKET_PASSWORD"
reject_prefix "COTERM_WORKSPACE_ID"
reject_prefix "COTERM_TAB_ID"
reject_prefix "COTERM_SURFACE_ID"
reject_prefix "COTERM_PANEL_ID"
reject_prefix "COTERMD_UNIX_PATH"
reject_prefix "COTERM_DEBUG_LOG"

echo "PASS: coterm-debug-cli.sh routes through the tagged CLI/socket and scrubs ambient coterm env"
