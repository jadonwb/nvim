NVTerminal = {}

function NVTerminal.keymaps()
  K.map { NVKeymaps.scroll.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_alt.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }

  K.map { '<C-/>', 'Toggle terminal', NVTerminal.toggle, mode = { 'n', 'v', 'i', 't' } }
  K.map { '<C-_>', 'Toggle terminal', NVTerminal.toggle, mode = { 'n', 'v', 'i', 't' } }

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'snacks_terminal',
    callback = function(event)
      K.map { '&', 'Enter terminal mode', 'i', mode = 'n', buffer = true }
      K.map { '&', 'Enter terminal mode', '<Esc>i', mode = 'v', buffer = true }

      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(event.buf) then
          return
        end

        if NVSTerminal.is_app('lazygit', event.buf) then
          K.map {
            NVKeymaps.scroll_ctx.up,
            'Lazygit: Scroll up main panel',
            '<C-\\><C-u>',
            mode = 't',
            buffer = event.buf,
          }
          K.map {
            NVKeymaps.scroll_ctx.down,
            'Lazygit: Scroll down main panel',
            '<C-\\><C-d>',
            mode = 't',
            buffer = event.buf,
          }
          K.map {
            '<C-w>',
            'Lazygit: Toggle Whitespace',
            '<C-\\><C-w>',
            mode = 't',
            buffer = event.buf,
          }
          K.map {
            '<C-t>',
            'Lazygit: Open difftool',
            '<C-\\><C-t>',
            mode = 't',
            buffer = event.buf,
          }
        end
      end)
    end,
  })
end

--- Toggle the terminal at the bottom of the editor.
--- Delegates to Snacks.terminal.toggle for all state management.
function NVTerminal.toggle()
  Snacks.terminal.toggle(nil, {
    win = { position = 'bottom', height = 0.32 },
  })
end

function NVTerminal.ensure_hidden()
  local term = Snacks.terminal.get(nil, { create = false })
  if term and term:valid() then
    term:hide()
    return true
  end
  return false
end

function NVTerminal.setup()
  NVClose.register('terminal', NVTerminal.ensure_hidden)
end
