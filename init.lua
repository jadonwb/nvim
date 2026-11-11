-- Load order matters: options set the leader and global behaviour before any
-- plugin spec is evaluated, editor modules register the globals other files
-- reference, ui2 patches the message layer, and lazy.nvim starts last.
require 'config.options'
require 'config.autocmds'

require 'editor'
require 'config.ui2'

require 'config.lazy'
