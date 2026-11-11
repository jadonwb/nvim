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

## Left in this stage

- The `diffview-diff` shell helper's own case matrix: unstaged, staged-only,
  historical, added, deleted, renamed, spaces/quotes/unicode paths, and an
  unreachable `$NVIM` socket.
