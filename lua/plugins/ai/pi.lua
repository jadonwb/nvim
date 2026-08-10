NVPi = {
  -- 'jadonwb/pi.nvim',
  dir = '~/c/pi.nvim',
  dependencies = { 'HakonHarnes/img-clip.nvim' },
  opts = function()
    NVCompanionPanels.register('pi_side', function()
      if NVPi.is_visible() and NVPi.is_side() then
        NVPi.toggle()
        return true
      end
      return false
    end)
    return {
      -- debug = true,
      expand_startup_details = false,
      show_thinking = false,
      -- models = {},
      cli = {
        bin = 'pi',
        args = {
          '--approve',
          '--fff-mode',
          'tools-and-ui', -- adds fffind/ffgrep as extra tools + FFF @ autocomplete
        },
      },
      layout = {
        side = function()
          return {
            position = 'right',
            width = NVCompanionPanels.width(),
          }
        end,
        float = function()
          local size = NVScreen.is_large() and { width = 0.65, height = 0.85 } or { width = 0.8, height = 0.85 }
          return {
            width = size.width,
            height = size.height,
            border = NVBorders.rounded,
          }
        end,
      },
      panels = {
        history = {
          name = function(tab_id)
            return 'π  󰫰󰫵󰫮󰬁  ' .. tab_id
          end,
        },
        prompt = {
          name = function(tab_id)
            return 'π  󰫽󰫿󰫼󰫺󰫽󰬁  ' .. tab_id
          end,
        },
      },
      diff = {
        icons = {
          note = '󰣒',
        },
        keys = {
          accept = { '<C-CR>', modes = { 'n', 'i', 'v' } },
          reject = { '<C-c>', modes = { 'n', 'i', 'v' } },
          edit_note = '<C-S-n>',
          delete_note = '<C-S-x>',
          list_notes = '<M-S-l>',
          expand_context = { '+', modes = { 'n' } },
          shrink_context = { '-', modes = { 'n' } },
        },
      },
      statusline = {
        layout = {
          left = {
            'context',
            '  ',
            function(state)
              if state.extensions['permission'] then
                return '󰐌', 'PiStatusLineOn'
              end
            end,
            '  ',
            'attention',
          },
          right = { 'model', '   ', 'thinking' },
        },
      },
      dialog = {
        border = NVBorders.rounded,
        keys = {
          cancel = { { NVKeymaps.close, modes = { 'n', 'i' } }, { NVKeymaps.close_esc, modes = { 'n', 'i' } } },
        },
      },
      zen = {
        keys = {
          toggle = { '<M-f>', modes = { 'n', 'i', 'v' } },
          exit = { { NVKeymaps.close, modes = { 'n', 'i', 'v' } }, { NVKeymaps.close_esc, modes = { 'n' } } },
        },
      },
      on_widget = function(key, lines)
        if key == 'rules:load' then
          local content = {}
          for _, line in ipairs(lines) do
            content[#content + 1] = {
              { '   ╰  rule: ' .. line, 'Comment' },
            }
          end
          return {
            target = 'history',
            block = 'custom',
            content = content,
          }
        end
        return nil
      end,
    }
  end,
  keys = function()
    return {
      {
        '<leader>af',
        function()
          return NVPi.toggle 'float'
        end,
        mode = { 'n', 'v' },
        desc = 'Toggle π in a float layout',
      },
      {
        '<leader>ai',
        function()
          if not NVCompanionPanels.ensure_exclusive 'pi_side' then
            return
          end
          return NVPi.toggle 'side'
        end,
        mode = { 'n', 'v' },
        desc = 'Toggle π in a side layout',
      },
      {
        '<leader>as',
        function()
          vim.cmd 'PiContinue'
        end,
        mode = { 'n', 'v' },
        desc = 'Continue last π session',
      },
      {
        '<leader>al',
        function()
          vim.cmd 'PiResume'
        end,
        mode = { 'n', 'v' },
        desc = 'Select past π session',
      },
      {
        '<A-a>',
        function()
          -- FIXME: if no pi session is open yet, needs to open it
          local skip = NVPi.is_visible() and NVPi.is_side()
          if not skip then
            if not NVCompanionPanels.ensure_exclusive 'pi_side' then
              return
            end
          end
          vim.cmd 'PiToggleChat'
        end,
        mode = { 'n', 'i', 'v' },
        desc = 'Toggle π layout (side/float)',
      },
      {
        '<A-S-a>',
        function()
          local skip = NVPi.is_visible() and NVPi.is_side()
          if not skip then
            if not NVCompanionPanels.ensure_exclusive 'pi_side' then
              return
            end
          end
          vim.cmd 'PiToggleLayout'
        end,
        mode = { 'n', 'i', 'v' },
        desc = 'Toggle π layout (side/float)',
      },
      {
        '<leader>am',
        function()
          vim.cmd 'PiSendMention'
        end,
        mode = { 'n', 'v' },
        desc = 'Send @-mention to π and focus the chat',
      },
      {
        '<leader>an',
        function()
          vim.cmd 'PiAttention'
        end,
        mode = { 'n', 'v' },
        desc = 'Give an agent a bit of attention',
      },
    }
  end,
}

