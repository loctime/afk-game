class_name WaveScalingCurve
extends Resource

const CURRENT_SCHEMA: int = 1

@export var id: StringName = &""
@export var schema_version: int = CURRENT_SCHEMA
@export var wave_entries: Array[Dictionary] = []
@export var loop_after_wave: int = -1
@export var loop_hp_scale: float = 1.0
@export var loop_dmg_scale: float = 1.0
@export var allow_loop_seam: bool = false
