-- Run screen: builds a RunContext on enter and destroys it on exit.
-- All per-run objects live inside the context; nothing survives to the
-- next run. Pause is a pushed modal, not a boolean.

local class = require("src.core.class")
local Arena = require("src.game.arena")
local Camera = require("src.game.camera")
local HUD = require("src.ui.hud")
local Hitboxes = require("src.debug.hitboxes")
local Input = require("src.game.input")
local Player = require("src.game.entities.player")
local RunContext = require("src.game.run_context")

local RunScreen = class()

function RunScreen:init(app, opts)
  self.app = app
  self.opts = opts or {}
end

function RunScreen:enter()
  self.ctx = RunContext({
    seed = self.opts.seed,
    app_bus = self.app.bus,
  })
  self.app.log.info("state", "Run started (seed " .. self.ctx.seed .. ")")

  self.arena = Arena()
  self.input = Input()

  self.camera = Camera({
    random = function() return self.ctx.rng.vfx:random() end,
  })
  self.camera:set_bounds(self.arena.width, self.arena.height)

  local cx, cy = self.arena:center()
  self.player = self.ctx.world:add("player", Player({ x = cx, y = cy }))
  self.camera:snap(self.player.x, self.player.y)

  self.hud = HUD(self.ctx, self.player)
end

function RunScreen:exit()
  self.ctx:destroy()
  self.app.log.info("state", "Run ended")
end

function RunScreen:update(dt)
  self.ctx:update(dt)

  self.player:update(dt, self.input, self.camera, self.arena)
  self.ctx.world:moved(self.player)

  self.camera:follow(self.player.x, self.player.y, dt)
  self.camera:update(dt)
end

function RunScreen:draw()
  self.camera:apply()
  self.arena:draw()
  self.player:draw()
  Hitboxes.draw(self.ctx.world)
  self.camera:detach()

  self.hud:draw()
end

function RunScreen:keypressed(key)
  if Input.is_action(key, "pause") then
    local PauseScreen = require("src.ui.screens.pause")
    self.app.states:push(PauseScreen(self.app))
    return true
  end
  if key == "f3" then
    Hitboxes.toggle()
    return true
  end
  return false
end

function RunScreen:gamepadpressed(_, button)
  if Input.is_gamepad_action(button, "pause") then
    local PauseScreen = require("src.ui.screens.pause")
    self.app.states:push(PauseScreen(self.app))
    return true
  end
  return false
end

return RunScreen
