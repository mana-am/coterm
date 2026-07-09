#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${COTERM_TAG:-}" ]]; then
  cat >&2 <<'EOF'
COTERM_TAG is required.

Usage:
  COTERM_TAG=<tag> scripts/coterm-debug-cli.sh <coterm-command> [args...]

Example:
  COTERM_TAG=codext scripts/coterm-debug-cli.sh list-workspaces
EOF
  exit 2
fi

if [[ ! "$COTERM_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid COTERM_TAG: $COTERM_TAG" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: COTERM_TAG=$COTERM_TAG scripts/coterm-debug-cli.sh <coterm-command> [args...]" >&2
  exit 2
fi

sanitize_bundle() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

sanitize_path() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

tag_slug="$(sanitize_path "$COTERM_TAG")"
tag_bundle_id="$(sanitize_bundle "$COTERM_TAG")"

socket_path="/tmp/coterm-debug-${tag_slug}.sock"
if [[ ! -S "$socket_path" ]]; then
  cat >&2 <<EOF
Tagged coterm socket not found:
  $socket_path

Launch the tagged app first:
  ./scripts/reload.sh --tag $COTERM_TAG --launch
EOF
  exit 1
fi

cli_path="${HOME}/Library/Developer/Xcode/DerivedData/coterm-${tag_slug}/Build/Products/Debug/Coterm DEV ${tag_slug}.app/Contents/Resources/bin/coterm"
if [[ ! -x "$cli_path" ]]; then
  cat >&2 <<EOF
Tagged coterm CLI not found:
  $cli_path

Build the tagged app first:
  ./scripts/reload.sh --tag $COTERM_TAG
EOF
  exit 1
fi

unset COTERM_SOCKET
unset COTERM_SOCKET_PASSWORD
unset COTERM_WORKSPACE_ID
unset COTERM_SURFACE_ID
unset COTERM_TAB_ID
unset COTERM_PANEL_ID
unset COTERMD_UNIX_PATH
unset COTERM_DEBUG_LOG
export COTERM_SOCKET_PATH="$socket_path"
export COTERM_TAG="$tag_slug"
export COTERM_BUNDLE_ID="coterm.com.emergent.app.debug.${tag_bundle_id}"
export COTERM_BUNDLED_CLI_PATH="$cli_path"
exec "$cli_path" "$@"
