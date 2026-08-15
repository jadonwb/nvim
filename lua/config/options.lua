-- FIXME: make sure now that I match reference config with layout manager, these options don't break anything / revisit these
vim.opt.termguicolors = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 4
vim.opt.cursorline = true
vim.o.cursorlineopt = 'number'
vim.opt.signcolumn = 'yes'

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4

vim.opt.timeoutlen = 300

vim.opt.scrolloff = 0
vim.opt.sidescrolloff = 8

vim.opt.autowrite = true
vim.opt.autoread = true

vim.opt.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus'

vim.opt.laststatus = 3
vim.opt.showmode = false
vim.opt.ruler = false
vim.opt.showtabline = 1
vim.opt.cmdheight = 1

vim.opt.smoothscroll = true

vim.opt.completeopt = 'menu,menuone,noselect'

vim.opt.pumblend = 10
vim.opt.pumheight = 10

vim.opt.wildmode = 'longest:full,full'

vim.opt.list = true
vim.opt.listchars = {
  -- tab = '» ', -- off by default now
  tab = '  ',
  trail = '·',
  precedes = '←',
  extends = '→',
  nbsp = '␣',
}

vim.opt.fillchars:append {
  eob = ' ',
  diff = '',
}

vim.opt.conceallevel = 2

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.mouse = 'a'

vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.splitkeep = 'screen'

vim.opt.winminwidth = 5

vim.opt.inccommand = 'nosplit'

vim.opt.wrap = false
vim.opt.linebreak = true

vim.opt.foldenable = true
vim.opt.foldcolumn = '1'
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

vim.opt.shiftround = true

vim.opt.whichwrap:append {
  ['<'] = true,
  ['>'] = true,
  ['['] = true,
  [']'] = true,
}

vim.opt.jumpoptions = 'view'

vim.opt.virtualedit = 'block'

vim.opt.grepprg = 'rg --vimgrep'
vim.opt.grepformat = '%f:%l:%c:%m'

vim.opt.spelllang = { 'en' }

-- W, I, c, C from LazyVim
vim.opt.shortmess:append {
  s = true,
}

vim.opt.updatetime = 200

vim.opt.swapfile = false

vim.opt.undofile = true
vim.opt.undolevels = 10000

vim.opt.confirm = true

vim.opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }

vim.o.hidden = true

vim.o.errorbells = false

vim.o.exrc = true
vim.o.secure = true

vim.g.markdown_recommended_style = 0

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
