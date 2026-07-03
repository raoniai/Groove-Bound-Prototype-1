-- On-screen debug overlay: renders the tail of the log ring buffer in the
-- top-left corner, entries fading out after a TTL. Drawn last, above all
-- screens. Pure consumer of core/log — it owns no logging logic itself.

local Fonts = require("src.ui.fonts")
local Log = require("src.core.log")
local settings = require("src.config.settings")

local Overlay = {}

function Overlay.draw()
  local cfg = settings.debug.overlay
  if not settings.debug.enabled then return end

  local entries = Log.recent(cfg.max_rows)
  if #entries == 0 then return end

  local now = os.time()
  local font = Fonts.get(cfg.font_size)
  local line_h = font:getHeight() + 2

  love.graphics.push("all")
  love.graphics.setFont(font)

  local y = 8
  for _, entry in ipairs(entries) do
    local age = now - entry.time
    if age <= cfg.ttl_secs then
      local alpha = 1 - (age / cfg.ttl_secs)
      love.graphics.setColor(0, 0, 0, 0.5 * alpha)
      local text = string.format("[%s] %s", entry.channel, entry.message)
      local width = font:getWidth(text) + 8
      love.graphics.rectangle("fill", 4, y - 1, width, line_h)
      love.graphics.setColor(1, 0.6, 0.2, alpha)
      love.graphics.print(text, 8, y)
      y = y + line_h
    end
  end

  love.graphics.pop()
end

return Overlay
