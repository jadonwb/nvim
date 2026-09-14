-- NVOpenCodeArtifactFormat: exact Lua implementation of the backend's
-- shared-markdown artifact format (format.mjs in the plan-bridge plugin)
-- and its canonical revision algorithm, pinned by the cross-implementation
-- fixtures in format-fixtures.json.
--
-- Document layout (exactly, LF line endings, UTF-8):
--
--   ---
--   id: "art_..."            nine header lines, fixed key order, each value
--   kind: "plan"             a canonical single-line JSON string scalar
--   ...                      (see serialize_header_value)
--   ---
--   <body Markdown, exactly as supplied; no H1 is inserted>
--
-- The content revision is the first 8 lowercase hex characters of the SHA-256
-- of a canonical input that EXCLUDES the bookkeeping fields (updated_at,
-- status) so approval can flip the displayed status without changing the
-- content revision.
--
-- JSON-string serialization matches JSON.stringify byte for byte: only quote,
-- backslash and C0 control characters are escaped (\b \t \n \f \r short
-- escapes, otherwise lowercase \u00xx); DEL (U+007F), NEL (U+0085), LINE
-- SEPARATOR (U+2028) and PARAGRAPH SEPARATOR (U+2029) stay literal, as do all
-- other non-ASCII characters. Lone surrogate code points — which the backend
-- parser accepts in \udXXX escaped form and re-escapes canonically — are
-- represented internally as their WTF-8 byte sequence and re-escaped on
-- serialization, so escaped and literal spellings round-trip exactly as the
-- backend does. vim.json.encode is deliberately NOT used: it is not
-- guaranteed byte-identical to JSON.stringify.

local M = {}
NVOpenCodeArtifactFormat = M

M.FORMAT_NAME = 'shared-markdown'

M.OPEN_FENCE = '---'
M.CLOSE_FENCE = '---'

--- All frontmatter keys, in the exact serialization/parse order.
M.FRONTMATTER_KEYS = {
  'id',
  'kind',
  'title',
  'description',
  'owner_session_id',
  'author_session_id',
  'created_at',
  'updated_at',
  'status',
}

--- Keys covered by the content revision; updated_at/status are validated but
--- never hashed.
M.REVISION_KEYS = {
  'id',
  'kind',
  'title',
  'description',
  'owner_session_id',
  'author_session_id',
  'created_at',
}

M.ARTIFACT_KINDS = { plan = true, evidence = true, review = true }
M.ARTIFACT_STATUSES = { draft = true, published = true, approved = true }

local key_index = {}
for index, key in ipairs(M.FRONTMATTER_KEYS) do
  key_index[key] = index
end

--- Format violation error; `.problem` is the machine-readable tag shared with
--- the backend FormatError (fence, duplicate_or_order, missing_field,
--- unknown_field, malformed_scalar, scalar_type, noncanonical_scalar,
--- empty_value, unknown_kind, unknown_status, unsupported_syntax, ...).
local function fail(problem, message, data)
  error(setmetatable({
    problem = problem,
    message = message,
    data = data,
    code = 'format',
  }, {
    __tostring = function(e)
      return e.message
    end,
  }), 0)
end
M.fail = fail

--------------------------------------------------------------------------------
-- JSON.stringify-compatible string serialization
--------------------------------------------------------------------------------

local SHORT_ESCAPES = {
  [8] = '\\b',
  [9] = '\\t',
  [10] = '\\n',
  [12] = '\\f',
  [13] = '\\r',
}

--- True when bytes i..i+2 are the WTF-8 encoding of a lone surrogate
--- (ED A0..BF ..): such code points only arise from decoding an escaped lone
--- surrogate and JSON.stringify re-escapes them.
local function is_wtf8_surrogate(s, i)
  if s:byte(i) == 0xED then
    local b2 = s:byte(i + 1)
    if b2 and b2 >= 0xA0 and b2 <= 0xBF then
      return true
    end
  end
  return false
end

