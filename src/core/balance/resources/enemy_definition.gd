class_name EnemyDefinition
extends Resource

const CURRENT_SCHEMA: int = 1

@export var id: StringName = &""
@export var schema_version: int = CURRENT_SCHEMA
@export var display_name: String = ""
@export var base_hp: float = 1.0
@export var base_damage: float = 1.0
@export var behavior_tag: StringName = &"melee"
@export var size_category: StringName = &"small"
@export var sprite_path: String = ""
@export var drop_table_id: StringName = &""
