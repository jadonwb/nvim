K = {}

NVKeymaps = {
  open_vsplit = '<C-v>',
  open_hsplit = '<C-s>',

  close = '<M-w>',
  close_esc = '<Esc>',
  close_q = 'q',

  focus = '<M-z>',

  scroll = { up = '<C-u>', down = '<C-d>' },
  scroll_alt = { up = '<C-b>', down = '<C-f>' },
  scroll_ctx = { up = '<A-k>', down = '<A-j>' },
  scroll_side = { left = '<A-h>', right = '<A-l>' },

  tab_create = '<C-t>',
  tab_close = '<C-w>',
  tab_move = { left = '<C-Left>', right = '<C-Right>' },
  tab_swap = { left = '<C-S-Left>', right = '<C-S-Right>' },
  window_move = { up = '<C-k>', down = '<C-j>', left = '<C-h>', right = '<C-l>' },
  window_swap = { up = '<M-S-Left>', down = '<M-S-Right>', left = '<M-S-Up>', right = '<M-S-Down>', swap = '<M-Tab>' },
  layout_resize = { up = '<S-Left>', down = '<S-Right>' },
  window_resize = { up = '<S-Up>', down = '<S-Down>' },
  layout_equalize = '<A-=>', -- TODO?: try something else

  quit_save = '<A-q>',
  quit_force = '<A-Q>',
  restart = '<A-r>',
}

local default_keymap_options = { noremap = true, silent = true }

---@class Keymap
---@field [1] string Keymap
---@field [2] string Description
---@field [3] string | function Action
---@field mode Mode | Mode[] Mode

---@alias Mode "n"|"v"|"i"|"c"|"s"|"o"|"t"|"x"

---@param mapping Keymap
function K.map(mapping)
  -- NB!: it is important to remove items in reverse order to avoid shifting
  local cmd = table.remove(mapping, 3)
  local desc = table.remove(mapping, 2)
  local key = table.remove(mapping, 1)

  local mode = mapping['mode']

  mapping['mode'] = nil
  mapping['desc'] = desc

  local options = vim.tbl_extend('force', default_keymap_options, mapping)

  vim.keymap.set(mode, key, cmd, options)
end
