-- Autocmds that LazyVim installed and this config relies on.
--
-- Kept deliberately small: each entry has a visible effect. Anything that only
-- made LazyVim's own plugins behave is gone with LazyVim.

-- Reload files changed on disk when focus returns to Neovim. The buffer-level
-- checktime in editor/buffers.lua covers the editing buffer; this covers the
-- rest after a terminal command or a window switch.
vim.api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  group = vim.api.nvim_create_augroup('NV checktime', { clear = true }),
  callback = function()
    if vim.o.buftype ~= 'nofile' then
      vim.cmd 'checktime'
    end
  end,
})

vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('NV highlight_yank', { clear = true }),
  callback = function()
    if vim.fn.has 'nvim-0.13' == 1 then
      vim.hl.hl_op()
    else
      (vim.hl or vim.highlight).on_yank()
    end
  end,
})

vim.api.nvim_create_autocmd('VimResized', {
  group = vim.api.nvim_create_augroup('NV resize_splits', { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- Reopen a buffer at its last cursor position.
vim.api.nvim_create_autocmd('BufReadPost', {
  group = vim.api.nvim_create_augroup('NV last_loc', { clear = true }),
  callback = function(event)
    local buf = event.buf
    if vim.bo[buf].filetype == 'gitcommit' or vim.b[buf].nv_last_loc then
      return
    end
    vim.b[buf].nv_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Read-only scratch filetypes close with q.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('NV close_with_q', { clear = true }),
  pattern = {
    'PlenaryTestPopup',
    'checkhealth',
    'dbout',
    'gitsigns-blame',
    'grug-far',
    'help',
    'lspinfo',
    'qf',
    'startuptime',
    'tsplayground',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set('n', 'q', function()
        vim.cmd 'close'
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, { buffer = event.buf, silent = true, desc = 'Quit buffer' })
    end)
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('NV man_unlisted', { clear = true }),
  pattern = { 'man' },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

-- Prose filetypes wrap and spell-check.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('NV wrap_spell', { clear = true }),
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- json/jsonc honour conceallevel 0 so quotes and braces stay visible.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('NV json_conceal', { clear = true }),
  pattern = { 'json', 'jsonc', 'json5' },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Create intermediate directories on write.
vim.api.nvim_create_autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('NV auto_create_dir', { clear = true }),
  callback = function(event)
    if event.match:match '^%w%w+:[\\/][\\/]' then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown' },
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'gitcommit' },
  callback = function()
    vim.b.completion = false
  end,
})

-- Project-local config. Replaces LazyVim's root detector: the nearest ancestor
-- holding a .git entry or a lua/ directory, falling back to the buffer's cwd.
vim.api.nvim_create_autocmd('BufReadPre', {
  group = vim.api.nvim_create_augroup('NV project_config', { clear = true }),
  callback = function(event)
    local root = vim.fs.root(event.buf, { '.git', 'lua' })
    local cfg = root and (root .. '/.nvim.lua') or nil
    if cfg and vim.fn.filereadable(cfg) == 1 then
      dofile(cfg)
    end
  end,
})
