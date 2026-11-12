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

    -- Splits need an edge: the theme's separator is the normal background.
    WinSeparator = { fg = line, bg = normal_bg },

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

    -- Mason. The theme leaves most of these undefined, which made its float
    -- transparent with invisible block highlights.
    MasonNormal = { fg = normal_fg, bg = normal_bg },
    MasonNormalNC = { fg = normal_fg, bg = normal_bg },
    MasonBackdrop = { bg = normal_bg },
    MasonHeader = { fg = normal_bg, bg = blue, bold = true },
    MasonHeaderSecondary = { fg = normal_bg, bg = green, bold = true },
    MasonHighlight = { fg = blue },
    MasonHighlightSecondary = { fg = green },
    MasonHighlightBlock = { fg = normal_bg, bg = blue },
    MasonHighlightBlockBold = { fg = normal_bg, bg = blue, bold = true },
    MasonHighlightBlockSecondary = { fg = normal_bg, bg = green },
    MasonHighlightBlockBoldSecondary = { fg = normal_bg, bg = green, bold = true },
    MasonMuted = { fg = comment },
    MasonMutedBlock = { fg = comment, bg = muted_bg },
    MasonMutedBlockBold = { fg = comment, bg = muted_bg, bold = true },
    MasonHeading = { fg = normal_fg, bold = true },
    MasonLink = { fg = blue, underline = true },
    MasonError = { fg = red },
    MasonWarning = { fg = yellow },

    -- blink.cmp. The menu's selection, scrollbar, matched text and kind icons
    -- were unstyled, so the menu read as a flat wall of text.
    BlinkCmpMenuSelection = { bg = muted_bg },
    BlinkCmpScrollBarThumb = { bg = blue },
    BlinkCmpScrollBarGutter = { bg = muted_bg },
    BlinkCmpLabelMatch = { fg = blue, bold = true },
    BlinkCmpLabelDescription = { fg = comment },
    BlinkCmpLabelDetail = { fg = comment },
    BlinkCmpKind = { fg = blue },
    BlinkCmpSource = { fg = comment },
    BlinkCmpDocSeparator = { fg = line },
    BlinkCmpSignatureHelpActiveParameter = { fg = yellow, bold = true },

    -- Diffview (its own tab). The theme leaves the base groups empty, which
    -- renders its panes black and its status lines unstyled.
    DiffviewNormal = { fg = normal_fg, bg = normal_bg },
    DiffviewEndOfBuffer = { fg = line, bg = normal_bg },
    DiffviewNonText = { fg = line, bg = normal_bg },
    DiffviewWinSeparator = { fg = line, bg = normal_bg },
    DiffviewStatusLine = { fg = normal_fg, bg = muted_bg },
    DiffviewStatusLineNC = { fg = comment, bg = muted_bg },
    DiffviewFilePanel = { fg = normal_fg, bg = normal_bg },
    DiffviewFilePanelCounter = { fg = blue, bg = normal_bg, bold = true },
    DiffviewFilePanelFileName = { fg = normal_fg, bg = normal_bg },
    DiffviewFilePanelPath = { fg = comment, bg = normal_bg },
    DiffviewFilePanelRootPath = { fg = comment, bold = true },
    DiffviewDiffAdd = { bg = bg('DiffAdd', muted_bg) },
    DiffviewDiffDelete = { bg = bg('DiffDelete', muted_bg) },
    DiffviewDiffChange = { bg = bg('DiffChange', muted_bg) },
    DiffviewCursorLine = { bg = muted_bg },

    -- Trouble (diagnostic/symbol lists).
    TroubleNormal = { fg = normal_fg, bg = normal_bg },
    TroubleNormalNC = { fg = normal_fg, bg = normal_bg },
    TroubleText = { fg = normal_fg },
    TroubleCount = { fg = blue, bold = true },
    TroubleFile = { fg = normal_fg, bold = true },
    TroubleDirectory = { fg = comment },
    TroubleSource = { fg = comment },
    TroublePos = { fg = comment },
    TroubleCode = { fg = comment },
    TroubleIndent = { fg = line },
    TroubleFoldIcon = { fg = comment },
    TroubleTitle = { fg = normal_fg, bold = true },
    TroubleWinSeparator = { fg = line },
    TroubleIconError = { fg = red },
    TroubleIconWarn = { fg = yellow },
    TroubleIconInfo = { fg = blue },
    TroubleIconHint = { fg = green },

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
