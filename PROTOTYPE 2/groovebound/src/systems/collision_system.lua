-- Collision System
-- Handles all collision detection and resolution between game objects
-- Supports multiple collision shapes and response types

local Settings = require("src/core/settings")

local CollisionSystem = {}

-- Initialize the collision system
-- @return self for chaining
function CollisionSystem:init()
  -- Log initialization
  if _G.SafeLog then
    SafeLog("SYSTEM", "Collision system initialized")
  elseif Logger and Logger.info then
    Logger:info("Collision system initialized")
  else
    print("Collision system initialized")
  end
  
  return self
end

-- Check if two rectangles are colliding
-- @param x1, y1 - Center of first rectangle
-- @param w1, h1 - Width and height of first rectangle
-- @param x2, y2 - Center of second rectangle
-- @param w2, h2 - Width and height of second rectangle
-- @return boolean - True if colliding
function CollisionSystem:checkRectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
  -- Convert from center coordinates to top-left corner
  local left1 = x1 - w1/2
  local right1 = x1 + w1/2
  local top1 = y1 - h1/2
  local bottom1 = y1 + h1/2
  
  local left2 = x2 - w2/2
  local right2 = x2 + w2/2
  local top2 = y2 - h2/2
  local bottom2 = y2 + h2/2
  
  -- Check if rectangles overlap
  return not (right1 < left2 or 
              left1 > right2 or 
              bottom1 < top2 or 
              top1 > bottom2)
end

-- Check collision between a circle and a rectangle
-- circle at (cx,cy) radius r; rectangle centered at (rx,ry) with width rw and height rh
function CollisionSystem:checkCircleRect(cx, cy, r, rx, ry, rw, rh)
  local dx = math.abs(cx - rx)
  local dy = math.abs(cy - ry)

  if dx > (rw/2 + r) then return false end
  if dy > (rh/2 + r) then return false end

  if dx <= rw/2 then return true end
  if dy <= rh/2 then return true end

  local cornerDist = (dx - rw/2)^2 + (dy - rh/2)^2
  return cornerDist <= r^2
end

-- Check if two circles are colliding
-- @param x1, y1 - Center of first circle
-- @param r1 - Radius of first circle
-- @param x2, y2 - Center of second circle
-- @param r2 - Radius of second circle
-- @return boolean - True if colliding
function CollisionSystem:checkCircleCollision(x1, y1, r1, x2, y2, r2)
  -- Calculate distance between centers
  local dx = x2 - x1
  local dy = y2 - y1
  local distance = math.sqrt(dx * dx + dy * dy)
  
  -- Collision if distance is less than sum of radii
  return distance < (r1 + r2)
end

-- Check collision between player and enemy
-- @param player - Player entity
-- @param enemy - Enemy entity
-- @return boolean - True if colliding
function CollisionSystem:checkPlayerEnemyCollision(player, enemy)
  -- Skip if enemy is dead
  if enemy.isDead then
    return false
  end
  
  -- Skip if player collision is disabled in settings
  if not Settings.collision.enable_enemy_player then
    return false
  end
  
  -- Calculate collision for rectangles using their center positions and sizes
  return self:checkRectCollision(
    player.x, player.y, player.rectSize, player.rectSize,
    enemy.x, enemy.y, enemy.rectSize, enemy.rectSize
  )
end

-- Check collision between bullet and enemy
-- @param bullet - Bullet entity
-- @param enemy - Enemy entity
-- @return boolean - True if colliding
function CollisionSystem:checkBulletEnemyCollision(bullet, enemy)
  -- Skip if enemy is dead
  if enemy.isDead then
    return false
  end
  
  if bullet.shape == "circle" then
    return self:checkCircleRect(
      bullet.x, bullet.y, bullet.size/2,
      enemy.x, enemy.y, enemy.rectSize, enemy.rectSize
    )
  else
    return self:checkRectCollision(
      bullet.x, bullet.y, bullet.size, bullet.size,
      enemy.x, enemy.y, enemy.rectSize, enemy.rectSize
    )
  end
end

-- Check collision between player and XP gem
-- @param player - Player entity
-- @param gem - XP gem entity
-- @return boolean - True if colliding
function CollisionSystem:checkPlayerGemCollision(player, gem)
  -- Skip if gem is already collected
  if gem.isCollected then
    return false
  end
  
  -- Check collision for circles (gems and player are better represented as circles)
  return self:checkCircleCollision(
    player.x, player.y, player.rectSize/2,
    gem.x, gem.y, gem.rectSize/2
  )
end

-- Handle collision between player and enemy
-- @param player - Player entity
-- @param enemy - Enemy entity
-- @param camera - Optional camera for shake effect
function CollisionSystem:handlePlayerEnemyCollision(player, enemy, camera)
  -- Skip if player has immunity frames active
  if player.immunityTime > 0 then
    return
  end
  
  -- Apply damage to player
  local damage = enemy.damage or Settings.enemies.basic.damage
  player:takeDamage(damage)
  
  -- Apply knockback to player away from enemy
  local knockbackForce = Settings.collision.knockback_force
  local angle = math.atan2(player.y - enemy.y, player.x - enemy.x)
  player.knockbackX = math.cos(angle) * knockbackForce
  player.knockbackY = math.sin(angle) * knockbackForce
  
  -- Apply camera shake if camera is provided
  if camera then
    camera:shake()
  end
  
  -- Log collision if debug is enabled
  if Debug and Debug.log then
    Debug.log("COLLISION", "Player took " .. damage .. " damage from enemy")
  end
end

-- Draw collision debug visuals
-- @param objects - Table of objects to show collision for
function CollisionSystem:drawDebug(objects)
  -- Only draw if hitboxes are enabled in settings
  if not Settings.collision.show_hitboxes then
    return
  end
  
  -- Save current graphics state
  love.graphics.push("all")
  
  -- Set line style for hitboxes
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 0, 1, 0.5) -- Purple for hitboxes
  
  -- Draw hitbox for each object
  for _, obj in ipairs(objects) do
    if obj.x and obj.y and obj.rectSize then
      -- Draw rectangle hitbox
      local halfSize = obj.rectSize / 2
      love.graphics.rectangle(
        "line", 
        obj.x - halfSize, 
        obj.y - halfSize, 
        obj.rectSize, 
        obj.rectSize
      )
    end
  end
  
  -- Restore graphics state
  love.graphics.pop()
end

-- Return the module
return CollisionSystem
