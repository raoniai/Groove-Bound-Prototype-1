-- Channelled logger with a ring buffer for the on-screen overlay and optional
-- sinks (console, file). Per-channel enablement lives here, at the sink — call
-- sites never check flags themselves (the old code checked flags inline and
-- forgot half the time).
--
--   local Log = require("src.core.log")
--   Log.configure({ channels = { gameplay = true, spawn = false } })
--   Log.info("gameplay", "Boss spawned")
--   Log.recent(20) -- newest-last array of entries for the overlay

local Log = {}

local RING_SIZE = 128

local state = {
  channels = {},        -- channel -> bool (unknown channels default to enabled)
  default_enabled = true,
  console = true,
  ring = {},            -- circular buffer of entries
  ring_head = 0,        -- index of most recent entry
  ring_count = 0,
  clock = os.time,      -- injectable for tests
  sinks = {},           -- extra sink functions fn(entry)
}

function Log.configure(opts)
  opts = opts or {}
  if opts.channels then state.channels = opts.channels end
  if opts.default_enabled ~= nil then state.default_enabled = opts.default_enabled end
  if opts.console ~= nil then state.console = opts.console end
  if opts.clock then state.clock = opts.clock end
end

function Log.add_sink(fn)
  state.sinks[#state.sinks + 1] = fn
end

function Log.enabled(channel)
  local flag = state.channels[channel]
  if flag == nil then
    return state.default_enabled
  end
  return flag
end

local function write(level, channel, message)
  if not Log.enabled(channel) then return end

  local entry = {
    level = level,
    channel = channel,
    message = tostring(message),
    time = state.clock(),
  }

  state.ring_head = (state.ring_head % RING_SIZE) + 1
  state.ring[state.ring_head] = entry
  if state.ring_count < RING_SIZE then
    state.ring_count = state.ring_count + 1
  end

  if state.console then
    print(string.format("[%s][%s] %s", level, channel, entry.message))
  end

  for i = 1, #state.sinks do
    state.sinks[i](entry)
  end
end

function Log.info(channel, message) write("INFO", channel, message) end
function Log.warn(channel, message) write("WARN", channel, message) end
function Log.error(channel, message) write("ERROR", channel, message) end

-- Return up to n most recent entries, oldest first.
function Log.recent(n)
  n = math.min(n or state.ring_count, state.ring_count)
  local out = {}
  for i = n - 1, 0, -1 do
    local idx = state.ring_head - i
    if idx < 1 then idx = idx + RING_SIZE end
    out[#out + 1] = state.ring[idx]
  end
  return out
end

function Log.clear()
  state.ring = {}
  state.ring_head = 0
  state.ring_count = 0
end

return Log
