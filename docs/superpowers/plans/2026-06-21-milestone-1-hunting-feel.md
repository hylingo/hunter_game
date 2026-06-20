# Milestone 1 — Hunting Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a playable vertical slice that proves the hunting feel: third-person character, stealth, bow combat, deer that flee, wolves that attack.

**Architecture:** Scene-centric Godot 4 project. Each game object is a `.tscn` paired with a same-named `.gd`. Three autoload singletons: `EventBus` (signals only), `GameState` (runtime player stats), `Config` (tuning constants). Animal AI is a hand-written FSM with state classes shared between deer and wolf. UI is a single `HUD` overlay. No third-party plugins except GUT for unit tests.

**Tech Stack:** Godot 4.x stable, GDScript, Quaternius/Kenney free art packs, GUT plugin for unit tests.

**Reference spec:** [`docs/superpowers/specs/2026-06-21-hunter-game-design.md`](../specs/2026-06-21-hunter-game-design.md)

---

## File Structure (planned at end of M1)

```
hunter_game/
├── project.godot                   # Godot project file with autoloads + input map
├── icon.svg                        # default Godot icon, kept
├── .gitignore                      # ignores .godot/ cache
├── README.md                       # quick-start instructions
├── addons/gut/                     # GUT plugin (installed via asset library)
├── assets/                         # Quaternius/Kenney imports
│   ├── models/animals/{deer,wolf}.glb
│   ├── models/characters/player.glb
│   └── models/environment/*.glb
├── scenes/
│   ├── player/{player.tscn, player.gd}
│   ├── animals/{deer.tscn, deer.gd, wolf.tscn, wolf.gd}
│   ├── projectiles/{arrow.tscn, arrow.gd}
│   └── world/forest_map.tscn
├── systems/
│   ├── event_bus.gd                # autoload
│   ├── game_state.gd               # autoload
│   └── config.gd                   # autoload
├── ui/{hud.tscn, hud.gd}
├── ai/
│   ├── animal_state.gd             # abstract base
│   ├── state_idle.gd
│   ├── state_wander.gd
│   ├── state_alert.gd              # deer
│   ├── state_flee.gd               # deer
│   ├── state_chase.gd              # wolf
│   ├── state_attack.gd             # wolf
│   └── state_retreat.gd            # wolf
└── tests/
    ├── unit/                       # GUT unit tests (pure logic)
    │   ├── test_game_state.gd
    │   ├── test_perception.gd
    │   └── test_fsm.gd
    └── verification/               # Manual play-test scenes
        ├── player_movement_test.tscn
        ├── deer_perception_test.tscn
        └── wolf_combat_test.tscn
```

## Conventions

- Every `.gd` script that backs a `.tscn` lives in the same folder with the same basename.
- `class_name X` is set on reusable types (`AnimalState`, etc.) so they can be referenced globally.
- All tunable numbers go in `Config`. Never hard-code a magic number in gameplay scripts.
- Cross-scene events: emit on `EventBus`. Direct interactions (arrow → deer): duck-typed `take_damage`.
- Tests under `tests/unit/` are GUT tests for pure logic only. Anything involving 3D physics, navigation, or input goes in a `tests/verification/*.tscn` scene you run by hand.

---

## Task 1: Initialize Godot 4 project

**Files:**
- Create: `project.godot`
- Create: `icon.svg`
- Create: `.gitignore`
- Create: `README.md`

- [ ] **Step 1: Verify Godot 4 is installed**

Run: `godot --version`
Expected output (or similar): `4.2.1.stable.official.b09f793f5`

If Godot is not on PATH, install it from https://godotengine.org/download. macOS: `brew install godot`. The rest of this plan assumes `godot` invokes Godot 4.

- [ ] **Step 2: Create the project file**

Create `project.godot` with this exact content (Godot will populate the rest on first open):

```
; Engine configuration file.
config_version=5

[application]

config/name="Hunter Game"
run/main_scene="res://scenes/world/forest_map.tscn"
config/features=PackedStringArray("4.2", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

EventBus="*res://systems/event_bus.gd"
GameState="*res://systems/game_state.gd"
Config="*res://systems/config.gd"

[input]

move_forward={
"deadzone": 0.5,
"events": [{
"device": -1,
"physical_keycode": 87,
"key_label": 0,
"unicode": 119,
"echo": false,
"script": null
}]
}
move_back={
"deadzone": 0.5,
"events": [{
"device": -1,
"physical_keycode": 83,
"key_label": 0,
"unicode": 115,
"echo": false,
"script": null
}]
}
move_left={
"deadzone": 0.5,
"events": [{
"device": -1,
"physical_keycode": 65,
"key_label": 0,
"unicode": 97,
"echo": false,
"script": null
}]
}
move_right={
"deadzone": 0.5,
"events": [{
"device": -1,
"physical_keycode": 68,
"key_label": 0,
"unicode": 100,
"echo": false,
"script": null
}]
}
jump={
"deadzone": 0.5,
"events": [{
"device": -1,
"physical_keycode": 32,
"key_label": 0,
"unicode": 32,
"echo": false,
"script": null
}]
}
sneak={
"deadzone": 0.5,
"events": [{
"device": -1,
"physical_keycode": 4194326,
"key_label": 0,
"unicode": 0,
"echo": false,
"script": null
}]
}
fire={
"deadzone": 0.5,
"events": [{
"device": -1,
"button_index": 1,
"factor": 1.0,
"script": null
}]
}

[rendering]

renderer/rendering_method="forward_plus"
```

Note: the autoload entries point to files we'll create in Task 2; Godot tolerates missing autoloads until the project is run.

- [ ] **Step 3: Use the default Godot icon**

