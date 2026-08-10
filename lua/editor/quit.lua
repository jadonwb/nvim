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

--- Save the session via persistence.
local function save_session()
  local ok = pcall(require, 'persistence')
  if ok then
    pcall(function()
      require('persistence').save()
    end)
  end
end

--- Process unsaved buffers with a per-file dialog, then call done_fn.
--- If no buffers are modified, calls done_fn immediately.
---@param done_fn fun() Called after all buffers are processed (or immediately if none modified)
local function process_unsaved_then(done_fn)
  local modified = fn.get_modified_buffers()

  if #modified == 0 then
    done_fn()
    return
  end

  local function process(index)
    if index > #modified then
      done_fn()
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
          return -- Abort on write failure
        end
        process(index + 1)
      elseif choice == 'Discard' then
        pcall(vim.api.nvim_buf_set_option, item.buf, 'modified', false)
        process(index + 1)
      end
      -- Cancel: do nothing, abort
    end)
  end

  process(1)
end

--- Save all unsaved buffers and quit.
--- Reviews each modified buffer with Write/Discard/Cancel dialog.
function NVQuit.save_and_quit()
  process_unsaved_then(function()
    save_session()
    vim.cmd 'qall'
  end)
end

--- Force quit all tabs and windows without saving.
function NVQuit.force_quit()
  vim.cmd 'qall!'
end

--- Save session and restart Neovim.
--- Reviews unsaved buffers with the same dialog as save_and_quit.
function NVQuit.restart()
  process_unsaved_then(function()
    save_session()
    vim.schedule(function()
      vim.cmd 'restart'
    end)
  end)
end
