return {
  sections = {
    width = 117,
    {
      section = 'terminal',
      -- cmd = 'cat ~/.config/nvim/dashboard.cat | ~/.config/nvim/colors.sh',
      cmd = 'cat ~/.config/nvim/colored-dashboard.cat',
      indent = -27,
      align = 'center',
      height = 10,
      width = 117,
      padding = 1,
    },
    {
      align = 'center',
      padding = 1,
      text = {
        { '  Update ', hl = 'Label' },
        { '  Sessions ', hl = '@property' },
        { '  Previous Session ', hl = 'Number' },
        { '  Files ', hl = 'DiagnosticInfo' },
        { '  Recent ', hl = '@string' },
        { ' 󰊢 lazyGit ', hl = 'Function' },
        { ' 󰝒 New File ', hl = '@keyword' },
        { ' 󰍉 Grep ', hl = 'Special' },
      },
    },
    { section = 'startup', padding = 1 },
    { icon = '󰏓 ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
    { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
    { hidden = true, action = ':Lazy update', key = 'u' },
    { hidden = true, action = ':lua require("persistence").select()', key = 's' },
    { hidden = true, action = ':lua require("persistence").load({ last = true })', key = 'p' },
    { hidden = true, action = ':lua Snacks.dashboard.pick("files")', key = 'f' },
    { hidden = true, action = ':lua Snacks.dashboard.pick("oldfiles")', key = 'r' },
    { hidden = true, action = ':lua Snacks.lazygit.open()', key = 'G' },
    { hidden = true, action = ':ene | startinsert', key = 'n' },
    { hidden = true, action = ':lua Snacks.dashboard.pick("live_grep")', key = 'g' },
    { hidden = true, action = ':qa', key = 'q' },
    { hidden = true, action = ':Lazy', key = 'l' },
  },
}

--     header = [[
--     _____                __                   __               __    __                             __
--    |     \              |  \                 |  \             |  \  |  \                           |  \
--     \▓▓▓▓▓ ______   ____| ▓▓ ______  _______ | ▓▓ _______     | ▓▓\ | ▓▓ ______   ______  __     __ \▓▓______ ____
--       | ▓▓|      \ /      ▓▓/      \|       \ \▓ /       \    | ▓▓▓\| ▓▓/      \ /      \|  \   /  \  \      \    \
--  __   | ▓▓ \▓▓▓▓▓▓\  ▓▓▓▓▓▓▓  ▓▓▓▓▓▓\ ▓▓▓▓▓▓▓\  |  ▓▓▓▓▓▓▓    | ▓▓▓▓\ ▓▓  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\\▓▓\ /  ▓▓ ▓▓ ▓▓▓▓▓▓\▓▓▓▓\
-- |  \  | ▓▓/      ▓▓ ▓▓  | ▓▓ ▓▓  | ▓▓ ▓▓  | ▓▓   \▓▓    \     | ▓▓\▓▓ ▓▓ ▓▓    ▓▓ ▓▓  | ▓▓ \▓▓\  ▓▓| ▓▓ ▓▓ | ▓▓ | ▓▓
-- | ▓▓__| ▓▓  ▓▓▓▓▓▓▓ ▓▓__| ▓▓ ▓▓__/ ▓▓ ▓▓  | ▓▓   _\▓▓▓▓▓▓\    | ▓▓ \▓▓▓▓ ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓  \▓▓ ▓▓ | ▓▓ ▓▓ | ▓▓ | ▓▓
--  \▓▓    ▓▓\▓▓    ▓▓\▓▓    ▓▓\▓▓    ▓▓ ▓▓  | ▓▓  |       ▓▓    | ▓▓  \▓▓▓\▓▓     \\▓▓    ▓▓   \▓▓▓  | ▓▓ ▓▓ | ▓▓ | ▓▓
--   \▓▓▓▓▓▓  \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓ \▓▓▓▓▓▓ \▓▓   \▓▓   \▓▓▓▓▓▓▓      \▓▓   \▓▓ \▓▓▓▓▓▓▓ \▓▓▓▓▓▓     \▓    \▓▓\▓▓  \▓▓  \▓▓
--
--
--
--
--     ]],
