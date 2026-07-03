-- Hitbox visualization: draws every collision circle straight from the
-- world's spatial-hash entries, so what you see is exactly what collides —
-- never a separately maintained copy of the shapes.

local settings = require("src.config.settings")

local Hitboxes = {}

-- Module-level toggle flipped by the F3 debug key on the run screen.
Hitboxes.visible = false

function Hitboxes.toggle()
  Hitboxes.visible = not Hitboxes.visible
end

-- Draw within camera space.
function Hitboxes.draw(world)
  if not Hitboxes.visible or not settings.debug.enabled then return end

  love.graphics.push("all")
  love.graphics.setColor(0.7, 0.7, 0.75, 0.7)
  love.graphics.setLineWidth(1)
  for _, entry in pairs(world.hash.entries) do
    love.graphics.circle("line", entry.x, entry.y, entry.r)
  end
  love.graphics.pop()
end

return Hitboxes
