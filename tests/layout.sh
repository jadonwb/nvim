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
vim.cmd 'NVLayout close'
add('close wins=' .. wins() .. ' applied=' .. tostring(NVSlots.is_applied()))
vim.cmd 'NVLayout open'
add('reopen wins=' .. wins())
vim.cmd 'NVLayout close'
add('final wins=' .. wins())

io.write(table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa 2>&1)
printf '%s\n' "$got"

fail=0
check() { if ! grep -qx -- "$1" <<<"$got"; then printf 'FAIL: missing %s\n' "$1"; fail=1; fi; }
check 'start wins=1'
check 'open wins=6 slots=5 applied=true'
check 'right halves=true'
check 'close wins=1 applied=false'
check 'reopen wins=6'
check 'final wins=1'
grep -q 'ratios=true' <<<"$got" || { echo 'FAIL: left column not narrower than right'; fail=1; }

[ "$fail" = 0 ] && echo 'layout: pass' || { echo 'layout: FAIL'; exit 1; }
