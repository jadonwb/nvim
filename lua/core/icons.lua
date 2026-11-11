NVIcons = {}

-- TODO!: expand to cover more icons that I want to set in certain places

NVIcons.lsp = {
  mini = {
    error = '󰫲',
    warn = '󰬄',
    hint = '󰫵',
    info = '󰫶',
    debug = '󰫱',
  },
  full = {
    error = '󰬌 ',
    warn = '󰬞 ',
    hint = '󰬏 ',
    info = '󰬐 ',
    debug = '󰬋 ',
  },
}

-- Git status icons used by snacks pickers (lua/plugins/snacks/snacks-picker.lua).
-- Glyphs follow snacks.nvim defaults; tweak to taste.
-- `enabled` is a snacks config flag: set false to disable git icons entirely.
NVIcons.git = {
  enabled = true,
  commit = '󰜘 ', -- git log picker
  staged = ' ', -- overrides the type icon when a change is staged
  added = ' ',
  deleted = ' ',
  ignored = ' ',
  modified = ' ',
  renamed = ' ',
  unmerged = ' ',
  untracked = ' ',
}
