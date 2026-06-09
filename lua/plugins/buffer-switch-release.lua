return {
  'tomkhoailang/buffer-switch-release',
  opts = {
    -- Key configuration
    keymap = {
      hold = 'control', -- "control", "alt", "shift", or "super"
      navigate = ';', -- key pressed to trigger/navigate
      auto_map = true, -- automatically register the trigger keymap in Neovim
    },

    -- Directories to filter buffers (returns string or list of strings)
    search_dir = function()
      return { vim.fn.getcwd() }
    end,

    -- Sorting strategy
    sort_fn = function(a, b)
      return (a.lastused or 0) > (b.lastused or 0)
    end,

    -- Mappings active only while the switcher menu is open
    mappings = {
      ['<C-f>'] = function()
        vim.cmd 'FzfLua buffers'
      end,
    },

    -- 'l',
    -- ';',
    -- "'",
    -- 'h',
    -- Snipe quick-jump options
    snipe = {
      enabled = true,
      keys = {
        'j',
        'k',
        'l',
        'h',
        'n',
        'y',
        'u',
        'o',
        'p',
        ',',
        '.',
        'a',
        's',
        'd',
        'w',
        'r',
        'x',
        'v',
        't',
        'q',
        'z',
        'b',
        'g',
      },
    },

    -- Window styling
    window = {
      width = 84, -- Use an integer (columns) or float (0.0 to 1.0 for % of screen width)
      max_height = 15, -- Max rows to show
      border = 'rounded', -- "single", "double", "rounded", "shadow", or "none"
      title = ' Switch Buffer ',
      title_pos = 'center',
      enable_devicons = true, -- Requires nvim-web-devicons
    },

    -- Backend/Python executable configuration
    python = {
      executable = nil, -- Auto-detected if nil (searches python3, then python)
      timeout = 10.0, -- Maximum run duration for the background daemon in seconds
    },
  },
  config = function(_, opts)
    require('buffer_switch').setup(opts)
  end,
}
