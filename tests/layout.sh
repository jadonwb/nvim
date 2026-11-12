#!/usr/bin/env bash
# IDE slot layout assertions, run headless against this checkout.
#
#   tests/layout.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-layout.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

# A deterministic repository: the changed-files panel must not depend on the
# caller's working tree having uncommitted edits.
repo=$tmp/repo
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
printf 'one\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm base
printf 'two\n' >>"$repo/a.txt"
printf 'two\n' >>"$repo/b.txt"
cd "$repo" || exit 1

probe=$(cat <<'LUA'
local function wins() return #vim.api.nvim_tabpage_list_wins(0) end
local function slot(name)
  local s = NVSlots.status()[name]
  return s and (s.width .. 'x' .. s.height) or 'none'
end
local out = {}
local function add(s) out[#out + 1] = s end

vim.cmd 'enew'
add('start wins=' .. wins())
vim.cmd 'NVLayout open'
add('open wins=' .. wins() .. ' slots=' .. vim.tbl_count(NVSlots.status()) .. ' applied=' .. tostring(NVSlots.is_applied()))
local left = NVSlots.status().left
local right = NVSlots.status().right_top
local rt = NVSlots.status().right_top.height
local rb = NVSlots.status().right_bottom.height
add('left=' .. left.width .. ' right=' .. right.width .. ' ratios=' .. tostring(left.width < right.width))
add('right halves=' .. tostring(rt == rb))
-- Providers render into their slots.
local function ft(name)
  local w = NVSlots.win(name)
  return w and vim.bo[vim.api.nvim_win_get_buf(w)].filetype or 'none'
end
add('providers=' .. ft 'right_top' .. ',' .. ft 'right_bottom' .. ',' .. ft 'bottom')
add('left=' .. ft 'left')

-- Volt panels draw with virtual text; read what is actually visible.
local function visible(name)
  local w = NVSlots.win(name)
  if not w then
    return ''
  end
  local b = vim.api.nvim_win_get_buf(w)
  local t = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, -1, 0, -1, { details = true })) do
    if m[4].virt_text then
      t[#t + 1] = table.concat(vim.tbl_map(function(c) return c[1] end, m[4].virt_text))
    end
  end
  return table.concat(t, ' ')
end
add('session=' .. tostring(visible('right_bottom'):find('branch', 1, true) ~= nil))

-- Bottom panel modes: each one swaps content in place and draws its winbar.
for _, mode in ipairs { 'terminal', 'quickfix', 'problems', 'prompt' } do
  NVBottom.set(mode)
  local bw = NVSlots.win 'bottom'
  add(('bottom %s=%s'):format(mode, tostring(NVSlots.provider_of('bottom') == mode and bw and vim.wo[bw].winbar ~= '')))
end
NVBottom.cycle(1)
add('bottom cycle=' .. tostring(NVSlots.provider_of('bottom') ~= nil))

-- LSP progress renders as a volt bar inside the session panel.
NVMessages.progress['test.1'] = {
  client_id = 1,
  name = 'lua_ls',
  kind = 'report',
  title = 'LuaLS',
  percent = 50,
  updated = 1,
}
NVSlots.providers.session(NVSlots.win 'right_bottom')
add('progress=' .. tostring(visible('right_bottom'):find('LuaLS', 1, true) ~= nil))

-- The changed-files panel is a volt table: title plus at least one status row.
local changes = visible 'right_top'
add('changes=' .. tostring(changes:find('Changes', 1, true) ~= nil))

local top_buf = vim.api.nvim_win_get_buf(NVSlots.win 'right_top')
local changes_meta = vim.b[top_buf].nv_changes or {}
add('rows=' .. tostring(#(changes_meta.paths or {}) > 0))
-- Body rows start after the frame's top border and header.
add('row map=' .. tostring(changes_meta.first == 4 and #(changes_meta.paths or {}) > 0))

-- Any slot can host any provider.
NVSlots.set_provider('right_top', 'session')
add('substituted=' .. vim.bo[top_buf].filetype)
NVSlots.set_provider('right_top', 'changes')
add('restored=' .. vim.bo[top_buf].filetype)

-- A provider can move to a slot that is not its default.
NVSlots.set_provider('right_bottom', 'prompt')
add('prompt moved=' .. vim.bo[vim.api.nvim_win_get_buf(NVSlots.win 'right_bottom')].filetype)
NVSlots.set_provider('right_bottom', 'session')

-- After a swap, the periodic refresh must find changes by provider, not by slot.
NVSlots.swap('right_top', 'right_bottom')
add('changes slot=' .. tostring(NVSlots.slot_with_provider 'changes'))
NVMessages.progress = {}
vim.cmd 'NVLayout close'
add('close wins=' .. wins() .. ' applied=' .. tostring(NVSlots.is_applied()))
vim.cmd 'NVLayout open'
add('reopen wins=' .. wins())
vim.cmd 'NVLayout close'
add('final wins=' .. wins())

-- Per-slot control: closing a slot returns its space to the neighbour.
local function center()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local c = vim.api.nvim_win_get_config(w)
    if c.relative == '' and not vim.b[vim.api.nvim_win_get_buf(w)].nv_slot then
      return w
    end
  end
end

vim.cmd 'NVLayout open'
local h_before = vim.api.nvim_win_get_height(center())
vim.cmd 'NVLayout slot bottom close'
local h_after = vim.api.nvim_win_get_height(center())
add('bottom closed grows centre=' .. tostring(h_after > h_before) .. ' open=' .. tostring(NVSlots.is_open('bottom')))

-- Closing a slot leaves the others alone: left, bottom and right are
-- independent, and what remains keeps its own space.
vim.cmd 'NVLayout slot left close'
add('left closed others stay=' .. tostring(not NVSlots.is_open 'left' and NVSlots.is_open 'right_top' and NVSlots.is_open 'right_bottom'))
vim.cmd 'NVLayout slot left open'
vim.cmd 'NVLayout slot bottom open'
add('reopen one slot=' .. tostring(NVSlots.is_open 'bottom'))

-- Protection: deleting a slot buffer must not lose the slot. The window is
-- either kept (bufhidden=hide) or rebuilt by repair.
local left_win = NVSlots.win 'left'
vim.api.nvim_buf_delete(vim.api.nvim_win_get_buf(left_win), { force = true })
vim.wait(200, function() return NVSlots.is_open 'left' end)
add('buffer delete keeps window=' .. tostring(NVSlots.is_open 'left' and vim.api.nvim_win_is_valid(NVSlots.win 'left')))

-- Protection: a slot window closed outside the API is rebuilt.
local rt = NVSlots.win 'right_top'
vim.api.nvim_win_close(rt, true)
vim.wait(200, function() return NVSlots.is_open 'right_top' end)
add('window repair=' .. tostring(NVSlots.is_open 'right_top'))

-- Protection: the configured geometry is re-applied after a manual resize.
local rw = NVSlots.win 'right_top'
vim.api.nvim_win_set_width(rw, 12)
NVSlots.enforce()
add('geometry enforced=' .. tostring(vim.api.nvim_win_get_width(rw) > 12))

-- Swap keeps the windows and exchanges their buffers.
local ft_top_before = vim.bo[vim.api.nvim_win_get_buf(NVSlots.win 'right_top')].filetype
vim.cmd 'NVLayout swap right_top right_bottom'
local ft_top_after = vim.bo[vim.api.nvim_win_get_buf(NVSlots.win 'right_top')].filetype
add('swap exchanged=' .. tostring(ft_top_before ~= ft_top_after) .. ' win=' .. tostring(NVSlots.win 'right_top' ~= nil))
_ = left_h_before

io.write(table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa 2>&1)
printf '%s\n' "$got"

fail=0
check() { if ! grep -qx -- "$1" <<<"$got"; then printf 'FAIL: missing %s\n' "$1"; fail=1; fi; }
check 'start wins=1'
check 'open wins=5 slots=4 applied=true'
check 'right halves=true'
check 'providers=nvchanges,nvsession,nvprompt'
check 'left=oil'
check 'session=true'
check 'progress=true'
check 'changes=true'
check 'rows=true'
check 'row map=true'
check 'substituted=nvsession'
check 'restored=nvchanges'
check 'prompt moved=nvprompt'
check 'changes slot=right_bottom'
check 'bottom terminal=true'
check 'bottom quickfix=true'
check 'bottom problems=true'
check 'bottom prompt=true'
check 'bottom cycle=true'
check 'close wins=1 applied=false'
check 'reopen wins=5'
check 'final wins=1'
check 'bottom closed grows centre=true open=false'
check 'left closed others stay=true'
check 'buffer delete keeps window=true'
check 'window repair=true'
check 'geometry enforced=true'
check 'reopen one slot=true'
grep -q 'ratios=true' <<<"$got" || { echo 'FAIL: left column not narrower than right'; fail=1; }
grep -q 'swap exchanged=true win=true' <<<"$got" || { echo 'FAIL: swap did not exchange slot contents'; fail=1; }

[ "$fail" = 0 ] && echo 'layout: pass' || { echo 'layout: FAIL'; exit 1; }
