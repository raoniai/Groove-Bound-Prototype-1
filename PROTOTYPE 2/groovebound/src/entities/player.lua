-- Player entity
-- Handles player movement, weapons, and related functionality

local Input = require("src/core/input")
local Bullet = require("src/entities/bullet")
local EventBus = require("src/core/event_bus")
local Settings = require("src/core/settings")
local WeaponsData = require("src/data/weapons")

local Player = {}

-- Create a new player
-- @param x - X position
-- @param y - Y position
-- @param arenaManager - Reference to arena manager
-- @return A new player entity
function Player.new(x, y, arenaManager)
  -- Get player settings from globals
  local playerSettings = Settings.player
  
  local self = {
    -- Core properties
    x = x or 0,              -- X position
    y = y or 0,              -- Y position
    speed = playerSettings.speed,        -- Movement speed (pixels per second)
    baseSpeed = playerSettings.speed,    -- Base movement speed (for upgrades)
    hp = playerSettings.hp,              -- Health points
    maxHp = playerSettings.hp,           -- Maximum health points
    rectSize = playerSettings.size,      -- Player rectangle size
    aimDirectionX = 1,       -- Aim direction X component
    aimDirectionY = 0,       -- Aim direction Y component
    arenaManager = arenaManager, -- Reference to arena manager
    camera = nil,            -- Reference to camera (set externally)
    alive = true,            -- Whether player is alive
    
    -- Status effects
    immunityTime = 0,         -- Invincibility timer after taking damage
    immunityDuration = playerSettings.iframes, -- Invincibility duration
    damageFlashTime = 0,      -- Flash timer when damaged
    knockbackX = 0,           -- Knockback X component
    knockbackY = 0,           -- Knockback Y component
    knockbackResistance = 10, -- How quickly knockback diminishes
    
    -- Inventory and weapons
    weapons = {
      {
        name = Settings.weapons.base_weapon.name,   -- Weapon name
        damage = Settings.weapons.base_weapon.damage,  -- Damage per bullet
        level = 1,              -- Weapon level
        fireRate = Settings.weapons.base_weapon.fire_rate,  -- Time between shots
        bulletSpeed = Settings.weapons.base_weapon.bullet_speed, -- Bullet speed
        bulletSize = Settings.weapons.base_weapon.bullet_size,   -- Bullet size
        bulletLifetime = Settings.weapons.base_weapon.bullet_lifetime, -- Bullet lifetime
        fireTimer = 0,           -- Timer for next shot
        enabled = true,          -- Whether weapon is active
        isPassive = false        -- Whether this is a passive item
      }
      -- Additional weapons will be added here through upgrades
    },
    passives = {},            -- Passive items (max 4)
    bullets = {}              -- Active bullets
  }
  
  -- Set the metatable for the player object
  setmetatable(self, {__index = Player})
  
  return self
end

-- Update player position and state
-- @param dt - Delta time since last update
function Player:update(dt)
  -- Skip full update if player is dead, just update visual effects
  if not self.alive then
    -- Just update any remaining effects/particles
    -- Update bullets that may still be active
    self:updateBullets(dt)
    return
  end
  
  -- Skip update if immunity frames are active
  if self.immunityTime > 0 then
    self.immunityTime = self.immunityTime - dt
  end
  
  -- Handle damage flash effect
  if self.damageFlashTime > 0 then
    self.damageFlashTime = self.damageFlashTime - dt
  end
  
  -- Apply knockback and reduce it over time
  if self.knockbackX ~= 0 or self.knockbackY ~= 0 then
    -- Apply knockback to movement
    self.x = self.x + self.knockbackX * dt
    self.y = self.y + self.knockbackY * dt
    
    -- Reduce knockback over time
    local resistance = self.knockbackResistance * dt
    self.knockbackX = self:approach(self.knockbackX, 0, resistance)
    self.knockbackY = self:approach(self.knockbackY, 0, resistance)
  end
  
  -- Get movement input
  local dx, dy = Input:getMovementDirection()
  
  -- Apply movement speed
  self.x = self.x + dx * self.speed * dt
  self.y = self.y + dy * self.speed * dt
  
  -- Handle arena bounds
  if self.arenaManager then
    -- Ensure player stays within the arena
    local padding = self.rectSize / 2
    self.x, self.y = self.arenaManager:constrain(self.x, self.y, padding + self.arenaManager.borderThickness)
  else
    -- Fallback to window dimensions if no arena manager
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local halfSize = self.rectSize / 2
    
    -- Ensure player stays within the window boundaries
    self.x = math.max(halfSize, math.min(self.x, windowWidth - halfSize))
    self.y = math.max(halfSize, math.min(self.y, windowHeight - halfSize))
  end
  
  -- Update aim direction - convert screen mouse coords to world coords
  if self.camera then
    -- Use camera for proper coordinate conversion
    self.aimDirectionX, self.aimDirectionY = Input:getAimDirection(self.x, self.y, self.camera)
    
    -- Log aim direction for debugging
    if Debug and Debug.log then
      -- Debug.log("AIM", string.format("Direction: %.2f, %.2f", self.aimDirectionX, self.aimDirectionY))
    end
  else
    -- Fallback if no camera (should not happen in normal gameplay)
    self.aimDirectionX, self.aimDirectionY = Input:getAimDirection(self.x, self.y)
  end
  
  -- Handle weapon firing
  self:updateWeapons(dt)
  
  -- Update bullets
  self:updateBullets(dt)
  
  -- Check for death
  if self.hp <= 0 and self.alive then
    self.alive = false
    
    -- Emit player death event
    if EventBus then
      EventBus:emit("PLAYER_DIED", {})
    end
    
    -- Log death
    if Debug and Debug.log then
      Debug.log("PLAYER", "Player died")
    end
  end
