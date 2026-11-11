# Stage 2 — remove the custom git and tab UI

## Done: custom git UI

Deleted, because lazygit + gitsigns + diffview-plus already cover the same
operations:

| File | Was |
| --- | --- |
| `lua/editor/git.lua` | `NVGit` helper library: worktree CRUD and labels, repo info, diff counters, commit/amend/push wrappers |
| `lua/editor/features/git-commit.lua` | four-window floating commit form, drafts per cwd, `<leader>gc/ga/gr` |
| `lua/editor/features/git-worktrees.lua` | worktree picker, one tab per worktree with `tcd`, `<leader>gw`, `<C-S-t>` |

Kept: `lua/plugins/snacks/snacks-lazygit.lua` (`<M-g>`, `<leader>gl/gs/gt`),
`lua/plugins/git/gitsigns.lua`, `lua/plugins/git/diffview.lua` and the
`diffview-diff`/`diffview-merge` helpers. `git_commit` was dropped from
`NVClose.priority`.

Lost with them: persisted worktree labels, commit-form drafts, the recent-commit
preview, and the one-tab-per-worktree model. lazygit covers worktrees itself;
drafts and labels have no replacement yet.

## Next: custom tabs

`lua/editor/tabs.lua` is still load-bearing, so it goes last and in pieces.
`diffview-plus` registers a temporary tab type, focus mode registers a second,
session restore saves and restores `tab_label`, and the layout manager labels
new tabs. Only the tab keymaps, the named-tab dialog and the label rendering can
be removed outright; the type registry and close dispatch have to survive in
some form.
