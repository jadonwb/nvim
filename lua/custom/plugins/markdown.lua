local ft = { 'markdown', 'copilot-chat' }
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = ft,
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' },
    opts = {
      file_types = ft,
      completions = { lsp = { enabled = true } },
      debounce = 150, -- Delay rendering to prevent conflicts
      -- max_file_size = 1.5, -- Skip large files
      render_modes = { 'n', 'v' },
    },
  },
}
