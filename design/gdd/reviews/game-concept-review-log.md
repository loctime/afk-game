# Review Log — game-concept.md (AFK RPG)

## Review — 2026-04-19 — Verdict: NEEDS REVISION (accepted with deferral)
Scope signal: XL (master concept document — covers 8–10 systems)
Specialists: None (lean depth, single-session structural review)
Blocking items: 3 | Recommended: 7 | Nice-to-have: 3

Summary: Documento fuerte como visión/pitch con tono claro, scope acotado e inventario de assets. Falla el estándar de GDD formal por ausencia de fórmulas cuantificadas, acceptance criteria testables y Player Fantasy como sección dedicada. Varias ambigüedades en combate (prioridad de habilidades, interacción taunt+ranged, reflect%) y sistemas (inventario sin cap, revive sin coste, gating de zonas). Aceptado como concepto maestro — bloqueantes se resolverán en los GDDs por sistema generados por /map-systems.

Prior verdict resolved: First review

### Blockers (3)
1. Formulas ausentes (STR→daño, VIT→HP, XP curve, wave scaling, offline efficiency %, habilidades iniciales)
2. Acceptance Criteria ausentes (sin condiciones testables por sistema)
3. Player Fantasy como sección formal (contenido existe embebido en Sección 1)

### Recommended (7)
4. Priorización de habilidades: definir orden total (taunt+HP bajo+múltiples skills)
5. Taunt + Ranged Poison interaction
6. Reflect: % concreto, base vs final damage, crítico
7. Inventario: capacidad máxima / comportamiento al llenarse
8. Revive sin coste: ¿decisión intencional? (rompe loop clásico AFK)
9. Layout de equipamiento 5 vs 2 columnas inconsistente (Sec 3.4)
10. Zonas/Mapas: criterio de desbloqueo (oleada, boss, oro)

### Nice-to-Have (3)
- Sección Pillars / No-Goals
- Glosario (Wave/Phase/Stage/Fase)
- Soft caps y tiers de oleada

### Deferral Plan
Los 3 bloqueantes se resolverán durante `/map-systems` + `/design-system` por sistema:
- **Formulas** → sistemas Combat, Progression, Wave-Scaling, Offline-Progress
- **Acceptance Criteria** → cada GDD de sistema los incluye por requisito del template
- **Player Fantasy** → puede quedar como anchor global en game-concept.md o replicarse por sistema
