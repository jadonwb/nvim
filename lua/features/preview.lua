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
  backdrop_buf = nil,
  path = nil,
}

local MAX_LINES = 400

local function valid(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

-- ── images ─────────────────────────────────────────────────────────────────
--
-- PNG files preview as the image itself (vim.ui.img: the Kitty graphics
-- protocol, so WezTerm with enable_kitty_graphics, kitty, ghostty). Other
-- terminals, and other formats, show the file's text as before.

local image = nil ---@type { id: integer, w: integer, h: integer }?
local image_ok = nil ---@type boolean? terminal support, probed once

---@return boolean
local function images_supported()
  if image_ok == nil then
    local ok, supported = pcall(vim.ui.img._supported, { timeout = 300 })
    image_ok = ok and supported == true
  end
  return image_ok
end

--- Pixel size from a PNG header (IHDR), or nil when `data` is not a PNG.
---@param data string
---@return integer?, integer?
local function png_size(data)
  if data:sub(1, 8) ~= '\137PNG\r\n\26\n' or #data < 24 then
    return nil
  end
  local function u32(i)
    local a, b, c, d = data:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

local function hide_image()
  if image then
    pcall(vim.ui.img.del, image.id)
    image = nil
  end
end

--- Place the image inside the preview window, below its caption line, at
--- the largest size that keeps its aspect (a cell is about twice as tall
--- as it is wide).
local function place_image()
  if not (image and valid(NVPreview.win)) then
    return
  end
  -- From the float's config: its screen position is only resolved at the
  -- next redraw, and a float placed right after opening reads stale.
  local cfg = vim.api.nvim_win_get_config(NVPreview.win)
  local base = vim.api.nvim_win_get_position(cfg.win)
  local pos = { base[1] + cfg.row, base[2] + cfg.col }
  local W = vim.api.nvim_win_get_width(NVPreview.win)
  local H = vim.api.nvim_win_get_height(NVPreview.win) - 1
  local ratio = (image.w / image.h) * 2
  local w, h = W, math.floor(W / ratio)
  if h > H then
    w, h = math.floor(H * ratio), H
  end
  w, h = math.max(1, w), math.max(1, h)
  -- Screen rows / cols are 1-based; +1 for the border, +1 for the caption.
  pcall(vim.ui.img.set, image.id, {
    row = pos[1] + 3,
    col = pos[2] + 2 + math.floor((W - w) / 2),
    width = w,
    height = h,
    zindex = 60,
  })
end

--- Show `data` (PNG bytes) in the preview; false when it cannot be shown.
---@param data string
---@return boolean
local function show_image(data)
  local pw, ph = png_size(data)
  if not (pw and images_supported()) then
    return false
  end
  hide_image()
  local ok, id = pcall(vim.ui.img.set, data, { row = 1, col = 1, width = 1, height = 1, zindex = 60 })
  if not ok then
    return false
  end
  image = { id = id, w = pw, h = ph }
  place_image()
  return true
end

---@return boolean
function NVPreview.is_open()
  return valid(NVPreview.win)
end

function NVPreview.hide()
  hide_image()
  if valid(NVPreview.win) then
    pcall(vim.api.nvim_win_close, NVPreview.win, true)
  end
  if valid(NVPreview.backdrop) then
    pcall(vim.api.nvim_win_close, NVPreview.backdrop, true)
  end
  if NVPreview.backdrop_buf and vim.api.nvim_buf_is_valid(NVPreview.backdrop_buf) then
    pcall(vim.api.nvim_buf_delete, NVPreview.backdrop_buf, { force = true })
  end
  NVPreview.buf = nil
  NVPreview.win = nil
  NVPreview.backdrop = nil
  NVPreview.backdrop_buf = nil
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
    -- A previous float may have been closed by the user; never stack a second
    -- backdrop or a second preview window.
    if valid(NVPreview.backdrop) then
      pcall(vim.api.nvim_win_close, NVPreview.backdrop, true)
    end
    local backdrop_buf = vim.api.nvim_create_buf(false, true)
    NVPreview.backdrop_buf = backdrop_buf
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
    vim.wo[NVPreview.backdrop].winblend = NVUi and NVUi.BACKDROP_BLEND or 70
    vim.wo[NVPreview.backdrop].winhighlight = 'Normal:NvBackdrop'

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    NVPreview.buf = buf

    -- Close it even if the mouse focuses it; window navigation skips it.
    vim.keymap.set('n', 'q', NVPreview.hide, { buffer = buf, nowait = true })
    vim.keymap.set('n', '<Esc>', NVPreview.hide, { buffer = buf, nowait = true })

    NVPreview.win = vim.api.nvim_open_win(buf, false, {
      relative = 'win',
      win = target,
      row = geo.row,
      col = geo.col,
      width = geo.width,
      height = geo.height,
      style = 'minimal',
      border = 'single',
      focusable = false,
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

  -- A PNG shows as the image when the terminal can draw it.
  local picture
  if path:lower():match '%.png$' then
    local fd = io.open(path, 'rb')
    picture = fd and fd:read '*a'
    if fd then
      fd:close()
    end
  end

  local lines
  if not picture then
    local ok
    ok, lines = pcall(vim.fn.readfile, path, '', MAX_LINES)
    if not ok then
      return false
    end
  end

  draw(target)
  hide_image()
  local buf = NVPreview.buf
  local shown = picture and show_image(picture)
  if picture then
    local pw, ph = png_size(picture)
    lines = { pw and ('  %d × %d px · %.1f KB'):format(pw, ph, #picture / 1024) or '  not a PNG file' }
    if not shown and pw then
      lines[#lines + 1] = ''
      lines[#lines + 1] = '  Images need a terminal with the Kitty graphics protocol.'
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = shown and 'nvpreview_image' or (vim.filetype.match { filename = path } or 'text')
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
          place_image()
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(ev)
      if NVPreview.win and ev.win == NVPreview.win then
        NVPreview.hide()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'TabLeave', 'BufLeave' }, {
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
