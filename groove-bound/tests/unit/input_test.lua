local H = require("tests.helpers")
local Input = require("src.game.input")

local T = {}

-- Fake device backend: set .keys, .mouse, .axes then poll.
local function fake_backend()
  local b = { keys = {}, mouse = { 0, 0 }, axes = {} }
  b.is_key_down = function(k) return b.keys[k] == true end
  b.mouse_position = function() return b.mouse[1], b.mouse[2] end
  b.axis = function(name) return b.axes[name] or 0 end
  return b
end

local function make_input(backend)
  return Input({ backend = backend }), backend
end

T["keyboard cardinal movement"] = function()
  local input, b = make_input(fake_backend())
  b.keys.d = true
  local dx, dy = input:move_vector()
  H.eq(dx, 1)
  H.eq(dy, 0)
end

T["keyboard diagonal movement is normalized"] = function()
  local input, b = make_input(fake_backend())
  b.keys.d = true
  b.keys.s = true
  local dx, dy = input:move_vector()
  H.near(math.sqrt(dx * dx + dy * dy), 1, 0.0001, "diagonal must not be faster")
end

T["opposite keys cancel"] = function()
  local input, b = make_input(fake_backend())
  b.keys.a = true
  b.keys.d = true
  local dx, dy = input:move_vector()
  H.eq(dx, 0)
  H.eq(dy, 0)
end

T["stick inside deadzone is ignored"] = function()
  local input, b = make_input(fake_backend())
  b.axes.leftx = 0.1 -- below 0.25 deadzone
  local dx, dy = input:move_vector()
  H.eq(dx, 0)
  H.eq(dy, 0)
end

T["stick past deadzone overrides keyboard and preserves direction"] = function()
  local input, b = make_input(fake_backend())
  b.keys.a = true          -- keyboard says left
  b.axes.leftx = 0.9       -- stick says right
  local dx, dy = input:move_vector()
  H.is_true(dx > 0, "stick must win")
  H.near(dy, 0, 0.0001)
end

T["full stick deflection reaches full speed"] = function()
  local input, b = make_input(fake_backend())
  b.axes.lefty = -1
  local dx, dy = input:move_vector()
  H.near(dx, 0, 0.0001)
  H.near(dy, -1, 0.0001)
end

T["mouse aim points from player toward cursor"] = function()
  local input, b = make_input(fake_backend())
  b.mouse = { 200, 100 }
  -- No camera: mouse coords are world coords.
  local ax, ay = input:aim_vector(100, 100, nil)
  H.near(ax, 1, 0.0001)
  H.near(ay, 0, 0.0001)
end

T["mouse aim converts through the camera"] = function()
  local input, b = make_input(fake_backend())
  b.mouse = { 640, 360 } -- screen center
  local camera = {
    screen_to_world = function(_, sx, sy) return sx + 1000, sy + 500 end,
  }
  -- Player left of the converted point -> aim right/down blend.
  local ax, ay = input:aim_vector(1540, 860, camera)
  H.near(ax, 1, 0.0001) -- converted point (1640, 860): straight right
  H.near(ay, 0, 0.0001)
end

T["right stick beyond deadzone takes over aiming"] = function()
  local input, b = make_input(fake_backend())
  b.axes.rightx = 0
  b.axes.righty = -1
  local ax, ay = input:aim_vector(0, 0, nil)
  H.near(ax, 0, 0.0001)
  H.near(ay, -1, 0.0001)
end

T["gamepad aim persists when stick returns to center"] = function()
  local input, b = make_input(fake_backend())
  b.axes.righty = -1
  input:aim_vector(0, 0, nil)

  b.axes.righty = 0 -- stick released; mouse sits at (0,0) = player position
  local ax, ay = input:aim_vector(0, 0, nil)
  H.near(ax, 0, 0.0001)
  H.near(ay, -1, 0.0001, "last stick direction must persist")
end

T["action key mapping"] = function()
  H.is_true(Input.is_action("escape", "pause"))
  H.is_true(Input.is_action("p", "pause"))
  H.is_false(Input.is_action("x", "pause"))
  H.is_true(Input.is_gamepad_action("start", "pause"))
  H.is_false(Input.is_gamepad_action("a", "pause"))
end

return T
