return {
  'nosduco/remote-sshfs.nvim',
  dependencies = {
    {
      'nvim-telescope/telescope.nvim',
      lazy = true,
      dependencies = { 'nvim-lua/plenary.nvim' },
    },
  },
  opts = {},
  keys = {
    {
      '<leader>Rc',
      function()
        vim.ui.input({
          prompt = 'RemoteSSHFSConnect: ',
        }, function(input)
          if input and input ~= '' then
            vim.cmd('RemoteSSHFSConnect ' .. input)
          end
        end)
      end,
      desc = 'Remote SSH Connect',
    },
    { '<leader>Rd', '<cmd>RemoteSSHFSDisconnect<cr>', desc = 'Remote SSH Disconnect' },
    { '<leader>Re', '<cmd>RemoteSSHFSEdit<cr>', desc = 'Remote SSH Edit' },
  },
}

-- return {
-- 	"amitds1997/remote-nvim.nvim",
-- 	version = "*",         -- Pin to GitHub releases
-- 	dependencies = {
-- 		"nvim-lua/plenary.nvim", -- For standard functions
-- 		"MunifTanjim/nui.nvim", -- To build the plugin UI
-- 		-- "nvim-telescope/telescope.nvim", -- For picking b/w different remote methods
-- 	},
-- 	config = true,
-- }
