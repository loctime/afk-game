# Balance Data Layer

> **Status**: In Design — Revised post-review (2026-05-01, pass 8 revisions applied)
> **Author**: User + game-designer + systems-designer
> **Last Updated**: 2026-05-01
> **Last Verified**: 2026-05-01
> **Review history**: see `design/gdd/reviews/balance-data-layer-review-log.md`
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

Estas Resources son **plantillas inmutables** en disco — los sistemas que necesitan estado per-instance (ej: un enemigo específico con HP actual) hacen `duplicate_deep()` al instanciar (Godot 4.5+ deep-copy API; the older `duplicate(true)` form is deprecated). Cualquier designer puede modificar valores en el editor de Godot sin tocar GDScript, y el sistema de versionado (git) provee histórico de cambios de balance. En runtime, un **`BalanceDatabase` autoload** ofrece lookup O(1) por ID (ej: `BalanceDatabase.get_enemy("slime_common")`) para los sistemas consumidores.

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
| `size_category` | `StringName` | yes | closed enum (`&"small"`, `&"medium"`, `&"large"`, `&"huge"`) |
| `sprite_path` | `String` | yes | path only; loading owned by Enemy System |
| `drop_table_id` | `StringName` | yes | foreign key → DropTableDefinition (future), `&""` = no drops |

**ItemDefinition**

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | — |
| `schema_version` | `int` | no | — |
| `display_name` | `String` | yes | — |
| `rarity` | `StringName` | yes | closed enum (`&"common"`, `&"rare"`, `&"epic"`, `&"legendary"`) |
| `slot` | `StringName` | yes | closed enum (13 values — see C.1.2) — one slot per concrete equipment position from concept §3.4 |
| `stat_roll_ranges` | `Dictionary` | yes | `{ StringName: Vector2(min,max) }`; keys validated against closed base-stat set (see C.1.2) |
| `icon_path` | `String` | yes | — |

