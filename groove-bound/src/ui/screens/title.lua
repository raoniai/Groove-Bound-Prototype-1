-- Title screen. Constructed per visit (instance state), receives its
-- dependencies via the app table — no ambient globals.

local class = require("src.core.class")
local Fonts = require("src.ui.fonts")
local settings = require("src.config.settings")
local widgets = require("src.ui.widgets.button")

local TitleScreen = class()

function TitleScreen:init(app)
  self.app = app
end

function TitleScreen:enter()
  self.app.log.info("state", "Title screen entered")
  self:_layout()
end

function TitleScreen:_layout()
  local w, h = love.graphics.getDimensions()
  local bw, bh, gap = 260, 52, 18
  local x = (w - bw) / 2
  local y = h * 0.5

  local buttons = {
    widgets.Button({
      label = "Play", x = x, y = y, w = bw, h = bh,
      on_press = function()
        -- Run screen lands in Phase 1; log so the click visibly works.
        self.app.log.info("state", "Play pressed (run screen arrives in Phase 1)")
      end,
    }),
    widgets.Button({
      label = "Quit", x = x, y = y + (bh + gap), w = bw, h = bh,
      on_press = function() love.event.quit() end,
    }),
  }
  self.button_list = widgets.ButtonList(buttons)
end

function TitleScreen:resize()
  self:_layout()
end

function TitleScreen:update(dt) -- luacheck: ignore 212
end

function TitleScreen:draw()
  local w, h = love.graphics.getDimensions()

  love.graphics.setColor(settings.ui.background_color)
  love.graphics.rectangle("fill", 0, 0, w, h)

  love.graphics.setColor(settings.ui.accent_color)
  love.graphics.setFont(Fonts.get(56))
  love.graphics.printf("GROOVE BOUND", 0, h * 0.22, w, "center")

  love.graphics.setColor(settings.ui.text_color)
  love.graphics.setFont(Fonts.get(18))
  love.graphics.printf("Restore rhythm to the universe", 0, h * 0.22 + 72, w, "center")

  self.button_list:draw()
end

function TitleScreen:keypressed(key)
  return self.button_list:keypressed(key)
end

function TitleScreen:mousemoved(x, y)
  self.button_list:mousemoved(x, y)
end

function TitleScreen:mousepressed(x, y, button)
  return self.button_list:mousepressed(x, y, button)
end

return TitleScreen
