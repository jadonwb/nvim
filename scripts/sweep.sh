#!/usr/bin/env bash
# End-to-end panel/keymap sweep against this checkout.
#
#   scripts/sweep.sh [columns] [lines] [tag]
#
# Starts Neovim in a tmux session at the requested size, walks the layout,
# keymaps, bottom modes, command line, preview, compare, help, cheatsheet,
# which-key, picker, notification centre, terminal, slot close/reopen, and a
# session save/restart/restore. Every step asserts state over RPC (so an open
# picker cannot swallow a probe) and captures a PNG with scripts/shot.sh.
#
# Captures and the probe log are written to ${OUT:-/tmp/opencode/sweep-<tag>}.
# Exits non-zero if any probe fails.
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
W=${1:-190}
H=${2:-48}
TAG=${3:-$W}
S="nv-sweep-$TAG"
out=${OUT:-/tmp/opencode/sweep-$TAG}
shot="$root/scripts/shot.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-sweep.XXXXXX")
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$out"
# The tmux server keeps its own environment, so the config/state are passed explicitly: the installed config (which chezmoi keeps in sync with this checkout) and an isolated state dir for sessions.

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email sweep@example.com
git -C "$repo" config user.name sweep
printf 'b\nc\n' >"$repo/a.txt"
printf 'c\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm base
printf 'b\nc\nb\n' >"$repo/a.txt"

sock="$out/nvim-$$.sock"
: >"$out/log.txt"
fail=0

cleanup() {
  tmux kill-session -t "$S" 2>/dev/null
  rm -rf -- "$tmp"
}
trap cleanup EXIT

log() { printf '%s\n' "$*" >>"$out/log.txt"; }
send() { tmux send-keys -t "$S" "$@"; }
rpc() {
  printf '%s\n' "$1" >"$out/probe.lua"
  nvim --server "$sock" --remote-expr "luaeval(\"dofile('$out/probe.lua')\")" 2>&1
}
probe() {
  local tag=$1
  shift
  local got
  got=$(rpc "return $*")
  log "$tag: $got"
}
act() { rpc "$1" >/dev/null 2>&1; sleep "${2:-0.5}"; }
expect() {
  local tag=$1 pattern=$2
  local got
  got=$(grep "^$tag: " "$out/log.txt" | tail -1)
  if ! grep -q -- "$pattern" <<<"$got"; then
    printf 'FAIL %s (got %s)\n' "$tag" "${got:-nothing}" | tee -a "$out/log.txt"
    fail=1
  fi
}
geometry() {
  rpc 'table.concat(vim.tbl_map(function(n) local s=NVSlots.status()[n] return n..":"..s.width.."x"..s.height end, vim.tbl_keys(NVSlots.status())), " ")'
}

listener_pids() {
  local p
  for p in $(pgrep -x nvim); do
    if tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q -- "--listen $sock" 2>/dev/null; then
      printf '%s\n' "$p"
    fi
  done
}

start() {
  tmux kill-session -t "$S" 2>/dev/null
  local p
  for p in $(listener_pids); do kill "$p" 2>/dev/null; done
  for _ in $(seq 1 20); do [ -z "$(listener_pids)" ] && break; sleep 0.2; done
  rm -f "$sock"
  tmux new-session -d -s "$S" -x "$W" -y "$H" -c "$repo" \
  "XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$XDG_STATE_HOME nvim --listen $sock"
  for _ in $(seq 1 60); do
    nvim --server "$sock" --remote-expr 1 >/dev/null 2>&1 && break
    sleep 0.25
  done
  sleep 3
}

start

probe layout 'tostring(NVSlots.is_applied())'
probe keymaps 'table.concat(vim.tbl_map(function(k) return tostring(vim.fn.maparg(k, "n") ~= "") end, {"<C-h>","<C-l>","<M-i>","<M-n>","<M-a>","<leader>?"}), ",")'
bash "$shot" "$S" "$out/layout.png" >/dev/null

# Real key input for navigation.
send C-h; sleep 0.3; probe nav-left 'vim.b.nv_slot or "centre"'
send C-l; sleep 0.3; probe nav-back 'vim.b.nv_slot or "centre"'
send C-j; sleep 0.3; probe nav-down 'vim.b.nv_slot or "centre"'
send C-k; sleep 0.3; probe nav-up 'vim.b.nv_slot or "centre"'
send C-l; sleep 0.3; probe nav-right 'vim.b.nv_slot or "centre"'

# Bottom modes, then the command line over a closed bottom panel.
for mode in prompt quickfix problems prompt; do act "NVBottom.set('$mode')" 0.25; done
probe bottom "NVSlots.provider_of('bottom')"
bash "$shot" "$S" "$out/bottom.png" >/dev/null
act "NVSlots.remove('bottom')" 0.5
send ':'; sleep 0.5
probe cmdline "tostring(NVSlots.is_open('bottom'))"
send Escape; sleep 0.3

# Preview.
act 'vim.api.nvim_set_current_win(NVSlots.win("left")); vim.api.nvim_win_set_cursor(0,{1,0}); require("features.preview").toggle()' 0.8
probe preview 'tostring(require("features.preview").enabled).."/"..tostring(require("features.preview").is_open()).."/"..tostring(require("features.preview").path)'
bash "$shot" "$S" "$out/preview.png" >/dev/null
act 'require("features.preview").toggle()' 0.4

