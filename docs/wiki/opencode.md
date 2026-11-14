# OpenCode

Neovim and OpenCode talk in both directions:

- **Editor → agent:** OpenCode's background service API (HTTP plus one event
  stream), through `features/opencode/client.lua`.
- **Agent → editor:** Neovim's RPC socket, driven by the agent's `nvim` tool.

## The service client

OpenCode v2 runs one background service for every client (TUI, desktop, this
editor). It registers itself in `$XDG_STATE_HOME/opencode/service.json` (or
`service-<channel>.json`) with its URL and a password; requests use HTTP basic
auth as `opencode:<password>`.

`features/opencode/client.lua`:

- **Discovery:** registrations newest first, each verified with
  `GET /api/info`. A connection failure forgets the server so the next request
  re-discovers it (a restarted service moves port and password).
- **Requests:** `curl` jobs. The credentials and the JSON body go to curl on
  stdin (`-K -`), never on the command line where `ps` would show them.
- **Events:** one long-lived `GET /api/event` stream, re-emitted as
  `User NVOpenCode:<type>` autocmds with `data = event`. `User NVOpenCodeState`
  fires on connection changes.
- **Heartbeat:** the service sends `: heartbeat` every 15 s. 20 s of silence
  drops the stream, which reconnects with backoff (1 s doubling to 30 s).

The stream is **global** in 2.2.x: it carries every session of every project,
and `x-opencode-directory` does not filter it (verified: identical captures
with and without the header). Every consumer filters by session id
(`client.session_of(event)`).

## Sessions: internal and external

The **target** is the session attached to the current directory
(`features/opencode/attach.lua`, `<leader>as`); the prompt panel sends to it.

- **Internal**: created by Neovim and tagged `metadata.origin = "nvim"`. Their
  conversation shows here, in the transcript.
- **External**: any other session, such as one started in the TUI. The prompt
  panel can send to it; its conversation shows where it lives.

Without a target, the first prompt creates an internal session and attaches it.
`<leader>an` starts a new one, and `<leader>ax` interrupts the target's turn.

`features/opencode/sessions.lua` (`NVOpenCodeSessions`) follows the tracked
sessions from events:

- **Info:** title, model, agent, metadata, cost.
- **Busy:** busy or idle, with the running tool.
- **Waiting on you:** permission requests and forms (questions), until they're
  answered anywhere, the TUI included. Reading `GET …/permission` and
  `…/form` on attach and after every reconnect catches up on missed events.

`User NVOpenCodeSession` (`data = { id }`) fires on every change.

When a followed session starts waiting, one toast appears. The session panel
(`󰂞 waiting on you`) and the prompt strip keep an indicator until it's
answered.

## Prompt panel

| Key | Action |
| --- | --- |
| `<CR>` | send (queued behind the current turn if the agent is busy) |
| `<M-CR>` | send now: steer the running turn |
| `<S-CR>` / `<C-j>` | new line |
| `<M-a>` | transcript (and back) |

The strip shows the target, a `nvim` or `external` chip with its title, and its
state (`working`, `waiting on you`, `offline`). It fits the window: the title
shortens first, then hints drop, least used first.

## Transcript

`features/opencode/transcript.lua` keeps a model of the conversation: entries
for prompts, answers and notes.

- **Rebuilt from history:** it loads from `GET /api/session/<id>/message`,
  newest 120 messages, with older ones a `<CR>` away.
- **Kept current from events:**
  - `session.inbox.*` add prompts.
  - `session.text.*` / `session.reasoning.*` add text, keyed by message and
    ordinal.
  - `session.tool.*` update tool lines.
  - Execution, retry, compaction and skill events become notes.
- **The buffer is only a view:** one per session, `opencode://session/<id>`,
  read-only markdown. Deleting it (`Alt+w`) loses nothing; `<M-a>` rebuilds it.
- **Cheap redraws:** each entry renders to its own lines and an update redraws
  only that entry, coalesced to one redraw per 40 ms, so streaming stays cheap
  on long sessions.
- **One header per turn:** a turn's steps (several assistant messages) share a
  header.
