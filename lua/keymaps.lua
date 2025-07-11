vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local map = vim.keymap.set

-- Delete some default LSP keymaps
vim.keymap.del('n', 'gra')
vim.keymap.del('n', 'gri')
vim.keymap.del('n', 'grn')
vim.keymap.del('n', 'grr')
vim.keymap.del('n', 'gO')

map('n', 'gq', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })

-- Remap for dealing with word wrap
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Clear highlights
map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Disable arrow keys in normal mode
map('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
map('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
map('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
map('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  See `:help wincmd` for a list of all window commands
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- New line without insert mode
map('n', '<M-o>', 'o<Esc>', { desc = 'New Line Down' })
map('n', '<M-O>', 'O<Esc>', { desc = 'New Line Up' })

-- Swap r and ctrl+r
map('n', '<C-r>', 'r', { silent = true }) -- replace a single character
map('n', 'r', '<C-r>', { silent = true }) -- redo

-- Better J
map('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })

-- keep cursor centered while jumping around
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')
map('n', 'n', 'nzzzv')
map('n', 'N', 'Nzzzv')

-- Stay in visual when indenting
map('v', '<', '<gv')
map('v', '>', '>gv')

-- Yank file
map('n', '<leader>y', ':%y<CR>', { desc = 'Yank file' })

-- Lazy
map('n', '<leader>l', '<cmd>Lazy<CR>', { desc = 'Lazy' })

-- Shortcuts for save and exit
map('n', '<leader>w', function()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == '' then
    -- Buffer has no name, prompt for one
    vim.ui.input({
      prompt = 'Enter file name: ',
    }, function(name)
      if name and name ~= '' then
        vim.cmd('write ' .. vim.fn.fnameescape(name))
      end
    end)
    return
  end
  -- Buffer has a name, save normally
  vim.cmd.write()
end, { desc = 'Write Buffer' })
map('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit Window' })

-- Resize window using <ctrl> arrow keys with smart behavior
map('n', '<C-Up>', function()
  local win_id = vim.fn.winnr()
  local above_win = vim.fn.winnr 'k'

  if above_win == win_id then
    vim.cmd 'resize -2'
  else
    vim.cmd 'resize +2'
  end
end, { desc = 'Increase Window Height' })

map('n', '<C-Down>', function()
  local win_id = vim.fn.winnr()
  local above_win = vim.fn.winnr 'k'

  if above_win == win_id then
    vim.cmd 'resize +2'
  else
    vim.cmd 'resize -2'
  end
end, { desc = 'Decrease Window Height' })

map('n', '<C-Right>', function()
  local win_id = vim.fn.winnr()
  local left_win = vim.fn.winnr 'h'

  if left_win == win_id then
    vim.cmd 'vertical resize +2'
  else
    vim.cmd 'vertical resize -2'
  end
end, { desc = 'Increase Window Width' })

map('n', '<C-Left>', function()
  local win_id = vim.fn.winnr()
  local left_win = vim.fn.winnr 'h'

  if left_win == win_id then
    vim.cmd 'vertical resize -2'
  else
    vim.cmd 'vertical resize +2'
  end
end, { desc = 'Decrease Window Width' })

-- Buffer switching with Alt + h/l
map('n', '<A-h>', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
map('n', '<A-l>', '<cmd>bnext<cr>', { desc = 'Next buffer' })

-- Sessions
map('n', '<leader>S', '<cmd>:lua require("persistence").select()<CR>', { desc = 'Select Session' })
map('n', '<leader>p', '<cmd>:lua require("persistence").load({last = true})<CR>', { desc = 'Previous Session' })
