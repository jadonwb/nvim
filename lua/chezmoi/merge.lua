-- ============================================================================
-- chezmoi/merge.lua — In-Editor Chezmoi Diff Review
-- ============================================================================
-- Architecture:
--   Opens a dedicated Neovim tab with two panels:
--     Left  — file panel listing all files with pending chezmoi changes
--     Right — two-way vimdiff (live file vs. rendered chezmoi source)
--
-- Workflow:
--   1. :ChezmoiMerge          → opens the review tab
--   2. <Tab>/<S-Tab>          → cycle through changed files
--   3. Review each diff       → see what chezmoi would change
--   4. a                      → apply the selected file
--   5. A                      → apply ALL pending files
--   6. q                      → close the tab
--
-- How it works:
--   • chezmoi status         → discovers files with pending changes
--   • chezmoi source-path    → maps target → source path
--   • execute-template --file → renders templates & decrypts for accurate diff
--   • vimdiff (diffthis)     → side-by-side comparison in the same nvim instance
--
-- Does NOT interfere with the existing auto-apply autocmd for quick edits.
-- This is an opt-in review tool for when you want to carefully inspect changes
-- before applying (e.g., after pulling from remote or during heavy editing).
--
-- Dependencies:
--   • chezmoi.nvim (for source_path / apply APIs)
--   • chezmoi CLI (for status / execute-template)
--   • plenary.nvim (job runner — indirect, via chezmoi.nvim)
--
-- Edge cases handled:
--   • Template files       → rendered before diffing (no raw {{ .email }} noise)
--   • Encrypted files      → decrypted via execute-template
--   • New files (A status) → empty left buffer, rendered source on right
--   • Deleted files (D)    → live content on left, "[will be deleted]" on right
--   • Binary files         → detected and skipped with a notification
--   • No changes           → notification instead of empty tab
--   • Already open         → refuses to open a second merge tab
--
-- Known limitations / TODO for later:
--   • chezmoi execute-template can fail on malformed templates — error is shown
--   • Binary file detection is basic (null-byte check) — may need refinement
--   • No syntax highlighting on the panel status column (yet)
--   • No "edit destination inline" mode — diff is read-only for review
--   • Only supports single-target merges (not merge-all batch processing)
-- ============================================================================

local M = {}

-- ============================================================================
-- Session state for the current merge tab
-- ============================================================================
local state = {}

local function reset_state()
  state = {
    files = {},        -- { { source_status, dest_status, path, target }, ... }
    current_idx = 0,
    tab = nil,         -- tabpage handle
    panel_win = nil,   -- file panel window id
    panel_buf = nil,   -- file panel buffer handle
    diff_win_a = nil,  -- left diff window (destination)
    diff_win_b = nil,  -- right diff window (rendered source)
    diff_buf_a = nil,  -- left diff buffer
    diff_buf_b = nil,  -- right diff buffer
  }
end

-- ============================================================================
-- chezmoi CLI helpers
-- ============================================================================

--- Run chezmoi status and return raw output lines.
--- Returns empty table on error.
local function get_status()
  local output = vim.fn.systemlist({ "chezmoi", "status" })
  if vim.v.shell_error ~= 0 then
    vim.notify("chezmoi status failed (exit code " .. vim.v.shell_error .. ")",
      vim.log.levels.ERROR)
    return {}
  end
  return output
end

--- Parse chezmoi status output into structured entries.
---
--- chezmoi status format (two-char status + space + path):
---   " M /home/user/.bashrc"   src: no change,  dest: modified
---   "A  /home/user/.newrc"    src: added,       dest: no change
---   " D /home/user/.oldrc"    src: no change,   dest: deleted
---   "MM /home/user/shared"    src: modified,    dest: modified
---   " R /home/user/script"    src: run script
---
--- Only includes entries where the source has a change (A, M, D, R).
--- If dest-only changes exist (source is space), they are still interesting
--- for review and are included.
local function parse_status(lines)
  local files = {}
  for _, line in ipairs(lines) do
    if line and line ~= "" then
      -- Trim leading whitespace (chezmoi sometimes indents)
      local trimmed = line:match("^%s*(.*)")
      if trimmed and #trimmed >= 3 then
        local source_status = trimmed:sub(1, 1)
        local dest_status = trimmed:sub(2, 2)
        local raw_path = trimmed:sub(4) -- skip "XX " prefix

        -- Basic validation: status chars should be A/D/M/R or space
        if source_status:match("[ADMR ]") and dest_status:match("[ADMR ]") then
          local target = vim.fn.expand(raw_path) -- resolve ~ to $HOME
          if target and target ~= "" then
            table.insert(files, {
              source_status = source_status,
              dest_status = dest_status,
              path = raw_path,
              target = target,
            })
          end
        end
      end
    end
  end
  return files
