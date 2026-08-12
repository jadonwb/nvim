local fn = {}

NVDelta = {
  'alex35mil/delta.nvim',
  lazy = false,
  opts = function()
    local pi = require 'pi'
    local delta = require 'delta'
    local picker = delta.picker
    local spotlight = delta.spotlight

    return {
      picker = {
        initial_mode = 'n',
        layout = {
          height = { 0.5, 0.9 },
          main = {
            width = 0.25,
            border = NVBorders.rounded,
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
            title = ' 󰫽󰫿󰫲󰬃󰫶󰫲󰬄 ',
            width = 0.5,
            border = NVBorders.rounded,
          },
        },
        sources = {
          git = { label = 'git' },
          agent = { label = 'agent', files = pi.changed_files },
        },
        actions = {
          open = { '<CR>', fn.open(picker.actions.open) },
          open_vsplit = { NVKeymaps.open_vsplit, fn.open(picker.actions.open_vsplit) },
          open_hsplit = { NVKeymaps.open_hsplit, fn.open(picker.actions.open_hsplit) },
          spotlight = { '<M-CR>', fn.open(picker.actions.spotlight) },
          collapse = { { 'h', modes = 'n' }, picker.actions.collapse },
          expand = { { 'l', modes = 'n' }, picker.actions.expand },
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
          toggle_stage = { '<C-CR>', picker.actions.toggle_stage },
          reset = { { '<BS>', modes = 'n' }, picker.actions.reset },
          send_to_pi = { '<C-a>', fn.send_to_pi { close = false } },
          send_to_pi_and_close = { '<C-S-a>', fn.send_to_pi { close = true } },
        },
      },
      spotlight = {
        title = '󱦇 󰬀󰫽󰫼󰬁󰫹󰫶󰫴󰫵󰬁',
        status = {
          staged = { icon = '󰕥', label = '󰬀󰬁󰫮󰫴󰫲󰫱' },
          unstaged = { icon = '󰒙', label = '󰬂󰫻󰬀󰬁󰫮󰫴󰫲󰫱' },
          mixed = { icon = '', label = '󰫺󰫶󰬅󰫲󰫱' },
          untracked = { icon = '󰫛', label = '󰬂󰫻󰬁󰫿󰫮󰫰󰫸󰫲󰫱' },
          clean = { icon = '', label = '󰫰󰫹󰫲󰫮󰫻' },
          conflict = { icon = '󰻌', label = '󰫰󰫼󰫻󰫳󰫹󰫶󰫰󰬁' },
          error = { icon = '', label = '󰫲󰫿󰫿󰫼󰫿' },
          outsider = { icon = '', label = '󰫼󰬂󰬁󰬀󰫶󰫱󰫲󰫿' },
          no_repo = { icon = '', label = '󰫻󰫼 󰫿󰫲󰫽󰫼' },
          non_editable = { icon = '󱀰', label = '' },
        },
        autosave_before_stage = true,
        reopen_picker_after_stage = true,

        actions = {
          close = { '<Esc>', spotlight.actions.exit },
          next_hunk = { ']h', spotlight.actions.next_hunk, global = true },
          prev_hunk = { '[h', spotlight.actions.prev_hunk, global = true },
          alt_next_hunk = { '<C-n>', spotlight.actions.next_hunk },
          alt_prev_hunk = { '<C-p>', spotlight.actions.prev_hunk },
          toggle_stage_file = { '<C-CR>', spotlight.actions.toggle_stage_file },
          toggle_stage_hunk = { '<C-Space>', spotlight.actions.toggle_stage_hunk },
          reset_file = { '<C-S-x>', spotlight.actions.reset_file },
          reset_hunk = { { '<A-BS>', modes = { 'n', 'v' } }, spotlight.actions.reset_hunk, global = true },
        },
      },

      diff = {
        actions = {
          open_hunk_diff = { { '<A-Space>', modes = 'n' }, delta.diff.actions.open_hunk_diff },
        },
        hunk = {
          mode = 'auto',
          layout = {
            border = NVBorders.padded,
          },
          keys = {
            focus_left = { '<Tab>', '<C-h>' },
            focus_right = { '<Tab>', '<C-l>' },
            close = { NVKeymaps.close, NVKeymaps.close_q, NVKeymaps.close_esc },
          },
        },
      },
    }
  end,
  keys = function()
    return {
      {
        '<Leader>gs',
        function()
          require('delta.picker').toggle()
        end,
        desc = 'Git: Status',
      },
      {
        '<Leader>ds',
        function()
          require('delta.spotlight').toggle()
        end,
        desc = 'Delta Spotlight',
      },
    }
  end,
}

function NVDelta.cleanup()
  local delta = require 'delta'
  delta.spotlight.disable_all()
  delta.diff.close_all()
end

--- Opening a file from a Delta picker starts a review flow. If Pi is in the
--- floating layout, switch to the side layout first so the reviewed
--- code is on the left in a spotlight window and the agent chat is on the right.
---@param action delta.picker.ActionHandler
---@return delta.picker.ActionHandler
function fn.open(action)
  local pi = require 'pi'

  ---@param ctx delta.picker.ActionContext
  return function(ctx)
    if pi.is_visible() and pi.layout() == 'float' then
      pi.toggle_layout(function(_)
        action(ctx)
      end)
    else
      action(ctx)
    end
  end
end

---@param opts { close: boolean }
---@return delta.picker.ActionHandler
function fn.send_to_pi(opts)
  local pi = require 'pi'

  ---@param ctx delta.picker.ActionContext
  return function(ctx)
    local node = ctx.node
    if not node or not node.path or node.path == '' then
      return
    end

    pi.send_mention({ path = node.path }, { focus = false })

    if opts.close then
      ctx.close()
      pi.focus_chat_prompt()
    end
  end
end

return { NVDelta }
