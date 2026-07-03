# Groove Bound (remake)

A survival roguelike where the groove is the game. This folder is the
ground-up remake described in [`../GROOVE_BOUND_REMAKE_PLAN.md`](../GROOVE_BOUND_REMAKE_PLAN.md);
the old prototypes live in `PROTOTYPE 1/` and `PROTOTYPE 2/` for reference only.

## Requirements

- [LÖVE 11.5](https://love2d.org/) to play
- LuaJIT to run the headless test suite (`apt install luajit` / `brew install luajit`)

## Run

```sh
cd groove-bound
make run        # or: love .
```

## Test / lint

```sh
make test       # headless unit tests (no LÖVE needed)
make lint       # luacheck
```

## Layout

| Path | Contents |
|---|---|
| `src/core/` | Engine-agnostic plumbing: class, event bus, state machine, scheduler, RNG, log, save |
| `src/content/` | **Data only** — weapons, enemies, passives, characters, waves; validated at boot |
| `src/config/` | Engine/feel tunables (never gameplay numbers) |
| `src/game/` | Entities and systems (from Phase 1) |
| `src/ui/` | Screens, widgets, fonts |
| `src/debug/` | Overlay, tuning tools |
| `tests/` | Headless unit tests + runner |

## Ground rules

1. Content is keyed by stable `id`s; display names are never used for logic.
2. Every per-run listener/timer attaches through a run-scoped owner and dies with it.
3. No numeric tunables inline in `src/game/` — they live in `content/` or `config/`.
4. Every new system ships with unit tests; `main` stays green.
