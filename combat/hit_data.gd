class_name HitData
extends RefCounted
## Target eligibility and damage category are independent; source is current ownership.

enum TargetPolicy { OTHER_FACTIONS, OTHER_FACTIONS_AND_SELF, ALL_WITH_SAME_FACTION_REDUCTION, ALL }

var source: Node:
	set(actor):
		source = actor
		is_environment = false
		_source_actor_id = 0
		_source_faction = Combatant.Faction.FRIENDLY
		_capture_source()
var skill_id: StringName = &""
var damage: float = 0.0
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var knockback: float = 0.0
var damage_type: StringName = &"physical"
var target_policy: TargetPolicy = TargetPolicy.OTHER_FACTIONS
var self_reduction: float = 0.5
var same_faction_reduction: float = 0.5
var is_environment: bool = false

var _source_actor_id: int = 0
var _source_faction: Combatant.Faction = Combatant.Faction.FRIENDLY


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
	if is_instance_valid(source):
		var actor := source.get_parent() if source is Combatant else source
		if not is_instance_valid(actor):
			return source == target
		return actor == target or actor.is_ancestor_of(target)
	return _source_actor_id != 0 and target.get_instance_id() == _source_actor_id


func permits_target(target: Node, target_faction: Combatant.Faction) -> bool:
	var own_target := is_self(target)
	var same_faction := get_source_faction() == target_faction
	match target_policy:
		TargetPolicy.OTHER_FACTIONS:
			return not own_target and not same_faction
		TargetPolicy.OTHER_FACTIONS_AND_SELF:
			return own_target or not same_faction
		TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION, TargetPolicy.ALL:
			return true
	return false


func get_target_reduction(target: Node, target_faction: Combatant.Faction) -> float:
	if target_policy == TargetPolicy.OTHER_FACTIONS_AND_SELF and is_self(target):
		return self_reduction
	if (
		target_policy == TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION
		and (is_self(target) or get_source_faction() == target_faction)
	):
		return same_faction_reduction
	return 0.0


func is_valid() -> bool:
	return (
		is_finite(damage)
		and damage >= 0.0
		and is_finite(knockback)
		and knockback >= 0.0
		and origin.is_finite()
		and direction.is_finite()
		and not damage_type.is_empty()
		and target_policy in TargetPolicy.values()
		and is_finite(self_reduction)
		and self_reduction >= 0.0
		and self_reduction <= 1.0
		and is_finite(same_faction_reduction)
		and same_faction_reduction >= 0.0
		and same_faction_reduction <= 1.0
		and (not is_environment or target_policy == TargetPolicy.ALL)
	)


func _capture_source() -> void:
	if not is_instance_valid(source):
		return
	var actor := source.get_parent() if source is Combatant else source
	if is_instance_valid(actor):
		_source_actor_id = actor.get_instance_id()
	var combatant := source as Combatant
	if combatant == null:
		combatant = source.get_node_or_null("Combatant") as Combatant
	if combatant != null:
		_source_faction = combatant.faction
