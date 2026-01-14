return {
  'christoomey/vim-tmux-navigator',
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    'TmuxNavigatePrevious',
    'TmuxNavigatorProcessList',
  },
  keys = {
    { '<a-h>', '<cmd>TmuxNavigateLeft<cr>' },
    { '<a-j>', '<cmd>TmuxNavigateDown<cr>' },
    { '<a-k>', '<cmd>TmuxNavigateUp<cr>' },
    { '<a-l>', '<cmd>TmuxNavigateRight<cr>' },
  },
}
