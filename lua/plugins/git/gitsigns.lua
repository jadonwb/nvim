NVGitsigns = {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    signs = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '' },
      topdelete = { text = '' },
      changedelete = { text = '▎' },
      untracked = { text = '▎' },
    },
    signs_staged = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '' },
      topdelete = { text = '' },
      changedelete = { text = '▎' },
      untracked = { text = '▎' },
    },
    -- Hunk keys (LazyVim's layout; <leader>gh is file history here, so the
    -- hunk actions are single letters under <leader>g). K on a hunk also
    -- offers it in the hover menu (features/lsp).
    on_attach = function(buf)
      local gs = require 'gitsigns'
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc, silent = true })
      end
      -- In diff mode ]c / [c stay Neovim's; ]h / [h are always hunks.
      map('n', ']h', function()
        gs.nav_hunk('next', { target = 'all' })
      end, 'Next hunk')
      map('n', '[h', function()
        gs.nav_hunk('prev', { target = 'all' })
      end, 'Previous hunk')
      map('n', ']H', function()
        gs.nav_hunk('last', { target = 'all' })
      end, 'Last hunk')
      map('n', '[H', function()
        gs.nav_hunk('first', { target = 'all' })
      end, 'First hunk')
      map('n', '<leader>gp', gs.preview_hunk_inline, 'Preview hunk')
      map({ 'n', 'x' }, '<leader>gs', function()
        if vim.fn.mode():match '[vV]' then
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        else
          gs.stage_hunk()
        end
      end, 'Stage / unstage hunk')
      map({ 'n', 'x' }, '<leader>gr', function()
        if vim.fn.mode():match '[vV]' then
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        else
          gs.reset_hunk()
        end
      end, 'Reset hunk')
      map('n', '<leader>gS', gs.stage_buffer, 'Stage file')
      map('n', '<leader>gb', function()
        gs.blame_line { full = true }
      end, 'Blame line')
      map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Hunk')
      -- Without a language server, K on a hunk still opens the hover menu
      -- (its hunk section); elsewhere it stays Vim's K. A server's own K
      -- (features/lsp) replaces this when it attaches.
      map('n', 'K', function()
        local sections = require 'features.lsp.sections'
        if sections.hunk() or sections.diagnostics() then
          require('features.lsp.ui').show_at_cursor()
        else
          vim.cmd 'normal! K'
        end
      end, 'Hover (hunk / diagnostics)')
    end,
  },
}

return { NVGitsigns }
