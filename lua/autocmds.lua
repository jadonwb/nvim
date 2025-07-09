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
local function open_with_app(apps)
  return function()
    if type(apps) == 'string' then
      apps = { apps }
    end

    local file_path = vim.fn.expand '%:p'

    for _, app in ipairs(apps) do
      if app == 'browser' then
        vim.fn.jobstart({ 'xdg-open', file_path }, { detach = true })
        vim.cmd 'bdelete'
        return
      elseif vim.fn.executable(app) == 1 then
        vim.fn.jobstart({ app, file_path }, { detach = true })
        vim.cmd 'bdelete'
        return
      end
    end

    vim.notify('No suitable application found for opening ' .. file_path, vim.log.levels.WARN)
  end
end

local file_associations = {
  pdf = { 'zathura', 'browser' }, -- or "tdf"
  -- png = "feh",
  -- mp4 = "mpv",
}

-- local preview_associations = {
--   md = { 'zathura', 'browser' },
--   html = { 'zathura', 'browser' },
-- }

for ext, apps in pairs(file_associations) do
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    pattern = '*.' .. ext,
    callback = open_with_app(apps),
  })
end

-- vim.keymap.set('n', '<leader>o', function()
--   local file_path = vim.fn.expand '%:p'
--   local ext = vim.fn.expand '%:e'
--
--   local apps = preview_associations[ext]
--   if apps then
--     open_with_app(apps)()
--   else
--     vim.fn.jobstart({ 'xdg-open', file_path }, { detach = true })
--   end
-- end, { desc = 'Preview file with external application' })

-- Easy build and execute --
local lang_maps = {
  arduino = {
    build = 'arduino-cli compile --fqbn arduino:avr:uno %',
    run = 'arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno %',
    clean = 'rm -rf build/',
  },
  c = { build = 'gcc *.c -lm -g -o main', run = './main', clean = 'rm -f main' },
  clojure = { run = 'lein run' },
  cpp = {
    build = 'mkdir -p build && cd build && cmake .. && make',
    run = 'cd build && ./main',
    clean = 'rm -rf build/',
  },
  elixir = { run = 'mix run' },
  gleam = { run = 'gleam run' },
  go = { build = 'go build', run = 'go run %', clean = 'go clean && rm -f main' },
  haskell = { run = 'cabal run' },
  java = { build = 'javac %', run = 'java %:r', clean = 'rm -f *.class' },
  javascript = { run = 'bun %' },
  python = { run = 'python %' },
  rust = { run = 'cargo run' },
  sh = { run = '%' },
  tex = { build = 'pdflatex -shell-escape %' },
  typescript = { run = 'bun %' },
  typst = { build = 'typst compile %' },
}

for lang, data in pairs(lang_maps) do
  local f, _ = io.open('Makefile', 'r')
  if f then
    data.build = 'make build'
    data.run = 'make run'
    data.clean = 'make clean'
    f:close()
  end

  -- --TODO: add cmakelists detection for easy build execute and clean
  -- if vim.fn.filereadable 'CMakeLists.txt' == 1 then
  --   data.build = ''
  --   data.run = ''
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

  if data.run ~= nil then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = lang,
      callback = function()
        vim.keymap.set('n', '<Leader>cx', ':split<CR>:terminal ' .. data.run .. '<CR>', {
          desc = 'Execute: ' .. data.run,
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
