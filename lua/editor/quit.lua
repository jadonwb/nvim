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
function fn.save_session()
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
--- Collect decisions during review, apply all at the end so a later Cancel
--- undoes earlier Discard/Write choices.
local function process_unsaved_then(done_fn)
  local modified = fn.get_modified_buffers()

  if #modified == 0 then
    done_fn()
    return
  end

  local function process(index, decisions)
    if index > #modified then
      -- Phase 2: apply all collected decisions (only reached if no Cancel)
      for _, d in ipairs(decisions) do
        if d.action == 'write' then
          if d.filename then
            pcall(vim.api.nvim_buf_set_name, d.buf, d.filename)
          end
          local ok, err = pcall(vim.api.nvim_buf_call, d.buf, function()
            vim.cmd 'write'
          end)
          if not ok then
            vim.notify('Failed to write: ' .. tostring(err), vim.log.levels.ERROR)
          end
        elseif d.action == 'discard' then
          -- FIXME: deprecated
          pcall(vim.api.nvim_buf_set_option, d.buf, 'modified', false)
        end
      end
      done_fn()
      return
    end

    local item = modified[index]

    -- Focus the buffer being discussed so the user can see its content
    local current_win = vim.api.nvim_get_current_win()
    pcall(vim.api.nvim_win_set_buf, current_win, item.buf)

    NVDialogs.select({
      title = 'Unsaved Changes (' .. index .. '/' .. #modified .. ')',
      message = 'Buffer has unsaved changes:\n' .. item.name,
      options = { 'Write', 'Discard', 'Cancel' },
      shortcuts = { w = 'Write', d = 'Discard', c = 'Cancel' },
      initial_index = 1,
    }, function(choice)
      if choice == 'Write' then
        if item.name == '[No Name]' then
          NVDialogs.input({
            prompt = 'Save As',
          }, function(filename)
            if filename and filename ~= '' then
              table.insert(decisions, { buf = item.buf, action = 'write', filename = filename })
              process(index + 1, decisions)
            else
              -- User cancelled filename prompt; re-show the dialog
              process(index, decisions)
            end
          end)
        else
          table.insert(decisions, { buf = item.buf, action = 'write' })
          process(index + 1, decisions)
        end
      elseif choice == 'Discard' then
        table.insert(decisions, { buf = item.buf, action = 'discard' })
        process(index + 1, decisions)
      end
      -- Cancel: don't recurse, abort everything, no decisions applied
    end)
  end

  process(1, {})
end

--- Save all unsaved buffers and quit.
--- Reviews each modified buffer with Write/Discard/Cancel dialog.
function NVQuit.save_and_quit()
  process_unsaved_then(function()
    fn.save_session()
    vim.cmd 'qall'
  end)
end

--- Force quit all tabs and windows without saving.
function NVQuit.force_quit()
  vim.cmd 'qall!'
end

function fn.restart()
  local flag_file = vim.fn.stdpath 'cache' .. '/nvim_restart_flag'

  local file = io.open(flag_file, 'w')
  if file then
    file:write 'restart'
    file:close()
  end

  vim.cmd 'silent! restart'
end

--- Save session and restart Neovim.
--- Reviews unsaved buffers with the same dialog as save_and_quit.
function NVQuit.restart()
  process_unsaved_then(function()
    fn.save_session()
    fn.restart()
  end)
end
