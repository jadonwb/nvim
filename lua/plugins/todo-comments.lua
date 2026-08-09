local Picker = {}

NVTodoComments = {
  'folke/todo-comments.nvim',

  keys = function()
    return {
      {
        '<leader>xt',
        function()
          Picker.list { 'TODO', 'FIXME' }
        end,
        mode = 'n',
        desc = 'Show TODOs',
      },
    }
  end,
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

---@param types ("TODO" | "FIXME" )[]
function Picker.list(types)
  local trouble = require 'trouble'

  trouble.open {
    mode = 'todo',
    focus = true,
    filter = { tag = types },
    win = { position = 'top', size = 0.4 },
    groups = {
      { 'directory' },
      { 'filename', format = '{file_icon} {basename} {count}' },
    },
  }
end

return { NVTodoComments }