# Compare with a man page.
act 'NVCompare.man("mkdir")' 1.0
probe man 'vim.bo.filetype.."/"..#vim.api.nvim_tabpage_list_wins(0)'
bash "$shot" "$S" "$out/man.png" >/dev/null
act 'NVCompare.close()' 0.6
probe geometry-after-compare 'table.concat(vim.tbl_map(function(n) local s=NVSlots.status()[n] return n..":"..s.width.."x"..s.height end, vim.tbl_keys(NVSlots.status())), " ")'

# Help, cheatsheet, which-key, picker, notify, terminal.
act "vim.cmd('help lua-guide')" 1.0
probe help 'vim.bo.filetype'
send q; sleep 0.6
probe help-closed 'tostring(vim.bo.filetype ~= "help")'
act 'require("features.cheatsheet").open()' 1.0
probe cheatsheet '#vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "nvcheatsheet" end, vim.api.nvim_list_wins())'
bash "$shot" "$S" "$out/cheatsheet.png" >/dev/null
send q; sleep 0.5
probe cheatsheet-closed '#vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "nvcheatsheet" end, vim.api.nvim_list_wins())'
probe whichkey-before '#vim.api.nvim_list_wins()'
send ' '; sleep 0.8
probe whichkey-after '#vim.api.nvim_list_wins()'
send Escape; sleep 0.3
act "vim.cmd('edit a.txt')" 0.3
act "vim.cmd('edit b.txt')" 0.4
act 'NVSPickers.buffers()' 0.9
probe picker '#require("snacks").picker.get()'
bash "$shot" "$S" "$out/picker.png" >/dev/null
act 'local p=require("snacks").picker.get()[1] if p then p:close() end' 0.4
act 'local N=require("features.ui.notify") N.add(vim.log.levels.WARN,"sweep notification that is long enough to need wrapping inside the centre",{title="sweep"}); N.open()' 0.8
probe notify '#vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "nvnotify" end, vim.api.nvim_list_wins())'
bash "$shot" "$S" "$out/notify.png" >/dev/null
send q; sleep 0.5
probe geometry-before-terminal 'table.concat(vim.tbl_map(function(n) local s=NVSlots.status()[n] return n..":"..s.width.."x"..s.height end, vim.tbl_keys(NVSlots.status())), " ")'
act 'NVTerminal.toggle()' 2.2
probe geometry-with-terminal 'table.concat(vim.tbl_map(function(n) local s=NVSlots.status()[n] return n..":"..s.width.."x"..s.height end, vim.tbl_keys(NVSlots.status())), " ")'
probe terminal '#vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_terminal" end, vim.api.nvim_list_wins())'
bash "$shot" "$S" "$out/terminal.png" >/dev/null
act 'NVTerminal.toggle()' 0.8

# Close and reopen slots.
act "NVSlots.remove('left'); NVSlots.remove('right_top')" 0.8
probe closed "NVSlots.is_open('left') and 'open' or 'closed'"
bash "$shot" "$S" "$out/closed.png" >/dev/null
act 'NVSlots.open()' 0.8
probe reopened 'vim.tbl_count(NVSlots.status())'
probe geometry-after-reopen 'table.concat(vim.tbl_map(function(n) local s=NVSlots.status()[n] return n..":"..s.width.."x"..s.height end, vim.tbl_keys(NVSlots.status())), " ")'

# Save, restart, restore.
act 'NVSession.save()' 0.8
send ':qa!'; sleep 2
start
act 'NVSession.restore()' 1.2
probe restored 'tostring(NVSlots.is_applied()).."/"..vim.tbl_count(NVSlots.status())'
probe geometry-restored 'table.concat(vim.tbl_map(function(n) local s=NVSlots.status()[n] return n..":"..s.width.."x"..s.height end, vim.tbl_keys(NVSlots.status())), " ")'
bash "$shot" "$S" "$out/restored.png" >/dev/null

expect layout 'true'
expect keymaps 'true,true,true,true,true,true'
expect nav-left 'left'
expect nav-back 'centre'
expect nav-down 'bottom'
expect nav-up 'centre'
expect nav-right 'right_top'
expect bottom 'prompt'
expect cmdline 'true'
expect preview 'true/true/'
expect man 'man/'
expect help 'help'
expect help-closed 'true'
expect cheatsheet '1'
expect cheatsheet-closed '0'
expect picker '1'
expect notify '1'
expect terminal '1'
expect closed 'closed'
expect reopened '4'
expect restored 'true/4'
norm() { tr ' ' '\n' <<<"$1" | sort | tr '\n' ' '; }
reopen_geo=$(sed -n 's/^geometry-after-reopen: //p' "$out/log.txt" | tail -1)
restore_geo=$(sed -n 's/^geometry-restored: //p' "$out/log.txt" | tail -1)
if [ -n "$reopen_geo" ] && [ "$(norm "$reopen_geo")" != "$(norm "$restore_geo")" ]; then
  printf 'FAIL geometry-restored (reopen=%s restored=%s)\n' "$reopen_geo" "$restore_geo" | tee -a "$out/log.txt"
  fail=1
fi

cat "$out/log.txt"
if [ "$fail" = 0 ]; then
  echo "sweep: pass ($out)"
else
  echo "sweep: FAIL ($out)"
  exit 1
fi
