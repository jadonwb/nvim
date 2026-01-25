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
        mode = { 'n', 'v' },
        '<cmd>Yazi<cr>',
        desc = 'Open yazi at the current file',
      },
      {
        '<leader>E',
        '<cmd>Yazi toggle<cr>',
        desc = 'which_key_ignore',
      },
    },
    ---@type YaziConfig | {}
    opts = {
      open_for_directories = true,
      yazi_floating_window_border = 'none',
      floating_window_scaling_factor = 1,
      keymaps = {
        show_help = '<f1>',
        open_file_in_vertical_split = '<c-v>',
        open_file_in_horizontal_split = '<c-x>',
        open_file_in_tab = '<c-t>',
        grep_in_directory = '<c-g>',
        replace_in_directory = '<c-r>',
        cycle_open_buffers = false,
        copy_relative_path_to_selected_files = '<c-y>',
        send_to_quickfix_list = '<c-q>',
        change_working_directory = '<c-\\>',
        open_and_pick_window = '<c-o>',
      },
      integrations = {
        --- What should be done when the user wants to grep in a directory
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
      require('yazi.plugin').build_plugin(plugin, { sub_dir = 'full-border.yazi' })
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
    'TD-sky/sudo.yazi',
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
    'alberti42/faster-piper.yazi',
    lazy = true,
    build = function(plugin)
      require('yazi.plugin').build_plugin(plugin)
    end,
  },
}
