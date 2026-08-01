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
  },
}
