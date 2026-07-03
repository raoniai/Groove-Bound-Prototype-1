-- Loads and validates the full content bundle. Required once at boot;
-- any schema violation is a loud boot error, never a silent fallback.

local Validate = require("src.content.validate")

local content = {
  weapons    = require("src.content.weapons"),
  enemies    = require("src.content.enemies"),
  passives   = require("src.content.passives"),
  characters = require("src.content.characters"),
  waves      = require("src.content.waves"),
}

return Validate.assert_valid(content)
