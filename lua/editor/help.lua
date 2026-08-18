NVHelp = {}

local DOC_FT = { help = true, man = true }
local PANEL_NAME = 'help_docs'

---@param bufnr BufID?
---@return boolean
function NVHelp.is_help(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  return vim.bo[buf].filetype == 'help'
end

---@param bufnr BufID?
---@return boolean
function NVHelp.is_doc(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  return DOC_FT[vim.bo[buf].filetype] == true
end

--- Move the current help/man window to the far-right companion slot.
--- Closes any other help/man window in the tab so only one doc panel exists.
function NVHelp.reposition()
  local win = vim.api.nvim_get_current_win()

  for _, other in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if other ~= win and NVHelp.is_doc(vim.api.nvim_win_get_buf(other)) then
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
    if NVHelp.is_doc(vim.api.nvim_win_get_buf(win)) then
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

function NVHelp.autocmds()
  local group = vim.api.nvim_create_augroup('NVHelpPanel', { clear = true })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    callback = function(ev)
      if not NVHelp.is_doc(ev.buf) then
        return
      end

      local win = vim.fn.bufwinid(ev.buf)
      if win == -1 or vim.w[win].nvhelp_panel then
        return
      end
      vim.api.nvim_set_current_win(win)
      -- Help must not open inside temporary tabs (diffview, focus).
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
    end,
  })
end
