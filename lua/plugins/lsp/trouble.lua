local source_name = 'diagnostics_per_ft'

local function open_trouble(filter, buf)
  local trouble = require 'trouble'
  trouble.open {
    mode = source_name,
    focus = true,
    filter = vim.tbl_extend('keep', filter or {}, buf and { buf = buf } or {}),
    win = { size = 0.4, position = 'bottom' },
  }
end

return {
  {
    'folke/trouble.nvim',
    opts = function(_, opts)
      opts = opts or {}
      opts.auto_close = false
      opts.auto_preview = true
      opts.auto_refresh = true
      opts.focus = true
      opts.restore = true
      opts.follow = false
      opts.indent_guides = false
      opts.max_items = 200
      opts.multiline = true
      opts.warn_no_results = true
      opts.open_no_results = false

      -- Bottom layout
      opts.modes = opts.modes or {}
      opts.modes.lsp = opts.modes.lsp or {}
      opts.modes.lsp.win = { position = 'bottom', size = 0.4 }
      opts.modes.symbols = opts.modes.symbols or {}
      opts.modes.symbols.win = { position = 'bottom', size = 0.4 }

      opts.keys = vim.tbl_deep_extend('keep', opts.keys or {}, {
        ['<Esc>'] = 'close',
        q = 'close',
        ['<CR>'] = 'jump_close',
        ['<Right>'] = 'fold_open',
        ['<Left>'] = 'fold_close',
        ['<Space>'] = 'fold_toggle',
      })
    end,
    config = function(_, opts)
      require('trouble').setup(opts)

      local ok = pcall(require, 'trouble.sources')
      if not ok then
        return
      end

      require('trouble.sources').register(source_name, {
        get = function(cb)
          local Item = require 'trouble.item'
          local items = {}
          for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
            local ns = vim.lsp.diagnostic.get_namespace(client.id)
            for _, d in ipairs(vim.diagnostic.get(nil, { namespace = ns })) do
              table.insert(
                items,
                Item.new {
                  source = 'diagnostics',
                  buf = d.bufnr,
                  pos = { d.lnum + 1, d.col },
                  end_pos = { d.end_lnum and (d.end_lnum + 1) or nil, d.end_col },
                  item = d,
                }
              )
            end
          end
          cb(items)
        end,
        config = {
          format = '{severity_icon} {message:md} {item.source} {code} {pos}',
          groups = {
            { 'directory' },
            { 'filename', format = '{file_icon} {basename} {count}' },
          },
          modes = {
            [source_name] = { source = source_name },
          },
        },
      })
    end,
    keys = {
      {
        '<leader>xe',
        function()
          open_trouble { severity = vim.diagnostic.severity.ERROR }
        end,
        desc = 'Workspace Errors (Trouble)',
      },
      {
        '<leader>xw',
        function()
          open_trouble { severity = vim.diagnostic.severity.WARN }
        end,
        desc = 'Workspace Warnings (Trouble)',
      },
      {
        '<leader>xx',
        function()
          open_trouble()
        end,
        desc = 'Workspace Diagnostics (Trouble)',
      },
    },
  },
}
