-- Stack-based state machine for screens.
--
-- States are INSTANCES (constructed per visit), never shared module tables, so
-- no state survives across visits by accident. Lifecycle hooks, all optional:
--   enter()   - pushed onto the stack
--   exit()    - popped off the stack
--   pause()   - another state was pushed on top
--   resume(r) - the state above was popped; r = value passed to pop
--   update(dt), draw(), keypressed(k), keyreleased(k),
--   mousepressed(x,y,b), mousereleased(x,y,b), mousemoved(x,y,dx,dy),
--   gamepadpressed(js,b), resize(w,h)
--
-- draw() renders every state from the lowest opaque one up, so modals
-- (state.opaque == false) show the gameplay underneath without hacks.

local class = require("src.core.class")

local StateMachine = class()

function StateMachine:init()
  self.stack = {}
end

function StateMachine:push(state)
  local top = self.stack[#self.stack]
  if top and top.pause then
    top:pause()
  end
  self.stack[#self.stack + 1] = state
  if state.enter then
    state:enter()
  end
end

function StateMachine:pop(result)
  local state = self.stack[#self.stack]
  if not state then return nil end
  self.stack[#self.stack] = nil
  if state.exit then
    state:exit()
  end
  local top = self.stack[#self.stack]
  if top and top.resume then
    top:resume(result)
  end
  return state
end

-- Replace the whole stack with one state (e.g. back to title).
function StateMachine:switch(state)
  while #self.stack > 0 do
    local s = self.stack[#self.stack]
    self.stack[#self.stack] = nil
    if s.exit then s:exit() end
  end
  self:push(state)
end

function StateMachine:top()
  return self.stack[#self.stack]
end

function StateMachine:depth()
  return #self.stack
end

function StateMachine:update(dt)
  local top = self:top()
  if top and top.update then
    top:update(dt)
  end
end

function StateMachine:draw()
  -- Find the lowest state that must be drawn: walk down until one is opaque.
  local first = #self.stack
  while first > 1 and self.stack[first].opaque == false do
    first = first - 1
  end
  for i = first, #self.stack do
    local s = self.stack[i]
    if s.draw then s:draw() end
  end
end

-- Generic input forwarding: only the top state receives input.
local forwarded = {
  "keypressed", "keyreleased",
  "mousepressed", "mousereleased", "mousemoved",
  "gamepadpressed", "gamepadreleased", "resize",
}

for _, name in ipairs(forwarded) do
  StateMachine[name] = function(self, ...)
    local top = self:top()
    if top and top[name] then
      return top[name](top, ...)
    end
    return false
  end
end

return StateMachine
