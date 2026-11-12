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
  local m = vim.api.nvim_get_mode().mode
  if m == 'i' then
    return 'NvStModeInsert'
  elseif m == 'v' or m == 'V' or m == string.char(22) then
    return 'NvStModeVisual'
  elseif m == 'R' or m == 'r' then
    return 'NvStModeReplace'
  end
  return 'NvStMode'
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
  oil = ' Explorer ',
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
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    return ' [No Name] '
  end
  local label = vim.fn.fnamemodify(name, ':t')
  local icon = ''
  local ok, mini = pcall(require, 'mini.icons')
  if ok then
    icon = mini.get('file', name)
  end
  if vim.bo.modified then
    label = label .. ' ●'
  end
  if vim.bo.readonly then
    label = label .. ' '
  end
  return ' ' .. icon .. ' ' .. label .. ' '
end

local function lsp_clients()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
    if client.name and client.name ~= '' then
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
      theme = 'auto',
      globalstatus = true,
      section_separators = { left = '', right = '' },
      component_separators = { left = '', right = '' },
      disabled_filetypes = { statusline = { 'nvcheatsheet' } },
      always_show_tabline = false,
    },
    sections = {
      lualine_a = {
        {
          function()
            return mode_text()
          end,
          color = function()
            return colour(mode_group())
          end,
          padding = 0,
        },
      },
      lualine_b = {
        {
          'diagnostics',
          symbols = {
            error = ' ',
            warn = ' ',
            info = ' ',
            hint = ' ',
          },
          colored = true,
          always_visible = false,
          padding = { left = 1, right = 0 },
        },
      },
      lualine_c = {
        {
          file_component,
          color = 'NvStFile',
          padding = { left = 0, right = 0 },
        },
      },
      lualine_x = {
        {
          function()
            return (NVMessages and NVMessages.progress_hl) or ''
          end,
          cond = function()
            return NVMessages and type(NVMessages.progress_hl) == 'string' and NVMessages.progress_hl ~= ''
          end,
          padding = { left = 0, right = 1 },
        },
        {
          recording,
          cond = function()
            return vim.fn.reg_recording() ~= ''
          end,
          color = 'DiagnosticWarn',
          padding = { left = 0, right = 0 },
        },
        {
          search_count,
          cond = function()
            return vim.v.hlsearch ~= 0
          end,
          color = 'NvChipMuted',
          padding = { left = 0, right = 0 },
        },
        {
          lsp_clients,
          cond = function()
            -- The progress label already names the client doing the work.
            local busy = NVMessages and NVMessages.progress_hl and NVMessages.progress_hl ~= ''
            return not busy and #vim.lsp.get_clients { bufnr = 0 } > 0
          end,
          color = 'NvStMuted',
          padding = { left = 0, right = 0 },
        },
      },
      lualine_y = {
        {
          'filetype',
          colored = false,
          color = 'NvStMuted',
          padding = { left = 1, right = 1 },
          cond = function()
            return vim.bo.filetype ~= 'snacks_dashboard'
          end,
        },
      },
      lualine_z = {
        {
          function()
            return (' %d:%d '):format(vim.fn.line '.', vim.fn.col '.')
          end,
          color = 'NvStMuted',
          padding = { left = 0, right = 0 },
        },
      },
    },
  },
}
