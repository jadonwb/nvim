-- Highlight glue between the colorscheme and editor chrome.
--
-- The design vocabulary (Nv*, Ex*, NvMode*, NvChip*) lives in the colorscheme
-- (arrowlake `groups/nv.lua`, `groups/volt.lua`), so every surface follows the
-- theme's palette roles. This file only:
--   1. keeps older group names used around the config as links into it, and
--   2. fills plugin groups the active theme leaves undefined, without ever
--      overriding a group the theme does define.

local M = {}

local function defined(name)
  return next(vim.api.nvim_get_hl(0, { name = name, link = false })) ~= nil
end

-- Old names → new vocabulary.
local links = {
  NvPanelBorder = 'NvRule',
  NvPanelTitle = 'NvTitle',
  NvPanelLabel = 'NvLabel',
  NvPanelSection = 'NvIcon',
  NvChip = 'NvChipPurple',
  NvChipInfo = 'NvChipBlue',
  NvChipOk = 'NvChipGreen',
  NvChipWarn = 'NvChipYellow',
  NvChipErr = 'NvChipRed',
  NvStMode = 'NvModeNormal',
  NvStModeInsert = 'NvModeInsert',
  NvStModeVisual = 'NvModeVisual',
  NvStModeReplace = 'NvModeReplace',
  NvStFile = 'NvChipMuted',
  NvStMuted = 'NvMuted',
  NvStChip = 'NvChipGreen',
  ExDark = 'CommentFg',
}

-- Fallbacks for a theme that ships none of the vocabulary (habamax, default).
local function fallbacks()
  local function hl(name, attr)
    local h = vim.api.nvim_get_hl(0, { name = name, link = false })
    return h[attr] and ('#%06x'):format(h[attr]) or nil
  end
  local fg, bg = hl('Normal', 'fg'), hl('Normal', 'bg')
  local muted = hl('Comment', 'fg') or fg
  local sel = hl('Visual', 'bg') or bg
  local accent = hl('Function', 'fg') or fg
  return {
    NvPanel = { fg = fg, bg = bg },
    NvPanelBorder = { fg = bg, bg = bg },
    NvRaised = { link = 'NormalFloat' },
    NvRaisedBorder = { link = 'NormalFloat' },
    NvCursorLine = { bg = sel },
    NvTitle = { fg = fg, bold = true },
    NvIcon = { fg = accent },
    NvLabel = { fg = muted },
    NvMuted = { fg = muted },
    NvDim = { fg = muted },
    NvRule = { fg = muted },
    NvKey = { fg = accent, bg = sel },
    NvMeterTrack = { fg = muted },
    NvChipMuted = { fg = muted, bg = sel },
    NvChipPurple = { fg = bg, bg = accent, bold = true },
    NvPopup = { link = 'NormalFloat' },
    NvPopupBorder = { link = 'FloatBorder' },
    NvTabActive = { fg = accent, bold = true },
    NvTabInactive = { fg = muted },
  }
end

function M.setup()
  if not defined 'NvPanel' then
    for name, spec in pairs(fallbacks()) do
      vim.api.nvim_set_hl(0, name, spec)
    end
  end
  for name, target in pairs(links) do
    if not defined(name) or vim.api.nvim_get_hl(0, { name = name }).link then
      vim.api.nvim_set_hl(0, name, { link = target })
    end
  end
end

function M.setup_autocmds()
  M.setup()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('NV highlights', { clear = true }),
    callback = M.setup,
  })
end

return M
