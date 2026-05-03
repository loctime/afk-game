class_name SkillDefinition
extends Resource

const CURRENT_SCHEMA: int = 1

@export var id: StringName = &""
@export var schema_version: int = CURRENT_SCHEMA
@export var display_name: String = ""
@export var skill_type: StringName = &"attack"
@export var mana_cost: float = 0.0
@export var cooldown_sec: float = 0.0
@export var scaling_stat: StringName = &"str"
@export var scaling_coefficient: float = 1.0
@export var effect_tags: Array[StringName] = []
@export var icon_path: String = ""
