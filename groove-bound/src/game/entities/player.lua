-- Player entity: movement, aim, health fields. Weapons and damage arrive in
-- Phase 2; this entity stays a data holder + movement — combat is owned by
-- systems, not the player (single-owner rule).

local class = require("src.core.class")
local settings = require("src.config.settings")

local Player = class()

function Player:init(opts)
  opts = opts or {}
  local cfg = settings.player
  self.x = opts.x or 0
  self.y = opts.y or 0
  self.speed = cfg.speed
  self.radius = cfg.size / 2
  self.hp = cfg.hp
  self.max_hp = cfg.hp
  self.aim_x, self.aim_y = 1, 0
  self.dead = false
end

function Player:update(dt, input, camera, arena)
  local mx, my = input:move_vector()
  self.x = self.x + mx * self.speed * dt
  self.y = self.y + my * self.speed * dt
  self.x, self.y = arena:clamp(self.x, self.y, self.radius)

  self.aim_x, self.aim_y = input:aim_vector(self.x, self.y, camera)
end

function Player:draw()
  -- Body.
  love.graphics.setColor(0.95, 0.92, 0.85, 1)
  love.graphics.circle("fill", self.x, self.y, self.radius)
  love.graphics.setColor(0.3, 0.25, 0.2, 1)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", self.x, self.y, self.radius)

  -- Aim indicator.
  love.graphics.setColor(0.4, 0.95, 0.55, 0.9)
  love.graphics.line(
    self.x + self.aim_x * self.radius,
    self.y + self.aim_y * self.radius,
    self.x + self.aim_x * self.radius * 2.2,
    self.y + self.aim_y * self.radius * 2.2)
end

return Player
