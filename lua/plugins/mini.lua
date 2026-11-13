-- mini.ai: a/i text objects, extended with treesitter-aware objects.
--
--   f function   c class   o block/conditional/loop   L loop   = assignment
--   C comment    a argument   u / U call   t tag   d digits   e word part
--   q quote   b bracket   (al / il: last, aN / iN: next)
-- These are textobject specs, not keymaps, so they cannot be found by dumping
-- the keymap list; they are listed here to keep `af`, `if`, `ac`, `ic`, `at`
-- and the rest working as they did under LazyVim.
return {
  {
    'nvim-mini/mini.ai',
    event = 'VeryLazy',
    opts = function()
      local ai = require 'mini.ai'
      return {
        n_lines = 500,
        -- `an` / `in` stay Neovim's own node selection (grow / shrink the
        -- selection by treesitter node); "next" objects move to aN / iN.
        mappings = { around_next = 'aN', inside_next = 'iN', around_last = 'al', inside_last = 'il' },
        custom_textobjects = {
          o = ai.gen_spec.treesitter { -- code block
            a = { '@block.outer', '@conditional.outer', '@loop.outer' },
            i = { '@block.inner', '@conditional.inner', '@loop.inner' },
          },
          f = ai.gen_spec.treesitter { a = '@function.outer', i = '@function.inner' },
          c = ai.gen_spec.treesitter { a = '@class.outer', i = '@class.inner' },
          L = ai.gen_spec.treesitter { a = '@loop.outer', i = '@loop.inner' },
          ['='] = ai.gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.rhs' },
          C = ai.gen_spec.treesitter { a = '@comment.outer', i = '@comment.inner' },
          t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' },
          d = { '%f[%d]%d+' },
          e = {
            { '%u[%l%d]+%f[^%l%d]', '%f[%S][%l%d]+%f[^%l%d]', '%f[%P][%l%d]+%f[^%l%d]', '^[%l%d]+%f[^%l%d]' },
            '^().*()$',
          },
          -- Entire buffer (LazyVim's): `ag` all of it, `ig` without the
          -- blank lines at either end. yag, vag, dig, …
          g = function(ai_type)
            local first, last = 1, vim.fn.line '$'
            if ai_type == 'i' then
              local a, b = vim.fn.nextnonblank(first), vim.fn.prevnonblank(last)
              if a == 0 or b == 0 then
                return { from = { line = first, col = 1 } }
              end
              first, last = a, b
            end
            return { from = { line = first, col = 1 }, to = { line = last, col = math.max(#vim.fn.getline(last), 1) } }
          end,
          u = ai.gen_spec.function_call(),
          U = ai.gen_spec.function_call { name_pattern = '[%w_]' },
        },
      }
    end,
  },
  {
    'nvim-mini/mini.surround',
    opts = {
      silent = true,
    },
  },
}
