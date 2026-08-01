-- TODO: make per buffer keymaps, xT for buffer todo
local function picker_list(types)
  require('trouble').open {
    mode = 'todo',
    focus = true,
    filter = { tag = types },
    win = { position = 'top', size = 0.3 },
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
      -- Disable LazyVim's picker todo keymaps
      { '<leader>st', false },
      { '<leader>sT', false },

      -- Disable LazyVim's trouble todo keys (replaced by ours)
      { '<leader>xt', false },
      { '<leader>xT', false },

      {
        '<leader>xtt',
        function()
          picker_list { 'TODO' }
        end,
        desc = 'All TODOs (Trouble)',
      },
      {
        '<leader>xtf',
        function()
          picker_list { 'FIXME' }
        end,
        desc = 'All FIXMEs (Trouble)',
      },
    },
  },
}
