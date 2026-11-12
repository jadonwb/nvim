-- Compare mode.
--
-- Diffview is for git history; this is for the everyday "show me two things
-- side by side": two files, or a file and a man page. The layout is suspended
-- while compare mode is open and restored exactly as it was when it closes.

NVCompare = {
  active = false,
  restored = false,
}

local function content_win()
  return NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
end

--- Leave the layout (remembering it) and give the editing area back.
local function suspend_layout()
  if NVSlots and NVSlots.is_applied() then
    NVSlots.toggle()
    NVCompare.restored = true
  end
end

local function set_bar(win, label)
  pcall(vim.api.nvim_set_option_value, 'winbar', '%#NvPanelBorder# ' .. label .. '  %#NvChipMuted# <leader>wc close ', { win = win })
end

---@param win WinID
---@return string
local function name_of(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= '' and vim.fn.fnamemodify(name, ':~:.') or '[No Name]'
end

--- Open `path` beside the current file. With no path, pick one.
---@param path? string
function NVCompare.file(path)
  suspend_layout()
  NVCompare.active = true

  local left = content_win()
  vim.api.nvim_set_current_win(left)
  if path and path ~= '' then
    vim.cmd('vsplit ' .. vim.fn.fnameescape(path))
    set_bar(left, 'Compare  ' .. name_of(left))
    set_bar(vim.api.nvim_get_current_win(), 'Compare  ' .. name_of(vim.api.nvim_get_current_win()))
    return
  end

  require('snacks').picker.files {
    confirm = function(picker, item)
      picker:close()
      if item and item.file then
        vim.cmd('vsplit ' .. vim.fn.fnameescape(item.file))
        set_bar(left, 'Compare  ' .. name_of(left))
        set_bar(vim.api.nvim_get_current_win(), 'Compare  ' .. name_of(vim.api.nvim_get_current_win()))
      end
    end,
  }
end

--- Open a man page in a vertical split beside the current file.
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

  suspend_layout()
  NVCompare.active = true
  local left = content_win()
  vim.api.nvim_set_current_win(left)
  -- `:Man` opens its own window; `:vertical` makes that a side-by-side split,
  -- so there is no intermediate empty split.
  vim.cmd('vertical Man ' .. page)
  local win = vim.api.nvim_get_current_win()
  set_bar(left, 'Compare  ' .. name_of(left))
  set_bar(win, 'Man  ' .. page)
end

--- Close the extra windows and restore the layout.
function NVCompare.close()
  if not NVCompare.active then
    return
  end
  pcall(vim.cmd, 'only')
  NVCompare.active = false
  if NVCompare.restored then
    NVCompare.restored = false
    NVSlots.toggle()
  end
end

function NVCompare.setup()
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

  vim.keymap.set('n', '<leader>wv', function()
    NVCompare.file()
  end, { desc = 'Compare: file in vertical split' })

  vim.keymap.set('n', '<leader>wm', function()
    NVCompare.man()
  end, { desc = 'Compare: man page in vertical split' })

  vim.keymap.set('n', '<leader>wc', NVCompare.close, { desc = 'Compare: close and restore layout' })
end

return NVCompare
