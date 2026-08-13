---@class TabLabel
---@field icon string
---@field name string

NVTabs = {
  editor_icon = '',
}

---@class TabType
---@field name string Unique type identifier
---@field is_temporary boolean
---@field is_match fun(tabid: TabID): boolean
---@field create_hook? fun(tab: TabID) Called after tab creation
---@field close_hook? fun(tabid: TabID): boolean Custom close behavior

---@type TabType[]
NVTabs._types = {}

--- Register a tab type with the system.
---@param config TabType
function NVTabs.register_type(config)
  table.insert(NVTabs._types, config)
end

---@param tabid TabID
---@return TabType | nil
function NVTabs.get_tab_type(tabid)
  -- Temporary types first
  for _, t in ipairs(NVTabs._types) do
    if t.is_temporary and t.is_match(tabid) then
      return t
    end
  end
  -- Then non-temporary types
  for _, t in ipairs(NVTabs._types) do
    if not t.is_temporary and t.is_match(tabid) then
      return t
    end
  end
  return nil
end

local fn = {}

function NVTabs.keymaps()
  K.map { NVKeymaps.tab_create, 'Create new tab', fn.create_tab, mode = { 'n', 'i', 'v', 't' } }
  K.map { NVKeymaps.tab_close, 'Close tab', fn.close_tab, mode = { 'n', 'i', 'v', 't' }, nowait = true }
  K.map { NVKeymaps.tab_move.right, 'Next tab', '<Cmd>tabnext<CR>', mode = { 'n', 'i', 'v', 't' } }
  K.map { NVKeymaps.tab_move.left, 'Previous tab', '<Cmd>tabprev<CR>', mode = { 'n', 'i', 'v', 't' } }
  K.map { NVKeymaps.tab_swap.right, 'Move tab to the right', '<Cmd>tabmove +1<CR>', mode = { 'n', 'i', 'v', 't' } }
  K.map { NVKeymaps.tab_swap.left, 'Move tab to the left', '<Cmd>tabmove -1<CR>', mode = { 'n', 'i', 'v', 't' } }
end

function fn.create_tab()
  NVDialogs.input({ title = 'Tab name' }, function(name)
    if name and name ~= '' then
      vim.cmd 'tabnew'
      NVTabs.set_label { icon = NVTabs.editor_icon, name = name }
      NVPi.open_float()
    end
  end)
end

-- TODO: guard against / noop on last tab
function fn.close_tab()
  local tabid = vim.api.nvim_get_current_tabpage()
  local tab_type = NVTabs.get_tab_type(tabid)

  -- Tab-type-specific close hook
  if tab_type and tab_type.close_hook and tab_type.close_hook(tabid) then
    return
  end

  -- Default fallback: confirm then close
  NVDialogs.select({
    title = 'Close Tab?',
    -- message = 'Close tab?',
    options = { 'Yes', 'No' },
    shortcuts = { y = 'Yes', n = 'No' },
    initial_index = 1,
  }, function(choice)
    if choice == 'Yes' then
      vim.cmd 'tabclose'
    end
  end)
end

function NVTabs.render_label(label)
  return label.icon .. ' ' .. label.name
end

function NVTabs.set_label(label)
  vim.t.tab_label = label
  NVLualine.rename_tab(NVTabs.render_label(label))
end

function NVTabs.set_label_if_empty(label)
  if not vim.t.tab_label then
    NVTabs.set_label(label)
  end
end

function NVTabs.save_labels()
  local cwd = vim.fn.getcwd(-1, 0) -- first tab cwd
  local tab_labels = {}

  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local ok, tab_label = pcall(vim.api.nvim_tabpage_get_var, tab, 'tab_label')
    if ok and tab_label then
      tab_labels[tostring(i)] = tab_label
    end
  end

  local all = vim.g.NVTABS or {}
  all[cwd] = not vim.tbl_isempty(tab_labels) and tab_labels or nil
  vim.g.NVTABS = all
end

function NVTabs.restore_labels()
  local cwd = vim.fn.getcwd(-1, 0) -- first tab cwd
  local all = vim.g.NVTABS or {}
  local tab_labels = all[cwd]

  if not tab_labels then
    return
  end

  NVTabs.restoring = true

  local tabs = vim.api.nvim_list_tabpages()
  local current_tab = vim.api.nvim_get_current_tabpage()

  for i, tab_label in pairs(tab_labels) do
    local tab = tabs[tonumber(i)]
    if tab and tab_label.icon and tab_label.name then
      vim.api.nvim_set_current_tabpage(tab)
      NVTabs.set_label(tab_label)
    end
  end

  vim.api.nvim_set_current_tabpage(current_tab)

  NVTabs.restoring = false
end

---@param tabid TabID
---@return boolean
function NVTabs.is_temporary(tabid)
  for _, t in ipairs(NVTabs._types) do
    if t.is_temporary and t.is_match(tabid) then
      return true
    end
  end
  return false
end

---@return TabID[]
function NVTabs.get_non_temporary()
  local tabs = vim.api.nvim_list_tabpages()
  local result = {}

  for _, tabid in ipairs(tabs) do
    if not NVTabs.is_temporary(tabid) then
      table.insert(result, tabid)
    end
  end

  return result
end

function NVTabs.close_all_temporary()
  local tabs = vim.api.nvim_list_tabpages()
  for _, tabid in ipairs(tabs) do
    if not vim.api.nvim_tabpage_is_valid(tabid) then
      goto continue
    end
    local tab_type = NVTabs.get_tab_type(tabid)
    if tab_type and tab_type.is_temporary and tab_type.close_hook then
      vim.api.nvim_set_current_tabpage(tabid)
      tab_type.close_hook(tabid)
    end
    ::continue::
  end
end
