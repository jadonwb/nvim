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
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

printf 'a\n' >"$tmp/one"
printf 'b\n' >"$tmp/two"

probe='lua local s = NVEnv.startup; io.write(tostring(s.purpose) .. "|" .. s.mode .. "|" .. s.policy.close.finish)'

pass=0
fail=0

# run <expected> <env assignment or ""> [nvim args...]
run() {
  local expected=$1 envspec=$2
  shift 2
  local got
  got=$(env ${envspec:+"$envspec"} nvim --headless "+$probe" "$@" +qa 2>/dev/null)
  if [ "$got" = "$expected" ]; then
    pass=$((pass + 1))
    printf 'ok   - %s %s -> %s\n' "$envspec" "$*" "$got"
  else
    fail=$((fail + 1))
    printf 'FAIL - %s %s -> %s (want %s)\n' "$envspec" "$*" "$got" "$expected"
  fi
}

# A plain launch stays a workspace and keeps its last tab.
run 'nil|workspace|stay' ''

# The helper scripts set NVIM_LAUNCH_MODE.
run 'difftool|difftool|view' 'NVIM_LAUNCH_MODE=difftool'
run 'mergetool|mergetool|view' 'NVIM_LAUNCH_MODE=mergetool'
run 'nil|transient|last_buffer' 'NVIM_LAUNCH_MODE=transient'
run 'nil|workspace|stay' 'NVIM_LAUNCH_MODE=bogus'

# Commands from the helper scripts and chezmoi.
run 'difftool|difftool|view' '' +DiffviewDiffFiles "$tmp/one" "$tmp/two"
run 'mergetool|mergetool|view' '' +DiffviewMergeFiles "$tmp/one" "$tmp/one" "$tmp/one" "$tmp/two"

# Transient keeps purpose nil: it changes what closing the last tab does, not
# which command produced the launch.

# Diff mode is a difftool invocation even without a Diffview command.
run 'difftool|difftool|view' '' -d "$tmp/one" "$tmp/two"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
