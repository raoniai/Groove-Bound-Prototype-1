-- Minimal JSON encode/decode for save files. Supports objects, arrays,
-- strings, numbers, booleans, and null (decoded as nil, encoded from
-- json.null sentinel). Arrays are tables with contiguous integer keys from 1.

local json = {}

json.null = setmetatable({}, { __tostring = function() return "null" end })

-- ---------------------------------------------------------------- encoding

local escape_map = {
  ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
  ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function escape_char(c)
  return escape_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_string(s)
  return '"' .. s:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function is_array(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

local encode_value

local function encode_table(t, seen)
  assert(not seen[t], "cannot encode circular reference")
  seen[t] = true

  local parts = {}
  if is_array(t) then
    for i = 1, #t do
      parts[i] = encode_value(t[i], seen)
    end
    seen[t] = nil
    return "[" .. table.concat(parts, ",") .. "]"
  end

  for k, v in pairs(t) do
    assert(type(k) == "string", "object keys must be strings, got " .. type(k))
    parts[#parts + 1] = encode_string(k) .. ":" .. encode_value(v, seen)
  end
  seen[t] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

encode_value = function(v, seen)
  local tv = type(v)
  if v == json.null then
    return "null"
  elseif tv == "nil" then
    return "null"
  elseif tv == "boolean" then
    return tostring(v)
  elseif tv == "number" then
    assert(v == v and v ~= math.huge and v ~= -math.huge, "cannot encode NaN/inf")
    return string.format("%.14g", v)
  elseif tv == "string" then
    return encode_string(v)
  elseif tv == "table" then
    return encode_table(v, seen)
  end
  error("cannot encode value of type " .. tv)
end

function json.encode(value)
  return encode_value(value, {})
end

-- ---------------------------------------------------------------- decoding

local unescape_map = {
  ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f",
  n = "\n", r = "\r", t = "\t",
}

local function decode_error(s, pos, msg)
  error(string.format("json: %s at position %d (near %q)", msg, pos, s:sub(pos, pos + 10)))
end

local function skip_ws(s, pos)
  local _, e = s:find("^[ \t\r\n]*", pos)
  return e + 1
end

local decode_value

local function decode_string(s, pos)
  local out = {}
  local i = pos + 1
  while true do
    local c = s:sub(i, i)
    if c == "" then
      decode_error(s, i, "unterminated string")
    elseif c == '"' then
      return table.concat(out), i + 1
    elseif c == "\\" then
      local esc = s:sub(i + 1, i + 1)
      if esc == "u" then
        local hex = s:sub(i + 2, i + 5)
        local code = tonumber(hex, 16)
        if not code then decode_error(s, i, "invalid unicode escape") end
        -- Basic-plane only; encode as UTF-8.
        if code < 0x80 then
          out[#out + 1] = string.char(code)
        elseif code < 0x800 then
          out[#out + 1] = string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
        else
          out[#out + 1] = string.char(
            0xE0 + math.floor(code / 0x1000),
            0x80 + math.floor(code / 0x40) % 0x40,
            0x80 + code % 0x40)
        end
        i = i + 6
      else
        local mapped = unescape_map[esc]
        if not mapped then decode_error(s, i, "invalid escape") end
        out[#out + 1] = mapped
        i = i + 2
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
end

local function decode_number(s, pos)
  local num_str = s:match("^-?%d+%.?%d*[eE]?[+%-]?%d*", pos)
  local num = tonumber(num_str)
  if not num then decode_error(s, pos, "invalid number") end
  return num, pos + #num_str
end

local function decode_array(s, pos)
  local out = {}
  pos = skip_ws(s, pos + 1)
  if s:sub(pos, pos) == "]" then return out, pos + 1 end
  while true do
    local value
    value, pos = decode_value(s, pos)
    out[#out + 1] = value
    pos = skip_ws(s, pos)
    local c = s:sub(pos, pos)
    if c == "]" then return out, pos + 1 end
    if c ~= "," then decode_error(s, pos, "expected ',' or ']'") end
    pos = skip_ws(s, pos + 1)
  end
end

local function decode_object(s, pos)
  local out = {}
  pos = skip_ws(s, pos + 1)
  if s:sub(pos, pos) == "}" then return out, pos + 1 end
  while true do
    if s:sub(pos, pos) ~= '"' then decode_error(s, pos, "expected string key") end
    local key, value
    key, pos = decode_string(s, pos)
    pos = skip_ws(s, pos)
    if s:sub(pos, pos) ~= ":" then decode_error(s, pos, "expected ':'") end
    pos = skip_ws(s, pos + 1)
    value, pos = decode_value(s, pos)
    out[key] = value
    pos = skip_ws(s, pos)
    local c = s:sub(pos, pos)
    if c == "}" then return out, pos + 1 end
    if c ~= "," then decode_error(s, pos, "expected ',' or '}'") end
    pos = skip_ws(s, pos + 1)
  end
end

decode_value = function(s, pos)
  local c = s:sub(pos, pos)
  if c == '"' then
    return decode_string(s, pos)
  elseif c == "{" then
    return decode_object(s, pos)
  elseif c == "[" then
    return decode_array(s, pos)
  elseif c == "t" and s:sub(pos, pos + 3) == "true" then
    return true, pos + 4
  elseif c == "f" and s:sub(pos, pos + 4) == "false" then
    return false, pos + 5
  elseif c == "n" and s:sub(pos, pos + 3) == "null" then
    return nil, pos + 4
  elseif c:match("[%-%d]") then
    return decode_number(s, pos)
  end
  decode_error(s, pos, "unexpected character")
end

function json.decode(s)
  assert(type(s) == "string", "json.decode expects a string")
  local value, pos = decode_value(s, skip_ws(s, 1))
  pos = skip_ws(s, pos)
  if pos <= #s then
    decode_error(s, pos, "trailing garbage")
  end
  return value
end

return json
