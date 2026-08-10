NVSPickers = {}
NVSZoom = {}
NVSLazygit = {}
NVSTerminal = {}
NVSNotifier = {}
NVSInput = {}
NVSnacksDashboard = {}

NVSPickerVerticalLayout = {
  large_screen_width = 0.35,
  small_screen_width = 0.4,
}

NVSPickerHorizontalLayout = {
  large_screen_width = 0.75,
  small_screen_width = 0.95,
}

function NVSPickerVerticalLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, {
    width = NVScreen.is_large() and NVSPickerVerticalLayout.large_screen_width or NVSPickerVerticalLayout.small_screen_width,
    height = 0.7,
  })
  return {
    layout = {
      box = 'vertical',
      width = config.width,
      height = config.height,
      border = NVBorders.none,
      backdrop = false,
      { win = 'input', height = 1, title = '{title} {live}', title_pos = 'center', border = NVBorders.padded },
      { win = 'list', border = NVBorders.list },
      { win = 'preview', title = '{preview}', border = NVBorders.top_hr },
    },
  }
end

function NVSPickerHorizontalLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, {
    width = NVScreen.is_large() and NVSPickerHorizontalLayout.large_screen_width or NVSPickerHorizontalLayout.small_screen_width,
    height = 0.9,
  })
  return {
    layout = {
      box = 'horizontal',
      width = config.width,
      height = config.height,
      backdrop = false,
      {
        box = 'vertical',
        { win = 'input', height = 1, title = '{title} {live}', title_pos = 'center', border = NVBorders.padded },
        { win = 'list', border = NVBorders.top_none },
      },
      { win = 'preview', title = '{preview}', border = NVBorders.preview },
    },
  }
end

NVSPickers.keys = {
  ['<M-f>'] = { 'toggle_maximize', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.open_vsplit] = { 'edit_vsplit', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.open_hsplit] = { 'edit_split', mode = { 'n', 'i', 'v' } },
  ['<C-w>'] = { 'cycle_win', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll.up] = { 'list_scroll_up', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll.down] = { 'list_scroll_down', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_alt.up] = { 'x_list_scroll_up_bit', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_alt.down] = { 'x_list_scroll_down_bit', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_ctx.up] = { 'preview_scroll_up', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_ctx.down] = { 'preview_scroll_down', mode = { 'n', 'i', 'v' } },
  -- ['<C-S-l>'] = { 'focus_list', mode = { 'n', 'i', 'v' } },
  -- ['<C-S-p>'] = { 'focus_preview', mode = { 'n', 'i', 'v' } },
  ['<C-S-p>'] = { 'toggle_preview', mode = { 'n', 'i', 'v' } },
  ['<C-S-c>'] = { 'x_copy_absolute_path', mode = { 'n', 'i', 'v' } },
  ['<C-S-r>'] = { 'x_copy_relative_path', mode = { 'n', 'i', 'v' } },
  ['<C-S-f>'] = { 'x_copy_filename', mode = { 'n', 'i', 'v' } },
  ['<C-S-s>'] = { 'x_copy_filestem', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.close] = { 'close', mode = { 'n', 'i', 'v' } },
}

NVSPickers.actions = {
  x_list_scroll_up_bit = function(picker)
    picker.list:scroll(-2)
  end,
  x_list_scroll_down_bit = function(picker)
    picker.list:scroll(2)
  end,
  x_copy_absolute_path = function(_, item)
    NVSPickers.copy_path(item, 'absolute')
  end,
  x_copy_relative_path = function(_, item)
    NVSPickers.copy_path(item, 'relative')
  end,
  x_copy_filename = function(_, item)
    NVSPickers.copy_path(item, 'filename')
  end,
  x_copy_filestem = function(_, item)
    NVSPickers.copy_path(item, 'filestem')
  end,
  bufdelete = function(picker)
    NVSPickers.bufdelete(picker)
  end,
}

