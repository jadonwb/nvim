-- Global LSP/diagnostic keymaps.
--
-- Buffer-local LSP keymaps (K, gK, gd, gr, …) are attached in
-- config/lsp.lua because they only exist when a client is attached; these few
-- are global because they act on the diagnostic list.

local M = {}

function M.setup()
  -- Diagnostic jumps are Neovim's own ]d / [d (and ]D / [D).
  -- Line diagnostics are a section of the K popup.

  -- K opens the hover menu everywhere a file is edited. A client's own K
  -- (features/lsp/init.lua) is buffer-local and wins where one attaches; this
  -- fallback covers the time before that, and filetypes with no server, where
  -- native K would run 'keywordprg' instead (`:help` in Lua buffers, see
  -- after/ftplugin/lua.lua). Special buffers keep Vim's K.
  vim.keymap.set('n', 'K', function()
    if vim.bo.buftype ~= '' then
      return vim.cmd 'normal! K'
    end
    require('features.lsp.ui').show_at_cursor()
  end, { desc = 'Hover' })
end

return M
