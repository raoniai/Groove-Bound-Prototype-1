local H = require("tests.helpers")
local Log = require("src.core.log")

local T = {}

local function fresh(channels)
  Log.clear()
  Log.configure({
    channels = channels or {},
    default_enabled = true,
    console = false,
    clock = function() return 1000 end,
  })
end

T["messages land in the ring buffer newest-last"] = function()
  fresh()
  Log.info("test", "first")
  Log.info("test", "second")
  local entries = Log.recent(10)
  H.eq(#entries, 2)
  H.eq(entries[1].message, "first")
  H.eq(entries[2].message, "second")
end

T["disabled channel is dropped at the sink (call sites never check flags)"] = function()
  fresh({ spam = false })
  Log.info("spam", "should vanish")
  Log.info("keep", "should stay")
  local entries = Log.recent(10)
  H.eq(#entries, 1)
  H.eq(entries[1].channel, "keep")
end

T["recent(n) caps the returned rows"] = function()
  fresh()
  for i = 1, 30 do Log.info("test", "msg" .. i) end
  local entries = Log.recent(5)
  H.eq(#entries, 5)
  H.eq(entries[5].message, "msg30")
end

T["ring buffer overwrites oldest beyond capacity"] = function()
  fresh()
  for i = 1, 200 do Log.info("test", "msg" .. i) end
  local entries = Log.recent(500)
  H.eq(#entries, 128, "ring capacity")
  H.eq(entries[#entries].message, "msg200")
  H.eq(entries[1].message, "msg73") -- 200 - 128 + 1
end

T["sinks receive entries"] = function()
  fresh()
  local got
  Log.add_sink(function(entry) got = entry end)
  Log.warn("test", "hello")
  H.eq(got.level, "WARN")
  H.eq(got.message, "hello")
end

return T
