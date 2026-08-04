NVSearch = {}

NVSearch.cmd = 'rg'
NVSearch.base_args = {
  '--follow',
  '--color=never',
  '--no-heading',
  '--with-filename',
  '--line-number',
  '--column',
}
NVSearch.optional_args = {
  with_hidden = '--hidden',
  with_ignored = '--no-ignore-vcs',
  smart_case = '--smart-case',
  ignore_case = '--ignore-case',
}

