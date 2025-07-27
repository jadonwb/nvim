return {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  dependencies = {
    -- Integrate Nvim-cmp completion sources
    { 'saghen/blink.compat', version = '*', lazy = true, opts = {} },

    -- Sources
    'ribru17/blink-cmp-spell',
    'folke/snacks.nvim',

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
        require 'snippets.init'
      end,
    },

    -- Visual
    { 'xzbdmw/colorful-menu.nvim', opts = {} },
  },
  version = '*',
  config = function()
    require('blink.cmp').setup {
      completion = {
        list = {
          selection = {
            preselect = function(ctx)
              return not require('blink.cmp').snippet_active { direction = 1 }
            end,
            auto_insert = false,
          },
        },
        menu = {
          draw = {
            columns = { { 'kind_icon' }, { 'label', gap = 2 } },
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
          auto_show_delay_ms = 150,
          window = {
            border = 'rounded',
            max_width = 120,
            max_height = 120,
          },
        },
      },
      keymap = {
        preset = 'super-tab',
        ['<C-space>'] = { 'show', 'hide' },
        ['<C-k>'] = { 'show_documentation', 'hide_documentation' },
        ['<Up>'] = {},
        ['<Down>'] = {},
      },
      cmdline = {
        keymap = {
          preset = 'none',
          ['<Tab>'] = { 'show', 'select_next' },
          ['<S-Tab>'] = { 'show', 'select_prev' },
          ['<CR>'] = {
            function(cmp)
              if cmp.is_menu_visible() then
                cmp.select_and_accept()
                return true
              end
            end,
            'fallback',
          },
          ['<C-space>'] = { 'show', 'hide' },
          ['<C-e>'] = {
            function(cmp)
              if cmp.is_ghost_text_visible() then
                return cmp.accept()
              end
            end,
            'fallback',
          },
        },
        completion = {
          list = {
            selection = {
              auto_insert = false,
            },
          },
          menu = {
            auto_show = false,
          },
        },
      },
      snippets = { preset = 'luasnip' },
      sources = {
        default = { 'lsp', 'path', 'buffer', 'snippets', 'lazydev', 'spell' },
        providers = {
          snippets = {
            module = 'blink.cmp.sources.snippets',
            score_offset = -1,
          },
          lazydev = {
            name = 'LazyDev',
            module = 'lazydev.integrations.blink',
            score_offset = 100,
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
      fuzzy = {
        implementation = 'rust',
        sorts = {
          'exact',
          'score',
          'sort_text',
        },
        prebuilt_binaries = {
          download = true,
        },
      },
      appearance = {
        nerd_font_variant = 'mono',
        kind_icons = require('icons').kind_icons,
      },
    }
  end,

  -- allows extending the providers array elsewhere in your config
  -- without having to redefine it
  opts_extend = { 'sources.default' },
}
