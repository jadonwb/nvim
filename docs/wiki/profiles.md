# Launch profiles

`config/profile.lua` classifies the session from the real invocation
(`NVEnv.startup`), and plugin specs ask whether their feature is wanted. The
classification is read on every use, not cached: a restart restores the original
invocation after startup, and the restored launch decides panels and plugins
from then on.

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
difftool, pager, transient or embedded launch does not get panels, though the
last two get the empty inset column (`docs/wiki/layout.md`).

```lua
require('config.profile').wants 'lsp'   -- true only in a workspace
require('config.profile').kind()        -- 'workspace' | 'difftool' | …
```