**SkillDefinition**

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | — |
| `schema_version` | `int` | no | — |
| `display_name` | `String` | yes | — |
| `skill_type` | `StringName` | yes | closed enum (`&"attack"`, `&"heal"`, `&"buff"`, `&"debuff"`) |
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
| `wave_entries` | `Array[Dictionary]` | yes | dense; index = wave number (0-based). Each entry REQUIRED keys: `{ hp_mult: float, dmg_mult: float, spawn_count: int, enemy_ids: Array[StringName], loot_tier: int, is_boss: bool }`. `loot_tier` is an integer index consumed by Drop & Loot Tables to bias drop weights / minimum rarity floor per wave; the default authoring value is `0`. Balance Data Layer does not interpret `loot_tier` — it only validates the field exists and is a non-negative integer. Drop & Loot Tables GDD owns the semantics. `is_boss: bool` (default `false`) flags this wave as a boss encounter. Wave & Phase Manager reads this flag to trigger boss-gate flow, camera/music cues, and reward tables. Setting `is_boss: true` while `spawn_count > 1` emits a validator warning (boss waves typically spawn one boss enemy, but the data layer does not enforce single-spawn — that is Wave & Phase Manager's policy). |
| `loop_after_wave` | `int` | yes | -1 = no loop; otherwise index at which entries restart |
| `loop_hp_scale` | `float` | yes | per-loop HP multiplier compounded |
| `loop_dmg_scale` | `float` | yes | per-loop damage multiplier compounded |
| `allow_loop_seam` | `bool` | yes | default `false`. When `false`, Rule 12 (loop-boundary difficulty drop) fails in release builds. Set to `true` to explicitly accept an intentional difficulty reset at the loop seam (debug still warns either way). This is the pillar-protection override for "ver personaje crecer" — see C.1.6 Rule 12. |

**CharacterProgressionCurve** (single global instance for MVP; multi-class deferred)

| Field | Type | Tunable | Notes |
|---|---|---|---|
| `id` | `StringName` | no | `&"default"` for MVP |
| `schema_version` | `int` | no | — |
| `xp_per_level` | `Array[float]` | yes | index 0 unused (= 0); length = `max_level + 1` |
| `max_level` | `int` | yes | must equal `xp_per_level.size() - 1` |
| `hp_per_vit` | `float` | yes | — |
| `defense_per_vit` | `float` | yes | damage-reduction coefficient applied per VIT point; concept §7.2 ("VIT reduces damage received"). Combat Engine GDD owns the exact reduction formula. |
| `mana_per_int` | `float` | yes | — |
| `atk_per_str` | `float` | yes | — |
| `speed_per_dex` | `float` | yes | — |
| `base_stats` | `Dictionary` | yes | `{ &"str": int, &"dex": int, &"int": int, &"vit": int }` at level 1. **Keys are `StringName` literals** (note the `&` prefix) — matching the closed base-stat namespace in C.1.2 and `stat_roll_ranges` key type. Using plain `String` keys would silently mismatch StringName comparisons. |
| `stat_points_per_level` | `int` | yes | — |

#### C.1.2 Closed enum sets

The following `StringName` fields are validated against code-defined constant sets. Adding a value is a one-line code edit, not a schema bump.

- `EnemyDefinition.behavior_tag` ∈ `{ &"melee", &"ranged", &"aggressive", &"tank" }` — aligned to concept §6.1. Combat Engine GDD may extend this set; removals require a schema bump.
- `EnemyDefinition.size_category` ∈ `{ &"small", &"medium", &"large", &"huge" }` — `&"huge"` reserved for boss-scale encounters (concept §6.4, "Enorme").
- `ItemDefinition.rarity` ∈ `{ &"common", &"rare", &"epic", &"legendary" }`
- `ItemDefinition.slot` ∈ `{ &"helmet", &"chest", &"pants", &"boots", &"gloves", &"shield", &"weapon", &"necklace", &"wings", &"bracelet", &"ring", &"artifact", &"pet" }` — one value per concrete equipment position from concept §3.4. Slots that appear twice in the UI layout (e.g. two Ring slots) share the same enum value; Inventory & Equipment GDD owns the per-slot-count logic.
- `ItemDefinition.stat_roll_ranges` keys ∈ `{ &"str", &"dex", &"int", &"vit" }` — **base stats only**. ATK and DEF are derived values computed by Character Stats from these four inputs (see concept §7.2); items never roll derived stats directly. This keeps the item comparison UI unambiguous: every roll is in the same namespace.
- `SkillDefinition.skill_type` ∈ `{ &"attack", &"heal", &"buff", &"debuff" }` — matches concept §4.3. Priority-selection AI in Combat Engine classifies skills by this field.
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
signal balance_database_reloaded(success: bool)   # fired after a hot reload (see C.1.8); success=false if reload's validator reported errors and old templates were retained
signal balance_load_failed                         # fired only in release when boot validation failed

# --- Test injection seams (see AC-018/019/031/032) ---
# Two fields default to the production value but can be swapped in tests to
# exercise the release-path control flow under a debug engine binary.
var _is_debug: bool = OS.is_debug_build()
var _error_reporter: Callable = func(msg: String) -> void: push_error(msg)
var _warning_reporter: Callable = func(msg: String) -> void: push_warning(msg)
# _warning_reporter mirrors _error_reporter: swap in tests to capture push_warning calls
# (e.g., AC-026, AC-053, AC-051a, AC-051b). Production value emits via push_warning.
# --- Reporter routing contract (required for testability) ---
# ALL warning output in this module MUST route through _warning_reporter.
# ALL error output MUST route through _error_reporter.
# Direct push_warning() / push_error() calls in production code paths are FORBIDDEN —
# bypassing these reporters makes AC-026, AC-051a/b, AC-053, AC-018, AC-032, AC-041, AC-029, AC-029b untestable.

# Session-scoped one-time warning tracking (owned by BalanceDatabase, not by the Resource):
var _warned_no_loop_curves: Dictionary[StringName, bool] = {}
# Keyed by WaveScalingCurve.id (StringName). Populated on the first out-of-bounds query
# for a curve with loop_after_wave == -1 and w >= wave_entries.size(). Never cleared
# within a session. Prevents spam from AFK-mode wave-advance loops. Lives on
# BalanceDatabase (not on the template) because templates are immutable and must not
# hold mutable session state.

# Validation error accumulator — reset at the start of each validation run.
var _validation_errors: Array[String] = []
# Accumulates all Rule violation messages during a single boot/hot-reload validation
# pass. Cleared to [] at validation start; never shared between passes. Required by
# the "collect all errors, then assert" pattern below. Tests can read this member
# after injecting _is_debug = false to assert which specific errors were logged
# (see AC-018, AC-019).

# NO _assert_handler Callable. `assert` is a compile-time directive in GDScript;
# wrapping it in a Callable breaks AC-019's "collect all errors, then terminal
# assert" contract (a Callable halts on first invocation, preventing the
# multi-error collection the validator requires). The correct pattern is:
#   1. Validator accumulates failures into _validation_errors: Array[String]
#   2. After all rules run, if _is_debug and _validation_errors.size() > 0:
#        assert(false, "BalanceDatabase boot validation failed:\n" +
#                      PackedStringArray(_validation_errors).join("\n"))
#
# Test coverage boundary (important — do NOT claim more than this):
#   * `_is_debug = false` in a test exercises the runtime control flow as if
#     in release: the `if _is_debug:` branch is not entered, no assert fires.
#     This is what AC-018/019/032 automate.
#   * `_is_debug = true` + assert firing cannot be automated under GdUnit4 —
#     native `assert(false)` terminates the process; there is no signal,
#     exception, or invertible failure to catch. AC-031 and the debug branch
#     of AC-019 are manual-smoke-check items, not automated tests.
#   * The `_is_debug` flag controls runtime branching only. GDScript strips
#     `assert()` from release exports regardless of the flag — proving the
#     binary has no assert is a separate, export-time concern.
```

**Autoload ordering — hard constraint (not an edge case).** `BalanceDatabase` MUST be registered as the **first autoload** in Project Settings → Autoload. Any autoload listed before it cannot safely call getters or `await database_ready` — the signal may already have fired (deadlock) or not yet fired (getter returns `null`). A peer autoload listed AFTER `BalanceDatabase` is safe because Godot runs autoload `_ready()` calls sequentially and synchronously; by the time the peer's `_ready()` runs, `is_ready == true`. The guarded-await idiom below handles the narrow case of deferred signals that may fire after `database_ready` emission.

**Guarded await pattern for consumers.** Any consumer that may run before `BalanceDatabase._ready()` completes (peer autoloads, deferred signals) MUST use this idiom — a bare `await BalanceDatabase.database_ready` will block forever if the signal already fired:

```gdscript
if not BalanceDatabase.is_ready:
    await BalanceDatabase.database_ready
# safe to call getters from here
```

**Miss contract** (consistent across all getters):

- **Debug builds**: `assert(result != null, "BalanceDatabase: unknown <family> id '%s'" % id)` — crash loudly.
- **Release builds**: `push_error(...)` and return `null`. Consumers guard at the call site.
- No fallback sentinel Resources. Silent "default enemy" returns are forbidden.

Consumers that may run before autoloads finish must await `database_ready`. In practice the main scene's `_ready()` already fires after all autoloads, so this only matters for peer autoloads listed after `BalanceDatabase`.

#### C.1.5 Template / instance rule

- Resources returned by `BalanceDatabase` getters are **templates** — treat as read-only.
- Systems that need mutable per-instance state (Enemy System spawning a live enemy, Item System rolling stats on a drop) must call `resource.duplicate_deep()` **exactly once at instantiation** and store the instance on the owning node. Never duplicate per-frame.
  - **Godot 4.5+ API:** `duplicate_deep()` was introduced in Godot 4.5 as the explicitly-named deep-copy method for Resources. The older `duplicate(true)` form still functions but should not appear in new code authored against the 4.6 pin — prefer the self-documenting `duplicate_deep()` name. Every consumer MUST use `duplicate_deep()` — no `duplicate(true)` call sites are permitted in code authored against the 4.6 pin.
- `WaveScalingCurve` and `CharacterProgressionCurve` are read-only lookups — never duplicated.
- Consumer pattern: cache the typed reference at node init; do not call back into `BalanceDatabase` from `_process` / `_physics_process` / per-hit signals.
- **Nested Node-derived or physics sub-resources inside Balance Resources are forbidden** — they make `duplicate_deep()` cost unbounded. Balance Resources hold only primitives, StringNames, typed arrays, Dictionaries, and Vector2/3.

#### C.1.6 Boot-time validation

`BalanceDatabase._ready()` runs `_validate_all()` before setting `is_ready = true`. All failures are collected, then reported.

Rules checked:

1. Every path in `BalanceManifest.paths` resolves to a loadable file.
2. Every loaded Resource's `schema_version` equals its family's `CURRENT_SCHEMA` constant.
3. No duplicate `id` within a family (cross-family ID collisions are allowed).
4. All required fields are non-null; `id` is non-empty (`&""` is invalid). **`CharacterProgressionCurve.base_stats` structural check**: the Dictionary must contain exactly the four keys `{&"str", &"dex", &"int", &"vit"}` (StringName literals) and each value must be a non-negative `int`. Missing keys, extra keys (allowed, warned), or non-`int` values each fail Rule 4 with the offending key named. (Rule 10 performs an analogous structural check for `ItemDefinition.stat_roll_ranges`.)
5. Numeric invariants: `base_hp > 0`, `base_damage > 0`, `mana_cost ≥ 0`, `cooldown_sec ≥ 0`, `scaling_coefficient` finite, `hp_per_vit ≥ 0`, **`defense_per_vit > 0`** (strict — `= 0` silently removes VIT's damage-reduction role per concept §7.2; pillar-protection invariant), `mana_per_int ≥ 0`, `atk_per_str ≥ 0`, `speed_per_dex ≥ 0`, **`stat_points_per_level ≥ 0`** (negative value subtracts stat points on level-up — nonsense state), **`WaveScalingCurve.loop_hp_scale > 0`, `WaveScalingCurve.loop_dmg_scale > 0`**, every `wave_entries[i].hp_mult > 0` and `wave_entries[i].dmg_mult > 0`, every `wave_entries[i].spawn_count ≥ 0`, every `wave_entries[i].loot_tier ≥ 0`. No `loop_*_scale` upper bound is enforced, but values `>= 2.0` emit a tuning warning (see G.2).
6. Closed-enum fields (see C.1.2) contain only allowed values.
7. `WaveScalingCurve.wave_entries` is dense (no gaps); `loop_after_wave ∈ [-1, wave_entries.size())`. **Every entry Dictionary must contain all required keys with correct types**: `hp_mult: float`, `dmg_mult: float`, `spawn_count: int`, `enemy_ids: Array[StringName]`, `loot_tier: int`, `is_boss: bool`. Missing or mistyped keys fail validation with the offending wave index and key named. Extra keys are allowed (ignored with a warning) to support forward-compat authoring. Two `is_boss`-related validator checks:
- **Validator warning** (not fail) if `is_boss: true` AND `spawn_count == 0` — unusual authoring; Wave & Phase Manager semantics for a zero-spawn boss wave are deferred to that GDD (not yet authored). Warning: `"is_boss: true with spawn_count: 0 at wave_entries[i] — boss with zero spawn count; verify encounter design intent (see game-concept.md §5.3)."` The curve is NOT excluded from `_templates`. (AC-011c)
- **Validator warning** (not fail) if `is_boss: true` AND `spawn_count > 1` — unusual authoring that Wave & Phase Manager should handle explicitly, but may be intentional (multi-boss encounter). (AC-011b)
8. Every `enemy_ids` entry in every `WaveScalingCurve` resolves to a known EnemyDefinition.
9. `CharacterProgressionCurve.max_level == xp_per_level.size() - 1`, `xp_per_level[0] == 0`, every `xp_per_level[i]` for `i >= 1` is finite and strictly greater than `xp_per_level[i-1]` (monotonic). No gameplay-sanity bound is enforced; Character Stats & Leveling GDD owns the curve-shape safe range.
10. `ItemDefinition.stat_roll_ranges` keys are all in the closed base-stat set (see C.1.2); every value `Vector2(min, max)` satisfies `min <= max` and both components are finite.
11. `BalanceManifest` itself loads and is non-empty.
12. **Loop-boundary invariant (severity depends on build + override)**: **Rule 12 is skipped entirely when `loop_after_wave == -1`** — no loop exists, therefore no seam exists; the validator does not evaluate any inequality for the curve. (This guard is load-bearing: GDScript's `wave_entries[-1]` would silently wrap to the last element and produce spurious comparisons otherwise.) When `loop_after_wave >= 0`, the difficulty seam `wave_entries[0].hp_mult * loop_hp_scale` SHOULD be `>= wave_entries[loop_after_wave].hp_mult`, AND the same relation must hold for `dmg_mult` (`wave_entries[0].dmg_mult * loop_dmg_scale >= wave_entries[loop_after_wave].dmg_mult`). A violation in either field means the player experiences a difficulty drop at the wave transitioning from pre-loop to first loop — a pillar-level regression for "ver personaje crecer" (in an AFK game the player cannot self-detect this). Note on degenerate case: when `loop_after_wave == 0` the seam reduces to `loop_hp_scale >= 1.0` (and the `dmg` analogue) — trivially satisfied for any non-decelerating curve. Designers using a 1-entry loop span have tuning responsibility through curve-shape alone; Rule 12 does not police them further.
    - **Debug builds**: warning only, regardless of `allow_loop_seam`. The offending curve id, the violating field (`hp_mult` / `dmg_mult` / both), and the computed drop percentage are reported. Boot continues.
    - **Release builds with `allow_loop_seam == false` (default)**: **validation fails**. The curve is dropped from `_templates`; `balance_load_failed` is emitted. The pillar is protected by default.
    - **Release builds with `allow_loop_seam == true`**: warning only. The curve loads. Use only when a designer has an explicit reason to accept the seam.
    - This rule only checks the seam at `wave_entries[0]` vs `wave_entries[loop_after_wave]` — intra-loop cliffs (entry N where `N > 0` is drastically higher than entry 0 scaled) are out of scope for this layer; they belong to Wave & Phase Manager GDD as curve-shape guidance. AC coverage is in H.7b (AC-051a/b/c/d).

**Failure mode:**

- Debug builds: `_error_reporter.call()` per violation, then `assert(false)` after collecting all errors (so all problems are reported, not just the first).
- Release builds: write errors to a log, skip the offending Resources, emit a `balance_load_failed` signal. The game chooses to show an error screen or continue degraded.

#### C.1.7 Schema evolution

Each Resource class declares its **own** `const CURRENT_SCHEMA: int = N` — schemas evolve per-family independently. A file whose `schema_version` is less than its class's constant fails validation rule 2 — **no silent runtime migration.** The migration tool (below) must know which family each Resource belongs to and compare against the right constant.

Migration is a designer-tooling step: `tools/migrate_balance.gd` (editor script) reads old Resources, applies field transforms, writes new ones with the bumped version. Run manually before committing schema-breaking changes.

**Additive-field rule:** Purely additive fields (no existing consumer reads, no changed semantics) do not require a schema bump — but their default MUST be declared inline on the `@export` line (`@export var new_field: float = 1.0`). Godot's Resource deserializer fills missing fields from the `@export` default at load time; a default set only in `_init()` does NOT apply when an older `.tres` is loaded. (Cross-reference E.5 — this is the canonical statement.)

#### C.1.8 Hot reload (dev builds only)

A debug-build hotkey (configurable; default `F5`) invokes `BalanceDatabase.hot_reload()`. Release builds do not bind this action.

Concrete sequence:

```gdscript
func hot_reload() -> void:
    # Load into a fresh dictionary using CACHE_MODE_IGNORE. The returned Resource
    # MUST be used directly — discarding it and re-calling load() later would hit
    # the stale cached entry (CACHE_MODE_IGNORE bypasses the cache only for the
    # returned reference; it does NOT evict the cache entry). See OQ-1 for the
    # 4.6 constant-name verification gate.
    var new_templates: Dictionary = {}
    for path in _manifest.paths:
        var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
        _add_to_templates(new_templates, res)
    var ok: bool = _validator.validate_all(new_templates)
    if ok:
        _templates = new_templates  # atomic replace on success
    # else: retain existing _templates (state machine RELOADING → READY with errors)
    balance_database_reloaded.emit(ok)
```

The `success: bool` argument is REQUIRED — it is declared on the typed signal signature in C.1.4 (`signal balance_database_reloaded(success: bool)`); the direct-object `.emit()` form is the correct Godot 4.x idiom (the deprecated string-based `emit_signal("name", ...)` bypasses compile-time arity checking — do not use it). Godot 4.6 enforces typed signal arity at runtime for the `.emit()` call path.

Already-duplicated instances in the active scene are **intentionally stale** after reload (they are independent copies — `duplicate_deep()` breaks the reference chain). Consumers that want to apply reloaded values to live instances listen on `balance_database_reloaded` and decide per-system whether to re-fetch — that is a gameplay concern, outside this GDD.

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
- Consumers must not call `BalanceDatabase` getters during `_init()` of any `Node` or `Resource` — `_init()` runs at duplication time (including `duplicate_deep()` of Resources), which is outside the autoload-ready guarantee.

### Interactions with Other Systems

The Balance Data Layer has **no runtime input** from any other system. All 8 consumers are read-only: they call `BalanceDatabase` getters, treat returned templates as immutable, and `duplicate_deep()` when per-instance state is needed. Consumers MUST NOT call `BalanceDatabase` directly on any hot path — in particular, Combat Engine reads only from instances pre-warmed by Enemy/Skill/Character systems and never calls `BalanceDatabase` itself (the per-frame-getter lint in AC-052 enforces the hot-path subset; the "never direct" rule is a hard contract for Combat Engine even outside `_process`).

#### Interaction matrix

| Consumer system | Reads (families) | Call timing | Instance handling |
|---|---|---|---|
| Save/Load System | any family's `has_*` + `get_*` | boot + save-write + save-load | none — ID validation only |
| Character Stats & Leveling | `CharacterProgressionCurve` | wave-start + level-up events | no duplication (read-only lookup) |
| Item System | `ItemDefinition` | drop roll + equip event | `duplicate_deep()` per rolled item |
| Combat Engine | `EnemyDefinition`, `SkillDefinition`, `CharacterProgressionCurve` | wave-start (pre-warm); skill/stat values read from cached instance refs | reads instances owned by Enemy/Skill/Character systems — **Combat Engine must NEVER call `BalanceDatabase` directly at any point** (hard contract, not just hot-path lint) |
| Enemy System | `EnemyDefinition` | wave-start (pre-warm batch); enemy-spawn event | `duplicate_deep()` per spawned enemy |
| Skill System | `SkillDefinition` | character-init + skill-unlock event | `duplicate_deep()` per learned skill (holds cooldown state) |
| Wave & Phase Manager | `WaveScalingCurve`, `EnemyDefinition` (via wave entries) | wave-start | no duplication (curve is read-only; spawning enemies is Enemy System's job) |
| Drop & Loot Tables | `ItemDefinition`, `EnemyDefinition.drop_table_id` | enemy-death event | no duplication (delegates item creation to Item System) |

#### Per-consumer contracts

**Save/Load System** — Saves store IDs (`StringName`), never Resource contents. On save-load, Save/Load calls `BalanceDatabase.has_enemy(id)` / `has_item(id)` / etc. to validate every referenced ID still exists after balance changes. A missing ID is handled by Save/Load's own policy (warn/drop/upgrade) — Balance Data Layer does not opine. Save/Load waits on `database_ready` before validating.

**Character Stats & Leveling** — At wave-start, fetches the single `CharacterProgressionCurve` (MVP: always `&"default"`) and caches a typed reference for the duration of the session. Reads `xp_per_level[level]`, `hp_per_vit`, etc. as read-only values. On level-up, re-reads from the cached reference — no new database call. On `balance_database_reloaded`, refreshes the reference.

**Item System** — When rolling a drop, calls `get_item(id)` once, then `duplicate_deep()` to create the rolled instance, then reads `stat_roll_ranges` and writes the rolled stats onto the duplicated Resource's own fields (or onto a parallel runtime struct; see C.1.5). The rolled instance's `id` is kept identical to the template's `id` — save files reference items by `id` plus a rolled-stat blob, not by the duplicated Resource.

**Combat Engine** — Never calls `BalanceDatabase` on the hot path. Reads values (enemy `base_damage`, skill `scaling_coefficient`, curve `atk_per_str`) from the instance references owned by Enemy/Skill/Character systems, which those systems fetched and cached earlier. Combat Engine's role is pure calculation over values already in hand.

**Enemy System** — At wave-start, receives the upcoming wave's `enemy_ids` list from Wave & Phase Manager and **pre-warms** all needed templates using a typed array built explicitly (note: `Array.map()` returns an untyped `Array` in GDScript 4.x — direct assignment to `Array[EnemyDefinition]` fails at runtime):
```gdscript
var defs: Array[EnemyDefinition] = []
for id: StringName in ids:
    defs.append(db.get_enemy(id))
```
Per-enemy spawn then calls `defs[i].duplicate_deep()` to produce the live enemy's data. Mid-wave database calls are forbidden.

**Skill System** — On character init (game start or save load), calls `get_skill(id)` once per unlocked skill and `duplicate_deep()` to hold mutable per-instance state (current cooldown, stack counts). Stores instances keyed by `id`. On skill unlock mid-run, calls `get_skill` + `duplicate_deep()` for the newly learned skill.

**Wave & Phase Manager** — At wave-start, calls `get_wave_curve(curve_id)` once to resolve the curve for the current run. Indexes into `wave_entries[wave_number]` (or applies the loop logic if past `loop_after_wave`) to determine spawn_count, enemy_ids, multipliers. Never duplicates the curve — it's a read-only lookup table. Passes the resolved enemy_ids and multipliers to Enemy System for spawn.

**Drop & Loot Tables** — On enemy death, reads `enemy_instance.drop_table_id` (already held on the duplicated instance). If non-empty, consults the future `DropTableDefinition` family (out of MVP scope — flagged in Open Questions) to resolve drops. For MVP, a simple rarity-weighted lookup against `BalanceDatabase` item list is acceptable; the Loot system's GDD specifies the rolling policy. Balance Data Layer provides the data; rolling logic is owned by Loot.

#### Boundary that does NOT exist

**Audio System, UI Framework, Animation Controller, Status Effects, Revive & Game Over** do not read from the Balance Data Layer at runtime. Their tunables (volumes, UI sizes, animation speeds, revive costs, status timings) live in their own config Resources or Project Settings. This keeps the Balance Data Layer focused on *gameplay math* — enemies, items, skills, curves — rather than becoming a global config dumping ground.

#### Interaction ownership

- `BalanceDatabase` **owns** the getter API and the template lifecycle.
- Each consumer **owns** its per-instance state (duplicated Resources, cached references, runtime structs).
- Neither side owns the *rolled values* or *runtime state* of a duplicated Resource — that belongs to the consumer that duplicated it.

#### `balance_load_failed` recommended handler policy

When `balance_load_failed` is emitted in a release build, the Balance Data Layer has done its job (errors logged, offending Resources dropped from `_templates`, `is_ready` stays `false`). The game-level handler policy is **not owned by this GDD** but the recommended default — binding on the highest-level consumer (typically Game State Manager or the main scene) — is:

- **Show a hard error screen** identifying that balance data failed to load, with a "report this bug" affordance and an exit button.
- **Do NOT continue in degraded mode** (playing with missing enemies, broken curves, or invisible items is a worse player experience than a clean error, and makes bug reports ambiguous).

Rationale: solo-indie AFK RPG context means the most likely cause of `balance_load_failed` in a shipped build is a packaging error (a `.tres` missing from the export) or a schema-migration oversight. In both cases, the player cannot recover at runtime and should not be asked to play through it. A consumer GDD may override this recommendation with an explicit rationale in its own Dependencies section.

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
| loop cycle | `loop_count(w)` | int | 0 .. unbounded | 1-indexed loop number once looping is active (wave immediately past `loop_after_wave` has `loop_count == 1`). For waves `w <= loop_after_wave` (including the no-loop case `-1`), `loop_count == 0` and no `loop_*_scale` multiplier is applied. |
| entry index | `e` | int | 0 .. (loop_span - 1) | Which `wave_entries` entry to read |
| per-entry HP mult | `wave_entries[e].hp_mult` | float | > 0.0 (validator-enforced) | Authored base HP multiplier |
| per-entry damage mult | `wave_entries[e].dmg_mult` | float | > 0.0 | Authored base damage multiplier |
| loop HP scale | `loop_hp_scale` | float | > 0.0 | Per-loop compounding factor on HP |
| loop damage scale | `loop_dmg_scale` | float | > 0.0 | Per-loop compounding factor on damage |
| output HP mult | `effective_hp_mult(w)` | float | ≥ 0.0, unbounded above | Multiplier consumed by Combat Engine for enemy HP. Can reach exactly 0.0 via f64 subnormal underflow when `loop_hp_scale < 1.0` at extreme wave counts (see E.2); consumer systems must apply a floor. |
| output damage mult | `effective_dmg_mult(w)` | float | ≥ 0.0, unbounded above | Multiplier consumed by Combat Engine for enemy damage. Same subnormal-underflow caveat as HP mult. |

**Output Range:** Both outputs are non-negative floats (`≥ 0.0`), unbounded above. They can reach exactly `0.0` via f64 subnormal underflow when `loop_*_scale < 1.0` at extreme wave counts — `is_finite(0.0)` returns `true`, so the INF guard does not catch this. Consumer systems **must** apply their own floor (e.g., ≥ 0.01). This formula does **not** clamp — see E.2 for the de-escalating-scale edge case. Entries past index `loop_after_wave` in the array are ignored when looping is active (validator warns at boot but doesn't fail).

**Mandatory implementation guards — runtime-safe (survive release builds).** `assert()` is compile-time-stripped from release exports in GDScript, so guards that must run in shipped binaries MUST use `push_error` + explicit fallback, NOT `assert`. The validator is the primary gate; these runtime guards are a belt-and-braces secondary that must still work when the validator was bypassed (e.g., tool scripts, tests constructing curves in memory, or a release build where a validation failure dropped the curve):

```gdscript
# LOCAL VARIABLE REQUIREMENT — `loop_hp_scale` and `loop_dmg_scale` MUST be
# declared as LOCAL variable copies before the guards below.
# (Reading `curve.wave_entries[...]` directly is safe — reads do not mutate the template.)
# Example preamble:
#   var loop_hp_scale: float = curve.loop_hp_scale
#   var loop_dmg_scale: float = curve.loop_dmg_scale
# Assigning `loop_hp_scale = 1.0` or `loop_dmg_scale = 1.0` below reassigns the
# LOCAL variable only. Writing back to `curve.loop_hp_scale` would mutate the
# immutable template (C.1.5) — corrupting every future caller for this curve.
#
# SCOPE REQUIREMENT — `e` (entry index) and `loop_count` MUST be declared at
# FUNCTION scope with safe defaults BEFORE the branching block, not inside it.
# The INF guard (after the main formula) references `wave_entries[e]` as the
# fallback — if `e` is block-scoped inside the looping else-branch, GDScript
# raises a compile error ("Identifier not declared in current scope") or
# silently reads a different outer `e`. Required preamble:
#   var e: int = wave_entries.size() - 1  # safe default: last entry (pre-loop path)
#   var loop_count: int = 0               # safe default: no looping
# Both variables are reassigned inside the Else (w > loop_after_wave) branch.

# At formula entry — reject degenerate inputs the validator would have caught.
# Guard order: empty-array check FIRST (avoids OOB on wave_entries[0] in the w<0 return).
if wave_entries.is_empty():
    _error_reporter.call("effective_*_mult: wave_entries is empty for curve '%s'; returning safe default" % curve.id)
    return { &"hp_mult": 1.0, &"dmg_mult": 1.0, &"loop_count": 0 }
if w < 0:
    _error_reporter.call("effective_*_mult called with w=%d (< 0); returning wave_entries[0]" % w)
    return { &"hp_mult": wave_entries[0].hp_mult, &"dmg_mult": wave_entries[0].dmg_mult, &"loop_count": 0 }
if loop_hp_scale <= 0.0:
    _error_reporter.call("loop_hp_scale must be > 0 (got %f); clamping to 1.0" % loop_hp_scale)
    loop_hp_scale = 1.0  # plateau — no compounding
if loop_dmg_scale <= 0.0:
    _error_reporter.call("loop_dmg_scale must be > 0 (got %f); clamping to 1.0" % loop_dmg_scale)
    loop_dmg_scale = 1.0

# ... compute effective_hp_mult and effective_dmg_mult per formula ...

# At formula output — reject INF / NaN (large loop_*_scale compounds beyond
# DBL_MAX around wave ~1,550 for scale=100, ~10,240 for scale=2.0).
# Passing INF downstream becomes NaN in Combat Engine's damage math (INF * 0 = NaN),
# which propagates silently and breaks HP display + hit detection.
# Fallback policy: return wave_entries[e] UNSCALED (authored baseline for the
# current entry, loop_count ignored) — degrades gracefully to a difficulty plateau
# at the authored value rather than a hard reset to wave 0.
if not is_finite(effective_hp_mult) or not is_finite(effective_dmg_mult):
    _error_reporter.call("effective_*_mult overflowed at w=%d (hp=%s, dmg=%s); returning wave_entries[%d] unscaled" % [
        w, str(effective_hp_mult), str(effective_dmg_mult), e
    ])
    return {
        &"hp_mult": wave_entries[e].hp_mult,
        &"dmg_mult": wave_entries[e].dmg_mult,
        &"loop_count": loop_count,  # preserve loop_count for telemetry; scaling skipped
    }
```

**Why `_error_reporter` + fallback, not assert:** `assert(is_finite(...))` would be a no-op in the shipped release binary (GDScript strips `assert()` at export time). A player reaching wave ~1,550 in a release build would then see INF propagate into Combat Engine as NaN, silently breaking HP display and hit detection. `_error_reporter` (backed by `push_error` in production) fires in both debug and release; the explicit `return` guarantees downstream systems receive a finite value even at overflow boundaries.

The negative-`w` fallback returning `wave_entries[0]` (not `wave_entries[-1]`, which GDScript would wrap to the last element — silent semantic error) is the safe default covered by AC-029.

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

- **If `wave_entries` is empty and a caller queries the curve**: validator fails at boot (rule 7). Runtime guard routes through `_error_reporter` (per the reporter routing contract in C.1.4) and returns `{ &"hp_mult": 1.0, &"dmg_mult": 1.0, &"loop_count": 0 }` — three-field StringName-keyed dict matching the canonical D.1 return signature so consumers can safely read `result[&"loop_count"]`; the game continues degraded rather than crashing in release. Debug builds assert.
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
- **If a consumer mutates a returned template without `.duplicate_deep()` first**: the shared cache is corrupted for the rest of the session. Detection: optional debug-build guard that wraps every getter and asserts the returned object's hash matches its load-time hash. Mitigation: strict code review + consumer-side do/don't rules (see C.1.5).

### E.5 Schema evolution

- **If a Resource's `schema_version` is lower than the class's `CURRENT_SCHEMA`**: validator fails at rule 2 — no silent runtime migration. Designer runs `tools/migrate_balance.gd` in the editor, commits migrated Resources.
- **If a new field is added purely additively**: the field MUST declare its default inline on the `@export` line (`@export var new_field: float = 1.0`), not in a separate `_init()` assignment. Godot's Resource deserializer fills missing fields from the `@export` default at load time; `_init()`-only defaults don't apply.
- **If an old `.tres` predates the `schema_version` field entirely**: Godot loads the Resource with `schema_version = 0` (int default). Rule 2 catches the mismatch. The migration tool must recognize and handle `schema_version == 0` explicitly as "pre-versioning," not treat it as "version 0."
- **If a field is renamed**: bump `schema_version`, update the migration tool, run it before the commit. The renamed field's old name is not remembered by Godot — old files must be migrated or they load with the old value dropped.
- **If a field is removed but the `.tres` still has it**: Godot ignores unknown properties at load. Safe to remove fields as long as no code still reads them. Schema bump is still required so future reloads flag the intent.
- **If `schema_version > CURRENT_SCHEMA`** (future file loaded on older code — e.g., a designer checks out an older branch after a schema bump, or a save bundle from a later build is loaded by a hotfix rollback): Rule 2 fails as normal (the inequality is strict, not only "lower than"). `tools/migrate_balance.gd` MUST detect this case, refuse to run (a downgrade has no safe default for fields that did not yet exist when the older code was written), and print a clear error directing the designer to update their codebase rather than attempt a downgrade. The migration tool never attempts to remove fields that exist in the file but not in the older schema.

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

### F.2b Design constraint on upstream game-concept

**CharacterProgressionCurve assumes a single-archetype player.** The current `CharacterProgressionCurve` schema is a single global instance with `id = &"default"` (C.1.1). This encodes a design assumption inherited from `design/gdd/game-concept.md`: the player is one character type whose stats grow via a shared curve. If the game concept evolves to introduce character classes (warrior/mage/archer with different HP/stat curves — see OQ-6), this assumption breaks and triggers a schema bump: `CharacterProgressionCurve` becomes multi-instance, a `curve_id` must be stored per character in Save/Load, and Character Stats GDD's lookup pattern changes.

**Contract:** the game-concept MUST NOT introduce a class/archetype system without triggering `/propagate-design-change` against this GDD. Surfacing this here (rather than only in OQ-6) makes the constraint visible to the creative-director during any future concept revision.

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

**Important:** `spawn_count` is used **as-is** from `wave_entries[e]` on every loop cycle — it does **not** compound with `loop_count`. The number of enemies per wave stays at the authored value regardless of loop depth. To scale spawn count per loop, Wave & Phase Manager GDD owns that logic (additive migration path exists: add a `loop_spawn_scale: float = 1.0` field in a future schema bump).

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
- **Designer authoring notes (provisional)**: [`design/gdd/balance-data-layer-authoring-notes.md`](balance-data-layer-authoring-notes.md) — 5-step quick-start + provisional safe ranges for each Resource family, pending consumer-GDD ownership per G.1. Kept adjacent to this GDD rather than embedded to preserve G.1's ownership model.
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

- **AC-001b (complement — no spurious failure signal on clean load)** GIVEN the game launches with a valid `BalanceManifest.tres` WHEN `BalanceDatabase._ready()` completes THEN `balance_load_failed` has NOT been emitted. This is the complement of AC-001: a `balance_load_failed` signal that fires unconditionally would pass AC-001 but fail AC-001b.
  _How tested: integration test in `tests/integration/balance_data_layer/test_boot_ready.gd` — same fixture as AC-001; assert that `balance_load_failed` signal connection counter == 0 during the boot sequence._

- **AC-002 (pre-ready getter — release path, observable effects)** GIVEN `BalanceDatabase` is in state UNLOADED or LOADING AND `_is_debug = false` injected WHEN any getter is called THEN: (a) `null` is returned, (b) `_error_reporter` is invoked with a non-empty message, (c) `is_ready` remains `false`, (d) no assert fires (the `if _is_debug:` branch is not entered). This AC proves the release-path control flow; it does NOT prove the compiled release binary lacks an assert instruction (GDScript strips `assert()` at export regardless of the `_is_debug` flag).
  _Unit test: `tests/unit/balance_data_layer/test_getters_before_ready.gd` — injects `_is_debug = false`, calls getter in pre-ready state via deferred pre-check, asserts reporter call count ≥ 1, return value is `null`, `is_ready` unchanged._

- **AC-002b (pre-ready getter — debug-assert branch, manual evidence)** In a debug build the getter additionally fires a terminal `assert(false, ...)` under the `if _is_debug:` branch. **This sub-criterion is NOT automated** — native GDScript `assert(false)` terminates the process and cannot be caught by GdUnit4. Verification is via manual debug run documented in `production/qa/evidence/balance-getter-miss-debug-smoke.md` (same evidence file as AC-031 debug-miss check). ADVISORY gate — does not block merge; manual sign-off required before Foundation milestone close.

- **AC-003** GIVEN boot validation succeeds WHEN state machine transitions are traced THEN the sequence is exactly UNLOADED → LOADING → VALIDATING → READY with no skipped or repeated states.
  _How tested: unit test in `tests/unit/balance_data_layer/test_state_machine.gd` — instrument state transitions with a log array._

- **AC-004** GIVEN a peer autoload listed after `BalanceDatabase` WHEN that autoload's `_ready()` runs THEN checking `is_ready` returns `true` without needing to await `database_ready`.
  _How tested: integration test in `tests/integration/balance_data_layer/test_peer_autoload_ordering.gd` — register a dummy peer autoload and assert `is_ready` at its `_ready` entry point._

### H.2 Validator rule enforcement

Each criterion maps to one of the 12 boot validator rules from Section C.1.6 (Rule 12 was added in pass 2 of the design review).

- **AC-005 (Rule 1)** GIVEN a manifest that references a non-existent file path WHEN validation runs THEN an error is recorded naming the missing path, and the system transitions to FAILED in release or asserts in debug.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-006 (Rule 2)** GIVEN a Resource whose `schema_version` does not equal its family's `CURRENT_SCHEMA` WHEN validation runs THEN validation fails for that Resource, naming both the found version and the expected version.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-007 (Rule 3)** GIVEN two `EnemyDefinition` Resources with the same `id` value WHEN validation runs THEN validation fails with a duplicate-ID error; a cross-family collision (`EnemyDefinition` and `ItemDefinition` sharing an `id`) must not fail.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-008 (Rule 4)** GIVEN an `EnemyDefinition` Resource with `id == &""` WHEN validation runs THEN validation fails with a non-empty-id error.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-008a (Rule 4 — `base_stats` structural check)** GIVEN a `CharacterProgressionCurve` with `base_stats` missing the `&"vit"` key (e.g., `{ &"str": 5, &"dex": 5, &"int": 5 }`) WHEN validation runs THEN validation fails naming the missing key and the Resource id; the Resource is excluded from `_templates`. Separately, GIVEN `base_stats` contains a value with the wrong type (e.g., `{ &"str": 5.0, ... }` — float instead of int) WHEN validation runs THEN validation fails naming the offending key and actual type. Note: extra keys beyond the required four are warned but do not fail validation.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-009 (Rule 5)** GIVEN an `EnemyDefinition` with `base_hp <= 0`, a `SkillDefinition` with `mana_cost < 0`, or a `WaveScalingCurve` entry with `hp_mult <= 0` WHEN validation runs THEN validation fails for each offending Resource with a message identifying the field and value.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-009a (Rule 5 — `defense_per_vit > 0` pillar-protection invariant)** GIVEN a `CharacterProgressionCurve` with `defense_per_vit == 0.0` AND `_error_reporter` injected as a call-counting stub WHEN validation runs THEN validation **fails** (not warns — this is a strict `> 0` invariant, not `>= 0`), `_error_reporter` is called at least once with a message containing the substring `"defense_per_vit must be > 0"`, and the Resource is excluded from `_templates`. The test must inject `_error_reporter` to verify message content — direct `push_error` output is not interceptable in GdUnit4 without injection. This AC exists as a named test because `defense_per_vit = 0` is the only Rule 5 sub-check where `= 0` is specifically forbidden (all other sub-checks allow `= 0` or only forbid negative values), making it the highest-priority invariant to verify independently.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — injects `_error_reporter` stub; asserts call count ≥ 1 and message contains `"defense_per_vit must be > 0"`._

- **AC-010 (Rule 6)** GIVEN an `ItemDefinition` with `rarity == &"mythic"` (not in the closed set) WHEN validation runs THEN validation fails naming the field, the invalid value, and the allowed set.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-011 (Rule 7)** GIVEN a `WaveScalingCurve` with `wave_entries` empty, or with `loop_after_wave >= wave_entries.size()` WHEN validation runs THEN validation fails with a density/range error.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-011b (Rule 7 — is_boss multi-spawn warning)** GIVEN a `WaveScalingCurve` whose `wave_entries` contains **exactly one** entry with `is_boss: true` AND `spawn_count: 3` (all other entries have `is_boss: false`) AND `_warning_reporter` injected as a call-counting stub (reset in `before_each`) WHEN validation runs THEN `_warning_reporter` is called exactly once (message names the offending wave index) AND validation does not fail — the curve remains in `_templates` and `is_ready` reaches `true`. `_error_reporter` call count == 0. The fixture must contain exactly one violating entry so that "called at least once" is equivalent to "called exactly once" — an implementation that batches/de-duplicates warnings and fires only a single call regardless of entry count would still pass; specifying a single violating entry closes that gap.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — injects `_warning_reporter` stub; asserts call count == 1, `is_ready == true`, `_error_reporter` call count == 0._

- **AC-011c (Rule 7 — is_boss zero-spawn warning)** GIVEN a `WaveScalingCurve.wave_entries[i]` with `is_boss: true` AND `spawn_count: 0` AND `_warning_reporter` injected as a call-counting stub (reset in `before_each`) AND `_error_reporter` injected as a call-counting stub (reset in `before_each`) WHEN validation runs THEN `_warning_reporter` is called at least once with a message containing `"boss with zero spawn count"`, `_error_reporter` call count == 0, the curve remains in `_templates`, and `is_ready` reaches `true`. Both `spawn_count == 0` and `spawn_count > 1` are **warnings** — unusual authoring the designer should review but neither invalidates the curve.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — injects `_warning_reporter` stub and `_error_reporter` stub; asserts warning count ≥ 1, error count == 0, curve present in `_templates`, `is_ready == true`._

- **AC-012 (Rule 8)** GIVEN a `WaveScalingCurve` whose `wave_entries[0].enemy_ids` contains `&"unknown_enemy"` and no `EnemyDefinition` with that id is loaded WHEN validation runs THEN validation fails naming the unresolved foreign key.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-013 (Rule 9 — size)** GIVEN a `CharacterProgressionCurve` where `max_level != xp_per_level.size() - 1` WHEN validation runs THEN validation fails with a size-mismatch message.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-014 (Rule 9 — NaN/Inf)** GIVEN a `CharacterProgressionCurve` where `xp_per_level[3] == INF` WHEN validation runs THEN validation fails naming the index and value.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-015 (Rule 9 — monotonic)** GIVEN a `CharacterProgressionCurve` where `xp_per_level[5] < xp_per_level[4]` WHEN validation runs THEN validation fails naming the non-monotonic indices and values.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-016 (Rule 10)** GIVEN an `ItemDefinition` with `stat_roll_ranges[&"str"] = Vector2(100.0, 50.0)` (valid key, `min > max`) WHEN validation runs THEN validation fails naming the item id, the stat key, and the offending Vector2. Key must be from the closed base-stat set (see C.1.2) so Rule 6 is not also triggered — this AC isolates the `min <= max` check.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-017 (Rule 11)** GIVEN an empty `BalanceManifest` (zero paths) WHEN validation runs THEN validation fails with a non-empty-manifest error; `is_ready` stays `false`.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-018 (Release failure path — observable effects)** GIVEN validation fails in a release-behavior configuration (test injects `_is_debug = false` on the BalanceDatabase under test) WHEN validation runs THEN the following observable effects all occur: (a) `_validation_errors.size() >= 1`, (b) `_error_reporter` was invoked with at least one non-empty message, (c) `balance_load_failed` signal was emitted exactly once, (d) offending Resources are absent from `_templates`, (e) `is_ready == false`.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — asserts each observable effect directly. Note: this test does NOT attempt to prove "no assert fired" by any catch mechanism — native GDScript `assert(false)` is a terminal compile-time directive that GdUnit4 cannot intercept as a signal or exception. The `_is_debug = false` runtime flag guarantees the `if _is_debug: assert(false, ...)` branch is not entered at runtime; proving the compiled release binary contains no assert is a separate concern (GDScript strips `assert()` at export time regardless). What this AC tests: the runtime control-flow decision (does the flag work?). What it does NOT test: compile-time stripping (covered by the manual release-build smoke check in H.5)._

- **AC-019 (All errors collected before any terminal action)** GIVEN a manifest with three separate validator violations AND `_is_debug = false` injected (release-behavior path) WHEN validation runs THEN `_validation_errors.size() == 3` AND `_error_reporter` was called three times AND `balance_load_failed` was emitted exactly once (not once per error — one signal per validation pass). The multi-error collection pattern is the load-bearing behavior; this AC proves no fail-fast bail-out occurred at the first error.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — injects `_error_reporter` as a log-capturing stub and `_is_debug = false`. Debug-build terminal-assert behavior (the `if _is_debug: assert(false, joined)` line after collection) is NOT automated; it is verified via a manual debug run documented in `production/qa/evidence/balance-debug-assert-smoke.md` — launch debug build with a fixture producing 3 errors, observe all three in Output panel, then observe the terminal assert halting boot. Attempting to automate this in GdUnit4 would crash the runner (native assert terminates the process) and provide no verifiable pass/fail signal._

### H.3 Wave-loop formula correctness

**Test isolation requirement:** Every test function in `test_wave_loop_formula.gd` must run against a freshly instantiated `BalanceDatabase` or explicitly reset `_warned_no_loop_curves` and reporter stubs in `before_each`. `_warned_no_loop_curves` state from one test must not carry over to the next — tests must not depend on execution order. The exception is AC-053, which intentionally shares state across two formula calls within a single test function.

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

- **AC-026 (loop_after_wave = -1, w beyond range, clamp)** GIVEN `loop_after_wave = -1` AND `_warning_reporter` injected as a call-counting stub WHEN queried for `w = 50` THEN `effective_hp_mult == wave_entries[9].hp_mult` (clamped to N-1), `loop_count == 0`, and `_warning_reporter` was called exactly once.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd` — injects `_warning_reporter` stub and asserts call count == 1 and return values._

- **AC-027 (loop_hp_scale = 1.0, plateau)** GIVEN `loop_hp_scale = 1.0` WHEN queried for any `w > loop_after_wave` THEN `effective_hp_mult == wave_entries[e].hp_mult * 1.0 ^ loop_count` (authored value, no growth).
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-028 (loop_hp_scale < 1.0, decay, no clamp in this layer)** GIVEN `loop_hp_scale = 0.80` WHEN queried for `w = 27` THEN `effective_hp_mult == wave_entries[7].hp_mult * 0.80^2` — a value less than the authored base — and the formula returns it without clamping.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd`_

- **AC-029 (invalid w, negative)** GIVEN `w = -1` is passed to the formula AND `_error_reporter` injected as a call-counting stub THEN `_error_reporter` is called at least once AND the return value has `&"hp_mult" == wave_entries[0].hp_mult`, `&"dmg_mult" == wave_entries[0].dmg_mult`, `&"loop_count" == 0`; no crash.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd` — injects `_error_reporter` stub; asserts call count ≥ 1 and return dict field values._

- **AC-029b (INF/NaN overflow guard — formula branch 5)** GIVEN a `WaveScalingCurve` with `loop_hp_scale = 1e200` and `loop_dmg_scale = 1e200` AND `w = loop_after_wave + loop_span + 1` (producing `loop_count = 2`, so `1e200^2 = INF`) AND `_error_reporter` injected as a call-counting stub WHEN the formula is queried THEN: (a) `_error_reporter` is called at least once naming the wave `w`, the overflowed field(s), and the entry index `e`; (b) the return value has `&"hp_mult" == wave_entries[e].hp_mult` (authored baseline, unscaled); (c) `&"dmg_mult" == wave_entries[e].dmg_mult`, unscaled; (d) `&"loop_count"` equals the pre-overflow computed value (preserved for telemetry, not zeroed); (e) no crash or NaN propagates.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd` — injects `_error_reporter` stub; asserts call count ≥ 1 and return dict field values._

### H.4 API behavior — getters, miss contract, template immutability

- **AC-030 (getter hit, typed return)** GIVEN a loaded `EnemyDefinition` with `id = &"slime_common"` WHEN `BalanceDatabase.get_enemy(&"slime_common")` is called THEN the return type is `EnemyDefinition` and `result.id == &"slime_common"`.
  _Unit test: `tests/unit/balance_data_layer/test_getter_api.gd`_

- **AC-031 (miss contract — debug branch behavior, manual evidence)** The debug-build miss contract is: `null` is returned, `_error_reporter` is invoked with a non-empty message, AND a terminal `assert(false, ...)` fires under the `if _is_debug:` branch. **This AC is NOT automated** — native GDScript `assert(false)` terminates the process and cannot be caught by GdUnit4 as a signal, exception, or invertible failure. Verification is via a manual debug run documented in `production/qa/evidence/balance-getter-miss-debug-smoke.md`: launch a debug build, call `get_enemy(&"nonexistent_id")` via the dev console or a boot fixture, observe (a) the `push_error` message in the Output panel, and (b) the terminal assert halt. The observable-effect subset (`null` return + `_error_reporter` called) IS automated in AC-032.
  _Manual smoke check: `production/qa/evidence/balance-getter-miss-debug-smoke.md` (created per milestone). ADVISORY gate — does not block merge; manual sign-off required before Foundation milestone close._

- **AC-032 (miss contract — release, observable effects)** GIVEN `is_ready == true` AND `_is_debug = false` injected (release-behavior path) WHEN `get_enemy(&"nonexistent_id")` is called THEN: (a) `null` is returned, (b) `_error_reporter` is invoked exactly once with a non-empty message naming the missing id, (c) no side effect modifies `_templates` or `is_ready`. This AC proves the release-path control flow; it does NOT prove the compiled release binary lacks an assert instruction (GDScript strips `assert()` at export regardless of the `_is_debug` flag).
  _Unit test: injects `_is_debug = false` and a stubbed `_error_reporter`. Asserts reporter call count == 1, returned value is `null`, `is_ready` unchanged. `tests/unit/balance_data_layer/test_getter_api.gd`._

- **AC-033 (no direct ResourceLoader calls)** GIVEN any consumer file under `src/` WHEN the CI lint rule runs THEN no line matches `ResourceLoader\.load\s*\(\s*["'][^"']*assets/data/` in any `.gd` file outside `src/core/balance/`. Violation blocks CI.
  _Automated: `tools/ci/lint_forbidden_patterns.sh` (bash; uses `grep -rEn` on `src/`). CI step name: `balance-data-access-lint`. Exit code 1 on any match. **This is a BLOCKING gate** (C.1.4 declares the pattern forbidden) — promoted from ADVISORY to match C.1.4 language._

- **AC-034 (duplicate-once, not per-frame)** GIVEN an `EnemyDefinition` template obtained from `get_enemy` WHEN `duplicate_deep()` is called once and the resulting instance's `base_hp` is modified THEN a subsequent `get_enemy` call for the same id returns the original unmodified value.
  _Unit test: `tests/unit/balance_data_layer/test_getter_api.gd`_

- **AC-035 (WaveScalingCurve / CharacterProgressionCurve never duplicated)** GIVEN `get_wave_curve` or `get_progression` returns a template WHEN the CI lint rule runs THEN no `.duplicate` or `.duplicate_deep` call appears on a line that mentions either of the two read-only curve class names in any consumer `.gd` file under `src/`.
  _Automated (two-pass heuristic, acknowledged imprecise): `tools/ci/lint_forbidden_patterns.sh` extends AC-033's script with two grep rules:_
  1. _Primary (coarse, low false-negatives): `grep -rEn '\.(duplicate|duplicate_deep)\s*\(' src/ | grep -E '(WaveScalingCurve|CharacterProgressionCurve)'` — fails if any hit. Catches the common patterns where the type name and the call appear on the same line (e.g., `var c: WaveScalingCurve = template.duplicate_deep()`)._
  2. _Secondary (type-declaration scan): `grep -rEn '(var|const)\s+\w+\s*:\s*(WaveScalingCurve|CharacterProgressionCurve)' src/` — produces a list of variable names typed to the curve classes; CI fails if any of those variable names appears on a subsequent line in the same file followed by `.duplicate` or `.duplicate_deep`._
  _Known false-negative: a variable whose type is inferred (no explicit annotation) and later duplicated will not be caught. This is an accepted gap; code review catches these. The rule is classified BLOCKING for the patterns it does catch; the coverage gap is documented, not concealed. Violation (any hit in rule 1 or 2) blocks CI._

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

- **AC-041 (E.1 — empty wave_entries runtime guard)** GIVEN a `WaveScalingCurve` that somehow reaches runtime with `wave_entries` empty (validator failed silently in release) AND `_error_reporter` injected as a call-counting stub WHEN the formula is queried THEN `_error_reporter` is called at least once (the empty-entries guard routes through `_error_reporter` per the reporter routing contract in C.1.4 — not via direct `push_error`) AND the function returns immediately with `{ &"hp_mult": 1.0, &"dmg_mult": 1.0, &"loop_count": 0 }` (StringName-keyed dict — assert field-by-field: `result[&"hp_mult"] == 1.0`, `result[&"dmg_mult"] == 1.0`, `result[&"loop_count"] == 0`); no crash occurs and no further formula computation executes after the guard fires.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd` — injects `_error_reporter` stub; asserts call count ≥ 1 and each dict field value individually._

- **AC-042 (E.3 — resource_local_to_scene guard)** GIVEN a Resource saved with `resource_local_to_scene = true` is listed in the manifest WHEN validation runs THEN validation fails naming the Resource and field; the Resource is excluded from `_templates`.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd`_

- **AC-043 (E.3 — UID remap warning)** GIVEN a manifest path whose resolved `resource_path` after load differs from the manifest-listed path WHEN validation runs THEN a UID-remap warning is emitted; boot continues and the Resource is still loaded.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd` — mock ResourceLoader fixture._

- **AC-044 (E.4 — getter before ready, release path)** GIVEN the game is in LOADING state AND `_is_debug = false` injected (release-behavior path) WHEN a consumer calls `get_item` from a deferred signal THEN: (a) `null` is returned, (b) `_error_reporter` is invoked with a non-empty message, (c) no assert fires (the `if _is_debug:` branch is not entered), (d) `is_ready` remains `false`. The `_is_debug = false` injection is required — without it, a debug CI run triggers `assert(false)` which terminates the GdUnit4 runner (same pattern as AC-002/018/019/031/032).
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd` — injects `_is_debug = false` and `_error_reporter` stub. Asserts reporter call count ≥ 1, return value is `null`._

- **AC-045 (E.4 — peer autoload already-fired signal)** GIVEN `BalanceDatabase._ready()` completes synchronously before a peer autoload's `_ready()` runs WHEN the peer checks `is_ready` before connecting to `database_ready` THEN `is_ready == true` and the peer does not deadlock awaiting a signal that already fired.
  _Integration test: `tests/integration/balance_data_layer/test_peer_autoload_ordering.gd`_

- **AC-046 (E.5 — schema mismatch fails, no silent migration)** GIVEN a Resource with `schema_version = 0` and `CURRENT_SCHEMA = 1` WHEN validation runs THEN validation fails; the Resource is not silently loaded with a default schema version.
  _Unit test: `tests/unit/balance_data_layer/test_edge_cases.gd`_

### H.7 Performance / budget

- **AC-047a (boot validator speed — desktop CI threshold, automated gate)** GIVEN a manifest containing 200 Resources (across all five families) WHEN `BalanceDatabase._ready()` runs under a desktop GdUnit4 headless run (Godot's `--headless` flag) on CI THEN total time from LOADING entry to `database_ready` signal is under **200 ms**. This threshold is a proxy for the device target; it assumes desktop storage + CPU is ~2.5× faster than the reference Android device for text `.tres` parsing, consistent with OQ-2.
  _Automated benchmark: `tests/performance/test_balance_boot_time.gd` — `Time.get_ticks_msec()` delta; threshold asserted; BLOCKING gate._

- **AC-047b (boot validator speed — reference Android device, manual evidence)** GIVEN the same 200-Resource manifest WHEN the game is launched (non-headless — Godot has no headless mode on Android) on the project's reference Android device (**Pixel 4a, Snapdragon 730G, 2020 — pinned as the mid-range 2020+ benchmark**) THEN total time from LOADING entry to `database_ready` signal is under **500 ms** per the cold-start budget in `.claude/docs/technical-preferences.md`.
  _Manual measurement: bootstrap the benchmark fixture in a debug export, launch on the Pixel 4a, capture `Time.get_ticks_msec()` delta, record in `production/qa/evidence/balance-boot-time-device.md` (device model, OS version, fixture hash, observed ms, pass/fail). ADVISORY gate — required for Foundation milestone sign-off but does not block merge. If the Pixel 4a is unavailable at measurement time, a substitute Snapdragon 720/730/765-class device is acceptable with the device model logged in the evidence file; if the budget is missed, OQ-2 reopens and the binary `.res` export flip is reconsidered (see N-1 below)._

- **AC-048 (getter call cost)** GIVEN the database is READY WHEN any typed getter is called 10,000 times in a tight loop THEN total elapsed time is under 10 ms on desktop (O(1) Dictionary lookup requirement).
  _Unit benchmark: `tests/performance/test_balance_boot_time.gd`_

- **AC-049 (deferred — EnemySystem dependency)** The duplicate-once-per-spawn budget is a consumer-side contract owned by EnemySystem. Moved to the Enemy System GDD when authored. This GDD retains only a statement of the contract in C.1.5; the test lives downstream.
  _No test in this GDD. Placeholder retained so AC numbering stays stable across revisions._

- **AC-050 (memory ceiling)** GIVEN a baseline sample of `Performance.get_monitor(Performance.MEMORY_DYNAMIC)` taken immediately before `BalanceDatabase._ready()` is invoked, AND the full MVP manifest is then loaded, WHEN `Performance.MEMORY_DYNAMIC` is sampled a second time after `database_ready` fires THEN `(post - baseline)` is under 32 MB on desktop; under 20 MB on the reference Android device (Pixel 4a, per AC-047b).
  _Manual smoke check methodology: baseline captured via an injected `pre_ready_hook` Callable; post capture in the `database_ready` handler. Recorded in `production/qa/evidence/balance-memory-smoke.md` with the following required fields: device model, Godot version, OS version, fixture hash, baseline MB, post-load MB, delta MB, pass/fail. Owner: QA-lead; created before Foundation milestone sign-off. Desktop threshold also enforced by CI benchmark (`tests/performance/test_balance_boot_time.gd`)._
  _**Monitor choice rationale:** `Performance.MEMORY_DYNAMIC` measures GDScript-allocated heap (where loaded Resources and Dictionary entries live); `Performance.MEMORY_STATIC` measures engine-side static pools and returns near-zero for this workload. Using `MEMORY_STATIC` (as the pass-2 draft did) would produce meaningless false PASS results. If `MEMORY_DYNAMIC` is insufficiently granular in practice, fall back to external profiler capture (Godot's built-in "Monitors" panel or Android Studio Memory Profiler) and document the alternative in the evidence file._

### H.7b Coverage additions from review (2026-04-19)

- **AC-051a (Rule 12 — hp seam, debug warning)** GIVEN a `WaveScalingCurve` with `allow_loop_seam == false` AND `wave_entries[0].hp_mult * loop_hp_scale < wave_entries[loop_after_wave].hp_mult` AND `_is_debug == true` AND `_warning_reporter` injected as a call-counting stub WHEN validation runs THEN `_warning_reporter` was called with a message containing the curve id, the field name `hp_mult`, and the computed drop percentage; `is_ready` still reaches `true` (warning, not failure in debug). `_error_reporter` call count == 0.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — injects `_warning_reporter` stub; asserts call count ≥ 1 and message content; asserts `is_ready == true`._

- **AC-051b (Rule 12 — dmg seam, debug warning)** GIVEN a `WaveScalingCurve` with `allow_loop_seam == false` AND `wave_entries[0].dmg_mult * loop_dmg_scale < wave_entries[loop_after_wave].dmg_mult` AND `_is_debug == true` AND `_warning_reporter` injected WHEN validation runs THEN `_warning_reporter` was called with a message naming the curve id and `dmg_mult`; `is_ready` reaches `true`. Test uses a fixture that violates the dmg seam ONLY (hp seam valid) to isolate the dmg branch.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — same `_warning_reporter` injection pattern as AC-051a._

- **AC-051c (Rule 12 — release fail without override)** GIVEN a `WaveScalingCurve` with `allow_loop_seam == false` AND either hp seam OR dmg seam is violated AND `_is_debug == false` WHEN validation runs THEN validation **fails** for that curve: it is dropped from `_templates`, `balance_load_failed` is emitted, and `is_ready` remains `false`. This AC enforces the pillar-protection contract — no silent 42% drops ship to players.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — two test cases, one per violating field._

- **AC-051d (Rule 12 — release pass with override)** GIVEN a `WaveScalingCurve` with `allow_loop_seam == true` AND a seam violation on either field AND `_is_debug == false` AND `_warning_reporter` injected as a call-counting stub WHEN validation runs THEN the curve loads successfully (no failure), `_warning_reporter` is called at least once with a message naming the curve id and acknowledging the accepted seam (GDScript has no `push_info()`; this acknowledgement routes through `_warning_reporter`), and `is_ready` reaches `true`. This is the designer escape hatch for intentional difficulty resets.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd` — injects `_warning_reporter` stub; asserts call count ≥ 1 and curve in `_templates`._

- **AC-051e (Rule 12 — loop_after_wave = -1 skip)** GIVEN a `WaveScalingCurve` with `loop_after_wave == -1` (looping disabled) AND arbitrary `wave_entries` values that would violate the seam inequality if evaluated WHEN validation runs THEN Rule 12 does not execute: no warning, no failure, no info message is emitted for the seam check; the curve validates and loads normally regardless of whether `wave_entries[0]` is lower or higher than `wave_entries[wave_entries.size() - 1]`. This protects against GDScript's `wave_entries[-1]` negative-index wrap from producing spurious seam-check results.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-052 (consumer per-frame getter ban)** GIVEN any `.gd` file under `src/` WHEN the CI lint rule runs THEN no call to `BalanceDatabase.get_enemy|get_item|get_skill|get_wave_curve|get_progression` appears inside a `_process`, `_physics_process`, or `_input` function body.
  _Automated: `tools/ci/lint_forbidden_patterns.sh` extended with an AST-free grep heuristic (function-scope window scan). Violation blocks CI._

- **AC-053 (one-time clamp warning)** GIVEN `loop_after_wave = -1` AND `_warning_reporter` injected as a call-counting stub (reset in `before_each`) WHEN the formula is queried for `w = 50` twice on the **same `BalanceDatabase` instance** using the **same `WaveScalingCurve.id`** and `_warned_no_loop_curves` is NOT reset between the two calls THEN `_warning_reporter` call count == 1 across both calls — the second call does not re-emit the warning (session-scoped suppression, keyed per curve `id` on `BalanceDatabase._warned_no_loop_curves`). Both calls must use the same instance and same curve id; a fresh instance or a different curve id would trivially re-trigger the warning and not test suppression.
  _Unit test: `tests/unit/balance_data_layer/test_wave_loop_formula.gd` — injects `_warning_reporter` stub, calls formula twice on same instance+id, asserts stub call count == 1._

- **AC-054 (unrecognized-class skip)** GIVEN a manifest that includes a path resolving to a `Resource` not belonging to any of the five families WHEN validation runs THEN a warning is logged naming the path and actual class, the path is skipped (no entry in any `_templates` dictionary), remaining Resources load normally, and `is_ready` reaches `true`.
  _Unit test: `tests/unit/balance_data_layer/test_validator_rules.gd`_

- **AC-055 (migration tool `schema_version == 0` handling)** GIVEN a `.tres` whose stored `schema_version == 0` (pre-versioning) WHEN `tools/migrate_balance.gd` runs against it THEN the output `.tres` has `schema_version = CURRENT_SCHEMA` for its family, every field has a value consistent with that family's current schema (defaults applied where fields are missing), and the tool does not silently leave `schema_version = 0` or fail with an unhandled exception.
  _Unit test: `tests/unit/balance_data_layer/test_migrate_balance.gd`_

### H.8 Test evidence required

| Section | Story type | Required evidence | Test file location |
|---|---|---|---|
| H.1 Loading and readiness | Integration | Integration test — boot sequence with fixture manifest | `tests/integration/balance_data_layer/test_boot_ready.gd` |
| H.1 Loading and readiness | Logic | Unit test — state machine transitions, getter-before-ready | `tests/unit/balance_data_layer/test_state_machine.gd`, `test_getters_before_ready.gd` |
| H.2 Validator rule enforcement | Logic (blocking) | Unit tests — one test function per rule (12 rules + failure modes; Rule 12 tests live in H.7b via AC-051a/b/c/d/e; AC-008a covers `base_stats` structural check; AC-009a covers `defense_per_vit > 0` pillar-protection invariant; **AC-011b** covers Rule 7 `is_boss: true AND spawn_count > 1` warning branch; **AC-011c** covers Rule 7 `is_boss: true AND spawn_count == 0` warning branch) | `tests/unit/balance_data_layer/test_validator_rules.gd` |
| H.1 Loading and readiness — pre-ready getter (AC-002, AC-002b) | Logic — split gate | AC-002 automated (release path, `_is_debug = false` injection); AC-002b manual (debug-assert path, same evidence file as AC-031) | `tests/unit/balance_data_layer/test_getters_before_ready.gd` (automated); `production/qa/evidence/balance-getter-miss-debug-smoke.md` (advisory manual) |
| H.3 Wave-loop formula | Logic (blocking) | Unit tests — all boundary and case inputs listed in H.3 including INF/NaN overflow guard branch (AC-029b) | `tests/unit/balance_data_layer/test_wave_loop_formula.gd` |
| H.7b Migration tool (AC-055) | Logic (blocking) | Unit test — `schema_version == 0` handled, output schema correct, no unhandled exception | `tests/unit/balance_data_layer/test_migrate_balance.gd` |
| H.4 API behavior | Logic (blocking) | Unit tests — getter hit/miss, immutability, typed return | `tests/unit/balance_data_layer/test_getter_api.gd` |
| H.4 No direct ResourceLoader (AC-033, AC-035) | Logic (blocking) | CI grep lint — no `ResourceLoader.load()` on `assets/data/` paths in `src/`; no `.duplicate*()` on typed `WaveScalingCurve`/`CharacterProgressionCurve` variables | `tools/ci/lint_forbidden_patterns.sh` |
| H.5 Hot reload | Integration | Integration test — reload signal, old template retention, mid-wave stale instances | `tests/integration/balance_data_layer/test_hot_reload_integration.gd` |
| H.5 Hot reload — release guard | Visual/UI (advisory) | Manual smoke check on export build — press F5, confirm no reload | `production/qa/evidence/hot-reload-release-smoke.md` |
| H.6 Edge cases | Logic (blocking) | Unit tests covering all five E-section categories | `tests/unit/balance_data_layer/test_edge_cases.gd` |
| H.7 Boot time — desktop CI (AC-047a) | Performance (blocking) | Automated benchmark, 200ms desktop headless threshold | `tests/performance/test_balance_boot_time.gd` |
| H.7 Boot time — device (AC-047b) | Performance (advisory) | Manual on-device measurement (Pixel 4a pinned; Snapdragon 720/730/765 substitute allowed) | `production/qa/evidence/balance-boot-time-device.md` |
| H.7 Getter cost (AC-048) | Performance (blocking) | Automated benchmark desktop | `tests/performance/test_balance_boot_time.gd` |
| H.7 Memory ceiling (AC-050) | Performance (advisory) | Manual smoke check, `Performance.MEMORY_DYNAMIC`, with required evidence fields | `production/qa/evidence/balance-memory-smoke.md` |
| H.2 Debug-assert terminal behavior (AC-019 debug branch, AC-031) | Logic (advisory, manual) | Manual debug-run evidence documenting 3-error collection + terminal assert halt | `production/qa/evidence/balance-debug-assert-smoke.md`, `production/qa/evidence/balance-getter-miss-debug-smoke.md` |
| ~~H.7 duplicate budget~~ | — | AC-049 moved to Enemy System GDD per revision 2026-04-19; no test in this suite | see Enemy System GDD when authored |

**Minimum coverage gate (Advisory — OQ-9)**: Formula and validator code paths target 70% line coverage. **This threshold cannot be automatically enforced by the standard GdUnit4 CI command above** — GdUnit4 line coverage requires additional addon/plugin configuration not yet set up for this project. Until coverage tooling is configured (see OQ-9), this gate is advisory and does not automatically block merge via CI. Manual coverage review is required before Foundation milestone sign-off.

**CI command to run all automated tests in this section** (per `.claude/docs/technical-preferences.md`):

```
godot --headless --import && godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/
```

**Blocking gates** (CI must fail on violation):
- **H.1** pre-ready getter (AC-002 release path); state machine transitions (`test_state_machine.gd`); integration boot sequence (AC-001, AC-004 in `test_boot_ready.gd`, `test_peer_autoload_ordering.gd`)
- **H.2** validator logic — observable-effects subset automated: AC-005 through AC-018, AC-019 (release-path only), AC-054. AC-051a/b/c/d/e cover Rule 12 (**AC-051a and AC-051b now automatable** — require `_warning_reporter` injection seam, added pass 5). **AC-008a** covers `base_stats` structural check (Rule 4). **AC-009a** covers `defense_per_vit > 0` pillar-protection invariant (Rule 5). **AC-011b** covers Rule 7 `is_boss: true AND spawn_count > 1` warning branch (added pass 6). **AC-011c** covers Rule 7 `is_boss: true AND spawn_count == 0` warning branch (downgraded from fail in pass 8).
- **H.3** wave-loop formula correctness (AC-020 through AC-029, AC-029b INF/NaN overflow guard, AC-053)
- **H.4** API behavior — observable-effects subset: AC-030, AC-032, AC-034. Lint gates AC-033 and AC-035 are CI-enforced via `tools/ci/lint_forbidden_patterns.sh` (not GdUnit4) but block merge identically.
- **H.6** edge cases (AC-041 through AC-046; AC-044 now requires `_is_debug = false` injection — added pass 5)
- **H.7a** desktop boot benchmark (AC-047a)
- **H.7b** per-frame-getter lint (AC-052) — via the same lint script.
- **H.7** getter cost benchmark (AC-048)
- **H.7b** migration tool (AC-055) — `test_migrate_balance.gd`

Advisory gates (warnings, not merge-blocking):
- **H.5** release hot-reload guard (AC-039 — manual smoke check, `production/qa/evidence/hot-reload-release-smoke.md`)
- **H.7** memory ceiling (AC-050 — manual smoke check with MEMORY_DYNAMIC)
- **H.7b** device boot time (AC-047b — manual on Pixel 4a)
- **H.1/H.2** debug terminal-assert behavior (AC-002b, AC-019 debug-branch, AC-031 debug miss contract) — manual-only because native GDScript `assert(false)` cannot be captured by GdUnit4. Sign-off required before Foundation milestone close.

## Open Questions

Known-unknowns carried forward from design. Each has an owner and the moment at which it must be resolved. "Owner = user" means a design-owner decision; "Owner = architecture" means a decision that belongs to `/architecture-decision`.

### OQ-1 Godot 4.6 `CACHE_MODE_IGNORE` constant name — **RESOLVED (design-level)**

The hot-reload sequence (Section C.1.8) uses `ResourceLoader.CACHE_MODE_IGNORE`. Resolution based on Godot 4.x API analysis:

- **Correct constant form in GDScript**: `ResourceLoader.CACHE_MODE_IGNORE` (flat-namespace access into the `CacheMode` enum). Prefer this over `ResourceLoader.CacheMode.IGNORE` — both are valid GDScript 4.x syntax, but the flat-namespace form is the idiomatic GDScript style and is less likely to break if enum nesting changes between versions.
- **`CACHE_MODE_IGNORE` vs `CACHE_MODE_IGNORE_DEEP`**: `CACHE_MODE_IGNORE_DEEP` ensures sub-resources are also reloaded from disk. For Balance Resources, C.1.5 **prohibits nested Node-derived or physics sub-resources** — Balance Resources hold only primitives, StringNames, typed arrays, Dictionaries, and Vector2/3. Therefore `CACHE_MODE_IGNORE` is sufficient; sub-resources are either absent or are primitive inline types that load independently anyway.
- **Verification required at implementation time**: confirm constant name in a live Godot 4.6 editor console (`print(ResourceLoader.CACHE_MODE_IGNORE)`) before wiring C.1.8. If the constant is unavailable, fall back to the integer value (typically `2`) as a documented stopgap and file a bug.
- **Owner**: engine-programmer to confirm in the first implementation sprint.
- **Target**: before `/create-stories` for the Balance Data Layer epic — this is the one remaining verification step before C.1.8 can be implemented.

### OQ-2 Godot 4.6 `.tres` parse performance on Android

Engine-programmer estimated ~150–200 text `.tres` files are parseable within the 3s cold-start budget on mid-range Android 2020+ but could not confirm against 4.6-specific behavior. AC-047b (Pixel 4a, 500ms budget) is the measurement gate; until it passes, the 500ms number is a target, not a verified limit.
- **Impact if wrong**: cold-start exceeds 3s on target hardware; the "Text .tres everywhere" decision from framing may need to flip to "binary `.res` in release". The `.tres → .res` flip is transparent to the Resource schema and public API — only the export pipeline changes — so flipping does not trigger re-review of this GDD.
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

### OQ-8 Mana / resource regeneration — where does regen rate live?

The game concept (§4.4) mentions mana regenerates automatically over time; INT increases max mana. Mana regen rate is a core skill-uptime tunable. It is absent from `CharacterProgressionCurve` and from `SkillDefinition`.

- **Candidates**: (a) `CharacterProgressionCurve.mana_regen_base: float` + `mana_regen_per_int: float`; (b) per-skill regen as a side-effect tag interpreted by Combat Engine; (c) a separate `ResourceRegenCurve` family if multiple regenerating resources exist.
- **Impact on this GDD**: whichever candidate wins may require a schema addition here and a new Rule 5 check. If option (b), no change needed to this GDD.
- **Resolution**: Combat Engine GDD must claim this field or trigger `/propagate-design-change` against this GDD to add it.
- **Owner**: user + Combat Engine GDD author.
- **Target**: when Combat Engine GDD is authored — it must not be left unowned.

### OQ-9 GdUnit4 line-coverage tooling setup

The 70% line coverage gate in H.8 requires GdUnit4 coverage instrumentation that is not included in the standard `GdUnitCmdTool.gd` invocation — the standard CLI reports pass/fail and test counts but not line coverage. The gate will silently not run without additional configuration.
- **Impact if not set up**: coverage drift goes undetected; the 70% threshold claim in H.8 is unenforced and misleading across all downstream consumer GDDs.
- **Options**: (a) install a GdUnit4 coverage addon that adds a `--coverage` flag or equivalent; (b) use an external coverage tool (e.g., Godot headless + LCOV post-processing) and integrate into CI; (c) accept advisory-only coverage gate until the project reaches a milestone that justifies tooling investment.
- **Owner**: devops-engineer (when first implementation sprint is planned for Balance Data Layer).
- **Target**: before `/create-stories` for the Balance Data Layer epic — must be resolved before any story claims a coverage gate is blocking merge.

### OQ-7 `effect_tags` validation — open vs closed

Section C.1.2 declares `SkillDefinition.effect_tags` as an **open** StringName array. This is intentional — Combat Engine interprets the tags and new tags should be addable without a Balance Data Layer change. But it means typos are silent: `&"stun"` and `&"stunn"` are both valid here, and only the Combat Engine will notice the mismatch.
- **Impact if wrong**: silent no-op effects on skills with typo'd tags.
- **Resolution**: Combat Engine GDD defines the canonical tag list; this GDD can then validate against that list via a cross-system constant. Deferred to Combat Engine GDD.
- **Owner**: user + Combat Engine GDD author.
- **Target**: when Combat Engine GDD is authored.
