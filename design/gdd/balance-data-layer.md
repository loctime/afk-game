# Balance Data Layer

> **Status**: In Design
> **Author**: User + game-designer + systems-designer
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Infrastructure — enables data-driven progression ("ver cómo tu personaje se vuelve más poderoso con el tiempo")

## Summary

Balance Data Layer es la capa de datos centralizada del juego: todas las estadísticas, curvas, probabilidades y valores configurables viven en archivos `.tres` (Godot Custom Resources) que los sistemas gameplay consumen en runtime. Permite ajustar balance sin tocar código y provee un esquema versionable del que 8+ sistemas dependen. Sin esta capa, cada sistema tendría sus propias magic numbers hardcodeados y cualquier cambio de balance requeriría recompilar.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None (all other gameplay systems depend on this)`

## Overview

El Balance Data Layer es un conjunto de **Godot Custom Resources** (`extends Resource`) que define toda la configuración numérica y estructural del juego en archivos `.tres` ubicados en `assets/data/`. El sistema define 5 familias principales de Resources:

- **EnemyDefinition** — los 50 enemigos del catálogo con HP, daño, comportamiento, drops, tamaño, nombre
- **ItemDefinition** — items por rareza + slot + rangos de stat rolls
- **SkillDefinition** — habilidades con tipo (ataque/curación/buff), mana cost, cooldown, scaling, efectos
- **WaveScalingCurve** — cómo HP y daño de enemigos escalan por número de oleada, cuántos enemigos spawnean, composición
- **CharacterProgressionCurve** — XP por nivel, HP/mana por stat point, efecto matemático de cada stat (STR/DEX/INT/VIT)

Estas Resources son **plantillas inmutables** en disco — los sistemas que necesitan estado per-instance (ej: un enemigo específico con HP actual) hacen `duplicate_deep()` al instanciar. Cualquier designer puede modificar valores en el editor de Godot sin tocar GDScript, y el sistema de versionado (git) provee histórico de cambios de balance. En runtime, un **`BalanceDatabase` autoload** ofrece lookup O(1) por ID (ej: `BalanceDatabase.get_enemy("slime_common")`) para los sistemas consumidores.

## Player Fantasy

**Players do not interact with the Balance Data Layer directly.** La experiencia que habilita es el **sentido de curva justa y progresiva**: que subir de nivel *se sienta* significativo, que un Boss de oleada 20 *se sienta* más amenazante que uno de oleada 10, que un ítem Legendary *se sienta* claramente mejor que uno Common. Esa sensación depende de curvas matemáticas bien calibradas viviendo fuera del código, iterables sin rebuild.

**El "player" real de esta capa es el diseñador de balance.** La fantasy para ese diseñador es: *"puedo abrir el editor, cambiar un número, jugar 30 segundos, y ver el efecto — sin tocar código, sin esperar builds, sin romper saves"*. La Balance Data Layer sirve al anchor del juego ("ver cómo tu personaje se vuelve más poderoso con el tiempo") siendo el lugar donde se calibra *qué tan rápido*, *qué tan satisfactorio*, *qué tan desafiante* se siente ese crecimiento.

## Detailed Design

### Core Rules

#### C.1.1 Resource families

The Balance Data Layer defines 5 Custom Resource types, each with `class_name` registered globally. All fields are statically typed. Every Resource inherits two system-required fields that designers must not rename or remove:

- `id: StringName` — unique within its family
- `schema_version: int` — must equal the family's `CURRENT_SCHEMA` code constant

**EnemyDefinition**

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | unique across EnemyDefinitions |
| `schema_version` | `int` | no | — |
| `display_name` | `String` | yes | localization key or literal |
| `base_hp` | `float` | yes | must be > 0 |
| `base_damage` | `float` | yes | must be > 0 |
| `behavior_tag` | `StringName` | yes | closed enum — see C.1.2 |
| `size_category` | `StringName` | yes | closed enum (`&"small"`, `&"medium"`, `&"large"`) |
| `sprite_path` | `String` | yes | path only; loading owned by Enemy System |
| `drop_table_id` | `StringName` | yes | foreign key → DropTableDefinition (future), `&""` = no drops |

**ItemDefinition**

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | — |
| `schema_version` | `int` | no | — |
| `display_name` | `String` | yes | — |
| `rarity` | `StringName` | yes | closed enum (`&"common"`, `&"rare"`, `&"epic"`, `&"legendary"`) |
| `slot` | `StringName` | yes | closed enum (`&"weapon"`, `&"armor"`, `&"accessory"`) |
| `stat_roll_ranges` | `Dictionary` | yes | `{ StringName: Vector2(min,max) }`; keys validated against closed stat set |
| `icon_path` | `String` | yes | — |

**SkillDefinition**

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | — |
| `schema_version` | `int` | no | — |
| `display_name` | `String` | yes | — |
| `skill_type` | `StringName` | yes | closed enum (`&"attack"`, `&"heal"`, `&"buff"`) |
| `mana_cost` | `float` | yes | ≥ 0 |
| `cooldown_sec` | `float` | yes | ≥ 0 |
| `scaling_stat` | `StringName` | yes | closed enum matching Character stats |
| `scaling_coefficient` | `float` | yes | multiplier on scaling_stat |
| `effect_tags` | `Array[StringName]` | yes | open set; Combat Engine interprets |
| `icon_path` | `String` | yes | — |

**WaveScalingCurve**

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | — |
| `schema_version` | `int` | no | — |
| `wave_entries` | `Array[Dictionary]` | yes | dense; index = wave number (0-based). Each: `{ hp_mult: float, dmg_mult: float, spawn_count: int, enemy_ids: Array[StringName] }` |
| `loop_after_wave` | `int` | yes | -1 = no loop; otherwise index at which entries restart |
| `loop_hp_scale` | `float` | yes | per-loop HP multiplier compounded |
| `loop_dmg_scale` | `float` | yes | per-loop damage multiplier compounded |

**CharacterProgressionCurve** (single global instance for MVP; multi-class deferred)

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | `&"default"` for MVP |
| `schema_version` | `int` | no | — |
| `xp_per_level` | `Array[float]` | yes | index 0 unused (= 0); length = `max_level + 1` |
| `max_level` | `int` | yes | must equal `xp_per_level.size() - 1` |
| `hp_per_vit` | `float` | yes | — |
| `mana_per_int` | `float` | yes | — |
| `atk_per_str` | `float` | yes | — |
| `speed_per_dex` | `float` | yes | — |
| `base_stats` | `Dictionary` | yes | `{ "str": int, "dex": int, "int": int, "vit": int }` at level 1 |
| `stat_points_per_level` | `int` | yes | — |

#### C.1.2 Closed enum sets

The following `StringName` fields are validated against code-defined constant sets. Adding a value is a one-line code edit, not a schema bump.

- `EnemyDefinition.behavior_tag` ∈ `{ &"melee", &"ranged", &"magic" }` — MVP placeholder; Combat Engine GDD is the authority on the final tag set
- `EnemyDefinition.size_category` ∈ `{ &"small", &"medium", &"large" }`
- `ItemDefinition.rarity` ∈ `{ &"common", &"rare", &"epic", &"legendary" }`
- `ItemDefinition.slot` ∈ `{ &"weapon", &"armor", &"accessory" }`
- `ItemDefinition.stat_roll_ranges` keys ∈ `{ &"atk", &"def", &"str", &"dex", &"int", &"vit" }`
- `SkillDefinition.skill_type` ∈ `{ &"attack", &"heal", &"buff" }`
- `SkillDefinition.scaling_stat` ∈ `{ &"str", &"dex", &"int", &"vit" }`

`SkillDefinition.effect_tags` is intentionally **open** — new tags added by Combat Engine need no Balance Data Layer change.

#### C.1.3 Manifest discovery

A single file, `res://assets/data/BalanceManifest.tres`, lists every Resource:

```gdscript
class_name BalanceManifest extends Resource
@export var paths: Array[String]
```

- Adding a Resource = appending its path. Load order follows array order but no dependency ordering is assumed.
- Missing file referenced in manifest → validation error (see C.1.6).
- File present but wrong Resource type → logged warning, skipped, boot continues.
- Exactly one manifest is supported. Loading additional manifests requires explicit approval.

#### C.1.4 BalanceDatabase API (autoload, sole entry point)

