-- === Wrapper functions (set globals on load) ===

NVGitsigns = {}

function NVGitsigns.ensure_preview_hidden()
  local ok, gs = pcall(require, 'gitsigns')
  if not ok then
    return false
  end
  if gs.popup and gs.popup.handler and gs.popup.handler.close then
    gs.popup.handler.close()
    return true
  end
  return false
end

return {
  'lewis6991/gitsigns.nvim',
  opts = {
    signs = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '' },
      topdelete = { text = '' },
      changedelete = { text = '▎' },
      untracked = { text = '▎' },
    },
    signs_staged = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '' },
      topdelete = { text = '' },
      changedelete = { text = '▎' },
      untracked = { text = '▎' },
    },
    on_attach = function()
      -- Delta replaces all interactive gitsigns operations.
      -- Gitsigns only serves passive gutter indicators.
    end,
  },
}
