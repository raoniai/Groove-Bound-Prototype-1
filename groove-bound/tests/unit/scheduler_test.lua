local H = require("tests.helpers")
local Scheduler = require("src.core.scheduler")

local T = {}

T["after fires once at the right time"] = function()
  local s = Scheduler()
  local fired = 0
  s:after(1.0, function() fired = fired + 1 end)
  s:update(0.5)
  H.eq(fired, 0)
  s:update(0.5)
  H.eq(fired, 1)
  s:update(1.0)
  H.eq(fired, 1, "one-shot must not repeat")
  H.eq(s:count(), 0)
end

T["every repeats on its interval"] = function()
  local s = Scheduler()
  local fired = 0
  s:every(0.5, function() fired = fired + 1 end)
  for _ = 1, 4 do s:update(0.25) end
  H.eq(fired, 2)
end

T["cancel prevents firing"] = function()
  local s = Scheduler()
  local fired = 0
  local id = s:after(0.5, function() fired = fired + 1 end)
  s:cancel(id)
  s:update(1.0)
  H.eq(fired, 0)
end

T["callback may schedule new timers safely"] = function()
  local s = Scheduler()
  local chain = 0
  s:after(0.1, function()
    chain = chain + 1
    s:after(0.1, function() chain = chain + 1 end)
  end)
  s:update(0.1)
  H.eq(chain, 1)
  s:update(0.1)
  H.eq(chain, 2)
end

T["clear drops everything (owner-teardown semantics)"] = function()
  local s = Scheduler()
  local fired = 0
  s:after(0.1, function() fired = fired + 1 end)
  s:every(0.1, function() fired = fired + 1 end)
  s:clear()
  s:update(1.0)
  H.eq(fired, 0)
  H.eq(s:count(), 0)
end

return T
