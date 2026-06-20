# Hunter Game — Design Spec

**Date**: 2026-06-21
**Status**: Approved (pending user review of this doc)
**Author**: Brainstorming session with Claude

## Overview

A 3D stylized open-world survival/hunting RPG built in Godot 4 with GDScript. Non-turn-based, real-time action. The project is delivered in two milestones (vertical slice approach), targeting roughly 8–10 weeks total for a solo developer new to Godot and 3D.

The game's core loop: **explore forest → stalk animals → hunt with bow → gather/skin → craft at campfire → manage hunger/stamina**.

## Goals and Non-Goals

### Goals (Milestone 1 — Hunting Feel, 4–6 weeks)
1. Validate that the **stealth + bow hunting** gameplay feels good.
2. A single playable forest map (≈100m × 100m) with hand-placed Quaternius/Kenney assets.
3. Two animals with distinct behaviors: prey (deer) and predator (wolf).
4. Third-person character control, sneak, bow-and-arrow combat.
5. Minimal HUD: HP, arrows, kill counter.

### Goals (Milestone 2 — Survival Loop, +4 weeks)
1. Validate the full **hunt → gather → craft → eat** survival loop.
2. Gathering (berries, wood, stone) and skinning (meat, hide) from corpses.
3. Inventory + 5 fixed crafting recipes at a placeable campfire.
4. Hunger + stamina survival needs; running consumes stamina.

### Non-Goals (both milestones)
- Save/load system (death = reload scene).
- Multiplayer.
- Multiple biomes, weather, day/night.
- NPCs, dialogue, quests, story.
- Skill trees, leveling.
- Equipment durability.
- Audio polish, music, complex VFX.

## Technical Stack