`BalanceDatabase` is an autoload registered **first** in Project Settings → Autoload. Consumers must call only this API — direct `ResourceLoader.load()` on data paths is forbidden (ResourceLoader caches by path; a single stray mutation corrupts every future consumer).

```gdscript
# Public getters — one per family. Return the read-only template.
func get_enemy(id: StringName) -> EnemyDefinition
func get_item(id: StringName) -> ItemDefinition
func get_skill(id: StringName) -> SkillDefinition
func get_wave_curve(id: StringName) -> WaveScalingCurve
func get_progression(id: StringName) -> CharacterProgressionCurve

func has_enemy(id: StringName) -> bool   # and equivalents per family

# Readiness
var is_ready: bool = false
signal database_ready
signal balance_database_reloaded   # fired after a hot reload (see C.1.8)
```

**Miss contract** (consistent across all getters):

- **Debug builds**: `assert(result != null, "BalanceDatabase: unknown <family> id '%s'" % id)` — crash loudly.
- **Release builds**: `push_error(...)` and return `null`. Consumers guard at the call site.
- No fallback sentinel Resources. Silent "default enemy" returns are forbidden.

Consumers that may run before autoloads finish must await `database_ready`. In practice the main scene's `_ready()` already fires after all autoloads, so this only matters for peer autoloads listed after `BalanceDatabase`.

#### C.1.5 Template / instance rule

- Resources returned by `BalanceDatabase` getters are **templates** — treat as read-only.
- Systems that need mutable per-instance state (Enemy System spawning a live enemy, Item System rolling stats on a drop) must call `resource.duplicate(true)` **exactly once at instantiation** and store the instance on the owning node. Never duplicate per-frame.
- `WaveScalingCurve` and `CharacterProgressionCurve` are read-only lookups — never duplicated.
- Consumer pattern: cache the typed reference at node init; do not call back into `BalanceDatabase` from `_process` / `_physics_process` / per-hit signals.
- **Nested Node-derived or physics sub-resources inside Balance Resources are forbidden** — they make `duplicate(true)` cost unbounded. Balance Resources hold only primitives, StringNames, typed arrays, Dictionaries, and Vector2/3.

#### C.1.6 Boot-time validation

`BalanceDatabase._ready()` runs `_validate_all()` before setting `is_ready = true`. All failures are collected, then reported.

Rules checked:

1. Every path in `BalanceManifest.paths` resolves to a loadable file.
2. Every loaded Resource's `schema_version` equals its family's `CURRENT_SCHEMA` constant.
3. No duplicate `id` within a family (cross-family ID collisions are allowed).
4. All required fields are non-null; `id` is non-empty (`&""` is invalid).
5. Numeric invariants: `base_hp > 0`, `base_damage > 0`, `mana_cost ≥ 0`, `cooldown_sec ≥ 0`, `scaling_coefficient` finite.
6. Closed-enum fields (see C.1.2) contain only allowed values.
7. `WaveScalingCurve.wave_entries` is dense (no gaps); `loop_after_wave ∈ [-1, wave_entries.size())`.
8. Every `enemy_ids` entry in every `WaveScalingCurve` resolves to a known EnemyDefinition.
9. `CharacterProgressionCurve.max_level == xp_per_level.size() - 1` and `xp_per_level[0] == 0`.
10. `ItemDefinition.stat_roll_ranges` keys are all in the closed stat set.
11. `BalanceManifest` itself loads and is non-empty.

**Failure mode:**

- Debug builds: `push_error()` per violation, then `assert(false)` after collecting all errors (so all problems are reported, not just the first).
- Release builds: write errors to a log, skip the offending Resources, emit a `balance_load_failed` signal. The game chooses to show an error screen or continue degraded.

#### C.1.7 Schema evolution

Each Resource class declares `const CURRENT_SCHEMA: int = N`. A file whose `schema_version` is less than this constant fails validation rule 2 — **no silent runtime migration.**

Migration is a designer-tooling step: `tools/migrate_balance.gd` (editor script) reads old Resources, applies field transforms, writes new ones with the bumped version. Run manually before committing schema-breaking changes. Purely additive fields get a default in `_init()` and do not require a version bump.

#### C.1.8 Hot reload (dev builds only)

A debug-build hotkey (configurable; default `F5`) invokes `BalanceDatabase.hot_reload()`. Release builds do not bind this action.

Concrete sequence:

```gdscript
func hot_reload() -> void:
    for path in _manifest.paths:
        ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    _templates.clear()
    _load_from_manifest()
    _validator.validate_all(_templates)
    emit_signal("balance_database_reloaded")
```

Already-duplicated instances in the active scene are **intentionally stale** after reload (they are independent copies — `duplicate(true)` breaks the reference chain). Consumers that want to apply reloaded values to live instances listen on `balance_database_reloaded` and decide per-system whether to re-fetch — that is a gameplay concern, outside this GDD.

### States and Transitions

The `BalanceDatabase` autoload holds a small state machine that consumers can observe via `is_ready` and the `database_ready` / `balance_database_reloaded` / `balance_load_failed` signals.

#### States

| State | `is_ready` | Getter behavior | Entered when |
|---|---|---|---|
| **UNLOADED** | `false` | Returns `null` + pushes error; asserts in debug | Initial state before autoload `_ready()` runs |
| **LOADING** | `false` | Returns `null` + pushes error; asserts in debug | Autoload `_ready()` begins reading the manifest |
| **VALIDATING** | `false` | Returns `null` + pushes error; asserts in debug | After all Resources parsed, before validator finishes |
| **READY** | `true` | Normal: returns template for known IDs, enforces miss contract for unknown | Validator passed (or skipped in degraded release) |
| **RELOADING** | `true` (stays true to avoid stalling consumers) | Returns the *previous* template until reload completes | `hot_reload()` called in dev build |
| **FAILED** | `false` | Returns `null` + pushes error; never asserts (already failed) | Validation failed in release build; `balance_load_failed` emitted |

#### Transitions

- `UNLOADED → LOADING` — autoload `_ready()` starts.
- `LOADING → VALIDATING` — all manifest paths loaded into `_templates`.
- `VALIDATING → READY` — `_validate_all()` reports zero errors. Set `is_ready = true`, emit `database_ready`.
- `VALIDATING → (assert)` — debug build, validator collected ≥1 error. Boot halts via `assert(false)`; no READY state reached.
- `VALIDATING → FAILED` — release build, validator collected ≥1 error. Offending Resources dropped from `_templates`, `balance_load_failed` emitted, `is_ready` stays `false`.
- `READY → RELOADING` — dev-only hot-reload hotkey fires. `is_ready` intentionally stays `true` so mid-session consumers continue to see the old templates while reload is in flight.
- `RELOADING → READY` — reload succeeded; emit `balance_database_reloaded`. Already-duplicated instances in the active scene are stale by design (see C.1.8).
- `RELOADING → READY (with errors)` — reload's validator reported errors. In dev this is treated as non-fatal: push errors to the Output panel, keep the *old* templates in `_templates` (do not replace them with a half-valid set), emit `balance_database_reloaded` with a reload-failed flag so dev tools can show a notice. The session continues with the pre-reload data.
- No transition out of `FAILED` — release builds do not support recovery-reload. A FAILED state requires restarting the game.

#### Consumer rules

- Any code that can run before the main scene `_ready()` (peer autoloads listed after `BalanceDatabase`; deferred signals) must `await BalanceDatabase.database_ready` or guard on `is_ready`.
- Consumers that want to react to live-tuning changes must listen on `balance_database_reloaded`, re-fetch the templates they care about, and decide whether to apply to live instances. The Balance Data Layer does not push changes into any consumer.
- Consumers must not call `BalanceDatabase` getters during `_init()` of any `Node` or `Resource` — `_init()` runs at duplication time (including `duplicate(true)` of Resources), which is outside the autoload-ready guarantee.

### Interactions with Other Systems

The Balance Data Layer has **no runtime input** from any other system. All 8 consumers are read-only: they call `BalanceDatabase` getters, treat returned templates as immutable, and `duplicate(true)` when per-instance state is needed.

#### Interaction matrix

