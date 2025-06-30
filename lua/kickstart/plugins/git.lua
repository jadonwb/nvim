local git_signs = require('kickstart.icons').git.signs
return {
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = git_signs.add },
        change = { text = git_signs.modified },
        delete = { text = git_signs.delete },
        topdelete = { text = git_signs.delete },
        changedelete = { text = git_signs.modified },
        untracked = { text = git_signs.add },
      },
      signs_staged = {
        add = { text = git_signs.add },
        change = { text = git_signs.modified },
        delete = { text = git_signs.delete },
        topdelete = { text = git_signs.delete },
        changedelete = { text = git_signs.modified },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']h', function()
          if vim.wo.diff then
            vim.cmd.normal { ']h', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [h]hunk' })

        map('n', '[h', function()
          if vim.wo.diff then
            vim.cmd.normal { '[h', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [h]unk' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [r]eset hunk' })
        -- normal mode
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', gitsigns.stage_hunk, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk_inline, { desc = 'git [p]review hunk inline' })
        map('n', '<leader>hP', gitsigns.preview_hunk, { desc = 'git [P]review hunk' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [D]iff against last commit' })
        -- Toggles
        map('n', '<leader>ub', gitsigns.toggle_current_line_blame, { desc = 'Toggle git [b]lame line' })
        map('n', '<leader>uD', gitsigns.preview_hunk_inline, { desc = 'Git show [D]eleted' })
      end,
    },
  },
}
