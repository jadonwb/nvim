return {
  {
    'mikavilpas/yazi.nvim',
    event = 'VeryLazy',
    dependencies = {
      'folke/snacks.nvim',
    },
    keys = {
      {
        '<leader>e',
        '<cmd>Yazi toggle<cr>',
        desc = 'which_key_ignore',
      },
      {
        '<A-E>',
        mode = { 'n', 'v' },
        '<cmd>Yazi cwd<cr>',
        desc = 'which_key_ignore',
      },
      {
        '<A-e>',
        mode = { 'n', 'v' },
        '<cmd>Yazi<cr>',
        desc = 'which_key_ignore',
      },
    },
    ---@type YaziConfig | {}
    opts = {
      open_for_directories = true,
      yazi_floating_window_border = 'none',
      yazi_floating_window_zindex = 999,
      floating_window_scaling_factor = 1,
      keymaps = {
        show_help = '?',
        open_file_in_vertical_split = NVKeymaps.open_vsplit,
        open_file_in_horizontal_split = NVKeymaps.open_hsplit,
        open_file_in_tab = '<C-t>',
        grep_in_directory = '<C-g>',
        replace_in_directory = '<C-r>',
        cycle_open_buffers = '<C-o>',
        copy_relative_path_to_selected_files = '<C-y>',
        send_to_quickfix_list = '<C-q>',
        change_working_directory = '<C-CR>',
        open_and_pick_window = false,
      },
      integrations = {
        -- TODO!: use my styled fff picker, if fff capable, or use snacks but styled same
        grep_in_directory = 'snacks.picker',
        grep_in_selected_files = 'snacks.picker',
      },
    },
    init = function()
      -- More details: https://github.com/mikavilpas/yazi.nvim/issues/802
      -- vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
  },
  {
    -- https://github.com/yazi-rs/plugins
    'yazi-rs/plugins',
    name = 'yazi-rs-plugins',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin, { sub_dir = 'git.yazi' })
      require('yazi.plugin').build_plugin(plugin, { sub_dir = 'chmod.yazi' })
      require('yazi.plugin').build_plugin(plugin, { sub_dir = 'mount.yazi' })
    end,
  },
  {
    'ndtoan96/ouch.yazi',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin)
    end,
  },
  {
    'grappas/wl-clipboard.yazi',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin)
    end,
  },
  {
    'atareao/convert.yazi',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin)
    end,
  },
  {
    'GianniBYoung/rsync.yazi',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin)
    end,
  },
  {
    'MasouShizuka/close-and-restore-tab.yazi',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin)
    end,
  },
}
