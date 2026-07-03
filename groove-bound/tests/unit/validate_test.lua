local H = require("tests.helpers")
local Validate = require("src.content.validate")

local T = {}

-- Minimal valid bundle used as the mutation base for negative tests.
local function valid_content()
  return {
    weapons = {
      test_gun = {
        id = "test_gun", name = "Test Gun", description = "d",
        archetype = "projectile", max_level = 2,
        levels = {
          { damage = 10, cooldown = 0.5 },
          { damage = 12, cooldown = 0.5 },
        },
      },
    },
    enemies = {
      grunt = {
        id = "grunt", name = "Grunt",
        hp = 10, speed = 50, size = 10, damage = 5, xp = 5, brain = "chase",
      },
    },
    passives = {
      boost = {
        id = "boost", name = "Boost", description = "d",
        stat = "speed", max_level = 3, per_level = 0.1,
      },
    },
    characters = {
      hero = { id = "hero", name = "Hero", starting_weapon = "test_gun" },
    },
    waves = {
      { at = 1, enemies = { { id = "grunt", count = 3, cadence = 1.0 } } },
      { at = 10, enemies = { { id = "grunt", count = 5, cadence = 0.8 } } },
    },
  }
end

T["the real shipped content validates"] = function()
  local content = require("src.content.init") -- errors on invalid
  H.is_true(type(content) == "table")
end

T["a valid bundle passes"] = function()
  H.eq(#Validate.check(valid_content()), 0)
end

T["id must equal table key"] = function()
  local c = valid_content()
  c.enemies.grunt.id = "wrong"
  H.is_true(#Validate.check(c) > 0)
end

T["missing required field is reported"] = function()
  local c = valid_content()
  c.enemies.grunt.hp = nil
  local errors = Validate.check(c)
  H.is_true(#errors > 0)
  H.is_true(errors[1]:find("hp") ~= nil, "error should name the field")
end

T["wave referencing unknown enemy id fails (no silent fallback)"] = function()
  local c = valid_content()
  c.waves[1].enemies[1].id = "does_not_exist"
  local errors = Validate.check(c)
  H.is_true(#errors > 0)
  H.is_true(errors[1]:find("does_not_exist") ~= nil)
end

T["character referencing unknown weapon fails"] = function()
  local c = valid_content()
  c.characters.hero.starting_weapon = "ghost_gun"
  H.is_true(#Validate.check(c) > 0)
end

T["weapon levels count must match max_level"] = function()
  local c = valid_content()
  c.weapons.test_gun.max_level = 5 -- but only 2 level rows
  H.is_true(#Validate.check(c) > 0)
end

T["wave timeline must be ascending"] = function()
  local c = valid_content()
  c.waves[2].at = 0.5 -- before wave 1
  H.is_true(#Validate.check(c) > 0)
end

T["out-of-range value is reported"] = function()
  local c = valid_content()
  c.enemies.grunt.hp = 0 -- min is 1
  H.is_true(#Validate.check(c) > 0)
end

T["invalid enum value is reported"] = function()
  local c = valid_content()
  c.weapons.test_gun.archetype = "laser_disco"
  H.is_true(#Validate.check(c) > 0)
end

T["assert_valid raises with all problems listed"] = function()
  local c = valid_content()
  c.enemies.grunt.hp = nil
  c.waves[1].enemies[1].id = "nope"
  local err = H.errors(function() Validate.assert_valid(c) end)
  H.is_true(err:find("hp") ~= nil)
  H.is_true(err:find("nope") ~= nil)
end

return T
