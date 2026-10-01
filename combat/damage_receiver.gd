class_name DamageReceiver
extends Area2D
## Eligibility comes first; percentage reductions share one additive calculation.

signal hit_received(hit: HitData)

@export var enabled: bool = true
@export var combatant_path: NodePath = ^"../Combatant"

var last_damage: float = 0.0


func _init() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive_hit(hit: HitData) -> bool:
	last_damage = 0.0
	if not enabled or hit == null or not hit.is_valid():
		return false
	var combatant := get_combatant()
	var target_faction := Combatant.Faction.NEUTRAL
	if combatant != null:
		target_faction = combatant.faction
	if not hit.permits_target(self, target_faction):
		return false
	if combatant != null and not combatant.can_receive_damage():
		return false
	var reduction := hit.get_target_reduction(self, target_faction)
	if combatant != null:
		reduction += combatant.general_reduction + combatant.get_type_reduction(hit.damage_type)
	var resolved_damage := hit.damage * (1.0 - clampf(reduction, 0.0, 1.0))
	last_damage = resolved_damage
	if combatant != null and not combatant.apply_damage(hit, resolved_damage):
		last_damage = 0.0
		return false
	# A rejected hit in a synchronous health callback must not erase this result.
	last_damage = resolved_damage
	hit_received.emit(hit)
	return true


func get_combatant() -> Combatant:
	return get_node_or_null(combatant_path) as Combatant
