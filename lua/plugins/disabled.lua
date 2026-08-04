return {
  { 'catppuccin', enabled = false },
  { 'folke/tokyonight.nvim', enabled = false },
  { 'akinsho/bufferline.nvim', enabled = false },
  { 'nvim-mini/mini.pairs', enabled = false },
  -- ── flash.nvim — disable all default jump/skip keys ──────────────────
  {
    'folke/flash.nvim',
    -- stylua: ignore
    keys = {
      { 's',  mode = { 'n', 'x', 'o' }, false },
      { 'S',  mode = { 'n', 'o', 'x' }, false },
      { 'r',  mode = 'o',               false },
      { 'R',  mode = { 'o', 'x' },      false },
      { '<c-s>', mode = { 'c' },        false },
    },
  },
  -- ── snacks.nvim — disable default picker/file/terminal keymaps ──────
  {
    'folke/snacks.nvim',
    keys = {
      -- Git pickers
      { '<leader>gi', false },
      { '<leader>gI', false },
      { '<leader>gp', false },
      { '<leader>gP', false },
      { '<leader>gd', false },
      { '<leader>gD', false },
      { '<leader>gs', false },
      { '<leader>gS', false },
      -- Search
      { '<leader>/', false },
      { '<leader>sb', false },
      { '<leader>sB', false },
      { '<leader>sg', false },
      { '<leader>sG', false },
      { '<leader>sw', false },
      { '<leader>sW', false },
      -- File operations
      { '<leader>fe', false },
      { '<leader>fE', false },
      { '<leader>fc', false },
      { '<leader>ff', false },
      { '<leader>fb', false },
      { '<leader>fd', false },
      { '<leader>fB', false },
      { '<leader>fg', false },
      { '<leader>fr', false },
      { '<leader>fR', false },
      { '<leader>fF', false },
      { '<leader>fp', false },
      -- Misc
      { '<leader>S', false },
      { '<leader>.', false },
      { '<leader>:', false },
      { '<leader>,', false },
      { '<leader>n', false },
      -- Buffer
      { '<leader>bd', false },
    },
  },
  -- ── grug-far.nvim — disable default search-replace keymap ───────────
  {
    'MagicDuck/grug-far.nvim',
    keys = {
      { '<leader>sr', false },
    },
  },

  {
    'LazyVim/LazyVim',
    opts = {
      news = {
        lazyvim = false,
        neovim = false,
      },
    },
  },
  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { '<leader>K', hidden = true },
        { '<leader><tab>', group = 'tabs', hidden = true },
        { '<leader>gh', hidden = true },
        { '<Leader>dp' },
      })
    end,
  },
}
