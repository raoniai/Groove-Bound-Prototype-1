# Groove Bound — Complete Ground-Up Remake Plan

**Version:** 1.0
**Date:** 2026-07-03
**Status:** Planning document — no code changes included
**Scope:** Full audit of Prototype 1 and Prototype 2, followed by an exhaustive action plan to rebuild the game from scratch.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [What the Game Is](#2-what-the-game-is)
3. [Audit of the Current Codebase](#3-audit-of-the-current-codebase)
   - 3.1 Repository-level red flags
   - 3.2 Prototype 1 assessment
   - 3.3 Prototype 2 assessment
   - 3.4 Confirmed bugs (catalogued)
   - 3.5 Architectural problems and bad practices
   - 3.6 Design/legal red flags
   - 3.7 What is worth keeping
4. [Remake Vision & Design Pillars](#4-remake-vision--design-pillars)
5. [Technology Decisions](#5-technology-decisions)
6. [Target Architecture](#6-target-architecture)
7. [Systems Design Specifications](#7-systems-design-specifications)
8. [Data-Driven Content Design](#8-data-driven-content-design)
9. [The Musical Identity (Beat-Sync Layer)](#9-the-musical-identity-beat-sync-layer)
10. [UI/UX Plan](#10-uiux-plan)
11. [Testing, Debugging & Tooling Strategy](#11-testing-debugging--tooling-strategy)
12. [Repository & Workflow Standards](#12-repository--workflow-standards)
13. [Phased Implementation Roadmap](#13-phased-implementation-roadmap)
14. [Risk Register](#14-risk-register)
15. [Definition of Done per Phase](#15-definition-of-done-per-phase)

---

## 1. Executive Summary

Groove Bound is a Vampire Survivors–style survival roguelike with a musical theme, built in Lua on the LÖVE (Love2D) framework. The repository contains **two abandoned-in-progress prototypes**:

- **Prototype 1** (~6,700 LOC + a duplicated `src_legacy` tree): library-based (HUMP, windfield, anim8), more feature-complete on paper (gamepad, pooled projectiles, passives, level-up shop) but abandoned mid-refactor with known broken systems, per its own commit messages.
- **Prototype 2** (~5,000 LOC): dependency-free rewrite with a cleaner core (state stack, event bus, settings) but riddled with wiring bugs, dead data files, duplicated logic paths, and it stops at "Phase 3" — no boss, no win condition, no options persistence, no sound.

The audit below catalogues **19 concrete bugs** and **~25 structural/practice problems**. The recurring root causes are:

1. **Stringly-typed identity** — weapons/upgrades matched by display-name substring search rather than stable IDs.
2. **Duplicate ownership of behavior** — the same game event (XP pickup, level-up, bullet hit) is handled in two places with different data, producing double effects or dead code.
3. **Global mutable singletons + event listeners that are never unsubscribed**, so every new run stacks handlers on top of the previous run's.
4. **Data files that exist but are not wired in** (waves, enemies, passives, rarities), so the "data-driven" promise in the docs is not actually true.
5. **No tests, no CI, no linting**, despite the framework doc mandating tests per system.

The remake keeps LÖVE and the good architectural ideas (state stack, event bus, single settings/data files, block-grid UI, on-screen debug log) but rebuilds on a **stable-ID, single-owner, ECS-lite architecture** with automated tests from day one, and makes the musical theme a real mechanic (beat-synchronized gameplay) rather than a skin.

The plan is broken into **8 phases (P0–P7)**, each with explicit deliverables, file lists, and exit criteria, sized so each phase is a shippable, testable slice.

---

## 2. What the Game Is

### Premise (from `docs/lore.md`)
Joe, a burned-out office worker, is chosen by the Wizard of Groove to restore rhythm to the universe. He travels genre-themed planets (rock, reggae, hip-hop, pop, synth…), fighting "rhythmless" creatures (Tempo Leeches, Monotones, Clicktrack Clones, Boredom Shufflers) and earning legendary instruments as artifacts.

### Core loop (target)
1. Pick a character → drop into an arena.
2. Auto-firing weapons; player focuses on movement/positioning; enemies swarm in escalating waves.
3. Kills drop XP gems → level-ups pause the game and offer 3 upgrade cards (new weapon / weapon level-up / passive), with reroll (coins) and skip.
4. At the end of the run timer a boss spawns; kill it to win the run.
5. Results screen: time, kills, XP, coins. Coins feed a (future) permanent meta-progression shop.

### Musical twist (the differentiator)
Everything pulses to the soundtrack's beat: weapon cooldowns can be quantized to beats, on-beat pickups/attacks earn bonuses, bosses are genre legends with pattern attacks synced to their genre's rhythm. This is stubbed in the old docs ("beat_timer.lua — disabled") and never built; in the remake it becomes a first-class system.

---

## 3. Audit of the Current Codebase

### 3.1 Repository-level red flags

| # | Finding | Severity | Detail |
|---|---------|----------|--------|
| R1 | **23 MB `love.app` macOS binary committed** (`PROTOTYPE 2/love.app/...`) | High | The entire LÖVE runtime (SDL2, Lua, OpenAL frameworks…) is version-controlled. Bloats every clone (~10.6 MB packfile), is macOS-only, and will go stale. Runtimes belong in a README install step or a release pipeline, never in the repo. |
| R2 | **No `.gitignore` anywhere** | High | `.DS_Store` is committed at the root; `debug_output.txt` (containing `zsh: command not found: love` — a stray shell error) is committed inside the game folder. Logs/crash dumps would be committed too. |
| R3 | **Two full prototypes + a `src_legacy` duplicate tree in one repo/branch** | High | `PROTOTYPE 1/src` and `PROTOTYPE 1/src_legacy` are near-identical copies (~30 duplicated files). Dead code was "archived" by copying instead of relying on git history. Nobody can tell which code is live. |
| R4 | **Folder names with spaces** (`PROTOTYPE 1`, `PROTOTYPE 2`) | Medium | Breaks unquoted shell commands, complicates CI paths and `love` invocation. |
| R5 | **Commit history documents shipped-broken states** | Medium | Messages like "Needs fixing some bugs still", "Not working properly yet" show a workflow of committing regressions to the mainline with no branch/test discipline. Fine for a solo prototype, but the remake needs a working-main policy. |
| R6 | **No LICENSE, no CI, no tests** | Medium | `tests/` is mandated by the framework doc but doesn't exist in either prototype. |

### 3.2 Prototype 1 assessment

- **Stack:** LÖVE + HUMP (gamestate/vector), windfield (Box2D wrapper), anim8, custom camera/event libs.
- **State:** Abandoned mid-refactor. Its own README/commits admit: mouse aim buggy, weapon level-up broken ("all tagged as new"), shop level display stuck at Level 1, gems logic buggy.
- **Good ideas worth salvaging (as ideas, not code):** projectile pooling, weapon categories with evolution hooks in `config/weapons.lua`, gamepad + keyboard input abstraction with focus support, per-module debug flags gated by a master flag, level-up shop with reroll/skip.
- **Problems:** globals sprawl (`DEBUG_MASTER`, `Config`, `_G.Debug`…), 500–800-line god files (`player.lua` 779 lines, `game_play.lua` 564, `level_up_system.lua` 627), physics engine (windfield/Box2D) is overkill for circle/AABB survivor collisions and cost performance, and the `src_legacy` copy doubles the maintenance surface.

**Verdict: do not resurrect.** Mine `config/weapons.lua` and the input layer for design reference only.

### 3.3 Prototype 2 assessment

- **Stack:** pure LÖVE 11.4, no libraries. `conf.lua`, `main.lua`, `src/core` (camera, event_bus, input, logger, paths, settings, state_stack), `src/data`, `src/entities`, `src/systems`, `src/ui`.
- **State:** "Phase 3" — movement, aiming, auto-fire, enemies, XP gems, level-up modal, pause, game over all nominally present. **Missing vs. its own master plan:** boss, win condition, results screen, coins, options that actually persist, character select that matters, sound (zero audio code), reroll/skip buttons, rarity weights, dev tuning panel (button exists, does nothing).
- **Genuinely good bones:** the state stack, the event bus (with wildcard listeners), centralized `settings.lua`, BlockGrid responsive UI grid, the on-screen fading debug log, data modules with `defaults` + `get(id)` merge pattern.

**Verdict: this architecture direction is right, but the implementation is too tangled to fix incrementally — a clean rebuild that reuses the *patterns* is cheaper than untangling the wiring.**

### 3.4 Confirmed bugs (catalogued)

All references are to `PROTOTYPE 2/groovebound` unless noted.

| # | File / location | Bug | Effect |
|---|-----------------|-----|--------|
| B1 | `src/entities/player.lua:421-443` (`addWeapon`) | **Inverted condition**: `if #self.weapons >= 4 then` … adds the weapon. | Weapons can only be added once the inventory is *full*; a normal player can never gain a 2nd–4th weapon through this method. (UpgradeManager bypasses it with its own duplicate insert logic, which is why anything works at all.) |
| B2 | `src/ui/states/run.lua:89-96` vs `src/entities/enemy.lua:166-171` | Event payload mismatch: enemy emits `ENEMY_KILLED` with `xpValue`, run state reads `data.xp` (nil). | Every XP gem is created with `value = nil` → defaults to 1 XP regardless of enemy type. Enemy `xp_value` data is dead. |
| B3 | `src/ui/states/run.lua:228-250` + `src/entities/xp_gem.lua:54-63` + `src/systems/xp_system.lua:27-31` | **Double XP path**: gem's own `update` emits `XP_PICKED` (XPSystem listener adds XP) *and* run state's collision check calls `xpSystem:addXP(gem.value)` again. | XP can be granted twice per gem; combined with B2, XP math is untrustworthy. |
| B4 | `src/ui/states/run.lua:98-112` vs `run.lua:253-262` | **Two competing level-up triggers**: the `PLAYER_LEVEL_UP` event handler creates a modal with `(player, callback)`, while the per-frame `checkLevelUp()` poll creates another with `upgradeManager:getAvailableUpgrades(3)`. | Two modals constructed per level-up; the second path passes an options *array* into a constructor expecting a *player*, and… |
| B5 | `src/ui/states/run.lua:256` | Calls `self.upgradeManager:getAvailableUpgrades(3)` — **method doesn't exist** (it's `getUpgradeOptions`). | Runtime error on the polling path, masked only because the event path fires first and flips `isLevelingUp`. Also the polling path never resets `paused`, so its modal would soft-lock. |
| B6 | `src/ui/states/run.lua:33+` (`enter`) + `xp_system.lua:27` + `upgrade_manager.lua:34` | **Event listeners registered on every `enter()`/`new()` and never unsubscribed**; `EventBus:off` exists but is never called. RunState is also a module-level singleton, so state leaks across runs. | Each restart stacks another `PLAYER_DIED`/`ENEMY_KILLED`/`PLAYER_LEVEL_UP`/`XP_PICKED`/`CARD_PICKED` handler: after N runs, one kill spawns N gems, one card applies N upgrades, etc. Classic "works first run, weird after restart". |
| B7 | `src/systems/upgrade_manager.lua:45-65` | Upgrades matched by `name:find(...)` on display strings. Modal offers `"Speed Up"` (levelup_modal.lua:79) but manager checks `name:find("Speed Boost")`. | **"Speed Up" card silently does nothing.** Also `"Power Chord Lv2"` only matches because plain `find`, and any weapon whose name contains another's name would mis-match. Magic-pattern characters in names (`-`, `%`) would break `find` semantics. |
| B8 | `src/ui/levelup_modal.lua:50-87` | Modal option list is **hardcoded** (`Power Chord LvX`, `Bass Drop`, `Speed Up`) — ignores UpgradeManager's option generator, rarities, and the 4-slot rule. | The entire card system (weights, filtering, dedupe) is dead code; OmniGun/Pistol upgrades unreachable from the UI. |
| B9 | `src/data/waves.lua`, `src/data/enemies.lua`, `src/data/passives.lua` | **Never required by any system.** Spawner reads `Settings.spawner.wave_sizes` and `Enemy.new` hardcodes `Settings.enemies.basic`. | All enemies are "basic"; intermediate/advanced/boss types, the whole wave pattern table, and passives data are unreachable. The docs' "data-driven waves" claim is false. |
| B10 | `src/entities/enemy.lua:16` | Enemy constructor takes no type parameter; always `Settings.enemies.basic`. Health bar also divides by `Settings.enemies.basic.hp` — wrong for any future type. | Blocks enemy variety entirely. |
| B11 | `src/systems/spawner.lua:68-70` | `stopSpawnTime` computed then never used; no boss spawn; waves end at 60 s and nothing else ever happens. | Run has no ending: after last wave you idle forever. Master plan's boss/win condition absent. |
| B12 | `src/entities/player.lua:81-84` | Comment says "Skip update if immunity frames active" but code only decrements the timer (no skip). Harmless today, but shows copy-paste comment rot; the *intended* skip would have been a bug. | Misleading maintenance trap. |
| B13 | `src/ui/states/run.lua:265-291` | Player-enemy collision block computes knockback `dx/dy` then throws them away (handler recomputes its own). Duplicate of `collision_system.handlePlayerEnemyCollision` logic. | Dead code + two owners for knockback tuning. |
| B14 | `src/ui/levelup_modal.lua:126-172`, `game_over.lua:73-80` | `love.graphics.newFont(...)` called **every frame inside `draw()`** (up to 4 fonts per modal frame). | GC churn/frame spikes exactly when the game should feel snappy. Fonts must be cached (HUDInventory does it right). |
| B15 | `src/core/input.lua:60-70` | Escape handling checks `currentState.name == "RunState"`, but RunState never sets `name`; only GameOverState does. | The `Input.pause` flag can never be set in-game; pause works only because RunState handles Escape itself — more duplicate-owner logic. |
| B16 | `main.lua:219-224` vs `conf.lua:46-62` | Two competing `love.errorhandler` definitions (conf.lua wraps "original" before main.lua replaces it); main's handler `return true` is not a valid handler contract (should return a draw function or nothing), and `_G.error_message` freezes updates but the run state keeps rendering stale. | Error handling is unpredictable; crash logs may or may not be written. |
| B17 | `src/core/camera.lua:109-111` | `math.random(-shakeMagnitude, shakeMagnitude)` with **float** arguments — `math.random(m, n)` requires integers in Lua/LuaJIT; raises "bad argument" once magnitude is non-integral. | Camera shake is a latent crash (LÖVE 11.4 LuaJIT accepts floats via truncation in some builds — but it's UB across versions). Should be `(math.random()*2-1)*magnitude`. |
| B18 | `src/ui/states/run.lua:151-153` ("Quit to Title") | Pops run state and pushes a fresh TitleState **while leaking every listener** (see B6) and never calling any teardown; also `StateStack:pop()` then `push` leaves boot splash beneath. | Stack depth and listener count grow monotonically per menu round-trip. |
| B19 | `src/systems/xp_system.lua:39-79` | `addXP` only checks a single threshold crossing per call; a large XP grant that crosses two thresholds levels up once, and `getLevelProgress` divides by `(next - prev)` which is 0 if thresholds repeat; `xpLevels` in settings (10,20,…) diverges from doc (50,150,300…). | Progression math fragile; duplicate config sources disagree. |

Additional smells (not user-visible bugs but confirmed defects): `weapons.lua` `fire_rate` semantics inconsistent (pistol `fire_rate = 2` is *seconds between shots*, named "rate"); `Settings.weapons` and `data/weapons.lua` define the same weapons with **different values** (two sources of truth); `Debug.update`/`Debug.draw` called with `.` in some sites and `:` in others (works only because Debug ignores `self`); `enemy_separation.lua:91` checks `Settings.debug_display` which doesn't exist (it's `Settings.debug.display`) so its debug draw never renders; `spawner` reads `Settings.debug_tune` (also nonexistent — real path `Settings.debug.tune`).

### 3.5 Architectural problems and bad practices

1. **No stable IDs.** Cards, weapons, and passives are identified by mutable display strings. Every string edit is a logic change. (Root cause of B7/B8.)
2. **Split brains everywhere.** XP granting, level-up triggering, knockback, pause handling, error handling, and weapon data each have ≥2 independent implementations. There is no single owner per concern.
3. **Global singletons with hidden coupling.** `Debug`, `EventBus`, `Logger`, `StateStack`, `Input`, `BlockGrid` are ambient globals set in `main.lua`; modules sometimes `require` them and sometimes reach for `_G`. Load order is fragile (SafeLog/pendingLogs machinery exists purely to paper over this).
4. **Module-table states instead of instances.** `RunState` is a shared table with fields defined at module load; re-entering a run reuses stale fields unless each is manually reset (several aren't: `gameOverTimer`, `levelUpModal`).
5. **Event listeners with no lifecycle.** No `off` usage, no scoped subscriptions, no once-semantics. (B6/B18.)
6. **"No hard-coding" rule violated pervasively** while being loudly proclaimed: knockback `200` inline (run.lua:311, player.lua:399), separation `minDistance = 64`, gem `attractRadius = 200`, modal geometry, XP thresholds duplicated in code, wave times hardcoded in spawner. The settings file exists; discipline didn't.
7. **Dead/aspirational code shipped:** `checkBulletEnemyCollisions` (never called), waves/enemies/passives/globals data modules, `debug_main.lua` alternative entry point, Input fire-button plumbing (auto-fire always on), `UpgradeManager.shuffleTable` (unused).
8. **O(n²) hot loops with no spatial partition:** bullet×enemy and enemy×enemy pairs every frame; no pooling for bullets/gems/enemies (constant table churn). Fine at 20 enemies; will collapse at survivor-genre densities (300+).
9. **Per-frame allocations:** fonts (B14), the `collidables` table rebuilt every draw, closures in hot paths.
10. **Inconsistent require paths:** `require("src/core/settings")` vs `require("src.core.settings")` (globals.lua) — loads the same file twice as *two separate module instances*, so "hot-reload" writes to a copy nobody reads.
11. **Logging is print-spam:** every bullet fired logs two lines (player.lua:284-287 logs unconditionally, ignoring the per-file flag it checks 60 lines earlier); framework doc's "never log per-frame events" is violated by the code written against it.
12. **No pause abstraction:** `paused`/`isLevelingUp` booleans checked ad hoc; game-over is a state push on top of a still-live run state that keeps drawing.
13. **Version pinned to LÖVE 11.4** (2022): fine, but 11.5 is current in the 11.x line; remake should pin and test against 11.5.
14. **No seeding policy:** `math.randomseed` only in Prototype 1; Prototype 2 never seeds; no run-seed concept for reproducible testing/daily runs.
15. **Docs drift:** framework.md, master-plan.md, phase3_status.md, and settings.lua disagree on XP thresholds, folder layout (`save/`, `tests/`, `boss_manager.lua`, `damage_system.lua` don't exist), and completed features. Status docs overstate reality ("fully data-driven" — see B9).

### 3.6 Design/legal red flags

- **⚠️ Real-artist likenesses:** lore and master plan name **Bob Marley, Snoop Dogg, Michael Jackson, Jimi Hendrix** as in-game bosses, plus "Eternal Stratocaster" (Fender trademark). Using real musicians' names/likenesses commercially without licenses invites right-of-publicity and trademark claims (several of these estates are famously litigious). **The remake must replace them with original parody-free archetypes** (e.g., "The Reggae Prophet", "The King of Pop-alon", genre-spirit bosses) from day one so content isn't built on unshippable IP.
- **Genre-clone differentiation:** Vampire Survivors clones are a crowded market; the beat-sync mechanic must be core, not cosmetic, to justify the game.
- **Music licensing:** the game's soundtrack must be original or properly licensed, and the beat-sync system's design must not depend on any specific licensed track.

### 3.7 What is worth keeping (as designs, not code)

- State-stack + event-bus + centralized settings **pattern** (rebuilt with lifecycles).
- BlockGrid responsive UI grid concept.
- On-screen fading debug logger + file logger concept, with per-channel flags.
- Data-module pattern (`defaults` + deep-merged `get(id)`), extended to *actually be consumed*.
- The master plan's product spec (§2 of this doc) — the loop design is sound.
- Prototype 1's weapon config schema (categories, slots, evolution hooks) as the model for the new weapon data format.

---

## 4. Remake Vision & Design Pillars

1. **The groove is the game.** Every system (weapons, enemies, bosses, UI pulses) can query the beat clock. Playing "on beat" is rewarded; the world visibly moves to the music.
2. **Data first.** Designers add a weapon, enemy, wave, passive, or character by adding a table entry — zero engine edits. Every table is validated at load with loud errors.
3. **One owner per concern.** Every gameplay fact (XP, damage, pause, spawning) has exactly one system that mutates it; everyone else listens.
4. **Deterministic and testable.** A run is reproducible from a seed; core systems run headless under a test harness; main branch always boots and passes tests.
5. **Placeholder-friendly art pipeline.** Shapes now, sprites later, hitboxes never change when art lands (kept from the original plan).
6. **Ship a vertical slice early, then widen.** Boss + win/lose + results screen exist by Phase 3, not "later".

---

## 5. Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Engine | **LÖVE 11.5** (pin exact version in `conf.lua` + README) | Team knows it; both prototypes prove it's sufficient; excellent Lua iteration speed. Revisit LÖVE 12 when stable. |
| Language | Lua 5.1 semantics (LuaJIT) | LÖVE default. Adopt `luacheck` config to catch accidental globals. |
| Libraries (few, vetted, vendored under `lib/` with pinned versions) | `hump.class` or hand-rolled 30-line class helper; **no physics engine** (custom circle/AABB + spatial hash); `json.lua` for save data; optionally `batteries` for table utils | Prototype 1 showed Box2D is overkill and a perf tax. Everything else is small enough to own. |
| Test runner | **busted** (headless, mocking LÖVE APIs) + a LÖVE smoke-run script | Enables CI without a GPU. |
| Lint/format | `luacheck` + `.editorconfig` (2-space indent, 120 cols) | Enforce the standards the old framework doc only wished for. |
| CI | GitHub Actions: luacheck → busted → `love --version` boot smoke (xvfb) on push/PR | Keeps main green. |
| Audio | LÖVE `love.audio` sources + a custom **BeatClock** driven by declared BPM metadata per track (not FFT onset detection) | Deterministic, cheap, testable; tracks ship with a small metadata table (bpm, offset, time signature). |
| Packaging | `.love` zip via Makefile/script; per-OS bundles only in release CI, **never committed** | Fixes R1. |

---

## 6. Target Architecture

### 6.1 Repository layout (new, single game, no spaces)

```
groove-bound/
├── .github/workflows/ci.yml
├── .gitignore                  # .DS_Store, logs/, *.love, dist/, crash_*.log
├── .luacheckrc
├── LICENSE
├── README.md
├── Makefile                    # run, test, lint, package targets
├── conf.lua
├── main.lua                    # ~40 lines: bootstrap only
├── lib/                        # vendored 3rd-party (pinned, tiny)
├── src/
│   ├── core/                   # engine-agnostic-ish plumbing
│   │   ├── class.lua
│   │   ├── event_bus.lua       # scoped subscriptions, :off, :once, bus instances
│   │   ├── state_machine.lua   # stack-based, instance states, enter/exit/pause/resume
│   │   ├── scheduler.lua       # timers/tweens (replaces ad-hoc gameOverTimer etc.)
│   │   ├── rng.lua             # seeded streams: loot / spawn / cosmetic
│   │   ├── log.lua             # channels, levels, ring buffer + file sink
│   │   └── save.lua            # json save/load with schema version
│   ├── game/
│   │   ├── world.lua           # owns entity lists, spatial hash, update order
│   │   ├── entities/           # player, enemy, projectile, pickup (pooled)
│   │   ├── components/         # transform, health, hitbox, faction, loot, beat
│   │   ├── systems/            # movement, homing, collision, damage, spawn_director,
│   │   │                       #   xp_level, upgrade_offer, boss_director, drops,
│   │   │                       #   separation, beat_clock, run_clock, stats_tracker
│   │   └── run_context.lua     # per-run container: seed, rng, bus, world, clocks
│   ├── content/                # DATA ONLY (validated at load)
│   │   ├── weapons.lua
│   │   ├── passives.lua
│   │   ├── enemies.lua
│   │   ├── waves.lua
│   │   ├── bosses.lua
│   │   ├── characters.lua
│   │   ├── rarities.lua
│   │   ├── tracks.lua          # music metadata: file, bpm, offset, loop points
│   │   └── validate.lua        # schema checks, fail-loud on boot
│   ├── config/
│   │   ├── settings.lua        # tunables (single source of truth; nothing gameplay-inline)
│   │   ├── controls.lua        # kb/mouse/gamepad bindings
│   │   └── paths.lua
│   ├── ui/
│   │   ├── grid.lua            # BlockGrid v2
│   │   ├── widgets/            # button, card, bar, panel (focusable, gamepad-aware)
│   │   ├── fonts.lua           # cached font registry (fixes B14)
│   │   ├── hud.lua
│   │   └── screens/            # title, options, char_select, run, pause, level_up,
│   │                           #   game_over, results, debug_tuning
│   └── debug/
│       ├── overlay.lua         # on-screen log (kept concept)
│       ├── hitboxes.lua        # one master toggle
│       ├── tuning_panel.lua    # live sliders (finally implemented)
│       └── console.lua         # optional: spawn X, give weapon Y, set time
├── assets/
│   ├── placeholders/
│   ├── audio/
│   └── fonts/
├── tests/
│   ├── unit/                   # xp math, rng, event bus, data validation, upgrade logic
│   └── sim/                    # headless run simulations (seeded, assert invariants)
└── docs/
    ├── design.md               # living master plan (this doc's §4+ evolves there)
    ├── architecture.md
    └── content-authoring.md    # how to add a weapon/enemy/wave
```

### 6.2 Core architectural rules (fixing §3.5 root causes)

1. **Stable IDs everywhere.** Content keyed by `id` (`weapon.power_chord`); UI strings live in the data entry (`name`, `description`) and are never used for logic. Upgrade cards are `{kind="weapon"|"weapon_level"|"passive", id=..., to_level=...}` structs, not strings. *(Kills B7/B8 class of bugs.)*
2. **RunContext owns run lifetime.** Everything per-run (world, seeded RNGs, run-scoped event bus, clocks, stats) lives in one object created on run start and garbage-collected on run end. Run-scoped listeners attach to the run bus, so ending a run drops all of them wholesale. App-scoped bus is separate and tiny. *(Kills B6/B18.)*
3. **Single-owner systems.** XPLevelSystem is the only mutator of XP/level; DamageSystem the only applier of damage; SpawnDirector the only creator of enemies. Systems communicate via events; events carry full typed payloads documented in one `events.md` registry. *(Kills B2/B3/B4/B13.)*
4. **Instance states, not module tables.** Screens are classes instantiated on push; no residual state across visits. `pause()`/`resume()` hooks let level-up push over run without booleans sprinkled everywhere. *(Kills B4/B18 residue.)*
5. **Pooling + spatial hash.** Projectiles, enemies, pickups from object pools; a uniform-grid spatial hash (cell ≈ 2× max entity radius) services all collision queries. Target: 500 enemies + 200 projectiles at 60 fps. *(Fixes §3.5-8/9.)*
6. **Determinism.** One seed per run → named RNG streams (`rng.loot`, `rng.spawn`, `rng.vfx`). No `os.time`/`math.random` outside `rng.lua`. Headless sim tests replay seeds and assert invariants (XP totals, no orphan listeners, boss spawns at T).
7. **Fail-loud data validation.** On boot, `content/validate.lua` type-checks every table (required fields, ranges, dangling ID references — e.g., wave referencing unknown enemy id). A typo'd enemy id is a boot error, not a silent basic-enemy fallback. *(Kills B9/B10 silent-fallback class.)*
8. **No ambient globals.** Modules receive dependencies via `require` (stateless) or constructor injection (stateful). `luacheck` denies new globals. Debug overlay is the single sanctioned pseudo-global, injected in `main.lua`.
9. **Settings discipline enforced by review checklist + grep gate:** numeric literals in `src/game/**` outside `content/`/`config/` fail review; a CI grep flags suspicious inline numbers.

---

## 7. Systems Design Specifications

### 7.1 Game states / screens

```
Boot → Title → (Options) → CharacterSelect → Run
Run ⇄ Pause (push)         Run ⇄ LevelUp (push, freezes run clock)
Run → Victory/Defeat → Results → Title
```
- Push/pop only; every screen implements `enter/exit/pause/resume/update/draw/input`.
- Run clock (game time) is owned by RunContext and only ticks when Run is the top, unpaused state — one freeze mechanism for pause, level-up, and game-over transition. *(Replaces `paused`/`isLevelingUp` boolean maze.)*

### 7.2 Player & input

- WASD/arrows + mouse aim; full gamepad (left stick move, right stick aim) from Phase 1 — input layer abstracts to `move_vec`, `aim_vec`, `confirm/cancel/pause` actions (Prototype 1's design, reimplemented).
- Auto-fire always (genre standard); aim controls direction for directional weapons.
- i-frames, knockback (single implementation in DamageSystem), HP; contact damage ticks on a settings-defined cadence rather than per-frame collision events.
- Characters (data-driven): starting weapon, stat modifiers, unlock condition. Joe first; schema supports more.

### 7.3 Weapons

- Behavior archetypes implemented once, parameterized by data: `projectile` (count, spread mode fixed/full/random, pierce), `aoe_pulse` (radius ring), `orbital` (satellites), `beam` (later), `aura` (later).
- **Per-level tables, not multiplier drift:** each weapon defines `levels = {  {damage=15, cooldown=0.9, count=1}, ... }` (up to 10) so balance is auditable and the "×1.25 forever" compounding bug class disappears. Level-up = swap stat row.
- Cooldowns expressed in **seconds or beats** (`cooldown = {beats = 2}`) — the beat-sync hook (see §9).
- 4 weapon slots, no duplicates; slot/inventory logic lives in one `Loadout` component with exhaustive unit tests (direct response to B1).
- Launch set (from master plan): Power Chord (straight shot), Bass Drop (radial pulse), Drone Tambourine (orbital), Snare Scatter (spread). Base sidearm: Kazoo Pistol.

### 7.4 Enemies & spawning

- Enemy types fully data-driven: hp, speed, damage, size, xp, coins, color/sprite, movement brain (`chase`, `zigzag`, `ranged`, later `charger`), on-beat modifiers.
- **SpawnDirector** consumes `content/waves.lua`: a timeline of `{at=sec, pattern=..., enemies={{id, count, cadence}}, position=ring|edge|cluster}`. Supports simultaneous streams, elite injection, and a difficulty scalar (time-based HP/count ramp). *(Actually wires in what B9 left dead.)*
- Enemy separation via the spatial hash (neighbor queries), soft push forces, capped per-frame iterations.
- Culling/streaming rule for off-screen enemies (teleport-behind-player recycle at extreme distance, à la VS) to keep density up without runaway counts.

### 7.5 Combat & collision

- CollisionSystem is query-based over the spatial hash; circle-primary hitboxes (rect option for walls). Layers: player / player-projectiles / enemies / enemy-projectiles / pickups.
- DamageSystem resolves hits: damage, crit (luck), knockback, i-frames, pierce counters, kill events with **typed payload** `{enemy_id, x, y, xp, coins, killer_weapon_id}` documented in the event registry. *(Fixes B2 forever.)*
- Damage numbers (pooled floating text) — cheap juice with debugging value.

### 7.6 XP, leveling, upgrades

- Pickups: XP gems (tiered visuals by value), coins, occasional health notes; magnet radius stat; global vacuum item later.
- XPLevelSystem: curve from `settings.progression` (formula + optional per-level overrides); handles **multi-level grants in one pickup** (loop until below threshold — fixes B19); emits one `LEVEL_UP` per level with queued modals.
- **UpgradeOfferSystem** builds card offers: pool = new weapons (if slot free) ∪ owned-weapon level-ups (below max) ∪ passives (new or below max); weighted by `rarities.lua` and luck stat; guarantees no duplicate cards in one offer; supports reroll (coin cost) and skip (small XP refund). Cards are ID-structs rendered by UI (see 6.2-1).
- Passives from `content/passives.lua` with `apply(stats)` mapping into a **StatSheet** (base + additive + multiplicative buckets recomputed on change; no compounding-mutation bugs).

### 7.7 Boss & run resolution

- BossDirector: at `run_duration`, regular spawns stop, arena edge pulses, boss spawns with intro banner + big HP bar; boss has 2–3 telegraphed attack patterns (beat-timed).
- Boss death → Victory; player death → Defeat; both → Results screen (time, kills by type, damage dealt per weapon, XP, level, coins banked) fed by StatsTracker (a pure event listener — great test target).
- Coins persist via `core/save.lua` (versioned JSON in save dir) — the meta-shop hook, even before the shop exists.

### 7.8 Camera & arena

- Camera: smooth-damped follow, **clamped to arena bounds** (old camera shows out-of-bounds void near walls — edge_buffer setting existed but was unused), trauma-based shake (`shake += trauma`, decays, offset = trauma² × noise — replaces B17's crashy `math.random(float)`).
- Arena: rect with wall thickness from settings; later variants (obstacles, hazards) sit behind the same ArenaManager interface.

---

## 8. Data-Driven Content Design

Every content table follows one pattern:

```lua
-- content/weapons.lua (illustrative schema)
return {
  power_chord = {
    id          = "power_chord",
    name        = "Power Chord",
    description = "Fires quick riff notes forward.",
    archetype   = "projectile",
    tags        = {"string", "attack"},
    max_level   = 10,
    beat        = { quantize = "half" },     -- optional beat-sync behavior
    levels = {
      { damage = 15, cooldown = 0.9, count = 1, speed = 450, size = 6, spread = 0 },
      { damage = 18, cooldown = 0.9, count = 1, speed = 450, size = 6, spread = 0 },
      { damage = 18, cooldown = 0.8, count = 2, speed = 450, size = 6, spread = 8 },
      -- ... through level 10
    },
  },
}
```

Authoring rules (enforced by `validate.lua` + documented in `docs/content-authoring.md`):

- `id` must equal its table key; all cross-references (waves→enemy ids, characters→weapon ids, bosses→track ids) checked at boot.
- Naming: cooldowns always **seconds** (or `{beats=n}`); "rate" terminology banned (fixes the fire_rate ambiguity).
- One source of truth: gameplay numbers live *only* in `content/`; `config/settings.lua` holds engine/feel tunables (camera, UI, debug, audio volumes) — the current Settings-vs-data/weapons duplication is abolished.
- Every table addition requires a matching validation rule and (for logic-bearing fields) a unit test.

---

## 9. The Musical Identity (Beat-Sync Layer)

The remake's differentiator, built as an ordinary system rather than magic:

- **BeatClock** (Phase 4): given the playing track's `{bpm, offset, signature}` from `content/tracks.lua`, exposes `getBeat()`, `beatPhase()` (0–1), `isOnBeat(tolerance)`, `beatsToSeconds(n)`, and emits `BEAT` / `BAR` events. Driven by `source:tell()` with dt-smoothed fallback, so pause/resume and loop points stay in sync. Fully unit-testable with a fake source.
- **Consumers (each independently toggleable):**
  - Weapon quantize: `cooldown = {beats=1}` weapons fire *on* the beat; ready-but-waiting weapons show a charged glow.
  - Groove meter: collecting gems / dodging within on-beat windows builds a multiplier (damage/XP %) that decays on hits — the skill-expression layer.
  - Enemy choreography: certain enemies step/lunge on beats or bars (Boredom Shufflers shuffle on the 2 and 4); bosses telegraph on bar boundaries.
  - Presentation pulse: UI bars, gem shimmer, arena grid brightness keyed to `beatPhase()` — the world visibly grooves even before mechanics land.
- **Fallback discipline:** every beat feature must degrade gracefully when no track metadata exists (defaults to a 100 BPM internal clock), so content never hard-depends on audio assets.
- **Boss/legends redesign (legal fix):** original archetype bosses per genre — e.g., *The Static Baron* (noise), *Maestro Monotone* (drone), *DJ Discord* — with genre-flavored patterns. No real-person names, no trademarked instruments.

---

## 10. UI/UX Plan

- **Grid v2:** BlockGrid concept kept; adds anchoring (center/edges) and safe-area so layouts don't assume 1280×720; window becomes resizable once UI is anchored.
- **Widget set:** focusable Button, Card, Slider, Bar, Panel — one implementation, keyboard/mouse/gamepad navigation built in (Prototype 1 had gamepad focus; Prototype 2 lost it — restore it as a core widget feature, not per-screen code).
- **Screens:** Title (Play/Options/Quit + debug entry), Options (volumes, screen shake, show-damage-numbers, persisted via save.lua — the old options menu saved nothing), Character Select, Run HUD (HP, XP+level, timer, groove meter, weapon/passive slots, coins), Pause (Resume/Options/Quit + Dev Tuning when debug), Level-Up modal (3 cards + Reroll/Skip, rarity-colored, keyboard 1-3/click/gamepad), Game Over / Victory, Results.
- **Fonts:** loaded once via `ui/fonts.lua` registry (fixes B14). Placeholder aesthetic: bold flat shapes, neon-on-dark palette per the original color rules (blue=XP, gold=coins, red/orange=enemies, grey=debug).

---

## 11. Testing, Debugging & Tooling Strategy

### Testing (new — neither prototype had any)
- **Unit (busted, headless):** XP curve & multi-level grants; StatSheet math; Loadout add/level/slot rules (regression test for B1!); UpgradeOffer pool/weights/dedupe; event bus on/off/once/scoped teardown; RNG stream determinism; data validation (every content file passes; deliberately broken fixtures fail).
- **Simulation tests:** headless RunContext stepped with fake dt and scripted inputs for a 60 s seeded run; assert boss spawns, XP totals match kills exactly (regression for B2/B3), zero listeners remain after run teardown (regression for B6), pools return to baseline.
- **Boot smoke in CI:** game boots to Title under xvfb for 5 s with zero errors.
- **Manual QA checklist per phase** (documented in `docs/`): restart-twice test (the classic B6 killer), pause-during-levelup, resize during run, gamepad-only full loop.

### Debug tooling (kept & finished)
- Overlay logger with channels/levels and per-channel toggles that are *actually respected at the call site* (one `log.gameplay(...)` API — no more inline flag checks people forget).
- Master hitbox toggle drawing from the collision system's own data (never duplicated shapes).
- **Dev Tuning panel implemented** (spawn rate, damage, speed, luck sliders — the button that did nothing in Prototype 2).
- Debug console commands: `give weapon.bass_drop 3`, `time 55`, `spawn enemy.advanced 10`, `killall`, `god` — makes boss/balance iteration 10× faster.
- FPS/entity-count/pool-stats mini-readout; frame-time budget warnings.

---

## 12. Repository & Workflow Standards

1. New clean repo layout (§6.1); **do not carry over** prototypes — archive them on a `prototypes-archive` branch/tag for reference.
2. `.gitignore` from commit #1: `.DS_Store`, `logs/`, `crash_*.log`, `dist/`, `*.love`, editor droppings. **Never commit binaries/runtimes** (fixes R1/R2).
3. No spaces in paths (fixes R4). No `_legacy` copies — deleting code is what git history is for (fixes R3).
4. Branch discipline: `main` always boots and passes CI; feature branches per phase item; PRs run luacheck + busted + smoke.
5. Commit messages describe *working* increments; a red main is an incident, not a habit (fixes R5).
6. Add `LICENSE` (decide: proprietary or open) and a real README (run, test, package instructions).
7. Docs are living: `docs/design.md` updated in the same PR as behavior changes; status docs must not claim unbuilt features (fixes §3.5-15).

---

## 13. Phased Implementation Roadmap

Each phase ends with a tagged, bootable build passing CI. Estimates assume one primary developer with AI assistance.

### Phase 0 — Foundation (repo + core plumbing) — ~1 week
- New repo scaffold (§6.1), `.gitignore`, luacheck, busted, CI pipeline, Makefile (`make run/test/lint/package`).
- `core/`: class helper, event bus (scoped + off/once, **with tests**), state machine (instance states, push/pop/pause/resume, tests), scheduler, seeded RNG streams (tests), log channels + overlay skeleton, save.lua (versioned JSON, tests).
- `content/validate.lua` engine + empty content stubs; boot to a Title placeholder.
- **Exit:** CI green; boots; `make test` runs headless; restart-twice via states leaks nothing (asserted in a test).

### Phase 1 — Movement slice — ~1 week
- RunContext + world + pools + spatial hash (tests for hash queries).
- Player entity: movement, aim, camera (clamped, trauma shake), arena with walls, HUD skeleton (cached fonts), pause screen.
- Input abstraction incl. gamepad; controls in `config/controls.lua`.
- Debug: hitbox toggle, overlay logger live, FPS/entity readout.
- **Exit:** feels-good movement at 60 fps; gamepad parity; resize-safe HUD.

### Phase 2 — Combat slice — ~1–2 weeks
- Projectile archetype weapon (Kazoo Pistol) with per-level data; Loadout component (unit-tested add/level rules — B1 regression suite).
- Enemy entity + `chase` brain from `content/enemies.lua` (3 types wired, validated); SpawnDirector consuming `content/waves.lua` timeline (the real one this time); separation via spatial hash.
- CollisionSystem + DamageSystem (single knockback/i-frame owner); kill events → gems with correct values (B2/B3 regression sim test); damage numbers.
- **Exit:** seeded 60 s sim test passes: kills == gem XP total; 300 enemies + 150 bullets ≥ 60 fps on target hardware.

### Phase 3 — Progression + full run loop (vertical slice) — ~2 weeks
- XPLevelSystem (multi-level grants, tests), pickup magnetism, coins.
- UpgradeOfferSystem + rarities + luck; Level-Up modal with reroll/skip; passives (Speed, Health, Damage, Magnet) through StatSheet (tests).
- All four launch weapons (projectile, aoe_pulse, orbital, spread) at 10 levels each.
- BossDirector + first boss (The Static Baron) + Victory/Defeat + Results screen + coin banking to save file.
- Character select (Joe), options screen that persists.
- **Exit:** complete run: title → select → 3-min run → boss → results → title, twice in a row, gamepad-only, no leaks; this is the *playtestable vertical slice*.

### Phase 4 — The Groove layer — ~2 weeks
- BeatClock + `content/tracks.lua` (one original/CC0 test track per tempo band); beat events; presentation pulses (UI, gems, arena).
- Weapon beat-quantize option; Groove meter (on-beat multiplier) with HUD; one beat-choreographed enemy; boss patterns re-timed to bars.
- Audio bus: SFX hooks (fire, hit, pickup, level-up, UI), volume options wired.
- **Exit:** blind test — players report the game "moves with the music"; toggling beat features off leaves a fully functional plain build (fallback discipline).

### Phase 5 — Content expansion & balance — ~2–3 weeks
- Enemies to ~8 types incl. ranged + elite modifiers; wave timeline for a 10-minute run; second boss.
- Weapons to ~8; passives to ~8; weapon evolution rules (max weapon + specific passive → evolved form) — schema hooks from day one, implementation here.
- Dev Tuning panel + debug console (spawn/give/time) to accelerate balancing; StatsTracker-driven balance dashboards (per-weapon DPS share on results screen).
- Difficulty scalar & luck tuning passes with seeded reproducible runs.
- **Exit:** 10-minute run with continuous escalation; internal playtests hit target death curve (~40% fail first boss).

### Phase 6 — Meta & polish — ~2–3 weeks
- Meta shop (permanent upgrades bought with banked coins) + save schema migration test.
- 2nd and 3rd characters with distinct starts; unlocks.
- Juice pass: hit-stop, particles (pooled), screen transitions, better placeholder art or first sprite drop (hitboxes untouched per pillar 5).
- Accessibility: shake off/reduce, flash reduction, remappable controls, colorblind-safe pickup palette.
- **Exit:** "friends-and-family demo" quality; new-player completes a run without instruction.

### Phase 7 — Release engineering — ~1–2 weeks
- Release CI: `.love` + Win/macOS/Linux bundles; crash reporter (error handler writes structured crash log — one implementation, unlike B16).
- Performance hardening: profile top-3 hotspots; GC tuning (`collectgarbage` step budget); memory ceiling test in sim.
- Final legal sweep: no real-artist references (grep gate for banned names), soundtrack licenses documented, LICENSE + credits.
- **Exit:** tagged 0.1.0 demo build downloadable from CI artifacts.

**Total: ~12–15 working weeks to a polished demo**, with a playable vertical slice at the end of Phase 3 (~4–5 weeks in).

---

## 14. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Real-musician IP in existing lore/design | Certain (already present) | Legal — unshippable | Replace with original archetypes in Phase 0 docs; CI grep for banned names; original/licensed music only. |
| Beat-sync feels gimmicky or annoying | Medium | Core differentiator fails | Build as toggleable layer (Phase 4 exit criterion includes plain-build fallback); playtest early; groove meter rewards without punishing off-beat play. |
| Performance collapse at survivor-scale density | Medium | Core feel fails | Spatial hash + pooling from Phase 1; density perf test is a Phase 2 exit criterion, not an afterthought. |
| Scope creep repeating prototype history (2 abandoned attempts) | High | Third abandonment | Phased exits with Definition of Done; vertical slice by Phase 3; content additions are data entries, not engine work. |
| Solo-dev bus factor / AI-generated wiring bugs | High (proven by B1–B19) | Silent regressions | The test suite exists precisely to catch the observed bug classes; every audited bug gets a named regression test. |
| LÖVE limitations later (shaders, web export) | Low | Platform reach | Keep `core/` LÖVE-isolated behind thin wrappers; LÖVE 12 / love.js evaluated after 0.1.0. |
| Balance debt from 10-level hand-authored weapon tables | Medium | Tedium | Authoring helpers (curve generators emitting tables), tuning panel, seeded sims for DPS comparison. |

---

## 15. Definition of Done per Phase

A phase is complete only when **all** hold:

1. `make lint` and `make test` pass in CI on `main`.
2. Boot smoke passes; the game runs its full currently-implemented loop **twice consecutively** without residual-state artifacts (the B6 test).
3. No new numeric literals in `src/game/**` (grep gate) — all tunables in `content/` or `config/`.
4. Every new event type is documented in the event registry with its payload schema.
5. Every bug class fixed from the audit (B1–B19) that the phase touches has a named regression test.
6. `docs/design.md` and `docs/architecture.md` updated in the same PR; no doc claims an unbuilt feature.
7. Playable build tagged (`phase-N`) and a 5-minute self-playtest note recorded in `docs/playtests/`.

---

## Appendix A — Full bug index (quick reference)

B1 inverted addWeapon · B2 xpValue/xp payload mismatch · B3 double XP grant paths · B4 dual level-up triggers · B5 nonexistent getAvailableUpgrades call · B6 listener leaks across runs · B7 name-substring upgrade matching ("Speed Up" dead card) · B8 hardcoded modal options bypassing offer system · B9 dead data files (waves/enemies/passives) · B10 enemy type ignored · B11 no boss/run ending · B12 misleading i-frame comment · B13 dead knockback computation · B14 per-frame font allocation · B15 unreachable Input pause flag · B16 conflicting error handlers · B17 float math.random crash risk in shake · B18 state-stack + listener leak on quit-to-title · B19 single-threshold XP crossing & duplicated threshold config.

## Appendix B — Salvage map (old → new)

| Old artifact | Disposition |
|---|---|
| P2 state_stack / event_bus / settings / BlockGrid / debug overlay | Redesign & reimplement with lifecycles + tests (Phase 0) |
| P2 data modules (defaults + get) | Pattern kept, moved to `content/` with validation |
| P1 `config/weapons.lua` schema (categories, slots, evolution) | Design reference for new weapon schema |
| P1 gamepad/input abstraction | Design reference for Phase 1 input layer |
| P1 windfield/Box2D physics | Dropped — custom collision + spatial hash |
| `src_legacy`, `debug_main.lua`, both prototypes' game code | Archived on a branch; not carried forward |
| `love.app`, `.DS_Store`, `debug_output.txt` | Deleted from tracking; ignored |
| lore.md / master-plan.md product spec | Carried into `docs/design.md` **minus real-artist names** |