function NVPi.autocmds()
  local pi = require 'pi'

  local group = vim.api.nvim_create_augroup('pi-custom-keybinds', { clear = true })

  local keymap = function(key, event, action, modes)
    vim.keymap.set(modes or { 'n', 'i', 'v' }, key, action, { buffer = event.buf })
  end

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'pi-chat-history', 'pi-chat-prompt', 'pi-chat-attachments' },
    callback = function(event)
      keymap(NVKeymaps.close, event, function()
        vim.cmd 'PiToggleChat'
      end)
      keymap(NVKeymaps.close_esc, event, function()
        vim.cmd 'PiToggleChat'
      end, { 'n' })
      keymap('<C-c>', event, function()
        vim.cmd 'PiAbort'
      end)
      keymap('<C-o>', event, function()
        pi.toggle_history_blocks()
      end)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'pi-chat-history' },
    callback = function(event)
      keymap('&', event, function()
        pi.focus_chat_prompt()
        pi.scroll_chat_history_to_bottom()
      end)
      keymap(NVKeymaps.window_move.down, event, function()
        pi.focus_chat_prompt()
      end)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'pi-chat-prompt' },
    callback = function(event)
      keymap(NVKeymaps.window_move.up, event, function()
        pi.focus_chat_history()
      end)
      keymap(NVKeymaps.window_move.down, event, function()
        pi.focus_chat_attachments()
      end)
      keymap(NVKeymaps.scroll_ctx.up, event, function()
        pi.scroll_chat_history('up', 2)
      end)
      keymap(NVKeymaps.scroll_ctx.down, event, function()
        pi.scroll_chat_history('down', 2)
      end)
      keymap(NVKeymaps.scroll.up, event, function()
        pi.scroll_chat_history 'up'
      end)
      keymap(NVKeymaps.scroll.down, event, function()
        pi.scroll_chat_history 'down'
      end)
      keymap('<C-{>', event, function()
        pi.scroll_chat_history_to_last_agent_response()
      end)
      keymap('<C-}>', event, function()
        pi.scroll_chat_history_to_first_agent_response()
      end)
      keymap('<C-(>', event, function()
        pi.scroll_chat_history_to_bottom()
      end)
      keymap('<S-Tab>', event, function()
        pi.invoke '/permission-toggle-auto-accept'
      end)
      keymap('<A-m>', event, function()
        pi.select_model()
      end)
      keymap('<A-t>', event, function()
        pi.select_thinking_level()
      end)
      keymap('<C-v>', event, function()
        pi.paste_image()
      end)
      keymap('<C-S-n>', event, function()
        pi.new_session()
      end)
      keymap('<C-S-r>', event, function()
        pi.set_session_name()
      end)
      keymap('<C-S-x>', event, function()
        pi.compact()
      end)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'pi-chat-attachments' },
    callback = function(event)
      keymap(NVKeymaps.window_move.up, event, function()
        pi.focus_chat_prompt()
      end)
      keymap('<C-v>', event, function()
        pi.paste_image()
      end)
    end,
  })
end

function NVPi.open_float()
  vim.cmd 'Pi layout=float'
end

function NVPi.toggle(layout)
  local ok, pi = pcall(require, 'pi')
  if ok and pi.toggle then
    if not layout then
      pi.toggle()
    else
      pi.toggle { layout = layout }
    end
  end
end

function NVPi.is_visible()
  local ok, pi = pcall(require, 'pi')
  if ok and pi.is_visible then
    return pi.is_visible()
  end
  return false
end

function NVPi.is_side()
  local ok, pi = pcall(require, 'pi')
  if ok and pi.layout then
    return pi.layout() == 'side'
  end
  return false
end

return { NVPi }
