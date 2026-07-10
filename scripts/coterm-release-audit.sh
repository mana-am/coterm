#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ALLOW_DIRTY="${COTERM_RELEASE_AUDIT_ALLOW_DIRTY:-0}"
FAILURES=0

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $*"
}

check_no_match() {
  local label="$1"
  local pattern="$2"
  shift 2
  local output
  if output="$(rg -n "$pattern" "$@" 2>/dev/null)"; then
    fail "$label"
    printf '%s\n' "$output" >&2
  else
    pass "$label"
  fi
}

check_match() {
  local label="$1"
  local pattern="$2"
  shift 2
  if rg -n "$pattern" "$@" >/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "==> Coterm release audit"

origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ "$origin_url" == "https://github.com/mana-am/coterm"* || "$origin_url" == "git@github.com:mana-am/coterm"* ]]; then
  pass "origin remote points at mana-am/coterm"
else
  fail "origin remote should point at mana-am/coterm, found: ${origin_url:-<missing>}"
fi

dirty="$(git status --short)"
if [[ -n "$dirty" ]]; then
  if [[ "$ALLOW_DIRTY" == "1" ]]; then
    echo "WARN: worktree is dirty; continuing because COTERM_RELEASE_AUDIT_ALLOW_DIRTY=1"
    printf '%s\n' "$dirty"
  else
    fail "worktree must be clean before tagging a release"
    printf '%s\n' "$dirty" >&2
  fi
else
  pass "worktree is clean"
fi

if command -v zig >/dev/null 2>&1; then
  zig_version="$(zig version)"
  if [[ "$zig_version" == "0.15.2" ]]; then
    pass "zig 0.15.2 is installed for Release packaging"
  else
    fail "zig 0.15.2 is required for Release packaging, found: $zig_version"
  fi
else
  fail "zig 0.15.2 is required for Release packaging, but zig was not found"
fi

check_no_match \
  "public release/docs surfaces do not point at old coterm repo URLs" \
  "github\.com/emergent-inc/coterm" \
  README.md README.zh-cn.md README.ja.md README.ko.md README.ru.md \
  coterm/instruction.md coterm/docs .github/ISSUE_TEMPLATE .github/FUNDING.yml \
  web/app/lib scripts/build-sign-upload.sh .github/workflows/release.yml \
  .github/workflows/update-homebrew.yml tests/test_homebrew_sha.sh

check_no_match \
  "public release/docs surfaces do not point at Mosaic download/domains" \
  "download\.mosaic|mosaic\.inc|dashboard\.mosaic|github\.com/emergent-inc/mosaic" \
  README.md README.zh-cn.md README.ja.md README.ko.md README.ru.md \
  coterm/instruction.md coterm/docs web/app/lib .github/ISSUE_TEMPLATE \
  .github/FUNDING.yml scripts/build-sign-upload.sh .github/workflows/release.yml

check_no_match \
  "app-localized strings do not contain Mosaic branding" \
  "Mosaic|mosaic" \
  Resources/Localizable.xcstrings Resources/InfoPlist.xcstrings

check_match \
  "README declares self-host-only collaboration" \
  "self-host only|self-hosted collaboration" \
  README.md

check_match \
  "agent install guide declares self-host-only collaboration" \
  "self-host only" \
  coterm/instruction.md

check_match \
  "hosted auth is opt-in through COTERM_AUTH_WWW_ORIGIN" \
  "COTERM_AUTH_WWW_ORIGIN" \
  Sources/Auth/AuthEnvironment.swift

check_match \
  "default collaboration relay has no hosted URL" \
  'AuthEnvironment\.collaborationRelayURLOverride \?\? ""' \
  Sources/CollaborationRuntime.swift

check_match \
  "README download points at GitHub release DMG" \
  "github\.com/mana-am/coterm/releases/latest/download/coterm-macos\.dmg" \
  README.md

check_match \
  "release workflow publishes coterm-macos.dmg" \
  "coterm-macos\.dmg" \
  .github/workflows/release.yml scripts/release_asset_guard.js

if [[ "$FAILURES" -gt 0 ]]; then
  echo "==> Coterm release audit failed with $FAILURES issue(s)" >&2
  exit 1
fi

echo "==> Coterm release audit passed"
