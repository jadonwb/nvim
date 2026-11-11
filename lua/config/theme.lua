-- omarchy symlinks a theme-generated lazy spec into `lua/plugins/theme.lua`.
-- It used to carry the colorscheme inside an injected `LazyVim/LazyVim` entry;
-- arrowlake now sets `vim.g.arrowlake_colorscheme` and returns only its own
-- plugin. Both forms are accepted here so an older generated file still works.

local M = {
  colorscheme = 'habamax',
  plugin = nil,
}

local path = vim.fn.stdpath 'config' .. '/lua/plugins/theme.lua'
local ok, spec = pcall(dofile, path)

if ok and type(spec) == 'table' then
  for _, item in ipairs(spec) do
    if type(item) == 'table' then
      local name = type(item[1]) == 'string' and item[1] or ''
      if name:match 'arrowlake' then
        M.plugin = item
      end
      -- Legacy form: LazyVim carried the colorscheme in opts.
      if type(item.opts) == 'table' and type(item.opts.colorscheme) == 'string' then
        M.colorscheme = item.opts.colorscheme
      end
    end
  end
end

if type(vim.g.arrowlake_colorscheme) == 'string' and vim.g.arrowlake_colorscheme ~= '' then
  M.colorscheme = vim.g.arrowlake_colorscheme
end

--- Load the theme. Falls back to a built-in colorscheme so a broken or missing
--- theme never leaves the editor without colours.
function M.apply()
  if not pcall(vim.cmd.colorscheme, M.colorscheme) then
    vim.cmd.colorscheme 'habamax'
  end
end

return M
