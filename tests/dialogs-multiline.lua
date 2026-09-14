-- Tests for the opt-in multiline NVDialogs.input (lua/editor/dialogs.lua).
-- Run: nvim --headless -u NONE -l /home/jadon/.config/nvim/tests/dialogs-multiline.lua
-- Real float windows in a headless instance; no service, no model calls.
-- (Headless input processing cannot simulate typing; newline semantics are
-- pinned through the mapping contract and the normal-mode split callback.)

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/dialogs-multiline.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script)))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path

require 'editor.borders'
require 'editor.keymap'
require 'editor.keys'
require 'editor.dialogs'

local passed, failed, failures = 0, 0, {}

local function test(name, cb)
  -- Close any dialog left open by a failed test before running this one.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == 'nv-dialog' and vim.bo[b].buftype == 'nofile' then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  local ok, err = pcall(cb)
  if ok then
    passed = passed + 1
    print('ok - ' .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = name
    print('NOT OK - ' .. name .. '\n  ' .. tostring(err))
  end
  -- Deterministic screen for every test.
  vim.o.columns = 80
  vim.o.lines = 24
end

local function eq(a, b, what)
  if not vim.deep_equal(a, b) then
    error((what or 'value') .. ' mismatch:\n  actual:   ' .. vim.inspect(a) .. '\n  expected: ' .. vim.inspect(b), 2)
  end
end

--- The newest open dialog buffer (scratch nofile with the nv-dialog filetype).
local function dialog_buf()
  local newest
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == 'nv-dialog' and vim.bo[b].buftype == 'nofile' then
      newest = newest and math.max(newest, b) or b
    end
  end
  assert(newest, 'no open dialog buffer')
  return newest
end

local function dialog_win(buf)
  local win = vim.fn.bufwinid(buf)
  assert(win ~= -1, 'dialog window is displayed')
  return win
end

--- Buffer-local map's Lua callback (nil when unmapped).
local function map_cb(buf, mode, lhs)
  return vim.api.nvim_buf_call(buf, function()
    local map = vim.fn.maparg(lhs, mode, false, true)
    if type(map) ~= 'table' or next(map) == nil or map.callback == nil then
      return nil
    end
    return map.callback
  end)
end

--- Cancel the dialog under the cursor via Escape (normal mode).
local function cancel_dialog(buf)
  local esc = map_cb(buf, 'n', '<Esc>')
  assert(type(esc) == 'function', 'Esc cancels')
  esc()
  vim.wait(200, function()
    return not vim.api.nvim_buf_is_valid(buf)
  end)
end

local function set_dialog_text(buf, lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--------------------------------------------------------------------------------

test('default single-line input keeps Enter-submit and computed sizing', function()
  local result
  NVDialogs.input({ prompt = 'Tab name: ' }, function(value)
    result = value
  end)
  local buf = dialog_buf()
  local win = dialog_win(buf)

  -- Sizing: min_width 40 + pad 4, one line tall (0.6 caps do not bind at 80x24).
  eq(vim.api.nvim_win_get_width(win), 44, 'default width')
  eq(vim.api.nvim_win_get_height(win), 1, 'default height')
  eq(vim.wo[win].wrap, true, 'wrap on')

  -- Insert mode also submits on Enter (unchanged default).
  local submit_i = map_cb(buf, 'i', '<CR>')
  assert(type(submit_i) == 'function', 'insert <CR> submits by default')
  set_dialog_text(buf, { 'typed name' })
  submit_i()
  vim.wait(200, function() return result ~= nil end)
  eq(result, 'typed name', 'insert-mode Enter submitted the text')
  eq(vim.api.nvim_buf_is_valid(buf), false, 'dialog closed after submit')
end)

test('default normal-mode Enter still submits after the multiline addition', function()
  local result
  NVDialogs.input({ prompt = 'Other: ' }, function(value)
    result = value
  end)
  local buf = dialog_buf()
  local submit_n = map_cb(buf, 'n', '<CR>')
  assert(type(submit_n) == 'function', 'normal <CR> submits by default')
  set_dialog_text(buf, { 'second' })
  submit_n()
  vim.wait(200, function() return result ~= nil end)
  eq(result, 'second', 'normal-mode Enter submitted')
end)

test('default multiline input (no explicit size) keeps the computed single-line sizing', function()
  NVDialogs.input({ prompt = 'Q: ', multiline = true }, function() end)
  local buf = dialog_buf()
  local win = dialog_win(buf)
  eq(vim.api.nvim_win_get_width(win), 44, 'width from min_width + pad')
  eq(vim.api.nvim_win_get_height(win), 1, 'height tracks the default text')
  cancel_dialog(buf)
end)

test('multiline input requests explicit dimensions, clamped to the screen, wrapping on', function()
  vim.o.columns = 200
  vim.o.lines = 50
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true, width = 74, height = 6 }, function() end)
  local buf = dialog_buf()
  local win = dialog_win(buf)
  eq(vim.api.nvim_win_get_width(win), 74, 'explicit width honored when it fits')
  eq(vim.api.nvim_win_get_height(win), 6, 'explicit height honored when it fits')
  eq(vim.wo[win].wrap, true, 'wrap enabled for multiline')
  cancel_dialog(buf)

  -- Clamped to the 0.6 screen caps when the request does not fit.
  vim.o.columns = 80
  vim.o.lines = 24
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true, width = 74, height = 100 }, function() end)
  local buf2 = dialog_buf()
  local win2 = dialog_win(buf2)
  eq(vim.api.nvim_win_get_width(win2), 48, 'width clamped to 0.6 columns')
  eq(vim.api.nvim_win_get_height(win2), 13, 'height clamped to 0.6 lines')
  cancel_dialog(buf2)
end)

