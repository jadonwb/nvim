return {
  'b0o/incline.nvim',
  event = 'VeryLazy',
  opts = {
    hide = {
      cursorline = 'smart',
      focused_win = true,
      only_win = false,
    },
    render = function(props)
      local bufname = vim.api.nvim_buf_get_name(props.buf)
      if bufname == '' then
        bufname = '-'
      end
      local filename = vim.fn.fnamemodify(bufname, ':t')
      local ext = vim.fn.fnamemodify(bufname, ':e')
      local icon, _ = require('nvim-web-devicons').get_icon(filename, ext)
      local modified = vim.bo[props.buf].modified

      -- Resolve colors from theme highlight groups (updates on colorscheme change)
      local bg_hl = vim.api.nvim_get_hl(0, { name = 'StatusLine', link = false })
      local comment_hl = vim.api.nvim_get_hl(0, { name = 'Comment', link = false })
      local bg = bg_hl.bg and string.format('#%06x', bg_hl.bg)
      local fg = comment_hl.fg and string.format('#%06x', comment_hl.fg)

      return {
        { (icon or '') .. ' ', guibg = bg, guifg = fg },
        {
          filename .. ' ',
          guibg = bg,
          guifg = fg,
          gui = modified and 'bold,italic' or 'bold',
        },
      }
    end,
  },
}
