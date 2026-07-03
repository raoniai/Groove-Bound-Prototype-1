local H = require("tests.helpers")
local RNG = require("src.core.rng")

local T = {}

T["same seed produces identical sequences"] = function()
  local a = RNG.new(12345)
  local b = RNG.new(12345)
  for _ = 1, 100 do
    H.eq(a.loot:random(), b.loot:random())
  end
end

T["different seeds diverge"] = function()
  local a = RNG.new(1)
  local b = RNG.new(2)
  local same = 0
  for _ = 1, 50 do
    if a.loot:random() == b.loot:random() then same = same + 1 end
  end
  H.is_true(same < 5, "nearby seeds must diverge")
end

T["streams are independent (loot rolls never shift spawns)"] = function()
  local a = RNG.new(777)
  local b = RNG.new(777)

  -- Burn extra rolls on a's loot stream only.
  for _ = 1, 25 do a.loot:random() end

  -- Spawn stream must be unaffected.
  for _ = 1, 20 do
    H.eq(a.spawn:random(), b.spawn:random())
  end
end

T["range stays inclusive within bounds"] = function()
  local rng = RNG.new(42)
  local saw_lo, saw_hi = false, false
  for _ = 1, 2000 do
    local v = rng.combat:range(1, 5)
    H.is_true(v >= 1 and v <= 5, "range out of bounds: " .. v)
    if v == 1 then saw_lo = true end
    if v == 5 then saw_hi = true end
  end
  H.is_true(saw_lo and saw_hi, "both endpoints should be reachable")
end

T["random stays in [0,1)"] = function()
  local rng = RNG.new(9)
  for _ = 1, 2000 do
    local v = rng.vfx:random()
    H.is_true(v >= 0 and v < 1, "out of range: " .. v)
  end
end

T["pick returns nil for empty lists and members otherwise"] = function()
  local rng = RNG.new(5)
  H.is_nil(rng.loot:pick({}))
  local list = { "a", "b", "c" }
  for _ = 1, 20 do
    local v = rng.loot:pick(list)
    H.is_true(v == "a" or v == "b" or v == "c")
  end
end

T["shuffle preserves all elements"] = function()
  local rng = RNG.new(31337)
  local list = { 1, 2, 3, 4, 5, 6, 7, 8 }
  rng.loot:shuffle(list)
  local seen = {}
  for _, v in ipairs(list) do seen[v] = true end
  for i = 1, 8 do
    H.is_true(seen[i], "element " .. i .. " lost in shuffle")
  end
end

T["seed zero does not lock the generator"] = function()
  local rng = RNG.new(0)
  local first = rng.loot:random()
  local second = rng.loot:random()
  H.is_true(first ~= second, "zero seed must still produce a sequence")
end

return T
