-- Weapon definitions. Logic never reads `name` — only `id`.
-- cooldown is always SECONDS between activations ("rate" terminology banned).
-- Stats are explicit per-level rows so balance is auditable at a glance.

return {
  kazoo_pistol = {
    id          = "kazoo_pistol",
    name        = "Kazoo Pistol",
    description = "Joe's trusty starter. Fires a single buzzing note.",
    archetype   = "projectile",
    max_level   = 3, -- grows to 10 in Phase 3; kept short while stub
    levels = {
      { damage = 10, cooldown = 0.80, count = 1, speed = 420, size = 6, lifetime = 1.5, spread = 0 },
      { damage = 12, cooldown = 0.72, count = 1, speed = 420, size = 6, lifetime = 1.5, spread = 0 },
      { damage = 14, cooldown = 0.65, count = 2, speed = 420, size = 6, lifetime = 1.5, spread = 8 },
    },
  },
}
