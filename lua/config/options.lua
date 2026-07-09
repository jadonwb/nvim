vim.g.ai_cmp = false
vim.o.showtabline = 0
vim.o.cursorlineopt = 'number'
vim.o.swapfile = false
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.autoindent = true
vim.o.breakindent = true
vim.o.incsearch = true
vim.o.scrolloff = 0
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.opt.fillchars = { eob = ' ' }
vim.o.undofile = true
vim.o.undodir = vim.fn.expand '~/.vim/undodir'
-- FIXME: what do I want here?
-- vim.o.timeoutlen = 50
-- vim.opt.timeoutlen = 50
vim.o.autoread = true
local undodir = vim.fn.expand '~/.vim/undodir'
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end
vim.o.hidden = true
vim.o.errorbells = false
vim.o.exrc = true
vim.o.secure = true

-- Always sync unnamed register with system clipboard (overrides LazyVim's SSH disable)
vim.opt.clipboard = "unnamedplus"

-- When in SSH, use a hybrid clipboard: server clipboard (wl-copy) + client clipboard (OSC 52)
if vim.env.SSH_CONNECTION then
  local osc52 = require("vim.ui.clipboard.osc52")

  ---Pipe text to wl-copy (server clipboard)
  local function pipe_to(text)
    local f = io.popen("wl-copy", "w")
    if f then
      f:write(text)
      f:close()
    end
  end

  ---Read from wl-paste (server clipboard)
  ---@return string|nil
  local function read_paste()
    local f = io.popen("wl-paste --no-newline", "r")
    if f then
      local content = f:read("*a")
      f:close()
      return content
    end
    return nil
  end

  vim.g.clipboard = {
    name = "hybrid (wl-copy + OSC52)",
    copy = {
      ["+"] = function(lines)
        local text = table.concat(lines, "\n")
        pipe_to(text)            -- server clipboard via wl-copy
        osc52.copy("+")(lines)  -- client clipboard via OSC 52
      end,
      ["*"] = function(lines)
        local text = table.concat(lines, "\n")
        pipe_to(text)
        osc52.copy("*")(lines)
      end,
    },
    paste = {
      ["+"] = function()
        -- Try server clipboard first (fast), fall back to OSC 52 (client clipboard)
        local content = read_paste()
        if content and #content > 0 then
          return vim.split(content, "\n")
        end
        local result = osc52.paste("+")()
        if type(result) == "table" then
          return result
        end
        return { "" }
      end,
      ["*"] = function()
        local content = read_paste()
        if content and #content > 0 then
          return vim.split(content, "\n")
        end
        local result = osc52.paste("*")()
        if type(result) == "table" then
          return result
        end
        return { "" }
      end,
    },
  }
end

vim.filetype.add {
  extension = {
    -- systemd unit files
    service = 'systemd',
    socket = 'systemd',
    timer = 'systemd',
    mount = 'systemd',
    automount = 'systemd',
    swap = 'systemd',
    target = 'systemd',
    path = 'systemd',
    slice = 'systemd',
    scope = 'systemd',
    device = 'systemd',

    -- Podman Quadlet files
    container = 'systemd',
    volume = 'systemd',
    network = 'systemd',
    kube = 'systemd',
    pod = 'systemd',
    build = 'systemd',
    image = 'systemd',
  },
}