Create `icon.svg` with this exact content (it's the stock Godot icon):

```
<svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><rect fill="#363d52" height="128" rx="32" width="128"/><path d="m64 18a46 46 0 0 0-46 46 46 46 0 0 0 46 46 46 46 0 0 0 46-46 46 46 0 0 0-46-46zm-1.7 11.7c5.4-.1 10.9 1 16 3.4 19.9 9.5 27 35.4 14.5 53.4-12.6 18-39.6 18-52.1 0-12.5-18-5.4-43.9 14.5-53.4 2.3-1.1 4.7-2 7.1-2.6z" fill="#fff"/></svg>
```

- [ ] **Step 4: Add `.gitignore`**

Create `.gitignore`:

```
# Godot 4 cache and editor data
.godot/
.import/
export.cfg
export_presets.cfg

# OS / editor
.DS_Store
Thumbs.db
.vscode/
.idea/
```

- [ ] **Step 5: Add a minimal README**

Create `README.md`:

```markdown
# Hunter Game

A 3D stylized open-world survival/hunting RPG built in Godot 4.

## Status
Milestone 1: hunting feel vertical slice (in progress).

## Run
1. Install Godot 4.x (https://godotengine.org/download).
2. Open `project.godot` in Godot.
3. Press F5 to run.

## Tests
Open the project in Godot, then in the GUT panel (Project → Tools → GUT) run all tests in `tests/unit/`. Verification scenes under `tests/verification/` are run by opening and pressing F6.
```

- [ ] **Step 6: Verify Godot opens the project**

Run: `godot --headless --quit --path .` (from the project root)
Expected: exits cleanly with no fatal errors. Godot generates a `.godot/` cache directory (gitignored).

- [ ] **Step 7: Commit**

```bash
git add project.godot icon.svg .gitignore README.md
git commit -m "feat: initialize Godot 4 project with input map and autoload entries"
```

---

## Task 2: Add the three autoload singletons

**Files:**
- Create: `systems/event_bus.gd`
- Create: `systems/game_state.gd`
- Create: `systems/config.gd`

- [ ] **Step 1: Write the EventBus**

Create `systems/event_bus.gd`:

```gdscript
extends Node
## Global signal bus. Holds no state. Nodes emit/listen via EventBus.* to avoid
## tight coupling between scenes.

signal animal_killed(animal_type: String, position: Vector3)
signal animal_alerted(animal: Node3D)
signal player_shot_arrow(from: Vector3, direction: Vector3)
signal player_hit_by(damage: float, source: Node3D)
```

- [ ] **Step 2: Write GameState**

Create `systems/game_state.gd`:

```gdscript
extends Node
## Runtime player stats. Read by HUD, written by player.gd and combat code.

signal hp_changed(new_hp: float)
signal arrows_changed(new_count: int)

const HP_MAX := 100.0
const ARROWS_MAX := 99

var hp: float = HP_MAX:
    set(value):
        hp = clamp(value, 0.0, HP_MAX)
        hp_changed.emit(hp)

var arrows: int = 10:
    set(value):
        arrows = clamp(value, 0, ARROWS_MAX)
        arrows_changed.emit(arrows)

func reset() -> void:
    hp = HP_MAX
    arrows = 10
```

- [ ] **Step 3: Write Config**

Create `systems/config.gd`:

```gdscript
extends Node
## Tuning constants. Never mutate at runtime.

# Player movement
const PLAYER_WALK_SPEED := 4.0
const PLAYER_SNEAK_SPEED := 1.5
const PLAYER_JUMP_VELOCITY := 5.0
const PLAYER_GRAVITY := 20.0

# Noise radii (meters) — used by animal hearing checks
const NOISE_WALK := 6.0
const NOISE_SNEAK := 1.0

# Bow
const ARROW_DAMAGE := 50.0
const ARROW_SPEED_MIN := 20.0
const ARROW_SPEED_MAX := 40.0
const BOW_CHARGE_TIME := 1.0  # seconds to reach full charge

# Deer perception
const DEER_VIEW_RANGE := 15.0
const DEER_VIEW_CONE_DEG := 90.0
const DEER_HEARING_RANGE := 8.0
const DEER_HP := 40.0
const DEER_FLEE_SPEED := 8.0
const DEER_WANDER_SPEED := 1.5

# Wolf
const WOLF_AGGRO_RANGE := 12.0
const WOLF_ATTACK_RANGE := 2.0
const WOLF_HP := 60.0
const WOLF_CHASE_SPEED := 6.0
const WOLF_WANDER_SPEED := 2.0
const WOLF_ATTACK_DAMAGE := 20.0
const WOLF_RETREAT_HP_FRACTION := 0.3
```

- [ ] **Step 4: Verify the project still loads**

Run: `godot --headless --quit --path .`
Expected: exits cleanly. If you see "Autoload script failed to load", check the paths in `project.godot` match the files you created.

- [ ] **Step 5: Commit**

```bash
git add systems/
git commit -m "feat: add EventBus, GameState, Config autoloads"
```

---

## Task 3: Install GUT and write first unit tests for GameState

**Files:**
- Create: `addons/gut/` (via Godot Asset Library)
- Modify: `project.godot` (GUT adds plugin entries automatically)
- Create: `tests/unit/test_game_state.gd`

- [ ] **Step 1: Install GUT via the editor**

Open the project in Godot (`godot --path .`). In the editor:
1. AssetLib tab (top) → search "Gut" → "Gut - Godot Unit Testing" → Download → Install.
2. Project → Project Settings → Plugins → enable "Gut".
3. Close and reopen the project.

Verify `addons/gut/` exists.

- [ ] **Step 2: Write the failing test**

Create `tests/unit/test_game_state.gd`:

```gdscript
extends GutTest
## GameState is an autoload, accessible as the global identifier `GameState`.

func before_each() -> void:
    GameState.reset()

func test_initial_hp_is_max() -> void:
    assert_eq(GameState.hp, GameState.HP_MAX)

func test_hp_setter_clamps_to_max() -> void:
    GameState.hp = 9999.0
    assert_eq(GameState.hp, GameState.HP_MAX)

func test_hp_setter_clamps_to_zero() -> void:
    GameState.hp = -50.0
    assert_eq(GameState.hp, 0.0)

func test_arrows_setter_clamps_to_max() -> void:
    GameState.arrows = 500
    assert_eq(GameState.arrows, GameState.ARROWS_MAX)

func test_hp_changed_signal_emits() -> void:
    watch_signals(GameState)
    GameState.hp = 50.0
    assert_signal_emitted_with_parameters(GameState, "hp_changed", [50.0])

func test_reset_restores_defaults() -> void:
    GameState.hp = 10.0
    GameState.arrows = 0
    GameState.reset()
    assert_eq(GameState.hp, GameState.HP_MAX)
    assert_eq(GameState.arrows, 10)
```

- [ ] **Step 3: Run the test**

In the GUT panel (bottom dock when plugin is enabled), set the test directory to `res://tests/unit/`, then click "Run All".

Expected: 6 tests pass. (If "GutTest" is not found, ensure the GUT plugin is enabled.)

Equivalent CLI:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit
```

- [ ] **Step 4: Commit**

```bash
git add addons/ tests/ project.godot
git commit -m "test: install GUT and add GameState unit tests"
```

---

## Task 4: Build the player scene (no animation yet)

**Files:**
- Create: `scenes/player/player.tscn`
- Create: `scenes/player/player.gd`
- Create: `tests/verification/player_movement_test.tscn`

- [ ] **Step 1: Write player.gd (input-driven character controller)**

Create `scenes/player/player.gd`:

```gdscript
extends CharacterBody3D
class_name Player

## Third-person character controller. Owns movement, sneak state, and
## (later) bow charge/release.

enum Stance { STANDING, SNEAKING }

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var stance: Stance = Stance.STANDING

## Returns the noise radius the player is currently producing.
## Read by animal hearing checks.
func noise_radius() -> float:
    if velocity.length() < 0.1:
        return 0.0
    match stance:
        Stance.SNEAKING: return Config.NOISE_SNEAK
        _:               return Config.NOISE_WALK

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        camera_pivot.rotate_y(-motion.relative.x * 0.003)
        spring_arm.rotate_x(-motion.relative.y * 0.003)
        spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.2, 0.5)
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    _handle_jump()
    _update_stance()
    _apply_horizontal_movement(delta)
    move_and_slide()

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= Config.PLAYER_GRAVITY * delta

func _handle_jump() -> void:
    if is_on_floor() and Input.is_action_just_pressed("jump"):
        velocity.y = Config.PLAYER_JUMP_VELOCITY

func _update_stance() -> void:
    stance = Stance.SNEAKING if Input.is_action_pressed("sneak") else Stance.STANDING

func _apply_horizontal_movement(_delta: float) -> void:
    var input := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
        Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
    )
    var forward := -camera_pivot.global_transform.basis.z
    forward.y = 0
    forward = forward.normalized()
    var right := camera_pivot.global_transform.basis.x
    right.y = 0
    right = right.normalized()
    var move_dir := (right * input.x + forward * input.y).normalized() if input.length() > 0 else Vector3.ZERO
    var speed := Config.PLAYER_SNEAK_SPEED if stance == Stance.SNEAKING else Config.PLAYER_WALK_SPEED
    velocity.x = move_dir.x * speed
    velocity.z = move_dir.z * speed
