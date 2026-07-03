std = "luajit"
codes = true
max_line_length = 120

-- LÖVE's global namespace is the only sanctioned global.
read_globals = { "love" }
globals = { "love" } -- main.lua defines love.load etc.

-- Test files may use the shared arg convention.
files["tests/"] = {
  read_globals = { "arg" },
}

-- No unused-argument noise for self in methods.
self = false
