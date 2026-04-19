# Review Log — balance-data-layer.md

## Review — 2026-04-19 (pass 2) — Verdict: NEEDS REVISION (revisions applied in-session, awaiting fresh-session re-review)
Scope signal: L (unchanged — multi-system foundation hub; 1 formula, 5 Resource families, 12 validator rules, 57 ACs after split, 8 hard downstream dependents)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 8 (all applied) | Recommended: 12 (deferred) | Nice-to-have: 4 (deferred)

Summary: Fresh-session re-review of pass-1 revisions. Prior 5 blockers confirmed resolved (slot enum, stat namespace, wave-loop validator, C.1.7 vs E.5 contradiction, test contracts). 8 new/tighter blockers surfaced and all resolved in session. Key fixes: hot-reload `CACHE_MODE_IGNORE` misuse + missing signal `success` arg corrected; `_assert_handler` Callable seam removed in favor of accumulator+terminal-assert pattern; Rule 12 loop-boundary severity upgraded to release-fail with `allow_loop_seam` override; formula-level `is_finite()` guards added; `defense_per_vit > 0` strict enforced; autoload-ordering promoted from edge-case to hard constraint; AC-033/AC-035 gate classification unified; AC-016 key fix + H.8 stale row removed. Pass-2 arithmetic verification (AC-022/023/024) independently agreed — prior dispute closed.

Prior verdict resolved: Yes — all 5 pass-1 blockers confirmed held after fresh-session inspection.

### Blockers applied (8)
1. **Hot-reload sequence (C.1.8)** — rewritten to load into fresh dict using returned `ResourceLoader.load(..., CACHE_MODE_IGNORE)` value directly; atomic `_templates = new_templates` on success. `emit_signal("balance_database_reloaded", ok)` with required typed `success: bool` arg.
2. **`_assert_handler` seam removed (C.1.4)** — replaced with `_validation_errors: Array[String]` accumulator + terminal `if _is_debug: assert(false, joined_errors)`. AC-018/019/031/032 rewritten to test real debug/release branches without a Callable seam.
3. **Rule 12 severity + AC-051 split (C.1.1, C.1.6, H.7b)** — added `allow_loop_seam: bool = false` field to `WaveScalingCurve`. Rule 12: debug always warns; release fails unless override. AC-051 split into 051a (hp debug warn), 051b (dmg debug warn), 051c (release fail no override), 051d (release pass with override).
4. **Formula-level degeneracy guards (D.1)** — added mandatory implementation guards: `w < 0` fallback returns `wave_entries[0]` (prevents GDScript negative-index wrap); `assert(loop_*_scale > 0)` at entry; `assert(is_finite(result))` at output. Covers INF/NaN propagation into Combat Engine.
5. **`defense_per_vit > 0` strict (C.1.6 Rule 5)** — pillar-protection invariant. Allows no silent drop of VIT's damage-reduction role from concept §7.2.
6. **Autoload-order hard constraint (C.1.4)** — promoted from E.4 edge case to hard rule: "BalanceDatabase MUST be autoload #1; peer autoloads listed before it cannot safely call getters or await database_ready."
7. **AC-033/AC-035 unified BLOCKING classification (H.8)** — table row updated to `Logic (blocking)`; summary paragraph rewritten to list explicit blocking gates including all three lint ACs (AC-033, AC-035, AC-052) via `tools/ci/lint_forbidden_patterns.sh`.
8. **AC-016 key fix + H.8 stale row removed** — AC-016 uses valid key `&"str"` with inverted Vector2 (isolates Rule 10 from Rule 6). H.8 duplicate-budget row struck through, pointing to Enemy System GDD per AC-049.

### Specialist convergences
- `_assert_handler` architecture (systems-designer + godot-gdscript-specialist agreed from different angles — creative-director adjudicated removal).
- Hot-reload signal arity (game-designer framed as NICE-TO-HAVE; godot-specialist framed as BLOCKING — creative-director adjudicated BLOCKING since runtime error on every reload breaks the designer pillar).
- AC-022/023/024 arithmetic (qa-lead and systems-designer independently re-verified correct — prior pass-1 dispute closed).

### Specialist disagreement resolutions
- **AC-004 synchronous-init contract** — qa-lead BLOCKING; creative-director downgraded to RECOMMENDED (missing-spec gap, not broken behavior). Deferred with other recommended items.
- **Ceremony concern** — prior creative-director note acknowledged as tolerated tradeoff. Trim-down pass deferred until Foundation ships and 2+ consumer GDDs exist to validate load-bearing ACs.

### Recommended deferred (12)
Slot-enum display-mapping pointer; derived-stat display contract pointer; spawn-count loop scaling (concept §5.2); boss-wave difficulty multiplier (concept §5.3); AC-029 negative-index guard (now covered by Edit 5 guard, verify in re-review); `spawn_count = 0` warning; OQ-1 pre-implementation gate for H.5; injection seam release-mode coverage AC; `loot_tier` typeof() mechanism explicit; Rule 13 nested Node-resource guard; `balance_load_failed` NOT-fire-in-debug AC; AC-004 synchronous-init contract text.

### Nice-to-have deferred (4)
AC-052 grep heuristic blind-spot note; AC-055 migration-tool headless-compat classification; post-MVP trim pass (extract migration framework to appendix); AC-047 Android 500ms budget verification (OQ-2 owns).

