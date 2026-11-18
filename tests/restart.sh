#!/usr/bin/env bash
# Run the configured Alt+r mapping in a real terminal.
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-restart-test.XXXXXX")
test_process() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] && [ -r "/proc/$1/cmdline" ] &&
    grep -azFxq "luafile $tmp/probe.lua" "/proc/$1/cmdline"
}
cleanup() {
  local file pid
  # A restarted server detaches from the launcher; a script timeout alone
  # cannot stop it. Only contact processes started with this test's probe.
  for file in "$tmp"/pid-*; do
    [ -f "$file" ] || continue
    read -r pid <"$file"
    if test_process "$pid"; then
      kill "$pid" 2>/dev/null || :
    fi
  done
  rm -rf -- "$tmp"
}
trap cleanup EXIT
config="${NV_RESTART_CONFIG:-$root}"
export XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" XDG_RUNTIME_DIR="$tmp/run"
export NV_RESTART_TEST="$tmp"
mkdir -p "$XDG_CONFIG_HOME"
mkdir -m 700 "$XDG_RUNTIME_DIR"
ln -s "$config" "$XDG_CONFIG_HOME/nvim"
printf 'restart fixture\n' >"$tmp/sample.txt"
cd "$tmp"

cat >"$tmp/probe.lua" <<'LUA'
local dir = vim.env.NV_RESTART_TEST
local pid = vim.fn.getpid()
vim.fn.writefile({ tostring(pid) }, dir .. '/pid-' .. pid)
-- This checkout uses habamax; supply the Omarchy-only colors the todo spec expects.
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    if vim.g.colors_name == 'habamax' then
      for _, name in ipairs { 'Todo', 'Fixme', 'Note', 'Warn', 'Perf', 'Test' } do
        vim.api.nvim_set_hl(0, 'ArrowlakeComment' .. name, { fg = '#808080' })
      end
    end
  end,
})

local function check()
  local function position(win)
    return win and vim.api.nvim_win_get_position(win) or { -1, -1 }
  end
  local centre = NVSlots.content_win()
  local left, top, bottom = NVSlots.win('left'), NVSlots.win('right_top'), NVSlots.win('right_bottom')
  local top_pos, bottom_pos = position(top), position(bottom)
  local result = {
    profile = require('config.profile').kind(),
    terminals = NVTerminals ~= nil,
    provider = NVSlots.provider_of('left'),
    top = NVSlots.provider_of('right_top'),
    bottom = NVSlots.provider_of('right_bottom'),
    explorer = vim.bo[vim.api.nvim_win_get_buf(left or 0)].filetype,
    content = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(centre)),
    windows = { left = position(left), content = position(centre), top = top_pos, bottom = bottom_pos },
    positioned = left ~= nil and top_pos[1] >= 0 and top_pos[1] < bottom_pos[1]
      and top_pos[2] == bottom_pos[2] and position(left)[2] < position(centre)[2] and position(centre)[2] < top_pos[2],
    lines = vim.fn.getline(1, '$'),
    early_picker = vim.g.nv_test_picker,
    errors = {},
  }
  if result.top == 'lsp' and result.bottom == 'changes' then
    local toggle = vim.fn.maparg('<leader>ls', 'n', false, true).callback
    if toggle then
      toggle()
      result.toggle_hides_lsp = not NVSlots.is_open('right_top') and NVSlots.provider_of('right_bottom') == 'changes'
      toggle()
      result.toggle_shows_lsp = NVSlots.provider_of('right_top') == 'lsp'
    end
  end
  for _, item in ipairs(NVNotify.store) do
    if item.level >= vim.log.levels.ERROR then
      result.errors[#result.errors + 1] = item.msg
    end
  end
  vim.fn.writefile({ vim.json.encode(result) }, dir .. '/result.json')
  vim.cmd 'qa!'
end

vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.v.startreason:match '^restart' then
      -- Plugin conditions must already have used the original profile.
      vim.g.nv_test_picker = require('lazy.core.config').plugins['nvim-tree.lua'] ~= nil
      vim.defer_fn(check, 500)
    else
      vim.defer_fn(function()
        vim.cmd.edit(dir .. '/sample.txt')
        assert(vim.wait(2000, function()
          return NVSlots.provider_of('left') == 'explorer' and vim.fn.maparg('<M-r>', 'n') ~= ''
        end), 'workspace layout or restart key missing')
        assert(NVSlots.swap('right_top', 'right_bottom'), 'could not swap Changes and LSP')
        vim.api.nvim_feedkeys(vim.keycode '<M-r>', 'm', false)
      end, 100)
    end
  end,
})
LUA

export TERM=xterm-256color
if ! timeout 15 script -q -e -c 'stty rows 55 cols 190; exec nvim --cmd "luafile $NV_RESTART_TEST/probe.lua"' "$tmp/terminal" </dev/null >/dev/null; then
  cat "$tmp/terminal"
  exit 1
fi
cat "$tmp/result.json"
NV_RESTART_RESULT="$tmp/result.json" nvim --headless -u NONE -i NONE \
  '+lua local r = vim.json.decode(table.concat(vim.fn.readfile(vim.env.NV_RESTART_RESULT))); if not (r.profile == "workspace" and r.terminals and r.provider == "explorer" and r.explorer == "NvimTree" and r.content == vim.env.NV_RESTART_TEST .. "/sample.txt" and r.lines[1] == "restart fixture" and r.early_picker and r.positioned and r.toggle_hides_lsp and r.toggle_shows_lsp and #r.errors == 0) then vim.cmd.cquit(1) end' +qa!
if compgen -G "$XDG_RUNTIME_DIR/nvim-bridge/*.json" >/dev/null ||
  compgen -G "$XDG_STATE_HOME/nvim/nv-restart/*.vim" >/dev/null; then
  printf 'FAIL: stale bridge entry or restart snapshot after exit\n' >&2
  exit 1
fi
for file in "$tmp"/pid-*; do
  read -r pid <"$file"
  if test_process "$pid"; then
    printf 'FAIL: Neovim process %s is still running\n' "$pid" >&2
    exit 1
  fi
done
printf 'Alt+r: profile, file, explorer, and swapped panels restored; LSP key follows the view\n'
