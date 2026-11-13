NVHelp = {}

local DOC_FT = { help = true, man = true }
local PANEL_NAME = 'help_docs'

---@param bufnr BufID?
---@return boolean
function NVHelp.is_help(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  return DOC_FT[vim.bo[buf].filetype] == true
end

--- Move the current help/man window to the far-right companion slot.
--- Closes any other help/man window in the tab so only one doc panel exists.
function NVHelp.reposition()
  local win = vim.api.nvim_get_current_win()

  for _, other in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if other ~= win and NVHelp.is_help(vim.api.nvim_win_get_buf(other)) then
      if vim.api.nvim_win_is_valid(other) then
        vim.api.nvim_win_close(other, true)
      end
    end
  end

  vim.cmd 'wincmd L' -- far right, full height
  vim.wo[win].winfixwidth = true -- layout manager recognizes this as a companion panel
  local width = math.floor(vim.o.columns * NVCompanionPanels.width())
  vim.api.nvim_win_set_width(win, width)
end

--- Close the doc panel in the current tab, if present.
---@return boolean
function NVHelp.ensure_hidden()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  if #wins <= 1 then
    return false -- never close the last window
  end

  for _, win in ipairs(wins) do
    if NVHelp.is_help(vim.api.nvim_win_get_buf(win)) then
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      return true
    end
  end

  return false
end

function NVHelp.setup()
  NVCompanionPanels.register(PANEL_NAME, NVHelp.ensure_hidden)
  NVClose.register(PANEL_NAME, NVHelp.ensure_hidden)
end

--- The doc window's top strip: page name, then the reading keys right-aligned
--- (same style as the bottom panel's tab strip). Line numbers off.
local function doc_chrome(win, buf)
  local ft = vim.bo[buf].filetype
  local icon = ft == 'man' and '\u{f02d}' or '\u{f02d6}'
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t'):gsub('%%', '%%%%')
  vim.api.nvim_set_option_value(
    'winbar',
    ('%%#NvTabStrip# %%#NvIcon#%s %%#NvTabActive#%s%%#NvTabStrip#%%=%%#NvKey# K %%#NvMuted# follow  %%#NvKey# C-o %%#NvMuted# back  %%#NvKey# gO %%#NvMuted# contents  %%#NvKey# q %%#NvMuted# close '):format(
      icon,
      name
    ),
    { win = win }
  )
  vim.w[win].nv_doc_bar = true
  for opt, value in pairs { number = false, relativenumber = false, signcolumn = 'no', foldcolumn = '0', statuscolumn = '' } do
    pcall(vim.api.nvim_set_option_value, opt, value, { scope = 'local', win = win })
  end
end

function NVHelp.autocmds()
  local group = vim.api.nvim_create_augroup('NVHelpPanel', { clear = true })

  -- A doc pane sets a winbar; clear it when the window moves on so the label
  -- does not stick to the next file.
  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = group,
    callback = function(ev)
      if not NVHelp.is_help(ev.buf) then
        return
      end
      local win = vim.api.nvim_get_current_win()
      if vim.w[win].nv_doc_bar then
        vim.w[win].nv_doc_bar = nil
        pcall(vim.api.nvim_set_option_value, 'winbar', '', { win = win })
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType' }, {
    group = group,
    callback = function(ev)
      if not NVHelp.is_help(ev.buf) then
        return
      end

      local win = vim.fn.bufwinid(ev.buf)
      -- A compare view (features/compare.lua) places its own man page.
      if win == -1 or vim.w[win].nvhelp_panel or vim.t.nv_compare then
        return
      end

      -- With the layout on, a doc opens in the editing area instead of
      -- splitting it: a help split would carve a fifth column out of the grid.
      local win_buf = vim.api.nvim_win_get_buf(win)
      if NVSlots and NVSlots.is_applied() and vim.b[win_buf].nv_slot == nil then
        local centre = NVSlots.content_win()
        if not centre then
          return
        end
        -- Remember the file the reader came from exactly once. The handler
        -- fires again once the doc is displayed in the centre, and `:bprevious`
        -- is not reliable for an unlisted help buffer.
        if win ~= centre or vim.w[centre].nvhelp_previous == nil then
          local previous = vim.api.nvim_win_get_buf(centre)
          if previous ~= ev.buf then
            vim.w[centre].nvhelp_previous = previous
            vim.api.nvim_win_set_buf(centre, ev.buf)
          end
          if win ~= centre then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
        win = centre
        vim.api.nvim_set_current_win(win)
        doc_chrome(win, ev.buf)
        local function back()
          if not vim.api.nvim_win_is_valid(win) then
            return
          end
          pcall(vim.api.nvim_set_option_value, 'winbar', '', { win = win })
          vim.w[win].nv_doc_bar = nil
          local previous = vim.w[win].nvhelp_previous
          vim.w[win].nvhelp_previous = nil
          if previous and previous ~= ev.buf and vim.api.nvim_buf_is_valid(previous) then
            vim.api.nvim_win_set_buf(win, previous)
          else
            pcall(vim.cmd, 'bprevious')
          end
        end
        vim.keymap.set('n', 'q', back, { buffer = ev.buf, nowait = true, desc = 'Back to the file' })
        vim.keymap.set('n', '<Esc>', back, { buffer = ev.buf, nowait = true, desc = 'Back to the file' })
        return
      end

      if NVEnv.startup.purpose == 'pager' then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
            NVLualine.show_everything()
          end
        end)
        return
      end
      vim.api.nvim_set_current_win(win)
      -- Help must not open inside temporary tabs (diffview).
      if not NVCompanionPanels.ensure_exclusive(PANEL_NAME) then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end)
        return
      end
      vim.w[win].nvhelp_panel = true
      NVHelp.reposition()
      vim.keymap.set('n', 'q', function()
        if not NVHelp.ensure_hidden() then
          pcall(vim.cmd, 'close')
        end
      end, { buffer = ev.buf, nowait = true, desc = 'Close doc' })
    end,
  })
end
