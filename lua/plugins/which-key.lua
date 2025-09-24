return {
  'folke/which-key.nvim',
  opts = {
    spec = {
      {
        '<leader>W',
        group = 'windows',
        proxy = '<c-w>',
        expand = function()
          return require('which-key.extras').expand.win()
        end,
      },
      {
        '<leader>w',
        function()
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == '' then
            vim.ui.input({
              prompt = 'Enter file name: ',
            }, function(name)
              if name and name ~= '' then
                vim.cmd('write ' .. vim.fn.fnameescape(name))
              end
            end)
            return
          end
          vim.cmd.write()
        end,
        desc = 'Write Buffer',
      },
    },
  },
}
