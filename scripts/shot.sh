#!/usr/bin/env bash
# Screenshot a tmux pane as a PNG, colours included.
#
#   scripts/shot.sh [session] [output.png]
#
# Requires tmux, python3 and ImageMagick (`magick`).
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
session=${1:-nvim}
out=${2:-/tmp/opencode/shot.png}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/nvshot.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

tmux capture-pane -e -p -t "$session" >"$tmp/pane.ansi"

# Default colours follow the active theme so the render background matches.
nvim --headless "+lua local f=function(n,w) local i=vim.fn.hlID(n) if i==0 then return '' end return vim.fn.synIDattr(vim.fn.synIDtrans(i),w..'#') end vim.fn.writefile({f('Normal','fg'), f('Normal','bg')}, '$tmp/colors')" +qa! 2>/dev/null || true
fg=$(sed -n 1p "$tmp/colors" 2>/dev/null || true)
bg=$(sed -n 2p "$tmp/colors" 2>/dev/null || true)

python3 "$root/scripts/ansi2svg.py" "$tmp/pane.ansi" "$tmp/pane.svg" "${fg:-#2f2a22}" "${bg:-#e3d7c7}"
if ! magick "$tmp/pane.svg" "$out" 2>/dev/null; then
  convert "$tmp/pane.svg" "$out"
fi
echo "$out"
