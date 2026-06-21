# Project Status

**Last updated:** 2026-06-22 (commit `a9ffce9`)

## What's done — Milestone 1 (hunting feel)

All 15 tasks from `docs/superpowers/plans/2026-06-21-milestone-1-hunting-feel.md` are complete, plus the optional asset/animation pass:

- 3 autoloads: `EventBus`, `GameState`, `Config`
- Player CharacterBody3D with WASD + mouse-look + jump + sneak + run
- Bow charge/release shooting arrows (RigidBody3D)
- Animal FSM base + 7 states (Idle, Wander, Alert, Flee, Chase, Attack, Retreat)
- Deer (prey, view-cone + hearing perception, flees)
- Wolf (predator, aggro chase, attacks player)
- HUD: HP bar, arrow counter, kill counter, crosshair
- Forest map: 100x100 m grass, 12 stylized trees, sky, boundary walls
- Quaternius models for player (Adventurer), deer, wolf
- Animations wired: Idle / Walk / Run / Gallop / Attack / Death
- Death polish: physics off, Death animation, 2.5 s despawn

19/19 GUT unit tests passing.

## How to run

- Open `project.godot` in Godot 4.7.
- Main scene `scenes/world/forest_map.tscn` is set as the project's run target — hit Play.
- macOS shortcut: F-keys need Fn modifier, or use the top-right play buttons.
- Run tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit`

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Look (body rotates with yaw, camera pitch independent) |
| Left Ctrl | Sneak (1.5 m/s, noise 1 m) |
| Left Shift | Run (8 m/s, noise 12 m) — **see open issue 1** |
| Space | Jump |
| LMB hold/release | Draw bow / fire arrow |
| Esc | Release mouse capture |

## Tuning state (commit `a9ffce9`)

Measured real model extents (Python read of glTF bounding boxes):

| Model | W | H | D | Scale used | Final visual height |
|---|---|---|---|---|---|
| Deer | 1.46 | 4.27 | 4.40 | 0.469 | ~2.0 m |
| Wolf | 1.07 | 2.68 | 5.55 | 0.373 | ~1.0 m |
| Adventurer | 1.76 | 1.97 | 1.09 | 1.0 | ~1.9 m |

Animal colliders are BoxShape3D matching scaled model footprint exactly (not capsules).

Arrow: speed 25–45 m/s by charge, gravity_scale 0.3, HitArea 0.4×0.4×1.2 for soft aim assist.

Arrows start at 1000 (was 10) — temporary for tuning sessions. Reset by editing `systems/game_state.gd`'s `ARROWS_START`.

## Open issues — pick up here next session

1. **Run stance not firing.** User reports Shift+WASD does not trigger RUNNING. The `[stance]` debug print in `player.gd`'s `_update_stance()` never shows stance=2. Likely the input map wasn't reloaded in the user's Godot session, but verify the physical_keycode (`4194326` for Left Shift) is what the user's keyboard actually sends — try rebinding via the editor UI after a clean Godot restart.

2. **Aim feel still bumpy.** Arrows now follow camera pitch (not just yaw), but the user mentioned "射不中狼" frequently before colliders were re-measured. After commit `a9ffce9` colliders match the model — needs another play-test pass.

3. **Crosshair is a 6×6 square.** Spec calls for a crosshair while drawing the bow; we have a placeholder. Upgrade to a `+` (two thin ColorRects) when polish-time.

4. **Wolf collision box axis-aligned to wolf root.** The wolf doesn't rotate its root when chasing — the FSM rotates the model via `look_at`, but the collision BoxShape stays world-aligned. Long-axis hitbox may misalign when wolf charges sideways. Investigate during next combat tuning.

5. **Green forward indicator on player.** Still attached to `CameraPivot/ForwardIndicator` as a debugging aid. Remove or hide once aiming feels right.

## Where to find things

- Spec: `docs/superpowers/specs/2026-06-21-hunter-game-design.md`
- M1 plan: `docs/superpowers/plans/2026-06-21-milestone-1-hunting-feel.md`
- Player: `scenes/player/player.{tscn,gd}`
- Animals: `scenes/animals/{deer,wolf}.{tscn,gd}`
- FSM states: `ai/state_*.gd`
- HUD: `ui/hud.{tscn,gd}`
- Map: `scenes/world/forest_map.{tscn,gd}`
- Autoloads: `systems/{event_bus,game_state,config}.gd`
- Assets: `assets/models/{animals,characters,environment}/`
- Tests: `tests/unit/test_*.gd` (GUT, 19 passing)

## What's next — Milestone 2 (not started)

From the spec, M2 adds the survival loop:

- Gathering (berries / wood / stone)
- Inventory + Tab toggle UI
- 5 crafting recipes at a placeable campfire
- Hunger + stamina drain
- Run consumes stamina

When ready to begin, invoke the writing-plans skill to produce a fresh M2 implementation plan before touching code.

## Reproducible setup on another machine

```
git clone <repo-url> hunter_game
cd hunter_game
# Open project.godot in Godot 4.7 stable
# First open: Godot will reimport assets (one-time, a minute or two)
# Then ▶ Play
```

GUT plugin (`addons/gut/`) is committed, no extra install step needed.
