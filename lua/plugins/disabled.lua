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
  -- ── persistence.nvim — disable session keymaps ──────────────────────
  {
    'folke/persistence.nvim',
    keys = {
      { '<leader>ql', false },
      { '<leader>qS', false },
      { '<leader>qd', false },
    },
  },

  -- ── grug-far.nvim — disable default search-replace keymap ───────────
  {
    'MagicDuck/grug-far.nvim',
    keys = {
      { '<leader>sr', false },
    },
  },

  -- NOTE: LSP goto keymaps (gd, gr, gI, gy, gD) are disabled in
  -- lua/plugins/lsp/nvim-lspconfig.lua via opts.servers['*'].keys
  -- because LSP keymaps are set per-buffer on LspAttach, not through
  -- lazy.nvim's plugin-level keys system. See the nvim-lspconfig spec.

  {
    'LazyVim/LazyVim',
    opts = {
      news = {
        lazyvim = false,
        neovim = false,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        once = true,
        callback = function()
          vim.schedule(function()
            local function safe_del(mode, lhs)
              pcall(vim.keymap.del, mode, lhs)
            end

            -- ── Git ──────────────────────────────────────────────
            safe_del('n', '<leader>gf') -- Git File History
            safe_del('n', '<leader>gb') -- Git Blame Line
            safe_del('n', '<leader>gG') -- Lazygit (cwd)
            safe_del({ 'n', 'x' }, '<leader>gY') -- Git Browse (copy)
            safe_del({ 'n', 'x' }, '<leader>gB') -- Git Browse (open)

            -- ── Which-key / Changelog / New File ────────────────
            safe_del('n', '<leader>?') -- Buffer Keymaps (which-key)
            safe_del('n', '<leader>L') -- LazyVim Changelog
            safe_del('n', '<leader>fn') -- New File

            -- ── Profiler ────────────────────────────────────────
            safe_del('n', '<leader>dpp') -- Profiler toggle
            safe_del('n', '<leader>dph') -- Profiler highlights toggle
            safe_del('n', '<leader>dps') -- Profiler scratch buffer

            -- ── Window / Buffer ─────────────────────────────────
            safe_del('n', '<leader>-') -- Split Below
            safe_del('n', '<leader>|') -- Split Right
            safe_del('n', '<leader>`') -- Switch to Other Buffer
            safe_del('n', '<leader>wd') -- Delete Window (remapped to <c-w>d)
            safe_del('n', '<leader>wm') -- Toggle Zoom

            -- ── Move lines (conflict with tmux) ──
            safe_del('n', '<A-j>') -- Move line down (n mode)
            safe_del('n', '<A-k>') -- Move line up (n mode)

            -- ── Buffer navigation ───────────────────────────────
            safe_del('n', '<S-h>') -- Prev Buffer
            safe_del('n', '<S-l>') -- Next Buffer

            -- ── Terminal ────────────────────────────────────────
            safe_del('n', '<leader>ft') -- Terminal (Root Dir)
            safe_del('n', '<leader>fT') -- Terminal (cwd)

            -- ── LSP ─────────────────────────────────────────────
            safe_del('n', 'gra') -- Code Action (now <leader>ca)
            safe_del('n', 'grn') -- Rename (now <leader>cr)

            -- ── zen and Zoom ─────────────────────────────────────
            safe_del('n', '<leader>uz') -- zen mode
            safe_del('n', '<leader>uZ') -- zoom
          end) -- vim.schedule
        end,
      })
    end,
  },
  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { '<leader>K', hidden = true },
        { '<leader>gh' },
        { '<Leader>dp' },
      })
    end,
  },
}
