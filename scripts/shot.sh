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

# The capture carries the real theme colours; the renderer derives its default
# background/foreground from them (no second Neovim with a possibly different
# XDG config).
python3 "$root/scripts/ansi2svg.py" "$tmp/pane.ansi" "$tmp/pane.svg" auto auto
if ! magick "$tmp/pane.svg" "$out" 2>/dev/null; then
  convert "$tmp/pane.svg" "$out"
fi
echo "$out"
