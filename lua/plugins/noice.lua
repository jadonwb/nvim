NVNoice = {}

local fn = {}

function NVNoice.ensure_hidden()
  if fn.ensure_command_line_hidden() then
    return true
  end

  if fn.ensure_signature_hidden() then
    return true
  end

  if fn.is_noice_window() then
    fn.close_split()
    return true
  end

  return false
end

function fn.ensure_command_line_hidden()
  if vim.fn.mode() == 'c' then
    NVKeys.send('<Esc>', { mode = 'n' })
    return true
  end
  return false
end

function fn.ensure_signature_hidden()
  local ok, noice = pcall(require, 'noice')
  if not ok then
    return false
  end
  local ok2, lsp = pcall(require, 'noice.lsp')
  if not ok2 then
    return false
  end
  local ok3, docs = pcall(require, 'noice.lsp.docs')
  if not ok3 then
    return false
  end
  local signature = docs.get(lsp.kinds.signature)
  if #signature:wins() == 0 then
    return false
  end
  docs.hide(signature)
  return true
end

function fn.is_noice_window()
  return vim.bo.filetype == 'noice'
end

function fn.close_split()
  vim.cmd.close()
end

--- noice.nvim custom configuration.

return {
  'folke/noice.nvim',
  event = 'VeryLazy',

  config = function(_, opts)
    local is_large = NVScreen.is_large()

    local common_border = {
      style = 'none',
      padding = { top = 1, bottom = 1, left = 2, right = 2 },
    }

    local common_win_opts = {
      winhighlight = {
        Normal = 'NormalFloat',
        FloatBorder = 'FloatBorder',
      },
      winbar = '',
      foldenable = false,
    }

    opts = vim.tbl_deep_extend('force', {
      -- LSP: hover disabled (uses custom lsp-popup), signature via hint
      lsp = {
        hover = { enabled = false },
        signature = { enabled = true, view = 'hint' },
        progress = { enabled = false },
      },

      -- Notify: snacks handles notifications
      notify = { enabled = false },

      -- Cmdline format
      cmdline = {
        format = {
          cmdline = { pattern = '^:', icon = '❯', lang = 'vim' },
          search_down = { view = 'cmdline', icon = '  ' },
          search_up = { view = 'cmdline', icon = '  ' },
        },
      },

      -- Status: LSP progress via lualine, not noice
      status = {},

      -- Commands
      commands = {
        all = {
          view = 'popup',
          opts = { enter = true, format = 'details' },
          filter_opts = { reverse = true },
          filter = {},
        },
      },

      -- Views
      views = {
        popup = {
          backend = 'popup',
          relative = 'editor',
          position = { row = '40%', col = '50%' },
          border = common_border,
          size = {
            width = NVLayoutManager.default_width(),
            height = NVScreen.is_large() and 30 or 15,
          },
          win_options = common_win_opts,
          close = {
            events = { 'BufLeave' },
            keys = { 'q', '<Esc>', '<C-c>' },
          },
        },
        hint = {
          backend = 'popup',
          relative = 'cursor',
          size = {
            width = 'auto',
            height = 'auto',
            max_height = 20,
            max_width = 120,
          },
          position = { row = common_border.padding.top + 1, col = 0 },
          border = common_border,
          win_options = { wrap = true, linebreak = true },
          close = { keys = { 'q', '<Esc>', '<C-c>' } },
        },
        cmdline = {
          position = { row = vim.o.lines, col = '50%' },
          size = { width = 60, height = 1 },
        },
        cmdline_popup = {
          position = { row = 10, col = '50%' },
          size = { width = 60, height = 'auto' },
          border = common_border,
          win_options = common_win_opts,
          filter_options = {},
          close = { keys = { 'q', '<Esc>', '<C-c>' } },
        },
        cmdline_popupmenu = {
          position = { row = 14, col = '50%' },
          size = { width = 60, height = 'auto' },
          border = common_border,
          win_options = common_win_opts,
          close = { keys = { 'q', '<Esc>', '<C-c>' } },
        },
        cmdline_output = {
          enter = true,
          format = 'details',
          view = 'popup',
        },
        confirm = {
          backend = 'popup',
          relative = 'editor',
          focusable = false,
          align = 'center',
          enter = false,
          zindex = 210,
          format = { '{confirm}' },
          position = { row = 3, col = '50%' },
          size = 'auto',
          border = {
            style = common_border.style,
            padding = common_border.padding,
            text = { top = ' Confirm ' },
          },
          win_options = common_win_opts,
        },
      },

      -- Routes
      routes = {
        { filter = { event = 'lsp', kind = 'progress' }, opts = { skip = true } },
      },
    }, opts or {})

    require('noice').setup(opts)
  end,

  -- Keymaps
  keys = {
    -- Notification history (like Alex's <D-S-l>, adapted for Linux)
    { '<M-S-l>', '<Cmd>NoiceAll<CR>', mode = { 'n', 'i', 'v' }, desc = 'Notification History' },
  },
}
