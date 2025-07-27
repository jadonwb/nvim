local ok, dap = pcall(require, 'dap')
if not ok then
  return
end

local dap_utils = require 'dap.utils'

local cwd = vim.fn.getcwd()
local is_samba = cwd:find 'samba'

local path = cwd
if is_samba then
  path = vim.fs.joinpath(cwd, 'bin')
end

local exec_opts = {
  path = path,
  executables = true,

  filter = function(exec)
    -- Filter out shared libraries
    return not exec:match '%.so([.0-9]*)'
  end,
}

--
-- See
-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html
-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
dap.adapters.gdb = {
  id = 'gdb',
  type = 'executable',
  command = 'gdb',
  args = { '--quiet', '--interpreter=dap' },
  --[[
    args = {
        '-iex',
        'set debug dap-log-file /tmp/gdb-dap.log',
        '--quiet',
        '--interpreter=dap',
    },
]]
}

dap.configurations.c = {
  {
    name = 'Run executable (GDB)',
    type = 'gdb',
    request = 'launch',
    -- This requires special handling of 'run_last', see
    -- https://github.com/mfussenegger/nvim-dap/issues/1025#issuecomment-1695852355
    program = function()
      return dap_utils.pick_file(exec_opts)
    end,
  },
  {
    name = 'Run executable with arguments (GDB)',
    type = 'gdb',
    request = 'launch',
    -- This requires special handling of 'run_last', see
    -- https://github.com/mfussenegger/nvim-dap/issues/1025#issuecomment-1695852355
    program = function()
      return dap_utils.pick_file(exec_opts)
    end,
    args = function()
      local args_str = vim.fn.input {
        prompt = 'Execeutable arguments: ',
      }
      return vim.split(args_str, ' +')
    end,
  },
  {
    name = 'Attach to process (GDB)',
    type = 'gdb',
    request = 'attach',
    processId = require('dap.utils').pick_process,
  },
}
