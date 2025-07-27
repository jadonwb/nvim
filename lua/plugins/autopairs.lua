return {
  'windwp/nvim-autopairs',
  dependencies = 'nvim-treesitter',
  event = { 'BufReadPost', 'InsertEnter' },
  config = function()
    local npairs = require 'nvim-autopairs'
    local nrule = require 'nvim-autopairs.rule'
    local ncond = require 'nvim-autopairs.conds'

    npairs.setup {
      check_ts = true,
      ts_config = {
        lua = { 'string' },
      },
    }

    npairs.add_rule(nrule('<', '>', { 'rust', 'cpp' }):with_pair(ncond.not_before_regex_check ' '))
  end,
}
