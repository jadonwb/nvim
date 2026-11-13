-- Rust extra (config/extras.lua): Cargo.toml versions and features.
return {
  {
    'saecki/crates.nvim',
    event = { 'BufRead Cargo.toml' },
    cond = function()
      return require('config.profile').wants 'languages' and require('config.extras').enabled 'rust'
    end,
    opts = {
      lsp = { enabled = true, actions = true, completion = true, hover = true },
    },
  },
}
