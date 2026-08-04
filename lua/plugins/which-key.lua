local borders = require 'config.borders'

return {
  'folke/which-key.nvim',
  opts = {
    delay = 333,
    show_help = false,
    show_keys = false,
    win = {
      border = borders.padded,
      row = -3,
    },
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
        '<leader>bn',
        '<cmd>enew<cr>',
        desc = 'New Buffer',
      },
      { 'gr', group = 'LSP Jumps', icon = '' },
      { '<leader>b', group = 'buffer' },
      { '<leader>s', group = 'snacks/search', icon = '󱥰 ' },
      { '<leader>f', group = 'find' },
      { '<leader>d', group = 'Delta', icon = '󰇂 ' },
      { '<leader>i', group = 'image', icon = ' ' },
      { '<leader>a', group = 'pi', icon = 'π ' },
    },
  },
}
