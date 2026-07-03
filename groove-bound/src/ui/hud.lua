-- Run HUD: health bar, run timer, and (in debug) an FPS/entity readout.
-- Screen-space only; drawn after the camera detaches. Fonts come from the
-- cached registry — creating fonts in draw() is banned.

local class = require("src.core.class")
local Fonts = require("src.ui.fonts")
local settings = require("src.config.settings")

local HUD = class()

function HUD:init(ctx, player)
  self.ctx = ctx
  self.player = player
end

function HUD:draw()
  local w = love.graphics.getWidth()

  -- Health bar, top-left.
  local bar_x, bar_y, bar_w, bar_h = 16, 16, 240, 20
  local hp_frac = math.max(0, self.player.hp / self.player.max_hp)

  love.graphics.setColor(0.15, 0.12, 0.18, 0.85)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 4, 4)
  love.graphics.setColor(0.85, 0.25, 0.30, 1)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w * hp_frac, bar_h, 4, 4)
  love.graphics.setColor(0.6, 0.55, 0.7, 1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 4, 4)

  love.graphics.setColor(settings.ui.text_color)
  love.graphics.setFont(Fonts.get(13))
  love.graphics.print(
    string.format("HP %d / %d", math.floor(self.player.hp), self.player.max_hp),
    bar_x + 8, bar_y + 3)

  -- Run timer, top-center.
  local minutes = math.floor(self.ctx.time / 60)
  local seconds = math.floor(self.ctx.time % 60)
  love.graphics.setFont(Fonts.get(24))
  love.graphics.setColor(settings.ui.text_color)
  love.graphics.printf(string.format("%02d:%02d", minutes, seconds), 0, 14, w, "center")

  -- Debug readout, top-right.
  if settings.debug.enabled then
    love.graphics.setFont(Fonts.get(12))
    love.graphics.setColor(0.6, 0.9, 0.6, 0.9)
    local text = string.format("fps %d  entities %d  seed %d",
      love.timer.getFPS(), self.ctx.world:count(), self.ctx.seed)
    love.graphics.printf(text, 0, 18, w - 16, "right")
  end
end

return HUD
