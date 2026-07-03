-- Seeded RNG with named streams for deterministic runs.
--
-- A run seed fans out into independent streams so that, e.g., extra loot rolls
-- never shift enemy spawn positions:
--   local rng = RNG.new(seed)
--   rng.loot:random()          -- [0,1)
--   rng.spawn:range(1, 10)     -- integer in [1,10]
--   rng.vfx:pick(list)
--
-- Implementation: 32-bit xorshift* variant using LuaJIT's bit library (also
-- present in LÖVE). Quality is plenty for gameplay; the point is determinism.

local bit = require("bit")
local class = require("src.core.class")

local band, bxor, lshift, rshift = bit.band, bit.bxor, bit.lshift, bit.rshift

local Stream = class()

local MASK32 = 0xFFFFFFFF

function Stream:init(seed)
  -- Avoid the all-zero state, which xorshift can never leave.
  self.state = band(seed, MASK32)
  if self.state == 0 then
    self.state = 0x9E3779B9
  end
  -- Warm up so nearby seeds diverge quickly.
  for _ = 1, 4 do
    self:_next()
  end
end

function Stream:_next()
  local x = self.state
  x = bxor(x, band(lshift(x, 13), MASK32))
  x = bxor(x, rshift(x, 17))
  x = bxor(x, band(lshift(x, 5), MASK32))
  self.state = band(x, MASK32)
  return self.state
end

-- Float in [0, 1).
function Stream:random()
  -- bit ops return signed 32-bit ints in LuaJIT; normalize to [0, 2^32).
  local v = self:_next() % 2 ^ 32
  return v / 2 ^ 32
end

-- Integer in [lo, hi] inclusive.
function Stream:range(lo, hi)
  assert(lo <= hi, "range lo must be <= hi")
  return lo + math.floor(self:random() * (hi - lo + 1))
end

-- Float in [lo, hi).
function Stream:uniform(lo, hi)
  return lo + self:random() * (hi - lo)
end

-- Random element of an array (nil for empty).
function Stream:pick(list)
  local n = #list
  if n == 0 then return nil end
  return list[self:range(1, n)]
end

-- True with probability p.
function Stream:chance(p)
  return self:random() < p
end

-- In-place Fisher-Yates shuffle.
function Stream:shuffle(list)
  for i = #list, 2, -1 do
    local j = self:range(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

local RNG = {}

-- Stream names are fixed: adding a mid-run roll to one stream must never
-- perturb the others, and a fixed list keeps stream creation deterministic.
local STREAM_NAMES = { "loot", "spawn", "combat", "vfx" }

function RNG.new(seed)
  seed = seed or os.time()
  local self = { seed = seed }
  for i, name in ipairs(STREAM_NAMES) do
    -- Derive per-stream seeds by mixing the run seed with the stream index.
    self[name] = Stream(band(bxor(seed, i * 0x85EBCA6B), MASK32))
  end
  return self
end

RNG.Stream = Stream

return RNG
