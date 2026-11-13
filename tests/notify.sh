#!/usr/bin/env bash
# Notification centre: capture, render, filter, clear.
#
#   tests/notify.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-notify.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

probe=$(cat <<'LUA'
local out = {}
local function add(s) out[#out + 1] = s end

require('features.ui.notify').install()
vim.notify('first message', vim.log.levels.INFO, { title = 'Test' })
vim.notify('an error', vim.log.levels.ERROR)
add('entries=' .. #NVNotify.store)
add('notify replaced=' .. tostring(vim.g.nv_notify_installed == true))

-- Each notification shows a toast; <Esc> (NVNotify.dismiss) clears them.
vim.wait(200)
local toasts = 0
for _, w in ipairs(vim.api.nvim_list_wins()) do
  if vim.api.nvim_win_get_config(w).zindex == 150 then
    toasts = toasts + 1
  end
end
add('toasts=' .. toasts)
NVNotify.dismiss()
local after = 0
for _, w in ipairs(vim.api.nvim_list_wins()) do
  if vim.api.nvim_win_get_config(w).zindex == 150 then
    after = after + 1
  end
end
add('dismissed=' .. tostring(after == 0))

-- The centre is a real buffer: entries as text, filters in the winbar.
NVNotify.open()
local h = NVNotify.handle
local shown = table.concat(vim.api.nvim_buf_get_lines(h.buf, 0, -1, false), '\n')
local bar = vim.wo[h.win].winbar
add('shows title=' .. tostring(shown:find('Test', 1, true) ~= nil))
add('shows info=' .. tostring(shown:find('first message', 1, true) ~= nil))
add('shows error=' .. tostring(shown:find('an error', 1, true) ~= nil))
add('shows tabs=' .. tostring(bar:find('all', 1, true) ~= nil and bar:find('errors', 1, true) ~= nil))
add('unread cleared=' .. tostring(NVNotify.unread == 0))

NVNotify.clear()
local read = 0
for _, e in ipairs(NVNotify.store) do
  if e.read then
    read = read + 1
  end
end
add('cleared=' .. tostring(read == #NVNotify.store))
add('unread after clear=' .. tostring(NVNotify.unread == 0))

io.write('\n' .. table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa! 2>&1)
printf '%s\n' "$got"

fail=0
check() { grep -qx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'entries=2'
check 'notify replaced=true'
check 'toasts=2'
check 'dismissed=true'
check 'shows title=true'
check 'shows info=true'
check 'shows error=true'
check 'shows tabs=true'
check 'unread cleared=true'
check 'cleared=true'
check 'unread after clear=true'

[ "$fail" = 0 ] && echo 'notify: pass' || { echo 'notify: FAIL'; exit 1; }
