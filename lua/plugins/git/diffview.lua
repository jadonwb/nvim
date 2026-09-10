NVDiffview = {}

local dv_fn = {}
local cleanup_scheduled = {}

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

-- Only user actions finish a dedicated difftool invocation. Session cleanup
-- continues to use ensure_hidden(), which never exits the editor.
function NVDiffview.close()
  if not dv_fn.current_diff() then
    return false
  end
  if NVEnv.startup.purpose == 'difftool' then
    NVQuit.save_and_quit()
  else
    dv_fn.hide_current_diff()
  end
  return true
end

function NVDiffview.close_other_tabs(view)
  if NVEnv.startup.purpose ~= 'difftool' then
    return
  end
  if not view or cleanup_scheduled[view.tabpage] then
    return
  end
  cleanup_scheduled[view.tabpage] = true
  -- Diffview creates its tab during the open event. Defer until that tab and
  -- the original editor tab are both fully registered, then keep only the
  -- Diffview tab for a dedicated difftool invocation.
  vim.defer_fn(function()
    if not vim.api.nvim_tabpage_is_valid(view.tabpage) then
      cleanup_scheduled[view.tabpage] = nil
      return
    end
    local diff_tab = view.tabpage
    local tabs = vim.api.nvim_list_tabpages()
    for _, tab in ipairs(tabs) do
      if tab ~= diff_tab and vim.api.nvim_tabpage_is_valid(tab) then
        vim.api.nvim_set_current_tabpage(tab)
        pcall(vim.cmd, 'tabclose')
      end
    end
    if vim.api.nvim_tabpage_is_valid(diff_tab) then
      vim.api.nvim_set_current_tabpage(diff_tab)
    end
    vim.schedule(function()
      vim.o.showtabline = 2
    end)
    cleanup_scheduled[diff_tab] = nil
  end, 50)
end

function NVDiffview.setup()
  NVTabs.register_type {
    name = 'diffview',
    is_temporary = true,
    is_match = NVDiffview.is_diffview_tab,
    close_hook = NVDiffview.ensure_hidden,
    user_close_hook = NVDiffview.close,
  }
end

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

      view = {
        merge_tool = {
          layout = 'diff3_mixed',
        },
      },

      keymaps = {
        -- stylua: ignore
        view = {
          { 'n', NVKeymaps.close, NVDiffview.close, { desc = 'Close Diffview' } },
        },

        -- diff1/diff3/diff4: identical conflict keymaps, only non-conflict extras differ
        diff1 = conflict_d,
        diff3 = conflict_d,
        diff4 = conflict_d,

        -- file_panel: whole-file conflict resolution only
        -- stylua: ignore
        file_panel = {
          -- Preserve Diffview's contextual action: in the file panel this
          -- closes the panel; pressing close again from a view closes the view.
          { 'n', NVKeymaps.close, actions.close, { desc = 'Close Diffview panel' } },
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
          { 'n', NVKeymaps.close, actions.close, { desc = 'Close Diffview' } },
        },
      },

      -- ── hooks: tab renaming + diff2 highlighting ──────────────
      hooks = {
        view_opened = function(view)
          NVDiffview.close_other_tabs(view)
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
      function()
        if NVTabs.is_temporary(vim.api.nvim_get_current_tabpage()) then
          return
        end
        vim.cmd 'DiffviewFileHistory'
      end,
      desc = 'Diffview Log',
    },
    {
      '<Leader>dv',
      function()
        if NVTabs.is_temporary(vim.api.nvim_get_current_tabpage()) then
          return
        end
        vim.cmd 'DiffviewOpen'
      end,
      desc = 'Diffview',
    },
    {
      '<Leader>dL',
      function()
        if NVTabs.is_temporary(vim.api.nvim_get_current_tabpage()) then
          return
        end
        vim.cmd 'DiffviewFileHistory %'
      end,
      desc = 'Diffview Log (This File)',
    },
    {
      '<Leader>dh',
      function()
        if NVTabs.is_temporary(vim.api.nvim_get_current_tabpage()) then
          return
        end
        vim.cmd 'DiffviewFileHistory % --pin-local'
      end,
      desc = 'File History (Pinned to Working Tree)',
    },
  },
}
