-- Versioned JSON save/load with an injectable filesystem backend.
--
-- In-game the backend is love.filesystem; tests inject an in-memory table.
-- Saves carry a schema version; loading an older version runs it through
-- registered migrations so save formats can evolve without wiping players.
--
--   local store = Save.new({ filename = "save.json" })   -- LÖVE backend
--   local store = Save.new({ backend = fake, filename = "t" }) -- test backend
--   store:load()  -> data table (defaults when no file / corrupt file)
--   store:save(data)

local class = require("src.core.class")
local json = require("lib.json")

local Save = class()

Save.SCHEMA_VERSION = 1

-- Migrations: index N upgrades a version-N save to version N+1.
Save.migrations = {}

local function love_backend()
  return {
    read = function(name)
      local ok, contents = pcall(love.filesystem.read, name)
      if ok then return contents end
      return nil
    end,
    write = function(name, contents)
      return love.filesystem.write(name, contents)
    end,
  }
end

function Save:init(opts)
  opts = opts or {}
  self.filename = assert(opts.filename, "Save requires a filename")
  self.backend = opts.backend or love_backend()
  self.defaults = opts.defaults or {}
end

local function deep_copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do
    out[k] = deep_copy(v)
  end
  return out
end

function Save:load()
  local raw = self.backend.read(self.filename)
  if not raw then
    return deep_copy(self.defaults)
  end

  local ok, decoded = pcall(json.decode, raw)
  if not ok or type(decoded) ~= "table" or type(decoded.version) ~= "number" then
    -- Corrupt or unversioned save: fall back to defaults rather than crash.
    return deep_copy(self.defaults)
  end

  local data = decoded.data or {}
  local version = decoded.version
  while version < Save.SCHEMA_VERSION do
    local migrate = Save.migrations[version]
    if not migrate then
      -- No path forward; safest is defaults.
      return deep_copy(self.defaults)
    end
    data = migrate(data)
    version = version + 1
  end

  -- Fill any missing keys from defaults (new settings added since the save).
  for k, v in pairs(self.defaults) do
    if data[k] == nil then
      data[k] = deep_copy(v)
    end
  end

  return data
end

function Save:save(data)
  local envelope = {
    version = Save.SCHEMA_VERSION,
    data = data,
  }
  return self.backend.write(self.filename, json.encode(envelope))
end

return Save