| Consumer system | Reads (families) | Call timing | Instance handling |
|---|---|---|---|
| Save/Load System | any family's `has_*` + `get_*` | boot + save-write + save-load | none — ID validation only |
| Character Stats & Leveling | `CharacterProgressionCurve` | wave-start + level-up events | no duplication (read-only lookup) |
| Item System | `ItemDefinition` | drop roll + equip event | `duplicate(true)` per rolled item |
| Combat Engine | `EnemyDefinition`, `SkillDefinition`, `CharacterProgressionCurve` | wave-start (pre-warm); skill/stat values read from cached instance refs | reads instances owned by Enemy/Skill/Character systems |
| Enemy System | `EnemyDefinition` | wave-start (pre-warm batch); enemy-spawn event | `duplicate(true)` per spawned enemy |
| Skill System | `SkillDefinition` | character-init + skill-unlock event | `duplicate(true)` per learned skill (holds cooldown state) |
| Wave & Phase Manager | `WaveScalingCurve`, `EnemyDefinition` (via wave entries) | wave-start | no duplication (curve is read-only; spawning enemies is Enemy System's job) |
| Drop & Loot Tables | `ItemDefinition`, `EnemyDefinition.drop_table_id` | enemy-death event | no duplication (delegates item creation to Item System) |

#### Per-consumer contracts

**Save/Load System** — Saves store IDs (`StringName`), never Resource contents. On save-load, Save/Load calls `BalanceDatabase.has_enemy(id)` / `has_item(id)` / etc. to validate every referenced ID still exists after balance changes. A missing ID is handled by Save/Load's own policy (warn/drop/upgrade) — Balance Data Layer does not opine. Save/Load waits on `database_ready` before validating.

**Character Stats & Leveling** — At wave-start, fetches the single `CharacterProgressionCurve` (MVP: always `&"default"`) and caches a typed reference for the duration of the session. Reads `xp_per_level[level]`, `hp_per_vit`, etc. as read-only values. On level-up, re-reads from the cached reference — no new database call. On `balance_database_reloaded`, refreshes the reference.

**Item System** — When rolling a drop, calls `get_item(id)` once, then `duplicate(true)` to create the rolled instance, then reads `stat_roll_ranges` and writes the rolled stats onto the duplicated Resource's own fields (or onto a parallel runtime struct; see C.1.5). The rolled instance's `id` is kept identical to the template's `id` — save files reference items by `id` plus a rolled-stat blob, not by the duplicated Resource.

**Combat Engine** — Never calls `BalanceDatabase` on the hot path. Reads values (enemy `base_damage`, skill `scaling_coefficient`, curve `atk_per_str`) from the instance references owned by Enemy/Skill/Character systems, which those systems fetched and cached earlier. Combat Engine's role is pure calculation over values already in hand.

**Enemy System** — At wave-start, receives the upcoming wave's `enemy_ids` list from Wave & Phase Manager and **pre-warms** all needed templates: `var defs: Array[EnemyDefinition] = ids.map(func(id): return db.get_enemy(id))`. Per-enemy spawn then calls `defs[i].duplicate(true)` to produce the live enemy's data. Mid-wave database calls are forbidden.

**Skill System** — On character init (game start or save load), calls `get_skill(id)` once per unlocked skill and `duplicate(true)` to hold mutable per-instance state (current cooldown, stack counts). Stores instances keyed by `id`. On skill unlock mid-run, calls `get_skill` + `duplicate(true)` for the newly learned skill.

**Wave & Phase Manager** — At wave-start, calls `get_wave_curve(curve_id)` once to resolve the curve for the current run. Indexes into `wave_entries[wave_number]` (or applies the loop logic if past `loop_after_wave`) to determine spawn_count, enemy_ids, multipliers. Never duplicates the curve — it's a read-only lookup table. Passes the resolved enemy_ids and multipliers to Enemy System for spawn.

**Drop & Loot Tables** — On enemy death, reads `enemy_instance.drop_table_id` (already held on the duplicated instance). If non-empty, consults the future `DropTableDefinition` family (out of MVP scope — flagged in Open Questions) to resolve drops. For MVP, a simple rarity-weighted lookup against `BalanceDatabase` item list is acceptable; the Loot system's GDD specifies the rolling policy. Balance Data Layer provides the data; rolling logic is owned by Loot.

#### Boundary that does NOT exist

**Audio System, UI Framework, Animation Controller, Status Effects, Revive & Game Over** do not read from the Balance Data Layer at runtime. Their tunables (volumes, UI sizes, animation speeds, revive costs, status timings) live in their own config Resources or Project Settings. This keeps the Balance Data Layer focused on *gameplay math* — enemies, items, skills, curves — rather than becoming a global config dumping ground.

#### Interaction ownership

- `BalanceDatabase` **owns** the getter API and the template lifecycle.
- Each consumer **owns** its per-instance state (duplicated Resources, cached references, runtime structs).
- Neither side owns the *rolled values* or *runtime state* of a duplicated Resource — that belongs to the consumer that duplicated it.

## Formulas

The Balance Data Layer is a data layer, not a gameplay system. It **owns exactly one formula**: the `WaveScalingCurve` loop extrapolation that lets authored wave entries scale unbounded for AFK-late-game play. All other formulas that *consume* this data belong to the consumer system GDDs.

### D.1 Wave-loop extrapolation (owned by this GDD)

For a current wave number `w` (0-indexed, possibly greater than `wave_entries.size()`), the effective multipliers fed to Enemy System and Combat Engine are:

```
If loop_after_wave == -1:
    effective_hp_mult(w)  = wave_entries[min(w, N-1)].hp_mult
    effective_dmg_mult(w) = wave_entries[min(w, N-1)].dmg_mult
    loop_count(w)         = 0

Else if w <= loop_after_wave:
    effective_hp_mult(w)  = wave_entries[w].hp_mult
    effective_dmg_mult(w) = wave_entries[w].dmg_mult
    loop_count(w)         = 0

Else (w > loop_after_wave, looping active):
    loop_span             = loop_after_wave + 1
    offset                = w - loop_span
    loop_count(w)         = (offset / loop_span) + 1        # integer division
    e                     = offset mod loop_span
    effective_hp_mult(w)  = wave_entries[e].hp_mult  * loop_hp_scale ^ loop_count(w)
    effective_dmg_mult(w) = wave_entries[e].dmg_mult * loop_dmg_scale ^ loop_count(w)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| current wave | `w` | int | 0 .. unbounded | The wave the player is currently on (0-indexed) |
| authored length | `N` | int | 1 .. ∞ (validator requires ≥ 1) | `wave_entries.size()` |
| loop anchor | `loop_after_wave` | int | -1, or 0 .. N-1 | -1 disables looping; otherwise the last pre-loop wave index |
| loop length | `loop_span` | int | 1 .. N | Derived: `loop_after_wave + 1` |
| loop cycle | `loop_count(w)` | int | 0 .. unbounded | How many complete loops past the first pass |
| entry index | `e` | int | 0 .. (loop_span - 1) | Which `wave_entries` entry to read |
| per-entry HP mult | `wave_entries[e].hp_mult` | float | > 0.0 (validator-enforced) | Authored base HP multiplier |
| per-entry damage mult | `wave_entries[e].dmg_mult` | float | > 0.0 | Authored base damage multiplier |
| loop HP scale | `loop_hp_scale` | float | > 0.0 | Per-loop compounding factor on HP |
| loop damage scale | `loop_dmg_scale` | float | > 0.0 | Per-loop compounding factor on damage |
| output HP mult | `effective_hp_mult(w)` | float | > 0.0, unbounded above | Multiplier consumed by Combat Engine for enemy HP |
| output damage mult | `effective_dmg_mult(w)` | float | > 0.0, unbounded above | Multiplier consumed by Combat Engine for enemy damage |

**Output Range:** Both outputs are strictly positive floats, unbounded above. This formula does **not** clamp — consumer systems apply their own caps. Entries past index `loop_after_wave` in the array are ignored when looping is active (validator warns at boot but doesn't fail).

**Example:** `wave_entries.size() = 10`, `loop_after_wave = 9`, `loop_hp_scale = 1.15`, `wave_entries[7].hp_mult = 2.0`. For `w = 27`:

```
loop_span    = 9 + 1 = 10
offset       = 27 - 10 = 17
loop_count   = floor(17 / 10) + 1 = 1 + 1 = 2
e            = 17 mod 10 = 7
hp_mult(27)  = 2.0 × 1.15² = 2.0 × 1.3225 = 2.645
```

**Representative output scale** (assumes authored `hp_mult` baseline ~2.0 and `loop_hp_scale = 1.15`, `loop_span = 10`):

| Wave | Loops | Effective HP mult |
|---|---|---|
| 0–9 | 0 | 1.0 – 2.0 (authored) |
| 50 | 4 | ≈ 3.5 |
| 100 | 9 | ≈ 7.1 |
| 200 | 19 | ≈ 32 |
| 500 | 49 | ≈ 930 |
| 1000 | 99 | ≈ 8.6 × 10⁵ |

GDScript floats are f64. Precision loses sub-unit accuracy around wave 1000+, which is gameplay-irrelevant. The real risk is the *consumer* side — systems multiplying this by a base stat must use `float` through the damage pipeline, not `int`.

### D.2 Formulas owned by other GDDs (pointer table)

The following formulas use data provided by Balance Data Layer but are **not** defined here. Changes to these formulas do not require a change to this GDD.

| Formula | Data read from BDL | Owned by GDD |
|---|---|---|
| XP required at level N | `CharacterProgressionCurve.xp_per_level[N]` | Character Stats & Leveling |
| Max HP / Max mana from stats | `hp_per_vit`, `mana_per_int` + current VIT/INT | Character Stats & Leveling |
| Derived stat curves (attack from STR, speed from DEX) | `atk_per_str`, `speed_per_dex` + stats | Character Stats & Leveling |
| Basic attack damage calculation | `EnemyDefinition.base_damage`, player attack, defense | Combat Engine |
| Skill damage / heal / buff magnitude | `SkillDefinition.scaling_coefficient`, `scaling_stat`, `effect_tags` | Skill System (magnitude) + Combat Engine (application) |
| Item stat rolling (rolled value within range) | `ItemDefinition.stat_roll_ranges[stat]` | Item System |
| Rarity drop probabilities | `ItemDefinition.rarity` (as filter input) | Drop & Loot Tables |
| Enemy spawn count per wave | `WaveScalingCurve.wave_entries[w].spawn_count` (as input) | Wave & Phase Manager |
| Offline progression efficiency | (reads multiple) | Offline Progression |

Cross-GDD contract: when any of the above formulas change, the owning GDD is updated — **not** this one, unless the change requires a new field on a Balance Resource. In that case the consumer GDD triggers `/propagate-design-change`.

## Edge Cases

Edge cases are grouped by failure category. Every entry states the exact condition and the exact resolution. Some cases are also covered by the boot validator (Section C.1.6) — those entries cross-reference the relevant validator rule.

### E.1 Malformed data (designer mistakes the validator must catch)

- **If `wave_entries` is empty and a caller queries the curve**: validator fails at boot (rule 7). Runtime guard returns `{ hp_mult: 1.0, dmg_mult: 1.0 }` and `push_error()`s; the game continues degraded rather than crashing in release. Debug builds assert.
- **If `stat_roll_ranges[stat] = Vector2(min, max)` has `min > max`**: validator fails with a clear message pointing at the offending Item and stat key. Rule 10 is extended to require `v.x <= v.y` for every entry.
- **If `wave_entries[i].hp_mult <= 0` or `dmg_mult <= 0`**: validator fails. Rule 5 is extended to include these sub-fields (not only top-level `base_hp` / `base_damage`).
- **If `xp_per_level` contains `NaN` or `INF`** (possible via hand-edited `.tres`): validator fails. Rule 9 is extended — every `xp_per_level[i]` must satisfy `is_finite(v) == true`.
- **If `xp_per_level` is non-monotonic at index ≥ 1** (e.g., level 5 needs *less* XP than level 4): validator fails. Rule 9 is extended — every `xp_per_level[i]` for `i >= 1` must satisfy `xp_per_level[i] > xp_per_level[i-1]`.
- **If two Resources in a family share the same `id`**: validator fails at rule 3. Cross-family ID collision (`EnemyDefinition &"slime"` and `ItemDefinition &"slime"`) is allowed; each family has its own dictionary.
- **If a closed-enum StringName field contains a value not in its allowed set**: validator fails at rule 6 with the offending value and the allowed set in the error message.
- **If a `WaveScalingCurve.enemy_ids` entry does not resolve to a known EnemyDefinition**: validator fails at rule 8.

### E.2 Wave-loop formula boundaries

- **If `loop_after_wave == -1`**: looping disabled. For `w >= N`, the formula clamps `w` to `N-1` and emits a one-time runtime warning on the first such query. Designer-authored end-of-content.
- **If `loop_hp_scale == 1.0`**: formula is stable; difficulty plateaus at authored values. Explicit, valid designer choice.
- **If `loop_hp_scale < 1.0`** (de-escalating): `effective_hp_mult` approaches 0 at high loops. Balance Data Layer does **not** clamp — consumer systems are responsible for enforcing a floor (e.g., Combat Engine treats incoming multipliers below 0.01 as 0.01). Documented cross-system contract.
- **If `w > loop_after_wave` but there are `wave_entries` indices past `loop_after_wave`**: those entries are **ignored** once looping begins. Validator emits a warning but does not fail (it's a legitimate authoring choice to trim the array later without bumping `loop_after_wave`).
- **If float precision loses sub-unit accuracy at wave > 1000**: acceptable. Gameplay-irrelevant at f64. Document as known limit.

### E.3 Manifest and asset pipeline

- **If a path in the manifest resolves to no file**: validator fails at rule 1 with the missing path.
- **If a path resolves to a Resource of an unrecognized class**: logged as a warning, resource skipped, boot continues. This is intentional (tools may place non-balance resources in the data folder).
- **If a `.tres` was renamed on disk without updating its `uid://` UID reference in `.godot/uid_cache.bin`**: Godot 4.x resolves by UID when available. `ResourceLoader.load(path)` may silently return a Resource from the new path while the manifest still points at the old. Validator extension: after load, compare `resource.resource_path` to the manifest path; mismatch triggers a UID-remap warning.
- **If a Resource was saved with `resource_local_to_scene = true`** (inspector click-mistake): it will not deserialize correctly via `ResourceLoader.load()`. Validator rule: assert `resource.resource_local_to_scene == false` on every loaded template.
- **If a Resource contains inline `[sub_resource]` blocks**: harmless for immutability (each load creates independent sub-resource copies), but hot reload must not retain stale references. `CACHE_MODE_IGNORE` handles this; confirm no consumer is holding the old sub-resource reference via a signal/node path.

### E.4 Lifecycle, concurrency, and hot reload

- **If a consumer calls a getter before `is_ready == true`**: debug asserts; release returns `null` + `push_error`. Consumers in `_init()` or deferred-signal paths must guard on `is_ready` or `await database_ready`.
- **If `hot_reload()` fires mid-wave**: intentional design — `is_ready` stays `true` during RELOADING, and Wave & Phase Manager caches its resolved `WaveScalingCurve` at wave-start (documented consumer invariant). The in-flight wave completes with pre-reload data; the next wave uses reloaded data.
- **If `hot_reload()` fires while `Save/Load` is writing or reading**: Save/Load sees pre-reload templates during the write/read (consistent snapshot). If the reload removes IDs that the just-read save references, Save/Load re-validates on `balance_database_reloaded` and applies its own missing-ID policy.
- **If a peer autoload listed *after* `BalanceDatabase` connects to `database_ready` in its `_ready()` and the signal has already fired** (because `BalanceDatabase._ready()` completed synchronously): the connection will not re-trigger. Mitigation: peer autoloads that need balance data check `BalanceDatabase.is_ready` first, and only `await` the signal if not yet ready.
- **If a `database_ready` handler fires during the autoload `_ready()` chain**: the main scene is not yet ready. The handler must not call scene-tree mutations (`change_scene_to_*`, `add_child` on scene nodes). It must only initialize autoload-local state.
- **If validator errors occur mid-reload (dev only)**: old templates are retained in `_templates` (no half-valid state). `balance_database_reloaded` fires with a `success: bool = false` flag so dev UI can show a notice. Gameplay continues with pre-reload data.
- **If validator errors occur in release at boot**: `balance_load_failed` signal is emitted after offending Resources are dropped. The game decides (error screen or degraded continue) — Balance Data Layer does not opine.
- **If a consumer mutates a returned template without `.duplicate(true)` first**: the shared cache is corrupted for the rest of the session. Detection: optional debug-build guard that wraps every getter and asserts the returned object's hash matches its load-time hash. Mitigation: strict code review + consumer-side do/don't rules (see C.1.5).

### E.5 Schema evolution

- **If a Resource's `schema_version` is lower than the class's `CURRENT_SCHEMA`**: validator fails at rule 2 — no silent runtime migration. Designer runs `tools/migrate_balance.gd` in the editor, commits migrated Resources.
- **If a new field is added purely additively**: the field MUST declare its default inline on the `@export` line (`@export var new_field: float = 1.0`), not in a separate `_init()` assignment. Godot's Resource deserializer fills missing fields from the `@export` default at load time; `_init()`-only defaults don't apply.
- **If an old `.tres` predates the `schema_version` field entirely**: Godot loads the Resource with `schema_version = 0` (int default). Rule 2 catches the mismatch. The migration tool must recognize and handle `schema_version == 0` explicitly as "pre-versioning," not treat it as "version 0."
- **If a field is renamed**: bump `schema_version`, update the migration tool, run it before the commit. The renamed field's old name is not remembered by Godot — old files must be migrated or they load with the old value dropped.
- **If a field is removed but the `.tres` still has it**: Godot ignores unknown properties at load. Safe to remove fields as long as no code still reads them. Schema bump is still required so future reloads flag the intent.

## Dependencies

### F.1 Upstream dependencies (systems this GDD depends on)

**None.** Balance Data Layer is a Foundation-layer system. It depends on no other system at runtime. Build-time it depends only on Godot 4.6's `Resource` and `ResourceLoader` classes (see Section C.1.8 for the one `CACHE_MODE_IGNORE` verification item).

### F.2 Downstream dependents (systems that depend on this GDD)

All dependencies are **read-only at runtime** — no consumer writes to Balance Data Layer state. See Section C.3 for the per-consumer data contract; this section only classifies hard vs soft.

| Consumer system | Hard / Soft | Reason |
|---|---|---|
| Save/Load System | **Hard** | Save format stores Balance IDs; cannot validate or load without querying `has_*()` |
| Character Stats & Leveling | **Hard** | Derives all HP/mana/atk from `CharacterProgressionCurve`; no fallback data exists |
| Item System | **Hard** | Cannot roll or equip items without `ItemDefinition` |
| Combat Engine | **Hard** | Damage math reads enemy/skill/progression values that live here |
| Enemy System | **Hard** | Cannot spawn an enemy without `EnemyDefinition` |
| Skill System | **Hard** | Cannot instantiate a skill without `SkillDefinition` |
| Wave & Phase Manager | **Hard** | Wave composition, spawn count, multipliers all read from `WaveScalingCurve` |
| Drop & Loot Tables | **Hard** | Reads `ItemDefinition` for drop candidates and `EnemyDefinition.drop_table_id` |

All 8 MVP consumers are **hard** dependents — none can degrade gracefully without Balance Data Layer present. This is expected for a data-layer foundation system.

### F.3 Explicit non-dependents

The following systems are **declared not to depend** on Balance Data Layer. If a future design change introduces a dependency from any of these, it must be surfaced in the new dependency's GDD and `/propagate-design-change` must run against this GDD to re-evaluate scope.

- Game State Manager
- Audio System
- UI Framework & Navigation
- Character Animation Controller
- Status Effects
- Revive & Game Over

Their tunables live in their own config Resources or Project Settings (see Section C.3's "Boundary that does NOT exist").

### F.4 Bidirectional dependency contract

When this GDD is updated, the 8 consumer GDDs may need updates too. The tooling-visible contract:

- Adding a **required** field to an existing Resource family → **schema bump**, all consumers that duplicate that family's Resources must handle the new field. Trigger `/propagate-design-change`.
- Adding an **optional** field with an `@export` default → no consumer change required, but any consumer that reads it must be updated to actually use it.
- Removing a field → schema bump, all consumers that read it must stop reading. Trigger `/propagate-design-change`.
- Adding a new Resource family (e.g., future `DropTableDefinition` for loot rolls) → consumer GDD for that family (Drop & Loot Tables) updates, this GDD updates its C.1.1 schema + Section C.3 interaction row.
- Adding a new closed-enum value → single-line code edit + this GDD's C.1.2 list. Consumer GDDs that handle the new value update their own docs as needed.
- Changing the wave-loop formula (D.1) → only consumers that read `effective_hp_mult` / `effective_dmg_mult` need to be reviewed. In MVP, that's Enemy System and Combat Engine.

When a consumer GDD's formula changes, this GDD does **not** need an update unless the change requires new schema fields. That reverse case is covered by the consumer GDD's `/propagate-design-change`.

## Tuning Knobs

Balance Data Layer tuning knobs split into three groups:

1. **Per-Resource fields** (designer-adjustable in `.tres` files — the bulk of tuning surface area). Tunability per field is declared in Section C.1.1; safe-range guidance for numeric knobs is owned by the **consumer GDDs** (Combat Engine, Character Stats, etc.) — not this GDD.
2. **Wave-loop formula knobs** (owned by this GDD). Covered below.
3. **System-level knobs** (global, not per-Resource). Covered below.

### G.1 Per-Resource knobs — cross-reference only

Every field marked `Tunable: yes` in the Section C.1.1 schema tables is a designer knob. This GDD does not duplicate the list.

**Safe-range ownership:**

| Field | Range ownership |
|---|---|
| `EnemyDefinition.base_hp`, `base_damage` | Combat Engine GDD |
| `EnemyDefinition.behavior_tag`, `size_category` | Combat Engine GDD (gameplay meaning) |
| `ItemDefinition.stat_roll_ranges[*]` | Item System GDD |
| `ItemDefinition.rarity`, `slot` | Item System GDD (rarity weights + slot rules) |
| `SkillDefinition.mana_cost`, `cooldown_sec`, `scaling_coefficient` | Skill System GDD |
| `SkillDefinition.effect_tags` | Combat Engine GDD (interprets tags) |
| `CharacterProgressionCurve.xp_per_level`, `hp_per_vit`, `atk_per_str`, etc. | Character Stats & Leveling GDD |
| `WaveScalingCurve.wave_entries[*].hp_mult`, `dmg_mult`, `spawn_count` | Wave & Phase Manager GDD |

If a designer asks "what's a safe value for `base_hp`?" the answer is in the Combat Engine GDD, not here. Balance Data Layer only enforces structural sanity (`> 0`, finite, in closed enum, etc.) via the validator.

### G.2 Wave-loop formula knobs (owned by this GDD)

Three knobs per `WaveScalingCurve` Resource tune the late-game scaling curve.

#### `loop_hp_scale` / `loop_dmg_scale`

| Range | Behavior | Comment |
|---|---|---|
| `< 1.0` | De-escalating — difficulty decays per loop | Not recommended for AFK RPG pacing; consumer-clamp at 0.01 prevents zero-damage enemies |
| `= 1.0` | Plateau — authored values repeat unchanged | Valid. Use when designers want an explicit difficulty ceiling |
| `1.05 – 1.20` | **Recommended for MVP** | Perceptible scaling; reaches ~7× at loop 10, ~30× at loop 20 |
| `> 1.30` | Aggressive — player's gear must scale fast to keep up | Will trivialize idle progression if Character Stats can't keep pace |
| `>= 2.0` | Breaks within a few loops | Consumer damage pipeline may exceed display budgets (big-number UI) |

Both knobs default to **1.15** in the MVP reference curve unless a designer has a reason to deviate. Asymmetric values (e.g., `loop_hp_scale = 1.15`, `loop_dmg_scale = 1.10`) are valid and useful when enemy damage feels unfair faster than their HP feels tanky.

#### `loop_after_wave`

| Value | Behavior |
|---|---|
| `-1` | No looping — game hard-ends past `wave_entries.size()`; runtime warns |
| `0` | Loop starts immediately — wave 1 uses entry 0 with `loop_count = 1` |
| `1 .. N-2` | Some pre-loop waves authored once, loop begins mid-array |
| `N-1` (most common) | All entries loop; simplest authoring mode |

**Cross-knob interaction — `loop_after_wave` × `loop_*_scale`:**

- A short `loop_span` (e.g., `loop_after_wave = 2`, so only 3 entries loop) compounds the scale *faster* per absolute wave number. Compensate by lowering `loop_*_scale`.
- A long `loop_span` (e.g., 20 authored entries) makes the scale effect gentler per wave. `loop_*_scale` may need to be higher to reach the intended difficulty slope.
- Quick sanity: target **HP multiplier ≈ 10× at wave 100**. Solve: `2.0 × loop_hp_scale^(100/loop_span - 1) ≈ 10`.

### G.3 System-level knobs

| Knob | Type | Default | Safe range | Notes |
|---|---|---|---|---|
| Hot-reload input action | InputMap | `F5` (dev only) | any InputMap action | Set in Project Settings → Input Map. Release build strips the binding at export time. |
| Manifest path | constant | `res://assets/data/BalanceManifest.tres` | fixed | Not runtime-configurable. Changing requires a code edit + validator re-run. |
| Validator fail mode | compile-time flag | `OS.is_debug_build()` | fixed | Debug = assert on error; release = emit signal + continue. Not a runtime toggle. |
| `CURRENT_SCHEMA` per family | `const int` | `1` | monotonically increasing | Code constant. Bump when breaking schema changes land. Migration tool must support every version gap. |

### G.4 What's **not** a tuning knob

- The 5 Resource family shapes (`EnemyDefinition`, `ItemDefinition`, etc.) — these are schema, not knobs. Adding a field is a schema bump (Section C.1.7).
- The closed-enum sets (Section C.1.2) — these are code constants. Adding a value is a code change, not data tuning.
- The boot-time validator rules (Section C.1.6) — these are invariants, not knobs. Loosening a rule requires an explicit decision in this GDD.
- The `BalanceDatabase` API signatures — fixed contract. Changing requires `/propagate-design-change`.

## UI Requirements

No player-facing UI.

A **dev-only debug panel** listing all loaded Resources with a reload button and live validator status is desirable but out of MVP scope. See Open Questions OQ-5 for related tooling considerations. When/if this panel is built, it lives in the Dev Tools area and is stripped from release builds via the same build-flag as the `F5` hot-reload hotkey (Section C.1.8).

## Cross-References

### Project documents
- **Systems index**: [`design/gdd/systems-index.md`](systems-index.md) — row 2 (Balance Data Layer, Foundation, MVP)
- **Game concept**: [`design/gdd/game-concept.md`](game-concept.md) — anchors the player fantasy this layer enables
- **Technical preferences**: `.claude/docs/technical-preferences.md` — Godot 4.6 / GDScript / GdUnit4 commitments this GDD inherits

### Consumer GDDs (to be authored — references expected)
- Save/Load System, Character Stats & Leveling, Item System, Combat Engine, Enemy System, Skill System, Wave & Phase Manager, Drop & Loot Tables

Each consumer GDD must include a "Reads from Balance Data Layer" subsection in its Dependencies section that mirrors the row in this GDD's Section C.3 interaction matrix.

### Expected ADRs (to emerge during `/create-architecture`)
- Autoload ordering policy for foundation systems
- Migration tooling architecture (`tools/migrate_balance.gd` pattern)
- Binary `.res` export pipeline (if OQ-2 forces the flip)
- Debug-panel architecture (if UI Requirements stub is expanded)

### Engine reference
- `docs/engine-reference/godot/VERSION.md` — Godot 4.6 pin (Jan 2026)
- `docs/engine-reference/godot/modules/core.md` (target for OQ-1 verification)

## Acceptance Criteria

### H.1 Loading and readiness

- **AC-001** GIVEN the game launches with a valid `BalanceManifest.tres` WHEN `BalanceDatabase._ready()` completes THEN `is_ready == true`, the `database_ready` signal has fired exactly once, and `get_enemy` / `get_item` / `get_skill` / `get_wave_curve` / `get_progression` all return non-null results for every ID listed in the manifest.
  _How tested: integration test in `tests/integration/balance_data_layer/test_boot_ready.gd` — instantiate BalanceDatabase with a fixture manifest, assert state._

- **AC-002** GIVEN `BalanceDatabase` is in state UNLOADED or LOADING WHEN any getter is called THEN the getter returns `null`, a `push_error` is recorded, and — in a debug build — an assert fires.
  _How tested: unit test in `tests/unit/balance_data_layer/test_getters_before_ready.gd` — call getter before `_ready` completes via a deferred pre-check._

- **AC-003** GIVEN boot validation succeeds WHEN state machine transitions are traced THEN the sequence is exactly UNLOADED → LOADING → VALIDATING → READY with no skipped or repeated states.
  _How tested: unit test in `tests/unit/balance_data_layer/test_state_machine.gd` — instrument state transitions with a log array._

- **AC-004** GIVEN a peer autoload listed after `BalanceDatabase` WHEN that autoload's `_ready()` runs THEN checking `is_ready` returns `true` without needing to await `database_ready`.
  _How tested: integration test in `tests/integration/balance_data_layer/test_peer_autoload_ordering.gd` — register a dummy peer autoload and assert `is_ready` at its `_ready` entry point._

### H.2 Validator rule enforcement

Each criterion maps to one of the 11 boot validator rules from Section C.1.6.

- **AC-005 (Rule 1)** GIVEN a manifest that references a non-existent file path WHEN validation runs THEN an error is recorded naming the missing path, and the system transitions to FAILED in release or asserts in debug.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-006 (Rule 2)** GIVEN a Resource whose `schema_version` does not equal its family's `CURRENT_SCHEMA` WHEN validation runs THEN validation fails for that Resource, naming both the found version and the expected version.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-007 (Rule 3)** GIVEN two `EnemyDefinition` Resources with the same `id` value WHEN validation runs THEN validation fails with a duplicate-ID error; a cross-family collision (`EnemyDefinition` and `ItemDefinition` sharing an `id`) must not fail.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-008 (Rule 4)** GIVEN an `EnemyDefinition` Resource with `id == &""` WHEN validation runs THEN validation fails with a non-empty-id error.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-009 (Rule 5)** GIVEN an `EnemyDefinition` with `base_hp <= 0`, a `SkillDefinition` with `mana_cost < 0`, or a `WaveScalingCurve` entry with `hp_mult <= 0` WHEN validation runs THEN validation fails for each offending Resource with a message identifying the field and value.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-010 (Rule 6)** GIVEN an `ItemDefinition` with `rarity == &"mythic"` (not in the closed set) WHEN validation runs THEN validation fails naming the field, the invalid value, and the allowed set.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-011 (Rule 7)** GIVEN a `WaveScalingCurve` with `wave_entries` empty, or with `loop_after_wave >= wave_entries.size()` WHEN validation runs THEN validation fails with a density/range error.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-012 (Rule 8)** GIVEN a `WaveScalingCurve` whose `wave_entries[0].enemy_ids` contains `&"unknown_enemy"` and no `EnemyDefinition` with that id is loaded WHEN validation runs THEN validation fails naming the unresolved foreign key.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-013 (Rule 9 — size)** GIVEN a `CharacterProgressionCurve` where `max_level != xp_per_level.size() - 1` WHEN validation runs THEN validation fails with a size-mismatch message.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-014 (Rule 9 — NaN/Inf)** GIVEN a `CharacterProgressionCurve` where `xp_per_level[3] == INF` WHEN validation runs THEN validation fails naming the index and value.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-015 (Rule 9 — monotonic)** GIVEN a `CharacterProgressionCurve` where `xp_per_level[5] < xp_per_level[4]` WHEN validation runs THEN validation fails naming the non-monotonic indices and values.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-016 (Rule 10)** GIVEN an `ItemDefinition` with `stat_roll_ranges[&"atk"] = Vector2(100.0, 50.0)` (min > max) WHEN validation runs THEN validation fails naming the item id, the stat key, and the offending Vector2.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-017 (Rule 11)** GIVEN an empty `BalanceManifest` (zero paths) WHEN validation runs THEN validation fails with a non-empty-manifest error; `is_ready` stays `false`.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-018 (Release failure path)** GIVEN validation fails in a release build WHEN errors are collected THEN `balance_load_failed` is emitted, offending Resources are absent from `_templates`, and `is_ready` remains `false`; no assert fires.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — build-flag fixture._

- **AC-019 (All errors reported)** GIVEN a manifest with three separate validator violations WHEN validation runs in debug THEN all three errors are pushed before the single final assert fires (no fail-fast at first error).
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

### H.3 Wave-loop formula correctness

All formula tests use a fixture `WaveScalingCurve` with `wave_entries.size() = 10`, `loop_after_wave = 9`, `loop_hp_scale = 1.15`, `loop_dmg_scale = 1.10`, and `wave_entries[7].hp_mult = 2.0` unless stated otherwise. Floating-point comparisons use `absf(actual - expected) < 0.0001`.

- **AC-020 (w = 0)** WHEN queried for `w = 0` THEN `effective_hp_mult == wave_entries[0].hp_mult` and `loop_count == 0`.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-021 (w = loop_after_wave)** WHEN queried for `w = 9` THEN `effective_hp_mult == wave_entries[9].hp_mult` and `loop_count == 0`.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-022 (w = loop_after_wave + 1, first loop wave)** WHEN queried for `w = 10` THEN `loop_count == 1`, `e == 0`, and `effective_hp_mult == wave_entries[0].hp_mult * 1.15^1`.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-023 (w = 27, documented example)** WHEN queried for `w = 27` THEN `loop_count == 2`, `e == 7`, and `effective_hp_mult == 2.645` (within 0.001).
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-024 (mid-second-loop)** WHEN queried for `w = 23` (`offset = 13`, `loop_count = 2`, `e = 3`) THEN `effective_hp_mult == wave_entries[3].hp_mult * 1.15^2`.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-025 (loop_after_wave = -1, w within range)** GIVEN `loop_after_wave = -1` WHEN queried for `w = 5` (within entries) THEN `effective_hp_mult == wave_entries[5].hp_mult` and `loop_count == 0`.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-026 (loop_after_wave = -1, w beyond range, clamp)** GIVEN `loop_after_wave = -1` WHEN queried for `w = 50` THEN `effective_hp_mult == wave_entries[9].hp_mult` (clamped to N-1), `loop_count == 0`, and a one-time runtime warning is recorded.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-027 (loop_hp_scale = 1.0, plateau)** GIVEN `loop_hp_scale = 1.0` WHEN queried for any `w > loop_after_wave` THEN `effective_hp_mult == wave_entries[e].hp_mult * 1.0 ^ loop_count` (authored value, no growth).
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-028 (loop_hp_scale < 1.0, decay, no clamp in this layer)** GIVEN `loop_hp_scale = 0.80` WHEN queried for `w = 27` THEN `effective_hp_mult == wave_entries[7].hp_mult * 0.80^2` — a value less than the authored base — and the formula returns it without clamping.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-029 (invalid w, negative)** GIVEN `w = -1` is passed to the formula THEN `push_error` is called and `effective_hp_mult` returns `wave_entries[0].hp_mult` as a safe fallback; no crash.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

### H.4 API behavior — getters, miss contract, template immutability

- **AC-030 (getter hit, typed return)** GIVEN a loaded `EnemyDefinition` with `id = &"slime_common"` WHEN `BalanceDatabase.get_enemy(&"slime_common")` is called THEN the return type is `EnemyDefinition` and `result.id == &"slime_common"`.
  _Unit test: `tests/unit/balance_data_layer/test_getter_api.gd`_

- **AC-031 (miss contract — debug)** GIVEN `is_ready == true` in a debug build WHEN `get_enemy(&"nonexistent_id")` is called THEN an assert fires.
  _Unit test: `tests/unit/balance_data_layer/test_getter_api.gd` — debug-flag fixture._

- **AC-032 (miss contract — release)** GIVEN `is_ready == true` in a release build WHEN `get_enemy(&"nonexistent_id")` is called THEN `null` is returned, `push_error` is called, and no assert fires.
  _Unit test: `tests/unit/balance_data_layer/test_getter_api.gd` — release-flag fixture._

- **AC-033 (no direct ResourceLoader calls)** GIVEN any consumer file in `src/` WHEN the file is static-analyzed THEN no call to `ResourceLoader.load()` on a path under `assets/data/` exists. (Forbidden pattern from C.1.4.)
  _Automated: grep-based CI lint check — no dedicated GdUnit4 file required; violation blocks CI._

- **AC-034 (duplicate-once, not per-frame)** GIVEN an `EnemyDefinition` template obtained from `get_enemy` WHEN `duplicate(true)` is called once and the resulting instance's `base_hp` is modified THEN a subsequent `get_enemy` call for the same id returns the original unmodified value.
  _Unit test: `tests/unit/balance_data_layer/test_getter_api.gd`_

- **AC-035 (WaveScalingCurve / CharacterProgressionCurve never duplicated)** GIVEN `get_wave_curve` or `get_progression` returns a template WHEN that template is used in Wave & Phase Manager or Character Stats THEN no `duplicate()` call appears on the returned object in those consumer files.
  _Automated: code-review checklist item + optional grep CI lint; documented in consumer contract._

### H.5 Hot reload

- **AC-036 (is_ready stays true during RELOADING)** GIVEN the game is in READY state WHEN `hot_reload()` is called THEN `is_ready` remains `true` for the entire duration of the reload sequence, and getters continue to return pre-reload templates until reload completes.
  _Unit test: `tests/unit/balance_data_layer/test_hot_reload.gd` — spy on `is_ready` inside the reload sequence._

- **AC-037 (balance_database_reloaded fires after success)** GIVEN `hot_reload()` is called with a valid new manifest WHEN reload completes without errors THEN `balance_database_reloaded` is emitted exactly once with `success = true`, and subsequent getter calls return updated templates.
  _Integration test: `tests/integration/balance_data_layer/test_hot_reload_integration.gd`_

- **AC-038 (hot reload with validator errors retains old templates)** GIVEN `hot_reload()` is called and the new data contains a validator violation WHEN reload completes THEN old templates are retained in `_templates`, `balance_database_reloaded` is emitted with `success = false`, and `is_ready` remains `true`.
  _Unit test: `tests/unit/balance_data_layer/test_hot_reload.gd`_

- **AC-039 (hot reload not available in release builds)** GIVEN a release build WHEN `F5` is pressed THEN no `hot_reload()` call is made and no `balance_database_reloaded` signal fires.
  _Manual smoke check: launch export build, press F5, confirm no reload signal in logs. Document in `production/qa/evidence/`._

- **AC-040 (mid-wave stale instances)** GIVEN an enemy instance was duplicated from a template before `hot_reload()` fires WHEN `hot_reload()` completes THEN the live enemy instance retains its pre-reload values; the post-reload template has the new values.
  _Integration test: `tests/integration/balance_data_layer/test_hot_reload_integration.gd`_

### H.6 Edge case handling

- **AC-041 (E.1 — empty wave_entries runtime guard)** GIVEN a `WaveScalingCurve` that somehow reaches runtime with `wave_entries` empty (validator failed silently in release) WHEN the formula is queried THEN a `push_error` is recorded and `{ hp_mult: 1.0, dmg_mult: 1.0 }` is returned; no crash occurs.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd`_

- **AC-042 (E.3 — resource_local_to_scene guard)** GIVEN a Resource saved with `resource_local_to_scene = true` is listed in the manifest WHEN validation runs THEN validation fails naming the Resource and field; the Resource is excluded from `_templates`.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd`_

- **AC-043 (E.3 — UID remap warning)** GIVEN a manifest path whose resolved `resource_path` after load differs from the manifest-listed path WHEN validation runs THEN a UID-remap warning is emitted; boot continues and the Resource is still loaded.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd` — mock ResourceLoader fixture._

- **AC-044 (E.4 — getter before ready, release)** GIVEN the game is in LOADING state WHEN a consumer calls `get_item` from a deferred signal THEN `null` is returned, `push_error` fires, and no assert fires in release.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd`_

- **AC-045 (E.4 — peer autoload already-fired signal)** GIVEN `BalanceDatabase._ready()` completes synchronously before a peer autoload's `_ready()` runs WHEN the peer checks `is_ready` before connecting to `database_ready` THEN `is_ready == true` and the peer does not deadlock awaiting a signal that already fired.
  _Integration test: `tests/integration/balance_data_layer/test_peer_autoload_ordering.gd`_

- **AC-046 (E.5 — schema mismatch fails, no silent migration)** GIVEN a Resource with `schema_version = 0` and `CURRENT_SCHEMA = 1` WHEN validation runs THEN validation fails; the Resource is not silently loaded with a default schema version.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd`_

### H.7 Performance / budget

- **AC-047 (boot validator speed)** GIVEN a manifest containing 200 Resources (across all five families) WHEN `BalanceDatabase._ready()` runs headlessly on a mid-range Android 2020+ device THEN total time from LOADING entry to `database_ready` signal is under 500 ms.
  _Automated benchmark: `tests/performance/test_balance_boot_time.gd` — `Time.get_ticks_msec()` delta; threshold asserted. Also run on target hardware during milestone sign-off._

- **AC-048 (getter call cost)** GIVEN the database is READY WHEN any typed getter is called 10,000 times in a tight loop THEN total elapsed time is under 10 ms on desktop (O(1) Dictionary lookup requirement).
  _Unit benchmark: `tests/performance/test_balance_boot_time.gd`_

- **AC-049 (duplicate(true) not per-frame)** GIVEN 100 concurrent enemy instances in a wave WHEN the wave runs for 60 frames THEN `duplicate(true)` is called exactly 100 times total (once per spawn, never again). Frame profiler shows zero `duplicate` calls after the spawn batch.
  _Integration test / profiler assertion: `tests/integration/balance_data_layer/test_duplicate_budget.gd` — instrument EnemySystem with a call counter._

- **AC-050 (memory ceiling)** GIVEN the full MVP manifest is loaded WHEN `Performance.get_monitor(Performance.MEMORY_STATIC)` is sampled after `database_ready` fires THEN the delta from baseline is under 32 MB on desktop; under 20 MB on mobile (all five Resource families, no duplicated instances counted).
  _Manual smoke check on target Android device during milestone QA. Document in `production/qa/evidence/`._

### H.8 Test evidence required

| Section | Story type | Required evidence | Test file location |
|---|---|---|---|
| H.1 Loading and readiness | Integration | Integration test — boot sequence with fixture manifest | `tests/integration/balance_data_layer/test_boot_ready.gd` |
| H.1 Loading and readiness | Logic | Unit test — state machine transitions, getter-before-ready | `tests/unit/balance_data_layer/test_state_machine.gd`, `test_getters_before_ready.gd` |
| H.2 Validator rule enforcement | Logic (blocking) | Unit tests — one test function per rule (11 rules + failure modes) | `tests/unit/balance_data_layer/test_validator_rules.gd` |
| H.3 Wave-loop formula | Logic (blocking) | Unit tests — all boundary and case inputs listed in H.3 | `tests/unit/balance_data_layer/test_wave_loop_formula.gd` |
| H.4 API behavior | Logic (blocking) | Unit tests — getter hit/miss, immutability, typed return | `tests/unit/balance_data_layer/test_getter_api.gd` |
| H.4 No direct ResourceLoader | Config/Data | CI grep lint — no `ResourceLoader.load()` on `assets/data/` paths in `src/` | CI rule; no GdUnit4 file |
| H.5 Hot reload | Integration | Integration test — reload signal, old template retention, mid-wave stale instances | `tests/integration/balance_data_layer/test_hot_reload_integration.gd` |
| H.5 Hot reload — release guard | Visual/UI (advisory) | Manual smoke check on export build — press F5, confirm no reload | `production/qa/evidence/hot-reload-release-smoke.md` |
| H.6 Edge cases | Logic (blocking) | Unit tests covering all five E-section categories | `tests/unit/balance_data_layer/test_edge_cases.gd` |
| H.7 Boot time / getter cost | Performance | Automated benchmark with asserted threshold | `tests/performance/test_balance_boot_time.gd` |
| H.7 Memory ceiling | Performance | Manual smoke check on target Android hardware | `production/qa/evidence/balance-memory-smoke.md` |
| H.7 duplicate budget | Integration | Integration test with call counter instrumentation | `tests/integration/balance_data_layer/test_duplicate_budget.gd` |

**Minimum coverage gate**: Formula and validator code paths must reach 70% line coverage (GdUnit4 coverage report). CI blocks merge if coverage drops below the threshold.

**CI command to run all automated tests in this section** (per `.claude/docs/technical-preferences.md`):

```
godot --headless --import && godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/
```

**Blocking gates**: H.2 (validator logic), H.3 (formula), H.4 (API), and H.6 (edge cases) — all Logic/Integration story types per the test evidence matrix. H.5 release guard, H.7 memory ceiling, and the no-direct-ResourceLoader lint are advisory or CI-enforced.

## Open Questions

Known-unknowns carried forward from design. Each has an owner and the moment at which it must be resolved. "Owner = user" means a design-owner decision; "Owner = architecture" means a decision that belongs to `/architecture-decision`.

### OQ-1 Godot 4.6 `CACHE_MODE_IGNORE` constant name

The hot-reload sequence (Section C.1.8) relies on `ResourceLoader.CACHE_MODE_IGNORE`. This constant exists pre-4.4 but may have been renamed or reorganized in the 4.5 enum cleanup.
- **Impact if wrong**: hot reload silently uses cached Resources; designer sees no effect on F5.
- **Resolution**: verify in `docs/engine-reference/godot/modules/core.md` or a live 4.6 editor session before implementing C.1.8.
- **Owner**: architecture (engine-programmer to verify during first implementation sprint).
- **Target**: before `/create-stories` for the Balance Data Layer epic.

### OQ-2 Godot 4.6 `.tres` parse performance on Android

Engine-programmer estimated ~150–200 text `.tres` files are parseable within the 3s cold-start budget on mid-range Android 2020+ but could not confirm against 4.6-specific behavior.
- **Impact if wrong**: cold-start exceeds 3s on target hardware; the "Text .tres everywhere" decision from framing may need to flip to "binary `.res` in release".
- **Resolution**: measure on target hardware as part of AC-047. If boot time exceeds 500ms for the MVP manifest, re-open the binary-export framing question.
- **Owner**: architecture (performance-analyst + engine-programmer).
- **Target**: first playable build on target Android device.

### OQ-3 `@abstract` + `extends Resource` in 4.5/4.6

If a shared base class `BalanceResourceBase extends Resource` is introduced (not in the MVP schema but a plausible evolution), the post-4.4 `@abstract` decorator may have edge cases with non-Node base classes.
- **Impact if wrong**: refactoring to a shared base class breaks the schema at load time; fall back to file-scoped scripts.
- **Resolution**: only matters if `/architecture-decision` proposes a shared base. Revisit then.
- **Owner**: architecture (deferred).
- **Target**: as needed — not a blocker for MVP.

### OQ-4 Future `DropTableDefinition` family scope

Section C.1.1 leaves `EnemyDefinition.drop_table_id` as a foreign key to a "future DropTableDefinition" family. The shape of that family (weighted item IDs? conditional drops? guaranteed first-kill items?) is deferred to the Drop & Loot Tables GDD.
- **Impact on this GDD**: adding a `DropTableDefinition` Resource family will require updating Section C.1.1, Section C.1.2 (if new enums), and the validator rules (Section C.1.6 rule 8 extension to validate drop table references).
- **Resolution**: when Drop & Loot Tables GDD is authored. That GDD triggers `/propagate-design-change` against this one.
- **Owner**: user (via `/design-system drop-loot-tables` later).
- **Target**: as part of the Economy layer GDD batch.

### OQ-5 Debug-build template-mutation detection

Section C.1.5 recommends but does not mandate a debug-only guard that wraps every getter and detects whether a consumer has mutated a template (by hash-comparison with the load-time state).
- **Impact if skipped**: template mutations by a careless consumer become a silent, hard-to-reproduce bug in development; only surfaces when tests run and values differ.
- **Resolution**: implement opportunistically if bugs appear; code-review vigilance is the primary control.
- **Owner**: lead-programmer (decision to add when first bug lands, or proactively during the Balance Data Layer story).
- **Target**: post-MVP if no bugs surface.

### OQ-6 Single vs per-class CharacterProgressionCurve

Section C.1.1 locks MVP to a single global `CharacterProgressionCurve` with `id = &"default"`. If future design introduces character classes (warrior/mage/archer) with different progression curves, this assumption breaks.
- **Impact if wrong**: Save/Load must store a `curve_id` per character; a `current_curve_id` field is needed somewhere (Character Stats state or save file); Character Stats GDD's lookup pattern changes.
- **Resolution**: when/if a class/archetype system enters design. Not in MVP scope.
- **Owner**: user (via Game Concept or Character Stats GDD evolution).
- **Target**: as needed — never, if the game remains single-archetype.

### OQ-7 `effect_tags` validation — open vs closed

Section C.1.2 declares `SkillDefinition.effect_tags` as an **open** StringName array. This is intentional — Combat Engine interprets the tags and new tags should be addable without a Balance Data Layer change. But it means typos are silent: `&"stun"` and `&"stunn"` are both valid here, and only the Combat Engine will notice the mismatch.
- **Impact if wrong**: silent no-op effects on skills with typo'd tags.
- **Resolution**: Combat Engine GDD defines the canonical tag list; this GDD can then validate against that list via a cross-system constant. Deferred to Combat Engine GDD.
- **Owner**: user + Combat Engine GDD author.
- **Target**: when Combat Engine GDD is authored.