--- Canonical single-line JSON string scalar, byte-identical to JSON.stringify.
function M.serialize_header_value(value)
  if type(value) ~= 'string' then
    fail('scalar_type', ('header value must be a string, got %s'):format(type(value)))
  end
  local out = { '"' }
  local i, n = 1, #value
  while i <= n do
    local b = value:byte(i)
    if b == 0x22 then
      out[#out + 1] = '\\"'
      i = i + 1
    elseif b == 0x5C then
      out[#out + 1] = '\\\\'
      i = i + 1
    elseif SHORT_ESCAPES[b] then
      out[#out + 1] = SHORT_ESCAPES[b]
      i = i + 1
    elseif b < 0x20 then
      out[#out + 1] = ('\\u%04x'):format(b)
      i = i + 1
    elseif is_wtf8_surrogate(value, i) then
      local b2, b3 = value:byte(i + 1), value:byte(i + 2)
      local cp = 0xD000 + (b2 - 0x80) % 0x40 * 0x40 + (b3 - 0x80) % 0x40
      out[#out + 1] = ('\\u%04x'):format(cp)
      i = i + 3
    else
      out[#out + 1] = value:sub(i, i)
      i = i + 1
    end
  end
  out[#out + 1] = '"'
  return table.concat(out)
end

--------------------------------------------------------------------------------
-- JSON string scalar decoding (JSON.parse restricted to strings)
--------------------------------------------------------------------------------

local function utf8_encode(cp)
  if cp < 0x80 then
    return string.char(cp)
  end
  if cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
  end
  if cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
  end
  return string.char(
    0xF0 + math.floor(cp / 0x40000),
    0x80 + math.floor(cp / 0x1000) % 0x40,
    0x80 + math.floor(cp / 0x40) % 0x40,
    0x80 + cp % 0x40
  )
end

--- Decode a JSON string scalar into bytes, or nil when malformed. Surrogate
--- pairs combine into the real code point; lone surrogates decode to their
--- WTF-8 bytes so re-serialization reproduces the \udXXX escape. Mirrors
--- JSON.parse, which accepts lone surrogate code units.
local function decode_json_string(raw)
  if type(raw) ~= 'string' or #raw < 2 or raw:byte(1) ~= 0x22 then
    return nil
  end
  local parts = {}
  local i, n = 2, #raw
  while i <= n do
    local b = raw:byte(i)
    if b == 0x22 then
      if i ~= n then
        return nil -- trailing garbage after the closing quote
      end
      return table.concat(parts)
    elseif b == 0x5C then
      local e = raw:byte(i + 1)
      if e == 0x22 then
        parts[#parts + 1] = '"'
        i = i + 2
      elseif e == 0x5C then
        parts[#parts + 1] = '\\'
        i = i + 2
      elseif e == 0x2F then
        parts[#parts + 1] = '/'
        i = i + 2
      elseif e == 0x62 then
        parts[#parts + 1] = '\b'
        i = i + 2
      elseif e == 0x66 then
        parts[#parts + 1] = '\f'
        i = i + 2
      elseif e == 0x6E then
        parts[#parts + 1] = '\n'
        i = i + 2
      elseif e == 0x72 then
        parts[#parts + 1] = '\r'
        i = i + 2
      elseif e == 0x74 then
        parts[#parts + 1] = '\t'
        i = i + 2
      elseif e == 0x75 then
        local hex = raw:sub(i + 2, i + 5)
        if #hex ~= 4 or not hex:match('^%x%x%x%x$') then
          return nil
        end
        local cp = tonumber(hex, 16)
        i = i + 6
        if cp >= 0xD800 and cp <= 0xDBFF then
          -- A following low-surrogate escape combines into one code point;
          -- anything else leaves the high surrogate lone, as in JSON.parse.
          local next_escape = raw:sub(i, i + 5)
          if next_escape:match([[^\u%x%x%x%x$]]) then
            local cp2 = tonumber(next_escape:sub(3), 16)
            if cp2 >= 0xDC00 and cp2 <= 0xDFFF then
              cp = 0x10000 + (cp - 0xD800) * 0x400 + (cp2 - 0xDC00)
              i = i + 6
            end
          end
        end
        parts[#parts + 1] = utf8_encode(cp)
      else
        return nil
      end
    else
      -- A raw (unescaped) C0 byte is rejected by JSON.parse itself, so the
      -- backend classifies it as malformed — not noncanonical (only DEL
      -- U+007F stays raw-and-canonical; it is not a C0 byte).
      if b < 0x20 then
        return nil
      end
      parts[#parts + 1] = raw:sub(i, i)
      i = i + 1
    end
  end
  return nil -- no closing quote
end

--- Strict UTF-8 validation (overlong forms and surrogates rejected). Applied
--- to raw header scalars: the backend consumes files through a UTF-8 decoder,
--- so bytes that are not valid UTF-8 can never round-trip canonically there.
local function utf8_valid(s)
  local i, n = 1, #s
  while i <= n do
    local b = s:byte(i)
    if b < 0x80 then
      i = i + 1
    elseif b >= 0xC2 and b <= 0xDF then
      local b2 = s:byte(i + 1)
      if not b2 or b2 < 0x80 or b2 > 0xBF then
        return false
      end
      i = i + 2
    elseif b >= 0xE0 and b <= 0xEF then
      local b2, b3 = s:byte(i + 1), s:byte(i + 2)
      if not b2 or not b3 then
        return false
      end
      if b == 0xE0 and b2 < 0xA0 then
        return false -- overlong
      end
      if b == 0xED and b2 >= 0xA0 then
        return false -- surrogate code point
      end
      if b2 < 0x80 or b2 > 0xBF or b3 < 0x80 or b3 > 0xBF then
        return false
      end
      i = i + 3
    elseif b >= 0xF0 and b <= 0xF4 then
      local b2, b3, b4 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3)
      if not b2 or not b3 or not b4 then
        return false
      end
      if b == 0xF0 and b2 < 0x90 then
        return false -- overlong
      end
      if b == 0xF4 and b2 > 0x8F then
        return false -- beyond U+10FFFF
      end
      if b2 < 0x80 or b2 > 0xBF or b3 < 0x80 or b3 > 0xBF or b4 < 0x80 or b4 > 0xBF then
        return false
      end
      i = i + 4
    else
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- Document parse / serialize
--------------------------------------------------------------------------------

--- Split exactly like JavaScript's String.prototype.split('\n'), keeping a
--- trailing empty line so the final-newline distinction survives.
local function split_lines(text)
  local lines = {}
  local pos = 1
  while true do
    local nl = text:find('\n', pos, true)
    if not nl then
      lines[#lines + 1] = text:sub(pos)
      return lines
    end
    lines[#lines + 1] = text:sub(pos, nl - 1)
    pos = nl + 1
  end
end

--- Serialize the nine header lines (no fences). Strict about key set/order.
function M.serialize_header(header)
  if type(header) ~= 'table' then
    fail('header_type', 'header must be an object')
  end
  for key in pairs(header) do
    if not key_index[key] then
      fail('unknown_field', ('unknown header field %s'):format(M.serialize_header_value(key)), { key = key })
    end
  end
  local lines = {}
  for _, key in ipairs(M.FRONTMATTER_KEYS) do
    local value = header[key]
    if type(value) ~= 'string' or value == '' then
      fail('missing_field', ('header field %s must be a non-empty string'):format(key), { key = key })
    end
    lines[#lines + 1] = key .. ': ' .. M.serialize_header_value(value)
  end
  return table.concat(lines, '\n')
end

--- Serialize a full document: fences + header + LF + exact body bytes.
function M.serialize_document(header, body)
  if type(body) ~= 'string' then
    fail('body_type', 'body must be a string')
  end
  return M.OPEN_FENCE .. '\n' .. M.serialize_header(header) .. '\n' .. M.CLOSE_FENCE .. '\n' .. body
end

--- Parse a document into { header, body }. Rejects anything that is not the
--- exact format; errors carry a `.problem` tag matching the backend.
function M.parse_document(text)
  if type(text) ~= 'string' then
    fail('document_type', 'document must be a string')
  end
  local lines = split_lines(text)
  if lines[1] ~= M.OPEN_FENCE then
    fail('fence', 'document must open with a --- fence line')
  end
  -- The first --- line after the opening fence closes the frontmatter; body
  -- fences are never mistaken for it. The closing fence must be terminated
  -- by LF so that an empty body is representable.
  local close_index = -1
  for index = 2, #lines do
    if lines[index] == M.CLOSE_FENCE then
      close_index = index
      break
    end
  end
  if close_index == -1 then
    fail('fence', 'document is missing its closing --- fence line')
  end
  if close_index == #lines then
    fail('fence', 'closing --- fence must be terminated by a line feed')
  end

  local header, seen, seen_keys = {}, {}, {}
  for index = 2, close_index - 1 do
    local line = lines[index]
    local separator = line:find(': ', 1, true)
    if not separator then
      fail('unsupported_syntax', ('unsupported header syntax at frontmatter line %d'):format(index), { line = index })
    end
    local key = line:sub(1, separator - 1)
    local raw_value = line:sub(separator + 2)
    if not key_index[key] then
      fail('unknown_field', ('unknown header field %s at frontmatter line %d'):format(M.serialize_header_value(key), index), { key = key, line = index })
    end
    if seen[key] then
      fail('duplicate_or_order', ('duplicate header field %s at frontmatter line %d'):format(M.serialize_header_value(key), index), { key = key, line = index })
    end
    -- String scalars use the canonical-aware decoder; any other JSON value
    -- (number, boolean, null, array, object) is accepted by JSON.parse and
    -- therefore rejected as a type error, exactly as the backend does.
    local value, malformed
    if raw_value:byte(1) == 0x22 then
      value = decode_json_string(raw_value)
      malformed = value == nil
    else
      local ok, decoded = pcall(vim.json.decode, raw_value)
      if not ok then
        malformed = true
      else
        value = decoded
      end
    end
    if malformed then
      fail('malformed_scalar', ('header field %s has a malformed JSON string scalar'):format(key), { key = key, line = index })
    end
    if type(value) ~= 'string' then
      fail('scalar_type', ('header field %s must be a JSON string scalar'):format(key), { key = key, line = index })
    end
    if not utf8_valid(raw_value) then
      fail('noncanonical_scalar', ('header field %s is not valid UTF-8 and cannot be canonical'):format(key), { key = key, line = index })
    end
    if M.serialize_header_value(value) ~= raw_value then
      fail('noncanonical_scalar', ('header field %s is not in canonical JSON form'):format(key), { key = key, line = index })
    end
    if value == '' then
      fail('empty_value', ('header field %s must be a non-empty string'):format(key), { key = key, line = index })
    end
    seen[key] = true
    seen_keys[#seen_keys + 1] = key
    header[key] = value
  end

  for _, key in ipairs(M.FRONTMATTER_KEYS) do
    if not seen[key] then
      fail('missing_field', ('missing header field %s'):format(M.serialize_header_value(key)), { key = key })
    end
  end
  for index, key in ipairs(M.FRONTMATTER_KEYS) do
    if seen_keys[index] ~= key then
      fail('duplicate_or_order', ('header field %s is out of the fixed field order'):format(M.serialize_header_value(seen_keys[index] or '?')), { key = seen_keys[index], line = index + 1 })
    end
  end
  if not M.ARTIFACT_KINDS[header.kind] then
    fail('unknown_kind', ('unknown kind %s'):format(M.serialize_header_value(header.kind)), { kind = header.kind })
  end
  if not M.ARTIFACT_STATUSES[header.status] then
    fail('unknown_status', ('unknown status %s'):format(M.serialize_header_value(header.status)), { status = header.status })
  end

  local body_parts = {}
  for index = close_index + 1, #lines do
    body_parts[#body_parts + 1] = lines[index]
  end
  return { header = header, body = table.concat(body_parts, '\n') }
end

--------------------------------------------------------------------------------
-- Canonical revision
--------------------------------------------------------------------------------

--- The exact bytes whose SHA-256 is the content revision: the seven
--- identity/descriptive header lines in fixed order (JSON string values, LF
--- delimiters), the closing delimiter line, then the exact body bytes.
--- updated_at and status are never hash inputs. Extra identity keys (the two
--- bookkeeping fields) are ignored, as in the backend.
function M.canonical_input(identity, body)
  if type(identity) ~= 'table' then
    fail('identity_type', 'identity must be an object')
  end
  local lines = {}
  for _, key in ipairs(M.REVISION_KEYS) do
    local value = identity[key]
    if type(value) ~= 'string' or value == '' then
      fail('missing_field', ('identity field %s must be a non-empty string'):format(key), { key = key })
    end
    lines[#lines + 1] = key .. ': ' .. M.serialize_header_value(value)
  end
  if type(body) ~= 'string' then
    fail('body_type', 'body must be a string')
  end
  return table.concat(lines, '\n') .. '\n' .. M.CLOSE_FENCE .. '\n' .. body
end

--- Content revision of an identity header + body: the first 8 hex digits of
--- the SHA-256 digest.
function M.canonical_revision(identity, body)
  return vim.fn.sha256(M.canonical_input(identity, body)):sub(1, 8)
end

--- Content revision of a displayed document. Rejects the same document
--- violations as parse_document; updated_at/status are validated but excluded
--- from the hash input.
function M.document_revision(text)
  local doc = M.parse_document(text)
  return M.canonical_revision(doc.header, doc.body)
end

--------------------------------------------------------------------------------
-- Format-branched helpers
--------------------------------------------------------------------------------

--- Revision of displayed bytes for a recorded artifact format. Unknown
--- formats are rejected rather than hashed with the wrong algorithm.
function M.revision_for_bytes(bytes, format)
  if format == 'shared-markdown' then
    return M.document_revision(bytes)
  end
  fail('unknown_format', ('unknown artifact format %s'):format(M.serialize_header_value(tostring(format))))
end

--- Revision plus the lifecycle status visible in the displayed bytes.
function M.revision_and_status(bytes, format)
  if format == 'shared-markdown' then
    local ok, doc = pcall(M.parse_document, bytes)
    if not ok then
      return nil, nil
    end
    return M.canonical_revision(doc.header, doc.body), doc.header.status
  end
  return nil, nil
end

return M
