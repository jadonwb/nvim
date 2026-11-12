-- Semantic highlight layer.
--
-- The UI code talks in a small vocabulary (ExRed, ExGreen, CommentFg, NvChip,
-- …) instead of raw theme groups, so panels can be rich without every feature
-- knowing the colorscheme. The groups are derived from the active theme and
-- rebuilt on ColorScheme.

local M = {}

local function fg(name, fallback)
  local id = vim.fn.hlID(name)
  if id == 0 then
    return fallback
  end
  local colour = vim.fn.synIDattr(vim.fn.synIDtrans(id), 'fg#')
  return colour ~= '' and colour or fallback
end

local function bg(name, fallback)
  local id = vim.fn.hlID(name)
  if id == 0 then
    return fallback
  end
  local colour = vim.fn.synIDattr(vim.fn.synIDtrans(id), 'bg#')
  return colour ~= '' and colour or fallback
end

function M.setup()
  local normal_fg = fg('Normal', '#e3d7c7')
  local normal_bg = bg('Normal', '#1e1e2e')

  local red = fg('DiagnosticError', '#e06c75')
  local green = fg('DiagnosticOk', '#98c379')
  local yellow = fg('DiagnosticWarn', '#e5c07b')
  local blue = fg('DiagnosticInfo', '#61afef')
  local comment = fg('Comment', normal_fg)
  local muted_bg = bg('Visual', bg('PmenuSel', normal_bg))
  local line = fg('LineNr', comment)

  local defs = {
    -- Accents (NvChad's `ex` palette names).
    ExRed = { fg = red },
    ExGreen = { fg = green },
    ExYellow = { fg = yellow },
    ExBlue = { fg = blue },
    ExLightGrey = { fg = normal_fg },
    ExInactive = { fg = comment },
    ExDark = { fg = comment },
    CommentFg = { fg = comment },

    -- Panel chrome.
    NvPanelBorder = { fg = line },
    NvPanelTitle = { fg = normal_fg, bold = true },
    NvPanelLabel = { fg = comment },
    NvPanelSection = { fg = blue, bold = true },

    -- Chips: dark text on a saturated background, like a badge.
    NvChip = { fg = normal_bg, bg = blue, bold = true },
    NvChipOk = { fg = normal_bg, bg = green, bold = true },
    NvChipWarn = { fg = normal_bg, bg = yellow, bold = true },
    NvChipErr = { fg = normal_bg, bg = red, bold = true },
    NvChipInfo = { fg = normal_bg, bg = blue, bold = true },
    NvChipMuted = { fg = comment, bg = muted_bg },

    -- A bar that reads as a surface instead of blending into the text.
    StatusLine = { fg = normal_fg, bg = muted_bg },
    StatusLineNC = { fg = comment, bg = muted_bg },
    WinBar = { fg = comment, bg = muted_bg },
    WinBarNC = { fg = comment, bg = muted_bg },

    -- Snacks surface groups. The theme does not define most of them, which made
    -- pickers and terminals transparent.
    SnacksPicker = { fg = normal_fg, bg = normal_bg },
    SnacksPickerBorder = { fg = line, bg = normal_bg },
    SnacksPickerBoxBorder = { fg = line, bg = normal_bg },
    SnacksPickerTitle = { fg = normal_fg, bg = normal_bg, bold = true },
    SnacksPickerInput = { fg = normal_fg, bg = muted_bg },
    SnacksPickerInputBorder = { fg = line, bg = normal_bg },
    SnacksPickerInputTitle = { fg = normal_fg, bg = normal_bg, bold = true },
    SnacksPickerList = { fg = normal_fg, bg = normal_bg },
    SnacksPickerPreview = { fg = normal_fg, bg = normal_bg },
    SnacksPickerListCursorLine = { fg = normal_fg, bg = muted_bg },
    SnacksPickerPreviewCursorLine = { fg = normal_fg, bg = muted_bg },
    SnacksPickerMatch = { fg = yellow, bold = true },
    SnacksPickerDir = { fg = comment },
    SnacksPickerFile = { fg = normal_fg },
    SnacksPickerIcon = { fg = blue },
    SnacksPickerDesc = { fg = comment },
    SnacksPickerLabel = { fg = blue, bold = true },
    SnacksPickerSearch = { fg = green, bold = true },
    SnacksPickerBuf = { fg = comment },
    SnacksWinBar = { fg = comment, bg = normal_bg },
    SnacksWinBarNC = { fg = comment, bg = normal_bg },
    SnacksTerminal = { fg = normal_fg, bg = normal_bg },
    SnacksNotifier = { fg = normal_fg, bg = normal_bg },
    SnacksNotifierBorder = { fg = line, bg = normal_bg },
    SnacksNotifierTitle = { fg = normal_fg, bg = normal_bg, bold = true },
    SnacksNotifierFooter = { fg = comment, bg = normal_bg },

    -- Statusline blocks.
    NvStMode = { fg = normal_bg, bg = blue, bold = true },
    NvStModeInsert = { fg = normal_bg, bg = green, bold = true },
    NvStModeVisual = { fg = normal_bg, bg = yellow, bold = true },
    NvStModeReplace = { fg = normal_bg, bg = red, bold = true },
    NvStFile = { fg = normal_fg, bg = muted_bg },
    NvStMuted = { fg = comment },
    NvStChip = { fg = normal_bg, bg = green, bold = true },
  }

  for name, spec in pairs(defs) do
    vim.api.nvim_set_hl(0, name, spec)
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
