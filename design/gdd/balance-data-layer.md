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

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
