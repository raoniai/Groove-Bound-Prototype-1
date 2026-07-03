-- Focusable button widget: mouse hover/click, keyboard/gamepad focus + confirm.
-- Screens own a list of buttons and route input through ButtonList.

local class = require("src.core.class")
local Fonts = require("src.ui.fonts")
local settings = require("src.config.settings")

local Button = class()

function Button:init(opts)
  self.label = assert(opts.label, "button needs a label")
  self.x = opts.x or 0
  self.y = opts.y or 0
  self.w = opts.w or 200
  self.h = opts.h or 48
  self.on_press = opts.on_press or function() end
  self.focused = false
  self.hovered = false
  self.font_size = opts.font_size or 20
end

function Button:contains(px, py)
  return px >= self.x and px <= self.x + self.w
     and py >= self.y and py <= self.y + self.h
end

function Button:draw()
  local colors = settings.ui.button
  local fill = self.hovered and colors.hover or colors.fill

  love.graphics.setColor(fill)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 6, 6)

  love.graphics.setColor(self.focused and colors.focus or colors.border)
  love.graphics.setLineWidth(self.focused and 3 or 1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 6, 6)

  love.graphics.setColor(settings.ui.text_color)
  local font = Fonts.get(self.font_size)
  love.graphics.setFont(font)
  local text_y = self.y + (self.h - font:getHeight()) / 2
  love.graphics.printf(self.label, self.x, text_y, self.w, "center")
end

-- Manages focus + input routing for a screen's buttons.
local ButtonList = class()

function ButtonList:init(buttons)
  self.buttons = buttons or {}
  self.focus_index = 1
  self:_apply_focus()
end

function ButtonList:_apply_focus()
  for i, b in ipairs(self.buttons) do
    b.focused = (i == self.focus_index)
  end
end

function ButtonList:move_focus(delta)
  local n = #self.buttons
  if n == 0 then return end
  self.focus_index = ((self.focus_index - 1 + delta) % n) + 1
  self:_apply_focus()
end

function ButtonList:confirm()
  local b = self.buttons[self.focus_index]
  if b then b.on_press() end
end

function ButtonList:keypressed(key)
  if key == "up" or key == "w" then
    self:move_focus(-1)
    return true
  elseif key == "down" or key == "s" then
    self:move_focus(1)
    return true
  elseif key == "return" or key == "space" then
    self:confirm()
    return true
  end
  return false
end

function ButtonList:mousemoved(x, y)
  for i, b in ipairs(self.buttons) do
    b.hovered = b:contains(x, y)
    if b.hovered and self.focus_index ~= i then
      self.focus_index = i
      self:_apply_focus()
    end
  end
end

function ButtonList:mousepressed(x, y, mouse_button)
  if mouse_button ~= 1 then return false end
  for _, b in ipairs(self.buttons) do
    if b:contains(x, y) then
      b.on_press()
      return true
    end
  end
  return false
end

function ButtonList:draw()
  for _, b in ipairs(self.buttons) do
    b:draw()
  end
end

return { Button = Button, ButtonList = ButtonList }
