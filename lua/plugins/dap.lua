return {
  {
    'mfussenegger/nvim-dap',
    -- stylua: ignore
    keys = {
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>da", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
      { "<leader>dc", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
      { "<leader>dg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
      { "<leader>dj", function() require("dap").down() end, desc = "Down a Frame" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up a Frame" },
      { "<leader>dC", false },
      { "<leader>dl", false },
      { "<leader>dO", false },
      { "<leader>di", false },
      { "<leader>do", false },
      { "<leader>dP", false },
      { "<leader>dt", false },
      { "<F4>", function() require("dap").pause() end, desc = "Pause" },
      { "<F5>", function() require("dap").continue() end, desc = "Run/Continue" },
      { "<F6>", function() require("dap").step_into() end, desc = "Step Into" },
      { "<F7>", function() require("dap").step_over() end, desc = "Step Over" },
      { "<F8>", function() require("dap").step_out() end, desc = "Step Out" },
      { "<F9>", function() require("dap").step_back() end, desc = "Step Back" },
      { "<F10>", function() require("dap").run_last() end, desc = "Run Last" },
      { "<F12>", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>ds", function() require("dap").session() end, desc = "Session" },
      { "<leader>dd", function() require("dap").disconnect() end, desc = "Disconnect" },
      { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    },
    opts = function()
      local dap = require 'dap'
      local dap_utils = require 'dap.utils'
      local cwd = vim.fn.getcwd()
      local path = cwd
      local exec_opts = {
        path = path,
        executables = true,
        filter = function(exec)
          return not exec:match '%.so([.0-9]*)' and not exec:match '%.git/'
        end,
      }
      for _, configs in pairs(dap.configurations) do
        for _, cfg in ipairs(configs) do
          if type(cfg.program) == 'function' then
            cfg.program = function()
              return dap_utils.pick_file(exec_opts)
            end
          end
        end
      end
    end,
  },
  {
    'theHamsta/nvim-dap-virtual-text',
    opts = {
      virt_text_pos = 'eol',
    },
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'nvim-neotest/nvim-nio' },
    opts = {
      icons = {
        expanded = '▾',
        collapsed = '▸',
        current_frame = '*',
      },
      controls = {
        icons = {
          pause = ' F4',
          play = ' F5',
          step_into = ' F6',
          step_over = ' F7',
          step_out = ' F8',
          step_back = ' F9',
          run_last = ' F10',
          terminate = ' F12',
          disconnect = ' (␣dd)',
        },
      },
    },
  },
}
