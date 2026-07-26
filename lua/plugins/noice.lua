return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    opts = {
      presets = {
        bottom_search = false,
        lsp_doc_border = true,
      },
      views = {
        cmdline_popup = {
          position = {
            row = '40%',
            col = '50%',
          },
        },
        hover = {
          border = {
            style = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
            padding = { 1, 2 },
          },
          position = { row = 3 },
        },
        notify = {
          border = {
            style = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
          },
        },
      },
    },
  },
}
