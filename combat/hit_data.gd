class_name HitData
extends RefCounted
## Target eligibility and damage category are independent; source is current ownership.

enum TargetPolicy { OTHER_FACTIONS, OTHER_FACTIONS_AND_SELF, ALL }

var source: Node:
	set(actor):
		source = actor
		is_environment = false
		_source_actor_id = 0
		_source_combatant_id = 0
		_source_valid = false
		_source_faction = Combatant.Faction.NEUTRAL
		_capture_source()
var skill_id: StringName = &""
var damage: float = 0.0
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var knockback: float = 0.0
var damage_type: StringName = &"physical"
var target_policy: TargetPolicy = TargetPolicy.OTHER_FACTIONS
var is_environment: bool = false

var _source_actor_id: int = 0
var _source_combatant_id: int = 0
var _source_valid: bool = false
var _source_faction: Combatant.Faction = Combatant.Faction.NEUTRAL


func set_source(actor: Node) -> void:
	source = actor


func set_environment() -> void:
	source = null
	is_environment = true
	target_policy = TargetPolicy.ALL


func get_source_faction() -> Combatant.Faction:
	_capture_source()
	return _source_faction


func is_self(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	_capture_source()
	var target_combatant := _resolve_combatant(target)
	if is_instance_valid(target_combatant) and _source_combatant_id != 0:
		return target_combatant.get_instance_id() == _source_combatant_id
	if is_instance_valid(source):
		return source == target or source.is_ancestor_of(target)
	return _source_actor_id != 0 and target.get_instance_id() == _source_actor_id


func permits_target(target: Node, target_faction: Combatant.Faction) -> bool:
	var own_target := is_self(target)
	var same_faction := get_source_faction() == target_faction
	match target_policy:
		TargetPolicy.OTHER_FACTIONS:
			return not own_target and not same_faction
		TargetPolicy.OTHER_FACTIONS_AND_SELF:
			return own_target or not same_faction
		TargetPolicy.ALL:
			return true
	return false


func is_valid() -> bool:
	return validate().is_empty()


func validate() -> Array[String]:
	_capture_source()
	var errors: Array[String] = []
	if not is_valid_damage(damage):
		errors.append("damage must be a finite nonnegative multiple of 0.5 hearts")
	if not is_finite(knockback) or knockback < 0.0:
		errors.append("knockback must be finite and nonnegative")
	if not origin.is_finite() or not direction.is_finite():
		errors.append("origin and direction must be finite vectors")
	if damage_type.is_empty():
		errors.append("damage_type must not be empty")
	if target_policy not in TargetPolicy.values():
		errors.append("target_policy must be a declared TargetPolicy")
	if is_environment:
		if is_instance_valid(source) or target_policy != TargetPolicy.ALL:
			errors.append("environment damage must have no source and use ALL")
	elif not _source_valid:
		errors.append(
			"source must be a Combatant or provide get_combatant(); use set_environment()"
		)
	return errors


static func is_valid_damage(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0 and fmod(amount, 0.5) == 0.0


func _capture_source() -> void:
	if not is_instance_valid(source):
		return
	_source_valid = false
	var combatant := _resolve_combatant(source)
	if is_instance_valid(combatant) and combatant.faction in Combatant.Faction.values():
		_source_actor_id = source.get_instance_id()
		_source_combatant_id = combatant.get_instance_id()
		_source_faction = combatant.faction
		_source_valid = true


func _resolve_combatant(node: Node) -> Combatant:
	if node is Combatant:
		return node as Combatant
	if node.has_method("get_combatant"):
		return node.call("get_combatant") as Combatant
	return null
