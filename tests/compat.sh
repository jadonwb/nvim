#!/usr/bin/env bash
# The 0.13 APIs the config is written against, on whichever Neovim runs it:
# on 0.12 these are core/compat.lua's polyfills, on 0.13 the real thing.
# Run under both (PATH=<nightly>/bin:$PATH tests/compat.sh).
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-compat.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

repo=$tmp/repo
mkdir -p "$repo"
git -C "$repo" init -q
printf 'one\n' >"$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m base
printf 'two\n' >"$repo/a.txt"
printf 'three\n' >"$repo/b.txt"
cd "$repo" || exit 1
mkdir -p "$XDG_STATE_HOME/nvim"
printf '{"%s":{"closed":{},"shown":{"right_mid":true},"providers":{}}}' "$repo" >"$XDG_STATE_HOME/nvim/nv-layout.json"

probe=$(cat <<'LUA'
vim.o.columns, vim.o.lines = 200, 50
local out = {}
local function add(s) out[#out + 1] = s end
local v013 = vim.fn.has 'nvim-0.13' == 1

-- vim.async: a sync callback, a later one, and awaiting another task.
local t = vim.async.run(function()
  local a = vim.async.await(1, function(cb) cb(1) end)
  local b = vim.async.await(1, vim.schedule)
  local child = vim.async.run(function()
    vim.async.await(1, vim.schedule)
    return 'child'
  end)
  return a, b, vim.async.await(child)
end)
local a, b, c = t:wait(2000)
add(('async=%s,%s,%s'):format(tostring(a), tostring(b), tostring(c)))

-- Event args carry the window.
local seen
vim.api.nvim_create_autocmd('WinClosed', { once = true, callback = function(ev) seen = ev.win end })
vim.cmd 'split'
local closing = vim.api.nvim_get_current_win()
vim.cmd 'close'
add('ev.win=' .. tostring(seen == closing))

-- nvim_win_resize with an anchor.
vim.cmd 'vsplit'
vim.api.nvim_win_resize(0, 40, -1, { anchor = 'right' })
add('resize=' .. vim.api.nvim_win_get_width(0))
vim.cmd 'only'

add('uri=' .. tostring(vim.uri.to_buf(vim.uri.from_fname(vim.fn.getcwd() .. '/a.txt')) > 0))

-- The unsaved-changes review (vim.async + the dialog): discard.
vim.cmd 'edit a.txt'
vim.wait(500)
vim.cmd 'edit b.txt'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed' })
local reviewed = vim.api.nvim_get_current_buf()
NVQuit.close_current()
local dialog = vim.wait(1000, function() return vim.bo.filetype == 'nvdialog' end)
vim.api.nvim_feedkeys('d', 'x', false)
vim.wait(800, function() return not vim.api.nvim_buf_is_valid(reviewed) or not vim.bo[reviewed].buflisted end)
add('review dialog=' .. tostring(dialog) .. ' discarded=' .. tostring(not vim.api.nvim_buf_is_valid(reviewed) or not vim.bo[reviewed].buflisted) .. ' file=' .. vim.fn.readfile('b.txt')[1] .. ' reviewing=' .. tostring(NVQuit.is_reviewing()))

-- The git panel data (vim.async + vim.system).
local data = require 'features.layout.data'
data.git = nil
data.refresh_git()
vim.wait(3000, function() return data.git ~= nil end)
add('git=' .. tostring(data.git and data.git.repo) .. ' files=' .. (data.git and #data.git.files or -1))

-- 0.13 only: pinned slot windows survive :only; file watchers reload.
if v013 then
  vim.cmd 'edit a.txt'
  vim.wait(500, function() return NVSlots.is_applied() end)
  if not NVSlots.is_applied() then NVSlots.open() end
  vim.api.nvim_set_current_win(NVSlots.content_win())
  -- The same windows, not ones repair rebuilt after :only closed them.
  local left, bottom = NVSlots.win 'left', NVSlots.win 'bottom'
  pcall(vim.cmd, 'only')
  vim.wait(200)
  add('pinned=' .. tostring(left ~= nil and NVSlots.win 'left' == left and NVSlots.win 'bottom' == bottom))
  local changed
  vim.api.nvim_create_autocmd('FileChangedShellPost', { once = true, callback = function() changed = true end })
  local f = io.open('a.txt', 'w'); f:write('outside\n'); f:close()
  vim.wait(2000, function() return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'outside' end)
  add('watch=' .. vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] .. ' FileChangedShellPost=' .. tostring(changed))
else
  add 'pinned=true'
  add 'watch=outside FileChangedShellPost=true'
end

io.write('\n' .. table.concat(out, '\n') .. '\n')
LUA
)

got=$(timeout 90 nvim --headless "+lua $probe" +qa! 2>&1 </dev/null)
printf '%s\n' "$got"

fail=0
check() { grep -Fqx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'async=1,nil,child'
check 'ev.win=true'
check 'resize=40'
check 'uri=true'
check 'review dialog=true discarded=true file=three reviewing=false'
check 'git=true files=2'
check 'pinned=true'
check 'watch=outside FileChangedShellPost=true'

[ "$fail" = 0 ] && echo 'compat: pass' || { echo 'compat: FAIL'; exit 1; }
