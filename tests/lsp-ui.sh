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
export NV_LSP_HUNK_FILE="$tmp/repo/hunk.lua"
git init -q "$tmp/repo" || exit 1
printf '%s\n' '-- before' 'local paint = "warm red"' '-- after' >"$NV_LSP_HUNK_FILE"
git -C "$tmp/repo" add hunk.lua || exit 1
printf '%s\n' '-- before' 'local paint = "warm tan"' '-- after' >"$NV_LSP_HUNK_FILE"

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

-- A line that wraps in the placeholder-width float must not leave the popup
-- wider than its text once it is widened: the next render agrees on the width.
NVLspUi.open { { name = 'hover', lines = { 'alpha beta gamma delta x' } } }
menu, content = popup()
local width_open = vim.api.nvim_win_get_width(content)
NVLspUi.next()
add('stable width=' .. tostring(width_open == vim.api.nvim_win_get_width(content)))

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

-- Open the same hunk section as K and verify the rendered popup buffer.
vim.cmd.edit(vim.env.NV_LSP_HUNK_FILE)
local gs = require 'gitsigns'
assert(vim.wait(5000, function() return #(gs.get_hunks() or {}) == 1 end), 'Gitsigns did not attach')
vim.treesitter.start(0, 'lua')
vim.api.nvim_win_set_cursor(0, { 2, 0 })
NVLspUi.open { { name = 'hover', lines = { 'hover text' } }, assert(S.hunk()) }
NVLspUi.next()
menu, content = popup()
add('hunk body=' .. tostring(text(content) == 'change · line 2  -1 +1\n-local paint = "warm red"\n+local paint = "warm tan"'))
local buf = vim.api.nvim_win_get_buf(content)
local marks = vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_get_namespaces()['nv-lsp-ui'], 0, -1, { details = true })
local row_hls, changed, syntax = {}, {}, {}
for _, mark in ipairs(marks) do
  local row, col, d = mark[2], mark[3], mark[4]
  if d.line_hl_group then
    row_hls[row] = d.line_hl_group
  end
  if type(d.hl_group) == 'string' and d.hl_group:match('^GitSigns.*Inline$') then
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    changed[row] = line:sub(col + 1, d.end_col)
  end
  if type(d.hl_group) == 'string' and d.hl_group:find('string', 1, true) then
    syntax[row] = true
  end
end
add('hunk row tints=' .. tostring(row_hls[1] == 'DiffDelete' and row_hls[2] == 'DiffAdd'))
add('hunk word tints=' .. tostring(changed[1] == 'red' and changed[2] == 'tan'))
add('hunk syntax=' .. tostring(syntax[1] and syntax[2] or false))
NVLspUi.focus()
add('hunk actions=' .. tostring(vim.fn.maparg('s', 'n', false, true).desc == 'stage' and vim.fn.maparg('r', 'n', false, true).desc == 'reset'))
NVLspUi.close()

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
check 'stable width=true'
check 'external close=true'
check 'tab released=true'
check 'diag order=true'
check 'vimdoc fence=true'
check 'tilde=see \~/.vimrc and `~/x`'
check 'chained=example:|```vim|  echo 1|```|```vim|  echo 2|```'
check 'on name=false'
check 'on arg=true'
check 'hunk body=true'
check 'hunk row tints=true'
check 'hunk word tints=true'
check 'hunk syntax=true'
check 'hunk actions=true'

[ "$fail" = 0 ] && echo 'lsp-ui: pass' || { echo 'lsp-ui: FAIL'; exit 1; }
