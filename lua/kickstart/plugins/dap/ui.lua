local ok, dapui = pcall(require, 'dapui')
if not ok then
  return
end

local icons = require 'kickstart.icons'
local dapui_icons = icons.dapui

dapui.setup {
  icons = dapui_icons.icons,
  controls = {
    icons = dapui_icons.control_icons,
  },
  layouts = {
    -- Changing the layout order will give more space to the first element
    {
      -- You can change the order of elements in the sidebar
      elements = {
        -- { id = "scopes", size = 0.25, },
        { id = 'stacks', size = 0.50 },
        { id = 'breakpoints', size = 0.25 },
        { id = 'watches', size = 0.25 },
      },
      size = 56,
      position = 'right', -- Can be "left" or "right"
    },
    {
      elements = {
        { id = 'repl', size = 0.60 },
        { id = 'console', size = 0.40 },
      },
      size = 8,
      position = 'bottom', -- Can be "bottom" or "top"
    },
  },
}

local dap_icons = icons.dap
for name, sign in pairs(dap_icons) do
  sign = type(sign) == 'table' and sign or { sign }
  vim.fn.sign_define(
    'Dap' .. name,
    ---@diagnostic disable-next-line: assign-type-mismatch
    { text = sign[1], texthl = sign[2] or 'DiagnosticInfo', linehl = sign[3], numhl = sign[3] }
  )
end

local dap = require 'dap'

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close
