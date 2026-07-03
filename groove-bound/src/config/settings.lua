-- Engine/feel tunables. Gameplay numbers (weapon damage, enemy hp, waves)
-- live in src/content/ — never here. Nothing in src/game may hardcode a
-- numeric tunable; it reads from here or from content.

return {
  ui = {
    background_color = { 0.06, 0.05, 0.10, 1 },
    accent_color     = { 0.95, 0.75, 0.20, 1 }, -- gold
    text_color       = { 0.92, 0.92, 0.95, 1 },
    button = {
      fill    = { 0.16, 0.14, 0.24, 1 },
      hover   = { 0.28, 0.24, 0.42, 1 },
      border  = { 0.55, 0.50, 0.75, 1 },
      focus   = { 0.95, 0.75, 0.20, 1 },
    },
  },

  debug = {
    enabled = true,
    overlay = {
      max_rows  = 12,
      ttl_secs  = 10,
      font_size = 12,
    },
    channels = {
      -- Per-channel log toggles; unlisted channels default to enabled.
      boot  = true,
      state = true,
    },
  },

  save = {
    filename = "save.json",
    defaults = {
      coins = 0,
      options = {
        music_volume = 0.8,
        sfx_volume   = 0.8,
        screen_shake = true,
      },
    },
  },
}
