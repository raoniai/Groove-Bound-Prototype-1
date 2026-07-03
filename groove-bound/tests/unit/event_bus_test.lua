local H = require("tests.helpers")
local EventBus = require("src.core.event_bus")

local T = {}

T["on delivers events with payload"] = function()
  local bus = EventBus()
  local got
  bus:on("HIT", function(data) got = data end)
  bus:emit("HIT", { damage = 5 })
  H.eq(got.damage, 5)
end

T["off removes a listener"] = function()
  local bus = EventBus()
  local calls = 0
  local fn = function() calls = calls + 1 end
  bus:on("X", fn)
  bus:emit("X")
  bus:off("X", fn)
  bus:emit("X")
  H.eq(calls, 1)
end

T["unsubscribe function removes exactly its own entry"] = function()
  local bus = EventBus()
  local a, b = 0, 0
  local off_a = bus:on("X", function() a = a + 1 end)
  bus:on("X", function() b = b + 1 end)
  off_a()
  bus:emit("X")
  H.eq(a, 0)
  H.eq(b, 1)
end

T["once fires exactly one time"] = function()
  local bus = EventBus()
  local calls = 0
  bus:once("X", function() calls = calls + 1 end)
  bus:emit("X")
  bus:emit("X")
  H.eq(calls, 1)
  H.eq(bus:count("X"), 0)
end

T["listeners registered during emit do not fire in the same emit"] = function()
  local bus = EventBus()
  local late_calls = 0
  bus:on("X", function()
    bus:on("X", function() late_calls = late_calls + 1 end)
  end)
  bus:emit("X")
  H.eq(late_calls, 0)
  bus:emit("X")
  H.eq(late_calls, 1)
end

T["scope cancel drops all scope listeners (run-teardown leak regression)"] = function()
  local bus = EventBus()
  local calls = 0

  -- Simulate three "runs", each attaching listeners through its own scope.
  for _ = 1, 3 do
    local scope = bus:scope()
    scope:on("ENEMY_KILLED", function() calls = calls + 1 end)
    scope:on("XP_PICKED", function() calls = calls + 1 end)
    scope:cancel()
  end

  bus:emit("ENEMY_KILLED")
  bus:emit("XP_PICKED")
  H.eq(calls, 0, "no listeners should survive scope teardown")
  H.eq(bus:count(), 0)
end

T["separate buses are independent"] = function()
  local a, b = EventBus(), EventBus()
  local calls = 0
  a:on("X", function() calls = calls + 1 end)
  b:emit("X")
  H.eq(calls, 0)
end

return T
