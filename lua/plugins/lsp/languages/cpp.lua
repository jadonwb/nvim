return {
  {
    'madskjeldgaard/cppman.nvim',
    cmd = 'CPPMan',
    keys = {
      {
        '<leader>cK',
        function()
          if vim.fn.executable 'cppman' == 0 then
            return vim.notify('Install the cppman CLI to look up C++ documentation', vim.log.levels.WARN)
          end
          -- The upstream popup passes its argument to a shell command.
          local symbol = vim.fn.expand('<cword>'):match '^[%w_]+$'
          if symbol then
            require('cppman').open_cppman_for(symbol)
          end
        end,
        ft = 'cpp',
        desc = 'C++ documentation for the word under the cursor',
      },
    },
    cond = function()
      return require('config.profile').wants 'languages' and require('config.extras').enabled 'cpp'
    end,
    dependencies = {
      { 'MunifTanjim/nui.nvim' },
    },
    opts = {},
  },
}
