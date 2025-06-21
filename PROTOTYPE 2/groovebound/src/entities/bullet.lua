-- Bullet entity
-- Represents projectiles fired by the player

local Settings = require("src/core/settings")

-- Get ArenaManager singleton
local ArenaManager = require("src/systems/arena_manager")

local Bullet = {}

-- Create a new bullet
-- @param x - Starting X position
-- @param y - Starting Y position
-- @param dx - X direction component (normalized)
-- @param dy - Y direction component (normalized)
-- @param damage - Damage amount
-- @param speed - Movement speed
-- @param size - Size of the bullet
-- @param lifetime - Lifetime in seconds
-- @return A new bullet object
function Bullet.new(x, y, dx, dy, damage, speed, size, lifetime, shape)
  -- Debug logging if enabled
  if Settings.debug.enabled and Settings.debug.files.bullet then
    if Debug and Debug.log then
      Debug.log("BULLET", string.format("Creating bullet at (%.1f, %.1f) with direction (%.1f, %.1f)", x, y, dx, dy))
    end
  end
  
  local self = {
    x = x,                -- X position
    y = y,                -- Y position
    dx = dx,              -- X direction (normalized)
    dy = dy,              -- Y direction (normalized)
    speed = speed or Settings.weapons.base_weapon.bullet_speed,  -- Movement speed (pixels per second)
    damage = damage or Settings.weapons.base_weapon.damage,      -- Damage amount
    life = lifetime or Settings.weapons.base_weapon.bullet_lifetime, -- Lifetime in seconds
    size = size or Settings.weapons.base_weapon.bullet_size,     -- Size of the bullet
    dead = false,          -- Whether the bullet is dead
    color = Settings.weapons.base_weapon.bullet_color,
    shape = shape or "rectangle"
  }
  
  -- Set the metatable for the bullet object
  setmetatable(self, {__index = Bullet})
  
  return self
end

-- Update the bullet
-- @param dt - Delta time since last update
-- @return true if the bullet is dead (expired or hit something)
function Bullet:update(dt)
  -- Skip if already dead
  if self.dead then return true end
  
  -- Update position
  self.x = self.x + self.dx * self.speed * dt
  self.y = self.y + self.dy * self.speed * dt
  
  -- Update lifetime
  self.life = self.life - dt
  
  -- Check if lifetime expired
  if self.life <= 0 then
    self.dead = true
    return true
  end
  
  -- Check if bullet is outside arena bounds
  -- Use ArenaManager to determine if bullet is still in the playable area
  if not ArenaManager:isInside(self.x, self.y) then
    -- Mark as dead for cleanup, but don't draw
    self.dead = true
    
    -- Log bullet leaving arena if debug is enabled
    if Settings.debug.enabled and Settings.debug.files.bullet and Debug and Debug.log then
      Debug.log("BULLET", string.format("Bullet left arena at (%.1f, %.1f)", self.x, self.y))
    end
    
    return true
  end
  
  return false
end

-- Draw the bullet
function Bullet:draw()
  -- Skip if dead
  if self.dead then return end
  
  -- Save current graphics state
  love.graphics.push("all")
  
  love.graphics.setColor(self.color)

  local halfSize = self.size / 2
  if self.shape == "circle" then
    love.graphics.circle("fill", self.x, self.y, halfSize)
  else
    love.graphics.rectangle("fill", self.x - halfSize, self.y - halfSize, self.size, self.size)
  end
  
  -- Restore graphics state
  love.graphics.pop()
end

-- Mark the bullet as dead (hit something)
function Bullet:hit()
  self.dead = true
end

-- Get whether the bullet is dead
-- @return true if the bullet is dead
function Bullet:isDead()
  return self.dead
end

-- Return the bullet module
return Bullet
