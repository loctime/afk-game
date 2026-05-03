class_name CharacterProgressionCurve
extends Resource

const CURRENT_SCHEMA: int = 1

@export var id: StringName = &"default"
@export var schema_version: int = CURRENT_SCHEMA
@export var xp_per_level: Array[float] = [0.0]
@export var max_level: int = 0
@export var hp_per_vit: float = 1.0
@export var defense_per_vit: float = 0.1
@export var mana_per_int: float = 1.0
@export var atk_per_str: float = 1.0
@export var speed_per_dex: float = 0.1
@export var base_stats: Dictionary = {
	&"str": 1,
	&"dex": 1,
	&"int": 1,
	&"vit": 1
}
@export var stat_points_per_level: int = 1
