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

## Done: custom tabs

`lua/editor/tabs.lua` went from 154 to 118 lines and keeps only what diffview
and focus mode need:

| Kept | Why |
| --- | --- |
| `register_type`, `get_tab_type`, `is_temporary` | diffview and focus mode mark their tabpages so panels, session restore and `<C-w>` treat them differently |
| `close_all_temporary` | session save closes diffview/focus tabs before persisting a layout |
| `NVTabs.close` | `<C-w>` runs a temporary tab's own teardown hook before closing |

Removed: named tabs (the `<C-t>` input dialog), all labels (`set_label`,
`set_label_if_empty`, `editor_icon`, `render_label`, `tab_label` in session
snapshots, lualine's label rendering), the `<C-S-Left/Right>` reorder mappings,
`get_non_temporary` (no callers) and the "Close Tab? Yes/No" confirmation.

`<C-t>` is a plain `tabnew`, `<C-w>` closes a tab through the registry, and
`<C-Left/Right>` step between tabs.

Verified in the harness: `<C-t>` opens a second tab; `<C-w>` closes it;
`:DiffviewOpen` opens a temporary tab that a single `<C-w>` tears down
completely; `<M-z>` focus mode opens and closes its temporary tab; a restart
snapshot is written with no tab labels and restores without error.

## Next

Stage 3 — launch profiles: one classifier for difftool, mergetool, pager,
transient and embedded launches, driving which plugins, modules, keymaps,
session and dashboard load.
