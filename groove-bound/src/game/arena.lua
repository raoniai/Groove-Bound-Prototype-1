-- The playfield: a rectangle with walls. Owns bounds math (clamp/contains)
-- and its own rendering. Entities query it; nothing else knows arena size.

local class = require("src.core.class")
local settings = require("src.config.settings")

local Arena = class()

function Arena:init(opts)
  opts = opts or settings.arena
  self.width = opts.width
  self.height = opts.height
  self.wall = opts.wall
end

function Arena:center()
  return self.width / 2, self.height / 2
end

-- Clamp a point so a body of the given radius stays inside the walls.
function Arena:clamp(x, y, radius)
  radius = radius or 0
  local lo = self.wall + radius
  return math.max(lo, math.min(x, self.width - self.wall - radius)),
         math.max(lo, math.min(y, self.height - self.wall - radius))
end

function Arena:contains(x, y, radius)
  radius = radius or 0
  local lo = self.wall + radius
  return x >= lo and y >= lo
     and x <= self.width - self.wall - radius
     and y <= self.height - self.wall - radius
end

function Arena:draw()
  local cfg = settings.arena

  -- Floor.
  love.graphics.setColor(cfg.floor_color)
  love.graphics.rectangle("fill", 0, 0, self.width, self.height)

  -- Background grid so motion is readable on a flat floor.
  love.graphics.setColor(cfg.grid_color)
  love.graphics.setLineWidth(1)
  for x = cfg.grid_step, self.width - 1, cfg.grid_step do
    love.graphics.line(x, 0, x, self.height)
  end
  for y = cfg.grid_step, self.height - 1, cfg.grid_step do
    love.graphics.line(0, y, self.width, y)
  end

  -- Walls.
  love.graphics.setColor(cfg.wall_color)
  love.graphics.rectangle("fill", 0, 0, self.width, self.wall)
  love.graphics.rectangle("fill", 0, self.height - self.wall, self.width, self.wall)
  love.graphics.rectangle("fill", 0, 0, self.wall, self.height)
  love.graphics.rectangle("fill", self.width - self.wall, 0, self.wall, self.height)
end

return Arena
