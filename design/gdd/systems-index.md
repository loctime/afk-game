# Systems Index: AFK RPG

> **Status**: Draft
> **Created**: 2026-04-19
> **Last Updated**: 2026-04-19
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

AFK RPG es un idle RPG 2D side-view para mobile+desktop donde el personaje pelea oleadas de enemigos automáticamente mientras el jugador gestiona stats, equipamiento y habilidades. El loop central requiere: combate automático por rondas, oleadas con boss gate cada 10, progresión de stats con XP, sistema de items con 4 rarezas y 13 slots de equipamiento, y simulación offline. La complejidad mecánica es media-alta; la UI tiene 7 pantallas; la fricción está en 4 sistemas (Balance Data Layer, Combat Engine, Wave & Phase Manager, Offline Progression) que son cuellos de botella técnicos o de diseño.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| 1 | Game State Manager | Core | MVP | Not Started | — | (none) |
| 2 | Balance Data Layer | Core | MVP | Designed | [balance-data-layer.md](balance-data-layer.md) | (none) |
| 3 | Save/Load System (inferred) | Persistence | MVP | Not Started | — | Balance Data Layer |
| 4 | Audio System | Audio | VS | Not Started | — | (none) |
| 5 | Character Stats & Leveling | Progression | MVP | Not Started | — | Balance Data Layer, Save/Load |
| 6 | Item System | Economy | MVP | Not Started | — | Balance Data Layer |
| 7 | UI Framework & Navigation (inferred) | UI | MVP | Not Started | — | Game State Manager |
| 8 | Character Animation Controller | Presentation | MVP | Not Started | — | (event-driven) |
| 9 | Combat Engine | Gameplay | MVP | Not Started | — | Character Stats, Balance Data, Animation Controller |
| 10 | Enemy System | Gameplay | MVP | Not Started | — | Balance Data, Combat Engine |
| 11 | Skill System | Gameplay | MVP | Not Started | — | Combat Engine, Balance Data |
| 12 | Status Effects | Gameplay | MVP | Not Started | — | Combat Engine |
| 13 | Drop & Loot Tables (inferred) | Economy | MVP | Not Started | — | Item System, Enemy System |
| 14 | Wave & Phase Manager | Gameplay | MVP | Not Started | — | Enemy System, Game State Manager |
| 15 | Revive & Game Over | Gameplay | MVP | Not Started | — | Character Stats, Game State, Wave & Phase |
| 16 | Inventory & Equipment | Economy | MVP | Not Started | — | Item System, Character Stats, Save/Load |
| 17 | Offline Progression | Progression | MVP | Not Started | — | Combat Engine (sim), Character Stats, Wave Manager, Save/Load |
| 18 | Combat VFX & Floating Numbers | Presentation | MVP | Not Started | — | Combat Engine (event-driven) |
| 19 | Combat HUD | UI | MVP | Not Started | — | Combat Engine, Character Stats, Wave Manager, Skill System, Status Effects |
| 20 | Character Panel | UI | MVP | Not Started | — | Character Stats, Inventory |
| 21 | Inventory/Equipment Panel | UI | MVP | Not Started | — | Inventory & Equipment |
| 22 | Boss Gate Modal | UI | MVP | Not Started | — | Wave & Phase Manager, Game State Manager |
| 23 | Parallax Background System | Presentation | VS | Not Started | — | UI Framework (for selector) |
| 24 | Settings Panel | UI | VS | Not Started | — | Audio, Save/Load |
| 25 | Map/Zone Panel | UI | VS | Not Started | — | Game State Manager |

---

## Categories

| Category | Description | Systems in This Project |
|---|---|---|
| **Core** | Foundation systems everything depends on | Game State Manager, Balance Data Layer |
| **Gameplay** | Systems that make the game fun | Combat Engine, Enemy System, Skill System, Status Effects, Wave & Phase Manager, Revive & Game Over |
| **Progression** | How the player grows over time | Character Stats & Leveling, Offline Progression |
| **Economy** | Resource creation and consumption | Item System, Drop & Loot Tables, Inventory & Equipment |
| **Persistence** | Save state and continuity | Save/Load System |
| **UI** | Player-facing information displays | UI Framework, Combat HUD, Character Panel, Inventory Panel, Boss Gate Modal, Settings Panel, Map/Zone Panel |
| **Audio** | Sound and music systems | Audio System |
| **Presentation** | Visual presentation wrapping gameplay | Character Animation Controller, Combat VFX & Floating Numbers, Parallax Background |