- **Reasoning:** one dimmed line; `<CR>` expands it.
- **Tools:** one line each: status mark, name, and what the tool touched.
  OpenCode's `execute` wrapper is resolved to the inner tool
  (`nvim.control open`).

The window is a reading surface: no numbers or sign column, wrapped prose, and
render-markdown only at 110 columns or wider (narrow tables clip). The winbar
shows the title, state, waiting chip, model and cost.

## Context in the prompt

References are plain text in the draft, so typed, completed and inserted ones
behave the same. `features/opencode/context.lua` parses them when sending:

| In the draft | Sent as |
| --- | --- |
| `@path`, `@path:12`, `@path:12-30` | `files[]`: `file://abs?start=12&end=30` with a mention span; OpenCode inlines that slice (a bare path: the whole file) |
| `$skill` | `skills[]` (known skill ids only) |
| `/command args` at the start | the whole prompt runs that command (`POST …/command`) |

Mentions are offsets in UTF-16 code units (JS strings).

| Key | Adds to the draft |
| --- | --- |
| `<leader>ai` | `@path:line` (normal) or `@path:a-b` (visual) |
| `<leader>aI` | `@path` (the whole file) |
| `<leader>ad` | diagnostics as a block under `@path:a-b`; with none on the line, the file's, under its plain path (not attached) |
| `<leader>ao{motion}` | `@path:a-b` for the motion's lines |
| `<leader>ak` / `<leader>ac` | `$skill` / `/command ` (pickers) |

`features/opencode/prompt_lsp.lua` is an in-process language server attached
to the prompt buffer (`opencode://prompt`). It needs no process and no
JSON-RPC: `vim.lsp.start` with a Lua `cmd`.

- **Completion** through blink's LSP source:
  - `@` offers files (open buffers first). They're filtered and ranked on the
    whole typed path, because blink's own filter only sees the word after the
    last `/`. The label is the file name followed by its directory.
  - `$` offers skills, and `/` offers commands at the start of the prompt.
- **Hover:** `K` previews a reference's lines, or a skill's or command's
  description.
- **Go to definition:** `gd` opens the file at the line.

Project files come from `rg --files --hidden`, not `git ls-files`, which lists
a submodule as a single entry. The LSP panel leaves this server out.

## Permissions and questions

`features/opencode/requests.lua`:

- **Internal sessions:** a permission request opens a select (allow once,
  always allow, reject, reject with a message). A form (question) is walked
  field by field:
  - free text, number or integer, yes/no, options (with "Something else…" when
    custom answers are allowed), multiselect (Tab marks), external (opens the
    URL);
  - `when` conditions and hidden fields are honoured;
  - cancelling leaves the question open.
- **External sessions:** the "waiting on you" indicator only.
- **`<leader>aw`:** answers or dismisses anything any followed session is
  waiting on.
- **Answered elsewhere** (the TUI): `permission.replied` / `form.replied` /
  `form.cancelled` close the prompt.
- **Edit review**, opt-in: `vim.g.nv_opencode_review_edits = true`. For
  internal sessions, an edit permission carrying a single-file patch opens as a
  diff in its own tab: `da` accept, `dr` reject, `q` decide later. Off by
  default, since edits are reviewed afterwards in the Changes panel.

## Model, variant, agent

`features/opencode/pickers.lua`:

- **`<leader>am` model:** the TUI's favourites (★) and recents (◷) from
  `~/.local/state/opencode/model.json` come first. Choosing a model that has
  variants asks for one.
- **`<leader>av` variant**, **`<leader>ag` agent** (primary, visible).

The choice goes to the target session (`POST …/model`, `…/agent`). With no
session yet, it applies to the next one the prompt creates.

## Agent → editor (`nvim` tool)

An OpenCode plugin runs in the service and does not inherit `$NVIM`, so the
editor publishes its socket:

```
${XDG_RUNTIME_DIR}/nvim-bridge/<pid>.json
{ "server": "/run/user/1000/nvim.123.0", "cwd": "/home/me/project",
  "pid": 123, "profile": "workspace", "updated": 1794442321,
  "sessions": ["ses_…"] }
```

