NVFff = {}

NVClose.register('fff', function()
  return NVFff.ensure_hidden()
end, 20)

function NVFff.is_active()
  local ft = vim.bo.filetype
  if ft == 'fff_input' or ft == 'fff_list' or ft == 'fff_preview' or ft == 'fff_file_info' then
    return true
  end
  return false
end

function NVFff.ensure_hidden()
  if not NVFff.is_active() then
    return false
  end

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
    border = NVBorders.fff_border,
    prompt_position = 'top',
    preview_position = 'right',
    preview_size = 0.6,
  }
end

function NVFff.find_files()
  require('fff').find_files { layout = NVFffPickerLayout.build() }
end

function NVFff.live_grep()
  require('fff').live_grep { layout = NVFffPickerLayout.build() }
end

function NVFff.live_grep_under_cursor()
  require('fff').live_grep_under_cursor { layout = NVFffPickerLayout.build() }
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
    keymaps = {
      close = { NVKeymaps.close, NVKeymaps.close_esc },
      select = '<CR>',
      select_split = NVKeymaps.open_hsplit,
      select_vsplit = NVKeymaps.open_vsplit,
      insert_newline_escape = '<S-CR>',
      select_tab = NVKeymaps.tab_create,
      preview_scroll_up = NVKeymaps.scroll_ctx.up,
      preview_scroll_down = NVKeymaps.scroll_ctx.down,
      toggle_debug = '<F2>',
      cycle_grep_modes = '<S-Tab>',
      -- grep mode only: jump cursor to first match of next/prev file group
      grep_jump_to_next_file = { NVKeymaps.scroll_alt.down },
      grep_jump_to_prev_file = { NVKeymaps.scroll_alt.up },
      cycle_previous_query = '<C-Up>', -- TODO?: anything else make more sense here?
      toggle_select = '<Tab>',
      send_to_quickfix = '<C-q>',
      focus_list = '<C-S-l>',
      focus_preview = '<C-S-p>',
    },
  },
  keys = {
    {
      '<leader>ff',
      NVFff.find_files,
      desc = 'Find Files',
    },
    {
      '<leader>fs',
      NVFff.live_grep,
      desc = 'Live Grep',
    },
    {
      '<leader>fw',
      NVFff.live_grep_under_cursor,
      mode = { 'n', 'x' },
      desc = 'Grep Word',
    },
    {
      '<leader>fl',
      function()
        require('fff').resume()
      end,
      desc = 'Resume Last Search',
    },
  },
}
