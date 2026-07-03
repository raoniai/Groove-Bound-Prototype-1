-- Enemy definitions. All rhythmless creatures, no real-world references.

return {
  monotone = {
    id     = "monotone",
    name   = "Monotone",
    hp     = 20,
    speed  = 60,
    size   = 12,
    damage = 10,
    xp     = 10,
    coins  = 1,
    brain  = "chase",
    color  = { 0.85, 0.25, 0.25, 1 },
  },

  tempo_leech = {
    id     = "tempo_leech",
    name   = "Tempo Leech",
    hp     = 45,
    speed  = 95,
    size   = 18,
    damage = 15,
    xp     = 20,
    coins  = 2,
    brain  = "chase",
    color  = { 0.95, 0.55, 0.2, 1 },
  },
}