```

- [ ] **Step 2: Build player.tscn in the editor**

Open Godot, create a new scene with root `CharacterBody3D` named `Player`. Attach `scenes/player/player.gd` to it. Add children:

```
Player (CharacterBody3D, scripted with player.gd)
├── CollisionShape3D
│     - Shape: new CapsuleShape3D, height 1.8, radius 0.4
│     - Position y: 0.9
├── MeshInstance3D
│     - Mesh: new CapsuleMesh (placeholder until we import a model in Task 12)
│     - Position y: 0.9
├── CameraPivot (Node3D)
│     - Position y: 1.6  (eye height)
│     - SpringArm3D
│           - Spring length: 3.0
│           - Camera3D (current)
└── BowMount (Node3D)
      - Position: (0.3, 1.4, -0.4)
```

Save as `scenes/player/player.tscn`.

- [ ] **Step 3: Create a verification scene**

Create `tests/verification/player_movement_test.tscn` in the editor: root `Node3D` named `Test`, children:

```
Test (Node3D)
├── DirectionalLight3D                  # default values
├── StaticBody3D (a floor)
│   ├── CollisionShape3D (BoxShape3D 100×0.2×100, position y -0.1)
│   └── MeshInstance3D (PlaneMesh 100×100, with a default StandardMaterial3D, gray)
└── Player (instance of scenes/player/player.tscn)
```

Save it.

- [ ] **Step 4: Verify player movement by hand**

Open `tests/verification/player_movement_test.tscn` and press F6 to run it.

Verify in the running window:
- Mouse captured; moving the mouse rotates the view.
- WASD moves the capsule across the floor.
- Holding Ctrl slows it noticeably.
- Space causes a small jump.
- Escape releases the mouse.

If any of these fail, recheck input map entries (Task 1) and player.gd logic.

- [ ] **Step 5: Commit**

```bash
git add scenes/player/ tests/verification/player_movement_test.tscn
git commit -m "feat: third-person player controller with walk/sneak/jump"
```

---

## Task 5: Bow input — track draw/release state

**Files:**
- Modify: `scenes/player/player.gd`
- Create: `tests/unit/test_player_bow.gd`

This task adds bow charge tracking only — actual arrow spawning happens in Task 6.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_player_bow.gd`:

```gdscript
extends GutTest

func test_charge_starts_zero() -> void:
    var p := preload("res://scenes/player/player.gd").new()
    assert_eq(p.bow_charge, 0.0)
    p.free()

func test_charge_increases_while_drawing() -> void:
    var p := preload("res://scenes/player/player.gd").new()
    p.is_drawing_bow = true
    p.tick_bow(0.5)  # half a second of draw
    assert_almost_eq(p.bow_charge, 0.5, 0.001)
    p.free()

func test_charge_clamped_at_one() -> void:
    var p := preload("res://scenes/player/player.gd").new()
    p.is_drawing_bow = true
    p.tick_bow(5.0)
    assert_eq(p.bow_charge, 1.0)
    p.free()

func test_release_returns_charge_and_resets() -> void:
    var p := preload("res://scenes/player/player.gd").new()
    p.is_drawing_bow = true
    p.tick_bow(0.5)
    var released := p.release_bow()
    assert_almost_eq(released, 0.5, 0.001)
    assert_eq(p.bow_charge, 0.0)
    assert_false(p.is_drawing_bow)
    p.free()
```

- [ ] **Step 2: Run it; expect failure**

GUT panel → Run All.
Expected: 4 failures referencing `bow_charge`, `tick_bow`, `release_bow` not existing.

- [ ] **Step 3: Add bow state to player.gd**

Edit `scenes/player/player.gd`. Add these declarations near the top (under `var stance`):

```gdscript
var is_drawing_bow: bool = false
var bow_charge: float = 0.0  # 0.0..1.0
```

Add these methods at the bottom of the file:

```gdscript
## Advance bow charge for one tick. Pure logic, no node calls — testable.
func tick_bow(delta: float) -> void:
    if is_drawing_bow:
        bow_charge = clamp(bow_charge + delta / Config.BOW_CHARGE_TIME, 0.0, 1.0)

## Release the bow. Returns the charge level [0..1] and resets state.
func release_bow() -> float:
    var charge := bow_charge
    bow_charge = 0.0
    is_drawing_bow = false
    return charge
```

Wire input in `_unhandled_input` — add at the bottom of that function:

```gdscript
    if event.is_action_pressed("fire"):
        is_drawing_bow = true
    elif event.is_action_released("fire"):
        var charge := release_bow()
        _fire_arrow(charge)  # implemented in Task 6 — for now just stub it

```

And add a stub at the bottom of the file:

```gdscript
func _fire_arrow(_charge: float) -> void:
    pass  # filled in Task 6
```

Finally, call `tick_bow(delta)` from `_physics_process` — add at the top of `_physics_process` (after the function signature):

```gdscript
    tick_bow(delta)
```

- [ ] **Step 4: Run tests; expect pass**

GUT → Run All.
Expected: all 10 tests (6 from GameState + 4 from bow) pass.

- [ ] **Step 5: Commit**

```bash
git add scenes/player/player.gd tests/unit/test_player_bow.gd
git commit -m "feat: track bow draw/release charge with unit tests"
```

---

## Task 6: Arrow scene + firing

**Files:**
- Create: `scenes/projectiles/arrow.tscn`
- Create: `scenes/projectiles/arrow.gd`
- Modify: `scenes/player/player.gd` — flesh out `_fire_arrow`

- [ ] **Step 1: Write arrow.gd**

Create `scenes/projectiles/arrow.gd`:

```gdscript
extends RigidBody3D
class_name Arrow

const LIFETIME_SECONDS := 3.0

var damage: float = Config.ARROW_DAMAGE
var _age: float = 0.0

@onready var hit_area: Area3D = $HitArea

func _ready() -> void:
    hit_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    _age += delta
    if _age >= LIFETIME_SECONDS:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body.has_method("take_damage"):
        body.take_damage(damage)
    queue_free()
```

- [ ] **Step 2: Build arrow.tscn in the editor**

Create new scene with root `RigidBody3D` named `Arrow`. Attach `arrow.gd`. Configure root:
- Gravity Scale: 0.3 (mild arc)
- Continuous CD: enabled (avoids tunneling through deer)

Children:
```
Arrow (RigidBody3D)
├── CollisionShape3D
│     - Shape: BoxShape3D, size (0.05, 0.05, 0.6)
├── MeshInstance3D
│     - Mesh: BoxMesh, size (0.05, 0.05, 0.6)
│     - Material: StandardMaterial3D, brown
└── HitArea (Area3D)
      └── CollisionShape3D
            - Shape: BoxShape3D, size (0.06, 0.06, 0.7)
```

Save as `scenes/projectiles/arrow.tscn`.

- [ ] **Step 3: Wire firing in player.gd**

Replace the stub `_fire_arrow` from Task 5 with:

```gdscript
const ArrowScene := preload("res://scenes/projectiles/arrow.tscn")

func _fire_arrow(charge: float) -> void:
    if GameState.arrows <= 0:
        return
    GameState.arrows -= 1
    var arrow: Arrow = ArrowScene.instantiate()
    get_tree().current_scene.add_child(arrow)
    var bow_mount: Node3D = $BowMount
    arrow.global_transform.origin = bow_mount.global_transform.origin
    # Aim along camera forward
    var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
    var direction: Vector3 = -camera.global_transform.basis.z
    arrow.look_at(arrow.global_transform.origin + direction, Vector3.UP)
    var speed: float = lerp(Config.ARROW_SPEED_MIN, Config.ARROW_SPEED_MAX, charge)
    arrow.linear_velocity = direction * speed
    EventBus.player_shot_arrow.emit(arrow.global_transform.origin, direction)
```

