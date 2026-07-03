-- Cached font registry. Fonts are created once per size and reused;
-- creating fonts inside draw() is banned (it was a per-frame allocation
-- bug in the prototype).

local Fonts = {}

local cache = {}

function Fonts.get(size)
  local font = cache[size]
  if not font then
    font = love.graphics.newFont(size)
    cache[size] = font
  end
  return font
end

function Fonts.clear()
  cache = {}
end

return Fonts
