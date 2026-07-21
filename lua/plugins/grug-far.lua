return {
  'MagicDuck/grug-far.nvim',
  keys = {
    { '<leader>sr', false },
    { '<leader>fr', function()
      local grug = require("grug-far")
      local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
      grug.open({
        transient = true,
        prefills = {
          filesFilter = ext and ext ~= "" and "*." .. ext or nil,
        },
      })
    end, mode = { "n", "x" }, desc = "Search and Replace" },
    { '<localleader>', '<cmd>lua require("which-key").show("\\\\")<cr>', ft = 'grug-far' },
  },
}
