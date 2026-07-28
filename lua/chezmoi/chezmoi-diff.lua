-- ============================================================================
-- chezmoi-diff.lua — Plugin Spec: Chezmoi Merge Review
-- ============================================================================
-- Extends chezmoi.nvim with an in-editor diff review workflow.
--
-- Provides:
--   :ChezmoiMerge          Open the chezmoi merge review tab
--   :ChezmoiMergeClose     Close the chezmoi merge review tab
--   <leader>gC             Open chezmoi merge review (keymap)
--
-- This spec merges with the existing chezmoi.nvim spec from the LazyVim extra.
-- The :ChezmoiMerge command lazy-loads chezmoi.nvim if it isn't already loaded.
--
-- ── How to enable/disable ──────────────────────────────────────────────
-- The plugin is active by default. To disable:
--   1. Add `enabled = false` below
--   2. Or remove/rename this file
--
-- To change the keymap, edit the `keys` table below.
-- To add your own keymaps, use vim.keymap.set in your keymaps.lua:
--   vim.keymap.set("n", "<leader>gm", "<cmd>ChezmoiMerge<cr>",
--     { desc = "Chezmoi merge review" })
-- ============================================================================

return {
  -- Extend chezmoi.nvim (already loaded by LazyVim's chezmoi extra)
  "xvzc/chezmoi.nvim",

  -- ── Lazy-loading triggers ──────────────────────────────────────────────
  -- These commands will lazy-load chezmoi.nvim (and this config) on first use
  cmd = {
    "ChezmoiMerge",
    "ChezmoiMergeClose",
  },

  -- ── Keymaps ────────────────────────────────────────────────────────────
  -- <leader>gC: "git Chezmoi" — lives near your existing git keymaps
  -- (<leader>gv = DiffviewOpen, <leader>gf = File History, etc.)
  keys = {
    {
      "<leader>gC",
      "<cmd>ChezmoiMerge<cr>",
      desc = "Chezmoi Merge (review changes)",
    },
  },

  -- ── Config ─────────────────────────────────────────────────────────────
  -- Runs when chezmoi.nvim loads (from any trigger: LazyVim event, our cmd,
  -- or our keymap). Registers the user commands.
  config = function()
    -- :ChezmoiMerge — open the chezmoi diff review tab
    vim.api.nvim_create_user_command("ChezmoiMerge", function()
      require("chezmoi.merge").open()
    end, {
      desc = "Open chezmoi merge review tab — review changes before applying",
    })

    -- :ChezmoiMergeClose — programmatic close (useful in scripts/autocmds)
    vim.api.nvim_create_user_command("ChezmoiMergeClose", function()
      require("chezmoi.merge").close()
    end, {
      desc = "Close the chezmoi merge review tab",
    })

    -- ── Optional: Auto-close on apply ────────────────────────────────────
    -- Uncomment the block below if you want the merge tab to automatically
    -- close after a chezmoi apply is triggered from the merge tab.
    -- This is currently handled by the merge module's apply keymaps (which
    -- close when all files are applied).
    --
    -- vim.api.nvim_create_autocmd("User", {
    --   pattern = "ChezmoiApplyPost",
    --   callback = function()
    --     pcall(function()
    --       require("chezmoi.merge").close()
    --     end)
    --   end,
    --   desc = "Auto-close chezmoi merge tab after apply",
    -- })

    -- ── Optional: Syntax highlighting for the merge panel ────────────────
    -- Define basic syntax groups for the file panel status column.
    -- These can be customized with your colorscheme.
    vim.cmd([[
      syntax clear chezmoimergepanel

      " Status column highlights (first two characters of each line)
      " Added files (source only)
      syntax match chezmoimergepanelAdded    "^A. "  nextgroup=chezmoimergepanelPath skipwhite
      " Modified files
      syntax match chezmoimergepanelModified "^M.\|^.M " nextgroup=chezmoimergepanelPath skipwhite
      " Deleted files
      syntax match chezmoimergepanelDeleted  "^D.\|^.D " nextgroup=chezmoimergepanelPath skipwhite
      " Run scripts
      syntax match chezmoimergepanelScript   "^R.\|^.R " nextgroup=chezmoimergepanelPath skipwhite
      " File paths
      syntax match chezmoimergepanelPath     ".*$" contained

      highlight default chezmoimergepanelAdded    guifg=#a6e3a1 ctermfg=green
      highlight default chezmoimergepanelModified guifg=#f9e2af ctermfg=yellow
      highlight default chezmoimergepanelDeleted  guifg=#f38ba8 ctermfg=red
      highlight default chezmoimergepanelScript   guifg=#89dceb ctermfg=cyan
      highlight default chezmoimergepanelPath     guifg=#cdd6f4 ctermfg=white
    ]])
  end,
}
