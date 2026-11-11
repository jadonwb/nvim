-- Auto format on save, with global and per-buffer switches.
--
-- LazyVim provided this; without it, `vim.g.autoformat` has no effect and
-- conform only runs when called by hand.
NVFormat = {}

---@param buf? integer
---@return boolean
function NVFormat.enabled(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local buffer = vim.b[buf].autoformat
  if buffer ~= nil then
    return buffer
  end
  return vim.g.autoformat == nil or vim.g.autoformat
end

function NVFormat.toggle_global()
  vim.g.autoformat = not (vim.g.autoformat == nil or vim.g.autoformat)
  NVMessages.info('Autoformat (global): ' .. (vim.g.autoformat and 'enabled' or 'disabled'))
end

function NVFormat.toggle_buffer()
  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].autoformat = not NVFormat.enabled(buf)
  NVMessages.info('Autoformat (buffer): ' .. (vim.b[buf].autoformat and 'enabled' or 'disabled'))
end

function NVFormat.setup()
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = vim.api.nvim_create_augroup('NV format_on_save', { clear = true }),
    callback = function(ev)
      if not NVFormat.enabled(ev.buf) then
        return
      end
      pcall(function()
        require('conform').format { bufnr = ev.buf, async = false, lsp_format = 'fallback' }
      end)
    end,
  })
end
