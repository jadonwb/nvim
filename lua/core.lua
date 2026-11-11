-- Shared primitives.
--
-- Everything here is used by more than one feature and knows nothing about any
-- particular one: keymap plumbing, messages, screen geometry, borders, icons,
-- filesystem and clipboard helpers, environment detection, the close stack and
-- the tab type registry.
--
-- Loaded before any feature module, in this order.

require 'types'

require 'core.keymap'
require 'core.messages'
require 'core.screen'
require 'core.borders'
require 'core.keys'
require 'core.icons'
require 'core.fs'
require 'core.clipboard'
require 'core.environment'

require 'core.close'
require 'core.tabs'
require 'core.dialogs'
