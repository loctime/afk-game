extends Node

const MANIFEST_PATH: String = "res://assets/data/BalanceManifest.tres"

const ENEMY_BEHAVIORS := {
	&"melee": true,
	&"ranged": true,
	&"aggressive": true,
	&"tank": true
}
const ENEMY_SIZES := {
	&"small": true,
	&"medium": true,
	&"large": true,
	&"huge": true
}
const ITEM_RARITIES := {
	&"common": true,
	&"rare": true,
	&"epic": true,
	&"legendary": true
}
const ITEM_SLOTS := {
	&"helmet": true,
	&"chest": true,
	&"pants": true,
	&"boots": true,
	&"gloves": true,
	&"shield": true,
	&"weapon": true,
	&"necklace": true,
	&"wings": true,
	&"bracelet": true,
	&"ring": true,
	&"artifact": true,
	&"pet": true
}
const BASE_STATS := {
	&"str": true,
	&"dex": true,
	&"int": true,
	&"vit": true
}
const SKILL_TYPES := {
	&"attack": true,
	&"heal": true,
	&"buff": true,
	&"debuff": true
}

var is_ready: bool = false
signal database_ready
signal balance_load_failed

var _enemies: Dictionary = {}
var _items: Dictionary = {}
var _skills: Dictionary = {}
var _wave_curves: Dictionary = {}
var _progressions: Dictionary = {}


func _ready() -> void:
	var ok: bool = _load_all()
	if ok:
		is_ready = true
		database_ready.emit()
	else:
		balance_load_failed.emit()


func get_enemy(id: StringName) -> EnemyDefinition:
	return _enemies.get(id) as EnemyDefinition


func has_enemy(id: StringName) -> bool:
	return _enemies.has(id)


func get_item(id: StringName) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func has_item(id: StringName) -> bool:
	return _items.has(id)


func get_skill(id: StringName) -> SkillDefinition:
	return _skills.get(id) as SkillDefinition


func has_skill(id: StringName) -> bool:
	return _skills.has(id)


func get_wave_curve(id: StringName) -> WaveScalingCurve:
	return _wave_curves.get(id) as WaveScalingCurve


func has_wave_curve(id: StringName) -> bool:
	return _wave_curves.has(id)


func get_progression(id: StringName) -> CharacterProgressionCurve:
	return _progressions.get(id) as CharacterProgressionCurve


func has_progression(id: StringName) -> bool:
	return _progressions.has(id)


func _load_all() -> bool:
	_clear_indexes()
	var manifest := ResourceLoader.load(MANIFEST_PATH, "BalanceManifest") as BalanceManifest
	if manifest == null:
		push_error("BalanceDatabase: missing manifest at %s" % MANIFEST_PATH)
		return false

	var has_error: bool = false
	for path: String in manifest.paths:
		if not ResourceLoader.exists(path):
			push_error("BalanceDatabase: manifest entry not found: %s" % path)
			has_error = true
			continue

		var resource := ResourceLoader.load(path) as Resource
		if resource == null:
			push_error("BalanceDatabase: failed to load resource: %s" % path)
			has_error = true
			continue

		if not _validate_resource(resource, path):
			has_error = true
			continue

		_index_resource(resource)

	return not has_error


func _clear_indexes() -> void:
	_enemies.clear()
	_items.clear()
	_skills.clear()
	_wave_curves.clear()
	_progressions.clear()


func _validate_resource(resource: Resource, path: String) -> bool:
	if resource is EnemyDefinition:
		return _validate_enemy(resource as EnemyDefinition, path)
	if resource is ItemDefinition:
		return _validate_item(resource as ItemDefinition, path)
	if resource is SkillDefinition:
		return _validate_skill(resource as SkillDefinition, path)
	if resource is WaveScalingCurve:
		return _validate_wave_curve(resource as WaveScalingCurve, path)
	if resource is CharacterProgressionCurve:
		return _validate_progression(resource as CharacterProgressionCurve, path)

	push_warning("BalanceDatabase: unsupported resource type at %s (%s), skipped." % [path, resource.get_class()])
	return false


func _validate_enemy(def: EnemyDefinition, path: String) -> bool:
	if not _validate_common(def.id, def.schema_version, EnemyDefinition.CURRENT_SCHEMA, path):
		return false
	if def.base_hp <= 0.0 or def.base_damage <= 0.0:
		push_error("BalanceDatabase: EnemyDefinition '%s' must have base_hp/base_damage > 0." % def.id)
		return false
	if not ENEMY_BEHAVIORS.has(def.behavior_tag):
		push_error("BalanceDatabase: EnemyDefinition '%s' has invalid behavior_tag." % def.id)
		return false
	if not ENEMY_SIZES.has(def.size_category):
		push_error("BalanceDatabase: EnemyDefinition '%s' has invalid size_category." % def.id)
		return false
	return true


