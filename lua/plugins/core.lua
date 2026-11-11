-- Plugins that LazyVim provided, kept because this config uses them.
--
-- Each entry is here for a concrete user: grep for the plugin name before
-- removing one. Anything not listed here that used to arrive with LazyVim
-- (bufferline, noice, flash, persistence, mini.pairs, catppuccin, tokyonight,
-- dashboard-nvim, SchemaStore, friendly-snippets) is intentionally not
-- installed any more.
return {
  { 'nvim-lua/plenary.nvim', lazy = true },

  {
    'nvim-mini/mini.icons',
    lazy = true,
    opts = {},
  },

  {
    -- Highlight colours in code: #aabbcc, named CSS colours, Tailwind classes.
    'nvim-mini/mini.hipatterns',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = function()
      local hi = require 'mini.hipatterns'
      return {
        highlighters = {
          hex_color = hi.gen_highlighter.hex_color { priority = 2000 },
          shorthand = {
            pattern = '()#%x%x%x()%f[^%x%w]',
            group = function(_, _, data)
              local match = data.full_match
              if match == '#add' then
                return
              end
              local r, g, b = match:sub(2, 2), match:sub(3, 3), match:sub(4, 4)
              return MiniHipatterns.compute_hex_color_group('#' .. r .. r .. g .. g .. b .. b, 'bg')
            end,
            extmark_opts = { priority = 2000 },
          },
        },
      }
    end,
  },

  {
    -- Comment syntax per language, including the awkward nested cases.
    'folke/ts-comments.nvim',
    event = 'VeryLazy',
    opts = {},
  },

  {
    -- LuaLS library support while editing this config.
    'folke/lazydev.nvim',
    ft = 'lua',
    cmd = 'LazyDev',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  -- Chezmoi: filetype detection for templates, and :ChezmoiEdit so editing a
  -- managed file goes through chezmoi instead of writing the deployed copy.
  {
    'alker0/chezmoi.vim',
    init = function()
      vim.g['chezmoi#use_tmp_buffer'] = 1
      vim.g['chezmoi#source_dir_path'] = vim.env.HOME .. '/.local/share/chezmoi'
    end,
  },
  {
    'xvzc/chezmoi.nvim',
    cmd = { 'ChezmoiEdit' },
    keys = {
      {
        '<leader>sz',
        function()
          local results = require('chezmoi.commands').list {
            args = { '--path-style', 'absolute', '--include', 'files', '--exclude', 'externals' },
          }
          local items = {}
          for _, file in ipairs(results) do
            items[#items + 1] = { text = file, file = file }
          end
          Snacks.picker.pick {
            items = items,
            confirm = function(picker, item)
              picker:close()
              require('chezmoi.commands').edit { targets = { item.text }, args = { '--watch' } }
            end,
          }
        end,
        desc = 'Chezmoi files',
      },
    },
    opts = {
      edit = { watch = false, force = false },
      notification = { on_open = true, on_apply = true, on_watch = false },
    },
    init = function()
      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = { vim.env.HOME .. '/.local/share/chezmoi/*' },
        callback = function()
          vim.schedule(require('chezmoi.commands.__edit').watch)
        end,
      })
    end,
  },
}
