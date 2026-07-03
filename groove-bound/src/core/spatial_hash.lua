-- Uniform-grid spatial hash for broad-phase collision and neighbor queries.
-- Replaces the prototypes' O(n²) all-pairs loops: bullets, enemies, and
-- pickups register here and systems query only nearby cells.
--
--   local hash = SpatialHash(64)          -- cell size ~ 2x max entity radius
--   hash:insert(obj, x, y, r)
--   hash:update(obj, x, y, r)             -- call when the object moves
--   hash:remove(obj)
--   hash:query_circle(x, y, r)            -- array of objects overlapping it
--   hash:each_in_circle(x, y, r, fn)      -- allocation-light iteration

local class = require("src.core.class")

local SpatialHash = class()

function SpatialHash:init(cell_size)
  assert(cell_size and cell_size > 0, "SpatialHash needs a positive cell size")
  self.cell_size = cell_size
  self.cells = {}   -- "cx:cy" -> { obj = true, ... }
  self.entries = {} -- obj -> { x, y, r, keys = {key1, ...} }
end

local function cell_range(self, x, y, r)
  local cs = self.cell_size
  return math.floor((x - r) / cs), math.floor((x + r) / cs),
         math.floor((y - r) / cs), math.floor((y + r) / cs)
end

function SpatialHash:insert(obj, x, y, r)
  assert(self.entries[obj] == nil, "object already in spatial hash")
  local entry = { x = x, y = y, r = r, keys = {} }
  self.entries[obj] = entry

  local x0, x1, y0, y1 = cell_range(self, x, y, r)
  for cy = y0, y1 do
    for cx = x0, x1 do
      local key = cx .. ":" .. cy
      local cell = self.cells[key]
      if not cell then
        cell = {}
        self.cells[key] = cell
      end
      cell[obj] = true
      entry.keys[#entry.keys + 1] = key
    end
  end
end

function SpatialHash:remove(obj)
  local entry = self.entries[obj]
  if not entry then return end
  for i = 1, #entry.keys do
    local cell = self.cells[entry.keys[i]]
    if cell then
      cell[obj] = nil
      if next(cell) == nil then
        self.cells[entry.keys[i]] = nil
      end
    end
  end
  self.entries[obj] = nil
end

function SpatialHash:update(obj, x, y, r)
  local entry = self.entries[obj]
  if not entry then
    self:insert(obj, x, y, r)
    return
  end

  -- Skip the rehash when the object stayed within the same cell span.
  local ox0, ox1, oy0, oy1 = cell_range(self, entry.x, entry.y, entry.r)
  local nx0, nx1, ny0, ny1 = cell_range(self, x, y, r)
  if ox0 == nx0 and ox1 == nx1 and oy0 == ny0 and oy1 == ny1 then
    entry.x, entry.y, entry.r = x, y, r
    return
  end

  self:remove(obj)
  self:insert(obj, x, y, r)
end

-- Iterate every object whose stored circle overlaps the query circle.
function SpatialHash:each_in_circle(x, y, r, fn)
  local x0, x1, y0, y1 = cell_range(self, x, y, r)
  local seen = {}
  for cy = y0, y1 do
    for cx = x0, x1 do
      local cell = self.cells[cx .. ":" .. cy]
      if cell then
        for obj in pairs(cell) do
          if not seen[obj] then
            seen[obj] = true
            local e = self.entries[obj]
            local dx, dy = e.x - x, e.y - y
            local rr = e.r + r
            if dx * dx + dy * dy <= rr * rr then
              fn(obj, e)
            end
          end
        end
      end
    end
  end
end

function SpatialHash:query_circle(x, y, r)
  local out = {}
  self:each_in_circle(x, y, r, function(obj)
    out[#out + 1] = obj
  end)
  return out
end

function SpatialHash:count()
  local n = 0
  for _ in pairs(self.entries) do n = n + 1 end
  return n
end

function SpatialHash:clear()
  self.cells = {}
  self.entries = {}
end

return SpatialHash
