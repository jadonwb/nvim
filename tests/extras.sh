#!/usr/bin/env bash
# Language extras: packs, this machine's choice, merging, live toggling.
#
#   tests/extras.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-extras.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
mkdir -m 700 -p "$XDG_RUNTIME_DIR"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

probe=$(cat <<'LUA'
local out = {}
local function add(s) out[#out + 1] = s end
local X = require 'config.extras'

-- Every pack in the menu order exists, and the reverse.
local listed = {}
for _, name in ipairs(X.order) do
  listed[name] = X.packs[name] ~= nil
end
local all = true
for name in pairs(X.packs) do
  all = all and listed[name] == true
end
add('order complete=' .. tostring(all and #X.order == vim.tbl_count(X.packs)))

-- A machine that never chose gets the defaults (what the config did before).
X._reset()
add('defaults=' .. table.concat(X.list(), ',') .. ' chosen=' .. tostring(X.chosen()))

-- Choosing is remembered in the state file, in menu order.
X.set('python', true)
X.set('cpp', false)
X._reset()
add('saved=' .. table.concat(X.list(), ',') .. ' chosen=' .. tostring(X.chosen()))

-- Merging: base first, packs after, no duplicates.
local servers = X.collect 'servers'
add('servers=' .. tostring(servers[1] == 'lua_ls' and vim.tbl_contains(servers, 'basedpyright') and vim.tbl_contains(servers, 'bitbake_ls') and not vim.tbl_contains(servers, 'clangd')))
local parsers = X.collect 'parsers'
local seen, dup = {}, false
for _, p in ipairs(parsers) do
  dup = dup or seen[p]
  seen[p] = true
end
add('parsers no dups=' .. tostring(not dup) .. ' base reads asm=' .. tostring(seen.asm == true and seen.linkerscript == true))
local fmt = X.by_ft 'formatters'
add('formatters=' .. tostring(fmt.markdown ~= nil and fmt.python ~= nil and fmt.cpp == nil))
add('linters=' .. tostring(X.by_ft('linters').bitbake ~= nil))
add('enabled()=' .. tostring(X.enabled 'python' and not X.enabled 'rust'))

-- Live toggle: servers enable / disable without a restart. Nothing is
-- installed: Mason and the parser installer are stubbed (the data directory is
-- the user's).
local installs = {}
package.loaded['mason-registry'] = {
  refresh = function(cb) cb() end,
  get_package = function(name)
    return {
      is_installed = function() return false end,
      is_installing = function() return false end,
      install = function() installs[#installs + 1] = name end,
    }
  end,
}
package.loaded['nvim-treesitter'] = {
  get_installed = function() return { 'rust' } end,
  install = function(list) installs[#installs + 1] = 'ts:' .. table.concat(list, ',') end,
}
local E = require 'features.extras'
require('features.lsp').servers.rust_analyzer = require('features.lsp').servers.rust_analyzer or {}
E.toggle 'rust'
add('rust on=' .. tostring(X.enabled 'rust' and vim.lsp.is_enabled 'rust_analyzer'))
add('installs requested=' .. tostring(vim.tbl_contains(installs, 'ts:ron')))
E.toggle 'rust'
add('rust off=' .. tostring(not X.enabled 'rust' and not vim.lsp.is_enabled 'rust_analyzer'))

io.write('\n' .. table.concat(out, '\n') .. '\n')
LUA
)

got=$(timeout 60 nvim --headless "+lua $probe" +qa! 2>&1 </dev/null)
printf '%s\n' "$got"

fail=0
check() { grep -Fqx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'order complete=true'
check 'defaults=cpp,bitbake chosen=false'
check 'saved=bitbake,python chosen=true'
check 'servers=true'
check 'parsers no dups=true base reads asm=true'
check 'formatters=true'
check 'linters=true'
check 'enabled()=true'
check 'rust on=true'
check 'installs requested=true'
check 'rust off=true'

# Use fresh processes so lazy.nvim sees the choice made before startup.
printf '%s\n' '// C++ extra fixture' >"$tmp/sample.cpp"
for enabled in false true; do
  mkdir -p "$XDG_STATE_HOME/nvim"
  if [ "$enabled" = true ]; then
    printf '%s\n' '{"enabled":["cpp"]}' >"$XDG_STATE_HOME/nvim/extras.json"
  else
    printf '%s\n' '{"enabled":[]}' >"$XDG_STATE_HOME/nvim/extras.json"
  fi
  got=$(timeout 30 nvim --headless --cmd "lua vim.lsp.enable = function() end" "$tmp/sample.cpp" \
    "+lua local map = vim.fn.maparg('<leader>cK', 'n', false, true); print('cpp=' .. tostring(map.buffer == 1) .. ' loaded=' .. tostring(package.loaded.cppman ~= nil)); vim.cmd.enew(); print('elsewhere=' .. tostring(vim.fn.maparg('<leader>cK', 'n') ~= ''))" \
    +qa! 2>&1 </dev/null)
  check "cpp=$enabled loaded=false"
  check 'elsewhere=false'
if grep -Eq "module 'cppman' not found|Error in BufRead" <<<"$got"; then
    printf '%s\n' "$got"
    fail=1
  fi
done

# Exercise the real read/write hooks with a fake linter, then turn its pack off.
printf '%s\n' '{"enabled":["bitbake"]}' >"$XDG_STATE_HOME/nvim/extras.json"
printf '%s\n' 'SUMMARY = "BitBake extra fixture"' >"$tmp/sample.bb"
lint_probe=$(cat <<'LUA'
local calls = {}
package.loaded.lint = {
  try_lint = function(names) calls[#calls + 1] = table.concat(names, ',') end,
  get_namespace = function() return vim.api.nvim_create_namespace('nv-test-lint') end,
}
vim.lsp.enable = function() end
_G.NVTestLint = calls
LUA
)
got=$(NV_LINT_FIXTURE="$tmp/sample.bb" timeout 30 nvim --headless --cmd "lua $lint_probe" \
  "+lua vim.cmd.edit(vim.env.NV_LINT_FIXTURE); vim.cmd.write(); require('features.extras').toggle('bitbake'); vim.cmd.write(); io.write('\nlint=' .. table.concat(NVTestLint, '|') .. '\n')" \
  +qa! 2>&1 </dev/null)
check 'lint=oelint-adv|oelint-adv'

[ "$fail" = 0 ] && echo 'extras: pass' || { echo 'extras: FAIL'; exit 1; }
