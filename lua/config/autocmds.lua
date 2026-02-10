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

vim.api.nvim_create_autocmd('BufReadPre', {
  callback = function()
    local root = require('lazyvim.util.root').get()
    local cfg = root and (root .. '/.nvim.lua') or nil
    if cfg and vim.fn.filereadable(cfg) == 1 then
      dofile(cfg)
    end
  end,
})

-- vim.api.nvim_create_autocmd('User', {
--   pattern = 'PersistedSavePre',
--   callback = function()
--     local buffers = vim.api.nvim_list_bufs()
--
--     for _, buf in ipairs(buffers) do
--       if vim.api.nvim_buf_is_loaded(buf) then
--         local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
--         local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = buf })
--
--         if buftype ~= '' or not modifiable then
--           vim.api.nvim_buf_delete(buf, { force = true })
--         end
--       end
--     end
--   end,
-- })

-- vim.api.nvim_create_autocmd('BufRead', {
--   pattern = '*.md',
--   callback = function()
--     -- Get the full path of the current file
--     local file_path = vim.fn.expand '%:p'
--
--     -- Avoid running zk multiple times for the same buffer
--     if vim.b.zk_executed then
--       return
--     end
--     vim.b.zk_executed = true -- Mark as executed
--
--     -- Use `vim.defer_fn` to add a slight delay before executing `zk`
--     vim.defer_fn(function()
--       vim.cmd 'normal zk'
--       vim.notify('Folded keymaps', vim.log.levels.INFO)
--     end, 100) -- Delay in milliseconds (100ms should be enough)
--   end,
-- })
