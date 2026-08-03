local M = {}
NVSearch = M

M.cmd = 'rg'
M.base_args = {
  '--follow',
  '--color=never',
  '--no-heading',
  '--with-filename',
  '--line-number',
  '--column',
}
M.optional_args = {
  with_hidden = '--hidden',
  with_ignored = '--no-ignore-vcs',
  smart_case = '--smart-case',
  ignore_case = '--ignore-case',
}

return M
