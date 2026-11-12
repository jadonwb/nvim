-- File preview as an inset float over the editing area.
--
-- The preview is not a layout slot: it is a surface over the content window,
-- inset by a couple of rows and columns with a dimmed backdrop, so it reads as
-- a layer above the file instead of a second editor. It never takes focus and
-- never changes the buffer you are editing.

NVPreview = {
  enabled = false,
  buf = nil,
  win = nil,
  backdrop = nil,
  path = nil,
}

local MAX_LINES = 400

local function valid(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

---@return boolean
function NVPreview.is_open()
  return valid(NVPreview.win)
end

function NVPreview.hide()
  if valid(NVPreview.win) then
    pcall(vim.api.nvim_win_close, NVPreview.win, true)
  end
  if valid(NVPreview.backdrop) then
    pcall(vim.api.nvim_win_close, NVPreview.backdrop, true)
  end
  NVPreview.win = nil
  NVPreview.backdrop = nil
  NVPreview.path = nil
end

---@param target WinID
---@return { row: integer, col: integer, width: integer, height: integer }
local function geometry(target)
  local w = vim.api.nvim_win_get_width(target)
  local h = vim.api.nvim_win_get_height(target)
  local height = math.max(3, math.min(24, h - 4))
  return {
    row = math.max(0, math.floor((h - height) / 2)),
    col = math.max(0, math.floor((w - (w - 4)) / 2)),
    width = math.max(20, w - 4),
    height = height,
  }
end

---@param target WinID
local function draw(target)
  local geo = geometry(target)

  if not valid(NVPreview.win) then
    local backdrop_buf = vim.api.nvim_create_buf(false, true)
    NVPreview.backdrop = vim.api.nvim_open_win(backdrop_buf, false, {
      relative = 'win',
      win = target,
      row = 0,
      col = 0,
      width = vim.api.nvim_win_get_width(target),
      height = vim.api.nvim_win_get_height(target),
      style = 'minimal',
      focusable = false,
      border = 'none',
      zindex = 40,
    })
    vim.wo[NVPreview.backdrop].winblend = 40

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    NVPreview.buf = buf

    NVPreview.win = vim.api.nvim_open_win(buf, false, {
      relative = 'win',
      win = target,
      row = geo.row,
      col = geo.col,
      width = geo.width,
      height = geo.height,
      style = 'minimal',
      border = 'single',
      zindex = 41,
      title = ' preview ',
      title_pos = 'center',
    })
    vim.wo[NVPreview.win].winhighlight = 'FloatBorder:LineNr,Normal:NormalFloat'
    vim.wo[NVPreview.win].wrap = false
  else
    vim.api.nvim_win_set_config(NVPreview.win, {
      relative = 'win',
      win = target,
      row = geo.row,
      col = geo.col,
      width = geo.width,
      height = geo.height,
    })
    if valid(NVPreview.backdrop) then
      vim.api.nvim_win_set_config(NVPreview.backdrop, {
        relative = 'win',
        win = target,
        row = 0,
        col = 0,
        width = vim.api.nvim_win_get_width(target),
        height = vim.api.nvim_win_get_height(target),
      })
    end
  end
end

--- Show `path` in the preview. No-op while preview is disabled.
---@param path string
---@return boolean
function NVPreview.show(path)
  if not NVPreview.enabled or type(path) ~= 'string' or path == '' then
    return false
  end
  if vim.fn.filereadable(path) == 0 then
    NVPreview.hide()
    return false
  end

  local target = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  if not valid(target) then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, path, '', MAX_LINES)
  if not ok then
    return false
  end

  draw(target)
  local buf = NVPreview.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = vim.filetype.match { filename = path } or 'text'
  NVPreview.path = path

  pcall(vim.api.nvim_win_set_config, NVPreview.win, {
    relative = 'win',
    win = target,
    title = (' %s '):format(vim.fn.fnamemodify(path, ':~:.')),
    title_pos = 'center',
  })
  return true
end

--- Preview the entry under the explorer cursor, if preview is on.
function NVPreview.from_cursor()
  if not NVPreview.enabled then
    return
  end
  local entry, dir = require('features.layout.providers').explorer_entry()
  if not entry or entry.type ~= 'file' then
    NVPreview.hide()
    return
  end
  local path = entry.name
  if path:sub(1, 1) ~= '/' and dir then
    path = dir .. '/' .. entry.name
  end
  NVPreview.show(path)
end

--- Toggle preview mode. Turning it off closes the float.
---@return boolean enabled
function NVPreview.toggle()
  NVPreview.enabled = not NVPreview.enabled
  if NVPreview.enabled then
    NVPreview.from_cursor()
  else
    NVPreview.hide()
  end
  NVMessages.info(NVPreview.enabled and 'Preview on' or 'Preview off')
  return NVPreview.enabled
end

function NVPreview.setup()
  -- The float is anchored to the content window; a resize or a different tab
  -- would leave it in the wrong place.
  local group = vim.api.nvim_create_augroup('NV preview', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = group,
    callback = function()
      if NVPreview.is_open() then
        local target = NVSlots and NVSlots.content_win and NVSlots.content_win()
        if target then
          draw(target)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'WinClosed', 'TabLeave', 'BufLeave' }, {
    group = group,
    callback = function()
      vim.schedule(function()
        local target = NVSlots and NVSlots.content_win and NVSlots.content_win()
        if not target then
          NVPreview.hide()
        end
      end)
    end,
  })
end

return NVPreview
