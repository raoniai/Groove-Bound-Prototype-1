-- Spawn timeline for the run. Ordered by `at` (seconds since run start).
-- Each entry starts streams of enemies: `count` spawned one per `cadence` sec.

return {
  { at = 1,  enemies = { { id = "monotone", count = 5, cadence = 1.5 } } },
  { at = 15, enemies = { { id = "monotone", count = 8, cadence = 1.2 } } },
  { at = 30, enemies = {
      { id = "monotone",    count = 10, cadence = 1.0 },
      { id = "tempo_leech", count = 2,  cadence = 4.0 },
  } },
  { at = 45, enemies = {
      { id = "monotone",    count = 12, cadence = 0.8 },
      { id = "tempo_leech", count = 4,  cadence = 3.0 },
  } },
}
