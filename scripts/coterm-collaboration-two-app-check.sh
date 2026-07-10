#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HOST_TAG="${COTERM_COLLAB_HOST_TAG:-host-test}"
GUEST_TAG="${COTERM_COLLAB_GUEST_TAG:-guest-test}"
FAST_RELOAD="${COTERM_COLLAB_FAST_RELOAD:-1}"
LAUNCH="${COTERM_COLLAB_LAUNCH:-1}"

usage() {
  cat <<'EOF'
usage: scripts/coterm-collaboration-two-app-check.sh [--no-build] [--no-launch]

Builds two isolated tagged Coterm DEV apps for manual self-host collaboration
regression testing, then prints the exact checklist to run.

Environment:
  COTERM_COLLAB_HOST_TAG=host-test
  COTERM_COLLAB_GUEST_TAG=guest-test
  COTERM_COLLAB_FAST_RELOAD=1
  COTERM_COLLAB_LAUNCH=1

The apps use the normal DEBUG self-host configuration. Run:

  cd coterm && bun run configure:client

first if the DEBUG client has not been pointed at your self-host backend.
EOF
}

BUILD=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      BUILD=0
      shift
      ;;
    --no-launch)
      LAUNCH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

build_tag() {
  local tag="$1"
  if [[ "$FAST_RELOAD" == "1" ]]; then
    COTERM_DEV_FAST_RELOAD=1 ./scripts/reload.sh --tag "$tag"
  else
    ./scripts/reload.sh --tag "$tag"
  fi
}

app_path_for_tag() {
  local tag="$1"
  printf '%s/Library/Developer/Xcode/DerivedData/coterm-%s/Build/Products/Debug/Coterm DEV.app' "$HOME" "$tag"
}

launch_tag() {
  local tag="$1"
  local app_path
  app_path="$(app_path_for_tag "$tag")"
  if [[ ! -d "$app_path" ]]; then
    echo "error: app missing for tag '$tag': $app_path" >&2
    exit 1
  fi
  pkill -f "/coterm-${tag}/Build/Products/Debug/Coterm DEV.app" >/dev/null 2>&1 || true
  open -n "$app_path"
}

if [[ "$BUILD" == "1" ]]; then
  build_tag "$HOST_TAG"
  build_tag "$GUEST_TAG"
fi

HOST_APP="$(app_path_for_tag "$HOST_TAG")"
GUEST_APP="$(app_path_for_tag "$GUEST_TAG")"

if [[ "$LAUNCH" == "1" ]]; then
  launch_tag "$HOST_TAG"
  launch_tag "$GUEST_TAG"
fi

cat <<EOF

Coterm two-app collaboration regression checklist

Host app:
  $HOST_APP

Guest app:
  $GUEST_APP

Before testing:
  1. Confirm the self-host backend is deployed:
     cd coterm && bun run doctor:self-host
  2. Confirm the DEBUG client config is written:
     cd coterm && bun run configure:client

Manual test:
  1. In Host, open or focus a terminal.
  2. Click Share Session.
  3. Confirm the setup/help entry is visible in the share popover.
  4. Click Copy Invite Code.
  5. In Guest, click Join and paste the copied token.
  6. Confirm Guest waits for owner approval instead of entering immediately.
  7. In Host, approve the join request.
  8. Confirm Guest sees the shared terminal.
  9. Confirm the Host sharing popover lists the Guest recipient.
  10. Click Stop sharing in Host.
  11. Confirm the Host button returns from Sharing to Share.
  12. Confirm the Guest mirror closes or stops receiving the shared terminal.
  13. If this was the only shared terminal, confirm the session people pill disappears.

EOF
