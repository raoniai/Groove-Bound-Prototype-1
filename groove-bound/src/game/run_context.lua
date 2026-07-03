-- RunContext: the container for everything with run lifetime.
--
-- One object owns the run's event bus, RNG streams, scheduler, world, and
-- clock. Ending a run calls destroy() once, which tears down every listener
-- and timer wholesale — the structural fix for the prototype's
-- accumulating-listeners bugs (one kill spawning N gems after N restarts).
--
--   local ctx = RunContext({ seed = 1234, app_bus = app.bus })
--   ctx.bus:on("ENEMY_KILLED", ...)     -- run-scoped: dies with the run
--   ctx.app_scope:on("WINDOW_X", ...)   -- app-bus listener: also dies with the run
--   ctx:update(dt)                       -- advances clock + timers unless paused
--   ctx:destroy()

local class = require("src.core.class")
local EventBus = require("src.core.event_bus")
local RNG = require("src.core.rng")
local Scheduler = require("src.core.scheduler")
local World = require("src.game.world")

local RunContext = class()

function RunContext:init(opts)
  opts = opts or {}
  self.seed = opts.seed or os.time()
  self.rng = RNG.new(self.seed)
  self.bus = EventBus()
  self.app_scope = opts.app_bus and opts.app_bus:scope() or nil
  self.scheduler = Scheduler()
  self.world = World()
  self.time = 0        -- run clock, seconds; frozen while paused
  self.paused = false
  self.destroyed = false
end

function RunContext:update(dt)
  if self.paused or self.destroyed then return end
  self.time = self.time + dt
  self.scheduler:update(dt)
end

function RunContext:destroy()
  if self.destroyed then return end
  self.destroyed = true
  if self.app_scope then
    self.app_scope:cancel()
  end
  self.scheduler:clear()
  self.world:clear()
  self.bus = EventBus() -- drop all run-bus listeners
end

return RunContext
