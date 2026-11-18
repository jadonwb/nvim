#!/usr/bin/env bash
# Launch-profile matrix.
#
# Every case runs the real config headless and asserts what NVEnv derived from
# the invocation: purpose, mode, and what closing the last tab does.
#
#   tests/launch.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)

tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-launch.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

# Run against this checkout rather than the deployed config.
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_CONFIG_HOME"
mkdir -m 700 "$XDG_RUNTIME_DIR"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

printf 'a\n' >"$tmp/one"
printf 'b\n' >"$tmp/two"

probe='lua local s = NVEnv.startup; vim.fn.writefile({ tostring(s.purpose) .. "|" .. s.mode .. "|" .. s.policy.close.finish }, vim.env.NV_PROBE)'

pass=0
fail=0

# run <expected> <env assignment or ""> [nvim args...]
run() {
  local expected=$1 envspec=$2
  shift 2
  local got=''
  : >"$tmp/probe"
  if timeout 15 env NV_PROBE="$tmp/probe" ${envspec:+"$envspec"} nvim --headless "+$probe" "$@" +qa >"$tmp/stdout" 2>"$tmp/stderr"; then
    got=$(cat "$tmp/probe")
  fi
  if [ "$got" = "$expected" ]; then
    pass=$((pass + 1))
    printf 'ok   - %s %s -> %s\n' "$envspec" "$*" "$got"
  else
    fail=$((fail + 1))
    printf 'FAIL - %s %s -> %s (want %s)\n' "$envspec" "$*" "$got" "$expected"
    cat "$tmp/stderr"
  fi
}

# A plain launch stays a workspace and keeps its last tab.
run 'nil|workspace|stay' ''

# The helper scripts set NVIM_LAUNCH_MODE.
run 'difftool|difftool|view' 'NVIM_LAUNCH_MODE=difftool'
run 'mergetool|mergetool|view' 'NVIM_LAUNCH_MODE=mergetool'
run 'pager|pager|view' 'NVIM_LAUNCH_MODE=pager'
run 'nil|transient|last_buffer' 'NVIM_LAUNCH_MODE=transient'
run 'nil|workspace|stay' 'NVIM_LAUNCH_MODE=bogus'
run 'pager|pager|view' '' - </dev/null
# Keep the RPC channel open without sending a request.
mkfifo "$tmp/embed"
exec {embed_fd}<>"$tmp/embed"
run 'nil|embedded|last_buffer' '' --embed <&"$embed_fd"
exec {embed_fd}>&-

# Commands from the helper scripts and chezmoi.
run 'difftool|difftool|view' '' +DiffviewDiffFiles "$tmp/one" "$tmp/two"
run 'mergetool|mergetool|view' '' +DiffviewMergeFiles "$tmp/one" "$tmp/one" "$tmp/one" "$tmp/two"

# Transient keeps purpose nil: it changes what closing the last tab does, not
# which command produced the launch.

# Diff mode is a difftool invocation even without a Diffview command.
run 'difftool|difftool|view' '' -d "$tmp/one" "$tmp/two"

# Profile gating: a difftool launch must not resolve editor-only plugins.
got=$(nvim --headless "+DiffviewDiffFiles" "$tmp/one" "$tmp/two" \
  "+lua local p = require('lazy.core.config').plugins; io.write(tostring(p['nvim-ufo'] ~= nil) .. '|' .. tostring(p['blink.cmp'] ~= nil) .. '|' .. vim.fn.exists(':NVAgent') .. '|' .. vim.fn.exists(':NVExtras') .. '|' .. vim.fn.exists(':NVLayout'))" \
  +qa 2>/dev/null)
if [ "$got" = "false|false|0|0|0" ]; then
  pass=$((pass + 1))
  printf 'ok   - difftool excludes ufo, blink, agent, extras, and layout -> %s\n' "$got"
else
  fail=$((fail + 1))
  printf 'FAIL - profile gating: difftool -> %s (want false|false|0|0|0)\n' "$got"
fi

# A difftool launch has no Snacks; the VeryLazy steps must still complete.
got=$(NVIM_LAUNCH_MODE=difftool nvim --headless \
  "+lua vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })" \
  "+lua vim.wait(300)" \
  "+lua io.write(tostring(vim.g.nv_notify_installed == true) .. '|' .. tostring(vim.fn.maparg('<M-w>', 'n') ~= ''))" \
  +qa! 2>/dev/null)
if [ "$got" = "true|true" ]; then
  pass=$((pass + 1))
  printf 'ok   - VeryLazy in difftool profile -> %s\n' "$got"
else
  fail=$((fail + 1))
  printf 'FAIL - VeryLazy in difftool profile -> %s (want true|true)\n' "$got"
fi

# A real terminal launch uses Neovim's own --embed child. Check both the
# startup drawing and the transition from the dashboard to a file.
if command -v script >/dev/null; then
  tui_probe=':lua vim.wait(1000, function() return vim.g.did_very_lazy end); vim.fn.writefile({require("config.profile").kind(), vim.bo.filetype, tostring(NVSlots.is_applied()), tostring(package.loaded.lualine ~= nil), tostring(vim.o.laststatus)}, vim.env.NV_PROBE)'
  file_probe=':lua vim.cmd.edit(vim.env.NV_TUI_FILE); vim.wait(2000, function() return NVSlots.is_applied() end); vim.fn.writefile({NVSlots.provider_of("left") or "none", tostring(package.loaded.lualine ~= nil), tostring(vim.o.laststatus)}, vim.env.NV_PROBE, "a")'
  got=''
  if printf '%s\r' "$tui_probe" "$file_probe" ':qa!' | (
    cd "$tmp" &&
      TERM=xterm-256color NV_PROBE="$tmp/tui-probe" NV_TUI_FILE="$tmp/one" \
        timeout 15 script -q -e -c 'stty rows 55 cols 190; exec nvim' "$tmp/terminal" >/dev/null
  ); then
    got=$(cat "$tmp/tui-probe")
  fi
  if [ "$got" = $'workspace\nsnacks_dashboard\nfalse\nfalse\n0\nexplorer\ntrue\n3' ] &&
    LC_ALL=C grep -aqF 'Recent files' "$tmp/terminal" &&
    ! LC_ALL=C grep -aqF 'Help poor children' "$tmp/terminal"; then
    pass=$((pass + 1))
    printf 'ok   - terminal draws the dashboard first, then loads lualine and the explorer with a file\n'
  else
    fail=$((fail + 1))
    printf 'FAIL - terminal workspace startup and layout:\n%s\n' "$got"
  fi
else
  printf 'skip - terminal launch requires script(1)\n'
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
