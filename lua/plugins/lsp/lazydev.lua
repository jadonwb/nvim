-- lazydev: LuaLS library support for this config.
return {
  {
    -- LuaLS library support while editing this config.
    'folke/lazydev.nvim',
    ft = 'lua',
    cmd = 'LazyDev',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
      -- lazydev adds the deployed config as a library, which is what gives the
      -- source tree `vim` types; keep it.
    },
  },
}