end

--- Get the chezmoi source path for a target file.
--- Uses chezmoi.nvim's source_path API. Returns nil on failure.
local function get_source_path(target)
  local ok, result = pcall(function()
    return require("chezmoi.commands").source_path({ targets = { target } })
  end)
  if ok and result and #result > 0 then
    return result[1]
  end
  return nil
end

--- Get rendered content for a source file.
--- Runs `chezmoi execute-template --file <source_path>` which handles
--- template rendering AND decryption. Returns empty table on error.
local function get_rendered_content(source_path)
  if not source_path then
    return {}
  end
  local output = vim.fn.systemlist({
    "chezmoi",
    "execute-template",
    "--file",
    source_path,
  })
  if vim.v.shell_error ~= 0 then
    -- Return the error output so the user can see what went wrong
    return { "[chezmoi execute-template failed]", "---", table.unpack(output) }
  end
  return output
end

--- Naive binary check: does the file contain null bytes?
local function is_binary(path)
  if not path or vim.fn.filereadable(path) == 0 then
    return false
  end
  -- Read raw bytes to check for nulls
  local ok, content = pcall(function()
    return vim.fn.readfile(path, "B") -- "B" = binary mode
  end)
  if not ok then
    return false
  end
  for _, line in ipairs(content) do
    if line:find("\0", 1, true) then
      return true
    end
  end
  return false
end

-- ============================================================================
-- UI: File Panel
-- ============================================================================

--- Create the file panel buffer listing all changed files.
--- Format: "<source_status><dest_status>  <path>"
--- Example: "M   ~/.bashrc"
local function create_panel_buffer(files)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_option(buf, "filetype", "chezmoi-merge-panel")

  local lines = {}
  for _, file in ipairs(files) do
    local status = file.source_status .. file.dest_status
    table.insert(lines, status .. "  " .. file.path)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Apply basic syntax highlighting to the panel
  -- Status column: highlight A=green, M=yellow, D=red, R=cyan
  vim.api.nvim_buf_set_option(buf, "syntax", "chezmoimergepanel")

  return buf
end

