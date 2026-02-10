return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    opts = {
      presets = {
        bottom_search = false,
        lsp_doc_border = true,
      },
      messages = {
        enabled = true,
        view = 'mini',
        view_error = 'mini',
        view_warn = 'mini',
        view_history = 'mini',
        view_search = 'mini',
      },
      notify = {
        enabled = true,
        view = 'mini',
      },
      lsp = {
        message = {
          enabled = true,
          view = 'mini',
        },
      },
      views = {
        cmdline_popup = {
          position = {
            row = '40%',
            col = '50%',
          },
        },
        mini = {
          timeout = 3000, -- timeout in milliseconds
          align = 'center',
          position = {
            -- Centers messages top to bottom
            row = '95%',
            -- Aligns messages to the far right
            col = '100%',
          },
        },
      },
    },
  },
}
