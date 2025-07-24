-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    vim.opt.formatoptions:remove { 'c', 'r', 'o' }
  end,
  group = vim.api.nvim_create_augroup('disable_newline_comment', { clear = true }),
  desc = 'Disable New Line Comment',
})

local function open_with_app(apps)
  return function()
    if type(apps) == 'string' then
      apps = { apps }
    end

    local file_path = vim.fn.expand '%:p'

    for _, app in ipairs(apps) do
      if app == 'default' then
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
  pdf = { 'default' },
}

for ext, apps in pairs(file_associations) do
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    pattern = '*.' .. ext,
    callback = open_with_app(apps),
  })
end

vim.keymap.set('n', '<leader>o', function()
  local file_path = vim.fn.expand '%:p'
  local ext = vim.fn.expand '%:e'
  vim.fn.jobstart({ 'xdg-open', file_path }, { detach = true })
end, { desc = 'Open file with default application' })

local lang_maps = {
  arduino = {
    build = 'arduino-cli compile --fqbn arduino:avr:uno %',
    run = 'arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno %',
    clean = 'rm -rf build/',
  },
  c = { build = 'gcc *.c -lm -g -o main', run = './main', clean = 'rm -f main' },
  cpp = {
    build = 'mkdir -p build && cd build && cmake .. && make',
    run = 'cd build && ./main',
    clean = 'rm -rf build/',
  },
  go = { build = 'go build', run = 'go run %', clean = 'go clean && rm -f main' },
  java = { build = 'javac %', run = 'java %:r', clean = 'rm -f *.class' },
  python = { run = 'python %' },
  rust = { run = 'cargo run' },
  sh = { run = '%' },
}

for lang, data in pairs(lang_maps) do
  local f, _ = io.open('Makefile', 'r')
  if f then
    data.build = 'make build'
    data.run = 'make run'
    data.clean = 'make clean'
    f:close()
  end

  --TODO: add cmakelists detection for easy build execute and clean
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

local augroup = vim.api.nvim_create_augroup('UserConfig', {})

vim.api.nvim_create_autocmd('TermClose', {
  group = augroup,
  callback = function()
    if vim.v.event.status == 0 then
      vim.api.nvim_buf_delete(0, {})
    end
  end,
})

vim.api.nvim_create_autocmd('TermOpen', {
  group = augroup,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end,
})

vim.api.nvim_create_autocmd('VimResized', {
  group = augroup,
  callback = function()
    vim.cmd 'tabdo wincmd ='
  end,
})

vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup,
  callback = function()
    local dir = vim.fn.expand '<afile>:p:h'
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
  end,
})

vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    local colorscheme_file = vim.fn.expand '~/.config/nvim/colorscheme.txt'
    local file = io.open(colorscheme_file, 'r')

    if file then
      local colorscheme = file:read '*line'
      file:close()

      if colorscheme and colorscheme ~= '' then
        colorscheme = colorscheme:gsub('^%s*(.-)%s*$', '%1')

        local ok, err = pcall(vim.cmd, 'colorscheme ' .. colorscheme)
        if ok then
          vim.cmd 'doautocmd ColorScheme'
        end
      end
    end
  end,
})