- **Writing it:** `features/bridge/registry.lua` writes the entry and refreshes
  it on directory, buffer and focus changes. `VimLeavePre` removes it, and dead
  entries are pruned.
- **Editor-initiated:** `sessions` lists the OpenCode sessions this editor
  connected to: its prompt target, and sessions whose transcript it shows
  (`NVOpenCodeSessions.bound()`). Changing the target or detaching removes the
  old session from the list, unless its transcript is open.
- **Only those sessions have the tool.** The plugin
  (`dot_config/opencode/plugins/nvim-bridge.ts`) registers a session `context`
  hook. Before every model request, it removes `nvim_control` from the tool
  list unless a live editor lists that session. The tool is a direct tool
  (`codemode: false`), because the hook sees only direct tools, not Code Mode's
  catalog.
- **Exactly that editor:** a call drives the editor bound to its session (the
  most recently active one if several are bound). Nothing is guessed from the
  working directory; with no bound editor, the call is refused.

Verified live: a session the dev editor connected to answered that it had
`nvim_control` and opened a file in that editor. A session created outside
Neovim answered that it had no such tool.

| Action | Effect (editor function) |
| --- | --- |
| `open` | open a file at a line (`NVBridge.open_file`) |
| `transcript` | show the target's transcript (`NVBridge.open`) |
| `slot` | point a slot at a provider |
| `layout` / `status` | layout state as JSON |
| `append` | a note in the transcript, or a toast for an external target (`NVBridge.append`) |
| `show` | read-only text in the editing area (`NVBridge.show_text`) |

All of it goes through `nvim --server … --remote-expr` against the editor API
([editor API](editor-api.md)).

## Artifacts (plans, evidence, reviews)

`lua/features/opencode/artifacts.lua` exposes the global
`NVOpenCodeArtifacts`: one Neovim interface over the OpenCode artifact registry
(`personal.artifacts` RPC) for plans, evidence, and reviews. All calls run
through the `opencode api` CLI as nonblocking `vim.system` jobs with argv lists
and JSON-encoded bodies, an explicit location (the current tab directory), a
bounded timeout, and scheduled callbacks. Calls run in the background.

Artifacts are addressed by ID only. Each artifact has one authoritative server
record and one generated `current.md` view; the editor opens that view
read-only.

### Commands and keymaps

| Command              | Keymap       | Shows                          |
| -------------------- | ------------ | ------------------------------ |
| `:OpenCodePlans`     | `<leader>ap` | Draft plans only               |
| `:OpenCodeEvidence`  | `<leader>ae` | Evidence                       |
| `:OpenCodeReviews`   | `<leader>ar` | Reviews                        |
| `:OpenCodeArtifacts` | `<leader>aa` | Plan/evidence/review artifacts |
| `:OpenCodeSession`   | `<leader>as` | Attach or switch session       |

Evidence, Reviews and All hide `read` evidence and reviews until `<M-a>` (the
include-finished toggle) flips the filter; the toggle re-runs the finder and
relabels the filter. `:OpenCodePlans` shows every plan, draft or completed. Rows
show kind, title, status, and provenance (primary author label and update date),
with the owner session id kept internal for feedback routing. Artifacts are
keyed by the project: every worktree of the same checkout lists the same plans,
evidence, and reviews. Confirming an entry opens the artifact's generated
Markdown view read-only in the current window; preview uses the real file.
Artifacts stay until the user removes them.

### Artifact buffers

Opened buffers are verified by path before options, metadata or commands are
attached; opening refuses when the current buffer has unsaved changes. Buffer
metadata (`vim.b[buf].opencode_artifact`) records the artifact ID, location,
display fields (title, kind, status, description, primary author), path, and a
full-document fingerprint of the displayed bytes used only to detect external
changes.

Buffer-local commands and keymaps:

- `OpenCodeArtifactFeedback` and `<leader>af` (normal/visual): feedback on the
  artifact; a visual range becomes the selected excerpt/range.
- `OpenCodeArtifactMarkRead` and `<leader>ay` (normal): mark a published
  evidence/review read; attached to evidence/review buffers that are not yet
  `read`. Plan buffers carry feedback only.

### Feedback submission

