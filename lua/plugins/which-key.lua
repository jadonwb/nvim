-- which-key: the popup that shows what a prefix can do.
--
-- Layout follows LazyVim: a bordered popup anchored at the bottom-left, groups
-- on the left and the expanded group beside it, keys right-aligned. The groups
-- mirror the leader groups this config actually defines (see the cheatsheet for
-- the flat list).

return {
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      delay = 200,
      expand = 1,
      preset = 'classic',
      show_help = false,
      show_keys = false,
      win = {
        width = { min = 24, max = 72 },
        height = { min = 4, max = 0.6 },
        border = 'single',
        padding = { 0, 1 },
        col = 0,
        row = -1,
        wo = { winblend = 0 },
      },
      layout = {
        width = { min = 24 },
        spacing = 3,
        align = 'left',
      },
      icons = { mappings = true },
      spec = {
        { '<leader>,', desc = 'Notifications', icon = '' },

        { '<leader>a', group = 'opencode', icon = '' },
        { '<leader>b', group = 'buffers', icon = '' },
        { '<leader>c', group = 'code', icon = '' },
        { '<leader>d', group = 'diffview', icon = '' },
        { '<leader>f', group = 'find', icon = '' },
        { '<leader>g', group = 'git', icon = '' },
        { '<leader>q', group = 'quit / session', icon = '' },
        { '<leader>s', group = 'search', icon = '' },
        { '<leader>u', group = 'ui', icon = '' },
        { '<leader>w', group = 'windows', icon = '' },
        { '<leader>x', group = 'diagnostics', icon = '' },
        { '<leader>?', desc = 'Cheatsheet', icon = '' },

        { '<Tab>', group = 'tabs', icon = '' },
      },
    },
  },
}
