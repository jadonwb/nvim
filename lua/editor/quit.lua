NVQuit = {}

local fn = {}

--- Gather all listed buffers with unsaved changes across all tabpages.
---@return { buf: integer, name: string }[]
function fn.get_modified_buffers()
  local modified = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified and vim.bo[buf].buflisted then
      local name = vim.api.nvim_buf_get_name(buf)
      if name == '' then
        name = '[No Name]'
      else
        name = vim.fn.fnamemodify(name, ':~:.')
      end
      table.insert(modified, { buf = buf, name = name })
    end
  end
  return modified
end

--- Save all unsaved buffers and quit. If any buffers have unsaved changes,
--- a custom floating dialog lets you review each one: Write, Discard, or Cancel.
function NVQuit.save_and_quit()
  local modified = fn.get_modified_buffers()

  if #modified == 0 then
    vim.cmd 'qall'
    return
  end

  local function process(index)
    if index > #modified then
      vim.cmd 'qall'
      return
    end

    local item = modified[index]
    NVDialogs.select({
      title = 'Unsaved Changes (' .. index .. '/' .. #modified .. ')',
      message = 'Buffer has unsaved changes:\n' .. item.name,
      options = { 'Write', 'Discard', 'Cancel' },
      shortcuts = { w = 'Write', d = 'Discard', c = 'Cancel' },
      initial_index = 1,
    }, function(choice)
      if choice == 'Write' then
        local ok, err = pcall(vim.api.nvim_buf_call, item.buf, function()
          vim.cmd 'write'
        end)
        if not ok then
          vim.notify('Failed to write ' .. item.name .. ': ' .. tostring(err), vim.log.levels.ERROR)
          return -- Abort the quit on write failure
        end
        process(index + 1)
      elseif choice == 'Discard' then
        -- Force-delete the buffer to discard unsaved changes before quitting
        pcall(vim.api.nvim_buf_delete, item.buf, { force = true })
        process(index + 1)
      end
      -- Cancel: do nothing, abort the quit
    end)
  end

  process(1)
end

--- Force quit all tabs and windows without saving.
function NVQuit.force_quit()
  vim.cmd 'qall!'
end

--- Save the current session and restart Neovim.
function NVQuit.restart()
  require('persistence').save()
  vim.schedule(function()
    vim.cmd 'restart'
  end)
end