---

## Review — 2026-04-19 (pass 1) — Verdict: MAJOR REVISION NEEDED (revisions applied in-session)
Scope signal: L (multi-system integration hub — 1 formula, 5 Resource families, 11→12 validator rules, 50→55 ACs, 8 hard downstream dependents, hot-reload infra, schema migration tooling)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 5 | Recommended: 3 | Nice-to-have: 4

Summary: First MVP GDD (Foundation layer). Architecturally sound but carried three load-bearing schema holes (slot enum collapse from 13→3, mixed base/derived stat namespace, wave-loop boundary 42% difficulty drop), one doc-internal contradiction (C.1.7 `_init()` claim vs E.5), and several under-specified test contracts. All five blockers + all three recommended fixes applied in-session. Awaiting fresh-session re-review to confirm fixes hold.

Prior verdict resolved: First review (no prior).

### Blockers applied (5)
1. **Slot enum** — expanded `ItemDefinition.slot` closed enum from 3 categories to 13 concrete values matching concept §3.4 (helmet, chest, pants, boots, gloves, shield, weapon, necklace, wings, bracelet, ring, artifact, pet). Per-slot-count logic (2× rings, 2× bracelets, 2× artifacts) deferred to Inventory & Equipment GDD per the comment in C.1.2.
2. **Mixed stat namespace** — `stat_roll_ranges` keys reduced to base stats only `{str, dex, int, vit}`. ATK/DEF remain derived via `CharacterProgressionCurve` coefficients.
3. **Wave-loop validator gaps** — rule 5 extended to enforce `loop_hp_scale > 0`, `loop_dmg_scale > 0`, per-entry `hp_mult > 0`, `dmg_mult > 0`, `spawn_count ≥ 0`, `loot_tier ≥ 0`. New rule 12 (warning) detects the 42% loop-boundary difficulty drop invariant violation. AC-051 covers the warning path.
4. **C.1.7 vs E.5 contradiction** — removed the `_init()` default claim from C.1.7; replaced with canonical `@export`-line default instruction matching E.5. Added explicit statement that each Resource family has its own `CURRENT_SCHEMA` constant.
5. **Test contracts** — added injection seams (`_is_debug`, `_error_reporter`, `_assert_handler`) to BalanceDatabase API (C.1.4); rewrote AC-018/019/031/032 to use them. AC-033/035 defined concrete regex + script path (`tools/ci/lint_forbidden_patterns.sh`) + CI step name; AC-033 promoted from ADVISORY to BLOCKING. AC-049 moved to Enemy System GDD (cross-GDD dependency). Rule 7 extended to validate `wave_entries` Dictionary per-entry keys/types. Formal signal signature `balance_database_reloaded(success: bool)` declared.

### Recommended applied (3)
6. **`defense_per_vit` added to `CharacterProgressionCurve`** — gives VIT's damage-reduction effect from concept §7.2 a data home.
7. **`loot_tier: int` added as required key on `WaveScalingCurve.wave_entries`** — reserves the field so Drop & Loot Tables GDD can bias drop weights by wave without a schema migration.
8. **Enum alignments + `await` guard pattern** — `behavior_tag` {melee, ranged, aggressive, tank}; `size_category` adds `huge`; `skill_type` adds `debuff`; canonical `if not is_ready: await database_ready` snippet added in C.1.4.

### Other clarifications
- `loop_count` variable-table description rewritten — 1-indexed once looping is active; `0` for pre-loop/no-loop.
- AC-050 baseline measurement methodology concretized (pre-ready hook + post-`database_ready` delta; reference Android device logged in `production/qa/evidence/balance-memory-smoke.md`).
- 5 new ACs: AC-051 (loop-boundary warning), AC-052 (per-frame getter ban), AC-053 (one-time clamp warning), AC-054 (unrecognized-class skip), AC-055 (migration tool `schema_version == 0`).

### Specialist disagreement resolutions
- **AC-024 arithmetic** — qa-lead flagged as wrong; creative-director agreed. Verified independently against the formula (`loop_span=10, offset=13, loop_count = 13/10 + 1 = 2`). **AC-024 is correct as written.** QA-lead's calculation missed the `+1` term in the formula. No edit applied.
- **Slot enum fix-now vs defer** — resolved as fix-now per creative-director. This review's cheapest window.
- **DropTableDefinition deferral** — GDD stays deferred; field reservation (`loot_tier`) added here to avoid later migration.

### Remaining work (for fresh-session re-review)
- **Unverified**: OQ-1 `CACHE_MODE_IGNORE` constant name in Godot 4.6 — still an Open Question; must be resolved before C.1.8 implementation.
- **Pillar tension** (flagged by creative-director, not resolved): GDD is ceremony-heavy (844 lines, migration framework, dev-only hot reload) for a layer meant to enable effortless balance iteration. Live-service balance strategy not addressed. Consider addressing in a follow-up pass if/when a retention-tuning need is surfaced.

### Nice-to-have (deferred)
- Post-launch live-balance strategy (remote config / fallback).
- 5-step quick-reference for designers ("how to add a new enemy").
- Verify `.godot/uid_cache.bin` path against Godot 4.6.
- Split `test_validator_rules.gd` into focused suite files per rule family.
