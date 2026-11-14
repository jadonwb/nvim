-- mini.icons: the single icon source for files, filetypes and diagnostics.
--
-- Loaded at startup, with the dashboard: icons are part of the first screen,
-- not something that pops in once a later plugin asks for them. It also
-- stands in for nvim-web-devicons for every plugin that asks for that.
return {
  {
    'nvim-mini/mini.icons',
    lazy = false,
    priority = 900,
    opts = {},
    config = function(_, opts)
      require('mini.icons').setup(opts)
      require('mini.icons').mock_nvim_web_devicons()
    end,
  },
}