- **Engine**: Godot 4.x (latest stable)
- **Language**: GDScript only (no C#, no mixed)
- **Art assets**: Free packs from Quaternius and Kenney (low-poly stylized). All assets imported under `assets/` with no edits beyond Godot's import settings.
- **AI architecture**: Hand-written finite state machines in GDScript (one base class + per-state subclasses). No LimboAI or other plugins.
- **No third-party plugins** for Milestone 1 or 2.

## Architectural Approach: Scene-Centric with Event Bus

Selected approach (vs. component-based or ECS): each game object is a scene (`.tscn` + same-named `.gd`), state is in three autoloads, and cross-scene communication goes through a global event bus.

### The Three Autoloads (strict limit)

**`EventBus`** (signals only, no state):
```gdscript
signal animal_killed(animal_type: String, position: Vector3)
signal animal_alerted(animal: Node3D)
signal player_shot_arrow(from: Vector3, direction: Vector3)
signal player_hit_by(damage: float, source: Node3D)
# Milestone 2 adds:
signal item_gathered(item_id: String, count: int)
signal hunger_critical()
```

**`GameState`** (runtime player state):
```gdscript
# Milestone 1
var hp: float = 100.0
var arrows: int = 10

# Milestone 2 adds
var hunger: float = 100.0
var stamina: float = 100.0
var inventory: Dictionary = {}  # {item_id: count}
```

**`Config`** (tuning constants, immutable):
```gdscript
const DEER_VIEW_RANGE := 15.0
const DEER_HEARING_RANGE := 8.0
const WOLF_AGGRO_RANGE := 12.0
const ARROW_DAMAGE := 50.0
const PLAYER_WALK_SPEED := 4.0
const PLAYER_SNEAK_SPEED := 1.5
const PLAYER_RUN_SPEED := 7.0  # Milestone 2
```

### Communication Rules

1. **Parent → child**: direct method call (OK).
2. **Child → parent**: signal, parent connects.
3. **Cross-scene broadcast**: `EventBus`.
4. **Direct interaction** (e.g., arrow hits deer): duck-typed call — `if body.has_method("take_damage"): body.take_damage(amount)`.
5. **Forbidden**: `get_node("../../OtherThing")` — relative paths leaking outside the scene.

The mix of "direct call for one-to-one impact" + "EventBus for one-to-many broadcast" is intentional. EventBus is for UI, statistics, achievements — not for combat logic.

## Project Layout

```
hunter_game/
├── project.godot
├── assets/                    # Imported Quaternius/Kenney
│   ├── models/animals/        # deer.glb, wolf.glb
│   ├── models/characters/     # player.glb
│   ├── models/environment/    # trees, bushes, rocks
│   ├── textures/
│   └── audio/
├── scenes/                    # Instantiable game objects (.tscn + .gd pairs)
│   ├── player/
│   │   ├── player.tscn
│   │   └── player.gd
│   ├── animals/
│   │   ├── deer.tscn + deer.gd
│   │   └── wolf.tscn + wolf.gd
│   ├── projectiles/
│   │   └── arrow.tscn + arrow.gd
│   ├── world/
│   │   └── forest_map.tscn
│   └── interactables/         # Milestone 2
│       ├── campfire.tscn + campfire.gd
│       ├── berry_bush.tscn + berry_bush.gd
│       └── corpse.tscn + corpse.gd
├── systems/                   # Autoloads + static utility classes
│   ├── event_bus.gd           # autoload
│   ├── game_state.gd          # autoload
│   ├── config.gd              # autoload
│   ├── items.gd               # Milestone 2: static class
│   └── recipes.gd             # Milestone 2: static class
├── ui/
│   ├── hud.tscn + hud.gd
│   └── inventory_ui.tscn + inventory_ui.gd   # Milestone 2
├── ai/                        # Shared FSM state classes for animals
│   ├── animal_state.gd        # base class
│   ├── state_idle.gd
│   ├── state_wander.gd
│   ├── state_alert.gd
│   ├── state_flee.gd
│   ├── state_chase.gd         # wolf
│   ├── state_attack.gd        # wolf
│   └── state_retreat.gd       # wolf
└── docs/superpowers/specs/    # this file
```

**Conventions**:
- `.tscn` and `.gd` files live in the same directory and share the base name.
- `scenes/` = anything you'd instantiate at runtime.
- `systems/` = global services. **Never exceed 3 autoloads.** Helpers (Items, Recipes) are static classes.
- `ai/` = state classes shared between animals.

## Milestone 1 — Hunting Feel (4–6 weeks)

### Player (`scenes/player/`)

**Node structure**:
```
Player (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D)
├── MeshInstance3D (Quaternius character)
├── AnimationPlayer
├── CameraPivot (Node3D)              # rotates with mouse
│   └── SpringArm3D                   # auto-avoids wall clipping
│       └── Camera3D                  # third-person camera
└── BowMount (Node3D)                 # arrow spawn point
```

**Behaviors**:
- Input: WASD move, Space jump, Ctrl sneak, mouse look, LMB hold-to-draw bow / release-to-fire.
- Three movement states: standing (4.0 m/s, noise 6m), sneaking (1.5 m/s, noise 1m). Running is M2.
- Bow: LMB held → charge meter rises → release → instantiate `arrow.tscn` at `BowMount`, give it `linear_velocity` based on charge level and camera forward.
- Exposes `take_damage(amount: float)` for the wolf to call.

### Arrow (`scenes/projectiles/arrow.tscn`)

```
Arrow (RigidBody3D)
├── CollisionShape3D
├── MeshInstance3D (Kenney arrow)
└── Area3D
    └── CollisionShape3D
```

- Receives initial velocity from player; gravity gives a mild arc.
- `Area3D.body_entered` → if `body.has_method("take_damage")`, call it with `Config.ARROW_DAMAGE`.
- 3-second lifetime, then `queue_free()`.

### Deer (`scenes/animals/deer.tscn`) — prey, timid

**Node structure**:
```
Deer (CharacterBody3D)
├── CollisionShape3D
├── MeshInstance3D + AnimationPlayer
├── PerceptionArea (Area3D)
└── NavigationAgent3D
```

**FSM states** (in `ai/`):
- **Idle**: stand still, graze. Random timeout (3–6s) → Wander.
- **Wander**: pick random point within 10m, navigate there. On arrival → Idle.
- **Alert**: player detected (sight or hearing). Hold for 2s; if player still detected → Flee, else → Idle.
- **Flee**: pick a point opposite the player, sprint there. 15s timeout → Wander.

**Perception**:
- **Sight**: player within `DEER_VIEW_RANGE` (15m), inside a 90° forward cone, with line-of-sight (raycast).
- **Hearing**: player within `DEER_HEARING_RANGE` (8m) AND player's current noise radius ≥ distance to deer.
- Sneaking (noise = 1m) makes the deer effectively deaf at any non-adjacent distance.

**`take_damage()`**: subtract from internal HP; on death play animation, emit `EventBus.animal_killed("deer", position)`, free after delay.

### Wolf (`scenes/animals/wolf.tscn`) — predator, aggressive

Same structure as deer plus `AttackHitbox (Area3D)`.

**FSM states**:
- **Idle** / **Wander**: same as deer.
- **Chase**: player within `WOLF_AGGRO_RANGE` (12m) → sprint toward player.
- **Attack**: distance < 2m → trigger attack animation; during animation enable `AttackHitbox`; if it overlaps player, call `player.take_damage(20)`.
- **Retreat**: HP < 30% → flee for 10s → Wander.

### Forest Map (`scenes/world/forest_map.tscn`)

- 100m × 100m terrain (heightmap-based `MeshInstance3D` with gentle hills, or a PlaneMesh subdivided).
- 50–100 hand-placed or script-scattered Quaternius trees.
- A handful of decorative rocks/bushes.
- `NavigationRegion3D` baked over the terrain.
- Invisible `StaticBody3D` walls at the boundary.
- 3–5 deer and 2–3 wolves spawned at scene start.

### HUD (`ui/hud.tscn`)

- Bottom-left: HP bar (reads `GameState.hp`).
- Bottom-right: arrow count (reads `GameState.arrows`).
- Center: crosshair (visible only while drawing bow).
- Top-left: kill counter (increments on `EventBus.animal_killed`).

### Definition of Done (Milestone 1)

1. WASD + mouse moves character through forest, third-person camera follows.
2. Crouch enables sneaking, deer cannot hear sneaking player at >2m.
3. Bow fires arrows that kill deer with one hit, death animation plays.
4. Deer flee when they see the player.
5. Wolves chase and damage the player.
6. HUD shows HP, arrows, kill count.
7. Player death reloads the scene (no save).

## Milestone 2 — Survival Loop (+4 weeks)

**Strictly additive**: Milestone 1 code is barely touched. Only `GameState` gains fields, and a few new scenes/UIs are introduced.

### Gathering

- New interactables in `scenes/interactables/`: `berry_bush.tscn`, `wood_pile.tscn` (or branch nodes), `rock.tscn`.
- Player walks within 1.5m and presses E → entity calls `GameState.add_to_inventory(item_id, count)`, then `queue_free()` (or temporary depleted state).
- Animal corpses persist for 30s; pressing E on a corpse calls "skin" — yields `raw_meat` and `hide`, then frees.

### Items (`systems/items.gd`, static class)

```gdscript
class_name Items
const DEFINITIONS := {
    "raw_meat":    {"name": "Raw Meat",    "stack": 20, "icon": "..."},
    "cooked_meat": {"name": "Cooked Meat", "stack": 20, "icon": "..."},
    "wood":        {"name": "Wood",        "stack": 50, "icon": "..."},
    "stone":       {"name": "Stone",       "stack": 50, "icon": "..."},
    "berry":       {"name": "Berry",       "stack": 20, "icon": "..."},
    "hide":        {"name": "Hide",        "stack": 10, "icon": "..."},
    "juice":       {"name": "Berry Juice", "stack": 10, "icon": "..."},
}
```

### Inventory UI (`ui/inventory_ui.tscn`)

- Hidden `CanvasLayer`, toggled by Tab.
- 8×4 grid showing icon + count for each entry in `GameState.inventory`.
- Click on stackable food (cooked meat, berry juice) → eat → restore hunger / HP.

### Campfire (`scenes/interactables/campfire.tscn`)

- Player presses F → instantiate campfire 2m ahead (consumes 3 wood from inventory).
- Press E near a campfire → opens crafting UI listing available recipes.

### Recipes (`systems/recipes.gd`, static class) — exactly 5

A recipe's `out` can target one of three things, declared by `out_kind`:
- `"inventory"` — adds items to `GameState.inventory`
- `"counter"` — increments a named field on `GameState` (e.g., `arrows`, `hp_max`)
- `"placeable"` — gives the player one placement charge (consumed when they press F to place)

```gdscript
class_name Recipes
const ALL := [
    {"id": "cook_meat",   "in": {"raw_meat": 1}, "out_kind": "inventory", "out": {"cooked_meat": 1}, "needs": "campfire"},
    {"id": "make_fire",   "in": {"wood": 3},     "out_kind": "placeable", "out": "campfire",         "needs": null},
    {"id": "make_arrow",  "in": {"wood": 1, "stone": 1}, "out_kind": "counter", "out": {"arrows": 5}, "needs": null},
    {"id": "make_armor",  "in": {"hide": 2},     "out_kind": "counter",   "out": {"hp_max": 20},     "needs": null},
    {"id": "berry_juice", "in": {"berry": 3},    "out_kind": "inventory", "out": {"juice": 1},       "needs": null},
]
```

`make_armor` is a one-time permanent bonus (no durability). `make_fire` gives the player a "placement charge" they activate by pressing F. `juice` is a new inventory item — add it to `Items.DEFINITIONS`.

### Hunger + Stamina

- `GameState.hunger`: starts 100, drains 0.05/sec (~33 min to empty).
- At 0 hunger → HP drains 1/sec.
- Eating: cooked meat +40 hunger; raw meat +15 hunger but -10 HP; berry juice +30 hunger.
- `GameState.stamina`: starts 100, recovers 5/sec while standing/walking. Running drains 10/sec, drawing bow drains 5/sec while held.
- At stamina < 10: forced walk speed.

### Running (added in M2)

- Shift while moving → 7 m/s, noise radius 12m → animals detect easily.
- HUD adds hunger bar (orange) and stamina bar (yellow) under HP.

### Definition of Done (Milestone 2)

1. Press E to gather berries, wood, stone.
2. Press E on corpse to get meat + hide.
3. Place campfire (F), cook raw meat on it.
4. Craft arrows and simple armor.
5. Hunger and stamina visibly drain and recover.
6. Running consumes stamina; depleted stamina forces walking.
7. Full loop: hungry → sneak → hunt deer → skin → place fire → cook → eat → restore HP.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| Solo developer new to Godot, scope creep | High | Strict per-milestone scope; non-goals list is binding. |
| 3D character controller surprisingly hard | Medium | Lean on official Godot 4 third-person template; don't customize physics. |
| Animation state machine confusion | Medium | Use `AnimationPlayer` (not `AnimationTree`) in M1. AnimationTree only if M2 demands it. |
| NavigationAgent3D pathing on uneven terrain | Medium | Keep terrain mild; bake navmesh once, verify in editor before runtime. |
| Autoload sprawl | Medium | Hard cap at 3; Items/Recipes are static classes. |
| AI difficulty tuning eats time | Medium | All tunables in `Config`; tune late, not while building. |

## Open Questions

None — every decision is locked. If new questions emerge during implementation, they go into a separate `docs/decisions/` log, not back into this spec.

## Out of Scope for This Spec

Everything beyond Milestone 2. The Demo stage (months 3–4) and any production push would be re-scoped after Milestone 2 ships.
