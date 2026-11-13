-- Compare mode.
--
-- Diffview is for git history; this is for the everyday "show me two things
-- side by side": two files, or a file and a man page. It opens in its own
-- tab (the tab line is hidden, so it reads as a view, not a tab), so the
-- slot layout of the editing tab is never touched. <M-w> / <leader>lx, or
-- closing either side, closes the view and returns to the layout as it was.

NVCompare = {}

local function is_compare(tab)
  return vim.t[tab or 0].nv_compare == true
end

function NVCompare.active()
  return is_compare(vim.api.nvim_get_current_tabpage())
end

---@param win integer
---@return string
local function name_of(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].filetype == 'man' then
    return name:gsub('^man://', '')
  end
  return name ~= '' and vim.fn.fnamemodify(name, ':~:.') or '[No Name]'
end

--- The shared top strip: icon, what this side shows, keys right-aligned.
local function bar(win, icon)
  local name = name_of(win):gsub('%%', '%%%%')
  pcall(
    vim.api.nvim_set_option_value,
    'winbar',
    ('%%#NvTabStrip# %%#NvIcon#%s %%#NvTabActive#Compare%%#NvTabStrip#  %%#NvDim#%s%%=%%#NvKey# M-w %%#NvMuted# close '):format(icon, name),
    { win = win }
  )
end

--- New compare tab showing the current buffer; returns its window.
local function open_tab()
  local src = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(src)
  vim.cmd 'tabnew'
  vim.t.nv_compare = true
  local scratch = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(0, buf)
  if vim.api.nvim_buf_is_valid(scratch) and scratch ~= buf then
    pcall(vim.api.nvim_buf_delete, scratch, { force = true })
  end
  local left = vim.api.nvim_get_current_win()

  -- Closing either side ends the view.
  local tab = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_create_autocmd('WinClosed', {
    group = vim.api.nvim_create_augroup('NV compare ' .. tab, { clear = true }),
    callback = function()
      vim.schedule(function()
        if
          vim.api.nvim_tabpage_is_valid(tab)
          and #vim.tbl_filter(function(w)
            return vim.api.nvim_win_get_config(w).relative == ''
          end, vim.api.nvim_tabpage_list_wins(tab)) < 2
        then
          NVCompare.close(tab)
        end
      end)
    end,
  })
  return left
end

local function decorate()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      bar(win, vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'man' and '\u{f02d}' or '\u{f0e85}')
    end
  end
end

--- Open `path` beside the current file. With no path, pick one.
---@param path? string
function NVCompare.file(path)
  local function go(file)
    open_tab()
    vim.cmd('rightbelow vsplit ' .. vim.fn.fnameescape(file))
    decorate()
  end
  if path and path ~= '' then
    return go(path)
  end
  require('snacks').picker.files {
    title = 'Compare with',
    confirm = function(picker, item)
      picker:close()
      if item and item.file then
        go(item.file)
      end
    end,
  }
end

--- Open a man page beside the current file.
---@param page? string
function NVCompare.man(page)
  if not page or page == '' then
    vim.ui.input({ prompt = 'Man page: ' }, function(input)
      if input and input ~= '' then
        NVCompare.man(input)
      end
    end)
    return
  end
  open_tab()
  vim.cmd('rightbelow vertical Man ' .. page)
  decorate()
end

--- Close the compare view (the current one, or `tab`) and return.
---@param tab? integer
function NVCompare.close(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  if not (vim.api.nvim_tabpage_is_valid(tab) and is_compare(tab)) then
    return false
  end
  pcall(vim.api.nvim_del_augroup_by_name, 'NV compare ' .. tab)
  vim.api.nvim_set_current_tabpage(tab)
  pcall(vim.cmd, 'tabclose')
  return true
end

function NVCompare.setup()
  -- <M-w> in a compare view closes the view, not a buffer.
  if NVClose and NVClose.register then
    NVClose.register('compare', function()
      return NVCompare.close()
    end)
  end
  vim.api.nvim_create_user_command('NVCompare', function(args)
    local arg = vim.trim(args.args)
    if arg == 'close' then
      NVCompare.close()
    elseif arg:match '^man ' then
      NVCompare.man(arg:sub(5))
    elseif arg ~= '' then
      NVCompare.file(arg)
    else
      NVCompare.file()
    end
  end, {
    nargs = '*',
    desc = 'Compare two files, or a file and a man page',
    complete = function()
      return { 'close', 'man ' }
    end,
  })
  -- Keys: <leader>lv / lm / lx (features/layout/keymaps.lua).
end

return NVCompare
