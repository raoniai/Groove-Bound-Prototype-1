-- Generic object pool. Survivor-scale densities (hundreds of bullets/enemies
-- per second) must not churn the GC, so short-lived entities are acquired
-- from and released to pools instead of being allocated per spawn.
--
--   local pool = Pool(function() return {} end)
--   local obj = pool:acquire()     -- reused table or fresh from factory
--   pool:release(obj)
--
-- If the pooled object has a `reset(...)` method, acquire calls it with the
-- acquire arguments so stale fields never leak between lives.

local class = require("src.core.class")

local Pool = class()

function Pool:init(factory)
  assert(type(factory) == "function", "Pool requires a factory function")
  self.factory = factory
  self.free = {}
  self.created = 0
end

function Pool:acquire(...)
  local obj = table.remove(self.free)
  if not obj then
    obj = self.factory()
    self.created = self.created + 1
  end
  if obj.reset then
    obj:reset(...)
  end
  return obj
end

function Pool:release(obj)
  self.free[#self.free + 1] = obj
end

function Pool:free_count()
  return #self.free
end

return Pool