Not included (per GDD Sec 14 — deferred to Alpha/Full Vision): Narrative (no story systems), Meta (no tutorials/analytics in MVP), Pets, Crafting, Guilds, Dungeons.

---

## Priority Tiers

| Tier | Definition | Target Milestone | Count in This Project |
|---|---|---|---|
| **MVP** | Required for core AFK loop to function end-to-end | First playable prototype | 21 |
| **Vertical Slice** | Required for a polished complete experience in 1 zone | VS demo / soft launch | 4 |
| **Alpha** | Scope expansion — multi-zone, roadmap features | Alpha milestone | 0 (added when scoped) |
| **Full Vision** | Polish, pets, crafting, guilds, dungeons | Release | 0 (added when scoped) |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Game State Manager** — state machine (menu → game → paused → game-over → boss-gate). Foundation for all flow control.
2. **Balance Data Layer** — Godot Resource (.tres) definitions for enemies, skills, items, wave scaling. Pure data — no runtime deps.
3. **Audio System** — music + SFX buses + volume config. Independent.

### Core Layer (depends on foundation)

1. **Save/Load System** — depends on: Balance Data Layer (for item/enemy IDs in saved state).
2. **Character Stats & Leveling** — depends on: Balance Data Layer, Save/Load.
3. **Item System** — depends on: Balance Data Layer.
4. **UI Framework & Navigation** — depends on: Game State Manager.
5. **Character Animation Controller** — depends on: (event-driven, minimal; listens to Combat events).

### Feature Layer (depends on core)

1. **Combat Engine** — depends on: Character Stats, Balance Data Layer, Audio, Animation Controller.
2. **Enemy System** — depends on: Balance Data Layer, Combat Engine.
3. **Skill System** — depends on: Combat Engine, Balance Data Layer.
4. **Status Effects** — depends on: Combat Engine.
5. **Drop & Loot Tables** — depends on: Item System, Enemy System.
6. **Wave & Phase Manager** — depends on: Enemy System, Game State Manager.
7. **Revive & Game Over** — depends on: Character Stats, Game State Manager, Wave & Phase Manager.
8. **Inventory & Equipment** — depends on: Item System, Character Stats, Save/Load.
9. **Offline Progression** — depends on: Combat Engine (simulated), Character Stats, Wave Manager, Save/Load.
10. **Combat VFX & Floating Numbers** — depends on: Combat Engine (event-driven).
11. **Parallax Background** — depends on: UI Framework (for bg selector).

### Presentation Layer (wraps feature systems)

1. **Combat HUD** — depends on: Combat Engine, Character Stats, Wave Manager, Skill System, Status Effects.
2. **Character Panel** — depends on: Character Stats & Leveling, Inventory & Equipment.
3. **Inventory/Equipment Panel** — depends on: Inventory & Equipment.
4. **Map/Zone Panel** — depends on: Game State Manager.
5. **Settings Panel** — depends on: Audio, Save/Load.
6. **Boss Gate Modal** — depends on: Wave & Phase Manager, Game State Manager.

### Polish Layer

(None in this MVP — polish systems like tutorials, analytics, accessibility are deferred to Alpha+.)

---

## Recommended Design Order

