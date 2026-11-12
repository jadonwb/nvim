#!/usr/bin/env bash
# Session persistence: the slot layout (which panels were open and what each
# showed) is saved with the workspace and rebuilt on restore.
#
#   tests/session.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-session.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
printf 'one\n' >"$repo/a.txt"
printf 'two\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm base
cd "$repo" || exit 1

# First run: build the layout, point three slots at non-default providers, save.
nvim --headless \
  "+lua vim.cmd 'edit $repo/a.txt'" \
  "+lua vim.cmd 'NVLayout open'" \
  "+lua NVSlots.set_provider('bottom', 'problems')" \
  "+lua NVSlots.set_provider('right_bottom', 'prompt')" \
  "+lua vim.fn.writefile({ 'saved=' .. tostring(NVSession.save()), 'applied=' .. tostring(NVSlots.is_applied()) }, '$tmp/save.txt')" \
  +qa! 2>"$tmp/save.err"

# Second run: restore and report the layout the user gets.
nvim --headless \
  "+lua local ok = NVSession.restore()" \
  "+lua vim.wait(400)" \
  "+lua local p = {}; for n, s in pairs(NVSlots.status()) do p[#p + 1] = n .. '=' .. tostring(s.provider) end; table.sort(p); vim.fn.writefile({ 'restore=' .. tostring(ok), 'applied=' .. tostring(NVSlots.is_applied()), table.concat(p, ',') }, '$tmp/restore.txt')" \
  +qa! 2>"$tmp/restore.err"

save=$(cat "$tmp/save.txt" 2>/dev/null)
got=$(cat "$tmp/restore.txt" 2>/dev/null)
printf 'first run: %s\n' "$save"
printf 'restore:   %s\n' "$got"

fail=0
check() { grep -qx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; [ -s "$tmp/restore.err" ] && sed -n 1,5p "$tmp/restore.err"; fail=1; }; }

check 'applied=true'
grep -q 'bottom=problems' <<<"$got" || { echo 'FAIL: bottom provider not restored'; fail=1; }
grep -q 'right_bottom=prompt' <<<"$got" || { echo 'FAIL: right_bottom provider not restored'; fail=1; }
grep -q 'right_top=changes' <<<"$got" || { echo 'FAIL: default provider missing'; fail=1; }
grep -q 'left=explorer' <<<"$got" || { echo 'FAIL: explorer not restored'; fail=1; }

[ "$fail" = 0 ] && echo 'session: pass' || { echo 'session: FAIL'; exit 1; }
