return {
  'l-lin/seeker.nvim',
  branch = 'customize_picker_opts',
  dependencies = { 'folke/snacks.nvim' },
  cmd = { 'Seeker' },
  keys = {
    { '<leader>ff', ':Seeker files<CR>', desc = 'Seek Files' },
  },
  opts = {
    picker_opts = {
      hidden = true,
      ignored = true,
    },
  },
}

-- vim.ui.input({ prompt = "Enter directory: " }, function(input)
-- 	if input then
-- 		require("seeker").seek({
-- 			mode = "grep",
-- 			picker_opts = { cwd = input },
-- 		})
-- 	end
-- end)
