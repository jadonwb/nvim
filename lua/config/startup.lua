local M = {}

local function deferred(layout, agent)
  local function step(name, fn)
    local ok, err = pcall(fn)
    if not ok then
      NVMessages.warn(('Startup (%s): %s'):format(name, err))
    end
  end
  local function module(name, method)
    step(name, function()
      require(name)[method]()
    end)
  end

  module('editor.editing', 'keymaps')
  module('editor.ui-toggles', 'keymaps')
  step('window keys', NVWindows.keymaps)
  step('buffer keys', NVBuffers.keymaps)
  module('editor.navigation', 'keymaps')
  if layout then
    module('features.layout.terminals', 'mode_keymaps')
    module('features.layout.keymaps', 'setup')
  end
  if agent then
    module('features.opencode.attach', 'keymaps')
    module('features.opencode.context', 'keymaps')
    module('features.opencode.pickers', 'keymaps')
    module('features.opencode.requests', 'keymaps')
  end
end

function M.setup()
  -- Set the leader, install compatibility APIs, and intercept UI calls before
  -- plugin specs are evaluated.
  require 'core.compat'
  require 'config.options'
  require 'config.autocmds'
  require 'core'
  require 'features.ui.dialogs'
  require 'features.ui.ui2'
  require('features.ui.notify').setup()
  require('config.highlights').setup_autocmds()

  local session = require 'editor.session'
  session.prepare_restart()
  local profile = require 'config.profile'
  local layout, agent = profile.wants 'layout', profile.wants 'agent'
  require 'editor.quit'
  require 'editor.buffers'
  NVBuffers.autocmds()
  require 'editor.windows'
  session.autocmds()
  require 'features.layout.panels'
  require 'features.layout.slots'
  if layout or profile.wants 'gutter' then
    NVSlots.setup()
  end
  if layout then
    require('features.layout.data').setup()
    require 'features.layout.bottom'
    NVBottom.setup()
    NVTerminals.setup()
  end

  require 'editor.help'
  NVHelp.setup()
  require 'core.class'
  require 'features.lsp.ui'
  require('features.quickfix').setup()
  require('features.preview').setup()
  require('features.compare').setup()
  require('features.cheatsheet').setup()
  if profile.wants 'format' then
    require 'editor.format'
    NVFormat.setup()
  end
  if profile.wants 'languages' then
    require('features.extras').setup()
  end
  if agent then
    require('features.bridge').setup()
    require('features.opencode.attach').setup()
  end

  vim.api.nvim_create_autocmd('User', {
    group = vim.api.nvim_create_augroup('NV startup', { clear = true }),
    pattern = 'VeryLazy',
    once = true,
    callback = function()
      vim.schedule(function()
        deferred(layout, agent)
      end)
    end,
  })
  require 'config.lazy'
end

return M
