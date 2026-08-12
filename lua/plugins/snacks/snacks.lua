NVSPickers = {}
NVSZoom = {}
NVSNotifier = {}
NVSInput = {}

NVSPickerVerticalLayout = {
  large_screen_width = 0.35,
  small_screen_width = 0.4,
}

NVSPickerHorizontalLayout = {
  large_screen_width = 0.75,
  small_screen_width = 0.95,
}

function NVSPickerVerticalLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, {
    width = NVScreen.is_large() and NVSPickerVerticalLayout.large_screen_width or NVSPickerVerticalLayout.small_screen_width,
    height = 0.7,
  })
  return {
    layout = {
      box = 'vertical',
      width = config.width,
      height = config.height,
      border = NVBorders.none,
      backdrop = false,
      { win = 'input', height = 1, title = '{title} {live}', title_pos = 'center', border = NVBorders.padded },
      { win = 'list', border = NVBorders.list },
      { win = 'preview', title = '{preview}', border = NVBorders.top_hr },
    },
  }
end

function NVSPickerHorizontalLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, {
    width = NVScreen.is_large() and NVSPickerHorizontalLayout.large_screen_width or NVSPickerHorizontalLayout.small_screen_width,
    height = 0.9,
  })
  return {
    layout = {
      box = 'horizontal',
      width = config.width,
      height = config.height,
      backdrop = false,
      {
        box = 'vertical',
        { win = 'input', height = 1, title = '{title} {live}', title_pos = 'center', border = NVBorders.padded },
        { win = 'list', border = NVBorders.top_none },
      },
      { win = 'preview', title = '{preview}', border = NVBorders.preview },
    },
  }
end

NVSPickers.keys = {
  ['<M-f>'] = { 'toggle_maximize', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.open_vsplit] = { 'edit_vsplit', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.open_hsplit] = { 'edit_split', mode = { 'n', 'i', 'v' } },
  ['<C-w>'] = { 'cycle_win', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll.up] = { 'list_scroll_up', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll.down] = { 'list_scroll_down', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_alt.up] = { 'x_list_scroll_up_bit', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_alt.down] = { 'x_list_scroll_down_bit', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_ctx.up] = { 'preview_scroll_up', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.scroll_ctx.down] = { 'preview_scroll_down', mode = { 'n', 'i', 'v' } },
  -- ['<C-S-l>'] = { 'focus_list', mode = { 'n', 'i', 'v' } },
  -- ['<C-S-p>'] = { 'focus_preview', mode = { 'n', 'i', 'v' } },
  ['<C-S-p>'] = { 'toggle_preview', mode = { 'n', 'i', 'v' } },
  ['<C-S-c>'] = { 'x_copy_absolute_path', mode = { 'n', 'i', 'v' } },
  ['<C-S-r>'] = { 'x_copy_relative_path', mode = { 'n', 'i', 'v' } },
  ['<C-S-f>'] = { 'x_copy_filename', mode = { 'n', 'i', 'v' } },
  ['<C-S-s>'] = { 'x_copy_filestem', mode = { 'n', 'i', 'v' } },
  [NVKeymaps.close] = { 'close', mode = { 'n', 'i', 'v' } },
}

NVSPickers.actions = {
  x_list_scroll_up_bit = function(picker)
    picker.list:scroll(-2)
  end,
  x_list_scroll_down_bit = function(picker)
    picker.list:scroll(2)
  end,
  x_copy_absolute_path = function(_, item)
    NVSPickers.copy_path(item, 'absolute')
  end,
  x_copy_relative_path = function(_, item)
    NVSPickers.copy_path(item, 'relative')
  end,
  x_copy_filename = function(_, item)
    NVSPickers.copy_path(item, 'filename')
  end,
  x_copy_filestem = function(_, item)
    NVSPickers.copy_path(item, 'filestem')
  end,
  bufdelete = function(picker)
    NVSPickers.bufdelete(picker)
  end,
}

function NVSPickers.bufdelete(picker)
  picker.preview:reset()
  for _, item in ipairs(picker:selected { fallback = true }) do
    if item.buf then
      local win = vim.fn.bufwinid(item.buf)
      if win ~= -1 then
        NVBuffers.delete_buf(item.buf, win)
      else
        vim.api.nvim_buf_delete(item.buf, { force = true })
      end
    end
  end
  pcall(picker.refresh, picker)
end

function NVSPickers.copy_path(item, fmt)
  if item == nil then
    vim.notify('No item selected', vim.log.levels.INFO)
    return
  end
  local result = NVFS.format(item.file, fmt)
  if result ~= nil then
    NVClipboard.yank(result)
    vim.notify('Copied: ' .. result, vim.log.levels.INFO)
  end
end

