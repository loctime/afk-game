# Session State — Active

**Last Updated:** 2026-04-19 (pass 2 complete)
**Current Task:** Balance Data Layer GDD — pass-2 fresh-session review completed; NEEDS REVISION verdict with 8 blockers applied in-session
**Status:** Pass 1 (authoring+review): 5 blockers fixed. Pass 2 (fresh-session re-review, this session): 8 new blockers surfaced, all 8 applied. Systems index marked `In Review (revised 2026-04-19 pass 2)`. Review log updated with pass-2 entry.
**Active GDD:** design/gdd/balance-data-layer.md (pass 2 revisions applied)
**Sections complete:** All required (Overview, Player Fantasy, Detailed Design, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria) + H.7b split

## Next Action

`/clear` then run `/design-review design/gdd/balance-data-layer.md` in a **fresh Claude Code session** (pass 3) to validate the pass-2 revisions. Reviewer must not inherit this session's revision context. Expected verdict: APPROVED barring new issues.

## Pass-2 blocker fixes (8 applied, all blockers resolved in-session)

1. **Hot-reload sequence (C.1.8)** — `ResourceLoader.load(..., CACHE_MODE_IGNORE)` result used directly; atomic `_templates = new_templates` on success; `emit_signal("balance_database_reloaded", ok)` with typed `success` arg.
2. **`_assert_handler` Callable seam removed (C.1.4)** — replaced with `_validation_errors` accumulator + terminal `if _is_debug: assert(false, joined)`. AC-018/019/031/032 rewritten.
3. **Rule 12 severity + AC-051 split (C.1.1, C.1.6, H.7b)** — added `allow_loop_seam: bool = false` on WaveScalingCurve; release fails without override; AC-051 split into 051a (hp warn), 051b (dmg warn), 051c (release fail), 051d (release pass with override).
4. **Formula-level guards (D.1)** — `w < 0` fallback; `assert(loop_*_scale > 0)` at entry; `assert(is_finite(result))` at output.
5. **`defense_per_vit > 0` strict (C.1.6 Rule 5)** — pillar-protection invariant.
6. **Autoload-order hard constraint (C.1.4)** — BalanceDatabase MUST be autoload #1.
7. **AC-033/AC-035 unified BLOCKING (H.8)** — table row + summary paragraph aligned; `tools/ci/lint_forbidden_patterns.sh` is the blocking enforcement point.
8. **AC-016 key fix + H.8 stale row removed** — AC-016 uses valid key `&"str"`; duplicate-budget row struck through (AC-049 in Enemy System GDD).

## Pass-2 deferred items

- 12 RECOMMENDED items deferred to pass 3 or later GDDs (see review log pass-2 entry for full list).
- 4 NICE-TO-HAVE deferred.
- Ceremony trim-pass deferred until 2+ consumer GDDs exist.

## Progress Checklist

- [x] Game concept placed at `design/gdd/game-concept.md`
- [x] `/design-review` run on game-concept (verdict: NEEDS REVISION, accepted with deferral)
- [x] `/setup-engine` run — Godot 4.6 + GDScript + Mobile/Desktop + GdUnit4 configured
- [x] `/map-systems` run — 25 systems enumerated
- [x] **First MVP GDD authored**: `design/gdd/balance-data-layer.md`
- [x] `/design-review` pass 1 (authoring session) — 5 blockers applied
- [x] `/design-review` pass 2 (this fresh session) — 8 blockers applied
- [ ] `/design-review` pass 3 (next fresh session) — validate pass-2 fixes, expected APPROVED
- [ ] Next MVP GDD: Game State Manager (Foundation layer, next in design order)
- [ ] All 21 MVP GDDs authored
- [ ] `/review-all-gdds` holistic check
- [ ] `/gate-check pre-production`

## To Resume

Abrir nueva sesión en este directorio y correr:
`/design-system balance-data-layer`

El skill detecta las secciones completas en el archivo y retoma desde Detailed Design automáticamente. No hay que repetir decisiones previas.

## Progress Checklist

- [x] Game concept placed at `design/gdd/game-concept.md`
- [x] `/design-review` run on game-concept (verdict: NEEDS REVISION, accepted with deferral — bloqueantes resolverán en GDDs por sistema)
- [x] `/setup-engine` run — Godot 4.6 + GDScript + Mobile/Desktop + GdUnit4 configured
- [x] `/map-systems` run — 25 systems enumerated, dependency-mapped, priority-assigned
- [ ] First MVP GDD authored (recommended: Balance Data Layer)
- [ ] All 21 MVP GDDs authored
- [ ] `/review-all-gdds` holistic check
- [ ] `/gate-check pre-production`

## Key Decisions

- **Engine**: Godot 4.6 (HIGH knowledge risk — agents must read engine-reference/godot/VERSION.md)
- **Language**: GDScript
- **Review mode**: lean (directors gate only at phase transitions)
- **Platform**: Mobile primary + Desktop secondary; Touch primary input; 60fps / 16.6ms / 100 draw calls / 512MB
- **Testing**: GdUnit4
- **MVP scope**: 21 systems, Vertical Slice adds 4 more (Audio, Parallax, Settings, Map)
- **Deferred (Sec 14)**: pets, crafting, guilds, dungeons, multi-zone enemy tables, extra skills

## Files Created/Modified

- `design/gdd/game-concept.md` (moved from repo root)
- `design/gdd/reviews/game-concept-review-log.md`
- `design/gdd/systems-index.md`
- `CLAUDE.md` (Technology Stack updated)
- `.claude/docs/technical-preferences.md` (fully populated)
- `production/review-mode.txt` = `lean`

## Open Questions (for future sessions)

- Concrete formulas (STR→damage, VIT→HP, XP curve, wave HP scaling, offline efficiency %): deferred to per-system GDDs
- Inventory capacity cap: TBD in Inventory & Equipment GDD
- Revive cost/penalty: decision pending — current design is free revive
- Zone unlock gating (by wave/boss/gold): TBD in Map/Zone Panel GDD

## Next Recommended Actions

1. `/prototype combat-engine` — validate core loop before writing its big GDD (High-risk system)
2. OR `/design-system balance-data-layer` — start authoring MVP Foundation GDDs in order
