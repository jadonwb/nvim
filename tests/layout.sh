#!/usr/bin/env bash
# Slot layout invariants, run headless against this checkout.
#
#   tests/layout.sh
#
# Covers what the layout promises (docs/wiki/layout.md): it applies on the
# first file, sizes are a pure function of the screen, hidden panels stay
# hidden, panels closed any other way are rebuilt, side panels step aside for
# a side-by-side split, and help opens in the content window.
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-layout.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
# Panel memory (nv-layout.json) must not touch the caller's state.
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

repo=$tmp/repo
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m base
printf 'one\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
cd "$repo" || exit 1
# The OpenCode panel waits for a session unless shown explicitly; these tests
# are about the layout, so it is shown for this directory.
mkdir -p "$XDG_STATE_HOME/nvim"
printf '{"%s":{"closed":{},"shown":{"right_mid":true},"providers":{}}}' "$repo" >"$XDG_STATE_HOME/nvim/nv-layout.json"

probe=$(cat <<'LUA'
vim.o.columns, vim.o.lines = 200, 50
local out = {}
local function add(s) out[#out + 1] = s end
local function wait(ms) vim.wait(ms or 200) end
local function sizes()
  local o = {}
  for name, s in pairs(NVSlots.status()) do
    o[#o + 1] = name .. '=' .. s.width .. 'x' .. s.height
  end
  table.sort(o)
  return table.concat(o, ' ')
end
local SIDES = { 'left', 'right_top', 'right_mid', 'right_bottom' }
local function sides_open()
  for _, n in ipairs(SIDES) do
    if not NVSlots.is_open(n) then return false end
  end
  return true
end

-- Applies on the first real file.
vim.cmd 'edit a.txt'
wait(500)
add('applied=' .. tostring(NVSlots.is_applied()) .. ' sides=' .. tostring(sides_open()) .. ' bottom=' .. tostring(NVSlots.is_open 'bottom'))
add('left narrower=' .. tostring(NVSlots.status().left.width < vim.o.columns / 4))
add('left provider=' .. tostring(NVSlots.status().left.provider))

-- Sizes are stable across focus mode.
local before = sizes()
NVSlots.toggle() wait()
add('focus off=' .. tostring(not NVSlots.is_applied()))
NVSlots.toggle() wait()
add('toggle stable=' .. tostring(sizes() == before))

-- Hidden panels stay hidden through focus mode; show brings them back.
NVSlots.hide 'right_mid' wait()
NVSlots.toggle() wait() NVSlots.toggle() wait()
add('hidden kept=' .. tostring(not NVSlots.is_open 'right_mid') .. ' remembered=' .. tostring(NVSlots.memory().closed.right_mid == true))
NVSlots.show 'right_mid' wait()
add('shown=' .. tostring(NVSlots.is_open 'right_mid'))

-- A panel closed outside the API is rebuilt; :only is repaired.
vim.api.nvim_win_close(NVSlots.win 'right_top', true) wait(400)
add('repaired=' .. tostring(NVSlots.is_open 'right_top'))
vim.api.nvim_set_current_win(NVSlots.content_win())
pcall(vim.cmd, 'only') wait(400)
add('only repaired=' .. tostring(sides_open()) .. ' stable=' .. tostring(sizes() == before))

-- Reading room: a narrow vsplit moves the side panels aside, closing it
-- brings them back.
vim.api.nvim_set_current_win(NVSlots.content_win())
vim.cmd 'vsplit b.txt' wait(400)
add('room sides gone=' .. tostring(not NVSlots.is_open 'left' and not NVSlots.is_open 'right_top'))
vim.cmd 'close' wait(400)
add('room sides back=' .. tostring(sides_open()))

-- Help opens in the content window (no extra split); q goes back.
local wins = #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == '' end, vim.api.nvim_tabpage_list_wins(0))
pcall(vim.cmd, 'help lua-guide') wait(400)
local now = #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == '' end, vim.api.nvim_tabpage_list_wins(0))
add('help in content=' .. tostring(vim.bo.filetype == 'help' and now == wins))
vim.cmd 'normal q' wait(300)
add('help back=' .. tostring(vim.fn.expand('%:t') == 'a.txt'))

-- Default sizes restore after a manual resize.
vim.api.nvim_win_set_width(NVSlots.win 'left', 50) wait()
pcall(NVSlots.reset_sizes or function() vim.cmd 'NVLayout reset' end) wait(300)
add('reset=' .. tostring(sizes() == before))

-- The content window closing (`:q!`, `:close`) rebuilds the layout around a
-- new content window with the same buffer; no panel becomes the content.
vim.api.nvim_set_current_win(NVSlots.content_win())
local shown = vim.api.nvim_get_current_buf()
vim.api.nvim_win_close(0, true)
wait(500)
local cw = NVSlots.content_win()
add('content rebuilt=' .. tostring(NVSlots.slot_of_win(cw) == nil and vim.api.nvim_win_get_buf(cw) == shown) .. ' sides=' .. tostring(sides_open()))

pcall(vim.cmd, 'silent! messages clear')
io.write('\n' .. table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa 2>&1)
printf '%s\n' "$got"

fail=0
check() { if ! grep -qx -- "$1" <<<"$got"; then printf 'FAIL: missing %s\n' "$1"; fail=1; fi; }
check 'applied=true sides=true bottom=true'
check 'left narrower=true'
check 'left provider=explorer'
check 'focus off=true'
check 'toggle stable=true'
check 'hidden kept=true remembered=true'
check 'shown=true'
check 'repaired=true'
check 'only repaired=true stable=true'
check 'room sides gone=true'
check 'room sides back=true'
check 'help in content=true'
check 'help back=true'
check 'reset=true'
check 'content rebuilt=true sides=true'

# ── inset in launches without a layout ─────────────────────────────────────
# A transient (and embedded) launch gets no panels: only the empty left
# column, at the explorer's width, toggled like any other panel and never
# remembered, so hiding it in a prompt cannot hide the explorer later.

gutter_probe=$(cat <<'LUA'
vim.o.columns, vim.o.lines = 200, 50
local out = {}
local function add(s) out[#out + 1] = s end
local function wait(ms) vim.wait(ms or 200) end
local function count() return vim.tbl_count(NVSlots.status()) end
local function left() return NVSlots.status().left end
local function content_x() return vim.api.nvim_win_get_position(NVSlots.content_win())[2] end

vim.cmd 'edit a.txt' wait(600)
add('gutter applied=' .. tostring(NVSlots.is_applied()) .. ' slots=' .. count() .. ' provider=' .. tostring(left() and left().provider))
add('gutter width=' .. tostring(left() and left().width) .. ' content_x=' .. content_x())

NVSlots.toggle() wait(300)
add('gutter off=' .. tostring(not NVSlots.is_applied()) .. ' x=' .. content_x())
NVSlots.toggle() wait(300)
add('gutter back=' .. tostring(NVSlots.is_applied()) .. ' slots=' .. count())

NVSlots.hide 'left' wait(200)
local mem = NVSlots.memory()
add('gutter hidden=' .. tostring(not NVSlots.is_open 'left') .. ' remembered=' .. tostring(mem.closed.left == true or mem.providers.left ~= nil))
NVSlots.toggle() wait(300)
add('gutter returns=' .. tostring(NVSlots.is_open 'left'))

NVSlots.show 'right_top' wait(300)
add('gutter panel=' .. tostring(NVSlots.is_open 'right_top' and count() == 2))

pcall(vim.cmd, 'silent! messages clear')
io.write('\n' .. table.concat(out, '\n'))
LUA
)

got=$(NVIM_LAUNCH_MODE=transient XDG_STATE_HOME="$tmp/gutter-state" nvim --headless "+lua $gutter_probe" +qa 2>&1)
printf '%s\n' "$got"
check 'gutter applied=true slots=1 provider=empty'
check 'gutter width=34 content_x=35'
check 'gutter off=true x=0'
check 'gutter back=true slots=1'
check 'gutter hidden=true remembered=false'
check 'gutter returns=true'
check 'gutter panel=true'

[ "$fail" = 0 ] && echo 'layout: pass' || { echo 'layout: FAIL'; exit 1; }
