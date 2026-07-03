local H = require("tests.helpers")
local EventBus = require("src.core.event_bus")
local RunContext = require("src.game.run_context")

local T = {}

T["clock advances only while unpaused"] = function()
  local ctx = RunContext({ seed = 1 })
  ctx:update(0.5)
  H.near(ctx.time, 0.5)

  ctx.paused = true
  ctx:update(0.5)
  H.near(ctx.time, 0.5, nil, "paused clock must freeze")

  ctx.paused = false
  ctx:update(0.25)
  H.near(ctx.time, 0.75)
end

T["scheduler timers freeze with the clock"] = function()
  local ctx = RunContext({ seed = 1 })
  local fired = false
  ctx.scheduler:after(1.0, function() fired = true end)

  ctx.paused = true
  ctx:update(2.0)
  H.is_false(fired, "timers must not fire while paused")

  ctx.paused = false
  ctx:update(1.0)
  H.is_true(fired)
end

T["destroy cancels app-bus listeners (restart leak regression)"] = function()
  local app_bus = EventBus()
  local calls = 0

  -- Three consecutive runs, each subscribing to an app-level event.
  for _ = 1, 3 do
    local ctx = RunContext({ seed = 1, app_bus = app_bus })
    ctx.app_scope:on("SOMETHING", function() calls = calls + 1 end)
    ctx:destroy()
  end

  app_bus:emit("SOMETHING")
  H.eq(calls, 0, "no listeners may survive their run")
  H.eq(app_bus:count(), 0)
end

T["destroy drops run-bus listeners and world entities"] = function()
  local ctx = RunContext({ seed = 1 })
  local calls = 0
  ctx.bus:on("ENEMY_KILLED", function() calls = calls + 1 end)
  ctx.world:add("enemy", { x = 1, y = 1, radius = 5 })

  ctx:destroy()
  ctx.bus:emit("ENEMY_KILLED")
  H.eq(calls, 0)
  H.eq(ctx.world:count(), 0)
end

T["destroy is idempotent and stops the clock"] = function()
  local ctx = RunContext({ seed = 1 })
  ctx:destroy()
  ctx:destroy()
  ctx:update(1.0)
  H.eq(ctx.time, 0)
end

T["same seed gives identical rng streams (reproducible runs)"] = function()
  local a = RunContext({ seed = 555 })
  local b = RunContext({ seed = 555 })
  for _ = 1, 20 do
    H.eq(a.rng.spawn:random(), b.rng.spawn:random())
  end
end

return T
