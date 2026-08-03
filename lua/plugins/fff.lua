local K = require 'utils.keymap'
local screen = require 'utils.screen'
local borders = require 'config.borders'

NVFffPickerLayout = {}

function NVFffPickerLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, {
    height = 0.88,
    width = screen.is_large() and 0.75 or 0.9,
  })
  return {
    height = config.height,
    width = config.width,
    border = borders.fff_border,
    prompt_position = 'top',
    preview_position = 'right',
    preview_size = 0.6,
  }
end

return {
  'dmtrKovalenko/fff.nvim',
  branch = 'main',
  build = function()
    require('fff.download').download_or_build_binary()
  end,
  opts = function()
    return vim.tbl_extend('force', {
      prompt_vim_mode = true,
      layout = NVFffPickerLayout.build(),
    }, {
      -- Additional opts that aren't layout-related
      file_picker = {
        fuzzy_query_highlighting = true,
      },
      grep = {
        modes = { 'plain', 'regex', 'fuzzy' },
      },
      debug = {
        enabled = false,
        show_scores = true,
        show_file_info = { file_info = true, score_breakdown = false, timings = false, full_path = false },
      },
      hl = {
        title = 'FloatTitle',
      },
      mappings = {
        ['<C-Tab>'] = 'toggle_preview_tab',
        ['<C-l>'] = 'focus_list',
        ['<C-p>'] = 'focus_preview',
        [K.keys.close] = 'close',
      },
    })
  end,
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
