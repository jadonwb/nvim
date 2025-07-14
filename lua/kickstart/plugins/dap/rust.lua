local ok, dap = pcall(require, 'dap')
if not ok then
  return
end

local dap_utils = require 'dap.utils'

local cwd = vim.fn.getcwd()

local exec_opts = {
  path = cwd,
  executables = true,

  filter = function(exec)
    -- Filter out shared libraries
    return not exec:match '%.so([.0-9]*)'
  end,
}

local function get_unittest_executables()
  local cmd = "cargo test --no-run --message-format=json 2>/dev/null | jq -r 'select(.profile.test == true) | .filenames[]'"
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local result = handle:read '*a'
  handle:close()
  if not result then
    return nil
  end

  local unittests = vim.fn.split(result, '\n')
  return unittests
end

--
-- See
-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html
-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
dap.adapters.rust_gdb = {
  id = 'rust_gdb',
  type = 'executable',
  command = 'rust-gdb',
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

dap.configurations.rust = {
  {
    name = 'Run rust unit tests (GDB)',
    type = 'rust_gdb',
    request = 'launch',
    program = function()
      local unittests = get_unittest_executables()
      if not unittests then
        return
      end

      -- Filter out against cargo test --no-run list
      return dap_utils.pick_file {
        path = cwd,
        executables = true,

        filter = function(exec)
          for _, test in ipairs(unittests) do
            if vim.fn.trim(test) == exec then
              return test
            end
          end
        end,
      }
    end,
  },
  {
    name = 'Run executable (GDB)',
    type = 'rust_gdb',
    request = 'launch',
    -- This requires special handling of 'run_last', see
    -- https://github.com/mfussenegger/nvim-dap/issues/1025#issuecomment-1695852355
    program = function()
      return dap_utils.pick_file(exec_opts)
    end,
  },
  {
    name = 'Run executable with arguments (GDB)',
    type = 'rust_gdb',
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
    type = 'rust_gdb',
    request = 'attach',
    processId = require('dap.utils').pick_process,
  },
}
