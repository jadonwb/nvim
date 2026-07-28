return {
  'alex35mil/delta.nvim',
  event = 'VeryLazy',

  config = function(_, opts)
    require('delta').setup(opts)
    -- Label delta file diff tabs via buffer name pattern (delta://diff/*)
    vim.api.nvim_create_autocmd('BufEnter', {
      group = vim.api.nvim_create_augroup('delta-tab-label', { clear = true }),
      callback = function()
        local name = vim.api.nvim_buf_get_name(0)
        if name:match '^delta://diff/' then
          vim.api.nvim_tabpage_set_var(vim.api.nvim_get_current_tabpage(), 'tab_label', '  diff')
          pcall(require('lualine').refresh, { place = 'tabline' })
        end
      end,
    })
  end,

  opts = function()
    local pi_ok, pi = pcall(require, 'pi')
    local delta = require 'delta'
    local picker = delta.picker
    local spotlight = delta.spotlight

    -- ── custom action: send file to pi as @mention ──────
    local function send_to_pi(close_after)
      return function(ctx)
        local node = ctx.node
        if not node or not node.path or node.path == '' then
          return
        end
        if pi_ok then
          pi.send_mention({ path = node.path }, { focus = false })
          if close_after then
            ctx.close()
            pi.focus_chat_prompt()
          end
        end
      end
    end

    -- ── custom action: open file, switching pi to side if float ──
    local function open_with_pi_side(action)
      return function(ctx)
        if pi_ok and pi.is_visible and pi.is_visible() and pi.layout and pi.layout() == 'float' then
          pi.toggle_layout(function()
            action(ctx)
          end)
        else
          action(ctx)
        end
      end
    end

    local border_none = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }

    return {
      picker = {
        initial_mode = 'n',
        layout = {
          height = { 0.5, 0.9 },
          main = {
            width = 0.25,
            border = border_none,
            title = function(source)
              local icon = source == 'agent' and '󰫮󰫴󰫲󰫻󰬁' or '󰫴󰫶󰬁'
              return ' Delta ' .. icon .. ' '
            end,
          },
          preview = {
            enabled = false,
            width = 0.5,
            border = border_none,
          },
        },
        sources = {
          git = { label = 'Git' },
          agent = pi_ok and { label = 'Agent', files = pi.changed_files } or nil,
        },
        actions = {
          open = { '<CR>', open_with_pi_side(picker.actions.open) },
          open_vsplit = { '<C-v>', open_with_pi_side(picker.actions.open_vsplit) },
          open_hsplit = { '<C-x>', open_with_pi_side(picker.actions.open_hsplit) },
          spotlight = { '<S-CR>', open_with_pi_side(picker.actions.spotlight) },
          send_to_pi = { '<C-p>', send_to_pi(false) },
          send_to_pi_and_close = { '<Leader>p', send_to_pi(true) },
          move_up = { { { 'k', modes = 'n' }, '<Up>' }, picker.actions.move(-1) },
          move_down = { { { 'j', modes = 'n' }, '<Down>' }, picker.actions.move(1) },
          close = { { '<Esc>', modes = 'n' }, picker.actions.close },
          close_q = { { 'q', modes = 'n' }, picker.actions.close },
          toggle_preview = { '<C-S-p>', picker.actions.toggle_preview },
          cycle_source = { '<Tab>', picker.actions.cycle_source },
          cycle_source_back = { '<S-Tab>', picker.actions.cycle_source_back },
          toggle_stage = { '<C-CR>', picker.actions.toggle_stage },
          reset = { 'R', picker.actions.reset },
        },
      },

      spotlight = {
        title = '󱦇 Spotlight',
        autosave_before_stage = true,
        reopen_picker_after_stage = true,
        actions = {
          -- ── hunk navigation (global so they work even when spotlight isn't focused) ──
          next_hunk = { ']h', spotlight.actions.next_hunk, global = true },
          prev_hunk = { '[h', spotlight.actions.prev_hunk, global = true },
          -- ── spotlight-only actions (auto-cleared when spotlight exits) ──
          toggle_stage_hunk = { '<CR>', spotlight.actions.toggle_stage_hunk },
          reset_hunk = { { 'gr', modes = { 'n', 'v' } }, spotlight.actions.reset_hunk },
          reset_file = { 'gR', spotlight.actions.reset_file },
          expand_context = { '+', spotlight.actions.expand_context },
          shrink_context = { '-', spotlight.actions.shrink_context },
          cycle_mode = { 'm', spotlight.actions.cycle_mode },
          exit = { 'q', spotlight.actions.exit },
          -- ── open hunk diff popup from within spotlight ──
          open_hunk_popup = {
            { 'gd', modes = 'n' },
            function()
              require('delta.diff').open_hunk()
            end,
          },
        },
      },

      diff = {
        file = {
          keys = {
            close = 'q',
          },
        },
        hunk = {
          mode = 'auto',
          layout = {
            border = border_none,
          },
          keys = {
            scroll_up = '<C-u>',
            scroll_down = '<C-d>',
            focus_left = { '<Tab>', '<Left>' },
            focus_right = { '<Tab>', '<Right>' },
            close = { 'q', '<Esc>' },
          },
        },
      },

      reset = {
        confirm = true,
      },
    }
  end,

  keys = {
    {
      '<Leader>gp',
      function()
        require('delta.picker').toggle()
      end,
      desc = 'Delta Picker (changed files)',
    },
    {
      '<Leader>gP',
      function()
        require('delta.picker').toggle { source = 'agent' }
      end,
      desc = 'Delta Picker (agent changes)',
    },
    {
      '<Leader>gs',
      function()
        require('delta.spotlight').toggle()
      end,
      desc = 'Delta Spotlight (inline hunks)',
    },
    {
      'gD',
      function()
        require('delta.diff').open_file()
      end,
      mode = 'n',
      desc = 'Delta File Diff',
    },
    {
      'gd',
      function()
        require('delta.diff').open_hunk()
      end,
      mode = 'n',
      desc = 'Delta Hunk Diff',
    },
    {
      ']h',
      mode = 'n',
      desc = 'Delta Next Hunk (load)',
    },
    {
      '[h',
      mode = 'n',
      desc = 'Delta Prev Hunk (load)',
    },
  },
}