Diseñar en este orden. Cada GDD debe estar completo y revisado antes de empezar el siguiente, aunque sistemas independientes en el mismo layer pueden paralelizarse.

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|---|---|---|---|---|---|
| 1 | Balance Data Layer | MVP | Foundation | systems-designer + game-designer | M |
| 2 | Game State Manager | MVP | Foundation | systems-designer | S |
| 3 | Save/Load System | MVP | Core | systems-designer + security-engineer | M |
| 4 | Character Stats & Leveling | MVP | Core | systems-designer + economy-designer | M |
| 5 | Item System | MVP | Core | economy-designer + systems-designer | M |
| 6 | UI Framework & Navigation | MVP | Core | ux-designer + ui-programmer | M |
| 7 | Character Animation Controller | MVP | Core | gameplay-programmer | S |
| 8 | Combat Engine | MVP | Feature | game-designer + systems-designer + ai-programmer | **L** |
| 9 | Enemy System | MVP | Feature | game-designer + ai-programmer | **L** |
| 10 | Skill System | MVP | Feature | game-designer + systems-designer | M |
| 11 | Status Effects | MVP | Feature | systems-designer | S |
| 12 | Drop & Loot Tables | MVP | Feature | economy-designer | M |
| 13 | Wave & Phase Manager | MVP | Feature | game-designer + level-designer | **L** |
| 14 | Revive & Game Over | MVP | Feature | game-designer | S |
| 15 | Inventory & Equipment | MVP | Feature | economy-designer + ux-designer | M |
| 16 | Offline Progression | MVP | Feature | economy-designer + systems-designer | **L** |
| 17 | Combat VFX & Floating Numbers | MVP | Feature | technical-artist + gameplay-programmer | M |
| 18 | Combat HUD | MVP | Presentation | ux-designer | M |
| 19 | Character Panel | MVP | Presentation | ux-designer | M |
| 20 | Inventory/Equipment Panel | MVP | Presentation | ux-designer | M |
| 21 | Boss Gate Modal | MVP | Presentation | ux-designer | S |
| 22 | Audio System | VS | Foundation | audio-director | M |
| 23 | Parallax Background | VS | Feature | technical-artist | S |
| 24 | Settings Panel | VS | Presentation | ux-designer | S |
| 25 | Map/Zone Panel | VS | Presentation | ux-designer + game-designer | S |

Effort: S = 1 session (~30-60 min), M = 2-3 sessions, L = 4+ sessions.

Totales estimados:
- MVP: 9 S + 8 M + 4 L = ~30-40 sesiones de authoring
- VS: 1 M + 3 S = ~5 sesiones

---

## Circular Dependencies

- **Combat Engine ↔ Enemy System** — Combat necesita estado de enemigos (HP, status) y Enemies necesitan Combat para aplicar daño. **Resolución:** Combat Engine es el **mediador autoritativo** — ejecuta todas las mutaciones de HP y status. Enemies son *data + behavior definitions* + *instances con estado pasivo* que emiten señales de intención (ej: `attack_requested`) que Combat Engine resuelve. Diseñar Combat primero, luego Enemy System sabiendo qué contrato debe cumplir.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| **Balance Data Layer** | Technical | Schema mal pensado bloquea todo: si rediseñás el formato de items o enemigos después de tener 20+ Resources creados, es trabajo manual. | Diseñar schema con vista a futuro (pets, crafting como campos opcionales). Prototipar 2-3 Resources de ejemplo antes de escribir el GDD final. |
| **Combat Engine** | Design+Scope | Priorización de skills, ataque básico, taunt, reflect, multi-enemigo, mana regen, cooldowns — muchas reglas interactuando. Alto risk de scope creep. | Prototipar el core loop (1 enemigo + 1 skill + ataque básico) antes de formalizar GDD. Escribir reglas en pseudocódigo. `/prototype` temprano. |
| **Wave & Phase Manager** | Design | Curva de dificultad define si el juego es jugable o frustrante. Balance crítico para AFK feel. | Balance pass intensivo en `/design-system`. Curvas parametrizadas, no hardcoded. Playtest con tiempo real offline. |
| **Offline Progression** | Design+Security | Matemática compleja + exploitable si el sim es muy generoso (jugador cambia reloj del dispositivo) o muy pobre (jugadores se frustran). Diff con online efficiency %. | Cap duro de horas (GDD sugiere límite). Validar timestamp contra server cuando haya backend. Para MVP local: detectar tiempo futuro/pasado inconsistente. Fórmula simple: `rewards = wave_in_progress.rate × time × efficiency × multiplier`. |

---

## Progress Tracker

| Metric | Count |
|---|---|
| Total systems identified | 25 |
| Design docs started | 1 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 1/21 |
| Vertical Slice systems designed | 0/4 |

---

## Next Steps

- [ ] Prototype Combat Engine core loop before formalizing its GDD — `/prototype combat-engine`
- [ ] Design MVP Foundation systems first (in order): Balance Data Layer → Game State Manager → Save/Load
- [ ] Run `/design-system balance-data-layer` as the first GDD (schema definition is foundational)
- [ ] Run `/design-review design/gdd/[system].md` after each GDD is authored (in a fresh session for context)
- [ ] Run `/review-all-gdds` once ≥5 MVP GDDs exist — catch cross-system inconsistencies early
- [ ] Run `/gate-check pre-production` when all MVP GDDs are authored and reviewed
- [ ] Update this index after each GDD is approved (change Status column, increment Progress Tracker)
