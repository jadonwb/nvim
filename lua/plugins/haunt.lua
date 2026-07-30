return {
  'TheNoeTrevino/haunt.nvim',
  -- default config: change to your liking, or remove it to use defaults
  ---@class HauntConfig
  opts = {
    sign = '󱙝',
    sign_hl = 'DiagnosticInfo',
    virt_text_hl = 'HauntAnnotation',
    annotation_prefix = ' 󰆉 ',
    line_hl = nil,
    virt_text_pos = 'eol',
    data_dir = nil,
    picker_keys = {
      delete = { key = 'd', mode = { 'n' } },
      edit_annotation = { key = 'a', mode = { 'n' } },
    },
  },
  -- recommended keymaps, with a helpful prefix alias
  init = function()
    local wk = require 'which-key'
    local haunt = require 'haunt.api'
    local haunt_picker = require 'haunt.picker'

    wk.add {
      { '<leader>h', group = 'Haunt', icon = '󱙝' },

      { '<leader>ha', mode = 'n', haunt.annotate, desc = 'Annotate', icon = '' },
      { '<leader>ht', mode = 'n', haunt.toggle_all_lines, desc = 'Toggle all annotations' },
      { '<leader>hd', mode = 'n', haunt.delete, desc = 'Delete bookmark', icon = '' },
      { '<leader>hD', mode = 'n', haunt.clear_all, desc = 'Delete all bookmarks', icon = '' },

      { '[n', mode = 'n', haunt.prev, desc = 'Previous bookmark', icon = '' },
      { ']n', mode = 'n', haunt.next, desc = 'Next bookmark', icon = '' },

      { '<leader>hl', mode = 'n', haunt_picker.show, desc = 'Picker' },

      { '<leader>hq', mode = 'n', haunt.to_quickfix, desc = 'Quickfix (all)' },
      {
        '<leader>hQ',
        mode = 'n',
        function()
          haunt.to_quickfix { current_buffer = true }
        end,
        desc = 'Quickfix (buffer)',
      },

      {
        '<leader>hy',
        mode = 'n',
        function()
          haunt.yank_locations { current_buffer = true }
        end,
        desc = 'Yank locations (buffer)',
      },
      { '<leader>hY', mode = 'n', haunt.yank_locations, desc = 'Yank locations (all)', icon = '' },

      {
        '<leader>hs',
        mode = 'n',
        function()
          local bookmarks = require('haunt.api').get_bookmarks()
          if vim.tbl_isempty(bookmarks) then
            vim.notify('No bookmarks to send', vim.log.levels.WARN)
            return
          end
          local pi = require('pi')
          for _, bm in ipairs(bookmarks) do
            pi.send_mention(
              { path = bm.file, start_line = bm.line, note = bm.note },
              { focus = false }
            )
          end
          pi.focus_chat_prompt()
          vim.notify(string.format('Sent %d haunt(s) to Pi', #bookmarks), vim.log.levels.INFO)
        end,
        desc = 'Send to Pi',
      },
    }
  end,
}
