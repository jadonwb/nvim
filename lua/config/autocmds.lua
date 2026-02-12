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

vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = { '*' },
  callback = function()
    if vim.fn.expand('%:t'):match '%.tmpl$' then
      -- vim.treesitter.stop()

      vim.cmd [[
        " Match entire lines that are chezmoi directives (if/else/end/range/etc)
        syntax match ChezmoiDirective "^\s*{{-\?\s*\(if\|else\|end\|range\|with\|define\|template\|block\).*-\?}}\s*$"
        " Also match lines with just delimiters
        syntax match ChezmoiDirective "^\s*{{-\?.*-\?}}\s*$"
        " Style as comment
        highlight link ChezmoiDirective Comment
      ]]
    end
  end,
})

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.tmpl',
  callback = function()
    local name = vim.api.nvim_buf_get_name(0)
    local ft = nil

    -- Pattern-based mappings
    local patterns = {
      { 'dot_zshrc%.tmpl$', 'zsh' },
      { 'dot_zshenv%.tmpl$', 'zsh' },
      { 'dot_zprofile%.tmpl$', 'zsh' },
      { 'dot_gitconfig%.tmpl$', 'gitconfig' },
      { 'ghostty/config%.tmpl$', 'config' },
      { 'hypr/.*%.conf%.tmpl$', 'hyprlang' },
      { 'tmux/tmux%.conf%.tmpl$', 'tmux' },
      { 'kitty/kitty%.conf%.tmpl$', 'kitty' },
    }

    -- Check pattern matches first
    for _, pattern in ipairs(patterns) do
      if name:match(pattern[1]) then
        ft = pattern[2]
        break
      end
    end

    -- Fall back to extension-based detection
    if not ft then
      local base = name:match '^.+%.([^%.]+)%.tmpl$'
      if base and base ~= 'conf' then
        ft = base
      end
    end

    if ft then
      vim.bo.filetype = ft
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

--override lazyvim's markdown settings
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown' },
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = false
  end,
})
