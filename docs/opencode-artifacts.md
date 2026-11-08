# OpenCode artifacts (plans, evidence, reviews)

`lua/editor/features/opencode-artifacts.lua` exposes the global
`NVOpenCodeArtifacts`: one Neovim interface over the OpenCode artifact registry
(`personal.artifacts` RPC) for plans, evidence, and reviews.
All calls run through the `opencode api` CLI as nonblocking `vim.system` jobs
with argv lists and JSON-encoded bodies, an explicit location (the current tab
directory), a bounded timeout, and scheduled callbacks. Calls run in the
background.

Artifacts are addressed by ID only. Each artifact has one authoritative server
record and one generated `current.md` view; the editor opens that view
read-only.

## Commands and keymaps

| Command | Keymap | Shows |
|---|---|---|
| `:OpenCodePlans` | `<leader>ap` | Draft plans only |
| `:OpenCodeEvidence` | `<leader>ae` | Evidence |
| `:OpenCodeReviews` | `<leader>ar` | Reviews |
| `:OpenCodeArtifacts` | `<leader>aa` | Plan/evidence/review artifacts |
| `:OpenCodeSession` | `<leader>as` | Attach or switch session |

Evidence, Reviews and All hide resolved rows — `approved` plans and `read`
evidence/reviews — until `<M-a>` (include-finished toggle) flips the filter; the
toggle re-runs the finder and relabels the filter.
`:OpenCodePlans` is a kind-filtered view defaulting to draft plans (approved
plans only appear with the toggle). Rows show kind, title, status, and
provenance (primary author label and update date), with the owner session id
kept internal for feedback routing.
Artifacts are keyed by the project: every worktree of the same checkout lists
the same plans, evidence, and reviews.
Confirming an entry opens the artifact's generated Markdown view read-only in
the current window; preview uses the real file. Artifacts stay until the user
removes them.

## Artifact buffers

Opened buffers are verified by path before options, metadata or commands are
attached; opening refuses when the current buffer has unsaved changes. Buffer
metadata (`vim.b[buf].opencode_artifact`) records the artifact ID, location,
display fields (title, kind, status, description, primary author), path, and a
full-document fingerprint of the displayed bytes used only to detect external
changes.

Buffer-local commands and keymaps:

- `OpenCodeArtifactFeedback` and `<leader>af` (normal/visual): feedback on the
  artifact; a visual range becomes the selected excerpt/range.
- `OpenCodeArtifactRetryDelivery`: redeliver the recorded-but-undelivered plan
  approval for this artifact.
- `OpenCodeArtifactApprove` and `<leader>ay` (normal): approve a draft plan;
  attached to plan buffers only (approval applies to draft plans).
- `OpenCodeArtifactMarkRead` and the same `<leader>ay` (normal): mark a
  published evidence/review read; attached to evidence/review buffers that are
  not yet `read`. The key is buffer-local, so `<leader>ay` is Approve on a plan
  buffer and Mark read on an evidence/review buffer.

## Feedback submission

`<leader>af` opens the multiline input (74 columns by 6 lines, clamped to the
screen, wrapping enabled). Enter inserts a newline; Alt+Enter submits from
insert and normal mode; Escape/q/`<M-w>`/leaving the dialog cancels. The
question is limited to 16384 UTF-8 bytes and the selected excerpt to 65536.
Delivery notices state transport facts only: delivered means handed to the
Planner session, not that the Planner has processed or acted on it. Feedback is
send-once; retry applies to plan approvals.

## Plan approval and Mark read

`OpenCodeArtifactApprove`/`<leader>ay` exist only on draft plan buffers. The
confirm step shows the explicit label `Approve this plan` and the title. A
recorded plan approval is the user's review marker; editing the plan returns it
to draft and clears the marker. The plan stays editable until `plan_complete`
records the outcome. The picker hides `approved` rows until the include-finished
toggle `<M-a>` includes them. After an approval is recorded — including when its
notification fails — only the originating buffer is closed (revalidating
buffer, identity and modified state; the buffer stays in place, and transport
failures or unknown admission keep it open). If the approved buffer
stays open (displayed elsewhere), its approval UI is removed. A
recorded-but-undelivered approval is redeliverable from the picker after the
close. Approval applies to plans.

`OpenCodeArtifactMarkRead`/`<leader>ay` exist only on published
evidence/review buffers. The confirm step shows `Mark this evidence read` /
`Mark this review read`. Mark read records the dismissal on the server
(`status: read`) without delivery handling, then closes the originating buffer. The picker hides `read` rows until the
include-finished toggle includes them. A content patch (or finding mutation)
returns a `read` evidence/review to the visible `draft` (the read marker is
cleared and readiness resets), so it reappears in pickers as a draft and regains
its mark-read UI only after the author finalizes it again (`published`).

## Retry from the picker

`<M-r>` on a picker row fetches that artifact's record, lists its
recorded-but-undelivered plan approval, and retries that original request ID.
Retry applies to plan approvals. The records live server-side, so recovery works
after closing the buffer and after restarting Neovim; list rendering stays
metadata-only.

## External changes

Artifact buffers rely on `autoread` plus the existing checktime triggers
(`BufEnter`/`FocusGained`/`CursorHold`/`CursorHoldI`). On
`FileChangedShellPost`, an unmodified artifact buffer has its displayed-document
fingerprint recomputed; when the bytes changed, its metadata is refreshed from
the record (including title, status, description, primary author, readiness and
path) and a brief "Artifact updated" notice appears. The event reports the
change, keeping the author out of it. Locally modified buffers stay untouched.
Refresh relies on those triggers.

## Layers

Three modules, each with one job:

| Module | Owns | Independent of |
|---|---|---|
| `lua/editor/features/opencode-rpc.lua` | argv envelope, location-scoped RPC path, request IDs, timeouts, typed `RpcError` decoding, injectable transport | artifacts, sessions, buffers |
| `lua/editor/features/opencode-session.lua` | per-directory attachment map, session list/create/attach/detach picker | artifacts |
| `lua/editor/features/opencode-artifacts.lua` | artifact picker, read-only buffers, feedback, approval, mark read, retry | transport details, session storage |

The RPC layer takes a namespace and a method, so a future frontend domain
(session control, UI commands) reuses it without touching artifacts. The
OpenCode side mirrors this: `plugins/bridge/` serves `personal.bridge`, which
describes the registered domains, and an adapter plugin
(`plugins/artifacts-rpc/`) registers the artifact domain through it. The
artifact tools stay independent of bridge code.

## Module layout and reload

`NVOpenCodeRpc` lives in `lua/editor/features/opencode-rpc.lua`,
`NVOpenCodeSession` in `lua/editor/features/opencode-session.lua`, and
`NVOpenCodeArtifacts` in `lua/editor/features/opencode-artifacts.lua`.
`setup()` is idempotent (commands, keymaps and the autocmd group can be
re-created on module reload). `NVOpenCodeSession.setup()` owns
`:OpenCodeSession` and `<leader>as`.

Tests live in `tests/opencode/`:

```sh
nvim --headless -u NONE -l tests/opencode/bridge.lua
nvim --headless -u NONE -l tests/opencode/artifacts.lua
```