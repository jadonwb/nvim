return {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  dependencies = {
    -- Integrate Nvim-cmp completion sources
    { 'saghen/blink.compat', version = '*', lazy = true, opts = {} },

    -- Sources
    'kristijanhusak/vim-dadbod-completion',
    'disrupted/blink-cmp-conventional-commits',
    'ribru17/blink-cmp-spell',
    'Kaiser-Yang/blink-cmp-git',
    {
      'huijiro/blink-cmp-supermaven',
    },
    {
      'supermaven-inc/supermaven-nvim',

      opts = {
        disable_keymaps = true,
        disable_inline_completion = true,

        ignore_filetypes = {
          help = true,
          gitrebase = true,
          hgcommit = true,
          svn = true,
          cvs = true,
          ['.'] = true,
        },
        log_level = 'info',
      },
    },
    {
      'fang2hou/blink-copilot',
      dependencies = 'zbirenbaum/copilot.lua',
    },

    -- Snippet Engine
    {
      'L3MON4D3/LuaSnip',
      version = 'v2.*',
      dependencies = {
        -- Snippets
        'solidjs-community/solid-snippets',
        'rafamadriz/friendly-snippets',
      },
      config = function()
        require('luasnip.loaders.from_vscode').lazy_load()
        -- require 'snippets.init'
      end,
    },

    -- Visual
    { 'xzbdmw/colorful-menu.nvim', opts = {} },
  },
  version = '*',
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    completion = {
      menu = {
        draw = {
          columns = { { 'kind_icon' }, { 'label', gap = 1 } },
          components = {
            label = {
              text = function(ctx)
                return require('colorful-menu').blink_components_text(ctx)
              end,
              highlight = function(ctx)
                return require('colorful-menu').blink_components_highlight(ctx)
              end,
            },
          },
        },
        border = 'rounded',
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 500,
        window = {
          border = 'rounded',
        },
      },
    },
    keymap = {
      preset = 'default',
      ['<C-x>'] = { 'show', 'hide' },
      ['<C-k>'] = { 'show_documentation', 'hide_documentation' },
      ['<C-space>'] = {},
      ['<Up>'] = {},
      ['<Down>'] = {},
    },
    cmdline = {
      keymap = {
        preset = 'cmdline',
        ['<C-x>'] = { 'show', 'hide' },
        ['<C-space>'] = {},
        ['<Right>'] = {
          function(cmp)
            if cmp.is_ghost_text_visible() and not cmp.is_menu_visible() then
              return cmp.accept()
            end
          end,
          'fallback',
        },
      },
    },
    snippets = { preset = 'luasnip' },
    sources = {
      default = { 'supermaven', 'copilot', 'lsp', 'path', 'buffer', 'dadbod', 'snippets', 'lazydev', 'git', 'conventional_commits', 'spell' },
      providers = {
        supermaven = {
          name = 'supermaven',
          module = 'blink-cmp-supermaven',
          async = true,
          score_offset = -3,
          enabled = true,
          transform_items = function(ctx, items)
            for _, item in ipairs(items) do
              item.kind_icon = ''
              item.kind_name = 'Supermaven'
            end
            return items
          end,
        },
        copilot = {
          name = 'copilot',
          module = 'blink-copilot',
          async = true,
          score_offset = -4,
          opts = {
            max_completions = 3,
            max_attempts = 4,
          },
        },
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          score_offset = 100,
        },
        dadbod = {
          name = 'Dadbod',
          module = 'vim_dadbod_completion.blink',
        },
        git = {
          module = 'blink-cmp-git',
          name = 'Git',
          async = true,
          enabled = function()
            return vim.tbl_contains({ 'octo', 'gitcommit', 'markdown' }, vim.bo.filetype) and vim.fn.executable 'gh' == 1
          end,
          opts = { commit = { triggers = { ';' } } },
        },
        conventional_commits = {
          name = 'Conventional Commits',
          module = 'blink-cmp-conventional-commits',
          enabled = function()
            return vim.bo.filetype == 'gitcommit'
          end,
          opts = {},
        },
        spell = {
          name = 'Spell',
          module = 'blink-cmp-spell',
          opts = {
            -- Only enable source in `@spell` captures, and disable it
            -- in `@nospell` captures.
            enable_in_context = function()
              local curpos = vim.api.nvim_win_get_cursor(0)
              local captures = vim.treesitter.get_captures_at_pos(0, curpos[1] - 1, curpos[2] - 1)
              local in_spell_capture = false
              for _, cap in ipairs(captures) do
                if cap.capture == 'spell' then
                  in_spell_capture = true
                elseif cap.capture == 'nospell' then
                  return false
                end
              end
              return in_spell_capture
            end,
          },
        },
      },
    },
    appearance = {
      use_nvim_cmp_as_default = true,
      nerd_font_variant = 'mono',
      kind_icons = require('kickstart.icons').kind_icons,
    },
  },
  -- allows extending the providers array elsewhere in your config
  -- without having to redefine it
  opts_extend = { 'sources.default' },
}
