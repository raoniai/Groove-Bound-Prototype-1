local H = require("tests.helpers")
local Pool = require("src.core.pool")

local T = {}

T["acquire creates via factory, release enables reuse"] = function()
  local pool = Pool(function() return {} end)
  local a = pool:acquire()
  H.eq(pool.created, 1)
  pool:release(a)
  local b = pool:acquire()
  H.is_true(a == b, "released object must be reused")
  H.eq(pool.created, 1, "no new allocation on reuse")
end

T["reset is called with acquire arguments"] = function()
  local pool = Pool(function()
    return {
      reset = function(self, x, y)
        self.x, self.y = x, y
        self.stale = nil
      end,
    }
  end)

  local obj = pool:acquire(3, 4)
  H.eq(obj.x, 3)
  H.eq(obj.y, 4)

  obj.stale = "leftover"
  pool:release(obj)
  local again = pool:acquire(7, 8)
  H.eq(again.x, 7)
  H.is_nil(again.stale, "reset must clear stale fields between lives")
end

T["free_count tracks the free list"] = function()
  local pool = Pool(function() return {} end)
  local a, b = pool:acquire(), pool:acquire()
  H.eq(pool:free_count(), 0)
  pool:release(a)
  pool:release(b)
  H.eq(pool:free_count(), 2)
end

return T
