-- Event bus with instance buses, once-semantics, and scoped subscription groups.
--
-- Scopes are the leak-proofing mechanism: anything with a lifetime shorter than
-- the app (a run, a screen) subscribes through its own scope and calls
-- scope:cancel() on teardown, which drops every listener it registered.
--
--   local bus = EventBus.new()
--   local off = bus:on("ENEMY_KILLED", handler)   -- returns unsubscribe fn
--   bus:once("BOSS_DOWN", handler)
--   bus:emit("ENEMY_KILLED", { xp = 10 })
--
--   local scope = bus:scope()
--   scope:on("XP_PICKED", handler)
--   scope:cancel()                                 -- removes all scope listeners

local class = require("src.core.class")

local EventBus = class()

function EventBus:init()
  self.listeners = {} -- event name -> array of { fn = fn, once = bool }
end

-- Register a listener. Returns a function that unsubscribes it.
function EventBus:on(event, fn, once)
  assert(type(event) == "string", "event name must be a string")
  assert(type(fn) == "function", "listener must be a function")

  local list = self.listeners[event]
  if not list then
    list = {}
    self.listeners[event] = list
  end

  local entry = { fn = fn, once = once or false }
  list[#list + 1] = entry

  return function()
    self:_remove(event, entry)
  end
end

function EventBus:once(event, fn)
  return self:on(event, fn, true)
end

function EventBus:off(event, fn)
  local list = self.listeners[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i].fn == fn then
      table.remove(list, i)
    end
  end
end

function EventBus:_remove(event, entry)
  local list = self.listeners[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == entry then
      table.remove(list, i)
      return
    end
  end
end

function EventBus:emit(event, data)
  local list = self.listeners[event]
  if not list then return end

  -- Snapshot so listeners can subscribe/unsubscribe during dispatch safely.
  local snapshot = {}
  for i = 1, #list do
    snapshot[i] = list[i]
  end

  for i = 1, #snapshot do
    local entry = snapshot[i]
    if entry.once then
      self:_remove(event, entry)
    end
    entry.fn(data)
  end
end

-- Number of listeners for an event (all events when nil). Used by leak tests.
function EventBus:count(event)
  if event then
    local list = self.listeners[event]
    return list and #list or 0
  end
  local total = 0
  for _, list in pairs(self.listeners) do
    total = total + #list
  end
  return total
end

-- A scope collects unsubscribe functions so a whole group can be torn down at once.
local Scope = class()

function Scope:init(bus)
  self.bus = bus
  self.cancels = {}
  self.cancelled = false
end

function Scope:on(event, fn)
  assert(not self.cancelled, "scope already cancelled")
  local off = self.bus:on(event, fn)
  self.cancels[#self.cancels + 1] = off
  return off
end

function Scope:once(event, fn)
  assert(not self.cancelled, "scope already cancelled")
  local off = self.bus:once(event, fn)
  self.cancels[#self.cancels + 1] = off
  return off
end

function Scope:cancel()
  if self.cancelled then return end
  self.cancelled = true
  for i = 1, #self.cancels do
    self.cancels[i]()
  end
  self.cancels = {}
end

function EventBus:scope()
  return Scope(self)
end

return EventBus