test('multiline Enter inserts a newline and only Alt+Enter submits', function()
  local result
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true, width = 74, height = 6 }, function(value)
    result = value
  end)
  local buf = dialog_buf()

  -- Insert-mode Enter is deliberately unmapped: the native newline lands
  -- exactly where the cursor is.
  eq(map_cb(buf, 'i', '<CR>'), nil, 'insert <CR> is native in multiline')

  -- Normal-mode Enter inserts a newline by splitting the line at the cursor.
  set_dialog_text(buf, { 'hello', 'world' })
  local win = dialog_win(buf)
  vim.api.nvim_win_set_cursor(win, { 1, 2 }) -- between "he" and "llo"
  local submit_n = map_cb(buf, 'n', '<CR>')
  assert(type(submit_n) == 'function', 'normal <CR> is mapped in multiline')
  eq(result, nil, 'normal Enter did not submit')
  submit_n()
  eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { 'he', 'llo', 'world' }, 'normal Enter split the line at the cursor')
  eq(result, nil, 'normal Enter still did not submit')

  -- Alt+Enter submits the joined lines from insert mode...
  set_dialog_text(buf, { 'first line', 'second line' })
  local submit_i = map_cb(buf, 'i', '<A-CR>')
  assert(type(submit_i) == 'function', 'insert Alt+Enter submits in multiline')
  submit_i()
  vim.wait(200, function() return result ~= nil end)
  eq(result, 'first line\nsecond line', 'insert Alt+Enter submitted all lines joined')
  eq(vim.api.nvim_buf_is_valid(buf), false, 'dialog closed after multiline submit')

  -- ...and from normal mode.
  result = nil
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true, width = 74, height = 6 }, function(value)
    result = value
  end)
  local buf2 = dialog_buf()
  local submit_n2 = map_cb(buf2, 'n', '<A-CR>')
  assert(type(submit_n2) == 'function', 'normal Alt+Enter submits in multiline')
  set_dialog_text(buf2, { 'a', 'b' })
  submit_n2()
  vim.wait(200, function() return result ~= nil end)
  eq(result, 'a\nb', 'normal Alt+Enter submitted')
end)

test('multiline cancellation is unchanged and fires the callback exactly once', function()
  local calls = {}
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true, width = 74, height = 6 }, function(value)
    calls[#calls + 1] = value
  end)
  local buf = dialog_buf()

  -- Escape in normal mode cancels (insert-mode Esc uses the same resolve).
  local esc_n = map_cb(buf, 'n', '<Esc>')
  assert(type(esc_n) == 'function', 'normal Esc cancels')
  esc_n()
  vim.wait(200, function() return #calls >= 1 end)
  eq(calls, { nil }, 'Escape cancelled with nil exactly once')
  eq(vim.api.nvim_buf_is_valid(buf), false, 'dialog closed on cancel')

  -- q and <M-w> cancel; further resolve attempts (buffer leave after resolve)
  -- must not re-fire the callback.
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true }, function(value)
    calls[#calls + 1] = value
  end)
  local buf2 = dialog_buf()
  local q = map_cb(buf2, 'n', 'q')
  assert(type(q) == 'function', 'q cancels')
  local mw = map_cb(buf2, 'n', NVKeymaps.close)
  assert(type(mw) == 'function', '<M-w> cancels')
  q()
  vim.wait(200, function() return #calls >= 2 end)
  eq(vim.api.nvim_buf_is_valid(buf2), false, 'dialog closed on q')
  pcall(mw) -- after close: must be a no-op
  pcall(function()
    vim.api.nvim_exec_autocmds('BufLeave', { buffer = buf2 })
  end)
  vim.wait(100, function() return false end)
  eq(calls, { nil, nil }, 'callback fired exactly once per dialog')

  -- Leaving the open dialog buffer cancels.
  NVDialogs.input({ prompt = 'Feedback: ', multiline = true }, function(value)
    calls[#calls + 1] = value
  end)
  local buf3 = dialog_buf()
  vim.api.nvim_exec_autocmds('BufLeave', { buffer = buf3 })
  vim.wait(200, function() return #calls >= 3 end)
  eq(calls, { nil, nil, nil }, 'buffer leave cancelled')
end)

test('select dialog defaults are unchanged', function()
  local result
  NVDialogs.select({ title = 'Pick', options = { 'A', 'B' } }, function(choice)
    result = choice
  end)
  local buf = dialog_buf()
  local win = dialog_win(buf)
  -- Two option lines; width from the longest option/title + pad.
  eq(vim.api.nvim_win_get_height(win), 2, 'select height tracks option rows')
  eq(vim.api.nvim_win_get_width(win), 12, 'select width from title/content + pad')
  eq(map_cb(buf, 'i', '<CR>') ~= nil, true, 'insert Enter confirms')
  local confirm = map_cb(buf, 'n', '<CR>')
  confirm()
  vim.wait(200, function() return result ~= nil end)
  eq(result, 'A', 'select callback received the chosen option')
  eq(vim.api.nvim_buf_is_valid(buf), false, 'select closed after choice')
end)

test('info dialog defaults are unchanged', function()
  NVDialogs.info({ title = 'Info', lines = { 'x' } })
  local buf = dialog_buf()
  local win = dialog_win(buf)
  eq(vim.api.nvim_win_get_height(win), 3, 'info height tracks content + footer')
  eq(map_cb(buf, 'i', '<CR>'), nil, 'info has no insert-mode bindings')
  local close = map_cb(buf, 'n', 'q')
  assert(type(close) == 'function', 'q closes info')
  close()
  vim.wait(200, function() return not vim.api.nvim_buf_is_valid(buf) end)
end)

print(('\ntests: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  os.exit(1)
end
os.exit(0)