(Note: the `const ArrowScene := preload(...)` line goes at the top of the script, just after `class_name Player`.)

- [ ] **Step 4: Add a target dummy to player_movement_test.tscn**

In the editor, open `tests/verification/player_movement_test.tscn` and add:

```
StaticBody3D ("TargetDummy")
├── CollisionShape3D (BoxShape3D 1×2×1, position y 1)
├── MeshInstance3D (BoxMesh 1×2×1, red)
- Position: (0, 1, -8)
```

Attach a one-off script directly via the inspector with this content (right-click TargetDummy → Attach Script, save as `tests/verification/dummy.gd`):

```gdscript
extends StaticBody3D
func take_damage(amount: float) -> void:
    print("Dummy took ", amount, " damage")
    queue_free()
```

- [ ] **Step 5: Verify by hand**

Open the verification scene, press F6. Aim and hold LMB to charge the bow, release to fire.

Verify:
- Arrow spawns at the bow mount and flies forward.
- Arrow falls slightly under gravity.
- Arrow hitting the red dummy prints `"Dummy took 50 damage"` and despawns both.
- Out-of-arrows (`GameState.arrows == 0`) prevents further firing.
- A miss arrow despawns after 3 seconds.

- [ ] **Step 6: Commit**

```bash
git add scenes/projectiles/ scenes/player/player.gd tests/verification/dummy.gd tests/verification/player_movement_test.tscn
git commit -m "feat: arrow projectile with bow charge-based velocity"
```

---

## Task 7: Animal FSM base classes (no animals yet)

**Files:**
- Create: `ai/animal_state.gd`
- Create: `ai/state_idle.gd`
- Create: `ai/state_wander.gd`
- Create: `tests/unit/test_fsm.gd`

This task builds the state machine in isolation. The actual deer/wolf nodes consume it in Tasks 8 and 9.

- [ ] **Step 1: Write the base state class**

Create `ai/animal_state.gd`:

```gdscript
class_name AnimalState
extends RefCounted

## Abstract base for FSM states. Each concrete state implements process()
## and may return a different state name to request a transition.

## Override. Called every physics frame by the animal.
## Return:
##   "" to stay in the current state
##   "<state_name>" to request a transition (handled by the animal)
func process(_animal: Node3D, _delta: float) -> String:
    return ""

## Override. Called once when the state becomes active.
func enter(_animal: Node3D) -> void:
    pass

## Override. Called once when the state is being left.
func exit(_animal: Node3D) -> void:
    pass
```

- [ ] **Step 2: Write Idle and Wander**

Create `ai/state_idle.gd`:

```gdscript
class_name StateIdle
extends AnimalState

var _timer: float = 0.0
var _idle_duration: float = 0.0

func enter(_animal: Node3D) -> void:
    _timer = 0.0
    _idle_duration = randf_range(3.0, 6.0)

func process(animal: Node3D, delta: float) -> String:
    _timer += delta
    animal.velocity.x = 0
    animal.velocity.z = 0
    if _timer >= _idle_duration:
        return "wander"
    if animal.has_method("sees_threat") and animal.sees_threat():
        return animal.threat_response_state()
    return ""
```

Create `ai/state_wander.gd`:

```gdscript
class_name StateWander
extends AnimalState

var _target: Vector3
var _timer: float = 0.0

func enter(animal: Node3D) -> void:
    _timer = 0.0
    _pick_new_target(animal)

func _pick_new_target(animal: Node3D) -> void:
    var offset := Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
    _target = animal.global_transform.origin + offset

func process(animal: Node3D, delta: float) -> String:
    _timer += delta
    var to_target: Vector3 = _target - animal.global_transform.origin
    to_target.y = 0
    if to_target.length() < 0.5 or _timer > 10.0:
        return "idle"
    var direction: Vector3 = to_target.normalized()
    var speed: float = animal.wander_speed
    animal.velocity.x = direction.x * speed
    animal.velocity.z = direction.z * speed
    animal.look_at(animal.global_transform.origin + direction, Vector3.UP)
    if animal.has_method("sees_threat") and animal.sees_threat():
        return animal.threat_response_state()
    return ""
```

- [ ] **Step 3: Write FSM tests**

Create `tests/unit/test_fsm.gd`:

```gdscript
extends GutTest

class FakeAnimal:
    var velocity: Vector3 = Vector3.ZERO
    var global_transform: Transform3D = Transform3D.IDENTITY
    var wander_speed: float = 2.0
    var threat: bool = false
    func sees_threat() -> bool: return threat
    func threat_response_state() -> String: return "flee"
    func look_at(_a: Vector3, _b: Vector3) -> void: pass

func test_idle_zeroes_velocity() -> void:
    var s := StateIdle.new()
    var a := FakeAnimal.new()
    a.velocity = Vector3(5, 0, 5)
    s.enter(a)
    s.process(a, 0.01)
    assert_eq(a.velocity.x, 0.0)
    assert_eq(a.velocity.z, 0.0)

func test_idle_transitions_to_wander_after_timeout() -> void:
    var s := StateIdle.new()
    var a := FakeAnimal.new()
    s.enter(a)
    # Force the longest possible idle time, then exceed it.
    var result := ""
    for i in 700:  # 7 seconds worth of 10ms ticks
        result = s.process(a, 0.01)
        if result != "":
            break
    assert_eq(result, "wander")

func test_idle_breaks_to_threat_response_when_threat_seen() -> void:
    var s := StateIdle.new()
    var a := FakeAnimal.new()
    a.threat = true
    s.enter(a)
    assert_eq(s.process(a, 0.01), "flee")

func test_wander_transitions_to_idle_on_arrival() -> void:
    var s := StateWander.new()
    var a := FakeAnimal.new()
    s.enter(a)
    # Force target to current position so we "arrive" instantly.
    s._target = a.global_transform.origin
    assert_eq(s.process(a, 0.01), "idle")
```

- [ ] **Step 4: Run tests; expect pass**

GUT → Run All.
Expected: 14 tests pass (6 GameState + 4 bow + 4 FSM).

- [ ] **Step 5: Commit**

```bash
git add ai/ tests/unit/test_fsm.gd
git commit -m "feat: FSM base + Idle/Wander states with unit tests"
```

---

## Task 8: Deer — perception, Alert/Flee states, take_damage

**Files:**
- Create: `ai/state_alert.gd`
- Create: `ai/state_flee.gd`
- Create: `scenes/animals/deer.gd`
- Create: `scenes/animals/deer.tscn`
- Create: `tests/unit/test_perception.gd`
- Create: `tests/verification/deer_perception_test.tscn`

- [ ] **Step 1: Write perception unit tests first**

Create `tests/unit/test_perception.gd`:

