-- Bootstrap only: build the app container, validate content, push the first
-- screen, and forward LÖVE callbacks to the state machine. All game logic
-- lives in src/.

local EventBus = require("src.core.event_bus")
local Log = require("src.core.log")
local Save = require("src.core.save")
local StateMachine = require("src.core.state_machine")
local settings = require("src.config.settings")

local Overlay = require("src.debug.overlay")
local TitleScreen = require("src.ui.screens.title")

-- The app container: every screen receives this instead of reaching for
-- globals. App-scoped only — per-run objects live in RunContext (Phase 1).
local app = {
  bus = nil,
  states = nil,
  log = Log,
  save = nil,
}

function love.load()
  Log.configure({ channels = settings.debug.channels })
  Log.info("boot", "Groove Bound starting")

  -- Content is validated at boot; a bad table is a loud, immediate error.
  app.content = require("src.content.init")
  Log.info("boot", "Content validated")

  app.bus = EventBus()
  app.states = StateMachine()
  app.save = Save({
    filename = settings.save.filename,
    defaults = settings.save.defaults,
  })

  app.states:push(TitleScreen(app))
  Log.info("boot", "Boot complete")
end

function love.update(dt)
  app.states:update(dt)
end

function love.draw()
  app.states:draw()
  Overlay.draw()
end

function love.keypressed(key)
  app.states:keypressed(key)
end

function love.keyreleased(key)
  app.states:keyreleased(key)
end

function love.mousepressed(x, y, button)
  app.states:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
  app.states:mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
  app.states:mousemoved(x, y, dx, dy)
end

function love.gamepadpressed(joystick, button)
  app.states:gamepadpressed(joystick, button)
end

function love.resize(w, h)
  app.states:resize(w, h)
end
