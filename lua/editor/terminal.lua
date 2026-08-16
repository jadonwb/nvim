NVTerminal = {}

local fn = {}

function NVTerminal.keymaps()
  K.map { '<C-v>', 'Paste text', fn.paste, mode = 't', expr = true }
  K.map { NVKeymaps.scroll.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_alt.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_ctx.up, 'Lazygit: Scroll up main panel', '<C-\\><C-u>', mode = 't' }
  K.map { NVKeymaps.scroll_ctx.down, 'Lazygit: Scroll down main panel', '<C-\\><C-d>', mode = 't' }

  K.map { '<C-/>', 'Toggle vsplit terminal', NVTerminal.open_vsplit, mode = { 'n', 'v', 'i', 't' } }
  K.map { '<C-_>', 'Toggle vsplit terminal', NVTerminal.open_vsplit, mode = { 'n', 'v', 'i', 't' } }

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'snacks_terminal',
    callback = function()
      K.map { '&', 'Enter terminal mode', 'i', mode = 'n', buffer = true }
      K.map { '&', 'Enter terminal mode', '<Esc>i', mode = 'v', buffer = true }
    end,
  })
end

--- Toggle a vsplit terminal on the right side of the current tab.
--- Delegates to Snacks.terminal.toggle for all state management.
--- Integrates with companion panels for mutual exclusion.
function NVTerminal.open_vsplit()
  if not NVCompanionPanels.ensure_exclusive 'terminal_vsplit' then
    return
  end
  Snacks.terminal.toggle(nil, {
    win = {
      position = 'right',
      relative = 'editor',
      width = NVCompanionPanels.width(),
    },
  })
end

NVCompanionPanels.register('terminal_vsplit', function()
  local term = Snacks.terminal.get(nil, { create = false })
  if term and term:valid() then
    term:hide()
    return true
  end
  return false
end)

function NVTerminal.ensure_vsplit_hidden()
  local term = Snacks.terminal.get(nil, { create = false })
  if term then
    term:hide()
    return true
  end
  return false
end

function fn.paste()
  local content = vim.fn.getreg '*'
  content = vim.api.nvim_replace_termcodes(content, true, true, true)
  vim.api.nvim_feedkeys(content, 't', true)
end

NVClose.register('terminal_vsplit', function()
  return NVTerminal.ensure_vsplit_hidden()
end)