```gdscript
extends GutTest

const Perception := preload("res://scenes/animals/deer.gd")

func test_player_inside_view_cone_is_seen() -> void:
    var deer_pos := Vector3.ZERO
    var deer_forward := Vector3.FORWARD  # 0, 0, -1
    var player_pos := Vector3(0, 0, -5)  # 5m in front
    assert_true(Perception.in_view_cone(deer_pos, deer_forward, player_pos,
        Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG))

func test_player_outside_range_not_seen() -> void:
    var deer_pos := Vector3.ZERO
    var deer_forward := Vector3.FORWARD
    var player_pos := Vector3(0, 0, -50)
    assert_false(Perception.in_view_cone(deer_pos, deer_forward, player_pos,
        Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG))

func test_player_behind_not_seen() -> void:
    var deer_pos := Vector3.ZERO
    var deer_forward := Vector3.FORWARD
    var player_pos := Vector3(0, 0, 5)
    assert_false(Perception.in_view_cone(deer_pos, deer_forward, player_pos,
        Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG))

func test_player_within_hearing_with_loud_noise_heard() -> void:
    var deer_pos := Vector3.ZERO
    var player_pos := Vector3(5, 0, 0)
    var player_noise: float = Config.NOISE_WALK  # 6m, > 5m distance
    assert_true(Perception.heard(deer_pos, player_pos, player_noise,
        Config.DEER_HEARING_RANGE))

func test_sneaking_player_at_3m_not_heard() -> void:
    var deer_pos := Vector3.ZERO
    var player_pos := Vector3(3, 0, 0)
    var player_noise: float = Config.NOISE_SNEAK  # 1m < 3m distance
    assert_false(Perception.heard(deer_pos, player_pos, player_noise,
        Config.DEER_HEARING_RANGE))
```

- [ ] **Step 2: Run tests; expect failure**

GUT → Run All.
Expected: failures saying `Perception.in_view_cone` not found.

- [ ] **Step 3: Implement deer.gd with static perception helpers**

Create `scenes/animals/deer.gd`:

```gdscript
extends CharacterBody3D
class_name Deer

const STATES := {
    "idle":   preload("res://ai/state_idle.gd"),
    "wander": preload("res://ai/state_wander.gd"),
    "alert":  preload("res://ai/state_alert.gd"),
    "flee":   preload("res://ai/state_flee.gd"),
}

@export var max_hp: float = Config.DEER_HP
@export var wander_speed: float = Config.DEER_WANDER_SPEED

var hp: float
var current_state: AnimalState
var current_state_name: String = ""

func _ready() -> void:
    hp = max_hp
    _transition("idle")

func _physics_process(delta: float) -> void:
    if current_state == null:
        return
    _apply_gravity(delta)
    var next := current_state.process(self, delta)
    move_and_slide()
    if next != "" and next != current_state_name:
        _transition(next)

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= Config.PLAYER_GRAVITY * delta
    else:
        velocity.y = max(velocity.y, 0)

func _transition(state_name: String) -> void:
    if current_state:
        current_state.exit(self)
    current_state_name = state_name
    current_state = STATES[state_name].new()
    current_state.enter(self)

func take_damage(amount: float) -> void:
    hp -= amount
    if hp <= 0:
        EventBus.animal_killed.emit("deer", global_transform.origin)
        queue_free()

func sees_threat() -> bool:
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return false
    var forward: Vector3 = -global_transform.basis.z
    var seen := Deer.in_view_cone(global_transform.origin, forward,
        player.global_transform.origin,
        Config.DEER_VIEW_RANGE, Config.DEER_VIEW_CONE_DEG)
    var heard := Deer.heard(global_transform.origin,
        player.global_transform.origin,
        player.noise_radius(), Config.DEER_HEARING_RANGE)
    return seen or heard

func threat_response_state() -> String:
    return "alert"

# --- static perception helpers (testable without nodes) ---

static func in_view_cone(observer_pos: Vector3, observer_forward: Vector3,
        target_pos: Vector3, max_range: float, cone_deg: float) -> bool:
    var to_target: Vector3 = target_pos - observer_pos
    to_target.y = 0
    var dist := to_target.length()
    if dist > max_range or dist < 0.001:
        return false
    var fwd := observer_forward
    fwd.y = 0
    fwd = fwd.normalized()
    var angle := rad_to_deg(fwd.angle_to(to_target.normalized()))
    return angle <= cone_deg * 0.5

static func heard(observer_pos: Vector3, target_pos: Vector3,
        target_noise_radius: float, observer_hearing_range: float) -> bool:
    var dist := observer_pos.distance_to(target_pos)
    if dist > observer_hearing_range:
        return false
    return target_noise_radius >= dist
```

- [ ] **Step 4: Write Alert and Flee states**

Create `ai/state_alert.gd`:

```gdscript
class_name StateAlert
extends AnimalState

var _timer: float = 0.0
const ALERT_HOLD := 2.0

func enter(_animal: Node3D) -> void:
    _timer = 0.0

func process(animal: Node3D, delta: float) -> String:
    _timer += delta
    animal.velocity.x = 0
    animal.velocity.z = 0
    if _timer >= ALERT_HOLD:
        if animal.sees_threat():
            return "flee"
        return "idle"
    return ""
```

Create `ai/state_flee.gd`:

```gdscript
class_name StateFlee
extends AnimalState

var _timer: float = 0.0
const FLEE_DURATION := 15.0

func enter(_animal: Node3D) -> void:
    _timer = 0.0

func process(animal: Node3D, delta: float) -> String:
    _timer += delta
    if _timer >= FLEE_DURATION:
        return "wander"
    var player := animal.get_tree().get_first_node_in_group("player")
    if player == null:
        return "wander"
    var away: Vector3 = animal.global_transform.origin - player.global_transform.origin
    away.y = 0
    away = away.normalized()
    var speed: float = Config.DEER_FLEE_SPEED
    animal.velocity.x = away.x * speed
    animal.velocity.z = away.z * speed
    animal.look_at(animal.global_transform.origin + away, Vector3.UP)
    return ""
```

- [ ] **Step 5: Build deer.tscn in the editor**

Create new scene with root `CharacterBody3D` named `Deer`. Attach `deer.gd`. Children:

```
Deer (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D, height 1.2, radius 0.35, position y 0.6)
└── MeshInstance3D (CapsuleMesh, brown StandardMaterial3D)
```

Save as `scenes/animals/deer.tscn`.

- [ ] **Step 6: Player needs to be in the "player" group**

Open `scenes/player/player.tscn`. Select the root `Player` node → Node tab (right side, next to Inspector) → Groups → add `player`.

Save the scene.

- [ ] **Step 7: Create deer verification scene**

Create `tests/verification/deer_perception_test.tscn`: root `Node3D`, children:
- DirectionalLight3D
- Floor (StaticBody3D with BoxShape collision + PlaneMesh)
- Player instance at (0,1,0)
- 3 Deer instances at (5,0,-10), (-5,0,-10), (8,0,-15)

- [ ] **Step 8: Run unit tests; expect pass**

GUT → Run All. Expected: 19 tests pass (15 prior + 4 new perception, plus the deer state ones are exercised indirectly — we count just the explicitly written tests).

Actually verify by reading the GUT panel: at minimum the new `test_perception.gd` tests pass.

- [ ] **Step 9: Hand-verify deer behavior**

Open `tests/verification/deer_perception_test.tscn`, press F6.

Verify:
- Deer wander idly when player is far / behind them.
- Walking toward a deer's front causes it to pause (Alert), then flee.
- Sneaking (Ctrl) lets you get within ~3m without alerting if you stay behind/beside it.
- Shooting a deer kills it (HP 40, arrow does 50).

- [ ] **Step 10: Commit**

```bash
git add ai/state_alert.gd ai/state_flee.gd scenes/animals/deer.gd scenes/animals/deer.tscn scenes/player/player.tscn tests/unit/test_perception.gd tests/verification/deer_perception_test.tscn
git commit -m "feat: deer with view-cone+hearing perception, Alert/Flee FSM"
```

