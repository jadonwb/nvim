-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- [[ Disable new line comment ]]
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    vim.opt.formatoptions:remove { 'c', 'r', 'o' }
  end,
  group = vim.api.nvim_create_augroup('disable_newline_comment', { clear = true }),
  desc = 'Disable New Line Comment',
})

-- [[ Open files with external applications ]]
local function open_with_app(app)
  return function()
    if vim.fn.executable(app) == 0 then
      return
    end

    local file_path = vim.fn.expand '%:p'
    vim.fn.jobstart({ app, file_path }, { detach = true })
    vim.cmd 'bdelete'
  end
end

local file_associations = {
  pdf = 'zathura', -- or "tdf"
  -- You can add more file types here
  -- png = "feh",
  -- mp4 = "mpv",
}

for ext, app in pairs(file_associations) do
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    pattern = '*.' .. ext,
    callback = open_with_app(app),
  })
end

-- Easier setup for clangd --
-- local function ensure_basic_clangd_config()
--   if vim.fn.filereadable 'compile_commands.json' == 0 and vim.fn.filereadable '.clangd' == 0 then
--     local basic_config = [[
-- CompileFlags:
--   Add:
--     - -std=c11
--     - -Wall
--     - -Wextra
--   Remove: [-W*, -fopenmp*]
--
-- Diagnostics:
--   Suppress:
--     - unknown-warning-option
--     - unused-command-line-argument-hard-error-in-future
-- ]]
--     local file = io.open('.clangd', 'w')
--     if file then
--       file:write(basic_config)
--       file:close()
--     end
--   end
-- end
--
-- local function smart_clangd_setup()
--   local cwd = vim.fn.getcwd()
--
--   if vim.fn.filereadable 'compile_commands.json' == 1 then
--     return
--   end
--
--   if vim.fn.filereadable 'CMakeLists.txt' == 1 then
--     local success =
--       os.execute 'cd build 2>/dev/null && cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON . 2>/dev/null && ln -sf ../build/compile_commands.json .. 2>/dev/null'
--     if success ~= 0 then
--       os.execute 'cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build 2>/dev/null && ln -sf build/compile_commands.json . 2>/dev/null'
--     end
--   elseif vim.fn.filereadable 'Makefile' == 1 then
--     os.execute 'command -v bear >/dev/null && bear -- make build 2>/dev/null'
--   else
--     local compile_db = string.format(
--       [[
--   {
--     "directory": "%s",
--     "command": "gcc -std=c11 -Wall -Wextra -I. %s",
--     "file": "%s"
--   }
-- ]],
--       cwd,
--       vim.fn.expand '%',
--       vim.fn.expand '%:p'
--     )
--     local file = io.open('compile_commands.json', 'w')
--     if file then
--       file:write(compile_db)
--       file:close()
--     end
--   end
-- end

-- Easy build and execute --
local lang_maps = {
  arduino = {
    build = 'arduino-cli compile --fqbn arduino:avr:uno %',
    exec = 'arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno %',
    clean = 'rm -rf build/',
  },
  c = { build = 'gcc *.c -lm -g -o main', exec = './main', clean = 'rm -f main' },
  clojure = { exec = 'lein run' },
  cpp = {
    build = 'mkdir -p build && cd build && cmake .. && make',
    exec = 'cd build && ./main',
    clean = 'rm -rf build/',
  },
  elixir = { exec = 'mix run' },
  gleam = { exec = 'gleam run' },
  go = { build = 'go build', exec = 'go run %', clean = 'go clean && rm -f main' },
  haskell = { exec = 'cabal run' },
  java = { build = 'javac %', exec = 'java %:r', clean = 'rm -f *.class' },
  javascript = { exec = 'bun %' },
  python = { exec = 'python %' },
  rust = { exec = 'cargo run' },
  sh = { exec = '%' },
  tex = { build = 'pdflatex -shell-escape %' },
  typescript = { exec = 'bun %' },
  typst = { build = 'typst compile %' },
}

for lang, data in pairs(lang_maps) do
  local f, _ = io.open('Makefile', 'r')
  if f then
    data.build = 'make build'
    data.exec = 'make exec'
    data.clean = 'make clean'
    f:close()
  end

  -- --TODO: add cmakelists detection for easy build execute and clean
  -- if vim.fn.filereadable 'CMakeLists.txt' == 1 then
  --   data.build = ''
  --   data.exec = ''
  --   data.clean = ''
  -- end

  if data.build ~= nil then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = lang,
      callback = function()
        vim.keymap.set('n', '<Leader>cb', ':!' .. data.build .. '<CR>', {
          desc = 'Build: ' .. data.build,
          buffer = true,
        })
      end,
    })
  end

  if data.exec ~= nil then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = lang,
      callback = function()
        vim.keymap.set('n', '<Leader>cx', ':split<CR>:terminal ' .. data.exec .. '<CR>', {
          desc = 'Execute: ' .. data.exec,
          buffer = true,
        })
      end,
    })
  end

  if data.clean ~= nil then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = lang,
      callback = function()
        vim.keymap.set('n', '<Leader>cc', ':!' .. data.clean .. '<CR>', {
          desc = 'Clean: ' .. data.clean,
          buffer = true,
        })
      end,
    })
  end
end

-- vim.api.nvim_create_autocmd('FileType', {
--   pattern = { 'c', 'cpp' },
--   callback = function()
--     ensure_basic_clangd_config()
--     vim.keymap.set('n', '<Leader>cC', smart_clangd_setup, {
--       buffer = true,
--       desc = 'Setup clangd compile_commands.json',
--     })
--   end,
-- })
