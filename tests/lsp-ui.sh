#!/usr/bin/env bash
# Unified LSP popup: frame, sections, sizing.
#
#   tests/lsp-ui.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-lspui.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

probe=$(cat <<'LUA'
local out = {}
local function add(s) out[#out + 1] = s end

-- Volt draws with virtual text over blank lines, so the visible text has to be
-- reconstructed from extmarks.
local function visible(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local by_row = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
    local row, d = mark[2], mark[4]
    local chunk = d.virt_text and table.concat(vim.tbl_map(function(c) return c[1] end, d.virt_text)) or nil
    if chunk and chunk ~= '' then
      by_row[row] = (by_row[row] or '') .. chunk
    end
  end
  local text = {}
  for i = 0, math.max(#lines - 1, 0) do
    text[#text + 1] = by_row[i] or lines[i + 1] or ''
  end
  return table.concat(text, '\n')
end

local function win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local c = vim.api.nvim_win_get_config(w)
    if c.relative ~= '' and c.zindex == 60 then
      return w
    end
  end
end

local function text()
  local w = win()
  return w and visible(vim.api.nvim_win_get_buf(w)) or ''
end

vim.cmd 'enew'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a short line' })

NVLspUi.open {
  { name = 'hover', lines = { 'hover text' } },
  { name = 'diagnostics', lines = { '**Error** 1:1', string.rep('long word ', 60) } },
}
add('open=' .. tostring(NVLspUi.is_open()))
add('has tabs=' .. tostring(text():find('hover', 1, true) and text():find('diagnostics', 1, true) ~= nil))
add('has body=' .. tostring(text():find('hover text', 1, true) ~= nil))

local w = win()
add('inside=' .. tostring(vim.api.nvim_win_get_config(w).width <= vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())))

NVLspUi.next()
add('next body=' .. tostring(text():find('long word', 1, true) ~= nil))

-- Long wrapped line must grow the window, not clip it.
add('wrapped height=' .. tostring(vim.api.nvim_win_get_config(win()).height > 2))

NVLspUi.prev()
add('prev body=' .. tostring(text():find('hover text', 1, true) ~= nil))

NVLspUi.close()
add('closed=' .. tostring(NVLspUi.is_open()))

-- Signature section: the active parameter is marked, ranges are LSP-exclusive.
local sections = require 'features.lsp.sections'
local sig = sections.signature_chunks({
  label = 'function(name: string, count: integer)',
  parameters = { { label = { 9, 22 } }, { label = { 24, 38 } } },
}, 1)
local joined, active = '', ''
for _, c in ipairs(sig) do
  joined = joined .. c[1]
  if c[2] == 'NvSigActive' then
    active = c[1]
  end
end
add('sig label=' .. joined)
add('sig active=' .. active)

NVLspUi.open { { name = 'signature', chunks = { sig } } }
add('sig drawn=' .. tostring(text():find('function(', 1, true) ~= nil))
NVLspUi.close()

-- Diagnostics section: severity order, both entries present.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x' })
vim.diagnostic.set(vim.api.nvim_create_namespace 'test', 0, {
  { lnum = 0, col = 0, end_lnum = 0, end_col = 1, severity = vim.diagnostic.severity.HINT, message = 'hint here' },
  { lnum = 0, col = 0, end_lnum = 0, end_col = 1, severity = vim.diagnostic.severity.ERROR, message = 'error here' },
})
local section = require('features.lsp.sections').diagnostics()
local body = table.concat(section and section.lines or {}, '\n')
add('diag order=' .. tostring(body:find('Error') and body:find('Hint') and body:find('Error') < body:find('Hint')))

io.write(table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa! 2>&1)
printf '%s\n' "$got"

fail=0
check() { grep -qx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'open=true'
check 'has tabs=true'
check 'has body=true'
check 'next body=true'
check 'prev body=true'
check 'closed=false'
check 'diag order=true'
check 'sig label=function(name: string, count: integer)'
check 'sig active=name: string,'
check 'sig drawn=true'
grep -q '^inside=true' <<<"$got" || { echo 'FAIL: popup wider than the window'; fail=1; }
grep -q '^wrapped height=true' <<<"$got" || { echo 'FAIL: wrapped line did not grow the popup'; fail=1; }

[ "$fail" = 0 ] && echo 'lsp-ui: pass' || { echo 'lsp-ui: FAIL'; exit 1; }
