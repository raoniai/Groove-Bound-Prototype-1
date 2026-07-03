-- Input abstraction: translates keyboard/mouse/gamepad into abstract intents.
-- Game code asks for move_vector / aim_vector / action states and never
-- touches key names or devices. The device backend is injectable for tests.
--
-- Aim resolution order: right stick beyond deadzone wins, else mouse
-- (converted through the camera), else the last non-zero aim direction —
-- so a gamepad player who releases the stick keeps shooting forward.

local class = require("src.core.class")
local controls = require("src.config.controls")
local settings = require("src.config.settings")

local Input = class()

local function love_backend()
  return {
    is_key_down = function(...) return love.keyboard.isDown(...) end,
    mouse_position = function() return love.mouse.getPosition() end,
    axis = function(name)
      local sticks = love.joystick.getJoysticks()
      local js = sticks[1]
      if js then return js:getGamepadAxis(name) end
      return 0
    end,
  }
end

function Input:init(opts)
  opts = opts or {}
  self.backend = opts.backend or love_backend()
  self.deadzone = settings.input.deadzone
  self.last_aim_x, self.last_aim_y = 1, 0 -- default: aim right
end

local function any_down(backend, keys)
  for i = 1, #keys do
    if backend.is_key_down(keys[i]) then return true end
  end
  return false
end

-- Normalized movement vector from keyboard + left stick.
function Input:move_vector()
  local kb = controls.keyboard
  local dx, dy = 0, 0

  if any_down(self.backend, kb.left) then dx = dx - 1 end
  if any_down(self.backend, kb.right) then dx = dx + 1 end
  if any_down(self.backend, kb.up) then dy = dy - 1 end
  if any_down(self.backend, kb.down) then dy = dy + 1 end

  -- Gamepad overrides keyboard when the stick is deflected past deadzone;
  -- analog magnitude is preserved for fine movement.
  local gp = controls.gamepad
  local ax = self.backend.axis(gp.move_x)
  local ay = self.backend.axis(gp.move_y)
  local mag = math.sqrt(ax * ax + ay * ay)
  if mag > self.deadzone then
    -- Rescale so movement ramps from 0 just past the deadzone.
    local scaled = math.min(1, (mag - self.deadzone) / (1 - self.deadzone))
    return ax / mag * scaled, ay / mag * scaled
  end

  local len = math.sqrt(dx * dx + dy * dy)
  if len > 0 then
    return dx / len, dy / len
  end
  return 0, 0
end

-- Normalized aim direction for a player at world position (px, py).
function Input:aim_vector(px, py, camera)
  local gp = controls.gamepad
  local ax = self.backend.axis(gp.aim_x)
  local ay = self.backend.axis(gp.aim_y)
  local mag = math.sqrt(ax * ax + ay * ay)

  if mag > self.deadzone then
    self.last_aim_x, self.last_aim_y = ax / mag, ay / mag
    self.aim_device = "gamepad"
    return self.last_aim_x, self.last_aim_y
  end

  -- Gamepad players keep their last direction when the stick centers;
  -- otherwise the mouse aims.
  if self.aim_device ~= "gamepad" then
    local mx, my = self.backend.mouse_position()
    if camera then
      mx, my = camera:screen_to_world(mx, my)
    end
    local dx, dy = mx - px, my - py
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.001 then
      self.last_aim_x, self.last_aim_y = dx / len, dy / len
    end
  end

  return self.last_aim_x, self.last_aim_y
end

-- Event-driven action checks for screens (called from keypressed handlers).
function Input.is_action(key, action)
  local keys = controls.keyboard[action]
  if not keys then return false end
  for i = 1, #keys do
    if keys[i] == key then return true end
  end
  return false
end

function Input.is_gamepad_action(button, action)
  return controls.gamepad[action] == button
end

return Input
