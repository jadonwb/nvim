NVFff = {
  'dmtrKovalenko/fff.nvim',
  cond = function()
    return require('config.profile').wants 'picker'
  end,
  branch = 'main',
  build = function()
    require('fff.download').download_or_build_binary()
  end,
  event = 'VeryLazy',
  config = function(_, opts)
    require('fff').setup(opts)
    -- Start the background scan before the first search.
    require('fff.core').ensure_initialized()
  end,
  opts = {
    prompt_vim_mode = true,
    file_picker = {
      fuzzy_query_highlighting = true,
    },
    grep = {
      modes = { 'plain', 'regex', 'fuzzy' },
    },
    -- TODO?: not really relevant anymore with snacks as frontend?
    debug = {
      enabled = false,
      show_scores = true,
      show_file_info = { file_info = true, score_breakdown = false, timings = false, full_path = false },
    },
  },
}

return { NVFff }
