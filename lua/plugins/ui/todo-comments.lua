NVTodoComments = {
  'folke/todo-comments.nvim',

  -- Highlighting is part of the first screen: loaded with the dashboard
  -- (VimEnter), not on first use of a todo command. Pickers: <leader>st /
  -- <leader>sT (snacks).
  event = 'VimEnter',
  cmd = { 'TodoQuickFix' },
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
}

return { NVTodoComments }
