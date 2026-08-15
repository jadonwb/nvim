NVLualine = {}

function NVLualine.show_everything()
  vim.opt.laststatus = 3
  vim.opt.showtabline = 1
end

function NVLualine.hide_everything()
  vim.opt.laststatus = 0
  vim.opt.showtabline = 0
end

function NVLualine.show_tabline()
  pcall(function()
    require('lualine').hide { place = 'tabline', unhide = true }
  end)
end

function NVLualine.hide_tabline()
  pcall(function()
    require('lualine').hide { place = 'tabline', unhide = false }
  end)
end

function NVLualine.rename_tab(label)
  vim.cmd('LualineRenameTab ' .. label)
end

local tabline_mode = 'filepath'

return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  keys = {
    {
      '<Leader><tab>t',
      function()
        tabline_mode = tabline_mode == 'filepath' and 'lsp_symbol' or 'filepath'
        vim.notify('Tabline: ' .. (tabline_mode == 'filepath' and 'filepath' or 'LSP symbols'), vim.log.levels.INFO, { title = 'Tabline' })
      end,
      desc = 'Toggle Tabline (filepath / LSP symbols)',
    },
  },
  opts = function(_, opts)
    local icons = LazyVim.config.icons

    -- Single letter mode indicator
    opts.sections.lualine_a = {
      {
        'mode',
        fmt = function(str)
          return ' ' .. str:sub(1, 1) .. ' '
        end,
      },
    }

    -- Remove separators for square look
    opts.options = vim.tbl_deep_extend('force', opts.options or {}, {
      section_separators = { left = '', right = '' },
      component_separators = { left = '', right = '' },
      always_show_tabline = false,
    })

    -- Make nice path and modified indicator
    opts.sections.lualine_x = {
      {
        function()
          local reg = vim.fn.reg_recording()
          return reg ~= '' and 'Recording @' .. reg or ''
        end,
        cond = function()
          return #vim.fn.reg_recording() > 0
        end,
        color = 'DiagnosticWarn',
      },
      {
        function()
          if not NVUi2 then
            return ''
          end
          if NVUi2.progress_text and NVUi2.progress_text ~= '' then
            return NVUi2.progress_text
          end
          -- fallback to table (first entry formatted)
          local _, p = next(NVUi2.progress or {})
          if not p then
            return ''
          end
          local parts = {}
          if p.name then table.insert(parts, p.name) end
          if p.title then table.insert(parts, p.title) end
          if p.message then table.insert(parts, p.message) end
          if p.percent then table.insert(parts, p.percent .. '%') end
          return table.concat(parts, ' ')
        end,
        cond = function()
          if not NVUi2 then
            return false
          end
          if NVUi2.progress_text and NVUi2.progress_text ~= '' then
            return true
          end
          return NVUi2.progress and next(NVUi2.progress) ~= nil
        end,
        color = 'MsgArea',
      },
      {
        function()
          local sc = vim.fn.searchcount { recompute = true, maxcount = 999 }
          if sc.incomplete == 1 then
            return '[?/??]'
          end
          return string.format('[%d/%d]', sc.current, sc.total)
        end,
        cond = function()
          if vim.v.hlsearch == 0 then
            return false
          end
          local sc = vim.fn.searchcount { recompute = true, maxcount = 999 }
          return sc.total > 0
        end,
        color = 'DiagnosticInfo',
      },
    }
    opts.sections.lualine_c = {
      LazyVim.lualine.root_dir(),
      {
  'diagnostics',
  symbols = {
    error = NVIcons.lsp.full.error .. ' ',
    warn = NVIcons.lsp.full.warn .. ' ',
    info = NVIcons.lsp.full.info .. ' ',
    hint = NVIcons.lsp.full.hint .. ' ',
  },
      },
      { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
      { LazyVim.lualine.pretty_path { modified_sign = ' ●' } },
    }

    -- Tabline: project name | filepath / LSP symbol | tab list
    -- DiagnosticFloatingHintLabel: dark fg on cyan bg (pill badge style from arrowlake)
    opts.tabline = {
      lualine_a = {
        {
          function()
            return ' ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t'):upper() .. ' '
          end,
          color = 'DiagnosticFloatingHintLabel',
          padding = 1,
        },
      },
      lualine_c = {
        {
          function()
            if tabline_mode == 'lsp_symbol' then
              local ok, result = pcall(require('trouble').statusline, {
                mode = 'lsp_document_symbols',
                groups = {},
                title = '',
                filter = { range = true },
                format = '{kind_icon}{filename}:{symbol.name}',
              })
              return ok and result.get() or ''
            end
            return vim.fn.expand '%:.:h' == '.' and vim.fn.expand '%:t' or vim.fn.expand '%:.:h' .. '/' .. vim.fn.expand '%:t'
          end,
        },
      },
      lualine_z = {
        {
          'tabs',
          mode = 2,
          fmt = function(name, ctx)
            local label = vim.fn.gettabvar(ctx.tabnr, 'tab_label')
            if type(label) == 'table' and label.icon and label.name then
              return label.icon .. ' ' .. label.name
            end
            return '' .. name .. ' '
          end,
        },
      },
    }
  end,
}
