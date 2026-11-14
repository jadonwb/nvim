-- mini.hipatterns: highlight colour literals in code.
return {
  {
    -- Highlight colours in code: #aabbcc, named CSS colours, Tailwind classes.
    'nvim-mini/mini.hipatterns',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = function()
      local hi = require 'mini.hipatterns'
      return {
        highlighters = {
          hex_color = hi.gen_highlighter.hex_color { priority = 2000 },
          shorthand = {
            pattern = '()#%x%x%x()%f[^%x%w]',
            group = function(_, _, data)
              local match = data.full_match
              if match == '#add' then
                return
              end
              local r, g, b = match:sub(2, 2), match:sub(3, 3), match:sub(4, 4)
              return MiniHipatterns.compute_hex_color_group('#' .. r .. r .. g .. g .. b .. b, 'bg')
            end,
            extmark_opts = { priority = 2000 },
          },
        },
      }
    end,
  },
}
