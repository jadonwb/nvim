#!/usr/bin/env bash
# Capture the panels the interaction sweep does not screenshot.
#
#   scripts/capture-panels.sh [columns] [lines] [tag]
#
# hover, Trouble (with a long diagnostic), which-key, Lazy, Mason, grug-far,
# the unsaved-changes prompt and the notification centre, each captured with
# scripts/shot.sh. Runs in an isolated tmux session and temporary XDG dirs, so
# it does not touch a live editor.
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
W=${1:-190}
H=${2:-48}
TAG=${3:-$W}
S="nv-panels-$TAG-$$"
out=${OUT:-/tmp/opencode/panels-$TAG}
shot="$root/scripts/shot.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-panels.XXXXXX")
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$out"
# The tmux server keeps its own environment, so the config/state are passed explicitly: the installed config (which chezmoi keeps in sync with this checkout) and an isolated state dir for sessions.

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email panels@example.com
git -C "$repo" config user.name panels
printf 'a\n' >"$repo/a.txt"
printf 'b\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm base
printf 'a\nmore\n' >"$repo/a.txt"

sock="$out/nvim-$$.sock"
cleanup() {
  tmux kill-session -t "$S" 2>/dev/null
  rm -rf -- "$tmp"
}
trap cleanup EXIT

tmux new-session -d -s "$S" -x "$W" -y "$H" -c "$repo" \
  "XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$XDG_STATE_HOME nvim --listen $sock"
for _ in $(seq 1 60); do
  nvim --server "$sock" --remote-expr 1 >/dev/null 2>&1 && break
  sleep 0.25
done
sleep 3

rpc() {
  printf '%s\n' "$1" >"$out/probe.lua"
  nvim --server "$sock" --remote-expr "luaeval(\"dofile('$out/probe.lua')\")" 2>&1
}
key() { tmux send-keys -t "$S" "$@"; }
cap() { bash "$shot" "$S" "$out/$1.png" >/dev/null; }

# A real Lua buffer so lua_ls attaches.
rpc "vim.cmd('edit $root/lua/features/layout/slots.lua')" >/dev/null
sleep 4
rpc 'vim.api.nvim_set_current_win(NVSlots.content_win()); local l = vim.fn.search("nvim_win_is_valid", "nw"); vim.api.nvim_win_set_cursor(0, { l, 12 })' >/dev/null
key K
sleep 3
cap hover
key Escape
sleep 0.6

rpc "vim.api.nvim_set_current_win(NVSlots.content_win()); vim.diagnostic.set(vim.api.nvim_create_namespace('panel-demo'), 0, {{ lnum = 0, col = 0, message = 'This is a long diagnostic message that explains in detail why the thing is wrong, mentions three possible causes and a suggested fix, and must not be cut off by the float edge without an ellipsis', severity = vim.diagnostic.severity.ERROR }}); vim.cmd('Trouble diagnostics toggle')" >/dev/null 2>&1
sleep 2
cap trouble
key q
sleep 0.8

key ' '
sleep 1.2
cap whichkey
key Escape
sleep 0.6

rpc "vim.cmd('Lazy')" >/dev/null 2>&1
sleep 3
cap lazy
key q
sleep 1.2

rpc "vim.cmd('Mason')" >/dev/null 2>&1
sleep 3
cap mason
key q
sleep 1.2

rpc "vim.cmd('GrugFar')" >/dev/null 2>&1
sleep 2
cap grugfar
key q
sleep 1

rpc 'NVDialogs.select_panel({ title = "Unsaved Changes (1/2)", message = "a.txt", options = { "Write", "Discard", "Cancel" }, shortcuts = { w = "Write", d = "Discard", c = "Cancel" } }, function() end)' >/dev/null 2>&1
sleep 1.2
cap unsaved
key Escape
sleep 1
left=$(rpc 'return #vim.tbl_filter(function(b) return vim.bo[b].filetype == "nvdialog" end, vim.api.nvim_list_bufs())')

rpc 'local N = require("features.ui.notify") N.add(vim.log.levels.ERROR, "A long notification that must wrap inside the centre rather than being clipped at the right edge, repeated to make it long enough to wrap onto a second and third line in a narrow centre.", { title = "agent" }); N.add(vim.log.levels.INFO, "Layout on"); N.add(vim.log.levels.WARN, "No LSP client for this buffer", { title = "lsp" }); N.open()' >/dev/null 2>&1
sleep 1.2
cap notify
key q
sleep 0.4

ls "$out"/*.png
if [ "$left" = "0" ]; then
  echo "panels: pass ($out)"
else
  echo "panels: FAIL (dialog still open after Esc)"
  exit 1
fi
