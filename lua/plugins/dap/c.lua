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
    return not exec:match '%.so([.0-9]*)' and not exec:match '%.git/'
  end,
}

--
-- See
-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html
-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
local gdb_cmd = vim.fn.executable 'gdb-multiarch' == 1 and 'gdb-multiarch' or 'gdb'
dap.adapters.gdb = {
  id = 'gdb',
  type = 'executable',
  command = gdb_cmd,
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

local gdb_configs = {
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
        prompt = 'Executable arguments: ',
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
  -- Remote debugging via gdbserver
  {
    name = 'Connect to gdbserver (GDB)',
    type = 'gdb',
    request = 'attach',
    target = function()
      local host = vim.fn.input('Remote host: ', '')
      local port = vim.fn.input('Remote port: ', '')
      return host .. ':' .. port
    end,
    program = function()
      return vim.fn.input('Path to binary on target: ', '/app/')
    end,
  },
}

dap.configurations.c = gdb_configs
dap.configurations.cpp = gdb_configs
