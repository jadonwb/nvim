NVDiffview = {}

local dv_fn = {}

function NVDiffview.is_diffview_tab(tabid)
  local ok, dv = pcall(require, 'diffview.lib')
  if not ok or not dv.views then
    return false
  end
  for _, view in ipairs(dv.views) do
    if view.tabpage == tabid then
      return true
    end
  end
  return false
end

function NVDiffview.ensure_hidden()
  local current_diff = dv_fn.current_diff()
  if current_diff then
    dv_fn.hide_current_diff()
    return true
  end
  return false
end

NVTabs.register_type {
  name = 'diffview',
  is_temporary = true,
  is_match = NVDiffview.is_diffview_tab,
  close_hook = NVDiffview.ensure_hidden,
}

function dv_fn.current_diff()
  local ok, dv = pcall(require, 'diffview.lib')
  if not ok then
    return nil
  end
  return dv.get_current_view()
end

function dv_fn.hide_current_diff()
  vim.cmd 'DiffviewClose'
end

function dv_fn.inactive_diff()
  local ok, dv = pcall(require, 'diffview.lib')
  if not ok or not dv.views then
    return nil
  end
  local tabs = vim.api.nvim_list_tabpages()
  for _, tabpage in ipairs(tabs) do
    for _, view in ipairs(dv.views) do
      if view.tabpage == tabpage then
        return tabpage
      end
    end
  end
  return nil
end

return {
  'dlyongemallo/diffview-plus.nvim',
  lazy = false,
  opts = function()
    local actions = require 'diffview.actions'

    -- Remap default <leader>c* conflict keymaps to <leader>d*
    local conflict_d = {
      -- Disable defaults
      { 'n', '<leader>co', false },
      { 'n', '<leader>ct', false },
      { 'n', '<leader>cb', false },
      { 'n', '<leader>ca', false },
      { 'n', '<leader>cO', false },
      { 'n', '<leader>cT', false },
      { 'n', '<leader>cB', false },
      { 'n', '<leader>cA', false },
      -- Replacements: per-hunk
      { 'n', '<leader>do', actions.conflict_choose 'ours', { desc = 'Choose OURS' } },
      { 'n', '<leader>dt', actions.conflict_choose 'theirs', { desc = 'Choose THEIRS' } },
      { 'n', '<leader>db', actions.conflict_choose 'base', { desc = 'Choose BASE' } },
      { 'n', '<leader>da', actions.conflict_choose 'all', { desc = 'Choose ALL' } },
      -- Replacements: whole-file
      { 'n', '<leader>dO', actions.conflict_choose_all 'ours', { desc = 'Choose OURS (whole file)' } },
      { 'n', '<leader>dT', actions.conflict_choose_all 'theirs', { desc = 'Choose THEIRS (whole file)' } },
      { 'n', '<leader>dB', actions.conflict_choose_all 'base', { desc = 'Choose BASE (whole file)' } },
      { 'n', '<leader>dA', actions.conflict_choose_all 'all', { desc = 'Choose ALL (whole file)' } },
      -- New: whole-buffer side replacement (no default to disable)
      { 'n', '<leader>dSo', actions.conflict_choose_side 'ours', { desc = 'Replace buffer with OURS' } },
      { 'n', '<leader>dSt', actions.conflict_choose_side 'theirs', { desc = 'Replace buffer with THEIRS' } },
      { 'n', '<leader>dSb', actions.conflict_choose_side 'base', { desc = 'Replace buffer with BASE' } },
    }

    return {
      enhanced_diff_hl = true,
      show_help_hints = false,
      watch_index = true,

      -- TODO!: make default merge diff3_horizontal I think
      -- TODO!: integrate NVKeymaps more for closing

      keymaps = {
        -- stylua: ignore
        view = {
          { 'n', 'q', actions.close, { desc = 'Close Diffview' } },
        },

        -- diff1/diff3/diff4: identical conflict keymaps, only non-conflict extras differ
        diff1 = conflict_d,
        diff3 = conflict_d,
        diff4 = conflict_d,

        -- file_panel: whole-file conflict resolution only
        -- stylua: ignore
        file_panel = {
          { 'n', 'q', actions.close, { desc = 'Close Diffview' } },
          { 'n', '<leader>cO', false },
          { 'n', '<leader>cT', false },
          { 'n', '<leader>cB', false },
          { 'n', '<leader>cA', false },
          { 'n', '<leader>dO', actions.conflict_choose_all('ours'),    { desc = 'Choose OURS (whole file)' } },
          { 'n', '<leader>dT', actions.conflict_choose_all('theirs'),  { desc = 'Choose THEIRS (whole file)' } },
          { 'n', '<leader>dB', actions.conflict_choose_all('base'),    { desc = 'Choose BASE (whole file)' } },
          { 'n', '<leader>dA', actions.conflict_choose_all('all'),     { desc = 'Choose ALL (whole file)' } },
        },

        -- stylua: ignore
        file_history_panel = {
          { 'n', 'q', actions.close, { desc = 'Close Diffview' } },
        },
      },

      -- ── hooks: tab renaming + diff2 highlighting ──────────────
      hooks = {
        view_opened = function(view)
          NVTabs.set_label { icon = '', name = 'diff' }
        end,
        view_closed = function() end,
        diff_buf_win_enter = function(_bufnr, _winid, ctx)
          if ctx.layout_name:match '^diff2' then
            if ctx.symbol == 'a' then
              vim.opt_local.winhl = table.concat({
                'DiffAdd:DiffviewDiffDelete',
                'DiffDelete:DiffviewDiffFill',
                'DiffChange:DiffviewDiffDelete',
                'DiffText:DiffviewDiffDeleteText',
              }, ',')
            elseif ctx.symbol == 'b' then
              vim.opt_local.winhl = table.concat({
                'DiffAdd:DiffviewDiffAdd',
                'DiffChange:DiffviewDiffAdd',
                'DiffText:DiffviewDiffAddText',
                'DiffDelete:DiffviewDiffFill',
              }, ',')
            end
          end
        end,
      },
    }
  end,

  keys = {
    {
      '<Leader>dl',
      '<Cmd>DiffviewFileHistory<CR>',
      desc = 'Diffview Log',
    },
    {
      '<Leader>dv',
      '<Cmd>DiffviewOpen<CR>',
      desc = 'Diffview',
    },
    {
      '<Leader>dL',
      '<Cmd>DiffviewFileHistory %<CR>',
      desc = 'Diffview Log (This File)',
    },
    {
      '<Leader>dh',
      '<Cmd>DiffviewFileHistory % --pin-local<CR>',
      desc = 'File History (Pinned to Working Tree)',
    },
  },
}