function NVSPickers.files()
  Snacks.picker.files {
    show_empty = true,
    hidden = true,
    ignored = false,
    follow = false,
    supports_live = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.buffers()
  Snacks.picker.buffers {
    hidden = true,
    unloaded = true,
    current = false,
    sort_lastused = true,
    layout = NVSPickerVerticalLayout.build(),
    filter = {
      -- FIXME: filter out or don't show files in my picker from other neovim instances? keep seeing weird issues where other neovim files are showing up in my buffer picker, from different neovim sessions altogether
      filter = function(item, _)
        local file = item.file or ''
        if file:find '^diffview://' then
          return false
        end
        if file:find '^term://' then
          return false
        end
        if file:find '^oil://' then
          return false
        end
        if NVLayoutManager.is_sidepad_buf(item.buf) then
          return false
        end
        if file == '[Scratch]' or file == '' then
          return false
        end
        return true
      end,
    },
    win = {
      input = {
        keys = {
          ['<BS>'] = { 'bufdelete', mode = { 'n' } },
        },
      },
      list = {
        keys = {
          ['dd'] = 'bufdelete',
        },
      },
    },
  }
end

function NVSPickers.text_search()
  Snacks.picker.grep {
    hidden = true,
    ignored = false,
    regex = false,
    layout = NVSPickerHorizontalLayout.build(),
  }
end

function NVSPickers.git_branches()
  Snacks.picker.git_branches {
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.lsp_document_symbols()
  Snacks.picker.lsp_symbols {
    layout = NVSPickerVerticalLayout.build {
      width = NVScreen.is_large() and 0.5 or 0.8,
      height = 0.9,
    },
  }
end

function NVSPickers.lsp_workspace_symbols()
  Snacks.picker.lsp_workspace_symbols {
    layout = NVSPickerVerticalLayout.build {
      width = NVScreen.is_large() and 0.5 or 0.8,
      height = 0.9,
    },
  }
end

function NVSPickers.lsp_references()
  Snacks.picker.lsp_references {
    auto_confirm = false,
    layout = NVSPickerHorizontalLayout.build(),
  }
end

function NVSPickers.lsp_implementations()
  Snacks.picker.lsp_implementations {
    auto_confirm = false,
    layout = NVSPickerHorizontalLayout.build(),
  }
end

function NVSPickers.lsp_definitions()
  Snacks.picker.lsp_definitions {
    auto_confirm = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.lsp_type_definitions()
  Snacks.picker.lsp_type_definitions {
    auto_confirm = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.lsp_declarations()
  Snacks.picker.lsp_declarations {
    auto_confirm = true,
    layout = NVSPickerVerticalLayout.build(),
  }
end

function NVSPickers.highlights()
  Snacks.picker.highlights {
    layout = NVSPickerHorizontalLayout.build(),
  }
end

-- =============================================================================
-- FFF-backed Snacks Pickers
-- Uses fff's headless file_search() / content_search() API for frecency-ranked
-- search, rendered through snacks' unified picker UI.
-- =============================================================================
NVFffPicker = {}

-- Helper: merge per-call options with shared defaults.
-- Uses vim.tbl_extend('keep', ...) so call-site overrides take priority.
local function fff_defaults(overrides)
  return vim.tbl_extend('keep', overrides or {}, {
    live = true, -- fff re-searches on every keystroke (sub-10ms)
    supports_live = true, -- tell snacks the finder supports live refresh
    -- matcher is a passthrough when live=true (filter.pattern stays "", all items
    -- get score 1000, topk heap is bypassed). fff results are displayed as-is.
    confirm = 'jump',
    preview = 'file',
    layout = NVSPickerHorizontalLayout.build(),
    win = {
      input = { keys = NVSPickers.keys },
      list = { keys = NVSPickers.keys },
      preview = { keys = NVSPickers.keys },
    },
  })
end

-- Map fff file_search results to snacks picker items.
-- Tradeoff: passing "" yields all files ranked by frecency, matching fff's
-- native "open picker shows recent files" behavior. Results capped at 100.
local function files_to_items(query)
  local results = require('fff').file_search(query, {
    mode = 'files',
    max_results = 100,
  })
  local items = {}
  for i, item in ipairs(results.items) do
    local abs = vim.fn.fnamemodify(item.relative_path, ':p')
    -- Map fff git_status to snacks' 2-char porcelain format for the built-in
    -- file formatter (format.lua:156 reads item.status and renders git icons).
    -- fff returns: clean, untracked, modified, deleted, renamed, staged_new,
    -- staged_modified, staged_deleted, ignored, unknown (fff-core/src/git.rs).
    -- Porcelain "xy": x = index (staged), y = worktree. 'clean'/'unknown' -> nil.
    local status = nil
    if item.git_status and item.git_status ~= '' and item.git_status ~= 'clean' and item.git_status ~= 'unknown' then
      local map = {
        untracked = '??',
        modified = ' M',
        deleted = ' D',
        renamed = ' R',
        staged_new = 'A ',
        staged_modified = 'M ',
        staged_deleted = 'D ',
        ignored = '!!',
      }
      status = map[item.git_status]
    end
    items[#items + 1] = {
      text = item.relative_path,
      file = abs,
      pos = { 1, 0 },
      status = status,
      idx = i,
      score = results.scores[i] and results.scores[i].total or 0,
      _fff = { item = item, score = results.scores[i] },
    }
  end
  return items
end

-- Map fff content_search results to snacks picker items.
-- Empty query returns nothing (unlike file search).
local function grep_to_items(query)
  if query == '' then
    return {}
  end
  local results = require('fff').content_search(query, {
    mode = 'plain',
    smart_case = true,
    page_size = 100,
  })
  local items = {}
  for _, match in ipairs(results.items) do
    local abs = vim.fn.fnamemodify(match.relative_path, ':p')
    -- Compute pos and end_pos from match_ranges for preview highlighting.
    -- fff match_ranges are {start_byte, end_byte} pairs (0-based, end exclusive).
    -- snacks preview loc() uses 0-based byte columns for BOTH pos and end_pos:
    --   pos = { 1-based_line, 0-based_start_col }
    --   end_pos = { 1-based_line, 0-based_exclusive_end_col }
    -- No +/-1 adjustment (rg columns are byte-based, and snacks never converts).
    local pos = { match.line_number, match.col or 0 }
    local end_pos = nil
    if #match.match_ranges > 0 then
      local first = match.match_ranges[1]
      local last = match.match_ranges[#match.match_ranges]
      pos = { match.line_number, first[1] }
      end_pos = { match.line_number, last[2] }
    end
    local col1 = pos[2] + 1 -- 1-based for human-friendly display in the list text
    items[#items + 1] = {
      text = string.format('%s:%d:%d: %s', match.relative_path, match.line_number, col1, vim.trim(match.line_content or '')),
      file = abs,
      pos = pos,
      end_pos = end_pos,
      _fff = { match = match },
    }
  end
  return items
end

--- Finder for fff-backed file search.
--- Called by snacks on every keystroke when live=true.
---@param opts table
---@param ctx snacks.picker.finder.ctx
function NVFffPicker.files_finder(opts, ctx)
  return files_to_items(ctx.filter.search or '')
end

--- Finder for fff-backed content grep.
---@param opts table
---@param ctx snacks.picker.finder.ctx
function NVFffPicker.grep_finder(opts, ctx)
  return grep_to_items(ctx.filter.search or '')
end

--- Open the fff-backed file finder via snacks picker.
--- Replaces the old NVFff.find_files() that used fff's native UI.
function NVFffPicker.find_files()
  Snacks.picker(fff_defaults { title = 'Find Files (fff)', finder = NVFffPicker.files_finder })
end

--- Open the fff-backed live grep via snacks picker.
function NVFffPicker.live_grep()
  Snacks.picker(fff_defaults { title = 'Live Grep (fff)', finder = NVFffPicker.grep_finder })
end

--- Open fff-backed grep pre-filled with the word under cursor or visual selection.
--- Matches the old NVFff.live_grep_under_cursor() behavior.
function NVFffPicker.live_grep_word()
  local word
  local mode = vim.api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local _, ls, cs = unpack(vim.fn.getpos "'<")
    local _, le, ce = unpack(vim.fn.getpos "'>")
    local lines = vim.fn.getline(ls, le)
    if #lines == 0 then
      return
    end
    lines[1] = string.sub(lines[1], cs)
    lines[#lines] = string.sub(lines[#lines], 1, ce)
    word = table.concat(lines, ' ') -- replace newlines with spaces for grep
  else
    word = vim.fn.expand '<cword>'
  end
  if not word or word == '' then
    return
  end
  Snacks.picker(fff_defaults {
    title = 'Grep Word (fff)',
    finder = NVFffPicker.grep_finder,
    search = word, -- pre-fill the input with the word/selection
  })
end

--- Resume the last snacks picker.
--- Tradeoff: snacks.picker.resume() resumes ANY last picker, not just fff ones.
--- This is arguably better UX — it restores whatever you were last doing.
function NVFffPicker.resume()
  Snacks.picker.resume()
end

-- Zoom
function NVSZoom.activate()
  Snacks.zen.zoom()
end

function NVSZoom.ensure_deactivated()
  local win = Snacks.zen.win
  if win then
    Snacks.zen.zoom()
    return true
  end
  return false
end

NVClose.register('snacks_zoom', function()
  return NVSZoom.ensure_deactivated()
end, 30)

-- Notifier
function NVSNotifier.log()
  Snacks.notifier.show_history()
end

function NVSNotifier.hide()
  Snacks.notifier.hide()
end

-- Input
function NVSInput.is_input(bufid)
  bufid = bufid or vim.api.nvim_get_current_buf()
  return vim.bo[bufid].filetype == 'snacks_input'
end

function NVSInput.ensure_hidden()
  if NVSInput.is_input() then
    vim.cmd.close()
    return true
  end
  return false
end

NVClose.register('snacks_input', function()
  return NVSInput.ensure_hidden()
end, 20)

return {
  {
    'folke/snacks.nvim',
    opts = {
      explorer = { enabled = false },
      scroll = { enabled = false },
      notifier = {
        enabled = true,
        timeout = 3000,
        level = vim.log.levels.DEBUG,
        date_format = '%T',
        filter = function(n)
          local tab_label = vim.t.tab_label
          if tab_label and tab_label.name and tab_label.name:find 'diff' then
            if string.find(n.msg, '^Client %S+ quit with exit code %d+ and signal %d+%.') or string.find(n.msg, '^%[null%-ls%] failed to run generator') then
              return false
            end
          end
          return true
        end,
      },
      indent = {
        indent = { enabled = false },
        scope = { only_current = true },
        chunk = { enabled = true, only_current = true, char = { corner_top = '╭', corner_bottom = '╰' } },
      },
      zen = {
        zoom = {
          show = { statusline = true, tabline = true },
          win = { width = 0, backdrop = false },
        },
      },
      picker = {
        prompt = '❯ ',
        ui_select = true,
        icons = {
          diagnostics = {
            Error = NVIcons.lsp.full.error,
            Warn = NVIcons.lsp.full.warn,
            Hint = NVIcons.lsp.full.hint,
            Info = NVIcons.lsp.full.info,
          },
        },
        layout = vim.tbl_extend('force', NVSPickerHorizontalLayout.build(), { cycle = false }),
        win = {
          input = { keys = NVSPickers.keys },
          list = { keys = NVSPickers.keys },
          preview = { keys = NVSPickers.keys },
        },
        actions = NVSPickers.actions,
        formatters = {
          file = { filename_first = true, truncate = 80 },
        },
        layouts = {
          default = {
            layout = NVSPickerHorizontalLayout.build(),
          },
          select = {
            layout = {
              box = 'vertical',
              backdrop = false,
              width = 0.5,
              height = 0.5,
              border = NVBorders.none,
              { win = 'input', height = 1, title = '{title}', title_pos = 'center', border = NVBorders.bottom_hr },
              { win = 'list', border = NVBorders.top_none },
            },
          },
          vscode = {
            hidden = { 'preview' },
            layout = {
              backdrop = false,
              row = 1,
              width = 0.4,
              min_width = 80,
              height = 0.4,
              border = 'none',
              box = 'vertical',
              { win = 'input', height = 1, border = NVBorders.bottom_hr, title = '{title} {live} {flags}', title_pos = 'center' },
              { win = 'list', border = NVBorders.top_none },
              { win = 'preview', title = '{preview}', border = NVBorders.padded },
            },
          },
        },
      },
      input = {
        win = { border = NVBorders.padded },
      },
      styles = {
        terminal = {
          wo = {
            winhighlight = 'Normal:Normal,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,WinSeparator:SnacksWinSeparator,FloatBorder:Border',
          },
        },
        float = { backdrop = false },
        notification = { border = NVBorders.padded },
        notification_history = {
          backdrop = false,
          border = NVBorders.padded,
          keys = { q = 'close', ['<Esc>'] = 'close' }, -- TODO: cleanup and use nvkeymaps, remove q?
        },
      },
    },
    keys = {
      { '<M-f>', NVSZoom.activate, mode = { 'n', 'i', 'v' }, desc = 'Maximize' },
      {
        '<leader><space>',
        function()
          NVSPickers.buffers()
        end,
        desc = 'Buffers',
      },
      {
        '<leader>sH',
        function()
          NVSPickers.highlights()
        end,
        desc = 'Search Highlights',
      },
      {
        '<leader>ff',
        NVFffPicker.find_files,
        desc = 'Find Files (fff)',
      },
      {
        '<leader>fs',
        NVFffPicker.live_grep,
        desc = 'Live Grep (fff)',
      },
      {
        '<leader>fw',
        NVFffPicker.live_grep_word,
        mode = { 'n', 'x' },
        desc = 'Grep Word (fff)',
      },
      {
        '<leader>fl',
        NVFffPicker.resume,
        desc = 'Resume Last Picker',
      },
    },
  },
}
