#!/usr/bin/env bash
# Dashboard in a real terminal: the status chips, the startup footer, and the
# refresh after a lazy.nvim check.
#
#   tests/dashboard.sh
#
# Each case starts the checkout's config in a private tmux server and reads
# the drawn screen; state comes from the editor's --listen socket.
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-dashboard.XXXXXX")
server="nv-dashboard-$$"
cleanup() {
  tmux -L "$server" kill-server 2>/dev/null
  rm -rf -- "$tmp"
}
trap cleanup EXIT

export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
mkdir -m 700 "$XDG_RUNTIME_DIR"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

# A recent update check: lazy.nvim runs only its local check at startup, the
# same as within an hour of a real check, and the run stays offline.
mkdir -p "$XDG_STATE_HOME/nvim/lazy"
printf '{"checker":{"last_check":%s}}\n' "$(date +%s)" >"$XDG_STATE_HOME/nvim/lazy/state.json"

mkdir -p "$tmp/plain" "$tmp/repo"
git -C "$tmp/repo" init -q -b trunk

pass=0
fail=0
ok() {
  pass=$((pass + 1))
  printf 'ok   - %s\n' "$1"
}
bad() {
  fail=$((fail + 1))
  printf 'FAIL - %s\n' "$1"
  [ -n "${2:-}" ] && printf '%s\n' "$2"
}

# start <cwd> [nvim args...]: launch the dashboard and wait until lazy.nvim
# reported the startup time (LazyVimStarted, after the first frame).
start() {
  local cwd=$1 extra=''
  shift
  [ $# -gt 0 ] && extra=$(printf ' %q' "$@")
  sock="$tmp/nvim-$RANDOM.sock"
  tmux -L "$server" -f /dev/null kill-server 2>/dev/null
  tmux -L "$server" -f /dev/null new-session -d -x 120 -y 45 -c "$cwd" \
    "XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_STATE_HOME='$XDG_STATE_HOME' XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' nvim --listen '$sock'$extra"
  for _ in $(seq 50); do
    [ -S "$sock" ] && break
    sleep 0.1
  done
  for _ in $(seq 50); do
    [ "$(nv 'luaeval("require(\"lazy.stats\").stats().startuptime > 0")')" = v:true ] && break
    sleep 0.1
  done
  sleep 0.3
}
nv() { nvim --server "$sock" --remote-expr "$1" 2>/dev/null; }
screen() { tmux -L "$server" capture-pane -p; }

# Outside a repository: no git error, no branch chip.
start "$tmp/plain"
chips=$(screen | grep -m1 'nvim 0\.')
if [ -n "$chips" ] && ! grep -q 'fatal' <<<"$chips" && grep -q 'workspace' <<<"$chips"; then
  ok 'chips outside a repository show version and profile only'
else
  bad 'chips outside a repository' "$chips"
fi

# The footer shows the time lazy.nvim measured at UIEnter, after the
# dashboard's first draw.
footer=$(screen | grep -m1 'Neovim loaded')
if grep -Eq 'in [0-9.]+ms' <<<"$footer" && ! grep -q ' in 0ms' <<<"$footer"; then
  ok "footer shows the startup time ($(grep -Eo '[0-9.]+ms' <<<"$footer"))"
else
  bad 'footer startup time' "$footer"
fi

# A finished update check refreshes the dashboard without reloading a file.
result=$(nv 'luaeval("vim.inspect({ pcall(vim.api.nvim_exec_autocmds, \"User\", { pattern = \"LazyCheck\" }) })")')
if [ "$(nv '&filetype')" = snacks_dashboard ] && [ "$result" = '{ true }' ]; then
  ok 'LazyCheck refreshes the dashboard'
else
  bad 'LazyCheck refresh' "$result"
fi

# The local check finds updates after the dashboard drew and fires no event;
# its report() must bring up the update item. Inject one update the way
# fast_check records it.
nv 'luaeval("(function() local p = require(\"lazy.core.config\").plugins[\"snacks.nvim\"]; p._.updates = { from = {}, to = {} }; require(\"lazy.manage.checker\").report(false) end)()")' >/dev/null
sleep 0.3
count=$(nv 'luaeval("NVLazy.update_count()")')
item=$(screen | grep -m1 'Update plugins')
if [ "${count:-0}" -gt 0 ] && grep -qF "Update plugins ($count)" <<<"$item"; then
  ok 'updates found by the local check show on the dashboard'
else
  bad 'update item after the local check' "$(screen)"
fi

# Updates lazy.nvim already knows about are in the first frame. The probe
# fakes one: lazy sees a different remote commit for snacks.nvim (set up at
# VimEnter, before the dashboard draws), and records whether the dashboard
# buffer has the item when the first frame is drawn (UIEnter).
cat >"$tmp/fake-update.lua" <<'LUA'
vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function()
  local git = require 'lazy.manage.git'
  local get_target = git.get_target
  git.get_target = function(plugin)
    local target = get_target(plugin)
    if target and plugin.name == 'snacks.nvim' then
      target = vim.tbl_extend('force', target, { commit = string.rep('0', 40) })
    end
    return target
  end
end })
vim.api.nvim_create_autocmd('UIEnter', { once = true, callback = function()
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  vim.g.nv_first_frame_item = text:match 'Update plugins %(%d+%)' or ''
end })
LUA
start "$tmp/plain" --cmd "luafile $tmp/fake-update.lua"
first=$(nv 'g:nv_first_frame_item')
if [ -n "$first" ]; then
  ok "known updates are in the first frame ($first)"
else
  bad 'update item missing from the first frame' "$(screen)"
fi

# Inside a repository: the branch chip.
start "$tmp/repo"
chips=$(screen | grep -m1 'nvim 0\.')
if grep -q 'trunk' <<<"$chips" && grep -q 'workspace' <<<"$chips"; then
  ok 'chips inside a repository show the branch'
else
  bad 'branch chip' "$chips"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
