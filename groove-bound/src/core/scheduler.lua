-- Timer scheduler: one-shot and repeating callbacks driven by update(dt).
-- Replaces ad-hoc countdown fields (gameOverTimer et al.) with one mechanism
-- that is created per owner (RunContext, screen) and dropped wholesale on
-- teardown — no timers survive their owner.
--
--   local sched = Scheduler()
--   sched:after(0.5, fn)          -> handle
--   sched:every(2.0, fn)          -> handle (fn(count) each firing)
--   sched:cancel(handle)
--   sched:update(dt)

local class = require("src.core.class")

local Scheduler = class()

function Scheduler:init()
  self.timers = {}
  self.next_id = 1
end

local function add(self, delay, interval, fn)
  assert(type(fn) == "function", "scheduler callback must be a function")
  assert(delay >= 0, "delay must be >= 0")
  local id = self.next_id
  self.next_id = id + 1
  self.timers[id] = {
    remaining = delay,
    interval = interval, -- nil for one-shot
    fn = fn,
    count = 0,
  }
  return id
end

function Scheduler:after(delay, fn)
  return add(self, delay, nil, fn)
end

function Scheduler:every(interval, fn)
  assert(interval > 0, "interval must be > 0")
  return add(self, interval, interval, fn)
end

function Scheduler:cancel(id)
  self.timers[id] = nil
end

function Scheduler:clear()
  self.timers = {}
end

function Scheduler:count()
  local n = 0
  for _ in pairs(self.timers) do n = n + 1 end
  return n
end

function Scheduler:update(dt)
  -- Collect fired ids first: callbacks may add/cancel timers mid-iteration.
  local fired = {}
  for id, t in pairs(self.timers) do
    t.remaining = t.remaining - dt
    if t.remaining <= 0 then
      fired[#fired + 1] = id
    end
  end

  for i = 1, #fired do
    local id = fired[i]
    local t = self.timers[id]
    if t then -- may have been cancelled by an earlier callback this frame
      if t.interval then
        t.count = t.count + 1
        t.remaining = t.remaining + t.interval
        t.fn(t.count)
      else
        self.timers[id] = nil
        t.fn()
      end
    end
  end
end

return Scheduler
