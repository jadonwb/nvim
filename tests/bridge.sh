#!/usr/bin/env bash
# Bridge: service client, session store, transcript, agent-facing entry points.
#
# No OpenCode service: the client's transport (`spawn`) is replaced by a fake
# that answers the API paths the editor uses, and events are injected the way
# the stream delivers them.
#
#   tests/bridge.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nv-bridge.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$root" "$XDG_CONFIG_HOME/nvim"
# Keep registry files, attachments and service discovery out of the user's
# directories: no real service is found or touched.
export XDG_RUNTIME_DIR="$tmp/runtime"
# Neovim creates its server socket there; without the directory it has no
# server name and the registry stays empty.
mkdir -m 700 -p "$XDG_RUNTIME_DIR"
export XDG_STATE_HOME="$tmp/state"
export PROBE_FILE="$tmp/probe.txt"
printf 'alpha\nbeta\n' >"$PROBE_FILE"

probe=$(cat <<'LUA'
local out = {}
local function add(s) out[#out + 1] = s end
vim.opt.clipboard = ''

local C = require 'features.opencode.client'
local S = require 'features.opencode.sessions'
local T = require 'features.opencode.transcript'

-- ── fake transport ──────────────────────────────────────────────────────────
local calls = {}
local history = {
  { id = 'msg_a2', type = 'assistant', agent = 'build', model = { id = 'm1', providerID = 'p' }, time = { created = 2000 },
    content = {
      { type = 'reasoning', text = 'thinking line one\nline two' },
      { type = 'text', text = 'earlier answer' },
      { type = 'tool', id = 't1', name = 'read', state = { status = 'completed', input = { filePath = '/x/note.txt' } } },
    } },
  { id = 'msg_a1', type = 'user', text = 'earlier question', time = { created = 1000 } },
}
local routes = {
  ['GET /api/session/ses_int/message'] = { data = history, cursor = {} },
  ['GET /api/session/ses_int'] = { data = { id = 'ses_int', title = 'Internal', metadata = { origin = 'nvim' }, time = { busy = 1, idle = 2 } } },
  ['GET /api/session/ses_ext'] = { data = { id = 'ses_ext', title = 'TUI work', time = { busy = 5, idle = 2 } } },
  ['GET /api/session/ses_int/permission'] = { data = {} },
  ['GET /api/session/ses_int/form'] = { data = {} },
  ['GET /api/session/ses_ext/permission'] = { data = { { id = 'per_1', sessionID = 'ses_ext', action = 'edit', resources = { 'a.lua' } } } },
  ['GET /api/session/ses_ext/form'] = { data = {} },
  ['POST /api/session/ses_int/prompt'] = { data = { id = 'msg_u2' } },
  ['POST /api/session'] = { data = { id = 'ses_new', title = 'New', metadata = { origin = 'nvim' } } },
}
C.spawn = function(argv, opts, on_exit)
  local url = argv[#argv]
  local method = 'GET'
  for i, a in ipairs(argv) do
    if a == '-X' then method = argv[i + 1] end
  end
  calls[#calls + 1] = { argv = argv, stdin = opts.stdin, method = method, url = url }
  if url:match '/api/event$' then
    return { kill = function() end }
  end
  local path = url:gsub('^http://fake', ''):gsub('%?.*', '')
  local body = routes[method .. ' ' .. path]
  vim.schedule(function()
    if body then
      on_exit { code = 0, stdout = vim.json.encode(body), stderr = '' }
    else
      on_exit { code = 22, stdout = vim.json.encode { message = 'not found: ' .. path }, stderr = '' }
    end
  end)
  return { kill = function() end }
end
C.server = { url = 'http://fake', password = 'sekrit"pw' }
local function settle() vim.wait(300, function() return false end) end

-- ── client ──────────────────────────────────────────────────────────────────
local got
C.request('POST', '/api/session/ses_int/prompt', { text = 'say "hi"\n', files = {} }, function(err, data) got = { err = err, data = data } end)
vim.wait(1000, function() return got ~= nil end)
local last = calls[#calls]
add('request ok=' .. tostring(got.err == nil and got.data.id == 'msg_u2'))
add('password not in argv=' .. tostring(not table.concat(last.argv, ' '):find('sekrit', 1, true)))
add('credentials on stdin=' .. tostring(last.stdin:find('user = "opencode:sekrit\\"pw"', 1, true) ~= nil))
-- The body is a quoted curl config value: unescape it and read the JSON back.
local quoted = last.stdin:match 'data%-binary = "(.-)"\n$'
local json = quoted and quoted:gsub('\\(.)', function(c) return ({ n = '\n', r = '\r', t = '\t' })[c] or c end)
local ok_body, decoded = pcall(vim.json.decode, json or '')
add('body on stdin=' .. tostring(ok_body and decoded.text == 'say "hi"\n'))
got = nil
C.request('GET', '/api/nope', nil, function(err) got = err end)
vim.wait(1000, function() return got ~= nil end)
add('error message=' .. tostring(got:find('not found', 1, true) ~= nil))
C.server = { url = 'http://fake', password = 'sekrit"pw' }

-- SSE framing: split chunks, heartbeats, multi-line data.
local evs, beats, st = {}, 0, { buf = '', data = {} }
local function feed(chunk) C._parse(st, chunk, function(e) evs[#evs + 1] = e end, function() beats = beats + 1 end) end
feed 'data: {"type":"a","da'
feed 'ta":{}}\n\n: heartbeat\n\ndata: {"type":"b",\ndata: "data":{}}\n\n'
add('sse=' .. #evs .. ' ' .. tostring(evs[1] and evs[1].type) .. tostring(evs[2] and evs[2].type) .. ' beats=' .. beats)

-- ── sessions: tracking, busy, waiting ───────────────────────────────────────
S.track 'ses_ext'
settle()
add('external=' .. tostring(not S.is_internal 'ses_ext') .. ' busy=' .. tostring(S.busy.ses_ext))
add('catch-up waiting=' .. select(1, S.waiting 'ses_ext'))
S.handle { type = 'permission.replied', data = { sessionID = 'ses_ext', requestID = 'per_1', reply = 'once' } }
add('replied clears=' .. select(1, S.waiting 'ses_ext'))
S.handle { type = 'form.created', data = { form = { id = 'frm_1', sessionID = 'ses_ext', title = 'Pick one', fields = {} } } }
local _, forms = S.waiting 'ses_ext'
add('form waiting=' .. forms)
S.handle { type = 'form.cancelled', data = { id = 'frm_1', sessionID = 'ses_ext' } }
add('form cleared=' .. select(2, S.waiting 'ses_ext'))
S.handle { type = 'session.execution.succeeded', data = { sessionID = 'ses_ext' } }
add('idle after=' .. tostring(S.busy.ses_ext))
S.handle { type = 'permission.asked', data = { id = 'per_x', sessionID = 'ses_other', action = 'edit', resources = {} } }
add('untracked ignored=' .. tostring(S.pending.ses_other == nil))

-- ── transcript: history, live events, durability ────────────────────────────
S.track 'ses_int'
settle()
add('internal=' .. tostring(S.is_internal 'ses_int'))
local win = T.open 'ses_int'
settle()
local view = T.views.ses_int
local function text() return table.concat(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false), '\n') end
add('history=' .. tostring(text():find('earlier question', 1, true) ~= nil and text():find('earlier answer', 1, true) ~= nil))
add('tool line=' .. tostring(text():find('✓ read: /x/note.txt', 1, true) ~= nil))
add('reasoning collapsed=' .. tostring(text():find('󰟶 thinking line one …', 1, true) ~= nil and not text():find('line two', 1, true)))
add('readonly=' .. tostring(vim.bo[view.buf].modifiable == false))

-- Live: prompt, a two-step turn (one header), streamed deltas, a failed tool.
T.handle { type = 'session.inbox.enqueued', data = { sessionID = 'ses_int', inboxID = 'msg_u2', item = { type = 'user', payload = { text = 'new question' } } } }
T.handle { type = 'session.step.started', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s1', agent = 'build', model = { id = 'm2' } } }
T.handle { type = 'session.text.delta', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s1', ordinal = 0, delta = 'stream' } }
T.handle { type = 'session.text.delta', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s1', ordinal = 0, delta = 'ed reply' } }
T.handle { type = 'session.tool.input.started', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s1', id = 't2', name = 'shell' } }
T.handle { type = 'session.tool.called', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s1', id = 't2', input = { command = 'false' } } }
T.handle { type = 'session.tool.failed', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s1', id = 't2', error = { message = 'exit 1' } } }
T.handle { type = 'session.step.started', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s2' } }
T.handle { type = 'session.text.ended', data = { sessionID = 'ses_int', assistantMessageID = 'msg_s2', ordinal = 0, text = 'second step' } }
T.handle { type = 'session.text.delta', data = { sessionID = 'ses_other', assistantMessageID = 'zzz', ordinal = 0, delta = 'LEAK' } }
settle()
local t = text()
add('live prompt=' .. tostring(t:find('new question', 1, true) ~= nil))
add('deltas joined=' .. tostring(t:find('streamed reply', 1, true) ~= nil))
add('failed tool=' .. tostring(t:find('✗ shell: false', 1, true) ~= nil and t:find('exit 1', 1, true) ~= nil))
local _, heads = t:gsub(' opencode ', '')
add('one header per turn=' .. heads)
add('no leak=' .. tostring(not t:find('LEAK', 1, true)))

-- <CR> on the reasoning line expands it.
local row
for i, l in ipairs(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)) do
  if l:find('󰟶', 1, true) then row = i end
end
vim.api.nvim_set_current_win(win)
vim.api.nvim_win_set_cursor(win, { row, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)
add('expanded=' .. tostring(text():find('│ line two', 1, true) ~= nil))

-- Deleting the buffer loses nothing: the next open rebuilds from history.
vim.api.nvim_buf_delete(view.buf, { force = true })
add('view dropped=' .. tostring(T.views.ses_int == nil))
T.open 'ses_int'
settle()
add('rebuilt=' .. tostring(T.views.ses_int ~= nil and text ~= nil and table.concat(vim.api.nvim_buf_get_lines(T.views.ses_int.buf, 0, -1, false), '\n'):find('earlier answer', 1, true) ~= nil))

-- Tool detail: plugin tools run through `execute`.
add('execute detail=' .. tostring(T.tool_detail('execute', { code = 'await tools.nvim.control({ action: "open" })' })))

-- ── agent-facing entry points (nvim tool) ───────────────────────────────────
local registry = vim.fn.glob(vim.env.XDG_RUNTIME_DIR .. '/nvim-bridge/*.json', false, true)
add('registry=' .. tostring(#registry == 1))
add('open_file=' .. tostring(NVBridge.open_file(vim.env.PROBE_FILE, 2)))
add('open_line=' .. vim.api.nvim_win_get_cursor(0)[1])
add('show_text=' .. tostring(NVBridge.show_text('Report', 'line one\nline two') and vim.bo.filetype == 'markdown'))

io.write('\n' .. table.concat(out, '\n') .. '\n')
LUA
)

got=$(timeout 60 nvim --headless "+lua $probe" +qa! 2>&1 </dev/null)
printf '%s\n' "$got"

fail=0
check() { grep -Fqx -- "$1" <<<"$got" || { printf 'FAIL: missing %s\n' "$1"; fail=1; }; }
check 'request ok=true'
check 'password not in argv=true'
check 'credentials on stdin=true'
check 'body on stdin=true'
check 'error message=true'
check 'sse=2 ab beats=1'
check 'external=true busy=true'
check 'catch-up waiting=1'
check 'replied clears=0'
check 'form waiting=1'
check 'form cleared=0'
check 'idle after=false'
check 'untracked ignored=true'
check 'internal=true'
check 'history=true'
check 'tool line=true'
check 'reasoning collapsed=true'
check 'readonly=true'
check 'live prompt=true'
check 'deltas joined=true'
check 'failed tool=true'
check 'one header per turn=2'
check 'no leak=true'
check 'expanded=true'
check 'view dropped=true'
check 'rebuilt=true'
check 'execute detail=nvim.control open'
check 'registry=true'
check 'open_file=true'
check 'open_line=2'
check 'show_text=true'

[ "$fail" = 0 ] && echo 'bridge: pass' || { echo 'bridge: FAIL'; exit 1; }