---

## Task 9: Wolf — Chase/Attack/Retreat, damages player

**Files:**
- Create: `ai/state_chase.gd`
- Create: `ai/state_attack.gd`
- Create: `ai/state_retreat.gd`
- Create: `scenes/animals/wolf.gd`
- Create: `scenes/animals/wolf.tscn`
- Modify: `scenes/player/player.gd` — add `take_damage`
- Create: `tests/verification/wolf_combat_test.tscn`

- [ ] **Step 1: Add take_damage to player**

Append to `scenes/player/player.gd`:

```gdscript
func take_damage(amount: float) -> void:
    GameState.hp -= amount
    EventBus.player_hit_by.emit(amount, self)
    if GameState.hp <= 0:
        _die()

func _die() -> void:
    # Milestone 1: reload scene on death.
    GameState.reset()
    get_tree().reload_current_scene()
```

- [ ] **Step 2: Write wolf states**

Create `ai/state_chase.gd`:

```gdscript
class_name StateChase
extends AnimalState

func process(animal: Node3D, _delta: float) -> String:
    var player := animal.get_tree().get_first_node_in_group("player")
    if player == null:
        return "wander"
    var to_player: Vector3 = player.global_transform.origin - animal.global_transform.origin
    to_player.y = 0
    var dist := to_player.length()
    if dist <= Config.WOLF_ATTACK_RANGE:
        return "attack"
    if dist > Config.WOLF_AGGRO_RANGE * 1.5:
        return "wander"  # lost interest
    if animal.hp < animal.max_hp * Config.WOLF_RETREAT_HP_FRACTION:
        return "retreat"
    var dir: Vector3 = to_player.normalized()
    animal.velocity.x = dir.x * Config.WOLF_CHASE_SPEED
    animal.velocity.z = dir.z * Config.WOLF_CHASE_SPEED
    animal.look_at(animal.global_transform.origin + dir, Vector3.UP)
    return ""
```

Create `ai/state_attack.gd`:

```gdscript
class_name StateAttack
extends AnimalState

var _cooldown: float = 0.0
const ATTACK_INTERVAL := 1.2

func enter(_animal: Node3D) -> void:
    _cooldown = 0.0

func process(animal: Node3D, delta: float) -> String:
    animal.velocity.x = 0
    animal.velocity.z = 0
    var player := animal.get_tree().get_first_node_in_group("player")
    if player == null:
        return "wander"
    var dist: float = animal.global_transform.origin.distance_to(player.global_transform.origin)
    if dist > Config.WOLF_ATTACK_RANGE * 1.2:
        return "chase"
    _cooldown -= delta
    if _cooldown <= 0:
        if player.has_method("take_damage"):
            player.take_damage(Config.WOLF_ATTACK_DAMAGE)
        _cooldown = ATTACK_INTERVAL
    if animal.hp < animal.max_hp * Config.WOLF_RETREAT_HP_FRACTION:
        return "retreat"
    return ""
```

Create `ai/state_retreat.gd`:

```gdscript
class_name StateRetreat
extends AnimalState

var _timer: float = 0.0
const RETREAT_DURATION := 10.0

func process(animal: Node3D, delta: float) -> String:
    _timer += delta
    if _timer >= RETREAT_DURATION:
        return "wander"
    var player := animal.get_tree().get_first_node_in_group("player")
    if player == null:
        return "wander"
    var away: Vector3 = animal.global_transform.origin - player.global_transform.origin
    away.y = 0
    away = away.normalized()
    animal.velocity.x = away.x * Config.WOLF_CHASE_SPEED
    animal.velocity.z = away.z * Config.WOLF_CHASE_SPEED
    animal.look_at(animal.global_transform.origin + away, Vector3.UP)
    return ""
```

- [ ] **Step 3: Write wolf.gd**

Create `scenes/animals/wolf.gd`:

```gdscript
extends CharacterBody3D
class_name Wolf

const STATES := {
    "idle":    preload("res://ai/state_idle.gd"),
    "wander":  preload("res://ai/state_wander.gd"),
    "chase":   preload("res://ai/state_chase.gd"),
    "attack":  preload("res://ai/state_attack.gd"),
    "retreat": preload("res://ai/state_retreat.gd"),
}

@export var max_hp: float = Config.WOLF_HP
@export var wander_speed: float = Config.WOLF_WANDER_SPEED

var hp: float
var current_state: AnimalState
var current_state_name: String = ""

func _ready() -> void:
    hp = max_hp
    _transition("idle")

func _physics_process(delta: float) -> void:
    if current_state == null:
        return
    _apply_gravity(delta)
    var next := current_state.process(self, delta)
    move_and_slide()
    if next != "" and next != current_state_name:
        _transition(next)

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= Config.PLAYER_GRAVITY * delta
    else:
        velocity.y = max(velocity.y, 0)

func _transition(state_name: String) -> void:
    if current_state:
        current_state.exit(self)
    current_state_name = state_name
    current_state = STATES[state_name].new()
    current_state.enter(self)

func take_damage(amount: float) -> void:
    hp -= amount
    if hp <= 0:
        EventBus.animal_killed.emit("wolf", global_transform.origin)
        queue_free()

func sees_threat() -> bool:
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return false
    var dist: float = global_transform.origin.distance_to(player.global_transform.origin)
    return dist <= Config.WOLF_AGGRO_RANGE

func threat_response_state() -> String:
    return "chase"
```

- [ ] **Step 4: Build wolf.tscn**

Create new scene with root `CharacterBody3D` named `Wolf`. Attach `wolf.gd`. Children:

```
Wolf (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D, height 0.8, radius 0.3, rotation x 90°, position y 0.4)
└── MeshInstance3D (CapsuleMesh, dark gray StandardMaterial3D, rotation x 90°)
```

Save as `scenes/animals/wolf.tscn`.

- [ ] **Step 5: Create wolf verification scene**

Create `tests/verification/wolf_combat_test.tscn`: root `Node3D`, children:
- DirectionalLight3D
- Floor (StaticBody3D)
- Player instance at (0, 1, 0)
- 2 Wolf instances at (10, 0, -10) and (-10, 0, -10)

- [ ] **Step 6: Hand-verify wolf combat**

Open `tests/verification/wolf_combat_test.tscn`, press F6.

