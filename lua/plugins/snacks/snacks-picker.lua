NVSPickers = {}
NVFffPicker = {}

-- TODO: configure just preview width
NVSPickerVerticalLayout = {
  width = NVScreen.is_large() and 0.35 or 0.4,
  height = 0.68,
  border = NVBorders.none,
  backdrop = true,
}

NVSPickerHorizontalLayout = {
  width = NVScreen.is_large() and 0.75 or 0.85,
  height = 0.85,
  border = NVBorders.none,
  backdrop = true,
}

function NVSPickerVerticalLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, NVSPickerVerticalLayout)
  return {
    layout = {
      box = 'vertical',
      width = config.width,
      height = config.height,
      border = config.border,
      backdrop = config.backdrop,
      { win = 'input', height = 1, title = '{title} {live}', title_pos = 'center', border = NVBorders.padded },
      { win = 'list', border = NVBorders.list },
      { win = 'preview', title = '{preview}', border = NVBorders.top_hr },
    },
  }
end

function NVSPickerHorizontalLayout.build(opts)
  local config = vim.tbl_extend('keep', opts or {}, NVSPickerHorizontalLayout)
  return {
    layout = {
      box = 'horizontal',
      width = config.width,
      height = config.height,
      border = config.border,
      backdrop = config.backdrop,
      {
        box = 'vertical',
        { win = 'input', height = 1, title = '{title} {live}', title_pos = 'center', border = NVBorders.bottom_hr },
        { win = 'list', border = NVBorders.top_none },
      },
      { win = 'preview', title = '{preview}', width = 0.6, border = NVBorders.preview },
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

-- FIXME: still showing current buffer after refresh
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
    layout = NVSPickerVerticalLayout.build(),
  }
end

local function fff_defaults(overrides)
  return vim.tbl_extend('keep', overrides or {}, {
    live = true,
    supports_live = true,
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
      -- TODO: staged vs added?
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
    -- Compute pos and positions from match_ranges for preview highlighting.
    -- fff match_ranges are {start_byte, end_byte} pairs (0-based, end exclusive).
    -- snacks preview loc() prefers item.positions (one extmark per char) over
    -- item.end_pos (single contiguous span), positions correctly highlights
    -- only matched chars when there are multiple matches on one line.
    local pos = { match.line_number, match.col or 0 }
    local positions = nil
    if #match.match_ranges > 0 then
      pos = { match.line_number, match.match_ranges[1][1] }
      positions = {}
      for _, range in ipairs(match.match_ranges) do
        for byte = range[1], range[2] - 1 do
          positions[#positions + 1] = byte + 1 -- 0-based byte → 1-based col
        end
      end
    end
    local col1 = pos[2] + 1 -- 1-based
    items[#items + 1] = {
      text = string.format('%s:%d:%d: %s', match.relative_path, match.line_number, col1, vim.trim(match.line_content or '')),
      file = abs,
      pos = pos,
      positions = positions,
      _fff = { match = match },
    }
  end
  return items
end

---@param opts table
---@param ctx snacks.picker.finder.ctx
function NVFffPicker.files_finder(opts, ctx)
  return files_to_items(ctx.filter.search or '')
end

---@param opts table
---@param ctx snacks.picker.finder.ctx
function NVFffPicker.grep_finder(opts, ctx)
  return grep_to_items(ctx.filter.search or '')
end

function NVFffPicker.find_files()
  Snacks.picker(fff_defaults { title = 'Find Files (fff)', finder = NVFffPicker.files_finder })
end

function NVFffPicker.live_grep()
  Snacks.picker(fff_defaults { title = 'Live Grep (fff)', finder = NVFffPicker.grep_finder })
end

function NVFffPicker.live_grep_word()
  local word
  local mode = vim.api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local ok, region = pcall(vim.fn.getregion, vim.fn.getpos 'v', vim.fn.getpos '.', { type = mode })
    if ok and #region > 0 then
      -- FIXME: I think grep might be able to take newlines?
      word = table.concat(region, ' ') -- replace newlines with spaces for grep
    end
  end
  if not word or word == '' then
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

function NVFffPicker.resume()
  -- TODO: improve?
  Snacks.picker.resume()
end

return {
  {
    'folke/snacks.nvim',
    opts = {
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
          git = NVIcons.git,
        },
        layout = { cycle = false },
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
          select = {
            layout = {
              box = 'vertical',
              backdrop = true,
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
              backdrop = true,
              row = 1,
              width = 0.4,
              min_width = 80,
              height = 0.4,
              border = NVBorders.none,
              box = 'vertical',
              { win = 'input', height = 1, border = NVBorders.bottom_hr, title = '{title} {live} {flags}', title_pos = 'center' },
              { win = 'list', border = NVBorders.top_none },
              { win = 'preview', title = '{preview}', border = NVBorders.padded },
            },
          },
        },
      },
    },
    keys = {
      {
        '<leader><space>',
        NVSPickers.buffers,
        desc = 'Buffers',
      },
      {
        '<leader>sH',
        NVSPickers.highlights,
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
