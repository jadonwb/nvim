-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- [[ Disable new line comment ]]
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    vim.opt.formatoptions:remove { 'c', 'r', 'o' }
  end,
  group = vim.api.nvim_create_augroup('disable_newline_comment', { clear = true }),
  desc = 'Disable New Line Comment',
})

-- [[ Open files with external applications ]]
local function open_with_app(app)
  return function()
    if vim.fn.executable(app) == 0 then
      return
    end

    local file_path = vim.fn.expand '%:p'
    vim.fn.jobstart({ app, file_path }, { detach = true })
    vim.cmd 'bdelete'
  end
end

local file_associations = {
  pdf = 'zathura', -- or "tdf"
  -- You can add more file types here
  -- png = "feh",
  -- mp4 = "mpv",
}

for ext, app in pairs(file_associations) do
  -- vim.api.nvim_create_autocmd({ 'BufReadPre', 'FileReadPre' }, {
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    pattern = '*.' .. ext,
    callback = open_with_app(app),
  })
end
