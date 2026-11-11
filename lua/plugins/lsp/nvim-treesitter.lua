-- Treesitter setup.
--
-- nvim-treesitter is pinned to its `main` branch (the `master` branch is frozen
-- and archived). This replaces LazyVim's treesitter config, which is the only
-- thing that used to call `TS.setup()` and start parsers per FileType.

local function installed()
  local ok, list = pcall(function()
    return require('nvim-treesitter').get_installed()
  end)
  local set = {}
  for _, lang in ipairs(ok and list or {}) do
    set[lang] = true
  end
  return set
end

--- Resolve a filetype to a parser name, and report whether the parser exists.
---@param ft string
---@return string, boolean
local function parser_for(ft)
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local ok = pcall(vim.treesitter.language.add, lang)
  return lang, ok
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    version = false,
    event = { 'BufReadPre', 'BufNewFile', 'VeryLazy' },
    cmd = { 'TSUpdate', 'TSInstall', 'TSLog', 'TSUninstall', 'TSUpdateSync', 'TSInstallSync' },
    build = ':TSUpdate',
    opts = {
      indent = { enable = true },
      highlight = { enable = true },
      folds = { enable = true },
      ensure_installed = {
        'bash',
        'c',
        'cpp',
        'diff',
        'devicetree',
        'dockerfile',
        'glsl',
        'html',
        'javascript',
        'jsdoc',
        'json',
        'lua',
        'luadoc',
        'luap',
        'markdown',
        'markdown_inline',
        'printf',
        'python',
        'query',
        'regex',
        'toml',
        'tsx',
        'typescript',
        'vim',
        'vimdoc',
        'xml',
        'yaml',
      },
    },
    config = function(_, opts)
      local TS = require 'nvim-treesitter'
      TS.setup(opts)

      local have = installed()
      local missing = vim.tbl_filter(function(lang)
        return not have[lang]
      end, opts.ensure_installed or {})
      if #missing > 0 then
        TS.install(missing)
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('NV treesitter', { clear = true }),
        callback = function(ev)
          local lang, ok = parser_for(ev.match)
          if not ok then
            return
          end

          if (opts.highlight or {}).enable ~= false then
            pcall(vim.treesitter.start, ev.buf)
          end

          -- Only fill in an indent/fold expression the buffer does not already
          -- define; ftplugins and filetype files win.
          if (opts.indent or {}).enable ~= false and vim.bo[ev.buf].indentexpr == '' then
            pcall(function()
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end)
          end

          if (opts.folds or {}).enable ~= false and vim.wo.foldmethod ~= 'expr' then
            vim.wo.foldmethod = 'expr'
            vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          end

          _ = lang
        end,
      })
    end,
  },

  {
    -- a/i text objects for functions, classes, parameters.
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    event = 'VeryLazy',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      move = {
        enable = true,
        set_jumps = true,
        keys = {
          goto_next_start = { [']f'] = '@function.outer', [']c'] = '@class.outer', [']a'] = '@parameter.inner' },
          goto_next_end = { [']F'] = '@function.outer', [']C'] = '@class.outer', [']A'] = '@parameter.inner' },
          goto_previous_start = { ['[f'] = '@function.outer', ['[c'] = '@class.outer', ['[a'] = '@parameter.inner' },
          goto_previous_end = { ['[F'] = '@function.outer', ['[C'] = '@class.outer', ['[A'] = '@parameter.inner' },
        },
      },
    },
    config = function(_, opts)
      require('nvim-treesitter-textobjects').setup(opts)

      local function attach(buf)
        if not (vim.tbl_get(opts, 'move', 'enable') == true) then
          return
        end
        for method, keymaps in pairs(vim.tbl_get(opts, 'move', 'keys') or {}) do
          for key, query in pairs(keymaps) do
            vim.keymap.set({ 'n', 'x', 'o' }, key, function()
              require('nvim-treesitter-textobjects.move')[method](query, 'textobjects')
            end, { buffer = buf, desc = 'Treesitter ' .. method, silent = true })
          end
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('NV treesitter textobjects', { clear = true }),
        callback = function(ev)
          attach(ev.buf)
        end,
      })
      vim.tbl_map(attach, vim.api.nvim_list_bufs())
    end,
  },

  {
    'windwp/nvim-ts-autotag',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },

  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      enable = false,
      mode = 'cursor',
      max_lines = 3,
    },
    keys = {
      {
        '<leader>ut',
        function()
          local tsc = require 'treesitter-context'
          if tsc.enabled and tsc.enabled() then
            tsc.disable()
            NVMessages.info('Disabled Treesitter Context')
          else
            tsc.enable()
            NVMessages.info('Enabled Treesitter Context')
          end
        end,
        desc = 'Toggle Treesitter Context',
      },
    },
  },

  {
    'Wansmer/treesj',
    keys = {
      { '<leader>cj', '<cmd>TSJToggle<cr>', mode = 'n', desc = 'Join or Split Code Block' },
    },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      use_default_keymaps = false,
      max_join_length = 168,
    },
  },
}
