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

local function win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative ~= '' then
      return w
    end
  end
end

local function title()
  local w = win()
  if not w then
    return 'none'
  end
  local t = vim.api.nvim_win_get_config(w).title or {}
  local parts = {}
  for _, chunk in ipairs(t) do
    parts[#parts + 1] = chunk[1]
  end
  return (table.concat(parts):gsub('^%s+', ''):gsub('%s+$', ''))
end

vim.cmd 'enew'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a short line' })

NVLspUi.open {
  { name = 'hover', lines = { 'hover text' } },
  { name = 'diagnostics', lines = { '**Error** 1:1', string.rep('long word ', 60) } },
}
add('open=' .. tostring(NVLspUi.is_open()))
add('title=' .. title())

local w = win()
add('wrap=' .. tostring(vim.wo[w].wrap) .. ' border=' .. tostring((vim.api.nvim_win_get_config(w).border ~= nil)))
add('inside=' .. tostring(vim.api.nvim_win_get_config(w).width <= vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())))

NVLspUi.next()
add('next title=' .. title())

-- Long wrapped line must grow the window, not clip it (measured on the
-- diagnostics section, which holds the long line).
local h = vim.api.nvim_win_get_config(win()).height
add('wrapped height=' .. tostring(h > 2))

NVLspUi.prev()
add('prev title=' .. title())

NVLspUi.close()
add('closed=' .. tostring(NVLspUi.is_open()))

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
check 'title=hover 1/2'
check 'wrap=true border=true'
check 'next title=diagnostics 2/2'
check 'prev title=hover 1/2'
check 'closed=false'
check 'diag order=true'
grep -q '^inside=true' <<<"$got" || { echo 'FAIL: popup wider than the window'; fail=1; }
grep -q '^wrapped height=true' <<<"$got" || { echo 'FAIL: wrapped line did not grow the popup'; fail=1; }

[ "$fail" = 0 ] && echo 'lsp-ui: pass' || { echo 'lsp-ui: FAIL'; exit 1; }