function NVSPickers.bufdelete(picker)
  picker.preview:reset()
  for _, item in ipairs(picker:selected { fallback = true }) do
    if item.buf then
      local win = vim.fn.bufwinid(item.buf)
      if win ~= -1 then
        NVBuffers.delete_buf(item.buf, win)
      else
        vim.api.nvim_buf_delete(item.buf, { force = true })
      end
    end
  end
  pcall(picker.refresh, picker)
end

function NVSPickers.copy_path(item, fmt)
  if item == nil then
    vim.notify('No item selected', vim.log.levels.INFO)
    return
  end
  local result = NVFS.format(item.file, fmt)
  if result ~= nil then
    NVClipboard.yank(result)
    vim.notify('Copied: ' .. result, vim.log.levels.INFO)
  end
end

function NVSPickers.files()
  Snacks.picker.files {
    show_empty = true,
    hidden = true,
    ignored = false,
    follow = false,
    supports_live = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.buffers()
  Snacks.picker.buffers {
    hidden = true,
    unloaded = true,
    current = false,
    sort_lastused = true,
    layout = NVSPickerVerticalLayout.build(),
    filter = {
      -- FIXME: filter out or don't show files in my picker from other neovim instances? keep seeing weird issues where other neovim files are showing up in my buffer picker, from different neovim sessions altogether
      filter = function(item, _)
        local file = item.file or ''
        if file:find '^diffview://' then
          return false
        end
        if file:find '^term://' then
          return false
        end
        if file:find '^oil://' then
          return false
        end
        if NVLayoutManager.is_sidepad_buf(item.buf) then
          return false
        end
        if file == '[Scratch]' or file == '' then
          return false
        end
        return true
      end,
    },
    win = {
      input = {
        keys = {
          ['<BS>'] = { 'bufdelete', mode = { 'n' } },
        },
      },
      list = {
        keys = {
          ['dd'] = 'bufdelete',
        },
      },
    },
  }
end

function NVSPickers.text_search()
  Snacks.picker.grep {
    hidden = true,
    ignored = false,
    regex = false,
    layout = NVSPickerHorizontalLayout.build(),
  }
end

function NVSPickers.git_branches()
  Snacks.picker.git_branches {
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.lsp_document_symbols()
  Snacks.picker.lsp_symbols {
    layout = NVSPickerVerticalLayout.build {
      width = NVScreen.is_large() and 0.5 or 0.8,
      height = 0.9,
    },
  }
end

function NVSPickers.lsp_workspace_symbols()
  Snacks.picker.lsp_workspace_symbols {
    layout = NVSPickerVerticalLayout.build {
      width = NVScreen.is_large() and 0.5 or 0.8,
      height = 0.9,
    },
  }
end

function NVSPickers.lsp_references()
  Snacks.picker.lsp_references {
    auto_confirm = false,
    layout = NVSPickerHorizontalLayout.build(),
  }
end

function NVSPickers.lsp_implementations()
  Snacks.picker.lsp_implementations {
    auto_confirm = false,
    layout = NVSPickerHorizontalLayout.build(),
  }
end

function NVSPickers.lsp_definitions()
  Snacks.picker.lsp_definitions {
    auto_confirm = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.lsp_type_definitions()
  Snacks.picker.lsp_type_definitions {
    auto_confirm = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.lsp_declarations()
  Snacks.picker.lsp_declarations {
    auto_confirm = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.highlights()
  Snacks.picker.highlights {
    layout = NVSPickerHorizontalLayout.build(),
  }
end

-- Zoom
function NVSZoom.activate()
  Snacks.zen.zoom()
end

function NVSZoom.ensure_deactivated()
  local win = Snacks.zen.win
  if win then
    Snacks.zen.zoom()
    return true
  end
  return false
end

NVClose.register('snacks_zoom', function()
  return NVSZoom.ensure_deactivated()
end, 30)

-- Terminal
function NVSTerminal.is_app(app, bufid)
  bufid = bufid or vim.api.nvim_get_current_buf()
  local buf_info = vim.fn.getbufinfo(bufid)[1]
  if buf_info and buf_info.variables.snacks_terminal and buf_info.variables.snacks_terminal.cmd then
    local cmd = buf_info.variables.snacks_terminal.cmd
    if type(cmd) == 'string' then
      return string.find(cmd, app) ~= nil
    elseif type(cmd) == 'table' and cmd[1] then
      return string.find(cmd[1], app) ~= nil
    end
  end
  return false
end

-- Notifier
function NVSNotifier.log()
  Snacks.notifier.show_history()
end

function NVSNotifier.hide()
  Snacks.notifier.hide()
end

-- Lazygit
function NVSLazygit.show()
  Snacks.lazygit()
end

function NVSLazygit.ensure_hidden()
  if NVSTerminal.is_app 'lazygit' then
    Snacks.lazygit()
    return true
  end
  return false
end

NVClose.register('snacks_lazygit', function()
  return NVSLazygit.ensure_hidden()
end, 5)

function NVSInput.is_input(bufid)
  bufid = bufid or vim.api.nvim_get_current_buf()
  return vim.bo[bufid].filetype == 'snacks_input'
end

function NVSInput.ensure_hidden()
  if NVSInput.is_input() then
    vim.cmd.close()
    return true
  end
  return false
end

NVClose.register('snacks_input', function()
  return NVSInput.ensure_hidden()
end, 20)

function NVSnacksDashboard.is_active()
  return vim.bo.filetype == 'snacks_dashboard'
end

NVClose.register('dashboard', function()
  return NVSnacksDashboard.is_active()
end, 10)

return {
  {
    'folke/snacks.nvim',
    opts = {
      dashboard = {
        preset = {
          keys = function()
            local items = {}

            if NVLazy.anything_missing() then
              table.insert(items, {
                icon = ' ',
                key = 'i',
                desc = 'Install Plugins',
                action = function()
                  NVLazy.install()
                end,
              })
            end

            if NVPersistence.has_session() then
              table.insert(items, { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' })
            end

            table.insert(items, { icon = ' ', key = 'e', desc = 'Browse Files', action = ':Yazi' })
            table.insert(items, { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' })

            return items
          end,
        },
      },
      explorer = { enabled = false },
      scroll = { enabled = false },
      notifier = {
        enabled = true,
        timeout = 3000,
        level = vim.log.levels.DEBUG,
        date_format = '%T',
        filter = function(n)
          local tab_label = vim.t.tab_label
          if tab_label and tab_label.name and tab_label.name:find 'diff' then
            if string.find(n.msg, '^Client %S+ quit with exit code %d+ and signal %d+%.') or string.find(n.msg, '^%[null%-ls%] failed to run generator') then
              return false
            end
          end
          return true
        end,
      },
      indent = {
        indent = { enabled = false },
        scope = { only_current = true },
        chunk = { enabled = true, only_current = true, char = { corner_top = '╭', corner_bottom = '╰' } },
      },
      lazygit = {
        config = {
          -- TODO?: is this even any different from default snacks lazygit config anymore?
          os = {
            edit = vim.v.progpath
              .. [[ --server "$NVIM" --remote-send '<Cmd>lua require("snacks").lazygit()<CR>' && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-silent {{filename}} ]],
            editAtLine = vim.v.progpath
              .. [[ --server "$NVIM" --remote-send '<Cmd>lua require("snacks").lazygit()<CR>' && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-silent {{filename}} && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-send ':{{line}}<CR>' ]],
            openDirInEditor = vim.v.progpath
              .. [[ --server "$NVIM" --remote-send '<Cmd>lua require("snacks").lazygit()<CR>' && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-silent {{dir}} ]],
          },
        },
      },
      zen = {
        zoom = {
          show = { statusline = true, tabline = true },
          win = { width = 0, backdrop = false },
        },
      },
      picker = {
        prompt = '❯ ',
        ui_select = true,
        icons = {
          diagnostics = {
            Error = NVIcons.lsp.full.error,
            Warn = NVIcons.lsp.full.warn,
            Hint = NVIcons.lsp.full.hint,
            Info = NVIcons.lsp.full.info,
          },
        },
        layout = vim.tbl_extend('force', NVSPickerHorizontalLayout.build(), { cycle = false }),
        win = {
          input = { keys = NVSPickers.keys },
          list = { keys = NVSPickers.keys },
          preview = { keys = NVSPickers.keys },
        },
        actions = NVSPickers.actions,
        formatters = {
          file = { filename_first = true, truncate = 80 },
        },
        layouts = {
          default = {
            layout = NVSPickerHorizontalLayout.build(),
          },
          select = {
            layout = {
              box = 'vertical',
              backdrop = false,
              width = 0.5,
              height = 0.5,
              border = NVBorders.none,
              { win = 'input', height = 1, title = '{title}', title_pos = 'center', border = NVBorders.bottom_hr },
              { win = 'list', border = NVBorders.top_none },
            },
          },
          vscode = {
            hidden = { 'preview' },
            layout = {
              backdrop = false,
              row = 1,
              width = 0.4,
              min_width = 80,
              height = 0.4,
              border = 'none',
              box = 'vertical',
              { win = 'input', height = 1, border = NVBorders.bottom_hr, title = '{title} {live} {flags}', title_pos = 'center' },
              { win = 'list', border = NVBorders.top_none },
              { win = 'preview', title = '{preview}', border = NVBorders.padded },
            },
          },
        },
      },
      input = {
        win = { border = NVBorders.padded },
      },
      styles = {
        terminal = {
          wo = {
            winhighlight = 'Normal:Normal,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,WinSeparator:SnacksWinSeparator,FloatBorder:Border',
          },
        },
        lazygit = { width = 0, height = 0, border = 'rounded' },
        float = { backdrop = false },
        notification = { border = NVBorders.padded },
        notification_history = {
          backdrop = false,
          border = NVBorders.padded,
          keys = { q = 'close', ['<Esc>'] = 'close' }, -- TODO: cleanup and use nvkeymaps, remove q?
        },
      },
    },
    init = function()
      local dashboard_setup = {}
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'snacks_dashboard',
        callback = function()
          local buf = vim.api.nvim_get_current_buf()
          if dashboard_setup[buf] then
            return
          end
          dashboard_setup[buf] = true
          NVLualine.hide_everything()
          vim.api.nvim_create_autocmd('BufWipeout', {
            callback = function(args)
              if args.buf ~= buf then
                return
              end
              dashboard_setup[buf] = nil
              NVTabs.set_label_if_empty { icon = NVTabs.editor_icon, name = 'main' }
              NVLualine.show_everything()
              NVLayoutManager.enable()
            end,
          })
        end,
      })
      if vim.bo.filetype == 'snacks_dashboard' then
        vim.api.nvim_exec_autocmds('FileType', { pattern = 'snacks_dashboard' })
      end
      local layout_enabled = false
      vim.api.nvim_create_autocmd('BufEnter', {
        callback = function()
          if layout_enabled then
            return true
          end
          local ft = vim.bo.filetype
          if ft == 'snacks_dashboard' or ft == '' or ft == 'nofile' then
            return
          end
          layout_enabled = true
          NVLualine.show_everything()
          NVLayoutManager.enable()
        end,
      })
    end,
    keys = {
      { '<M-f>', NVSZoom.activate, mode = { 'n', 'i', 'v' }, desc = 'Maximize' },
      {
        '<leader><space>',
        function()
          NVSPickers.buffers()
        end,
        desc = 'Buffers',
      },
      {
        '<leader>sH',
        function()
          NVSPickers.highlights()
        end,
        desc = 'Search Highlights',
      },
    },
  },
}
