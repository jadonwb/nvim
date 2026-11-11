-- Editing behaviour.
--
-- Session persistence and the panel registry are needed before any feature
-- sets up; the rest of the editor modules are loaded by their feature or by the
-- startup spec in lua/plugins/editor.lua.

require 'editor.session'
require 'features.layout.panels'