end

-- Update bullets
-- @param dt - Delta time since last update
function Player:updateBullets(dt)
  for i = #self.bullets, 1, -1 do
    local bullet = self.bullets[i]
    bullet:update(dt)
    
    -- Remove bullets that should be removed
    if bullet.remove or bullet:isDead() then
      table.remove(self.bullets, i)
    end
  end
end

-- Update all weapons and handle auto-firing
-- @param dt - Delta time since last update
function Player:updateWeapons(dt)
  -- Process each weapon
  for i, weapon in ipairs(self.weapons) do
    -- Skip disabled weapons
    if not weapon.enabled then goto continue end
    
    -- Update weapon cooldown timer
    weapon.fireTimer = weapon.fireTimer - dt
    
    -- Check if auto-fire is enabled in settings
    if Settings.weapons.auto_fire then
      -- Auto-fire when ready
      if weapon.fireTimer <= 0 then
        weapon.fireTimer = weapon.fireRate
        self:fireWeapon(weapon)
      end
    else
      -- Manual fire when button pressed and ready
      if weapon.fireTimer <= 0 and Input:isFirePressed() then
        weapon.fireTimer = weapon.fireRate
        self:fireWeapon(weapon)
      end
    end
    
    ::continue::
  end
end

-- Fire a weapon
-- @param weapon - The weapon to fire
function Player:fireWeapon(weapon)
  -- Get bullet count (default to 1 if not specified)
  local bulletCount = weapon.bullet_count or 1
  
  -- Ensure we have at least 1 bullet
  bulletCount = math.max(1, bulletCount)
  
  -- Get spread settings
  local spreadMode = "fixed"
  local spreadAngle = 0
  
  if weapon.spread then
    spreadMode = weapon.spread.mode or "fixed"
    spreadAngle = weapon.spread.angle or 0
  end
  
  -- Log debug info
  if Debug and Debug.log and Settings.debug.files.weapon then
    Debug.log("WEAPON", string.format("Firing %s with %d bullets, spread: %s", 
      weapon.name, bulletCount, spreadMode))
  end
  
  -- Fire multiple bullets according to spread pattern
  for i = 1, bulletCount do
    -- Calculate direction based on spread type
    local dirX, dirY = self.aimDirectionX, self.aimDirectionY
    
    if bulletCount > 1 then
      -- Convert original direction to angle
      local baseAngle = math.atan2(self.aimDirectionY, self.aimDirectionX)
      local finalAngle = baseAngle
      
      if spreadMode == "fixed" then
        -- Fixed angle spread
        -- Calculate offset from center based on bullet index
        -- For 3 bullets with 10 degree spread: -10, 0, 10 degrees
        local offset = spreadAngle * (i - (bulletCount + 1) / 2) / (bulletCount - 1)
        finalAngle = baseAngle + math.rad(offset)
      elseif spreadMode == "full" then
        -- Full 360 degree spread
        local angleStep = 2 * math.pi / bulletCount
        finalAngle = baseAngle + angleStep * (i - 1)
      end
      
      -- Convert angle back to direction vector
      dirX = math.cos(finalAngle)
      dirY = math.sin(finalAngle)
    end
    
    -- Log individual bullet direction in debug mode
    if Debug and Debug.log and Settings.debug.files.bullet then
      local angle = math.deg(math.atan2(dirY, dirX))
      Debug.log("BULLET", string.format("Bullet %d/%d angle: %.1f°", 
        i, bulletCount, angle))
    end
    
    -- Create the bullet with calculated direction
    local bullet = Bullet.new(
      self.x,
      self.y,
      dirX,
      dirY,
      weapon.damage,
      weapon.bulletSpeed,
      weapon.bulletSize,
      weapon.bulletLifetime,
      "circle"
    )
    
    -- Set bullet color if specified
    if weapon.bullet_color then
      bullet.color = weapon.bullet_color
    end
    
    -- Add bullet to the list
    table.insert(self.bullets, bullet)
  end
  
  -- Log weapon firing if debug is enabled
  if Debug and Debug.log then
    Debug.log("WEAPON", "Fired " .. weapon.name .. " (Level " .. weapon.level .. ")")
  end
end

