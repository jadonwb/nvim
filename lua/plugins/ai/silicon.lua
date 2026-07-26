return {
  '0oAstro/silicon.lua',
  dependencies = { 'nvim-lua/plenary.nvim' },
  cmd = 'Silicon',
  opts = {
    font = 'monospace',
    theme = 'auto', -- auto-generates from current colorscheme
    bg_color = nil, -- uses colorscheme background
    round_corner = true,
    window_controls = true,
    line_number = true,
    line_offset = 1,
    line_pad = 2,
    pad_horiz = 80,
    pad_vert = 100,
    shadow_blur_radius = 10,
    shadow_color = '#555555',
    shadow_offset_x = 8,
    shadow_offset_y = 8,
    gobble = false,
    debug = false,
    output = function()
      return vim.fn.stdpath('cache') .. '/pi-screenshots/silicon_' .. os.date('%Y-%m-%d_%H-%M-%S') .. '.png'
    end,
  },
  keys = {
    -- Visual selection → image
    {
      '<Leader>is',
      function()
        require('silicon').visualise_api({ to_clip = false })
      end,
      mode = 'v',
      desc = 'Silicon: Screenshot selection',
    },
    -- Visual selection → whole buffer image with selection highlighted
    {
      '<Leader>iS',
      function()
        require('silicon').visualise_api({ to_clip = false, show_buf = true })
      end,
      mode = 'v',
      desc = 'Silicon: Full buffer + highlight selection',
    },
    -- Current buffer line → image
    {
      '<Leader>il',
      function()
        require('silicon').visualise_api({ to_clip = false })
      end,
      mode = 'n',
      desc = 'Silicon: Screenshot current line',
    },
    -- Visible portion of buffer → image
    {
      '<Leader>iv',
      function()
        require('silicon').visualise_api({ to_clip = false, visible = true })
      end,
      mode = 'n',
      desc = 'Silicon: Screenshot visible portion',
    },
    -- Screenshot selection and attach to pi
    {
      '<Leader>ip',
      function()
        require('utils.screenshot').screenshot_and_attach()
      end,
      mode = 'v',
      desc = 'Screenshot selection → Pi',
    },
    -- Screenshot full buffer (with selection highlighted) and attach to pi
    {
      '<Leader>iP',
      function()
        require('utils.screenshot').screenshot_and_attach({ show_buf = true })
      end,
      mode = 'v',
      desc = 'Screenshot full buffer → Pi',
    },
  },

  -- ── auto-regenerate theme on colorscheme change ───────────
  config = function(_, opts)
    require('silicon').setup(opts)

    vim.api.nvim_create_autocmd('ColorScheme', {
      group = vim.api.nvim_create_augroup('SiliconRefresh', { clear = true }),
      callback = function()
        local utils = require('silicon.utils')
        utils.build_tmTheme()
        utils.reload_silicon_cache({ async = true })
      end,
      desc = 'Reload silicon theme cache on colorscheme switch',
    })
  end,
}
