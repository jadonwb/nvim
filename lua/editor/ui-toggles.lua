-- The `<leader>u` toggle group.
--
-- Every entry here came from LazyVim's config/keymaps.lua and is built on
-- snacks' toggle API, so the toggles report their state in the message area and
-- stay in sync with the option they flip.
NVUIToggles = {}

---@param lhs string
---@param toggle table
local function map_toggle(lhs, toggle)
  pcall(function()
    toggle:map(lhs)
  end)
end

function NVUIToggles.keymaps()
  local ok, Snacks = pcall(require, 'snacks')
  if not ok then
    return
  end
  local t = Snacks.toggle

  map_toggle('<leader>ud', t.diagnostics())
  map_toggle('<leader>ul', t.line_number())
  map_toggle('<leader>uL', t.option('relativenumber', { name = 'Relative Number' }))
  map_toggle('<leader>us', t.option('spell', { name = 'Spelling' }))
  map_toggle('<leader>uw', t.option('wrap', { name = 'Wrap' }))
  map_toggle('<leader>uA', t.option('showtabline', { off = 0, on = 2, name = 'Tabline' }))
  map_toggle(
    '<leader>uc',
    t.option('conceallevel', {
      off = 0,
      on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
      name = 'Conceal Level',
    })
  )
  map_toggle('<leader>ub', t.option('background', { off = 'light', on = 'dark', name = 'Dark Background' }))
  map_toggle('<leader>uT', t.treesitter())
  map_toggle('<leader>uD', t.dim())
  map_toggle('<leader>ua', t.animate())
  map_toggle('<leader>ug', t.indent())
  map_toggle('<leader>uS', t.scroll())
  map_toggle('<leader>uh', t.inlay_hints())

  local map = vim.keymap.set

  map('n', '<leader>ui', function()
    require 'features.lsp.ui'
    NVLspUi.show_inspect()
  end, { desc = 'Inspect highlights at cursor' })
  map('n', '<leader>uI', function()
    vim.treesitter.inspect_tree()
    vim.api.nvim_input 'I'
  end, { desc = 'Inspect Tree' })
  map('n', '<leader>ur', '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>', { desc = 'Redraw / Clear hlsearch / Diff Update' })
  map('n', '<leader>uC', function()
    Snacks.picker.colorschemes()
  end, { desc = 'Colorschemes' })
  map('n', '<leader>up', function()
    require('features.preview').toggle()
  end, { desc = 'Toggle file preview' })

  map('n', '<leader>un', function()
    require('features.ui.notify').clear()
  end, { desc = 'Clear notifications' })

  map('n', '<leader>uf', NVFormat.toggle_global, { desc = 'Toggle Auto Format (Global)' })
  map('n', '<leader>uF', NVFormat.toggle_buffer, { desc = 'Toggle Auto Format (Buffer)' })
end
