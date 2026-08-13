NVGitWorktrees = {}

local fn = {}

function NVGitWorktrees.keymaps()
  K.map { '<C-S-t>', 'Create new tab with git worktree', fn.create_tab_with_worktree, mode = { 'n', 'i', 'v', 't' } }
  K.map { '<leader>gw', 'Show worktree picker', fn.pick_worktree, mode = { 'n', 'v', 't' } }
end

function fn.create_tab_with_worktree()
  NVDialogs.input({ title = 'Worktree name' }, function(name)
    if name and name ~= '' then
      fn.create_worktree_from_name(name)
    end
  end)
end

function fn.create_worktree_from_name(name)
  local normalized = NVGit.normalize_worktree_name(name)
  if not normalized or normalized == '' then
    vim.notify('Invalid worktree name', vim.log.levels.ERROR)
    return
  end

  local repo = NVGit.get_repo_info()
  if not repo then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end

  local worktree_path = repo.parent .. '/' .. repo.name .. '--' .. normalized

  local path, status = NVGit.create_worktree(normalized, worktree_path)
  if not path then
    vim.notify('Failed to create worktree', vim.log.levels.ERROR)
    return
  end

  -- Store original label in worktree config
  if status == 'created' then
    NVGit.set_worktree_label(path, name)
  end

  -- Use stored label or fall back to input name
  local label = NVGit.get_worktree_label(path) or name
  fn.open_worktree_tab(label, path)
end

function fn.pick_worktree()
  local worktrees = NVGit.get_all_worktrees()

  if #worktrees == 0 then
    vim.notify('No worktrees found', vim.log.levels.WARN)
    return
  end

  local current_cwd = vim.fn.getcwd(-1, 0)
  local items = {}
  local current_idx = 1
  for _, wt in ipairs(worktrees) do
    if not wt.bare then
      local label = NVGit.get_worktree_label(wt.path) or wt.branch
      table.insert(items, {
        text = label,
        path = wt.path,
        branch = wt.branch,
      })
      if wt.path == current_cwd then
        current_idx = #items
      end
    end
  end

  local Snacks = require 'snacks'
  Snacks.picker {
    title = 'Worktrees',
    items = items,
    matcher = { fuzzy = false, regex = true },
    layout = NVSPickerVerticalLayout.build(),
    on_show = function(picker)
      if current_idx > 1 then
        picker.list:move(current_idx, true)
      end
    end,
    format = function(item)
      local tab = fn.find_tab_with_cwd(item.path)
      return { { '󰙅 ', tab and 'SnacksPickerIcon' or 'Comment' }, { item.text } }
    end,
    confirm = function(picker, item)
      if item then
        picker:close()
        fn.switch_to_worktree(item)
      else
        local filter = picker.input:get()
        if filter and filter ~= '' then
          picker:close()
          fn.create_worktree_from_name(filter)
        end
      end
    end,
    preview = function(ctx)
      local lines = { 'Path: ' .. ctx.item.path, 'Branch: ' .. ctx.item.branch }
      ctx.preview:set_lines(lines)
    end,
  }
end

function fn.open_worktree_tab(label, path)
  -- Get current file relative to git root
  local current_file = vim.fn.expand '%:p'
  local repo = NVGit.get_repo_info()
  local relative_path = nil
  if repo and current_file:find(repo.root, 1, true) == 1 then
    relative_path = current_file:sub(#repo.root + 2)
  end

  vim.cmd 'tabnew'
  vim.cmd('tcd ' .. vim.fn.fnameescape(path))

  NVTabs.set_label { icon = '󰙅', name = label }

  -- Open same file in new worktree if it exists
  if relative_path then
    local new_file = path .. '/' .. relative_path
    if vim.fn.filereadable(new_file) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(new_file))
    end
  end

  vim.notify('Worktree: ' .. path)
end

function fn.find_tab_with_cwd(path)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_cwd = vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(tab))
    if tab_cwd == path then
      return tab
    end
  end
  return nil
end

function fn.switch_to_worktree(worktree)
  local existing_tab = fn.find_tab_with_cwd(worktree.path)
  if existing_tab then
    vim.api.nvim_set_current_tabpage(existing_tab)
  else
    local label = NVGit.get_worktree_label(worktree.path) or worktree.branch
    fn.open_worktree_tab(label, worktree.path)
  end
end

---@param info GitWorktreeInfo
function NVGitWorktrees.close_tab(info)
  -- Check if other tabs are inside this worktree
  local current_tab = vim.api.nvim_get_current_tabpage()
  local other_tabs_in_worktree = false
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if tab ~= current_tab and vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(tab)) == info.path then
      other_tabs_in_worktree = true
      break
    end
  end

  -- Show all options; destructive ones are disabled when other tabs are in the worktree
  local options = {
    { text = 'Close tab' },
    { text = 'Remove worktree', disabled = other_tabs_in_worktree, reason = 'Another tab is open in this worktree' },
    { text = 'Delete branch and worktree', disabled = other_tabs_in_worktree, reason = 'Another tab is open in this worktree' },
  }
  local shortcuts = { c = 'Close tab', r = 'Remove worktree', d = 'Delete branch and worktree' }

  NVDialogs.select({
    title = 'Close: ' .. info.branch,
    options = options,
    shortcuts = shortcuts,
  }, function(choice)
    if not choice then
      return
    end

    if choice == 'Close tab' then
      vim.cmd 'tabclose'
      return
    end

    -- Destructive actions: confirm if there are uncommitted changes
    local has_changes = NVGit.worktree_has_changes(info.path)

    local function do_remove()
      vim.cmd 'tabclose'
      vim.defer_fn(function()
        if not NVGit.remove_worktree(info.path, has_changes) then
          log.error 'Failed to remove worktree'
          return
        end
        log.info('Removed worktree: ' .. info.path)

        -- Close buffers from the removed worktree path
        -- TODO: share logic with eventual close and delete all buffers type stuff
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
            local name = vim.api.nvim_buf_get_name(buf)
            if vim.startswith(name, info.path) then
              pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
          end
        end

        if choice == 'Delete branch and worktree' then
          if not NVGit.delete_branch(info.branch) then
            log.error 'Failed to delete branch'
            return
          end
          log.info('Deleted branch: ' .. info.branch)
        end
      end, 100)
    end

    if has_changes then
      NVDialogs.select({
        title = 'Force Remove',
        message = 'Worktree has uncommitted changes. Force remove?',
        options = { 'Yes', 'No' },
        shortcuts = { y = 'Yes', n = 'No' },
        initial_index = 2,
      }, function(confirm_choice)
        if confirm_choice == 'Yes' then
          do_remove()
        end
      end)
    else
      do_remove()
    end
  end)
end

NVTabs.register_type {
  name = 'worktree',
  is_temporary = false,
  is_match = NVGit.is_worktree,
  close_hook = function()
    local info = NVGit.get_worktree_info()
    if info then
      NVGitWorktrees.close_tab(info)
      return true
    end
    return false
  end,
}
