return {
  'alex35mil/pi.nvim',
  dependencies = { 'HakonHarnes/img-clip.nvim' },
  opts = {
    -- ── pi binary & pi-fff integration ──────────────────────
    cli = {
      bin = 'pi',
      args = {
        '--fff-mode',
        'tools-and-ui', -- adds fffind/ffgrep as extra tools + FFF @ autocomplete
      },
    },

    -- ── models ──────────────────────────────────────────────
    models = {
      -- { match = 'opus', latest = true },
      -- add more models as needed, e.g.:
      -- { match = 'sonnet', latest = true },
      -- { match = 'gpt-5', exact = true },
    },

    -- ── startup ─────────────────────────────────────────────
    expand_startup_details = false,

    -- ── layout: responsive to screen width ──────────────────
    layout = {
      default = 'side',
      side = function()
        local wide = vim.o.columns >= 180
        return {
          position = 'right',
          width = wide and 0.35 or 0.45,
        }
      end,
      float = function()
        local wide = vim.o.columns >= 180
        return {
          width = wide and 0.6 or 0.8,
          height = 0.85,
          border = 'rounded',
        }
      end,
    },

    -- ── statusline ──────────────────────────────────────────
    statusline = {
      layout = {
        left = {
          'context',
          '  ',
          -- show permission status from agentic-af extension
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

    -- ── diff review keys ────────────────────────────────────
    diff = {
      keys = {
        accept = '<Leader>da',
        reject = '<Leader>dr',
        edit_note = '<Leader>dn',
        delete_note = '<Leader>dx',
        list_notes = '<Leader>dN',
        expand_context = '+',
        shrink_context = '-',
      },
    },

    -- ── zen mode ────────────────────────────────────────────
    zen = {
      keys = {
        toggle = { '<M-z>', modes = { 'n', 'i' } },
        exit = { { '<Esc>', modes = 'n' } },
      },
    },

    -- ── dialog ──────────────────────────────────────────────
    dialog = {
      keys = {
        confirm = { { '<C-CR>', modes = { 'n', 'i' } } },
      },
    },
  },

  -- ── global keymaps ────────────────────────────────────────
  keys = {
    {
      '<Leader>pa',
      function()
        vim.cmd 'Pi layout=side'
      end,
      mode = { 'n', 'v' },
      desc = 'Pi (side panel)',
    },
    {
      '<Leader>pA',
      function()
        vim.cmd 'Pi layout=float'
      end,
      mode = { 'n', 'v' },
      desc = 'Pi (float)',
    },
    {
      '<Leader>pt',
      '<Cmd>PiToggleLayout<CR>',
      mode = { 'n', 'v' },
      desc = 'Pi Toggle Layout',
    },
    {
      '<Leader>pc',
      '<Cmd>PiContinue<CR>',
      mode = { 'n', 'v' },
      desc = 'Pi Continue Session',
    },
    {
      '<Leader>pr',
      '<Cmd>PiResume<CR>',
      mode = { 'n', 'v' },
      desc = 'Pi Resume Session',
    },
    {
      '<Leader>pm',
      '<Cmd>PiSendMention<CR>',
      mode = { 'n', 'v' },
      desc = 'Pi Send Mention',
    },
    {
      '<Leader>pn',
      '<Cmd>PiAttention<CR>',
      mode = { 'n', 'v' },
      desc = 'Pi Attention',
    },
    {
      '<Leader>pC',
      '<Cmd>PiToggleChat<CR>',
      mode = { 'n', 'v' },
      desc = 'Pi Toggle Chat',
    },
  },

  -- ── buffer-local keymaps inside pi windows ────────────────
  config = function(_, opts)
    require('pi').setup(opts)

    local pi = require 'pi'
    local group = vim.api.nvim_create_augroup('pi-custom-keybinds', { clear = true })

    local function map(buf, key, action, modes)
      vim.keymap.set(modes or { 'n', 'i', 'v' }, key, action, { buffer = buf })
    end

    -- Shared across all pi windows
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = { 'pi-chat-history', 'pi-chat-prompt', 'pi-chat-attachments' },
      callback = function(event)
        map(event.buf, '<C-q>', '<Cmd>PiToggleChat<CR>')
        map(event.buf, '<M-c>', '<Cmd>PiAbort<CR>')
        map(event.buf, '<C-o>', pi.toggle_history_blocks)
      end,
    })

    -- History window
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'pi-chat-history',
      callback = function(event)
        map(event.buf, '<S-Down>', pi.focus_chat_prompt)
      end,
    })

    -- Prompt window
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'pi-chat-prompt',
      callback = function(event)
        map(event.buf, '<S-Up>', pi.focus_chat_history)
        map(event.buf, '<S-Down>', pi.focus_chat_attachments)
        map(event.buf, '<C-Up>', function()
          pi.scroll_chat_history('up', 2)
        end)
        map(event.buf, '<C-Down>', function()
          pi.scroll_chat_history('down', 2)
        end)
        map(event.buf, '<M-m>', pi.cycle_model)
        map(event.buf, '<M-M>', pi.select_model)
        map(event.buf, '<M-t>', pi.cycle_thinking_level)
        map(event.buf, '<M-T>', pi.select_thinking_level)
        map(event.buf, '<M-n>', pi.new_session)
        map(event.buf, '<M-x>', pi.compact)
        map(event.buf, '<C-v>', pi.paste_image)
        map(event.buf, '<S-Tab>', function()
          pi.invoke '/permission-toggle-auto-accept'
        end)
      end,
    })

    -- Attachments window
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'pi-chat-attachments',
      callback = function(event)
        map(event.buf, '<S-Up>', pi.focus_chat_prompt)
        map(event.buf, '<C-v>', pi.paste_image)
      end,
    })
  end,
}
