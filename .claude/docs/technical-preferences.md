# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Forward+ (desktop) / Mobile renderer (mobile exports)
- **Physics**: Jolt (default in Godot 4.6)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Windows/Linux/macOS), Mobile (Android + iOS)
- **Input Methods**: Touch (primary), Mouse (desktop), Keyboard (desktop shortcuts only)
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: Orientación vertical en mobile. Mouse en desktop emula tap (single click = tap). No hover-only interactions. Los tap targets mínimos 48x48dp. HUD debe ser legible a brazo extendido en phone.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`, `current_hp`)
- **Functions**: snake_case (e.g., `take_damage()`, `spawn_wave()`)
- **Signals**: snake_case past tense (e.g., `health_changed`, `wave_completed`, `boss_defeated`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HP`, `BOSS_WAVE_INTERVAL`)

## Performance Budgets

Budgets target mobile-friendly performance (primary platform). Desktop will exceed these easily.

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms/frame
- **Draw Calls**: ≤ 100 per frame
- **Memory Ceiling**: ≤ 512 MB RAM (device-side, mobile target)
- **Texture Budget**: ≤ 128 MB VRAM (mobile)
- **Startup Time**: < 3 s cold start on mid-range Android (2020+)

## Testing

- **Framework**: GdUnit4
- **Minimum Coverage**: 70% for formula/balance code, 50% overall
- **Required Tests**: Balance formulas, wave scaling, XP curves, offline progression simulator, combat damage calculations, inventory operations
- **CI Command**: `godot --headless --import && godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/`

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- GdUnit4 (testing framework)
- [Additional addons will be added as they are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
