-- Leader keys for the editor's own UI: layout and panels, dashboards
-- (views), terminals, plugins. Plugin and Neovim defaults stay on their own
-- keys; this file is the one place these groups are defined.
--
--   <leader>l  layout    li focus · le lc lo ls lb panel toggles · l0 sizes ·
--                        lw swap panel · lv lm lx compare
--   <leader>v  views     vl LSP · vg Git · vo OpenCode dashboards
--   <leader>t  terminals tt pick · tn new · tb tf tc place/move · t] t[
--   <leader>p  plugins   pl Lazy · pu update · pm Mason
--   <leader>fe           toggle the file explorer

local M = {}

local function map(lhs, desc, rhs, mode)
  K.map { lhs, desc, rhs, mode = mode or 'n' }
end

local function panel(name)
  return function()
    if not NVSlots.is_applied() then
      NVSlots.toggle()
    end
    if name == 'bottom' then
      return NVBottom.toggle()
    end
    NVSlots.toggle_slot(name)
  end
end

local function view(name)
  return function()
    require('features.ui.dashboards').open(name)
  end
end

function M.setup()
  -- Layout and panels. A panel toggle also brings back a hidden panel.
  map('<leader>li', 'Focus mode (toggle layout)', NVSlots.toggle)
  map('<leader>le', 'Panel: explorer', panel 'left')
  map('<leader>fe', 'File explorer (toggle)', panel 'left')
  map('<leader>lc', 'Panel: changes', panel 'right_top')
  map('<leader>lo', 'Panel: OpenCode', panel 'right_mid')
  map('<leader>ls', 'Panel: LSP', panel 'right_bottom')
  map('<leader>lb', 'Panel: bottom', panel 'bottom')
  map('<leader>l0', 'Reset panel sizes', NVSlots.reset_sizes)
  map('<leader>lw', 'Swap this panel with…', function()
    if NVSlots.slot_of_win(vim.api.nvim_get_current_win()) then
      NVWindows.reposition 'swap'
    else
      NVMessages.info 'Focus a panel first'
    end
  end)
  map('<leader>lv', 'Compare: file side by side', function()
    NVCompare.file()
  end)
  map('<leader>lm', 'Compare: man page side by side', function()
    NVCompare.man()
  end)
  map('<leader>lx', 'Compare: close', function()
    NVCompare.close()
  end)

  -- Dashboards.
  map('<leader>vl', 'View: LSP dashboard', view 'lsp')
  map('<leader>vg', 'View: Git dashboard', view 'changes')
  map('<leader>vo', 'View: OpenCode dashboard', view 'session')

  -- Terminals.
  map('<leader>tt', 'Pick terminal', NVTerminals.pick)
  map('<leader>tn', 'New terminal (panel)', function()
    NVTerminals.new 'panel'
  end)
  map('<leader>tb', 'Terminal in bottom panel', function()
    NVTerminals.place 'panel'
  end)
  map('<leader>tf', 'Floating terminal (toggle)', function()
    NVTerminals.place 'float'
  end)
  map('<leader>tc', 'Terminal in main window', function()
    NVTerminals.place 'content'
  end)
  map('<leader>t]', 'Next terminal', function()
    NVTerminals.cycle(1)
  end)
  map('<leader>t[', 'Previous terminal', function()
    NVTerminals.cycle(-1)
  end)

  -- Plugins.
  map('<leader>pl', 'Lazy', '<Cmd>Lazy<CR>')
  map('<leader>pu', 'Update plugins', function()
    require('lazy').update()
  end)
end

return M