-- Draw the player
function Player:draw()
  -- Save current graphics state
  love.graphics.push("all")
  
  -- Calculate player color based on immunity and damage flash
  local r, g, b, a = 1, 1, 1, 1
  
  -- Apply damage flash effect (red tint)
  if self.damageFlashTime > 0 then
    r, g, b = 1, 0.3, 0.3
  end
  
  -- Apply immunity effect (pulsing alpha)
  if self.immunityTime > 0 then
    local pulse = math.sin(love.timer.getTime() * 10) * 0.3 + 0.7
    a = pulse
  end
  
  -- Set color with all effects applied
  love.graphics.setColor(r, g, b, a)
  
  local halfSize = self.rectSize / 2
  love.graphics.polygon("fill",
    self.x, self.y - halfSize,
    self.x - halfSize, self.y + halfSize,
    self.x + halfSize, self.y + halfSize
  )
  
  -- Draw direction indicator (line pointing in aim direction)
  love.graphics.setColor(0, 1, 0, a) -- Green indicator
  love.graphics.line(
    self.x,
    self.y,
    self.x + self.aimDirectionX * self.rectSize,
    self.y + self.aimDirectionY * self.rectSize
  )
  
  -- Draw bullets
  for _, bullet in ipairs(self.bullets) do
    bullet:draw()
  end
  
  -- Draw health bar above player
  self:drawHealthBar()
  
  -- Restore graphics state
  love.graphics.pop()
end

-- Draw health bar above player
function Player:drawHealthBar()
  -- Bar dimensions
  local barWidth = self.rectSize * 1.5
  local barHeight = 4
  local barY = self.y - self.rectSize / 2 - 8
  local barX = self.x - barWidth / 2
  
  -- Background (empty health)
  love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
  love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
  
  -- Foreground (current health)
  local healthPercent = self.hp / self.maxHp
  love.graphics.setColor(1 - healthPercent, healthPercent, 0, 0.8)
  love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
  
  -- Border
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
end

-- Apply damage to the player
-- @param amount - Amount of damage to apply
-- @param sourceX - X position of damage source (for knockback)
-- @param sourceY - Y position of damage source (for knockback)
-- @param knockbackForce - Optional knockback force
function Player:takeDamage(amount, sourceX, sourceY, knockbackForce)
  -- Skip if player has immunity frames active
  if self.immunityTime > 0 then return end
  
  -- Apply damage
  self.hp = math.max(0, self.hp - amount)
  
  -- Log damage taken
  if Debug and Debug.log then
    Debug.log("PLAYER", "Took " .. amount .. " damage. HP: " .. self.hp)
  end
  
  -- Apply damage effects
  self.immunityTime = self.immunityDuration
  self.damageFlashTime = 0.2
  
  -- Apply knockback if source position is provided
  if sourceX and sourceY then
    -- Calculate direction from source to player
    local dx = self.x - sourceX
    local dy = self.y - sourceY
    
    -- Normalize the direction
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
      dx = dx / len
      dy = dy / len
    else
      -- Default to random direction if source is at same position
      local angle = math.random() * math.pi * 2
      dx = math.cos(angle)
      dy = math.sin(angle)
    end
    
    -- Apply knockback force
    local force = knockbackForce or 200
    self.knockbackX = dx * force
    self.knockbackY = dy * force
  end
  
  -- Emit damage event
  if EventBus then
    EventBus:emit("PLAYER_DAMAGED", {damage = amount, hp = self.hp})
  end
  
  -- Check for death
  if self.hp <= 0 then
    self.alive = false
    if EventBus then
      EventBus:emit("PLAYER_DIED", {})
    end
  end
end

-- Add a new weapon to the player's inventory
-- @param weapon - The weapon to add
-- @return True if weapon was added, false if inventory is full
function Player:addWeapon(weapon)
  -- Check if there's room in the inventory
  if #self.weapons < Settings.globals.max_weapon_slots then
    -- Get default values for new weapons
    local defaults = Settings.weapons.base_weapon
    
    -- Add missing properties if needed
    weapon.level = weapon.level or 1
    weapon.damage = weapon.damage or defaults.damage
    weapon.fireRate = weapon.fireRate or defaults.fire_rate
    weapon.bulletSpeed = weapon.bulletSpeed or defaults.bullet_speed
    weapon.bulletSize = weapon.bulletSize or defaults.bullet_size
    weapon.bulletLifetime = weapon.bulletLifetime or defaults.bullet_lifetime
    weapon.fireTimer = 0
    weapon.enabled = true
    
    -- Add to inventory
    table.insert(self.weapons, weapon)
    return true
  end

  return false
end

-- Check if the player is dead
-- @return True if player is dead, false otherwise
function Player:isDead()
  return not self.alive
end

-- Utility function to smoothly approach a target value
-- @param current - Current value
-- @param target - Target value
-- @param delta - Maximum change allowed
-- @return New value moved toward target
function Player:approach(current, target, delta)
  if current < target then
    return math.min(current + delta, target)
  else
    return math.max(current - delta, target)
  end
end

-- Return the Player module
return Player