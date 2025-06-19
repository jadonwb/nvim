return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
    options = {
      component_separators = '',
      section_separators = '',
      globalstatus = true,
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff' },
      lualine_c = {
        {
          'filename',
          path = 0, -- Just filename, no path
          symbols = {
            modified = '●',
            readonly = '',
            unnamed = '',
          },
        },
      },
      lualine_x = {
        'filetype',
        'encoding',
        {
          'filesize',
          fmt = function(str)
            -- Only show if file has content
            if str == '' or str == '0B' then
              return ''
            end
            return str
          end,
        },
      },
      lualine_y = { 'location' },
      lualine_z = {},
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { 'filename' },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
  },
}
