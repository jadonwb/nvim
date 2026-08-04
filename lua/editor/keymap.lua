K = {}

NVKeymaps = {
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

  focus = '<M-f>',

  inc_width = '<M-C-Up>',
  dec_width = '<M-C-Down>',

  scroll = { up = '<C-u>', down = '<C-d>' },
  scroll_alt = { up = '<C-b>', down = '<C-f>' },
  scroll_ctx = { up = '<A-k>', down = '<A-j>' },
  scroll_side = { left = '<S-Left>', right = '<S-Right>' },

  open_vsplit = '<C-CR>',
  open_hsplit = '<C-S-CR>',
  open_tab = '<M-S-CR>', -- FIXME!: need to work on / find consistency between when to use ctrl vs alt and buffer vs tab,
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
