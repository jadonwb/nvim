#!/usr/bin/env bash
# External-caller smoke test: drive the slot API over the Neovim RPC socket, the
# way an opencode tool would.
#
#   tests/rpc.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-rpc.XXXXXX")
sock=$tmp/nvim.sock
export XDG_CONFIG_HOME="$tmp/xdg"
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

# The layout applies on the first real file.
export XDG_STATE_HOME="$tmp/state"
printf 'one\n' >"$tmp/a.txt"
nvim --headless --listen "$sock" --cmd 'set columns=200 lines=50' "$tmp/a.txt" >/dev/null 2>&1 &
pid=$!
# A headless nvim can ignore SIGTERM; never leave one behind.
cleanup() {
  nvim --server "$sock" --remote-send '<C-\><C-n>:qa!<CR>' >/dev/null 2>&1 </dev/null
  sleep 0.3
  kill -9 "$pid" 2>/dev/null
  rm -rf -- "$tmp"
}
trap cleanup EXIT

for _ in $(seq 1 100); do
  [ -S "$sock" ] && break
  sleep 0.1
done
[ -S "$sock" ] || { echo 'rpc: socket never appeared'; exit 1; }

# `v:lua.NVSlots.state()` returns a table handle; remoting structured data needs
# the whole expression evaluated in Lua.
state() { nvim --server "$sock" --remote-expr 'luaeval("vim.json.encode(NVSlots.state())")' 2>/dev/null; }
# Actions go through remote-expr: it executes synchronously, unlike remote-send.
act() { nvim --server "$sock" --remote-expr "v:lua.NVSlots.$1" >/dev/null 2>&1; }

fail=0
check() { if ! grep -q -- "$2" <<<"$1"; then printf 'FAIL: %s\n  got: %s\n' "$3" "$1"; fail=1; fi }

# Setup is deferred past startup; give the first file a moment to apply it.
for _ in $(seq 1 50); do
  s=$(state)
  grep -q '"applied":true' <<<"$s" && break
  sleep 0.2
done
check "$s" '"applied":true' 'layout applies on the first file'

# Closing over RPC is the external focus-mode switch.
act "close()"
s=$(state)
check "$s" '"applied":false' 'close over RPC removes the layout'

act "open()"
s=$(state)
check "$s" '"applied":true' 'open over RPC applies the layout'
check "$s" '"provider":"changes"' 'changes provider assigned'
check "$s" '"provider":"session"' 'session provider assigned'

act "remove('bottom')"
s=$(state)
# `order` still lists the name; the slots map must not.
if grep -q '"bottom":{"' <<<"$s"; then echo 'FAIL: bottom slot still present after remove'; fail=1; fi

act "swap('right_top', 'right_bottom')"
s=$(state)
check "$s" '"provider":"changes"' 'swap exchanges slot providers'

act "close()"
s=$(state)
check "$s" '"applied":false' 'close over RPC clears the layout'

[ "$fail" = 0 ] && echo 'rpc: pass' || { echo 'rpc: FAIL'; exit 1; }
