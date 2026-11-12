-- Statusline.
--
-- One line, no tabline: the layout's buffers live in the centre window and the
-- tab layer is gone. It carries what the session panel does not (mode, file,
-- diagnostics, LSP, position) so the two never repeat each other.

-- Used by the pager/help surfaces, which hide the statusline entirely.
NVLualine = {}

function NVLualine.show_everything()
  vim.opt.laststatus = 3
  vim.opt.showtabline = 0
end

function NVLualine.hide_everything()
  vim.opt.laststatus = 0
end

local function syn(name, what)
  local id = vim.fn.hlID(name)
  if id == 0 then
    return nil
  end
  local colour = vim.fn.synIDattr(vim.fn.synIDtrans(id), what .. '#')
  return colour ~= '' and colour or nil
end

local function colour(name)
  return { fg = syn(name, 'fg'), bg = syn(name, 'bg'), gui = 'bold' }
end

local MODE_NAMES = {
  n = 'NORMAL',
  i = 'INSERT',
  v = 'VISUAL',
  V = 'V-LINE',
  [string.char(22)] = 'V-BLOCK',
  R = 'REPLACE',
  r = 'REPLACE',
  c = 'COMMAND',
  t = 'TERMINAL',
  s = 'SELECT',
}

local function mode_group()
  local m = vim.api.nvim_get_mode().mode:sub(1, 1)
  if m == 'i' then
    return 'NvModeInsert'
  elseif m == 'v' or m == 'V' or m == string.char(22) or m == 's' then
    return 'NvModeVisual'
  elseif m == 'R' or m == 'r' then
    return 'NvModeReplace'
  elseif m == 'c' then
    return 'NvModeCommand'
  elseif m == 't' then
    return 'NvModeTerminal'
  end
  return 'NvModeNormal'
end

local function mode_text()
  local m = vim.api.nvim_get_mode().mode
  return ' ' .. (MODE_NAMES[m] or m:upper()) .. ' '
end

local function recording()
  local reg = vim.fn.reg_recording()
  return reg ~= '' and (' REC @' .. reg .. ' ') or ''
end

local function search_count()
  if vim.v.hlsearch == 0 then
    return ''
  end
  local sc = vim.fn.searchcount { recompute = true, maxcount = 999 }
  if sc.total == 0 then
    return ''
  end
  return (' %d/%d '):format(sc.current, sc.total)
end

--- File icon plus a shortened name. The directory is in the session panel, so
--- the statusline keeps the file itself readable instead of repeating a path.
local SPECIAL = {
  snacks_dashboard = ' Neovim ',
  nvnotify = ' Notifications ',
  nvprompt = ' Prompt ',
  nvcheatsheet = ' Cheatsheet ',
  oil = ' Directory ',
  NvimTree = ' Explorer ',
  snacks_picker_input = ' Picker ',
  snacks_picker_list = ' Picker ',
  nvchanges = ' Changes ',
  nvsession = ' OpenCode ',
  nvlsp = ' LSP ',
  nvdash = ' Dashboard ',
  qf = ' Quickfix ',
  pager = ' Messages ',
  trouble = ' Trouble ',
  snacks_terminal = ' Terminal ',
  nvdialog = ' Dialog ',
  lazy = ' Plugins ',
  mason = ' Mason ',
  ['grug-far'] = ' Search & Replace ',
  diffview = ' Diff ',
}

local function file_component()
  local special = SPECIAL[vim.bo.filetype]
  if special then
    return special
  end
  if vim.bo.buftype == 'terminal' then
    local id = vim.b.nv_terminal
    return ' \u{f018d} Terminal' .. (id and (' ' .. id) or '') .. ' '
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name:find('^opencode://', 1, true) then
    return ' Agent '
  end
  if name == '' then
    return ' [No Name] '
  end
  local icon = ''
  local ok, mini = pcall(require, 'mini.icons')
  if ok then
    icon = mini.get('file', name) .. ' '
  end
  local rel = vim.fn.fnamemodify(name, ':~:.')
  local dir = vim.fn.fnamemodify(rel, ':h')
  dir = (dir == '.' or dir == '') and '' or (dir .. '/')
  if #dir > 40 then
    dir = vim.fn.pathshorten(dir)
  end
  local label = '%#NvStPath#' .. dir:gsub('%%', '%%%%') .. '%#NvStName#' .. vim.fn.fnamemodify(name, ':t'):gsub('%%', '%%%%')
  if vim.bo.modified then
    label = label .. ' %#NvStModified#●'
  end
  if vim.bo.readonly then
    label = label .. ' %#NvStPath#'
  end
  return ' %#NvStIcon#' .. icon .. label .. ' '
