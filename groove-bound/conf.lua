-- LÖVE configuration. Engine-level only; gameplay tunables live in src/config/settings.lua.
function love.conf(t)
  t.identity = "groove-bound"
  t.version = "11.5"
  t.console = false

  t.window.title = "Groove Bound"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 600
  t.window.vsync = 1

  -- Modules we do not use yet; disabled to keep startup lean.
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = false
end
