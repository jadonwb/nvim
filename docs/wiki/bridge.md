# Agent bridge

Three directions between Neovim and OpenCode. The transport is OpenCode's own
CLI (`run --format json`) in one direction and Neovim's RPC socket in the other;
everything else is a thin layer on top.

## 1. Prompt out (Neovim → OpenCode)

The bottom panel's `prompt` provider (or `:NVAgent <text>`) submits a draft.

```lua
NVBridge.submit('refactor this function', { session = 'ses_…' })
```

- New sessions use `--archived` so scripted runs stay out of the session list.
- Continuing passes `--session <id>`.
- `:NVAgent new` forgets the session, `:NVAgent stop` cancels the run.
- The job runs on a pty: `opencode run` blocks without a terminal.

You can drive an existing TUI session by passing its id, which is the same as
typing the message into the TUI prompt for that session.

## 2. Content back (OpenCode → Neovim)

`opencode run --format json` emits NDJSON; `NVBridge.on_event` appends to a real
markdown buffer (`opencode://…`, `modifiable=false`):

- `text` parts append (delta-guarded by part id),
- `tool_use` becomes one highlighted line; OpenCode's `execute` wrapper is
  resolved to the inner tool (`vim_control status`),
- `step_finish` carries tokens/cost into the session panel and the transcript
  winbar.

Motions, visual selection, yanks, folds, search and `:g` work on the transcript;
editing does not. Status (running, tokens, cost) lives in the window bar, not in
the text.

## 3. Control back (OpenCode → Neovim)

An OpenCode plugin runs in the OpenCode server and does not inherit `$NVIM`, so
the editor publishes its socket:

```
${XDG_RUNTIME_DIR}/nvim-bridge/<pid>.json
{ "server": "/run/user/1000/nvim.123.0", "cwd": "/home/me/project",
  "pid": 123, "profile": "workspace", "updated": 1794442321 }
```

`features/bridge/registry.lua` writes it and refreshes it on
directory/buffer/focus changes; `VimLeavePre` removes it. Readers ignore entries
older than five minutes.

The OpenCode-side plugin (`dot_config/opencode/plugins/nvim-bridge.ts`) picks the
entry whose `cwd` contains the session directory and registers `nvim_control`:

| Action | Effect |
| --- | --- |
| `open` | open a file (and line) in the content window |
| `transcript` | show the agent transcript |
| `slot` | point a slot at a provider |
| `layout` / `status` | read layout state as JSON |
| `append` | add a note line to the transcript |

All of it goes through `nvim --server … --remote-expr` against the documented
editor API (`docs/editor-api.md`); there is no custom protocol.

## Extending it

- Add a Neovim-side command surface (`NVSlots`, `NVBridge`) first.
- Expose it through `nvim_control` if an agent should be able to call it.
- Keep features on top of these two layers: the bridge stays transport, the
  features orchestrate.

## Tests

`tests/bridge.sh` uses a fake `opencode` binary and asserts the NDJSON handling,
part de-duplication, tool lines and their extmarks, read-only + yankable
transcript, registry file, `open_file`, winbar, and the archived flag.

Live verification: a prompt typed into the bottom panel streams into the centre
buffer; a prompt sent from Neovim makes the agent call `nvim_control` and
change a slot / open a file.
