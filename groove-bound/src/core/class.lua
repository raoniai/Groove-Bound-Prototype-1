-- Minimal class helper: single inheritance, constructor via :init().
-- Usage:
--   local Foo = class()
--   function Foo:init(x) self.x = x end
--   local f = Foo(42)

local function class(parent)
  local c = {}
  c.__index = c

  if parent then
    setmetatable(c, { __index = parent, __call = nil })
  end

  local mt = getmetatable(c) or {}
  mt.__call = function(cls, ...)
    local instance = setmetatable({}, cls)
    if instance.init then
      instance:init(...)
    end
    return instance
  end
  setmetatable(c, mt)

  c.super = parent
  return c
end

return class
