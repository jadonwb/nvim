-- volt: the UI toolkit the popups and panels are drawn with.
--
-- It draws into a buffer we own (no windows of its own), so the layout, sizing
-- and backdrop stay ours. Loaded on first require, which is when a popup opens.
return {
  'nvzone/volt',
  lazy = true,
  cond = function()
    return require('config.profile').wants 'ui'
  end,
}
