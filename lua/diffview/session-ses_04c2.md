## 6. What `diffget` and `do` / `Ndo` Do

### Neovim's Native Diff Mode

When Neovim has `:diffthis` active on multiple windows:

- **`do`** (alias for `:diffget`) — **Obtain** (copy) the diff hunk under cursor *from* another window *into* the current window. Think "pull that change into my buffer."
- **`dp`** (alias for `:diffput`) — **Put** the diff hunk under cursor *from* the current window *into* the other window. Think "push my change into that buffer."
- **`[c`** / **`]c`** — Jump between diff hunks.
- **`zo`** / **`zc`** / **`zf`** — Fold commands (diff mode uses manual folding).

### How Diffview-Plus Maps This

In a 2-way diff (`diff2`), there are two buffers. Native `do`/`dp` work because Neovim just knows "the other window."

In 3-way and 4-way diffs, you need to specify *which* of the other windows to grab from:

| Window # | Symbol | Meaning | Keymap |
|----------|--------|---------|--------|
| 2 | OURS | Your version (working tree or HEAD) | `2do` |
| 3 | THEIRS | Their version (merge source) | `3do` |
| 1 | BASE | Common ancestor (4-way only) | `1do` |

So `2do` means "diffget the hunk under cursor from the OURS window into the current window."

### When Would You Use This?

When resolving a merge conflict interactively in `diff3_horizontal` layout:
- Cursor in the merge output buffer (center), looking at a conflict.
- Press `2do` → grab OURS version of this hunk.
- Press `3do` → grab THEIRS version of this hunk.
- Unlike `<leader>co`/`<leader>ct` (which parse `<<<<<<<` markers), `diffget` works on *any* diff, not just merge markers. It's a lower-level tool.

### What Else to Learn About Neovim Diffing

- `:h diff-mode` — the full native diff reference
- `:h :diffget` / `:h :diffput` — with `[buffer-spec]` for `:Ndiffget`
- `:h :diffupdate` — re-compute diffs after editing
- `:h diffopt` — configure diff algorithm, whitespace handling, etc.
- `:h diff-fold` — native fold-based navigation of changes

---
## 7. Merge Tool and Merge Highlights

### How to Test Merge Conflicts

**Quick simulated merge conflict:**

```bash
cd /tmp
mkdir merge-test && cd merge-test
git init

# Create initial commit
echo -e "line 1\nline 2\nline 3" > test.txt
git add test.txt && git commit -m "initial"

# Create feature branch with a conflicting change
git checkout -b feature
echo -e "line 1\nFEATURE version of line 2\nline 3" > test.txt
git add test.txt && git commit -m "feature change"

# Back to main, make a different change to the same line
git checkout -b main
echo -e "line 1\nMAIN version of line 2\nline 3" > test.txt
git add test.txt && git commit -m "main change"

# Trigger the merge conflict
git merge feature
# CONFLICT! Now open with:
nvim -c "DiffviewOpen"
```

You'll see the `diff3_horizontal` layout with three panes. Test your `<leader>dX` bindings and see how `2do`/`3do` work.

