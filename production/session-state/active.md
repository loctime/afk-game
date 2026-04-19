# Session State — Active

**Last Updated:** 2026-04-19
**Current Task:** Balance Data Layer GDD — COMPLETE (Designed, pending review)
**Status:** All 8 required sections + UI Requirements + Cross-References + Open Questions written. Registry seeded. Systems index updated.
**Active GDD:** design/gdd/balance-data-layer.md (844 lines)
**Sections complete:** All required (A–H) + optional stubs

## Next Action

Run `/design-review design/gdd/balance-data-layer.md` in a **fresh Claude Code session** to validate this GDD independently. Do NOT run in this session — the reviewer must not inherit the authoring context.

## Progress Checklist

- [x] Game concept placed at `design/gdd/game-concept.md`
- [x] `/design-review` run on game-concept (verdict: NEEDS REVISION, accepted with deferral)
- [x] `/setup-engine` run — Godot 4.6 + GDScript + Mobile/Desktop + GdUnit4 configured
- [x] `/map-systems` run — 25 systems enumerated
- [x] **First MVP GDD authored**: `design/gdd/balance-data-layer.md`
- [ ] `/design-review design/gdd/balance-data-layer.md` in fresh session
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
