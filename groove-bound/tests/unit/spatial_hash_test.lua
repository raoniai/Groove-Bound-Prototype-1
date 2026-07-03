local H = require("tests.helpers")
local SpatialHash = require("src.core.spatial_hash")

local T = {}

T["query finds overlapping circles and skips distant ones"] = function()
  local hash = SpatialHash(64)
  local near = { id = "near" }
  local far = { id = "far" }
  hash:insert(near, 100, 100, 10)
  hash:insert(far, 900, 900, 10)

  local hits = hash:query_circle(110, 100, 15)
  H.eq(#hits, 1)
  H.eq(hits[1].id, "near")
end

T["touching circles at exact range count as overlapping"] = function()
  local hash = SpatialHash(64)
  local obj = {}
  hash:insert(obj, 0, 0, 10)
  H.eq(#hash:query_circle(20, 0, 10), 1) -- distance 20 == r1 + r2
  H.eq(#hash:query_circle(21, 0, 10), 0)
end

T["objects spanning multiple cells are returned once"] = function()
  local hash = SpatialHash(32)
  local big = {}
  hash:insert(big, 32, 32, 40) -- covers several cells
  local hits = hash:query_circle(32, 32, 5)
  H.eq(#hits, 1, "no duplicates for multi-cell objects")
end

T["update tracks movement across cells"] = function()
  local hash = SpatialHash(64)
  local obj = {}
  hash:insert(obj, 10, 10, 5)
  hash:update(obj, 500, 500, 5)

  H.eq(#hash:query_circle(10, 10, 20), 0, "old position must be vacated")
  H.eq(#hash:query_circle(500, 500, 20), 1)
end

T["small moves within the same cells still update stored position"] = function()
  local hash = SpatialHash(64)
  local obj = {}
  hash:insert(obj, 30, 30, 5)
  hash:update(obj, 34, 30, 5) -- same cell span, fast path

  -- Query barely reaching the NEW position but not the old one.
  H.eq(#hash:query_circle(41, 30, 3), 1)
end

T["remove takes the object out of all queries"] = function()
  local hash = SpatialHash(64)
  local obj = {}
  hash:insert(obj, 100, 100, 10)
  hash:remove(obj)
  H.eq(#hash:query_circle(100, 100, 50), 0)
  H.eq(hash:count(), 0)
end

T["negative coordinates work"] = function()
  local hash = SpatialHash(64)
  local obj = {}
  hash:insert(obj, -100, -100, 10)
  H.eq(#hash:query_circle(-105, -100, 10), 1)
end

T["each_in_circle passes the stored entry"] = function()
  local hash = SpatialHash(64)
  hash:insert({ id = 1 }, 50, 60, 7)
  local got_entry
  hash:each_in_circle(50, 60, 5, function(_, entry) got_entry = entry end)
  H.eq(got_entry.x, 50)
  H.eq(got_entry.y, 60)
  H.eq(got_entry.r, 7)
end

T["clear empties everything"] = function()
  local hash = SpatialHash(64)
  hash:insert({}, 1, 1, 1)
  hash:insert({}, 2, 2, 1)
  hash:clear()
  H.eq(hash:count(), 0)
  H.eq(#hash:query_circle(1, 1, 100), 0)
end

T["stress: 500 objects query correctly"] = function()
  local hash = SpatialHash(64)
  -- Grid of objects every 50px; query a region and count expected hits.
  for gx = 0, 24 do
    for gy = 0, 19 do
      hash:insert({ gx = gx, gy = gy }, gx * 50, gy * 50, 5)
    end
  end
  H.eq(hash:count(), 500)

  -- Circle at (100,100) r=60 with object r=5: reaches 65px; brute-force count.
  local expected = 0
  for gx = 0, 24 do
    for gy = 0, 19 do
      local dx, dy = gx * 50 - 100, gy * 50 - 100
      if dx * dx + dy * dy <= 65 * 65 then expected = expected + 1 end
    end
  end
  H.eq(#hash:query_circle(100, 100, 60), expected)
end

return T
