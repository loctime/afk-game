class_name ItemDefinition
extends Resource

const CURRENT_SCHEMA: int = 1

@export var id: StringName = &""
@export var schema_version: int = CURRENT_SCHEMA
@export var display_name: String = ""
@export var rarity: StringName = &"common"
@export var slot: StringName = &"weapon"
@export var stat_roll_ranges: Dictionary = {}
@export var icon_path: String = ""
