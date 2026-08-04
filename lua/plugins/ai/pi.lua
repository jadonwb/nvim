local borders = require 'config.borders'

NVPi = {
  -- 'jadonwb/pi.nvim',
  dir = '~/c/pi.nvim',
  dependencies = { 'HakonHarnes/img-clip.nvim' },
  opts = {
    -- debug = true,
    expand_startup_details = false,
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
          width = NVScreen.is_large() and 0.40 or 0.50,
        }
      end,
      float = function()
        local size = NVScreen.is_large() and { width = 0.6, height = 0.85 } or { width = 0.8, height = 0.85 }
        return {
          width = size.width,
          height = size.height,
          border = 'rounded',
          -- border = borders.bottom_hr,
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
      border = borders.padded,
      keys = {
        confirm = { { '<C-CR>', modes = { 'n', 'i' } } },
        cancel = { { NVKeymaps.close, modes = { 'n', 'i' } }, { NVKeymaps.close_esc, modes = { 'n', 'i' } } },
      },
    },
    zen = {
      keys = {
        toggle = { '<M-f>', modes = { 'n', 'i', 'v' } },
        exit = { { NVKeymaps.close, modes = { 'n', 'i', 'i' } }, { NVKeymaps.close_esc, modes = { 'h' } } },
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
  },
  keys = function()
    return {
      {
        '<leader>af',
        function()
          vim.cmd 'Pi layout=float'
        end,
        mode = { 'n', 'v' },
        desc = 'Toggle π in a float layout',
      },
      {
        '<leader>ai',
        function()
          vim.cmd 'Pi layout=side'
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
        '<M-S-p>',
        function()
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
      keymap('<C-j>', event, function()
        pi.focus_chat_prompt()
      end)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'pi-chat-prompt' },
    callback = function(event)
      keymap('<C-k>', event, function()
        pi.focus_chat_history()
      end)
      keymap('<C-j>', event, function()
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
      keymap('<C-S-m>', event, function()
        pi.select_model()
      end)
      keymap('<C-m>', event, function()
        pi.cycle_model()
      end)
      keymap('<C-S-t>', event, function()
        pi.select_thinking_level()
      end)
      keymap('<C-t>', event, function()
        pi.cycle_thinking_level()
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
      keymap('<C-k>', event, function()
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

function NVPi.is_visible()
  local ok, pi = pcall(require, 'pi')
  if ok and pi.is_visible then
    return pi.is_visible()
  end
  return false
end

function NVPi.ensure_hidden()
  if NVPi.is_visible() then
    vim.cmd 'PiToggleChat'
    return true
  end
  return false
end

return { NVPi }
