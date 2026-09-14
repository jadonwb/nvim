# OpenCode artifacts (plans, evidence, reviews)

`lua/editor/features/opencode-artifacts.lua` exposes the global
`NVOpenCodeArtifacts`: one Neovim interface over the OpenCode plan-bridge
registry (`personal.artifacts` RPC) for plans, evidence and reviews. All calls
run through the `opencode api` CLI as nonblocking `vim.system` jobs with argv
lists and JSON-encoded bodies — selected text is never interpolated into a
shell string — with an explicit location (the current tab directory), a bounded
timeout, and scheduled callbacks. Nothing blocks or polls.

## Commands and keymaps

| Command | Keymap | Shows |
|---|---|---|
| `:OpenCodePlans` | `<leader>ap` | Draft plans only |
| `:OpenCodeEvidence` | `<leader>ae` | Evidence |
| `:OpenCodeReviews` | `<leader>ar` | Reviews |
| `:OpenCodeArtifacts` | `<leader>aa` | Every kind |

All entrypoints hide approved artifacts until `<M-a>` (include-approved toggle)
flips the filter; the toggle re-runs the finder and relabels the filter.
`:OpenCodePlans` is an intentional kind-filtered view of draft plans, not an
alias. Rows show kind, title, status and provenance (owner session, update
date, format). Confirming an entry opens the artifact's stable Markdown file
read-only in the current window; preview uses the real file. Nothing is ever
deleted and there is no time-based retention.

## Artifact buffers

Opened buffers are verified by path before options, metadata or commands are
attached; opening refuses when the current buffer has unsaved changes. Buffer
metadata (`vim.b[buf].opencode_artifact`) records identity, display fields,
format/schema version, provenance, and the revision tracking:

- `displayed_revision` — recomputed from the actual displayed bytes, never
  taken from the server latest. Shared-markdown-v1 artifacts use the canonical
  revision (which excludes `updated_at`/`status`); raw-markdown documents keep
  the raw-byte SHA-256.
- `fingerprint` — SHA-256 of the full displayed document, tracked separately
  from the content revision.

Buffer-local commands and keymaps:

- `OpenCodeArtifactFeedback` and `<leader>af` (normal/visual): feedback on the
  displayed revision; a visual range becomes the selected excerpt/range.
- `OpenCodeArtifactRetryDelivery`: redeliver the recorded-but-undelivered
  submission for this artifact (same request ID, no new prompt).
- `OpenCodeArtifactApprove` and `<leader>ay` (normal): approve the displayed
  revision, attached only to draft plans.

## Feedback submission

`<leader>af` opens the multiline input (74 columns by 6 lines, clamped to the
screen, wrapping enabled). Enter inserts a newline; Alt+Enter submits from
insert and normal mode; Escape/q/`<M-w>`/leaving the dialog cancels. The
question is limited to 16384 UTF-8 bytes and the selected excerpt to 65536.
Delivery notices state transport facts only: delivered means handed to the
Planner session, not that the Planner has processed or acted on it. When a
submission is recorded but not delivered, the exact request ID stays retryable.

## Approval

`OpenCodeArtifactApprove`/`<leader>ay` exist only on draft plan buffers. The
confirm step shows an explicitly selectable label, the title, and the displayed
revision. The label and outcome follow the artifact's record-only `authority`:

- `authority=implementation`: `Approve this revision (authorizes Builder)`.
  After approval the Planner may launch Builder for that exact revision.
- `authority=historical` (including an absent or unknown authority):
  `Record historical approval (does not authorize Builder)`. This is a freeze
  only.

After an approval is recorded — including when its notification fails — only
the originating buffer is closed (revalidating buffer, identity and modified
state; nothing is force-deleted, and transport failures or unknown admission
keep the buffer open). If the approved buffer stays open (displayed elsewhere),
its approval UI is removed. A recorded-but-undelivered approval is redeliverable
from the picker after the close.

## Retry from the picker

`<M-r>` on a picker row fetches that artifact's record, lists its persisted
pending/failed feedback/approval submissions, and retries the selected original
request ID. The records live server-side, so recovery works after closing the
buffer and after restarting Neovim; list rendering never fetches full records.

## External changes

Artifact buffers rely on `autoread` plus the existing checktime triggers
(`BufEnter`/`FocusGained`/`CursorHold`/`CursorHoldI`). On
`FileChangedShellPost`, an unmodified artifact buffer has its revision
recomputed from the displayed bytes and its whole metadata table reassigned; a
brief "Artifact updated" notice appears only when the bytes changed. The event
says nothing about who wrote the file. Locally modified buffers are never
touched. There is no polling, SSE, or extra checktime loop, and no manual
refresh command.

## Module layout and reload

`NVOpenCodeArtifacts` lives in `lua/editor/features/opencode-artifacts.lua`;
the exact shared-markdown-v1 parser/revision implementation is
`lua/editor/features/opencode-artifacts/format.lua`, pinned to the backend's
`format-fixtures.json`. `setup()` is idempotent (commands, keymaps and the
autocmd group can be re-created on module reload).