--- Refresh the panel buffer contents (e.g., after applying a file)
local function refresh_panel()
  if not state.panel_buf or not vim.api.nvim_buf_is_valid(state.panel_buf) then
    return
  end

  local lines = {}
  for _, file in ipairs(state.files) do
    local status = file.source_status .. file.dest_status
    table.insert(lines, status .. "  " .. file.path)
  end

  -- Preserve cursor position if possible
  local cursor_row = 1
  if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
    cursor_row = vim.api.nvim_win_get_cursor(state.panel_win)[1]
  end

  vim.api.nvim_buf_set_option(state.panel_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.panel_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.panel_buf, "modifiable", false)

  -- Restore cursor, clamped to valid range
  cursor_row = math.min(cursor_row, #lines)
  if cursor_row < 1 then
    cursor_row = 1
  end
  if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
    vim.api.nvim_win_set_cursor(state.panel_win, { cursor_row, 0 })
  end
end

-- ============================================================================
-- UI: Diff View
-- ============================================================================

--- Render the diff for the given file.
--- Creates/updates two diff buffers in the right-side windows.
local function show_diff(idx)
  if idx < 1 or idx > #state.files then
    return
  end
  state.current_idx = idx

  local file = state.files[idx]
  if not file then
    return
  end

  -- ── Gather content ────────────────────────────────────────────────────

  local dest_lines = {}
  local source_lines = {}
  local dest_label = "Destination"
  local source_label = "Source"

  -- Destination (live file on disk)
  if file.source_status == "A" then
    -- New file in source — destination doesn't exist yet
    dest_lines = {}
    dest_label = "[new file]"
  elseif vim.fn.filereadable(file.target) == 1 then
    if is_binary(file.target) then
      dest_lines = { "[binary file — diff not shown]" }
    else
      dest_lines = vim.fn.readfile(file.target)
    end
    dest_label = "Destination"
  else
    dest_lines = { "[file does not exist on disk]" }
    dest_label = "[missing]"
  end

  -- Source (rendered chezmoi content)
  if file.source_status == "D" then
    -- Deleted in source — file will be removed on apply
    source_lines = { "[this file will be deleted on chezmoi apply]" }
    source_label = "[deleted]"
  elseif file.source_status == "R" then
    -- Run script — can't meaningfully diff
    source_lines = { "[run script — no diff available]",
      "[chezmoi will execute this script on apply]" }
    source_label = "[script]"
  else
    local src_path = get_source_path(file.target)
    if src_path then
      if is_binary(src_path) then
        source_lines = { "[binary file — diff not shown]" }
      else
        source_lines = get_rendered_content(src_path)
      end
      source_label = "Rendered Source"
    else
      source_lines = { "[could not resolve source path]" }
      source_label = "[error]"
    end
  end

  -- ── Create / reuse diff buffers ───────────────────────────────────────

  -- Left diff buffer (destination)
  if not state.diff_buf_a or not vim.api.nvim_buf_is_valid(state.diff_buf_a) then
    state.diff_buf_a = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.diff_buf_a, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(state.diff_buf_a, "buftype", "nofile")
  end

  vim.api.nvim_buf_set_option(state.diff_buf_a, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.diff_buf_a, 0, -1, false, dest_lines)
  vim.api.nvim_buf_set_option(state.diff_buf_a, "modifiable", false)
  vim.api.nvim_buf_set_name(state.diff_buf_a,
    dest_label .. " ← " .. (file.path or ""))

  -- Right diff buffer (rendered source)
  if not state.diff_buf_b or not vim.api.nvim_buf_is_valid(state.diff_buf_b) then
    state.diff_buf_b = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.diff_buf_b, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(state.diff_buf_b, "buftype", "nofile")
  end

  vim.api.nvim_buf_set_option(state.diff_buf_b, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.diff_buf_b, 0, -1, false, source_lines)
  vim.api.nvim_buf_set_option(state.diff_buf_b, "modifiable", false)
  vim.api.nvim_buf_set_name(state.diff_buf_b,
    source_label .. " → " .. (file.path or ""))

  -- ── Assign buffers to windows & enable diff ───────────────────────────

  -- First, temporarily disable diff to avoid errors during buffer swap
  if state.diff_win_a and vim.api.nvim_win_is_valid(state.diff_win_a) then
    pcall(vim.api.nvim_win_set_option, state.diff_win_a, "diff", false)
  end
  if state.diff_win_b and vim.api.nvim_win_is_valid(state.diff_win_b) then
    pcall(vim.api.nvim_win_set_option, state.diff_win_b, "diff", false)
  end

  -- Assign buffers
  if state.diff_win_a and vim.api.nvim_win_is_valid(state.diff_win_a) then
    vim.api.nvim_win_set_buf(state.diff_win_a, state.diff_buf_a)
  end
  if state.diff_win_b and vim.api.nvim_win_is_valid(state.diff_win_b) then
    vim.api.nvim_win_set_buf(state.diff_win_b, state.diff_buf_b)
  end

  -- Re-enable diff on both windows
  if state.diff_win_a and vim.api.nvim_win_is_valid(state.diff_win_a) then
    pcall(vim.api.nvim_win_set_option, state.diff_win_a, "diff", true)
  end
  if state.diff_win_b and vim.api.nvim_win_is_valid(state.diff_win_b) then
    pcall(vim.api.nvim_win_set_option, state.diff_win_b, "diff", true)
  end

  -- Force diff recomputation
  pcall(vim.cmd, "diffupdate")

  -- ── Highlight current entry in panel ──────────────────────────────────

  if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
    vim.api.nvim_win_set_cursor(state.panel_win, { idx, 0 })
  end
end

-- ============================================================================
-- UI: Keymaps (applied to the file panel buffer)
-- ============================================================================

local function setup_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }

  -- ── Navigation ──────────────────────────────────────────────────────────

  vim.keymap.set("n", "<Tab>", function()
    if state.current_idx < #state.files then
      state.current_idx = state.current_idx + 1
      show_diff(state.current_idx)
    end
  end, vim.tbl_extend("force", opts, { desc = "Next file" }))

  vim.keymap.set("n", "<S-Tab>", function()
    if state.current_idx > 1 then
      state.current_idx = state.current_idx - 1
      show_diff(state.current_idx)
    end
  end, vim.tbl_extend("force", opts, { desc = "Previous file" }))

  -- ── Select & show diff (matching diffview muscle memory) ───────────────

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(state.panel_win)
    if cursor and cursor[1] then
      state.current_idx = cursor[1]
      show_diff(state.current_idx)
    end
  end, vim.tbl_extend("force", opts, { desc = "Show diff for selected file" }))

  vim.keymap.set("n", "<Left>", function()
    local cursor = vim.api.nvim_win_get_cursor(state.panel_win)
    if cursor and cursor[1] then
      state.current_idx = cursor[1]
      show_diff(state.current_idx)
    end
  end, vim.tbl_extend("force", opts, { desc = "Show diff (select entry)" }))

  vim.keymap.set("n", "<Right>", function()
    local cursor = vim.api.nvim_win_get_cursor(state.panel_win)
    if cursor and cursor[1] then
      state.current_idx = cursor[1]
      show_diff(state.current_idx)
    end
  end, vim.tbl_extend("force", opts, { desc = "Show diff (select entry)" }))

  -- ── Cursor navigation (j/k keep panel focus) ───────────────────────────

  vim.keymap.set("n", "j", "j", vim.tbl_extend("force", opts, { desc = "Down" }))
  vim.keymap.set("n", "k", "k", vim.tbl_extend("force", opts, { desc = "Up" }))

  -- ── Apply ───────────────────────────────────────────────────────────────

  vim.keymap.set("n", "a", function()
    local file = state.files[state.current_idx]
    if not file then
      return
    end
    vim.notify("chezmoi apply: " .. file.path, vim.log.levels.INFO,
      { title = "chezmoi merge" })

    local ok, err = pcall(function()
      require("chezmoi.commands").apply({ targets = { file.target } })
    end)
    if not ok then
      vim.notify("Apply failed: " .. tostring(err), vim.log.levels.ERROR,
        { title = "chezmoi merge" })
      return
    end

    -- Remove from list
    table.remove(state.files, state.current_idx)
    if state.current_idx > #state.files then
      state.current_idx = #state.files
    end

    if #state.files == 0 then
      vim.notify("All files applied!", vim.log.levels.INFO,
        { title = "chezmoi merge" })
      M.close()
      return
    end

    refresh_panel()
    if state.current_idx > 0 then
      show_diff(state.current_idx)
    end
  end, vim.tbl_extend("force", opts, { desc = "Apply selected file" }))

  vim.keymap.set("n", "A", function()
    local count = #state.files
    if count == 0 then
      return
    end

    -- Build target list
    local targets = {}
    for _, f in ipairs(state.files) do
      table.insert(targets, f.target)
    end

    vim.notify("Applying all " .. count .. " files...", vim.log.levels.INFO,
      { title = "chezmoi merge" })

    local ok, err = pcall(function()
      require("chezmoi.commands").apply({ targets = targets })
    end)
    if not ok then
      vim.notify("Apply all failed: " .. tostring(err), vim.log.levels.ERROR,
        { title = "chezmoi merge" })
      return
    end

    vim.notify("All " .. count .. " files applied!", vim.log.levels.INFO,
      { title = "chezmoi merge" })
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Apply all files" }))

  -- ── Close ───────────────────────────────────────────────────────────────

  vim.keymap.set("n", "q", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close chezmoi merge" }))

  -- ── Refresh ─────────────────────────────────────────────────────────────

  vim.keymap.set("n", "R", function()
    M.close()
    M.open()
  end, vim.tbl_extend("force", opts, { desc = "Refresh file list" }))
end

-- ============================================================================
-- UI: Layout Creation
-- ============================================================================

--- Create the full merge tab layout:
--- ┌──────────────────┬─────────────────────────────────────┐
--- │  FILE PANEL      │  DIFF WINDOW A  │ DIFF WINDOW B    │
--- │  (30 cols)       │  (Destination)  │ (Rendered Source) │
--- └──────────────────┴─────────────────────────────────────┘
local function create_layout(files)
  -- New tab
  vim.cmd("tabnew")
  state.tab = vim.api.nvim_get_current_tabpage()

  -- Set a readable tab label
  vim.api.nvim_tabpage_set_var(state.tab, "tab_label", " chezmoi merge")

  -- ── File panel ─────────────────────────────────────────────────────────

  state.panel_buf = create_panel_buffer(files)
  state.panel_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.panel_win, state.panel_buf)

  -- Set panel width: ~30 columns or 1/4 of available width
  local panel_width = math.min(35, math.floor(vim.o.columns / 4))
  vim.api.nvim_win_set_width(state.panel_win, panel_width)

  -- ── Diff windows ───────────────────────────────────────────────────────

  -- Create first diff window (destination / left)
  vim.cmd("belowright vsplit")
  state.diff_win_a = vim.api.nvim_get_current_win()

  -- Create second diff window (rendered source / right)
  vim.cmd("belowright vsplit")
  state.diff_win_b = vim.api.nvim_get_current_win()

  -- All three windows should have equal remaining width

  -- ── Keymaps ────────────────────────────────────────────────────────────

  setup_keymaps(state.panel_buf)

  -- ── Return focus to panel ──────────────────────────────────────────────

  vim.api.nvim_set_current_win(state.panel_win)

  -- ── Show first file ────────────────────────────────────────────────────

  if #files > 0 then
    state.current_idx = 1
    show_diff(1)
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Open the chezmoi merge review tab.
---
--- 1. Runs `chezmoi status` to discover files with pending changes
--- 2. Parses the output into structured entries
--- 3. Creates a new tab with file panel + diff view
--- 4. Shows the first file's diff
---
--- If no changes are detected, shows a notification instead of opening a tab.
--- If a merge tab is already open, focuses it instead of creating a new one.
function M.open()
  -- Check if already open
  if state.tab and vim.api.nvim_tabpage_is_valid(state.tab) then
    vim.api.nvim_set_current_tabpage(state.tab)
    vim.notify("Chezmoi merge is already open",
      vim.log.levels.WARN,
      { title = "chezmoi merge" })
    return
  end

  -- Discover changed files
  local raw_status = get_status()
  local files = parse_status(raw_status)

  if #files == 0 then
    vim.notify("No chezmoi changes to review",
      vim.log.levels.INFO,
      { title = "chezmoi merge" })
    return
  end

  -- Build fresh state
  reset_state()
  state.files = files

  -- Create the UI
  create_layout(files)

  -- Refresh lualine tabline if available (matches diffview pattern)
  vim.schedule(function()
    pcall(require("lualine").refresh, { place = "tabline" })
  end)

  -- User guidance
  local hints = #files .. " file(s) — "
    .. "<Tab>/<S-Tab> navigate  "
    .. "a apply  "
    .. "A apply all  "
    .. "q close"
  vim.notify(hints, vim.log.levels.INFO, { title = "chezmoi merge" })
end

--- Close the merge tab and clean up state.
function M.close()
  -- Don't close if state is already gone
  if not state.tab or not vim.api.nvim_tabpage_is_valid(state.tab) then
    reset_state()
    return
  end

  -- If we're on the merge tab, switch to another tab first
  local current = vim.api.nvim_get_current_tabpage()
  if current == state.tab then
    local tabs = vim.api.nvim_list_tabpages()
    for _, t in ipairs(tabs) do
      if t ~= state.tab then
        pcall(vim.api.nvim_set_current_tabpage, t)
        break
      end
    end
  end

  -- Close the tab (this also cleans up its windows/buffers)
  pcall(function()
    vim.api.nvim_set_current_tabpage(state.tab)
    vim.cmd("tabclose")
  end)

  -- Clean up state
  reset_state()

  -- Refresh lualine
  vim.schedule(function()
    pcall(require("lualine").refresh, { place = "tabline" })
  end)
end

return M
