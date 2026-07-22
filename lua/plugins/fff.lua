return {
  'dmtrKovalenko/fff.nvim',
  build = function()
    require('fff.download').download_or_build_binary()
  end,
  opts = {
    prompt_vim_mode = true,
    layout = {
      height = 0.9,
      width = 0.9,
      prompt_position = 'top',
      preview_position = 'right',
      preview_size = 0.6,
    },
    grep = {
      modes = { 'plain', 'regex', 'fuzzy' },
    },
    debug = {
      enabled = false,
    },
    git = {
      status_text_color = true,
    },
  },
  keys = {
    {
      '<leader>ff',
      function()
        require('fff').find_files()
      end,
      desc = 'Find Files',
    },
    {
      '<leader>fs',
      function()
        require('fff').live_grep()
      end,
      desc = 'Live Grep',
    },
    {
      '<leader>fw',
      function()
        require('fff').live_grep_under_cursor()
      end,
      mode = { 'n', 'x' },
      desc = 'Grep Word',
    },
    {
      '<leader>fR',
      function()
        require('fff').resume()
      end,
      desc = 'Resume Last Search',
    },
    {
      '<leader>fd',
      function()
        vim.ui.input({ prompt = 'Enter directory: ' }, function(input)
          if not input or input == '' then
            return
          end

          local cwd = vim.fn.getcwd()
          local path

          input = vim.fn.expand(input)

          if vim.fn.isdirectory(input) == 1 then
            path = input
          else
            local candidate = vim.fs.normalize(cwd .. '/' .. input)
            if vim.fn.isdirectory(candidate) == 1 then
              path = candidate
            end
          end

          if not path then
            vim.notify('Invalid directory: ' .. input, vim.log.levels.ERROR)
            return
          end

          require('fff').find_files_in_dir(path)
        end)
      end,
      desc = 'Find in Directory',
    },
  },
}
