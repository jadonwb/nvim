NVKeys = {}

--- Feed a key sequence into Neovim's input queue.
---@param keys string
---@param options {mode: "n" | "x" | "t", from_part: boolean, do_lt: boolean, special: boolean}
function NVKeys.send(keys, options)
  local mode = options.mode

  if mode == 'n' then
    local termcodes = vim.api.nvim_replace_termcodes(keys, true, true, true)
    vim.api.nvim_feedkeys(termcodes, 'n', false)
  elseif mode == 'x' then
    local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(termcodes, 'x', false)
  elseif mode == 't' then
    vim.api.nvim_feedkeys(keys, 't', false)
  else
    log.error('Unexpected mode in NVKeys.send: ' .. tostring(mode))
  end
end
