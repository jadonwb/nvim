-- TODO!: modularize and stuff!
return {
  'alex35mil/delta.nvim',
  lazy = false,

  config = function(_, opts)
    require('delta').setup(opts)
    -- Label delta file diff tabs via buffer name pattern (delta://diff/*)
    vim.api.nvim_create_autocmd('BufEnter', {
      group = vim.api.nvim_create_augroup('delta-tab-label', { clear = true }),
      callback = function()
        local name = vim.api.nvim_buf_get_name(0)
        if name:match '^delta://diff/' then
          vim.api.nvim_tabpage_set_var(vim.api.nvim_get_current_tabpage(), 'tab_label', '  diff')
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

    local borders = require 'config.borders'
    local hunk_border = borders.padded
    local picker_border = 'rounded'

    return {
      picker = {
        initial_mode = 'n',
        layout = {
          height = { 0.5, 0.9 },
          main = {
            width = 0.25,
            border = picker_border,
            title = function(source)
              local label
              if source == 'git' then
                label = '󰫴󰫶󰬁'
              elseif source == 'agent' then
                label = '󰫮󰫴󰫲󰫻󰬁'
              end
              return ' 󰫱󰫲󰫹󰬁󰫮' .. ' ⋆ ' .. label .. ' '
            end,
          },
          preview = {
            enabled = false,
            width = 0.5,
            border = picker_border,
          },
        },
        sources = {
          git = { label = 'git' },
          agent = pi_ok and { label = 'agent', files = pi.changed_files } or nil,
          -- chezmoi = { label = 'Chezmoi', files = "" }, -- TODO: implement, call chezmoi status and parse lines?
        },
        actions = {
          open = { NVKeymaps.confirm, open_with_pi_side(picker.actions.open) },
          open_vsplit = { NVKeymaps.open_vsplit, open_with_pi_side(picker.actions.open_vsplit) },
          open_hsplit = { NVKeymaps.open_hsplit, open_with_pi_side(picker.actions.open_hsplit) },
          spotlight = { NVKeymaps.confirm_alt, open_with_pi_side(picker.actions.spotlight) },
          collapse = { { 'h', modes = 'n' }, picker.actions.collapse },
          expand = { { 'l', modes = 'n' }, picker.actions.expand },
          send_to_pi = { '<C-a>', send_to_pi(false) },
          send_to_pi_and_close = { '<C-S-a>', send_to_pi(true) },
          jump_up = { NVKeymaps.scroll.up, picker.actions.move(-5) },
          jump_down = { NVKeymaps.scroll.down, picker.actions.move(5) },
          jump_top = { { 'gg', modes = 'n' }, picker.actions.move_to_top },
          jump_bottom = { { 'G', modes = 'n' }, picker.actions.move_to_bottom },
          scroll_left = { NVKeymaps.scroll_side.left, picker.actions.scroll_horizontal(-8) }, -- FIXME: why not working?
          scroll_right = { NVKeymaps.scroll_side.right, picker.actions.scroll_horizontal(8) },
          scroll_preview_up = { NVKeymaps.scroll_ctx.up, picker.actions.scroll_preview(-5) },
          scroll_preview_down = { NVKeymaps.scroll_ctx.down, picker.actions.scroll_preview(5) },
          move_up = { { { 'k', modes = 'n' }, '<C-p>' }, picker.actions.move(-1) },
          move_down = { { { 'j', modes = 'n' }, '<C-n>' }, picker.actions.move(1) },
          close = { { NVKeymaps.close, { '<Esc>', modes = 'n' } }, picker.actions.close },
          toggle_preview = { '<C-S-p>', picker.actions.toggle_preview },
          toggle_stage = { NVKeymaps.confirm_alt, picker.actions.toggle_stage },
          reset = { { '<C-x>', modes = 'n' }, picker.actions.reset },
        },
      },

      spotlight = {
        actions = {
          -- ── hunk navigation (global so they work even when spotlight isn't focused) ──
          next_hunk = { ']h', spotlight.actions.next_hunk, global = true },
          prev_hunk = { '[h', spotlight.actions.prev_hunk, global = true },
          -- ── spotlight-only actions (auto-cleared when spotlight exits) ──
          toggle_stage_hunk = { NVKeymaps.confirm, spotlight.actions.toggle_stage_hunk },
          reset_file = { '<C-S-x>', spotlight.actions.reset_file, global = true }, -- FIXME: make different?
          reset_hunk = { { '<C-x>', modes = { 'n', 'v' } }, spotlight.actions.reset_hunk, global = true }, -- FIXME: make different?
        },
      },

      diff = {
        actions = {
          open_hunk_diff = { { 'gd', modes = 'n' }, delta.diff.actions.open_hunk_diff },
        },
        file = {
          keys = {
            close = 'q',
          },
        },
        hunk = {
          mode = 'auto',
          layout = {
            border = hunk_border,
          },
          keys = {
            focus_left = { '<Tab>', '<C-h>' },
            focus_right = { '<Tab>', '<C-l>' },
            close = { NVKeymaps.close, NVKeymaps.close_q, NVKeymaps.close_esc },
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
      '<Leader>dp',
      function()
        require('delta.picker').toggle()
      end,
      desc = 'Delta Picker',
    },
    {
      '<Leader>ds',
      function()
        require('delta.spotlight').toggle()
      end,
      desc = 'Delta Spotlight',
    },
  },
}
