#!/usr/bin/env bash
# Capture the integration surfaces: signature help, code actions, completion,
# diffview (the only tab surface), lazygit, and the window swap/size keys.
#
#   scripts/capture-integrations.sh [columns] [lines] [tag]
#
# Runs in an isolated tmux session and temporary XDG dirs. Prints geometry
# assertions for the size/swap keymaps and exits non-zero if one is a no-op.
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
W=${1:-190}
H=${2:-48}
TAG=${3:-$W}
S="nv-integr-$TAG-$$"
out=${OUT:-/tmp/opencode/integrations-$TAG}
shot="$root/scripts/shot.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-integr.XXXXXX")
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$out"
# The tmux server keeps its own environment, so the config/state are passed explicitly: the installed config (which chezmoi keeps in sync with this checkout) and an isolated state dir for sessions.

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email integr@example.com
git -C "$repo" config user.name integr
printf 'one\ntwo\nthree\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm first
printf 'one\ntwo changed\nthree\nfour\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
git -C "$repo" commit -qam second
printf 'one\ntwo changed again\nthree\nfour\n' >"$repo/a.txt"

sock="$out/nvim-$$.sock"
fail=0
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
check() {
  local what=$1 allowed=$2 got=$3
  if [ "$got" = "$allowed" ]; then
    printf '%-22s %s\n' "$what" "$got"
  else
    printf 'FAIL %-17s %s (want %s)\n' "$what" "$got" "$allowed"
    fail=1
  fi
}
changed() { [ "$1" = "$2" ] && echo same || echo changed; }
geo() { rpc 'local o = {} for n, s in pairs(NVSlots.status()) do o[#o + 1] = n .. ":" .. s.width .. "x" .. s.height end table.sort(o) return table.concat(o, " ")'; }
wait_lsp() {
  local i
  for i in $(seq 1 40); do
    if [ "$(rpc 'return #vim.lsp.get_clients({ bufnr = 0 })' 2>/dev/null)" != "0" ]; then
      return
    fi
    sleep 0.25
  done
}
wins_with_ft() {
  rpc "return #vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == '$1' end, vim.api.nvim_list_wins())"
}
# Poll a Lua predicate so a slow server or picker does not fail the run.
reaches() {
  local expr=$1 i
  for i in $(seq 1 24); do
    if [ "$(rpc "return $expr" 2>/dev/null)" = "1" ]; then
      echo 1
      return
    fi
    sleep 0.25
  done
  echo 0
}

rpc "vim.cmd('edit $root/lua/features/layout/slots.lua')" >/dev/null
sleep 4

# Signature help on a call with arguments.
rpc 'vim.api.nvim_set_current_win(NVSlots.content_win()); local l = vim.fn.search("nvim_win_is_valid(", "nw"); vim.api.nvim_win_set_cursor(0, { l, 30 })' >/dev/null
key gK
sleep 2.5
cap signature
check 'signature help' '1' "$(reaches "#vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'nvlsp' end, vim.api.nvim_list_wins())")"
key Escape
sleep 0.5

# Code actions. A scratch Lua file with an unused local gives lua_ls real
# actions to offer.
printf 'local unused_demo = 2\n' >"$repo/demo.lua"
rpc "vim.cmd('edit $repo/demo.lua')" >/dev/null
wait_lsp
sleep 2
actions_ok=0
for _ in 1 2 3; do
  rpc 'vim.api.nvim_set_current_win(NVSlots.content_win()); vim.api.nvim_win_set_cursor(0, { 1, 8 })' >/dev/null
  key ' ' 'c' 'a'
  sleep 1.8
  if [ "$(rpc 'return #require("snacks").picker.get()' 2>/dev/null)" != "0" ]; then
    actions_ok=1
    break
  fi
  key Escape
  sleep 0.6
done
cap actions
check 'code actions' '1' "$actions_ok"
key Escape
sleep 0.5

# Completion menu: insert a prefix and force the menu.
rpc 'vim.api.nvim_set_current_win(NVSlots.content_win()); vim.api.nvim_win_set_cursor(0, { 1, 0 }); vim.cmd("startinsert")' >/dev/null
sleep 0.5
key 'v' 'i' 'm' '.'
sleep 1.5
# Typing `.` usually opens the menu; C-Space is the explicit request. Retry
# rather than assume a timing, since the first source may still be loading.
visible=0
for _ in 1 2 3 4 5; do
  if [ "$(wins_with_ft blink-cmp-menu)" != "0" ]; then
    visible=1
    break
  fi
  key C-Space
  sleep 1.5
done
cap completion
check 'completion menu' '1' "$visible"
key Escape
sleep 0.4
rpc 'vim.cmd("undo")' >/dev/null

# Diffview: the only tab surface.
rpc "vim.cmd('DiffviewFileHistory')" >/dev/null 2>&1
sleep 4
rpc 'vim.cmd("redraw!")' >/dev/null
sleep 0.5
cap diffview
check 'diffview tab' '2' "$(rpc 'return #vim.api.nvim_list_tabpages()')"
rpc "vim.cmd('DiffviewClose')" >/dev/null 2>&1
sleep 1.5
check 'diffview closed' '1' "$(rpc 'return #vim.api.nvim_list_tabpages()')"

# lazygit.
key M-g
sleep 4
cap lazygit
check 'lazygit' '1' "$(reaches '#vim.tbl_filter(function(b) return vim.api.nvim_buf_get_name(b):find("lazygit", 1, true) ~= nil or (vim.bo[b].filetype == "snacks_terminal" and vim.b[b].snacks_lazygit ~= nil) end, vim.api.nvim_list_bufs())')"
rpc 'if NVSLazygit and NVSLazygit.ensure_hidden then NVSLazygit.ensure_hidden() end' >/dev/null 2>&1
sleep 1

# Window width keys change the side-slot proportions.
width_before=$(geo)
key S-Left
sleep 0.8
width_after=$(geo)
cap width
check 'window width key' 'changed' "$(changed "$width_before" "$width_after")"
key M-=
sleep 0.6
check 'width reset' "$width_before" "$(geo)"

# Swap picker, then cancel. Winshift draws its diagram in the current window and
# blocks on getchar, so no RPC while it is open.
key M-Tab
sleep 1.5
cap swap
key Escape
sleep 1
check 'swap cancelled' '4' "$(rpc 'return vim.tbl_count(NVSlots.status())')"
check 'swap geometry' "$width_before" "$(geo)"

# Height keys resize the bottom panel (the grid's only vertical freedom).
b_before=$(rpc 'return NVSlots.status().bottom.height')
key S-Up
sleep 0.8
b_after=$(rpc 'return NVSlots.status().bottom.height')
check 'window height key' 'changed' "$(changed "$b_before" "$b_after")"
key M-=
sleep 0.6
check 'height reset' "$b_before" "$(rpc 'return NVSlots.status().bottom.height')"

ls "$out"/*.png
if [ "$fail" = 0 ]; then
  echo "integrations: pass ($out)"
else
  echo "integrations: FAIL ($out)"
  exit 1
fi
