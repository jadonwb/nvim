# Agent bridge

The bridge connects this editor to an `opencode` session in three directions.

1. **Prompt out.** The bottom panel's `prompt` provider sends the draft to
   `opencode run --format json`.
2. **Content back.** The NDJSON stream is appended to a real buffer: the agent's
   answer is ordinary text, so motions, visual selection, `y`, folds, search and
   `:g` work on it.
3. **Control back.** `opencode` drives Neovim over the RPC socket that Neovim
   exports to its jobs, using the same entry points any external tool uses
   (`docs/editor-api.md`).

The third direction is why this is "two and a half" ways rather than two: the
control channel is not a separate protocol, it reuses the editor API.

## Rendering rule

Volt draws virtual text. Virtual text is not in the buffer, so cursor motions
pass through it, `y` copies nothing, and `:g`/search cannot see it. Anything the
user may want to select must therefore be **real buffer lines**; volt is for
chrome (session panel, notification centre, popup, status bars).

This is the same split the surveyed plugins converged on: avante, codecompanion,
CopilotChat and agentic.nvim all keep the transcript as real lines and use
extmarks for spinners, separators, status and tool badges. Terminal wrappers
(sidekick, claudecode, gemini-cli) get selectability only through terminal
normal mode and lose markdown structure.

## Transcript buffer

- `opencode://<timestamp>`, `filetype=markdown`, listed, `bufhidden=hide`,
  `modifiable=false`. The stream writes with `modifiable` temporarily lifted, so
  the user cannot edit the record but can still select it.
- Append-only. Follow-the-stream scrolling happens only while the cursor is on
  the last line; scrolling back stops the follow for the rest of the response.
- Decoration lives in namespace `nv_bridge` (currently tool lines; later block
  separators, fenced-code backgrounds, message headers).
- One buffer per session, reused across prompts. A new session creates a new
  buffer.

## Stream events

`opencode run --format json` emits one JSON object per line:

| `type` | Handling |
| --- | --- |
| `step_start` | ignored; the next `step_finish` belongs to it |
| `text` | append `part.text`; a repeated `part.id` appends only the extension |
| `tool_use` | one highlighted line: `✓ read: note.txt`, `… edit: lua/x.lua` |
| `step_finish` | tokens/cost to `NVBridge.state.status`, then `User NVBridge` |
| `reasoning` | not rendered (only emitted with `--thinking`) |

The job needs a pty: without a terminal `opencode run` starts and blocks
forever. A pty merges stderr into stdout, so non-JSON lines are collected and
reported on failure instead of being drawn into the transcript.

New sessions are created with `--archived` so scripted runs stay out of the
session list. Continuing a session passes `--session <id>`.

## Control direction

Neovim exports `$NVIM` to processes it starts, including the `opencode` job, so
an opencode tool can call back:

```sh
nvim --server "$NVIM" --remote-expr 'v:lua.NVBridge.open()'
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.set_provider("right_top", "changes")'
nvim --server "$NVIM" --remote-expr 'luaeval("vim.json.encode(NVSlots.state())")'
```

That is the whole channel: no socket protocol of our own, no plugin on the
opencode side that Neovim must trust. The opencode-side wrapper belongs in the
opencode config repository.

## Known gaps

- Tool lines are plain lines for now; the next slice folds them into a
  collapsible summary with an extmark.
- Markdown blocks (fences, tables) render literally until a decoration pass
  lands; the popup's markdown chunk adapter is not reusable here because the
  transcript must stay text.
- No session picker or resume UI; `NVBridge.state.session` carries the id and
  `:NVAgent` reuses it.
- Throttled flushing is not needed yet because parts arrive whole; if opencode
  switches to per-token deltas, coalesce on a timer (codecompanion uses 25 ms,
  avante 50 ms).
