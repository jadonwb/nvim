local filetype = 'grug-far'

local fn = {}

NVGrugFar = {
  'MagicDuck/grug-far.nvim',
  cond = function()
    return require('config.profile').wants 'picker'
  end,
  cmd = { 'GrugFar', 'GrugFarWithin' },
  opts = {
    headerMaxWidth = 80,
    engines = {
      ripgrep = {
        -- extraArgs = "--smart-case",
      },
    },
    prefills = {
      flags = '--hidden --fixed-strings',
      filesFilter = '!.git/',
    },
    keymaps = {
      close = false,
      swapEngine = false, -- don't think I will ever use it
      swapReplacementInterpreter = false, -- same
    },
  },

  keys = {
    {
      '<leader>fr',
      function()
        if not NVCompanionPanels.ensure_exclusive 'grug-far' then
          return
        end
        fn.open_current()
      end,
      mode = { 'n', 'v' },
      desc = 'Search and Replace in current buffer',
    },
    {
      '<leader>fR',
      function()
        if not NVCompanionPanels.ensure_exclusive 'grug-far' then
          return
        end
        fn.open()
      end,
      mode = { 'n', 'v' },
      desc = 'Search and Replace in project',
    },
    { '<localleader>', '<cmd>lua require("which-key").show("\\\\")<cr>', ft = 'grug-far' },
  },
}

function fn.open()
  local plugin = require 'grug-far'

  local success, instance = pcall(plugin.get_instance)

  if success and instance then
    instance:open()
  else
    plugin.open { transient = true }
  end
end

function fn.open_current()
  local plugin = require 'grug-far'

  local success, instance = pcall(plugin.get_instance)

  if success and instance then
    instance:open()
  else
    plugin.open { transient = true, prefills = { paths = vim.fn.expand '%' } }
  end
end

function fn.toggle_flag(flag)
  local plugin = require 'grug-far'

  local instance = plugin.get_instance(0)

  if not instance then
    return
  end

  local state = unpack(instance:toggle_flags { flag })

  NVMessages.trace('grug-far: ' .. flag .. ' is set to ' .. (state and 'ON' or 'OFF'))
end

function NVGrugFar.autocmds()
  local keymap = function(key, action)
    vim.keymap.set({ 'n', 'i' }, key, action, { buffer = true })
  end

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('grug-far-custom-keybinds', { clear = true }),
    pattern = { filetype },
    callback = function()
      -- One instance only: a second :GrugFar used to stack another split in the
      -- editing area.
      local current = vim.api.nvim_get_current_win()
      pcall(vim.api.nvim_set_option_value, 'winbar', '%#NvPanelBorder# Search & Replace   %#NvChipMuted# q close ', { win = current })
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if win ~= current and vim.bo[buf].filetype == filetype then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
      -- TODO!: what this do? focuses the replace bar specifically?
      keymap('q', function()
        NVGrugFar.ensure_hidden()
      end)
      keymap('<Esc>', function()
        NVGrugFar.ensure_hidden()
      end)

      keymap('<A-Up>', function()
        vim.api.nvim_win_set_cursor(vim.fn.bufwinid(0), { 2, 0 })
        vim.cmd 'normal! $'
        vim.cmd 'startinsert!'
      end)

      keymap('<A-i>', function()
        fn.toggle_flag '--no-ignore-vcs'
      end)
      keymap('<A-h>', function()
        fn.toggle_flag '--hidden'
      end)
      keymap('<A-c>', function()
        fn.toggle_flag '--ignore-case'
      end)
      keymap('<A-r>', function()
        fn.toggle_flag '--fixed-strings'
      end)
    end,
  })
end

---@return boolean
function NVGrugFar.ensure_hidden()
  local plugin = require 'grug-far'

  local success, instance = pcall(plugin.get_instance)

  if not success or not instance then
    return false
  end

  instance:close()

  return true
end

---@return boolean
function NVGrugFar.ensure_current_hidden()
  local plugin = require 'grug-far'

  local success, instance = pcall(plugin.get_instance)

  if not success or not instance then
    return false
  end

  -- Exit insert mode before closing so focus returns to normal mode
  pcall(vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)

  instance:close()

  return true
end

---@return boolean
function fn.is_active()
  return vim.bo.filetype == filetype
end

function NVGrugFar.setup()
  NVCompanionPanels.register(filetype, NVGrugFar.ensure_hidden)
  NVClose.register(filetype, NVGrugFar.ensure_current_hidden)
end

return { NVGrugFar }
