local H = require("tests.helpers")
local class = require("src.core.class")

local T = {}

T["constructor runs init with arguments"] = function()
  local Point = class()
  function Point:init(x, y)
    self.x, self.y = x, y
  end
  local p = Point(3, 4)
  H.eq(p.x, 3)
  H.eq(p.y, 4)
end

T["instances are independent"] = function()
  local Counter = class()
  function Counter:init() self.n = 0 end
  function Counter:bump() self.n = self.n + 1 end
  local a, b = Counter(), Counter()
  a:bump()
  H.eq(a.n, 1)
  H.eq(b.n, 0)
end

T["single inheritance resolves through parent"] = function()
  local Animal = class()
  function Animal:init(name) self.name = name end
  function Animal:speak() return "..." end

  local Dog = class(Animal)
  function Dog:speak() return "woof" end

  local d = Dog("rex")
  H.eq(d.name, "rex", "parent init should run when child has none")
  H.eq(d:speak(), "woof")
end

return T
