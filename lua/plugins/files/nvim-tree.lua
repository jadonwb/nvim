-- nvim-tree: the file tree in the left slot.
--
-- The slot owns the window: the provider opens the tree *into* it
-- (`api.tree.open({ winid })`), so nvim-tree never creates or resizes a split.
-- Opening a file always targets the tracked content window, never the tree.
return {
  'nvim-tree/nvim-tree.lua',
  cmd = { 'NvimTreeOpen', 'NvimTreeFindFile' },
  dependencies = { 'nvim-mini/mini.icons' },
  cond = function()
    return require('config.profile').wants 'picker'
  end,
  opts = function()
    -- mini.icons is the single icon source; it stands in for devicons.
    require('mini.icons').mock_nvim_web_devicons()

    local function on_attach(buf)
      local api = require 'nvim-tree.api'
      api.config.mappings.default_on_attach(buf)

      local function map(lhs, fn, desc)
        vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, silent = true, desc = 'Tree: ' .. desc })
      end

      -- Files open in the content window; folders expand in place.
      local function open()
        local node = api.tree.get_node_under_cursor()
        if not node then
          return
        end
        if node.type == 'directory' or node.nodes then
          api.node.open.edit()
        elseif node.absolute_path then
          NVSlots.open_file(node.absolute_path)
        end
      end
      map('<CR>', open, 'Open')
      map('o', open, 'Open')
      map('l', open, 'Open')
      map('<2-LeftMouse>', open, 'Open')
      map('h', api.node.navigate.parent_close, 'Close folder')
      map('P', function()
        require('features.preview').toggle()
      end, 'Toggle preview')
      map('f', api.live_filter.start, 'Filter')
      map('F', api.live_filter.clear, 'Clear filter')
      -- Delete asks in the same button dialog as the unsaved-changes review.
      -- nvim-tree's own confirmation is a y/N text input (vim.ui.input); turn
      -- it off for this one call so it does not ask twice. Other entry points
      -- (the <cmd>s, a visual selection) keep nvim-tree's prompt.
      map('d', function()
        local node = api.tree.get_node_under_cursor()
        if not node then
          return
        end
        NVDialogs.select({
          title = ('Remove %s?'):format(node.name),
          message = vim.fn.fnamemodify(node.absolute_path, ':~:.'),
          options = { 'Remove', 'Cancel' },
          shortcuts = { y = 'Remove', n = 'Cancel' },
          initial_index = 2,
          min_width = 40,
        }, function(choice)
          if choice ~= 'Remove' then
            return
          end
          local confirm = require('nvim-tree.config').g.ui.confirm
          local was = confirm.remove
          confirm.remove = false
          local ok, err = pcall(api.fs.remove, node)
          confirm.remove = was
          if not ok then
            NVMessages.error('Delete failed: ' .. tostring(err))
          end
        end)
      end, 'Delete')
      -- Splits and tabs from the tree would break the grid.
      for _, lhs in ipairs { '<C-v>', '<C-x>', '<C-t>', 'O', '<Tab>' } do
        pcall(vim.keymap.del, 'n', lhs, { buffer = buf })
      end
      -- Window navigation stays global.
      for _, lhs in ipairs { '<C-k>', '<C-]>' } do
        pcall(vim.keymap.del, 'n', lhs, { buffer = buf })
      end

      vim.api.nvim_create_autocmd('CursorMoved', {
        buffer = buf,
        callback = function()
          require('features.preview').from_cursor()
        end,
      })
    end

    return {
      on_attach = on_attach,
      hijack_cursor = true,
      hijack_netrw = true,
      disable_netrw = false,
      hijack_unnamed_buffer_when_opening = false,
      sync_root_with_cwd = true,
      respect_buf_cwd = false,
      update_focused_file = { enable = true, update_root = { enable = false } },
      view = {
        preserve_window_proportions = true,
        signcolumn = 'no',
        width = 30,
      },
      renderer = {
        root_folder_label = false,
        highlight_git = 'name',
        highlight_opened_files = 'name',
        highlight_modified = 'icon',
        indent_markers = { enable = true },
        icons = {
          git_placement = 'after',
          modified_placement = 'after',
          glyphs = {
            folder = { arrow_closed = '\u{f0142}', arrow_open = '\u{f0140}' },
            git = {
              unstaged = '●',
              staged = '✓',
              unmerged = '\u{f062c}',
              renamed = '➜',
              untracked = '★',
              deleted = '\u{f01b4}',
              ignored = '◌',
            },
          },
        },
      },
      filters = { git_ignored = false, custom = { '^.git$' } },
      git = { enable = true, timeout = 400 },
      diagnostics = { enable = true, show_on_dirs = true },
      modified = { enable = true },
      actions = {
        open_file = { window_picker = { enable = false }, resize_window = false },
        change_dir = { enable = false },
      },
      live_filter = { prefix = '  ', always_show_folders = false },
      tab = { sync = { open = false, close = false } },
    }
  end,
}
