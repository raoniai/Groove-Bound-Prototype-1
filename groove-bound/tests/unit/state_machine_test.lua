local H = require("tests.helpers")
local StateMachine = require("src.core.state_machine")
local class = require("src.core.class")

local T = {}

local function recorder_state(log, name)
  local S = class()
  function S:init()
    self.name = name
  end
  function S:enter() log[#log + 1] = name .. ":enter" end
  function S:exit() log[#log + 1] = name .. ":exit" end
  function S:pause() log[#log + 1] = name .. ":pause" end
  function S:resume(r) log[#log + 1] = name .. ":resume(" .. tostring(r) .. ")" end
  function S:update() log[#log + 1] = name .. ":update" end
  return S()
end

T["push calls enter and pauses the state below"] = function()
  local log = {}
  local sm = StateMachine()
  sm:push(recorder_state(log, "a"))
  sm:push(recorder_state(log, "b"))
  H.eq(table.concat(log, ","), "a:enter,a:pause,b:enter")
end

T["pop calls exit and resumes below with the result value"] = function()
  local log = {}
  local sm = StateMachine()
  sm:push(recorder_state(log, "a"))
  sm:push(recorder_state(log, "b"))
  sm:pop("picked")
  H.eq(log[#log - 1], "b:exit")
  H.eq(log[#log], "a:resume(picked)")
  H.eq(sm:depth(), 1)
end

T["switch clears the whole stack (quit-to-title leak regression)"] = function()
  local log = {}
  local sm = StateMachine()
  sm:push(recorder_state(log, "boot"))
  sm:push(recorder_state(log, "run"))
  sm:push(recorder_state(log, "pause"))
  sm:switch(recorder_state(log, "title"))
  H.eq(sm:depth(), 1, "stack must not grow across menu round-trips")
  H.eq(sm:top().name, "title")
end

T["only the top state updates"] = function()
  local log = {}
  local sm = StateMachine()
  sm:push(recorder_state(log, "a"))
  sm:push(recorder_state(log, "b"))
  sm:update(0.016)
  H.eq(log[#log], "b:update")
end

T["input goes only to the top state"] = function()
  local sm = StateMachine()
  local received = {}
  local S = class()
  function S:init(name) self.name = name end
  function S:keypressed(key) received[#received + 1] = self.name .. ":" .. key end
  sm:push(S("bottom"))
  sm:push(S("top"))
  sm:keypressed("escape")
  H.eq(#received, 1)
  H.eq(received[1], "top:escape")
end

T["pop on empty stack returns nil"] = function()
  local sm = StateMachine()
  H.is_nil(sm:pop())
end

T["states are instances: two visits share no state"] = function()
  local Screen = class()
  function Screen:init() self.counter = 0 end
  function Screen:update() self.counter = self.counter + 1 end

  local sm = StateMachine()
  sm:push(Screen())
  sm:update(0.016)
  sm:update(0.016)
  H.eq(sm:top().counter, 2)

  sm:switch(Screen())
  H.eq(sm:top().counter, 0, "fresh instance must start clean")
end

return T
