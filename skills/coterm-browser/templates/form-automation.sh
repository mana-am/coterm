#!/usr/bin/env bash
set -euo pipefail

URL="${1:-https://example.com/form}"
SURFACE="${2:-surface:1}"

Coterm browser "$SURFACE" goto "$URL"
Coterm browser "$SURFACE" get url
Coterm browser "$SURFACE" wait --load-state complete --timeout-ms 15000
Coterm browser "$SURFACE" snapshot --interactive

echo "Now run fill/click commands using refs from the snapshot above."
