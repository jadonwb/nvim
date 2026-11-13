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

-- The popup is two floats: a menu (not focusable) and the content.
local function popup()
  local menu, content
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.w[w].nv_lsp_popup then
      if vim.api.nvim_win_get_config(w).focusable then
        content = w
      else
        menu = w
      end
    end
  end
  return menu, content
end
local function text(w)
  return w and table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), '\n') or ''
end

vim.cmd 'enew'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a short line' })

NVLspUi.open {
  { name = 'hover', lines = { 'hover text' } },
  { name = 'diagnostics', lines = { 'Error  1:1', string.rep('long word ', 60) } },
}
local menu, content = popup()
add('open=' .. tostring(NVLspUi.is_open()))
add('menu lists=' .. tostring(text(menu):find('hover', 1, true) ~= nil and text(menu):find('diagnostics', 1, true) ~= nil))
add('has body=' .. tostring(text(content):find('hover text', 1, true) ~= nil))
add('inside=' .. tostring(vim.api.nvim_win_get_width(content) <= vim.api.nvim_win_get_width(0)))

NVLspUi.next()
add('next body=' .. tostring(text(content):find('long word', 1, true) ~= nil))
add('wrapped height=' .. tostring(vim.api.nvim_win_get_height(content) > 2))
NVLspUi.prev()
add('prev body=' .. tostring(text(content):find('hover text', 1, true) ~= nil))

-- One section: still a menu (same shape every time).
NVLspUi.open { { name = 'hover', lines = { 'only' } } }
menu, content = popup()
add('single has menu=' .. tostring(menu ~= nil and content ~= nil))

-- Closing the content externally (:q, <C-w>c) takes everything down.
NVLspUi.open {
  { name = 'hover', lines = { 'a' } },
  { name = 'diagnostics', lines = { 'Error  1:1', 'b' } },
}
menu, content = popup()
vim.api.nvim_win_close(content, true)
vim.wait(100)
local left = 0
for _, w in ipairs(vim.api.nvim_list_wins()) do
  if vim.w[w].nv_lsp_popup then
    left = left + 1
  end
end
add('external close=' .. tostring(NVLspUi.is_open() == false and left == 0))
add('tab released=' .. tostring(vim.fn.maparg('<Tab>', 'n', false, true).buffer ~= 1))
NVLspUi.close()

local S = require 'features.lsp.sections'

-- Diagnostics: most severe first.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x' })
vim.diagnostic.set(vim.api.nvim_create_namespace 'test', 0, {
  { lnum = 0, col = 0, end_lnum = 0, end_col = 1, severity = vim.diagnostic.severity.HINT, message = 'hint here' },
  { lnum = 0, col = 0, end_lnum = 0, end_col = 1, severity = vim.diagnostic.severity.ERROR, message = 'error here' },
})
local body = table.concat(S.diagnostics().lines, '\n')
add('diag order=' .. tostring(body:find('Error') ~= nil and body:find('Error') < body:find('Hint')))

-- Vim help inside markdown: >vim … < becomes a fence, ~ is escaped in prose.
local n = S._normalize { 'use it like: >vim', '  echo 1', '<', 'see ~/.vimrc and `~/x`' }
add('vimdoc fence=' .. tostring(n[2] == '```vim' and n[4] == '```'))
add('tilde=' .. n[5])
local chained = S._normalize { 'example: >vim', '  echo 1', '< >vim', '  echo 2', '<' }
add('chained=' .. table.concat(chained, '|'))

-- Signature only inside a call's arguments.
vim.bo.filetype = 'lua'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo(alpha, beta)' })
vim.treesitter.get_parser(0, 'lua'):parse()
vim.api.nvim_win_set_cursor(0, { 1, 1 })
add('on name=' .. tostring(S.in_arguments()))
vim.api.nvim_win_set_cursor(0, { 1, 5 })
add('on arg=' .. tostring(S.in_arguments()))

io.write('\n' .. table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa! 2>&1)
printf '%s\n' "$got"

fail=0
check() { grep -Fqx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'open=true'
check 'menu lists=true'
check 'has body=true'
check 'inside=true'
check 'next body=true'
check 'wrapped height=true'
check 'prev body=true'
check 'single has menu=true'
check 'external close=true'
check 'tab released=true'
check 'diag order=true'
check 'vimdoc fence=true'
check 'tilde=see \~/.vimrc and `~/x`'
check 'chained=example:|```vim|  echo 1|```|```vim|  echo 2|```'
check 'on name=false'
check 'on arg=true'

[ "$fail" = 0 ] && echo 'lsp-ui: pass' || { echo 'lsp-ui: FAIL'; exit 1; }
