-- Load order matters: options set the leader and global behaviour before any
-- plugin spec is evaluated, core registers the globals every other module
-- references, editor brings the session and panel registry, ui2 patches the
-- message layer, and lazy.nvim starts last.
require 'config.options'
require 'config.autocmds'

require 'core'
require 'editor'

require 'config.ui2'
-- vim.notify goes to the notification centre (toasts) from the very start, so
-- messages sent while plugins load are styled like every other one.
require('features.ui.notify').install()
require('config.highlights').setup_autocmds()

require 'config.lazy'
