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

NVNotify.open()

local function visible()
  local text = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.zindex == 70 then
      local buf = vim.api.nvim_win_get_buf(win)
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
        if mark[4].virt_text then
          text[#text + 1] = table.concat(vim.tbl_map(function(c) return c[1] end, mark[4].virt_text))
        end
      end
    end
  end
  return table.concat(text, '\n')
end

local shown = visible()
add('shows title=' .. tostring(shown:find('Test', 1, true) ~= nil))
add('shows info=' .. tostring(shown:find('first message', 1, true) ~= nil))
add('shows error=' .. tostring(shown:find('an error', 1, true) ~= nil))
add('shows tabs=' .. tostring(shown:find('all', 1, true) ~= nil and shown:find('errors', 1, true) ~= nil))
add('unread cleared=' .. tostring(NVNotify.unread == 0))

NVNotify.clear()
local read = 0
for _, e in ipairs(NVNotify.store) do
  if e.read then
    read = read + 1
  end
end
add('cleared=' .. tostring(read == #NVNotify.store))

io.write(table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa! 2>&1)
printf '%s\n' "$got"

fail=0
check() { grep -qx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'entries=2'
check 'notify replaced=true'
check 'shows title=true'
check 'shows info=true'
check 'shows error=true'
check 'shows tabs=true'
check 'unread cleared=true'
check 'cleared=true'

[ "$fail" = 0 ] && echo 'notify: pass' || { echo 'notify: FAIL'; exit 1; }
