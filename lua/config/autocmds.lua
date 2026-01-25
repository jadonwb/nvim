vim.api.nvim_create_autocmd('FileType', {
  pattern = { '*' },
  callback = function()
    vim.opt.formatoptions:remove { 'c', 'r', 'o' }
  end,
  group = vim.api.nvim_create_augroup('disable_newline_comment', { clear = true }),
  desc = 'Disable New Line Comment',
})

local function open_with_app(apps)
  return function()
    if type(apps) == 'string' then
      apps = { apps }
    end

    local file_path = vim.fn.expand '%:p'

    for _, app in ipairs(apps) do
      if app == 'default' then
        vim.fn.jobstart({ 'xdg-open', file_path }, { detach = true })
        vim.cmd 'bdelete'
        return
      elseif vim.fn.executable(app) == 1 then
        vim.fn.jobstart({ app, file_path }, { detach = true })
        vim.cmd 'bdelete'
        return
      end
    end

    vim.notify('No suitable application found for opening ' .. file_path, vim.log.levels.WARN)
  end
end

local file_associations = {
  pdf = { 'default' },
}

for ext, apps in pairs(file_associations) do
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    pattern = '*.' .. ext,
    callback = open_with_app(apps),
  })
end

vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = { 'c', 'cpp', 'cmake' },
  callback = function()
    vim.b.autoformat = false
  end,
})

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { '*.env', '*.env.*' },
  callback = function()
    vim.b.autoformat = false
  end,
})

vim.api.nvim_create_autocmd('BufReadPre', {
  callback = function()
    local root = require('lazyvim.util.root').get()
    local cfg = root and (root .. '/.nvim.lua') or nil
    if cfg and vim.fn.filereadable(cfg) == 1 then
      dofile(cfg)
    end
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', { pattern = vim.fn.expand '$HOME/.config/kitty/kitty.conf', command = 'silent !kill -SIGUSR1 $(pgrep kitty)' })

-- vim.api.nvim_create_autocmd(
--   { "BufWinLeave", "BufWritePost", "WinLeave", "TabLeave" },
--   {
--     group = vim.api.nvim_create_augroup("PersistenceAutoSave", { clear = true }),
--     callback = function()
--       require("persistence").save()
--     end,
--   }
-- )
