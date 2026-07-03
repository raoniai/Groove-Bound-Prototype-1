-- Input bindings. The input layer translates these into abstract actions
-- (move vector, aim vector, confirm/cancel/pause) — game code never reads
-- key names directly.

return {
  keyboard = {
    up      = { "w", "up" },
    down    = { "s", "down" },
    left    = { "a", "left" },
    right   = { "d", "right" },
    confirm = { "return", "space" },
    cancel  = { "escape" },
    pause   = { "escape", "p" },
  },

  gamepad = {
    move_x  = "leftx",
    move_y  = "lefty",
    aim_x   = "rightx",
    aim_y   = "righty",
    confirm = "a",
    cancel  = "b",
    pause   = "start",
  },
}
