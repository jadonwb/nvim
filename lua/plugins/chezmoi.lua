-- chezmoi: edit managed files through chezmoi, not the deployed copy.
return {
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
