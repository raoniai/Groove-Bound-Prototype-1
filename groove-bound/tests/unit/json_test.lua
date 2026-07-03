local H = require("tests.helpers")
local json = require("lib.json")

local T = {}

T["round-trips a nested save-shaped table"] = function()
  local data = {
    coins = 120,
    options = { music_volume = 0.8, sfx_volume = 0.5, screen_shake = true },
    unlocks = { "joe", "second_character" },
  }
  H.deep_eq(json.decode(json.encode(data)), data)
end

T["round-trips strings with escapes"] = function()
  local s = 'he said "groove"\nnew\tline\\slash'
  H.eq(json.decode(json.encode(s)), s)
end

T["decodes standard JSON literals"] = function()
  H.eq(json.decode("true"), true)
  H.eq(json.decode("false"), false)
  H.is_nil(json.decode("null"))
  H.eq(json.decode("-12.5e2"), -1250)
end

T["empty containers survive"] = function()
  H.eq(json.encode({}), "[]") -- empty table encodes as array by convention
  H.deep_eq(json.decode("{}"), {})
  H.deep_eq(json.decode("[]"), {})
end

T["rejects trailing garbage"] = function()
  H.errors(function() json.decode('{"a":1} extra') end)
end

T["rejects unterminated string"] = function()
  H.errors(function() json.decode('"abc') end)
end

T["rejects circular references on encode"] = function()
  local t = {}
  t.self = t
  H.errors(function() json.encode(t) end)
end

return T