`<leader>af` opens the multiline input (74 columns by 6 lines, clamped to the
screen, wrapping enabled). Enter inserts a newline; Alt+Enter submits from
insert and normal mode; Escape/q/`<M-w>`/leaving the dialog cancels. The
question is limited to 16384 UTF-8 bytes and the selected excerpt to 65536.
Delivery notices state transport facts only: delivered means handed to the
Planner session, not that the Planner has processed or acted on it. Feedback is
send-once; delivery is not retried from the editor.

### Mark read

`OpenCodeArtifactMarkRead`/`<leader>ay` exist only on published evidence/review
buffers. The confirm step shows `Mark this evidence read` /
`Mark this review read`. Mark read records the dismissal on the server
(`status: read`) without delivery handling, then closes the originating buffer.
The picker hides `read` rows until the include-finished toggle includes them. A
content patch (or finding mutation) returns a `read` evidence/review to the
visible `draft` (the read marker is cleared and readiness resets), so it
reappears in pickers as a draft and regains its mark-read UI only after the
author finalizes it again (`published`).

### External changes

Artifact buffers rely on `autoread` plus the existing checktime triggers
(`BufEnter`/`FocusGained`/`CursorHold`/`CursorHoldI`). On
`FileChangedShellPost`, an unmodified artifact buffer has its displayed-document
fingerprint recomputed; when the bytes changed, its metadata is refreshed from
the record (including title, status, description, primary author, and path) and
a brief "Artifact updated" notice appears. The event reports the change only.
Locally modified buffers stay untouched. Refresh relies on those triggers.

### Layers

Three modules, each with one job:

| Module                                       | Owns                                                                                                            | Independent of                     |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `lua/editor/features/opencode-rpc.lua`       | argv envelope, location-scoped RPC path, request IDs, timeouts, typed `RpcError` decoding, injectable transport | artifacts, sessions, buffers       |
| `lua/editor/features/opencode-session.lua`   | per-directory attachment map, session list/create/attach/detach picker                                          | artifacts                          |
| `lua/features/opencode/artifacts.lua` | artifact picker, read-only buffers, feedback, mark read                                                         | transport details, session storage |

The RPC layer takes a namespace and a method, so a future frontend domain
(session control, UI commands) reuses it without touching artifacts. The
OpenCode side mirrors this: `plugins/bridge/` serves `personal.bridge`, which
describes the registered domains, and an adapter plugin
(`plugins/artifacts-rpc/`) registers the artifact domain through it. The Only
the RPC adapter imports bridge code.

### Module layout and reload

`NVOpenCodeRpc` lives in `lua/editor/features/opencode-rpc.lua`,
`NVOpenCodeSession` in `lua/editor/features/opencode-session.lua`, and
`NVOpenCodeArtifacts` in `lua/features/opencode/artifacts.lua`. `setup()`
is idempotent (commands, keymaps and the autocmd group can be re-created on
module reload). `NVOpenCodeSession.setup()` owns `:OpenCodeSession` and
`<leader>as`.

Tests live in `tests/opencode/`:

```sh
nvim --headless -u NONE -l tests/opencode/bridge.lua
nvim --headless -u NONE -l tests/opencode/artifacts.lua
```

## Tests

`tests/bridge.sh` replaces the client's transport with a fake that answers the
API paths. It asserts:

- credentials and body travel on stdin, never argv;
- SSE framing (split chunks, heartbeats, multi-line data);
- busy and waiting states, with catch-up and replies from elsewhere;
- events from untracked sessions are ignored;
- the transcript built from history, then live deltas, tool lines (including a
  failure) and one header per turn;
- reasoning expands with `<CR>`;
- the transcript is rebuilt after its buffer is deleted;
- the registry file, `open_file` and `show_text` work.

Verified live against OpenCode 2.2.7, with throwaway sessions on a cheap model,
deleted afterwards:

- A prompt typed into the panel streamed into the transcript.
- A tool call showed as one line.
- `Alt+w` and `<M-a>` rebuilt the transcript from history.
- An external session with a shell "ask" rule raised the waiting indicator, and
  answering through the API cleared it.
- Killing the stream reconnected within seconds.
