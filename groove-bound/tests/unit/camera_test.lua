local H = require("tests.helpers")
local Camera = require("src.game.camera")

local T = {}

local function make_camera(opts)
  opts = opts or {}
  opts.get_dimensions = opts.get_dimensions or function() return 1280, 720 end
  opts.random = opts.random or function() return 0.5 end
  return Camera(opts)
end

T["snap clamps to arena bounds (no void beyond walls)"] = function()
  local cam = make_camera()
  cam:set_bounds(2000, 1600)

  cam:snap(0, 0) -- top-left corner
  H.eq(cam.x, 640, "view left edge must sit at arena 0")
  H.eq(cam.y, 360)

  cam:snap(2000, 1600) -- bottom-right corner
  H.eq(cam.x, 2000 - 640)
  H.eq(cam.y, 1600 - 360)
end

T["arena smaller than screen centers the view"] = function()
  local cam = make_camera()
  cam:set_bounds(800, 600)
  cam:snap(100, 500)
  H.eq(cam.x, 400)
  H.eq(cam.y, 300)
end

T["follow converges on the target"] = function()
  local cam = make_camera()
  cam:set_bounds(4000, 4000)
  cam:snap(1000, 1000)
  for _ = 1, 300 do
    cam:follow(1500, 1200, 1 / 60)
  end
  H.near(cam.x, 1500, 1)
  H.near(cam.y, 1200, 1)
end

T["screen_to_world and world_to_screen round-trip"] = function()
  local cam = make_camera()
  cam:set_bounds(4000, 4000)
  cam:snap(1234, 987)

  local wx, wy = cam:screen_to_world(640, 360) -- screen center = camera position
  H.near(wx, 1234)
  H.near(wy, 987)

  local sx, sy = cam:world_to_screen(wx, wy)
  H.near(sx, 640)
  H.near(sy, 360)
end

T["trauma decays to zero and clamps at one"] = function()
  local cam = make_camera()
  cam:add_trauma(0.7)
  cam:add_trauma(0.7)
  H.eq(cam.trauma, 1, "trauma must clamp at 1")

  for _ = 1, 120 do
    cam:update(1 / 60)
  end
  H.eq(cam.trauma, 0)
  H.eq(cam.shake_x, 0)
  H.eq(cam.shake_y, 0)
end

T["shake magnitude scales with trauma squared"] = function()
  -- random() = 1 would give max positive offset; use a fake returning 1.
  local cam = make_camera({ random = function() return 1 end })
  cam.trauma = 0.5
  cam:update(0) -- no decay, just compute offsets
  -- max_shake(12) * 0.5^2 = 3
  H.near(cam.shake_x, 3, 0.001)
end

T["shake can be disabled (accessibility option)"] = function()
  local cam = make_camera({ shake_enabled = false, random = function() return 1 end })
  cam.trauma = 1
  cam:update(0)
  H.eq(cam.shake_x, 0)
end

return T
