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
        TODO = { icon = '', color = 'todo' },
        FIXME = { icon = '', color = 'fixme', alt = { 'FIX', 'BUG', 'ISSUE' } },
        WARN = { icon = '', color = 'warning', alt = { 'WARNING', 'XXX', 'HACK' } },
        PERF = { icon = '󱎫', color = 'perf', alt = { 'OPTIM', 'PERFORMANCE', 'OPTIMIZE' } },
        TEST = { icon = '', color = 'test', alt = { 'TESTING', 'DEBUG', 'PASSED', 'FAILED' } },
        NOTE = { icon = '', color = 'note', alt = { 'INFO', 'HINT' } },
      },
      colors = {
        todo = { 'ArrowlakeCommentTodo' },
        fixme = { 'ArrowlakeCommentFixme' },
        note = { 'ArrowlakeCommentNote' },
        warning = { 'ArrowlakeCommentWarn' },
        perf = { 'ArrowlakeCommentPerf' },
        test = { 'ArrowlakeCommentTest' },
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
