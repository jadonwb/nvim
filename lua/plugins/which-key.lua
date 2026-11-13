-- which-key: the popup that shows what a prefix can do.
--
-- A bordered popup anchored at the bottom-left. The leader groups mirror the
-- ones this config defines (features/layout/keymaps.lua and the plugin
-- specs); the cheatsheet (<leader>?) shows the flat list.

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
        -- Wide enough that a long group (e.g. <C-w>) splits into columns.
        width = { min = 24, max = 0.9 },
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
        { '<leader>,', desc = 'Notifications', icon = '󰂚' },
        { '<leader>?', desc = 'Cheatsheet', icon = '󰓫' },

        { '<leader>a', group = 'opencode', icon = '󰚩' },
        { '<leader>c', group = 'code', icon = '󰅩' },
        { '<leader>f', group = 'find', icon = '󰍉' },
        { '<leader>g', group = 'git', icon = '󰊢' },
        { '<leader>l', group = 'layout / panels', icon = '󰕰' },
        { '<leader>p', group = 'plugins', icon = '󰏗' },
        { '<leader>s', group = 'search', icon = '󰍉' },
        { '<leader>t', group = 'terminals', icon = '\u{f018d}' },
        { '<leader>u', group = 'ui toggles', icon = '󰙵' },
        { '<leader>v', group = 'views (dashboards)', icon = '󰕮' },
        { '<M-y>', group = 'yank path', icon = '󰆏' },

        -- Text objects (mini.ai + treesitter, plugins/mini.lua) after a / i
        -- in operator-pending and visual mode: `via`, `daf`, `ci=`, …
        (function()
          local objects = {
            { 'f', 'function' },
            { 'c', 'class' },
            { 'o', 'block / conditional / loop' },
            { 'L', 'loop' },
            { '=', 'assignment' },
            { 'C', 'comment' },
            { 'a', 'argument' },
            { 'g', 'entire buffer' },
            { 'u', 'function call' },
            { 'U', 'call (no dot)' },
            { 't', 'tag' },
            { 'd', 'digits' },
            { 'e', 'word part (camel/snake)' },
            { 'q', 'quote `"\'' },
            { 'b', 'bracket )]}' },
            { '?', 'user prompt' },
            { '(', '( )' },
            { '[', '[ ]' },
            { '{', '{ }' },
            { '<', '< >' },
            { '"', '" "' },
            { "'", "' '" },
            { '`', '` `' },
          }
          local spec = { mode = { 'o', 'x' } }
          for _, prefix in ipairs {
            { 'a', 'around' },
            { 'i', 'inside' },
            { 'al', 'around last' },
            { 'il', 'inside last' },
            { 'aN', 'around next' },
            { 'iN', 'inside next' },
          } do
            spec[#spec + 1] = { prefix[1], group = prefix[2] }
            for _, o in ipairs(objects) do
              spec[#spec + 1] = { prefix[1] .. o[1], desc = o[2] }
            end
          end
          return spec
        end)(),

        -- Built-in window commands which-key has no description for.
        { '<C-w>c', desc = 'Close window' },
        { '<C-w>p', desc = 'Previous (last accessed) window' },
        { '<C-w>W', desc = 'Previous window (cycle)' },
        { '<C-w>r', desc = 'Rotate windows down/right' },
        { '<C-w>R', desc = 'Rotate windows up/left' },
        { '<C-w>n', desc = 'New window' },
        { '<C-w>t', desc = 'Go to top-left window' },
        { '<C-w>b', desc = 'Go to bottom-right window' },
        { '<C-w>z', desc = 'Close preview window' },
        { '<C-w>P', desc = 'Go to preview window' },
        { '<C-w>^', desc = 'Split with alternate file' },
        { '<C-w>f', desc = 'Split: file under cursor' },
        { '<C-w>gf', desc = 'Tab: file under cursor' },
        { '<C-w>]', desc = 'Split: tag under cursor' },
        { '<C-w>|', desc = 'Maximise width' },
        { '<C-w>_', desc = 'Maximise height' },
      },
    },
  },
}
