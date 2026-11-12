#!/usr/bin/env bash
# Bridge: prompt -> opencode NDJSON stream -> real selectable buffer.
#
#   tests/bridge.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-bridge.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
mkdir -p "$XDG_CONFIG_HOME" "$tmp/bin"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"

cat >"$tmp/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${FAKE_ARGV_LOG:-/dev/null}"
printf '%s\n' '{"type":"step_start","sessionID":"ses_test"}'
printf '%s\n' '{"type":"text","sessionID":"ses_test","part":{"id":"p1","type":"text","text":"hello "}}'
printf '%s\n' '{"type":"text","sessionID":"ses_test","part":{"id":"p1","type":"text","text":"hello world"}}'
printf '%s\n' '{"type":"text","sessionID":"ses_test","part":{"id":"p2","type":"text","text":"!"}}'
printf '%s\n' '{"type":"step_finish","sessionID":"ses_test","part":{"cost":0.01,"tokens":{"input":10,"output":2}}}'
FAKE
chmod +x "$tmp/bin/opencode"
export PATH="$tmp/bin:$PATH"
export FAKE_ARGV_LOG="$tmp/argv.log"

probe=$(cat <<'LUA'
local out = {}
local function add(s) out[#out + 1] = s end

NVBridge.submit 'hi'
vim.wait(3000, function() return NVBridge.state.job == nil end)

local buf = NVBridge.state.buf
local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
add('streamed=' .. tostring(text:find('hello world!', 1, true) ~= nil))
add('deduped=' .. tostring(text:find('hello hello', 1, true) == nil))
add('prompt echoed=' .. tostring(text:find('hi', 1, true) ~= nil))
add('real lines=' .. tostring(vim.api.nvim_buf_line_count(buf) > 3))
add('ft=' .. vim.bo[buf].filetype)
add('session=' .. tostring(NVBridge.state.session))
add('tokens=' .. tostring(NVBridge.state.status and NVBridge.state.status.tokens.input))
add('readonly=' .. tostring(vim.bo[buf].modifiable == false))

-- The transcript is real text: visual selection and yanking work, editing does
-- not.
vim.api.nvim_win_set_buf(0, buf)
local line = vim.fn.search('hello world', 'nw')
vim.api.nvim_win_set_cursor(0, { line, 0 })
vim.cmd 'normal! yy'
add('yankable=' .. tostring(vim.fn.getreg '"':find('hello world', 1, true) ~= nil))
add('editing blocked=' .. tostring(not pcall(vim.api.nvim_buf_set_lines, buf, 0, 0, false, { 'x' })))

-- A new session is created archived; continuing one is not.
NVBridge.submit('again', { session = 'ses_existing' })
vim.wait(3000, function() return NVBridge.state.job == nil end)
local argv = vim.fn.readfile(vim.env.FAKE_ARGV_LOG)
add('archived first=' .. tostring(argv[1] and argv[1]:find('--archived', 1, true) ~= nil))
add('archived when continuing=' .. tostring(argv[2] and argv[2]:find('--archived', 1, true) ~= nil))

io.write(table.concat(out, '\n'))
LUA
)

got=$(nvim --headless "+lua $probe" +qa! 2>&1)
printf '%s\n' "$got"

fail=0
check() { grep -qx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'streamed=true'
check 'deduped=true'
check 'prompt echoed=true'
check 'real lines=true'
check 'ft=markdown'
check 'session=ses_test'
check 'tokens=10'
check 'readonly=true'
check 'yankable=true'
check 'editing blocked=true'
check 'archived first=true'
check 'archived when continuing=false'

[ "$fail" = 0 ] && echo 'bridge: pass' || { echo 'bridge: FAIL'; exit 1; }
