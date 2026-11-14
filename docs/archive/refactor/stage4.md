# Stage 4 — slot layout core

## Model

`lua/features/layout/slots.lua` owns a fixed set of regions around the editing
area:

```
┌────────┬──────────────────┬──────────┐
│        │                  │ right    │
│  left  │     center       │ top      │
│        │                  ├──────────┤
├────────┤                  │ right    │
│ bottom │──────────────────│ bottom   │
│ left   │     bottom       │          │
└────────┴──────────────────┴──────────┘
```

Each slot is `{ win, buf }` plus a name and a size rule. Slots are real splits
whose windows carry `winfixwidth`/`winfixheight` once sized, with unlisted
`nofile` placeholder buffers (`filetype=nvslot`, `vim.b[buf].nv_slot`) until the
providers in stage 5 replace them.

Sizing is computed from the geometry measured *before* splitting, because the
centre gives up width and height as soon as the first split exists:

| Slot | Rule |
| --- | --- |
| `left` | 20% of width, minimum 24 |
| `right_top`, `right_bottom` | 26% of width, minimum 28; the column splits in half |
| `bottom` | 30% of the centre column height, minimum 8 |
| `bottom_left` | 40% of the left column height, minimum 6 |

## Behaviour

- `:NVLayout [open|close|status|toggle]` and `<M-i>` (stored as
  `NVKeymaps.layout_toggle`).
- State is per tabpage; a new tab starts without slots.
- Applying the layout calls `NVLayoutManager.disable()`, so the sidepad
  centring used in plain mode cannot fight the fixed columns. The sidepad
  auto-enable also skips while slots are applied.
- `open()` clears orphan slot windows first, so a repeated or interrupted apply
  cannot stack two layouts.
- `close()` closes every slot window and leaves the centre; plain mode is
  unchanged.
- `NVSlots.status()` returns each slot's window and current size, and
  `NVSlots.win(name)` returns a slot window, which is what the RPC side and the
  providers will use.

## Checks

`tests/layout.sh` runs headless against this checkout: 1 window at start, 6
after `open` with 5 slots, left narrower than right, the right halves equal,
`close` back to a single leaf and `applied=false`, reopen, close. It passes.

Two things this stage learned:

- `nvim_tabpage_list_wins()` counts ui2's message/cmd/dialog/pager floats, so
  window counts must be read from `winlayout()` or by filtering floats.
- A `<M-l>` binding existed already (`NVKeymaps.scroll_side.right`); the toggle
  moved to `<M-i>`.
