-- Tests for lua/editor/features/opencode-artifacts/format.lua
-- (NVOpenCodeArtifactFormat) against the shared cross-implementation fixtures.
-- Run: nvim --headless -u NONE -l /home/jadon/.config/nvim/tests/opencode-artifact-format.lua
-- No service call, no model request, no windows.

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/opencode-artifact-format.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script)))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path

-- The shared fixtures live in the plan-bridge backend repo; both
-- implementations (format.mjs and this Lua module) are pinned to that file.
local FIXTURES_PATH = '/home/jadon/.local/share/chezmoi/dot_config/opencode/plugins/plan-bridge/format-fixtures.json'

local Format = require 'editor.features.opencode-artifacts.format'

local passed, failed, failures = 0, 0, {}

local function test(name, cb)
  local ok, err = pcall(cb)
  if ok then
    passed = passed + 1
    print('ok - ' .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = name
    print('NOT OK - ' .. name .. '\n  ' .. tostring(err))
  end
end

local function eq(a, b, what)
  if not vim.deep_equal(a, b) then
    error((what or 'value') .. ' mismatch:\n  actual:   ' .. vim.inspect(a) .. '\n  expected: ' .. vim.inspect(b), 2)
  end
end

local fixtures_raw = table.concat(vim.fn.readfile(FIXTURES_PATH), '\n')
local fixtures = vim.json.decode(fixtures_raw)

-- vim.json.decode maps JSON null to the truthy vim.NIL marker; normalize the
-- fixture fields that are legitimately null.
local function unn(value)
  if value == vim.NIL then
    return nil
  end
  return value
end
for _, case in ipairs(fixtures.revisionCases) do
  case.sameRevisionAs = unn(case.sameRevisionAs)
  case.differsFrom = unn(case.differsFrom)
end
for _, case in ipairs(fixtures.documentRevisionCases) do
  case.sameRevisionAs = unn(case.sameRevisionAs)
end

test('fixture file describes this format and module', function()
  eq(fixtures.name, Format.FORMAT_NAME, 'format name')
  eq(fixtures.formatVersion, Format.FORMAT_VERSION, 'format version')
  eq(fixtures.specification.frontmatterKeys, Format.FRONTMATTER_KEYS, 'frontmatter keys')
  eq(fixtures.specification.revisionKeys, Format.REVISION_KEYS, 'revision keys')
  eq(fixtures.specification.revisionExcludedKeys, { 'updated_at', 'status' }, 'excluded keys')
end)

test('serialization fixtures round-trip byte-exactly', function()
  for _, case in ipairs(fixtures.serializationCases) do
    eq(Format.serialize_document(case.header, case.body), case.document, case.name .. ' serialize')
    local parsed = Format.parse_document(case.document)
    eq(parsed.header, case.header, case.name .. ' header')
    eq(parsed.body, case.body, case.name .. ' body')
    eq(Format.serialize_document(parsed.header, parsed.body), case.document, case.name .. ' round-trip')
  end
end)

test('parse rejects non-string documents', function()
  local ok, err = pcall(Format.parse_document, 42)
  eq(ok, false, 'non-string document rejected')
  eq(err.problem, 'document_type', 'problem tag')
end)

test('canonical revision fixtures (identity + body)', function()
  local by_name = {}
  for _, case in ipairs(fixtures.revisionCases) do
    by_name[case.name] = case
  end
  for _, case in ipairs(fixtures.revisionCases) do
    eq(Format.canonical_input(case.identity, case.body), case.canonicalInput, case.name .. ' canonical input')
    eq(Format.canonical_revision(case.identity, case.body), case.revision, case.name .. ' revision')
    assert(case.revision:match('^sha256:[a-f0-9]+$') and #case.revision == 71, 'revision shape: ' .. case.revision)
    if case.sameRevisionAs then
      eq(case.revision, by_name[case.sameRevisionAs].revision, case.name .. ' same revision')
    end
    if case.differsFrom then
      assert(case.revision ~= by_name[case.differsFrom].revision, case.name .. ' differs from ' .. case.differsFrom)
    end
  end
end)

test('document revision fixtures (status/updated_at excluded)', function()
  local by_name = {}
  for _, case in ipairs(fixtures.documentRevisionCases) do
    by_name[case.name] = case
  end
  for _, case in ipairs(fixtures.documentRevisionCases) do
    eq(Format.document_revision(case.document), case.revision, case.name)
    if case.sameRevisionAs then
      eq(case.revision, by_name[case.sameRevisionAs].revision, case.name .. ' same revision')
    end
  end
  -- A revision case and its document case describe the same bytes.
  eq(fixtures.revisionCases[1].revision, fixtures.documentRevisionCases[1].revision, 'case families agree')
end)

test('invalid documents are rejected with the pinned problem tag', function()
  for _, case in ipairs(fixtures.invalidDocuments) do
    local ok, err = pcall(Format.parse_document, case.document)
    eq(ok, false, case.name .. ' rejected')
    eq(err.problem, case.problem, case.name .. ' problem tag')
    local ok2 = pcall(Format.document_revision, case.document)
    eq(ok2, false, case.name .. ' revision refused')
  end
end)

test('status-only re-serialization keeps the content revision', function()
  local base = fixtures.serializationCases[1]
  local approved_header = vim.deepcopy(base.header)
  approved_header.updated_at = '2026-09-13T18:00:00.000Z'
  approved_header.status = 'approved'
  local approved_doc = Format.serialize_document(approved_header, base.body)
  eq(Format.document_revision(approved_doc), Format.document_revision(base.document), 'content revision stable')
end)

test('raw-markdown documents hash the exact raw bytes', function()
  local bytes = '# Saved plan\n\nwith two lines\n'
  eq(Format.raw_revision(bytes), 'sha256:' .. vim.fn.sha256(bytes), 'raw-byte digest')
  -- The final-newline distinction is significant for raw bytes too.
  assert(Format.raw_revision(bytes) ~= Format.raw_revision(bytes:sub(1, -2)), 'trailing newline matters')
  eq(Format.revision_for_bytes(bytes, 'raw-markdown'), Format.raw_revision(bytes), 'format branch')
end)

test('unknown formats are rejected, never hashed with the wrong algorithm', function()
  local ok, err = pcall(Format.revision_for_bytes, 'bytes', 'shared-markdown-v2')
  eq(ok, false, 'unknown format rejected')
  eq(err.problem, 'unknown_format', 'problem tag')
  local ok2, revision = pcall(Format.revision_for_bytes, 'bytes', 'raw-markdown')
  eq(ok2, true, 'raw-markdown accepted')
  assert(revision:match('^sha256:'), 'digest returned')
end)

test('header serialization rejects non-strings, unknown and missing fields', function()
  local ok, err = pcall(Format.serialize_header_value, 3)
  eq(ok, false, 'number rejected')
  eq(err.problem, 'scalar_type', 'problem tag')

  local base = fixtures.serializationCases[1].header
  local ok2, err2 = pcall(Format.serialize_header, vim.tbl_extend('force', base, { extra = 'x' }))
  eq(ok2, false, 'unknown field rejected')
  eq(err2.problem, 'unknown_field', 'problem tag')

  local missing = vim.deepcopy(base)
  missing.description = nil
  local ok3, err3 = pcall(Format.serialize_header, missing)
  eq(ok3, false, 'missing field rejected')
  eq(err3.problem, 'missing_field', 'problem tag')

  local empty = vim.deepcopy(base)
  empty.title = ''
  local ok4, err4 = pcall(Format.serialize_header, empty)
  eq(ok4, false, 'empty field rejected')
  eq(err4.problem, 'missing_field', 'problem tag')
end)

test('canonical_revision requires all seven identity fields as strings', function()
  local identity = fixtures.revisionCases[1].identity
  for _, key in ipairs(Format.REVISION_KEYS) do
    local broken = vim.deepcopy(identity)
    broken[key] = nil
    local ok, err = pcall(Format.canonical_revision, broken, 'body')
    eq(ok, false, key .. ' required')
    eq(err.problem, 'missing_field', key .. ' problem tag')
  end
  for _, key in ipairs(Format.REVISION_KEYS) do
    local broken = vim.deepcopy(identity)
    broken[key] = ''
    local ok, err = pcall(Format.canonical_revision, broken, 'body')
    eq(ok, false, key .. ' non-empty')
    eq(err.problem, 'missing_field', key .. ' problem tag')
  end
  local ok = pcall(Format.canonical_revision, identity, '')
  eq(ok, true, 'empty body allowed')
end)

test('bookkeeping fields are validated but never hashed', function()
  local identity = vim.deepcopy(fixtures.revisionCases[1].identity)
  identity.updated_at = '2026-09-13T23:59:59.000Z'
  identity.status = 'approved'
  eq(Format.canonical_revision(identity, fixtures.revisionCases[1].body), fixtures.revisionCases[1].revision, 'bookkeeping ignored')
end)

test('body final-newline distinction changes the revision', function()
  local identity = fixtures.revisionCases[1].identity
  assert(Format.canonical_revision(identity, 'body\n') ~= Format.canonical_revision(identity, 'body'), 'trailing newline matters')
end)

test('kind and status enumerations match the specification', function()
  local kinds, statuses = {}, {}
  for _, kind in ipairs { 'plan', 'evidence', 'review' } do
    kinds[kind] = true
  end
  for _, status in ipairs { 'draft', 'published', 'approved' } do
    statuses[status] = true
  end
  eq(Format.ARTIFACT_KINDS, kinds, 'kinds')
  eq(Format.ARTIFACT_STATUSES, statuses, 'statuses')
end)

test('JSON.stringify escaping parity for control characters', function()
  -- Short escapes versus lowercase \u00xx for other C0 controls; DEL, NEL,
  -- LS and PS stay literal; lone surrogates (WTF-8 bytes) re-escape. Inputs
  -- are built from explicit bytes so the parity is exact.
  local BS, TAB, LF, FF, CR = string.char(8), string.char(9), string.char(10), string.char(12), string.char(13)
  local DEL, NEL = string.char(0x7F), '\194\133' -- U+0085
  local LS, PS = '\226\128\168', '\226\128\169' -- U+2028, U+2029
  eq(Format.serialize_header_value('quote " and \\ slash'), '"quote \\" and \\\\ slash"', 'quote/backslash')
  local pieces = { 'b', BS, 't', TAB, 't', 'n', LF, 'n', 'f', FF, 'f', 'r', CR, 'r' }
  local expected = {}
  for _, piece in ipairs(pieces) do
    if piece == BS then
      expected[#expected + 1] = '\\b'
    elseif piece == TAB then
      expected[#expected + 1] = '\\t'
    elseif piece == LF then
      expected[#expected + 1] = '\\n'
    elseif piece == FF then
      expected[#expected + 1] = '\\f'
    elseif piece == CR then
      expected[#expected + 1] = '\\r'
    else
      expected[#expected + 1] = piece
    end
  end
  eq(
    Format.serialize_header_value(table.concat(pieces)),
    '"' .. table.concat(expected) .. '"',
    'short escapes'
  )
  eq(
    Format.serialize_header_value('unit' .. string.char(1) .. 'sep' .. string.char(0x1F)),
    '"unit\\u0001sep\\u001f"',
    'lowercase hex for other C0'
  )
  eq(
    Format.serialize_header_value('del' .. DEL .. 'nel' .. NEL),
    '"del' .. DEL .. 'nel' .. NEL .. '"',
    'DEL and NEL literal'
  )
  eq(
    Format.serialize_header_value('ls' .. LS .. 'ps' .. PS),
    '"ls' .. LS .. 'ps' .. PS .. '"',
    'LS and PS literal'
  )
  eq(Format.serialize_header_value('emoji \240\159\154\128 and / slash'), '"emoji \240\159\154\128 and / slash"', 'non-ASCII raw')
  -- A lone surrogate is only reachable through an escape; decoded it is WTF-8
  -- bytes ED A0 80 and must re-serialize to the same canonical escape.
  eq(Format.serialize_header_value('lone\237\160\128end'), '"lone\\ud800end"', 'WTF-8 lone surrogate re-escape')
end)

test('parse accepts exactly the canonical spellings and rejects equivalents', function()
  local function header_line(raw)
    return raw
  end
  local function doc_with_title(raw_title)
    local lines = {
      '---',
      'id: "art_ParseProbe000000000000"',
      'kind: "plan"',
      'title: ' .. raw_title,
      'description: "d"',
      'owner_session_id: "ses_owner0000000000000000"',
      'author_session_id: "ses_author000000000000000"',
      'created_at: "2026-09-13T10:00:00.000Z"',
      'updated_at: "2026-09-13T10:00:00.000Z"',
      'status: "draft"',
      '---',
      'body\n',
    }
    return table.concat(lines, '\n')
  end

  -- Canonical spellings accepted (tab as \t; other C0 as lowercase hex;
  -- escaped lone surrogate).
  local accepted = {
    header_line('"Migrate\\tthe plan"'),
    header_line('"Migrate\\u0001the plan"'),
    header_line('"Migrate\\u001fthe plan"'),
    header_line('"lone\\ud800surrogate"'),
    header_line('"plain plan"'),
  }
  for _, raw in ipairs(accepted) do
    local parsed = Format.parse_document(doc_with_title(raw))
    assert(type(parsed.header.title) == 'string', 'accepted: ' .. raw)
  end

  -- Equivalent-but-noncanonical spellings rejected.
  local noncanonical = {
    { header_line('"Migrate\\u0009the plan"'), 'tab as unicode escape' },
    { header_line('"Migrate\\u000athe plan"'), 'newline lowercase hex' },
    { header_line('"Migrate\\u000Athe plan"'), 'newline uppercase hex' },
    { header_line('"Migrate\\u007fthe plan"'), 'DEL escape' },
    { header_line('"Migrate\\ud83d\\ude00 now"'), 'surrogate pair escape' },
  }
  for _, item in ipairs(noncanonical) do
    local ok, err = pcall(Format.parse_document, doc_with_title(item[1]))
    eq(ok, false, item[2] .. ' rejected')
    eq(err.problem, 'noncanonical_scalar', item[2] .. ' problem tag')
  end
end)

test('escaped lone surrogate is accepted and hashes like the backend', function()
  -- Fixture-pinned: the lone-surrogate document from the shared fixtures.
  local case
  for _, item in ipairs(fixtures.documentRevisionCases) do
    if item.document:find('\\ud800', 1, true) then
      case = item
      break
    end
  end
  assert(case, 'lone-surrogate document fixture present')
  eq(Format.document_revision(case.document), case.revision, 'lone surrogate digest')
end)

print(('\ntests: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  os.exit(1)
end
os.exit(0)
