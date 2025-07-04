local supermaven_enabled = false
return {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  dependencies = {
    -- Integrate Nvim-cmp completion sources
    { 'saghen/blink.compat', version = '*', lazy = true, opts = {} },

    -- Sources
    'ribru17/blink-cmp-spell',
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
      'Yu-Leo/cmp-go-pkgs',
      enabled = vim.fn.executable 'go' == 1,
      init = function()
        vim.api.nvim_create_autocmd({ 'LspAttach' }, {
          pattern = { '*.go' },
          callback = function(args)
            require('cmp_go_pkgs').init_items(args)
          end,
        })
      end,
    },
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
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    completion = {
      accept = {
        auto_brackets = {
          enabled = true,
        },
      },
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
        auto_show_delay_ms = 150,
        window = {
          border = 'rounded',
          max_width = 120,
          max_height = 120,
        },
      },
    },
    keymap = {
      preset = 'default',
      ['<Tab>'] = {
        function(cmp)
          if cmp.is_visible() then
            return cmp.select_and_accept()
          end
        end,
        'fallback',
      },
      ['<C-x>'] = { 'show', 'hide' },
      ['<C-k>'] = { 'show_documentation', 'hide_documentation' },
      ['<C-space>'] = {
        function(cmp)
          supermaven_enabled = not supermaven_enabled
          vim.notify('Supermaven ' .. (supermaven_enabled and 'enabled' or 'disabled'), vim.log.levels.INFO)

          if cmp.is_visible() then
            cmp.hide()
            vim.defer_fn(function()
              cmp.show()
            end, 10)
          end
        end,
      },
      ['<Up>'] = {},
      ['<Down>'] = {},
    },
    cmdline = {
      keymap = {
        preset = 'cmdline',
        ['<C-x>'] = { 'show', 'hide' },
        ['<C-space>'] = {
          function(cmp)
            supermaven_enabled = not supermaven_enabled
            vim.notify('Supermaven ' .. (supermaven_enabled and 'enabled' or 'disabled'), vim.log.levels.INFO)

            if cmp.is_visible() then
              cmp.hide()
              vim.defer_fn(function()
                cmp.show()
              end, 10)
            end
          end,
        },
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
      default = { 'supermaven', 'lsp', 'path', 'buffer', 'snippets', 'lazydev', 'go_pkgs', 'spell' },
      providers = {
        supermaven = {
          name = 'supermaven',
          module = 'blink-cmp-supermaven',
          async = true,
          score_offset = 10,
          enabled = function()
            return supermaven_enabled
          end,
          transform_items = function(ctx, items)
            for _, item in ipairs(items) do
              item.kind_icon = ''
              item.kind_name = 'Supermaven'
            end
            return items
          end,
        },
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
        go_pkgs = {
          name = 'go_pkgs',
          module = 'blink.compat.source',
          enabled = function()
            return vim.bo.filetype == 'go' and vim.fn.executable 'go' == 1
          end,
          opts = {},
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
      use_nvim_cmp_as_default = true,
      nerd_font_variant = 'mono',
      kind_icons = require('kickstart.icons').kind_icons,
    },
  },
  -- allows extending the providers array elsewhere in your config
  -- without having to redefine it
  opts_extend = { 'sources.default' },
}
