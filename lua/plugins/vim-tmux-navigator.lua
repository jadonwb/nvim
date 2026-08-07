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
    { NVKeymaps.window_move.left, '<cmd>TmuxNavigateLeft<cr>', mode = { 'n', 'i', 'v', 't' } },
    { NVKeymaps.window_move.down, '<cmd>TmuxNavigateDown<cr>', mode = { 'n', 'i', 'v', 't' } },
    { NVKeymaps.window_move.up, '<cmd>TmuxNavigateUp<cr>', mode = { 'n', 'i', 'v', 't' } },
    { NVKeymaps.window_move.right, '<cmd>TmuxNavigateRight<cr>', mode = { 'n', 'i', 'v', 't' } },
  },
}
