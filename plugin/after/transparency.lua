local state_file = vim.fn.stdpath 'state' .. '/transparency'
local transparent_enabled

local function load_transparency_state()
  local ok, lines = pcall(vim.fn.readfile, state_file)
  if ok and lines[1] ~= nil then
    return lines[1] == 'true'
  end

  return true
end

local function save_transparency_state()
  pcall(vim.fn.mkdir, vim.fn.stdpath 'state', 'p')
  pcall(vim.fn.writefile, { transparent_enabled and 'true' or 'false' }, state_file)
end

transparent_enabled = load_transparency_state()

local groups = {
  'Normal',
  'NormalFloat',
  'FloatBorder',
  'Pmenu',
  'Terminal',
  'EndOfBuffer',
  'FoldColumn',
  'Folded',
  'SignColumn',
  'LineNr',
  'CursorLineNr',
  'NormalNC',
  'WhichKeyFloat',
  'TelescopeBorder',
  'TelescopeNormal',
  'TelescopePromptBorder',
  'TelescopePromptTitle',
  'NeoTreeNormal',
  'NeoTreeNormalNC',
  'NeoTreeVertSplit',
  'NeoTreeWinSeparator',
  'NeoTreeEndOfBuffer',
  'NvimTreeNormal',
  'NvimTreeVertSplit',
  'NvimTreeEndOfBuffer',
  'NotifyINFOBody',
  'NotifyERRORBody',
  'NotifyWARNBody',
  'NotifyTRACEBody',
  'NotifyDEBUGBody',
  'NotifyINFOTitle',
  'NotifyERRORTitle',
  'NotifyWARNTitle',
  'NotifyTRACETitle',
  'NotifyDEBUGTitle',
  'NotifyINFOBorder',
  'NotifyERRORBorder',
  'NotifyWARNBorder',
  'NotifyTRACEBorder',
  'NotifyDEBUGBorder',
  'StatusLine',
  'TabLine',
  'TabLineFill',
  'SnacksNotifierInfo',
  'SnacksNotifierWarn',
  'SnacksNotifierDebug',
  'SnacksNotifierError',
  'SnacksNotifierTrace',
  'SnacksNotifierBorderInfo',
  'SnacksNotifierBorderWarn',
  'SnacksNotifierBorderDebug',
  'SnacksNotifierBorderError',
  'SnacksNotifierBorderTrace',
  'FloatTitle',
  'WhichKeyNormal',
  'WhichKeyBorder',
  'WhichKeyTitle',
  'BlinkCmpDoc',
  'BlinkCmpMenuBorder',
  'BlinkCmpMenu',
  'BlinkCmpDocBorder',
  'BlinkCmpSignatureHelp',
  'BlinkCmpSignatureHelpBorder',
  'SnacksPickerBorder',
  'SnacksPickerInputBorder',
  'SnacksPickerInputTitle',
  'SnacksPickerBoxTitle',
  'SnacksBackdrop',
  'SnacksNormal',
  'NoiceCmdline',
  'NoiceConfirm',
  'NoiceCmdlinePopup',
  'NoiceCmdlinePopupBorder',
  'NoiceCmdlinePopupBorderSearch',
  'TroubleNormal',
}

local augroup = vim.api.nvim_create_augroup('TransparencyHighlights', { clear = true })

local function get_highlight(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or vim.tbl_isempty(hl) then
    return nil
  end

  return vim.tbl_extend('force', {}, hl)
end

local function apply_transparency()
  for _, name in ipairs(groups) do
    local hl = get_highlight(name)

    if hl then
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end

  transparent_enabled = true
end

local function restore_colorscheme()
  local colors_name = vim.g.colors_name

  transparent_enabled = false

  if colors_name and colors_name ~= '' then
    vim.cmd.colorscheme(colors_name)
  end
end

local function set_transparent(enable)
  if enable then
    apply_transparency()
  else
    restore_colorscheme()
  end

  save_transparency_state()
end

local function refresh_transparency()
  if transparent_enabled then
    apply_transparency()
  end
end

local function toggle_transparency()
  local enable = not transparent_enabled

  set_transparent(enable)

  if enable then
    vim.notify('Enabled **Transparency**', vim.log.levels.INFO, { title = 'Transparency' })
  else
    vim.notify('Disabled **Transparency**', vim.log.levels.WARN, { title = 'Transparency' })
  end
end

vim.api.nvim_create_autocmd('ColorScheme', {
  group = augroup,
  callback = refresh_transparency,
})

vim.api.nvim_create_autocmd('User', {
  group = augroup,
  pattern = { 'LazyDone', 'VeryLazy' },
  callback = refresh_transparency,
})

vim.api.nvim_create_autocmd('VimEnter', {
  group = augroup,
  once = true,
  callback = refresh_transparency,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = augroup,
  callback = save_transparency_state,
})

vim.api.nvim_create_user_command('TransparencyToggle', toggle_transparency, {})

vim.keymap.set('n', '<leader>uH', toggle_transparency, {
  desc = 'Toggle transparency',
})
