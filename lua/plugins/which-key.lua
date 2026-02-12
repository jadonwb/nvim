return {
  'folke/which-key.nvim',
  opts = {
    delay = 333,
    win = {
      row = -3,
    },
    show_help = false,
    show_keys = false,
    spec = {
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
      {
        '<leader>K',
        hidden = true,
      },
      {
        '<leader>b',
        hidden = true,
      },
      {
        '<leader><tab>',
        hidden = true,
      },
      {
        mode = { 'n', 'v', 's', 'x' },
        '<leader>d',
        [["_d]],
        hidden = true,
      },
      {
        '<leader><space>',
        '<cmd>BentoToggle<cr>',
        desc = 'Bento Toggle',
      },
      { 'gr', group = 'LSP Jumps' },
    },
  },
}