end

--- Is the LSP panel showing? Then progress lives there, not here.
local function lsp_panel_open()
  return NVSlots and NVSlots.slot_with_provider and NVSlots.slot_with_provider 'lsp' ~= nil
end

local function lsp_clients()
  local seen, names = {}, {}
  for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
    if client.name and client.name ~= '' and not seen[client.name] then
      seen[client.name] = true
      names[#names + 1] = client.name
    end
  end
  if #names == 0 then
    return ''
  end
  return ' ' .. vim.fn.strcharpart(table.concat(names, ','), 0, 18) .. ' '
end

return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  opts = {
    options = {
      theme = (function()
        local function hl(name)
          return { fg = syn(name, 'fg'), bg = syn(name, 'bg') }
        end
        local base = hl 'NvSt'
        local t = {}
        for _, mode in ipairs { 'normal', 'insert', 'visual', 'replace', 'command', 'terminal', 'inactive' } do
          t[mode] = { a = base, b = base, c = base, x = base, y = base, z = base }
        end
        return t
      end)(),
      globalstatus = true,
      section_separators = { left = '', right = '' },
      refresh = { statusline = 200 },
      component_separators = { left = '', right = '' },
      disabled_filetypes = { statusline = { 'nvcheatsheet' } },
      always_show_tabline = false,
    },
    sections = {
      lualine_a = {
        {
          function()
            local g = mode_group()
            local cap = g:gsub('^NvMode', 'NvModeCap')
            return ('%%#%s#\u{e0b6}%%#%s#%s%%#%s#\u{e0b4}'):format(cap, g, mode_text(), cap)
          end,
          padding = 0,
        },
      },
      lualine_b = {
        {
          'branch',
          icon = { '\u{e0a0}', color = 'NvIcon' },
          color = 'NvStBranch',
          padding = { left = 2, right = 1 },
        },
        {
          -- Ahead/behind the upstream (the panel data's async git read).
          function()
            local git = package.loaded['features.layout.data'] and require('features.layout.data').git or {}
            local out = {}
            if (git.ahead or 0) > 0 then
              out[#out + 1] = '%#NvGreen#↑' .. git.ahead
            end
            if (git.behind or 0) > 0 then
              out[#out + 1] = '%#NvRed#↓' .. git.behind
            end
            return table.concat(out, ' ')
          end,
          padding = { left = 0, right = 1 },
        },
      },
      lualine_c = {
        {
          file_component,
          padding = { left = 0, right = 0 },
        },
        {
          'diagnostics',
          symbols = { error = '󰅚 ', warn = '󰀪 ', info = '󰋽 ', hint = '󰌶 ' },
          colored = true,
          always_visible = false,
          padding = { left = 1, right = 0 },
        },
      },
      lualine_x = {
        {
          function()
            return (NVMessages and NVMessages.progress_hl) or ''
          end,
          cond = function()
            return not lsp_panel_open() and NVMessages and type(NVMessages.progress_hl) == 'string' and NVMessages.progress_hl ~= ''
          end,
          padding = { left = 0, right = 1 },
        },
        {
          recording,
          cond = function()
            return vim.fn.reg_recording() ~= ''
          end,
          color = 'NvChipRedSoft',
          padding = { left = 0, right = 1 },
        },
        {
          search_count,
          cond = function()
            return vim.v.hlsearch ~= 0
          end,
          color = 'NvChipMagentaSoft',
          padding = { left = 0, right = 1 },
        },
        {
          lsp_clients,
          cond = function()
            return not lsp_panel_open() and #vim.lsp.get_clients { bufnr = 0 } > 0
          end,
          color = 'NvStMuted',
          padding = { left = 0, right = 1 },
        },
      },
      lualine_y = {
        {
          function()
            return '%#NvIcon#󰉋 %#NvStMuted#' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
          end,
          padding = { left = 1, right = 1 },
        },
        {
          'filetype',
          colored = false,
          color = 'NvStMuted',
          padding = { left = 1, right = 1 },
          cond = function()
            return vim.bo.buftype == '' and vim.bo.filetype ~= ''
          end,
        },
      },
      lualine_z = {
        {
          function()
            return ('%%#NvStPosCapL#\u{e0b6}%%#NvStPosIcon# 󰍎 %%#NvStPos# %d:%d %%#NvStPosCapR#\u{e0b4}'):format(vim.fn.line '.', vim.fn.col '.')
          end,
          padding = { left = 0, right = 1 },
        },
      },
    },
    inactive_sections = {},
  },
}
