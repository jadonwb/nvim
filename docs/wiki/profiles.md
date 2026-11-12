# Launch profiles

`config/profile.lua` classifies the session once, from the real invocation
(`NVEnv.startup`), and plugin specs ask whether their feature is wanted.

| Profile | Trigger | What loads |
| --- | --- | --- |
| `workspace` | normal `nvim` | everything |
| `difftool` | git difftool | colours, close chain, diffview, UI |
| `mergetool` | git mergetool | same as difftool |
| `pager` | `nvim -` / git pager | colours, keymaps, UI, help |
| `transient` | editor launched from another program | minimal, close returns to caller |
| `embedded` | `--embed` | minimal, no dashboard/layout |

`ui` is allowed in every profile: the notification centre and the LSP popup must
still report errors inside a difftool.

The layout opens at `VimEnter` for profiles that want it (`workspace`); a
difftool or pager does not get panels.

```lua
require('config.profile').wants 'lsp'   -- true only in a workspace
require('config.profile').kind          -- 'workspace' | 'difftool' | …
```
