-- World: owns entity collections, the spatial hash, and update order.
-- Systems and screens go through the world to add/remove/iterate entities;
-- nobody keeps private entity arrays (the prototype's duplicate-list bugs).

local class = require("src.core.class")
local SpatialHash = require("src.core.spatial_hash")
local settings = require("src.config.settings")

local World = class()

function World:init()
  self.hash = SpatialHash(settings.world.cell_size)
  self.entities = {}   -- kind -> array of entities
  self.counts = {}     -- kind -> live count
end

function World:add(kind, entity)
  local list = self.entities[kind]
  if not list then
    list = {}
    self.entities[kind] = list
    self.counts[kind] = 0
  end
  list[#list + 1] = entity
  self.counts[kind] = self.counts[kind] + 1
  if entity.x and entity.radius then
    self.hash:insert(entity, entity.x, entity.y, entity.radius)
  end
  return entity
end

-- Iterate live entities of a kind.
function World:each(kind, fn)
  local list = self.entities[kind]
  if not list then return end
  for i = 1, #list do
    local e = list[i]
    if not e.dead then fn(e) end
  end
end

function World:count(kind)
  if kind then return self.counts[kind] or 0 end
  local total = 0
  for _, n in pairs(self.counts) do total = total + n end
  return total
end

-- Update an entity's position in the spatial hash after it moves.
function World:moved(entity)
  self.hash:update(entity, entity.x, entity.y, entity.radius)
end

-- Sweep dead entities out of the lists and hash. Returns removed entities
-- per kind so callers can release them back to pools.
function World:sweep()
  local removed = {}
  for kind, list in pairs(self.entities) do
    local write = 1
    for read = 1, #list do
      local e = list[read]
      if e.dead then
        self.hash:remove(e)
        self.counts[kind] = self.counts[kind] - 1
        local bucket = removed[kind]
        if not bucket then
          bucket = {}
          removed[kind] = bucket
        end
        bucket[#bucket + 1] = e
      else
        list[write] = e
        write = write + 1
      end
    end
    for i = #list, write, -1 do
      list[i] = nil
    end
  end
  return removed
end

function World:clear()
  self.hash:clear()
  self.entities = {}
  self.counts = {}
end

return World