Verify:
- Wolves wander until you walk within 12m.
- Wolves chase you when in aggro range.
- When a wolf reaches you, it stops and attacks every ~1.2s, draining HP.
- HP bar (we don't have one yet — check the console via `print(GameState.hp)` if needed, OR proceed to Task 10 and re-verify).
- Hitting a wolf with 2 arrows (50 dmg × 2 = 100 > 60) kills it.
- After taking 4 hits (20 × 4 = 80), HP < 30% of 100 → not relevant for player; relevant for wolf: shoot a wolf once (50 dmg → 10 HP left → < 30% × 60 = 18, so HP 10 < 18) → wolf flees instead of attacking again.

Note: at this point a wolf killing the player reloads the scene — that's expected.

- [ ] **Step 7: Commit**

```bash
git add ai/state_chase.gd ai/state_attack.gd ai/state_retreat.gd scenes/animals/wolf.gd scenes/animals/wolf.tscn scenes/player/player.gd tests/verification/wolf_combat_test.tscn
git commit -m "feat: wolf with chase/attack/retreat FSM, deals damage to player"
```

---

## Task 10: HUD — HP, arrows, kill counter

**Files:**
- Create: `ui/hud.tscn`
- Create: `ui/hud.gd`

- [ ] **Step 1: Write hud.gd**

Create `ui/hud.gd`:

```gdscript
extends CanvasLayer
class_name HUD

@onready var hp_bar: ProgressBar = $Root/HPBar
@onready var hp_label: Label = $Root/HPBar/HPLabel
@onready var arrows_label: Label = $Root/ArrowsLabel
@onready var kills_label: Label = $Root/KillsLabel
@onready var crosshair: Control = $Root/Crosshair

var kills: int = 0

func _ready() -> void:
    GameState.hp_changed.connect(_on_hp_changed)
    GameState.arrows_changed.connect(_on_arrows_changed)
    EventBus.animal_killed.connect(_on_animal_killed)
    crosshair.visible = false
    _refresh()

func _process(_delta: float) -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("noise_radius"):
        crosshair.visible = player.is_drawing_bow

func _refresh() -> void:
    _on_hp_changed(GameState.hp)
    _on_arrows_changed(GameState.arrows)

func _on_hp_changed(new_hp: float) -> void:
    hp_bar.max_value = GameState.HP_MAX
    hp_bar.value = new_hp
    hp_label.text = "HP %d / %d" % [int(new_hp), int(GameState.HP_MAX)]

func _on_arrows_changed(new_count: int) -> void:
    arrows_label.text = "Arrows: %d" % new_count

func _on_animal_killed(_type: String, _pos: Vector3) -> void:
    kills += 1
    kills_label.text = "Kills: %d" % kills
```

- [ ] **Step 2: Build hud.tscn in the editor**

Create new scene with root `CanvasLayer` named `HUD`. Attach `hud.gd`. Add a child `Control` named `Root` with full-rect anchor preset.

Inside Root:
- `HPBar` (ProgressBar): anchor bottom-left, offset 20px from edges; size 200×24; min_value=0, max_value=100, value=100; modulate red.
  - Child `HPLabel` (Label): "HP 100 / 100", centered over the bar.
- `ArrowsLabel` (Label): anchor bottom-right, offset 20px from edges; text "Arrows: 10"; font size 24.
- `KillsLabel` (Label): anchor top-left, offset 20px; text "Kills: 0"; font size 24.
- `Crosshair` (Control with a centered ColorRect 6×6 white): anchored center; size 6×6.

Save as `ui/hud.tscn`.

- [ ] **Step 3: Add HUD to verification scenes**

Open each of:
- `tests/verification/player_movement_test.tscn`
- `tests/verification/deer_perception_test.tscn`
- `tests/verification/wolf_combat_test.tscn`

For each: drag `ui/hud.tscn` into the scene as a top-level child of `Test`. Save.

- [ ] **Step 4: Hand-verify HUD**

Run `tests/verification/wolf_combat_test.tscn`. Verify:
- HP bar shows 100/100 at start.
- Taking damage from a wolf decreases the bar; label updates.
- Firing arrows decrements "Arrows: N".
- Killing a deer or wolf increments "Kills: N".
- Crosshair appears only while holding LMB.

- [ ] **Step 5: Commit**

```bash
git add ui/ tests/verification/
git commit -m "feat: HUD with HP, arrows, kill counter, charge crosshair"
```

---

## Task 11: Forest map — terrain, scatter, navmesh, animal spawns

**Files:**
- Create: `scenes/world/forest_map.tscn`
- Create: `scenes/world/forest_map.gd`

- [ ] **Step 1: Write forest_map.gd**

Create `scenes/world/forest_map.gd`:

```gdscript
extends Node3D

const DeerScene := preload("res://scenes/animals/deer.tscn")
const WolfScene := preload("res://scenes/animals/wolf.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")

@export var deer_count: int = 4
@export var wolf_count: int = 2

func _ready() -> void:
    _spawn_player()
    _spawn_animals()

func _spawn_player() -> void:
    var p := PlayerScene.instantiate()
    p.global_transform.origin = Vector3(0, 1, 0)
    add_child(p)

func _spawn_animals() -> void:
    for i in deer_count:
        var d := DeerScene.instantiate()
        d.global_transform.origin = _random_ground_position()
        add_child(d)
    for i in wolf_count:
        var w := WolfScene.instantiate()
        w.global_transform.origin = _random_ground_position()
        add_child(w)

func _random_ground_position() -> Vector3:
    return Vector3(randf_range(-40, 40), 0.5, randf_range(-40, 40))
```

- [ ] **Step 2: Build forest_map.tscn**

Create new scene with root `Node3D` named `ForestMap`. Attach `forest_map.gd`. Children:

```
ForestMap (Node3D, scripted)
├── WorldEnvironment
│   └── Environment: new Environment with sky enabled, background = sky,
│                    procedural sky (default Godot 4 sky shader)
├── DirectionalLight3D (rotation -45°, shadows on)
├── Ground (StaticBody3D)
│   ├── CollisionShape3D (BoxShape3D size 100×0.4×100, position y -0.2)
│   └── MeshInstance3D (PlaneMesh size 100×100, green StandardMaterial3D)
├── Boundary (Node3D)
│   ├── WallN (StaticBody3D + BoxShape3D 100×4×1 + MeshInstance3D), position (0, 2, -50)
│   ├── WallS, position (0, 2, 50)
│   ├── WallE, position (50, 2, 0), rotation y 90°
│   └── WallW, position (-50, 2, 0), rotation y 90°
│   (Hide their MeshInstance3D visibility — boundary is invisible)
├── Trees (Node3D)
│   - In the editor, manually drop 30-50 simple tree placeholders made of:
│     CSGCylinder3D (trunk, brown, radius 0.3, height 2)
│     + CSGSphere3D (foliage, green, radius 1.5, position y 2.5)
│   - Scatter them across ±40 m. (Real Quaternius models come in Task 12.)
├── NavRegion (NavigationRegion3D)
│   - Add a NavigationMesh resource (default settings).
│   - In the editor toolbar, with NavRegion selected, click "Bake NavigationMesh"
│     after placing your geometry.
└── HUD (instance of ui/hud.tscn — drag from FileSystem)
```

Save as `scenes/world/forest_map.tscn`.

Verify `project.godot`'s `main_scene` is `res://scenes/world/forest_map.tscn` (we set this in Task 1).

- [ ] **Step 3: Hand-verify the forest map**

Press F5 (runs main scene). Verify:
- You spawn into the forest.
- You can see trees, sky, ground.
- 4 deer wander around; 2 wolves do too.
- Approaching deer/wolves triggers their respective FSMs.
- HUD is visible.

If HUD is missing, add an instance of `ui/hud.tscn` as a child of `ForestMap` in the editor.

- [ ] **Step 4: Commit**

```bash
git add scenes/world/
git commit -m "feat: forest map with scattered placeholder trees and animal spawns"
```

---

## Task 12: Import Quaternius assets

**Files:**
- Add: `assets/models/animals/deer.glb`, `wolf.glb`
- Add: `assets/models/characters/player.glb`
- Add: `assets/models/environment/tree*.glb`
- Modify: scene files to swap CapsuleMesh/CSG placeholders for imported meshes

- [ ] **Step 1: Download Quaternius packs**

Visit https://quaternius.com/. Recommended packs (all free, CC0):
- "Animated Animal Pack" (deer, wolf models — note license)
- "Stylized Character Pack" (player)
- "Stylized Nature MegaKit" (trees, rocks, bushes)

Download the `.glb` files and place under:
- `assets/models/animals/deer.glb`, `wolf.glb`
- `assets/models/characters/player.glb`
- `assets/models/environment/tree_01.glb`, `tree_02.glb`, etc.

(If Quaternius packs are tarballed, extract the relevant `.glb` files only — don't dump the whole archive into the repo.)

- [ ] **Step 2: Let Godot import them**

Open the project. Godot scans the `assets/` folder and creates `.import` metadata. Wait until the editor settles.

- [ ] **Step 3: Replace placeholder meshes**

For each scene that has a `CapsuleMesh` placeholder (player.tscn, deer.tscn, wolf.tscn):
1. Open the scene.
2. Drag the corresponding `.glb` from FileSystem (e.g., `assets/models/animals/deer.glb`) onto the root node — Godot will instance it as a child.
3. Delete the `MeshInstance3D` placeholder.
4. Adjust the new mesh's transform so the model fits the CollisionShape3D (scale uniformly, rotate as needed).

For trees in `forest_map.tscn`: select the `Trees` node, delete the CSG placeholders, and instantiate `tree_01.glb` etc. multiple times.

- [ ] **Step 4: Re-bake the navigation mesh**

In forest_map.tscn, select `NavRegion`, click "Bake NavigationMesh" again (geometry changed).

- [ ] **Step 5: Hand-verify visuals**

Press F5. Verify:
- Player looks like the imported character (even if T-posing for now).
- Deer/wolf models visible.
- Trees look stylized, not CSG primitives.
- Game still plays as before.

- [ ] **Step 6: Commit**

```bash
git add assets/ scenes/
git commit -m "feat: import Quaternius models for player, deer, wolf, trees"
```

---

## Task 13: Wire up animations (placeholder if models have them)

**Files:**
- Modify: `scenes/player/player.gd`, `scenes/animals/deer.gd`, `scenes/animals/wolf.gd`

This task is light because Quaternius models usually ship with an `AnimationPlayer` containing named clips. We just call the right one based on state. If your downloaded models lack animations, skip this task and proceed to Task 14 — animations are polish.

- [ ] **Step 1: Inspect what animations exist**

In the editor, open each imported `.glb` scene (double-click in FileSystem). Look for the `AnimationPlayer` node. Quaternius models typically include some subset of: `Idle`, `Idle_2`, `Walk`, `Run`, `Eating`, `Death`, `Attack`, `Jump`. Write down the exact names you see — you will reference them in Steps 2-4.

If a model has no AnimationPlayer at all, treat this entire task as skipped (move to Task 14). Static T-pose is acceptable for M1.

- [ ] **Step 2: Add a play_anim helper to deer.gd**

Append to `scenes/animals/deer.gd`:

```gdscript
@onready var anim_player: AnimationPlayer = _find_animation_player()

func _find_animation_player() -> AnimationPlayer:
    for child in get_children():
        if child is AnimationPlayer:
            return child
        for grandchild in child.get_children():
            if grandchild is AnimationPlayer:
                return grandchild
    return null

func play_anim(name: String) -> void:
    if anim_player and anim_player.has_animation(name):
        anim_player.play(name)
```

Then in `_transition`, after the state switch, add:

```gdscript
    match state_name:
        "idle": play_anim("Idle")
        "wander": play_anim("Walk")
        "alert": play_anim("Idle")
        "flee": play_anim("Run")
```

(Substitute the actual animation names you found in Step 1.)

- [ ] **Step 3: Same for wolf.gd**

Repeat for `scenes/animals/wolf.gd` with appropriate clip names (attack animation in `attack` state, etc.).

- [ ] **Step 4: Same for player.gd**

In `scenes/player/player.gd`, drive animations from `_physics_process`:

```gdscript
@onready var anim_player: AnimationPlayer = _find_animation_player()

func _find_animation_player() -> AnimationPlayer:
    for child in get_children():
        if child is AnimationPlayer:
            return child
        for grandchild in child.get_children():
            if grandchild is AnimationPlayer:
                return grandchild
    return null

func _update_anim() -> void:
    if anim_player == null:
        return
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    if horizontal_speed < 0.1:
        anim_player.play("Idle")
    elif stance == Stance.SNEAKING:
        anim_player.play("Sneak") if anim_player.has_animation("Sneak") else anim_player.play("Walk")
    else:
        anim_player.play("Walk")
```

Call `_update_anim()` at the end of `_physics_process`.

- [ ] **Step 5: Hand-verify**

Press F5. Verify:
- Player plays Walk/Idle clips when moving/standing.
- Deer plays Walk during Wander.
- Wolf plays Run during Chase.

- [ ] **Step 6: Commit**

```bash
git add scenes/
git commit -m "feat: drive AnimationPlayer clips from FSM and player state"
```

---

## Task 14: Polish pass — death animation delay, death VFX bare-minimum

**Files:**
- Modify: `scenes/animals/deer.gd`, `scenes/animals/wolf.gd`

- [ ] **Step 1: Delay deer despawn so the death animation can play**

In `scenes/animals/deer.gd`, replace `take_damage`:

```gdscript
func take_damage(amount: float) -> void:
    if hp <= 0:
        return  # already dying
    hp -= amount
    if hp <= 0:
        _die()

func _die() -> void:
    EventBus.animal_killed.emit("deer", global_transform.origin)
    set_physics_process(false)
    play_anim("Death")  # if available
    await get_tree().create_timer(2.0).timeout
    queue_free()
```

- [ ] **Step 2: Same for wolf.gd**

Mirror the change in `scenes/animals/wolf.gd`.

- [ ] **Step 3: Hand-verify**

Press F5. Shoot a deer; it should fall, hold for 2s, then disappear (rather than vanishing mid-strafe).

- [ ] **Step 4: Commit**

```bash
git add scenes/animals/
git commit -m "feat: delay animal despawn so death anim can finish"
```

---

## Task 15: Definition-of-Done verification

This task has no code. It's the gate that confirms M1 ships.

- [ ] **Step 1: Run all unit tests**

GUT panel → Run All. Expected: all tests pass.

CLI equivalent:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit
```

- [ ] **Step 2: Run DoD checklist by hand**

Open the main scene (F5) and verify each item:

1. [ ] WASD + mouse moves character through forest, third-person camera follows.
2. [ ] Crouch (Ctrl) enables sneaking; can approach deer to ~2-3m without alerting.
3. [ ] Bow fires arrows (LMB hold to charge, release to fire); kills deer in 1 hit.
4. [ ] Deer flee when they see or hear the player.
5. [ ] Wolves chase and damage the player when within aggro range.
6. [ ] HUD shows HP bar, arrow count, kill count.
7. [ ] Player death (HP → 0) reloads the scene with HP and arrows reset.

If any item fails, fix it inline and commit. Do NOT skip an item.

- [ ] **Step 3: Final commit (if no fixes needed, this step is a no-op)**

```bash
git status
# Expect "nothing to commit, working tree clean"
git log --oneline | head -20
# Skim: should see ~15 task commits + the initial spec commit
```

- [ ] **Step 4: Celebrate**

Milestone 1 is done. Time to play the game for fun, take notes on what feels off, and let those notes inform the Milestone 2 plan.

---

## What this plan does NOT cover

Per the spec's non-goals, the following are out of scope for Milestone 1 and will be addressed in a separate plan after M1 ships:

- Inventory, gathering, crafting, hunger/stamina (all Milestone 2).
- Multiple weapons.
- Day/night, weather, sound design.
- Save/load.
- Main menu, settings screen.
- Multiplayer.

If during implementation you find yourself wanting to add any of these "just real quick", **stop**. Add a TODO to a `M2-WISHLIST.md` and move on.
