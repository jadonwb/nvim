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
      -- "No hunks" goes through our notifications (a toast, dismissed with
      -- Esc) instead of gitsigns' own message.
      local function has_hunks()
        local staged = gs.get_hunks and #(gs.get_hunks(buf) or {}) or 0
        if staged > 0 then
          return true
        end
        local cache = require('gitsigns.cache').cache[buf]
        return cache ~= nil and cache.hunks_staged ~= nil and #cache.hunks_staged > 0
      end
      local function nav(dir)
        return function()
          if not pcall(has_hunks) or not has_hunks() then
            return NVMessages.info 'No hunks in this file'
          end
          gs.nav_hunk(dir, { target = 'all' })
        end
      end
      -- In diff mode ]c / [c stay Neovim's; ]h / [h are always hunks.
      map('n', ']h', nav 'next', 'Next hunk')
      map('n', '[h', nav 'prev', 'Previous hunk')
      map('n', ']H', nav 'last', 'Last hunk')
      map('n', '[H', nav 'first', 'First hunk')
      map('n', '<leader>gp', function()
        if not require('features.lsp.sections').hunk() then
          return NVMessages.info 'No hunk on this line'
        end
        gs.preview_hunk_inline()
      end, 'Preview hunk')
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
