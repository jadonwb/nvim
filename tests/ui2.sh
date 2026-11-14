#!/usr/bin/env bash
# ui2 setup: the message layer is configured on UIEnter, which a headless run
# never reaches on its own, so the other suites cannot see it fail (0.13
# removed config keys and the whole config stopped loading). Fire UIEnter and
# check the setup ran and routes messages where intended.
#
#   tests/ui2.sh            (uses the `nvim` on PATH; run with a nightly to
#                            check the next release)
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-ui2.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

probe=$(cat <<'LUA'
local out = {}
local function add(s) out[#out + 1] = s end
local ok, err = pcall(vim.api.nvim_exec_autocmds, 'UIEnter', {})
add('setup ok=' .. tostring(ok) .. (ok and '' or (' ' .. tostring(err):sub(1, 200))))
local ui2 = require 'vim._core.ui2'
local cfg = ui2.cfg.msg
-- The default target is `msg` on either version (0.12: `target`, 0.13:
-- `targets.default`); cmdheight 0 would draw `cmd` over the statusline.
local default = cfg.targets.default or cfg.target
add('default target=' .. tostring(default))
add('emsg target=' .. tostring(cfg.targets.emsg))
local timeout = vim.fn.has 'nvim-0.13' == 1 and vim.o.messagesopt:match 'timeout:(%d+)' or (cfg.msg and cfg.msg.timeout)
add('timeout=' .. tostring(timeout))
add('cmdline pinned=' .. tostring(require('vim._core.ui2.cmdline').__nv_pinned == true))
io.write('\n' .. table.concat(out, '\n') .. '\n')
LUA
)

got=$(timeout 60 nvim --headless "+lua $probe" +qa! 2>&1 </dev/null)
printf '%s\n' "$got"

fail=0
check() { grep -Fqx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'setup ok=true'
check 'default target=msg'
check 'emsg target=msg'
check 'timeout=4000'
check 'cmdline pinned=true'

[ "$fail" = 0 ] && echo 'ui2: pass' || { echo 'ui2: FAIL'; exit 1; }
