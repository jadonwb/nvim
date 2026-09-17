# OpenCode artifacts (plans, evidence, reviews, reports)

`lua/editor/features/opencode-artifacts.lua` exposes the global
`NVOpenCodeArtifacts`: one Neovim interface over the OpenCode artifact registry
(`personal.artifacts` RPC) for plans, evidence, reviews, and reports.
All calls run through the `opencode api` CLI as nonblocking `vim.system` jobs
with argv lists and JSON-encoded bodies — selected text is never interpolated
into a shell string — with an explicit location (the current tab directory), a
bounded timeout, and scheduled callbacks. Nothing blocks or polls.

Artifacts are addressed by ID only. Each artifact has one authoritative server
record and one generated `current.md` view; the editor opens that view read-only
and never parses it back into runtime state.

## Commands and keymaps

| Command | Keymap | Shows |
|---|---|---|
| `:OpenCodePlans` | `<leader>ap` | Draft plans only |
| `:OpenCodeEvidence` | `<leader>ae` | Evidence |
| `:OpenCodeReviews` | `<leader>ar` | Reviews |
| `:OpenCodeReports` | `<leader>aq` | Reports |
| `:OpenCodeArtifacts` | `<leader>aa` | Every kind |
| `:OpenCodeSession` | `<leader>as` | Attach or switch session |

Evidence, Reviews, Reports and All hide resolved rows — `approved` plans and
`read` evidence/reviews/reports — until `<M-a>` (include-finished toggle) flips
the filter; the toggle re-runs the finder and relabels the filter.
`:OpenCodePlans` is a kind-filtered view defaulting to draft plans (approved
plans only appear with the toggle). Rows show kind, title, status
and provenance (primary author label and update date; the owner session id is
used only for the internal attached-session filter and is never rendered).
Confirming an entry opens the artifact's generated Markdown view read-only in
the current window; preview uses the real file. Nothing is ever deleted and
there is no time-based retention.

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
  attached to plan buffers only (plans never approve from `approved`).
- `OpenCodeArtifactMarkRead` and the same `<leader>ay` (normal): mark a
  published evidence/review/report read; attached to evidence/review/report
  buffers that are not yet `read`. The key is buffer-local, so `<leader>ay` is
  Approve on a plan buffer and Mark read on an evidence/review/report buffer.

## Feedback submission

`<leader>af` opens the multiline input (74 columns by 6 lines, clamped to the
screen, wrapping enabled). Enter inserts a newline; Alt+Enter submits from
insert and normal mode; Escape/q/`<M-w>`/leaving the dialog cancels. The
question is limited to 16384 UTF-8 bytes and the selected excerpt to 65536.
Delivery notices state transport facts only: delivered means handed to the
Planner session, not that the Planner has processed or acted on it. Feedback is
send-once: a recorded-but-undelivered feedback submission is never retried
(retry is plan-approval-only).

## Plan approval and Mark read

`OpenCodeArtifactApprove`/`<leader>ay` exist only on draft plan buffers. The
confirm step shows the explicit label `Approve this plan` and the title. A
recorded plan approval authorizes Builder (the plan freezes; the picker hides
`approved` rows until the include-finished toggle `<M-a>` includes them). After
an approval is recorded — including when its notification fails — only the
originating buffer is closed (revalidating buffer, identity and modified state;
nothing is force-deleted, and transport failures or unknown admission keep the
buffer open). If the approved buffer stays open (displayed elsewhere), its
approval UI is removed. A recorded-but-undelivered approval is redeliverable
from the picker after the close. Non-plans are never approved.

`OpenCodeArtifactMarkRead`/`<leader>ay` exist only on published
evidence/review/report buffers. The confirm step shows `Mark this evidence
read` / `Mark this review read` / `Mark this report read`. Mark read records the
dismissal on the server (`status: read`) with NO owner notification and NO
delivery handling, then closes the originating buffer. The picker hides `read`
rows until the include-finished toggle includes them. A content patch (or
finding mutation) returns a `read` evidence/review/report to the visible
`draft` (the read marker is cleared and readiness resets), so it reappears in
pickers as a draft and regains its mark-read UI only after the author finalizes
it again (`published`).

## Retry from the picker

`<M-r>` on a picker row fetches that artifact's record, lists its
recorded-but-undelivered plan approval, and retries that original request ID.
Retry is plan-approval-only: feedback and evidence/review/report submissions are
never retryable. The records live server-side, so recovery works after closing
the buffer and after restarting Neovim; list rendering never fetches full
records.

## External changes

Artifact buffers rely on `autoread` plus the existing checktime triggers
(`BufEnter`/`FocusGained`/`CursorHold`/`CursorHoldI`). On
`FileChangedShellPost`, an unmodified artifact buffer has its displayed-document
fingerprint recomputed; when the bytes changed, its metadata is refreshed from
the record (including title, status, description, primary author, readiness and
path) and a brief "Artifact updated" notice appears. The event says nothing
about who wrote the file. Locally modified buffers are never touched. There is
no polling, SSE, or extra checktime loop, and no manual refresh command.

## Module layout and reload

`NVOpenCodeArtifacts` lives in `lua/editor/features/opencode-artifacts.lua`.
`setup()` is idempotent (commands, keymaps and
the autocmd group can be re-created on module reload).