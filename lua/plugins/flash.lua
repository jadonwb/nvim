return {
  'folke/flash.nvim',
  -- stylua: ignore
  keys = {
    { "s", mode = { "n", "x", "o" }, false },
    { "S", mode = { "n", "o", "x" }, false },
    { "r", mode = "o", false },
    { "R", mode = { "o", "x" }, false },
    { "<c-s>", mode = { "c" }, false },
  },
  opts = {
    modes = {
      char = {
        keys = { 'f', 'F', 't', 'T' },
      },
    },
  },
}
