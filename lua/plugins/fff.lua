local borders = require 'config.borders'

NVFff = {}

function NVFff.ensure_hidden()
  local ft = vim.bo.filetype
  if ft ~= 'fff_input' and ft ~= 'fff_list' and ft ~= 'fff_preview' and ft ~= 'fff_file_info' then
    return false
  end

  -- Use fff's own close which properly closes all windows, deletes all buffers,
  -- saves snapshot for resume, clears namespaces, and deletes the augroup.
  local ok, picker = pcall(require, 'fff.picker_ui.picker_ui')
  if ok and picker.state and picker.state.active then
    picker.close()
  end

  return true
end

NVFffPickerLayout = {}

function NVFffPickerLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, {
    height = 0.88,
    width = NVScreen.is_large() and 0.75 or 0.9,
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
  opts = {
    prompt_vim_mode = true,
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
      [NVKeymaps.close] = 'close',
    },
  },
  keys = {
    {
      '<leader>ff',
      function()
        require('fff').find_files { layout = NVFffPickerLayout.build() }
      end,
      desc = 'Find Files',
    },
    {
      '<leader>fs',
      function()
        require('fff').live_grep { layout = NVFffPickerLayout.build() }
      end,
      desc = 'Live Grep',
    },
    {
      '<leader>fw',
      function()
        require('fff').live_grep_under_cursor { layout = NVFffPickerLayout.build() }
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
  },
}
