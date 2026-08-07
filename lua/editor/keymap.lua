K = {}

-- TODO!: expand this table to cover more keymappings, consolidate items of related domains, resolve conflicts (with tmux too)
NVKeymaps = {
  confirm = '<CR>',
  alt_confirm = '<S-CR>',
  open_vsplit = '<C-CR>',
  open_hsplit = '<C-S-CR>',

  close = '<M-w>',
  close_esc = '<Esc>',
  close_q = 'q',

  -- FIXME: move into git-commit?
  -- or move all keymaps into here?
  commit = '<leader>gc',
  amend = '<leader>ga',
  rename_msg = '<leader>gr',
  commit_push = '<M-CR>',

  -- TODO?: move things in here?
  -- hunk_reset = '<>',
  -- file_reset = '<>',

  focus = '<M-z>',

  scroll = { up = '<C-u>', down = '<C-d>' },
  scroll_alt = { up = '<C-b>', down = '<C-f>' },
  scroll_ctx = { up = '<Up>', down = '<Down>' },
  scroll_side = { left = '<Left>', right = '<Right>' },

  worktree_create = '<C-S-t>',
  worktree_pick = '<leader>gw',

  tab_create = '<C-t>',
  tab_close = '<M-C-w>',
  tab_move = { left = '<C-Left>', right = '<C-Right>' },
  tab_swap = { left = '<C-S-Left>', right = '<C-S-Right>' },
  window_move = { up = '<C-k>', down = '<C-j>', left = '<C-h>', right = '<C-l>' },
  window_swap = { up = '<M-S-Left>', down = '<M-S-Right>', left = '<M-S-Up>', right = '<M-S-Down>', swap = '<M-s>' },
  layout_resize = { up = '<M-C-Up>', down = '<M-C-Down>' },
  window_resize = { up = '<M-C-S-Up>', down = '<M-C-S-Down>' },
  layout_equalize = '<A-e>', -- TODO: not a fan of e for recenter/reset
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