func _validate_item(def: ItemDefinition, path: String) -> bool:
	if not _validate_common(def.id, def.schema_version, ItemDefinition.CURRENT_SCHEMA, path):
		return false
	if not ITEM_RARITIES.has(def.rarity):
		push_error("BalanceDatabase: ItemDefinition '%s' has invalid rarity." % def.id)
		return false
	if not ITEM_SLOTS.has(def.slot):
		push_error("BalanceDatabase: ItemDefinition '%s' has invalid slot." % def.id)
		return false
	for stat_key in def.stat_roll_ranges.keys():
		if not BASE_STATS.has(stat_key):
			push_error("BalanceDatabase: ItemDefinition '%s' has invalid stat key: %s." % [def.id, stat_key])
			return false
	return true


func _validate_skill(def: SkillDefinition, path: String) -> bool:
	if not _validate_common(def.id, def.schema_version, SkillDefinition.CURRENT_SCHEMA, path):
		return false
	if not SKILL_TYPES.has(def.skill_type):
		push_error("BalanceDatabase: SkillDefinition '%s' has invalid skill_type." % def.id)
		return false
	if def.mana_cost < 0.0 or def.cooldown_sec < 0.0:
		push_error("BalanceDatabase: SkillDefinition '%s' must have mana_cost/cooldown_sec >= 0." % def.id)
		return false
	if not BASE_STATS.has(def.scaling_stat):
		push_error("BalanceDatabase: SkillDefinition '%s' has invalid scaling_stat." % def.id)
		return false
	return true


func _validate_wave_curve(def: WaveScalingCurve, path: String) -> bool:
	if not _validate_common(def.id, def.schema_version, WaveScalingCurve.CURRENT_SCHEMA, path):
		return false
	if def.loop_after_wave < -1:
		push_error("BalanceDatabase: WaveScalingCurve '%s' has invalid loop_after_wave." % def.id)
		return false
	if def.loop_hp_scale <= 0.0 or def.loop_dmg_scale <= 0.0:
		push_error("BalanceDatabase: WaveScalingCurve '%s' must have positive loop scales." % def.id)
		return false
	return true


func _validate_progression(def: CharacterProgressionCurve, path: String) -> bool:
	if not _validate_common(def.id, def.schema_version, CharacterProgressionCurve.CURRENT_SCHEMA, path):
		return false
	if def.max_level != def.xp_per_level.size() - 1:
		push_error("BalanceDatabase: CharacterProgressionCurve '%s' has max_level/xp_per_level mismatch." % def.id)
		return false
	if def.defense_per_vit <= 0.0:
		push_error("BalanceDatabase: CharacterProgressionCurve '%s' requires defense_per_vit > 0." % def.id)
		return false
	for stat in BASE_STATS.keys():
		if not def.base_stats.has(stat):
			push_error("BalanceDatabase: CharacterProgressionCurve '%s' missing base stat '%s'." % [def.id, stat])
			return false
	return true


func _validate_common(id: StringName, schema_version: int, current_schema: int, path: String) -> bool:
	if id == &"":
		push_error("BalanceDatabase: resource at %s has empty id." % path)
		return false
	if schema_version != current_schema:
		push_error(
			"BalanceDatabase: resource '%s' has schema_version=%d, expected=%d." %
			[id, schema_version, current_schema]
		)
		return false
	return true


func _index_resource(resource: Resource) -> void:
	if resource is EnemyDefinition:
		_index_unique(_enemies, (resource as EnemyDefinition).id, resource)
	elif resource is ItemDefinition:
		_index_unique(_items, (resource as ItemDefinition).id, resource)
	elif resource is SkillDefinition:
		_index_unique(_skills, (resource as SkillDefinition).id, resource)
	elif resource is WaveScalingCurve:
		_index_unique(_wave_curves, (resource as WaveScalingCurve).id, resource)
	elif resource is CharacterProgressionCurve:
		_index_unique(_progressions, (resource as CharacterProgressionCurve).id, resource)


func _index_unique(index: Dictionary, id: StringName, resource: Resource) -> void:
	if index.has(id):
		push_error("BalanceDatabase: duplicate id '%s' in manifest load." % id)
		return
	index[id] = resource
