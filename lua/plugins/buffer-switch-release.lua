return {
  dir = vim.fn.stdpath 'config' .. '/lua/buffer_switch',
  name = 'buffer-switch-release',
  opts = {
    keymap = {
      trigger = ';',
      toggle_action = 'close', -- 'close', 'confirm', or 'cycle'
      auto_map = true,
    },
    search_dir = function()
      return { vim.fn.getcwd() }
    end,
    sort_fn = function(a, b)
      return (a.lastused or 0) > (b.lastused or 0)
    end,
    mappings = {
      ['<C-f>'] = function()
        vim.cmd 'FzfLua buffers'
      end,
    },
    snipe = {
      enabled = true,
      keys = {
        'a',
        's',
        'd',
        'f',
        'q',
        'w',
        'e',
        'r',
        't',
        'z',
        'x',
        'c',
        'v',
        'b',
        '1',
        '2',
        '3',
        '4',
        '5',
      },
    },
    window = {
      width = 0.4,
      max_height = 15,
      border = 'rounded',
      title = ' Buffers ',
      title_pos = 'center',
      enable_devicons = true,
    },
  },
  config = function(_, opts)
    require('buffer_switch').setup(opts)
  end,
}
