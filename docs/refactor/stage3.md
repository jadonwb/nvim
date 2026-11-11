# Stage 3 — launch profiles

## Classification

`lua/config/profile.lua` turns `NVEnv.startup` into one profile kind:

| Kind | Source |
| --- | --- |
| `workspace` | normal launch |
| `difftool` | `+DiffviewDiffFiles`, `+DiffviewOpen`, `+DiffviewFileHistory`, `-d`/`--diff`/`vimdiff`, `NVIM_LAUNCH_MODE=difftool` |
| `mergetool` | `+DiffviewMergeFiles`, `NVIM_LAUNCH_MODE=mergetool` |
| `pager` | `+Man`, launched by `man` |
| `transient` | `NVIM_LAUNCH_MODE=transient` (desktop opener, `nvim-editor`) |
| `embedded` | launched from opencode, yazi, chezmoi, sudoedit |

Anything other than `workspace` gets nothing but the diffview/view/close
machinery. `M.wants(feature)` is the single question a plugin spec asks; the
per-kind allowlist is empty today, and `syntax` (treesitter) is deliberately not
gated so a diff view stays readable.

## What is gated

`cond = function() return require('config.profile').wants '<feature>' end`

| Spec | Feature |
| --- | --- |
| `neovim/nvim-lspconfig`, `mason.nvim`, `trouble.nvim` | `lsp` |
| `mfussenegger/nvim-lint` | `lint` |
| `stevearc/conform.nvim` | `format` |
| `saghen/blink.cmp` | `completion` |
| `kevinhwang91/nvim-ufo` | `folds` |
| `render-markdown.nvim` | `markdown` |
| `cppman.nvim` | `languages` |
| `fff.nvim`, `yazi.nvim`, `grug-far.nvim` | `picker` |

## Measurements

| Launch | Before | After |
| --- | --- | --- |
| difftool (`+DiffviewDiffFiles a b`) | 109 ms | 50–55 ms |
| workspace | ~90–108 ms | ~101–108 ms |

Workspace is unchanged within noise; the difftool launch halves because it no
longer resolves or loads LSP, completion, folds, markdown rendering, language
tooling and pickers. The remaining cost is lazy.nvim spec resolution (~34 ms)
plus diffview itself (~4 ms).

## Checks

`tests/launch.sh` asserts nine invocations: purpose, mode, close policy for
plain, difftool, mergetool, transient and an invalid launch mode; `+Diffview*`
commands; `-d`; and that a difftool launch resolves neither `nvim-ufo` nor
`blink.cmp`. Nine pass.

Also verified by hand: a `+DiffviewDiffFiles` launch opens the view
(`get_current_view()` non-nil, two tabpages), and a workspace launch still has
44 specs and an attached LSP client.

## Helper matrix

`~/.local/share/chezmoi/tests/diffview-diff/matrix.sh` (in the dotfiles repo,
not deployed) drives the real `diffview-diff` helper with a fake `nvim` on
PATH that records argv and the `DIFFVIEW_*` environment, so each case can
assert which path was taken:

| Case | Expected |
| --- | --- |
| unstaged change | in-worktree fast path |
| staged-only, clean worktree | in-worktree fast path at HEAD |
| path with spaces, quotes, non-ASCII | in-worktree fast path |
| historical commit | copied files |
| added file | copied files |
| deleted file | copied files |
| rename | copied files |
| existing `$NVIM` accepts the RPC | `--remote-expr` with `open_worktree` |
| existing `$NVIM` unreachable | copied files in a dedicated process |

Nine cases pass. The matrix also caught its own setup bug first: `git commit -a`
had swept the modified files into the fixture commit, so two cases silently had
nothing to diff and "passed" by never invoking the tool — the assertions now
prove the helper ran.

Stage 3 is complete.
