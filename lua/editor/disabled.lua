NVDisabled = {}

function NVDisabled.disable_keymaps()
  local function del(mode, lhs)
    pcall(vim.keymap.del, mode, lhs)
  end

  -- Snacks+Git
  del('n', '<leader>gh') -- Git Hunk stuff
  del('n', '<leader>gl') -- Git Log
  del('n', '<leader>gL') -- Git Log
  del('n', '<leader>gf') -- Git File History
  del('n', '<leader>gb') -- Git Blame Line
  del('n', '<leader>gG') -- Lazygit (cwd)
  del({ 'n', 'x' }, '<leader>gY') -- Git Browse (copy)
  del({ 'n', 'x' }, '<leader>gB') -- Git Browse (open)

  -- Which-key / Changelog / New File
  del('n', '<leader>L') -- LazyVim Changelog
  del('n', '<leader>fn') -- New File

  -- Profiler
  del('n', '<leader>dpp') -- Profiler toggle
  del('n', '<leader>dph') -- Profiler highlights toggle
  del('n', '<leader>dps') -- Profiler scratch buffer

  -- Window / Buffer
  del('n', '<leader>-') -- Split Below
  del('n', '<leader>|') -- Split Right
  del('n', '<leader>`') -- Switch to Other Buffer
  del('n', '<leader>wd') -- Delete Window
  del('n', '<leader>wm') -- Toggle Zoom

  -- Move lines
  -- TODO!: maybe keep after redoing my scroll?
  del({ 'n', 'i', 'v' }, '<A-j>') -- Move line down
  del({ 'n', 'i', 'v' }, '<A-k>') -- Move line up

  -- Buffer navigation
  del('n', '<S-h>') -- Prev Buffer
  del('n', '<S-l>') -- Next Buffer

  -- Terminal
  del({ 'n', 't' }, '<C-/>') -- Toggle terminal (now <M-/> and <M-C-t>)
  del({ 'n', 't' }, '<C-_>') -- Toggle terminal (alternate key)
  del('n', '<leader>ft') -- Terminal (Root Dir)
  del('n', '<leader>fT') -- Terminal (cwd)

  -- Window resize
  del('n', '<C-Left>')
  del('n', '<C-Right>')
  del('n', '<C-Up>')
  del('n', '<C-Down>')

  -- LSP
  del('n', 'gra') -- Code Action (now <leader>ca)
  del('n', 'grn') -- Rename (now <leader>cr)
  del('n', 'grx') -- Code lens (now <leader>cc)

  -- Zen / Zoom
  del('n', '<leader>uz') -- zen mode
  del('n', '<leader>uZ') -- zoom
end
