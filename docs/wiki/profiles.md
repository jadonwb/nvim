# Launch profiles

`core/environment.lua` records the invocation as `NVEnv.startup`.
`config/profile.lua` maps those facts to feature gates. `Alt+r` reads the
original launch facts from its snapshot before lazy.nvim resolves plugin
conditions. The editor restores the buffers and layout when the UI attaches.

| Profile | Trigger | What loads |
| --- | --- | --- |
| `workspace` | normal `nvim` | everything |
| `difftool` | git difftool or `nvim -d` | shared UI and diffview |
| `mergetool` | git mergetool | shared UI and diffview |
| `pager` | `nvim -`, `:Man` at startup, or `NVIM_LAUNCH_MODE=pager` | shared UI; close returns to caller |
| `transient` | `NVIM_LAUNCH_MODE=transient` | shared UI, formatting, Markdown, inset gutter |
| `embedded` | external `--embed` client or a recognized host such as yazi | shared UI, formatting, Markdown, inset gutter |

`ui` is allowed in every profile: the notification centre and the LSP popup must
still report errors inside a difftool.

Workspace layout opens on the first real file; an empty workspace starts
with the dashboard. Non-workspace profiles omit the agent bridge and extras
dashboard. Installed Treesitter parsers remain available for reading;
automatic parser installs run in workspaces.

```lua
require('config.profile').wants 'lsp'   -- true only in a workspace
require('config.profile').kind()        -- 'workspace' | 'difftool' | …
```
