NVSnacksDashboard = {}

function NVSnacksDashboard.is_active()
  return vim.bo.filetype == 'snacks_dashboard'
end

NVClose.register('dashboard', function()
  return NVSnacksDashboard.is_active()
end, 10)

return {
  'folke/snacks.nvim',
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

        local restart_flag = vim.fn.stdpath 'cache' .. '/nvim_restart_flag'
        if vim.fn.filereadable(restart_flag) == 1 then
          local lines = vim.fn.readfile(restart_flag)
          local restart_name = lines[1] or ''
          local restart_ft = lines[2] or ''
          vim.fn.delete(restart_flag)
          NVPersistence.restore()
          local buf = vim.api.nvim_get_current_buf()
          if restart_ft ~= '' and vim.api.nvim_buf_get_name(buf) == restart_name then
            vim.bo[buf].filetype = restart_ft
            vim.api.nvim_exec_autocmds('FileType', { pattern = restart_ft })
          end
        end

        local ft = vim.bo.filetype
        -- NOTE!: this is where I can specify other filetypes that don't trigger the layout mananger
        -- TODO!: make this a function or something that I can make a nice list somewhere instead of hardcoded here
        if
          ft == 'snacks_dashboard'
          or ft == ''
          or ft == 'nofile'
          or ft == 'snacks_terminal'
          -- TODO?: make a picker.is_active ?
          or ft == 'snacks_picker_input'
          or ft == 'snacks_picker_list'
          or ft == 'snacks_picker_preview'
        then
          return
        end
        layout_enabled = true
        NVLualine.show_everything()
        NVLayoutManager.enable()
      end,
    })
  end,
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
            table.insert(items, { icon = ' ', key = 'l', desc = 'Restore Session', action = NVPersistence.restore })
          end

          table.insert(items, { icon = ' ', key = 'g', desc = 'LazyGit', action = NVSLazygit.show })
          table.insert(items, { icon = ' ', key = 'f', desc = 'Find file', action = NVFffPicker.find_files })
          table.insert(items, { icon = ' ', key = 's', desc = 'Find text', action = NVFffPicker.live_grep })
          table.insert(items, { icon = ' ', key = 'e', desc = 'Browse Files', action = ':Yazi' })
          -- ' ' TODO: make a new file option?
          table.insert(items, { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' })

          return items
        end,
      },
    },
  },
}
