local function picker_list(types)
  local tags = vim.tbl_map(function(t)
    return t:gsub('!', '_NOW')
  end, types)
  require('trouble').open {
    mode = 'todo',
    focus = true,
    filter = { tag = tags },
    win = { position = 'top', size = 0.4 },
    groups = {
      { 'directory' },
      { 'filename', format = '{file_icon} {basename} {count}' },
    },
  }
end

return {
  {
    'folke/todo-comments.nvim',
    opts = {
      keywords = {
        -- TODO: fix these in arrowlake and make actual highlight groups, fix perf and hack too
        TODO = { icon = '󰬁 ', color = 'todo_normal' },
        TODO_NOW = { icon = '󰬁 ', color = 'todo_now', alt = { 'TODO!' } },
        FIXME = { icon = '󰫳 ', color = 'fixme_normal', alt = { 'FIX', 'BUG' } },
        FIXME_NOW = { icon = '󰫳 ', color = 'fixme_now', alt = { 'FIXME!' } },
        HACK = { icon = '󰫵 ', color = 'warning_normal' },
        WARN = { icon = '󰬄 ', color = 'warning_normal', alt = { 'WARNING', 'XXX' } },
        PERF = { icon = '󰫽 ', alt = { 'OPTIM', 'PERFORMANCE', 'OPTIMIZE' } },
        NOTE = { icon = '󰫻 ', color = 'note_normal', alt = { 'INFO' } },
      },
      colors = {
        todo_now = { 'DiagnosticWarn' },
        todo_normal = { 'DiagnosticInfo' },
        fixme_now = { 'DiagnosticError' },
        fixme_normal = { 'DiagnosticError' },
        note_normal = { 'DiagnosticHint' },
        warning_normal = { 'DiagnosticWarn' },
      },
      highlight = {
        pattern = [=[.*<((KEYWORDS)[!?]?(\([^)]*\)|\[[^)]*\])?)\s*:]=],
      },
      search = {
        pattern = [=[\b(KEYWORDS)[!?]?(\([^)]*\)|\[[^\]]*\])?:]=],
      },
      merge_keywords = false,
    },
    keys = {
      -- Disable LazyVim's telescope-based todo keymaps
      { '<leader>st', false },
      { '<leader>sT', false },

      -- Disable LazyVim's trouble todo keys (replaced by ours)
      { '<leader>xt', false },
      { '<leader>xT', false },

      {
        '<leader>xT',
        function()
          picker_list { 'TODO!', 'FIXME!' }
        end,
        desc = 'High Priority TODOs (Trouble)',
      },
      {
        '<leader>xt',
        function()
          picker_list { 'TODO!', 'TODO' }
        end,
        desc = 'All TODOs (Trouble)',
      },
      {
        '<leader>xf',
        function()
          picker_list { 'FIXME!', 'FIXME' }
        end,
        desc = 'All FIXMEs (Trouble)',
      },
    },
  },
}
