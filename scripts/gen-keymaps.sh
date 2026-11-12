#!/usr/bin/env bash
# Regenerate docs/wiki/keymaps.md from the live configuration.
#
#   scripts/gen-keymaps.sh
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
out="$root/docs/wiki/keymaps.md"

nvim --headless \
  "+lua dofile('$root/scripts/gen-keymaps.lua')" \
  "+qa!" 2>/dev/null || true

echo "wrote $out"
