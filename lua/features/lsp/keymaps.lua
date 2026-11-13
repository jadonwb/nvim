-- Global LSP/diagnostic keymaps.
--
-- Buffer-local LSP keymaps (K, gK, gd, gr, …) are attached in
-- config/lsp.lua because they only exist when a client is attached; these few
-- are global because they act on the diagnostic list.

local M = {}

function M.setup()
  -- Diagnostic jumps are Neovim's own ]d / [d (and ]D / [D).
  -- Line diagnostics are a section of the K popup.
end

return M
