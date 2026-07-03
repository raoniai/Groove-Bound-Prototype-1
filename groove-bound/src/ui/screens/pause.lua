-- Pause modal. Pushed over the run screen; the state machine stops updating
-- the run automatically (only the top state updates), so there is no paused
-- boolean to keep in sync. opaque = false lets the frozen run render below.

local class = require("src.core.class")
local Fonts = require("src.ui.fonts")
local Input = require("src.game.input")
local settings = require("src.config.settings")
local widgets = require("src.ui.widgets.button")

local PauseScreen = class()

PauseScreen.opaque = false

function PauseScreen:init(app)
  self.app = app
end

function PauseScreen:enter()
  self.app.log.info("state", "Paused")
  self:_layout()
end

function PauseScreen:_layout()
  local w, h = love.graphics.getDimensions()
  local bw, bh, gap = 260, 52, 18
  local x = (w - bw) / 2
  local y = h * 0.45

  self.button_list = widgets.ButtonList({
    widgets.Button({
      label = "Resume", x = x, y = y, w = bw, h = bh,
      on_press = function() self.app.states:pop() end,
    }),
    widgets.Button({
      label = "Quit to Title", x = x, y = y + bh + gap, w = bw, h = bh,
      on_press = function()
        local TitleScreen = require("src.ui.screens.title")
        self.app.states:switch(TitleScreen(self.app))
      end,
    }),
  })
end

function PauseScreen:resize()
  self:_layout()
end

function PauseScreen:draw()
  local w, h = love.graphics.getDimensions()

  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, w, h)

  love.graphics.setColor(settings.ui.accent_color)
  love.graphics.setFont(Fonts.get(40))
  love.graphics.printf("PAUSED", 0, h * 0.3, w, "center")

  self.button_list:draw()
end

function PauseScreen:keypressed(key)
  if Input.is_action(key, "pause") or Input.is_action(key, "cancel") then
    self.app.states:pop()
    return true
  end
  return self.button_list:keypressed(key)
end

function PauseScreen:gamepadpressed(_, button)
  if Input.is_gamepad_action(button, "pause") or Input.is_gamepad_action(button, "cancel") then
    self.app.states:pop()
    return true
  end
  if Input.is_gamepad_action(button, "confirm") then
    self.button_list:confirm()
    return true
  end
  return false
end

function PauseScreen:mousemoved(x, y)
  self.button_list:mousemoved(x, y)
end

function PauseScreen:mousepressed(x, y, button)
  return self.button_list:mousepressed(x, y, button)
end

return PauseScreen
