local function modify_hl(name, changes)
  local existing = vim.api.nvim_get_hl(0, { name = name })
  vim.api.nvim_set_hl(0, name, vim.tbl_extend('force', existing, changes))
end

-- transparent background
modify_hl('Normal', { bg = 'none' })
modify_hl('NormalFloat', { bg = 'none' })
modify_hl('FloatBorder', { bg = 'none' })
modify_hl('Pmenu', { bg = 'none' })
modify_hl('Terminal', { bg = 'none' })
modify_hl('EndOfBuffer', { bg = 'none' })
modify_hl('FoldColumn', { bg = 'none' })
modify_hl('Folded', { bg = 'none' })
modify_hl('SignColumn', { bg = 'none' })
modify_hl('NormalNC', { bg = 'none' })
modify_hl('WhichKeyFloat', { bg = 'none' })
modify_hl('TelescopeBorder', { bg = 'none' })
modify_hl('TelescopeNormal', { bg = 'none' })
modify_hl('TelescopePromptBorder', { bg = 'none' })
modify_hl('TelescopePromptTitle', { bg = 'none' })
modify_hl('StatusLine', { bg = 'none' })
modify_hl('TabLine', { bg = 'none' })
modify_hl('TabLineFill', { bg = 'none' })

-- transparent background for neotree
modify_hl('NeoTreeNormal', { bg = 'none' })
modify_hl('NeoTreeNormalNC', { bg = 'none' })
modify_hl('NeoTreeVertSplit', { bg = 'none' })
modify_hl('NeoTreeWinSeparator', { bg = 'none' })
modify_hl('NeoTreeEndOfBuffer', { bg = 'none' })

-- transparent background for nvim-tree
modify_hl('NvimTreeNormal', { bg = 'none' })
modify_hl('NvimTreeVertSplit', { bg = 'none' })
modify_hl('NvimTreeEndOfBuffer', { bg = 'none' })

-- transparent notify background
modify_hl('NotifyINFOBody', { bg = 'none' })
modify_hl('NotifyERRORBody', { bg = 'none' })
modify_hl('NotifyWARNBody', { bg = 'none' })
modify_hl('NotifyTRACEBody', { bg = 'none' })
modify_hl('NotifyDEBUGBody', { bg = 'none' })
modify_hl('NotifyINFOTitle', { bg = 'none' })
modify_hl('NotifyERRORTitle', { bg = 'none' })
modify_hl('NotifyWARNTitle', { bg = 'none' })
modify_hl('NotifyTRACETitle', { bg = 'none' })
modify_hl('NotifyDEBUGTitle', { bg = 'none' })
modify_hl('NotifyINFOBorder', { bg = 'none' })
modify_hl('NotifyERRORBorder', { bg = 'none' })
modify_hl('NotifyWARNBorder', { bg = 'none' })
modify_hl('NotifyTRACEBorder', { bg = 'none' })
modify_hl('NotifyDEBUGBorder', { bg = 'none' })

modify_hl('SnacksNotifierInfo', { bg = 'none' })
modify_hl('SnacksNotifierWarn', { bg = 'none' })
modify_hl('SnacksNotifierDebug', { bg = 'none' })
modify_hl('SnacksNotifierError', { bg = 'none' })
modify_hl('SnacksNotifierTrace', { bg = 'none' })
modify_hl('SnacksNotifierBorderInfo', { bg = 'none' })
modify_hl('SnacksNotifierBorderWarn', { bg = 'none' })
modify_hl('SnacksNotifierBorderDebug', { bg = 'none' })
modify_hl('SnacksNotifierBorderError', { bg = 'none' })
modify_hl('SnacksNotifierBorderTrace', { bg = 'none' })

-- General border highlight groups
modify_hl('FloatBorder', { bg = 'NONE' })
modify_hl('FloatTitle', { bg = 'NONE' })
modify_hl('NormalFloat', { bg = 'NONE' })

-- Which-key specific borders
modify_hl('WhichKeyNormal', { bg = 'NONE' })
modify_hl('WhichKeyBorder', { bg = 'NONE' })
modify_hl('WhichKeyFloat', { bg = 'NONE' })
modify_hl('WhichKeyTitle', { bg = 'NONE' })

-- Blink.cmp specific borders
modify_hl('BlinkCmpDoc', { bg = 'NONE' })
modify_hl('BlinkCmpMenuBorder', { bg = 'NONE' })

-- Snacks
modify_hl('SnacksPickerInputBorder', { bg = 'NONE' })
modify_hl('SnacksPickerInputTitle', { bg = 'NONE' })
modify_hl('SnacksPickerBoxTitle', { bg = 'NONE' })

-- Not Transparency but fun
local function resolve_hl(name)
  local hl = vim.api.nvim_get_hl(0, { name = name })
  if hl.link then
    return resolve_hl(hl.link)
  end
  return hl
end
local fg_color = resolve_hl('@constant').fg
modify_hl('CursorLineNr', { fg = fg_color, bold = true })
-- modify_hl('SnacksPickerInputBorder', { fg = fg_color, link = nil })
vim.api.nvim_set_hl(0, 'SnacksPickerInputBorder', { fg = fg_color })
