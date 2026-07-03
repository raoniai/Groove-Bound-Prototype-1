local H = require("tests.helpers")
local Save = require("src.core.save")

local T = {}

-- In-memory filesystem backend for tests.
local function fake_fs(initial)
  local files = initial or {}
  return {
    read = function(name) return files[name] end,
    write = function(name, contents)
      files[name] = contents
      return true
    end,
    files = files,
  }
end

local defaults = {
  coins = 0,
  options = { music_volume = 0.8 },
}

T["load returns defaults when no file exists"] = function()
  local store = Save({ filename = "s.json", backend = fake_fs(), defaults = defaults })
  local data = store:load()
  H.eq(data.coins, 0)
  H.near(data.options.music_volume, 0.8)
end

T["defaults are copied, not shared (mutation must not pollute defaults)"] = function()
  local store = Save({ filename = "s.json", backend = fake_fs(), defaults = defaults })
  local data = store:load()
  data.coins = 999
  data.options.music_volume = 0
  local fresh = store:load()
  H.eq(fresh.coins, 0)
  H.near(fresh.options.music_volume, 0.8)
end

T["save then load round-trips"] = function()
  local fs = fake_fs()
  local store = Save({ filename = "s.json", backend = fs, defaults = defaults })
  store:save({ coins = 42, options = { music_volume = 0.3 } })
  local data = store:load()
  H.eq(data.coins, 42)
  H.near(data.options.music_volume, 0.3)
end

T["corrupt file falls back to defaults instead of crashing"] = function()
  local fs = fake_fs({ ["s.json"] = "not json {{{" })
  local store = Save({ filename = "s.json", backend = fs, defaults = defaults })
  local data = store:load()
  H.eq(data.coins, 0)
end

T["missing keys are backfilled from defaults (new options after update)"] = function()
  local fs = fake_fs()
  local store = Save({ filename = "s.json", backend = fs, defaults = defaults })
  store:save({ coins = 7 }) -- old save without options
  local data = store:load()
  H.eq(data.coins, 7)
  H.near(data.options.music_volume, 0.8, nil, "new default must be backfilled")
end

T["migration path upgrades old save versions"] = function()
  local fs = fake_fs()
  local store = Save({ filename = "s.json", backend = fs, defaults = defaults })

  -- Write a fake version-0 save and register a 0 -> 1 migration.
  fs.write("s.json", '{"version":0,"data":{"gold":5}}')
  local original_version = Save.SCHEMA_VERSION
  local original_migrations = Save.migrations
  Save.SCHEMA_VERSION = 1
  Save.migrations = {
    [0] = function(data)
      return { coins = data.gold or 0 } -- rename gold -> coins
    end,
  }

  local ok, err = pcall(function()
    local data = store:load()
    H.eq(data.coins, 5, "migration should rename gold to coins")
  end)

  Save.SCHEMA_VERSION = original_version
  Save.migrations = original_migrations
  if not ok then error(err) end
end

return T
