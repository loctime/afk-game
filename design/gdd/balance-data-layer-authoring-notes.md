# Balance Data Layer — Designer Authoring Notes (Provisional)

> **Status:** Provisional — pending Combat Engine + Character Stats + Item System + Wave & Phase Manager GDDs, which own the safe-range truth.
> **Last Updated:** 2026-04-20
> **Companion GDD:** [balance-data-layer.md](balance-data-layer.md)
> **Purpose:** Unblock day-one `.tres` authoring while consumer GDDs are still being written.

This document is the **designer quick-reference** for adding and tuning Balance Data Layer Resources in the Godot editor. It protects the Player Fantasy stated in the GDD's Section B — "puedo abrir el editor, cambiar un número, jugar 30 segundos, y ver el efecto" — by giving authors a known-safe starting point before the consumer GDDs are formalised.

The values below are **provisional**. When the consumer GDDs (Combat Engine, Character Stats & Leveling, Item System, Wave & Phase Manager) are authored and reviewed, the safe ranges move into those GDDs (per the GDD's Section G.1 ownership table) and this file is either deleted or reduced to a pointer.

---

## 5-Step Quick Start — Adding a New Enemy

1. **Duplicate** an existing `EnemyDefinition.tres` in `assets/data/enemies/` (e.g., `slime_common.tres`) as the scaffold.
2. **Set `id`** to a unique `StringName` (e.g., `&"goblin_scout"`). Must be unique across EnemyDefinitions; cross-family collision with an ItemDefinition is allowed.
3. **Fill the numeric fields** using the provisional safe ranges below (`base_hp`, `base_damage`, `behavior_tag`, `size_category`, `sprite_path`, `drop_table_id`).
4. **Append the file path** to `assets/data/BalanceManifest.tres` → `paths` array.
5. **Launch the game in debug, press F5** to hot-reload. Watch the Output panel for validator errors. If none, the enemy is live in the next wave that references its `id`.

---

## Provisional Safe Ranges (subject to consumer-GDD override)

### EnemyDefinition

| Field | Provisional safe range | Notes |
|---|---|---|
| `base_hp` | 20 – 2000 | Scales via `WaveScalingCurve.hp_mult`. Bosses (size_category `&"huge"`) go 500+. Combat Engine GDD will own the true range. |
| `base_damage` | 2 – 80 | Before `loop_dmg_scale` compounding. Combat Engine GDD will own the true range. |
| `behavior_tag` | `&"melee"`, `&"ranged"`, `&"aggressive"`, `&"tank"` | Closed enum (C.1.2). |
| `size_category` | `&"small"`, `&"medium"`, `&"large"`, `&"huge"` | `&"huge"` reserved for bosses. |

### WaveScalingCurve

| Field | Provisional safe range | Notes |
|---|---|---|
| `wave_entries[w].hp_mult` | 1.0 – 5.0 | Per-entry authored base. Rule 5 requires > 0. |
| `wave_entries[w].dmg_mult` | 1.0 – 3.0 | Per-entry authored base. |
| `wave_entries[w].spawn_count` | 1 – 50 | Wave & Phase Manager GDD will refine. |
| `loop_hp_scale` | 1.05 – 1.20 | MVP default 1.15. `>= 2.0` breaks within a few loops. |
| `loop_dmg_scale` | 1.05 – 1.20 | MVP default 1.15. Can be asymmetric with `loop_hp_scale`. |
| `loop_after_wave` | `N - 1` (most common) | Set to `-1` only if you want the game to hard-end past the authored content. |
| `allow_loop_seam` | `false` (default) | Only flip to `true` if you have an explicit reason to accept the seam drop. Shipping with `true` is a code-smell. |

### CharacterProgressionCurve (single global instance, `id = &"default"`)

| Field | Provisional safe range | Notes |
|---|---|---|
| `max_level` | 30 – 100 | MVP typical 50. Character Stats GDD will own. |
| `xp_per_level[i]` | monotonic, finite, > previous | Authoring tool can generate curves; don't hand-edit past level 20. |
| `hp_per_vit` | 4 – 12 | Character Stats GDD will own. |
| `defense_per_vit` | 0.5 – 3.0 | **Must be > 0** (Rule 5). Character Stats / Combat Engine own the exact reduction formula. |
| `mana_per_int` | 3 – 8 | |
| `atk_per_str` | 1 – 5 | |
| `speed_per_dex` | 0.1 – 1.0 | Character Stats GDD will own. |
| `stat_points_per_level` | 3 – 6 | MVP typical 5. |

### ItemDefinition

| Field | Provisional safe range | Notes |
|---|---|---|
| `rarity` | `&"common"`, `&"rare"`, `&"epic"`, `&"legendary"` | Closed enum (C.1.2). Item System GDD will own drop weights. |
| `slot` | one of the 13 slot values in C.1.2 | |
| `stat_roll_ranges[&"str"\|&"dex"\|&"int"\|&"vit"]` | `Vector2(min, max)` with `min <= max` and reasonable ratio to `base_stats` (typically `base_stats[stat] * 0.1 – base_stats[stat] * 2.0` at the authoring level) | Item System GDD will own. Never ATK/DEF — derived only. |

### SkillDefinition

| Field | Provisional safe range | Notes |
|---|---|---|
| `skill_type` | `&"attack"`, `&"heal"`, `&"buff"`, `&"debuff"` | Closed enum. |
| `mana_cost` | 5 – 80 | Skill System GDD will own. |
| `cooldown_sec` | 3 – 60 | |
| `scaling_coefficient` | 0.5 – 3.0 | Multiplier on `scaling_stat`. |

---

## Common Mistakes (validator will catch, but faster to avoid)

- **Rule 12 (loop seam) in release builds:** If `wave_entries[0].hp_mult * loop_hp_scale < wave_entries[loop_after_wave].hp_mult`, the curve will be dropped from `_templates` in release. Either (a) raise `loop_hp_scale`, (b) lower `wave_entries[loop_after_wave].hp_mult`, or (c) set `allow_loop_seam = true` with an explicit design reason. Debug warns regardless.
- **`stat_roll_ranges` keys:** only `&"str"`, `&"dex"`, `&"int"`, `&"vit"` — ATK and DEF are DERIVED, never rolled directly.
- **`StringName` vs `String`:** all ids and enum values use the `&"..."` prefix. Plain `"..."` strings will silently mismatch in Dictionary lookups.
- **Nested sub-resources:** do not drag a `Node` or a `RigidBody2D`-derived resource into a Balance Resource's field. `duplicate_deep()` cost becomes unbounded.
- **Duplicate ids within a family:** each family has its own namespace; `EnemyDefinition` with `id = &"slime"` and `ItemDefinition` with `id = &"slime"` is fine, but two `EnemyDefinition`s with `id = &"slime"` fails Rule 3.

---

## When This File Goes Away

- **Each section** migrates to the consumer GDD that owns it (per GDD Section G.1).
- **The 5-step quick start** may migrate to a Tools README if a balance-authoring tool is eventually built.
- **Common mistakes** migrate to whichever consumer GDD owns the validator rule.

Until then, this file is the authoring contract. Revise it when any of the underlying assumptions change.
