@tool
class_name DamageReceiver
extends Area2D
## Eligibility comes first; accepted hits spend the same heart amount for every faction.

signal hit_received(hit: HitData)
signal hit_resolved(hit: HitData, amount: float)

@export var enabled: bool = true
@export var combatant_path: NodePath = ^"../Combatant":
	set(value):
		combatant_path = value
		_refresh_configuration_warnings()
## Explicit contact-only targets; ordinary actors must bind their health component.
@export var healthless_target: bool = false:
	set(value):
		healthless_target = value
		_refresh_configuration_warnings()

var last_damage: float = 0.0
var last_error: String = ""


func _init() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive_hit(hit: HitData) -> bool:
	last_damage = 0.0
	last_error = ""
	if not enabled or hit == null:
		return false
	var errors := validate()
	errors.append_array(hit.validate())
	if not errors.is_empty():
		last_error = "; ".join(errors)
		return false
	var combatant := get_combatant()
	var target_faction := Combatant.Faction.NEUTRAL
	if combatant != null:
		target_faction = combatant.faction
	if not hit.permits_target(self, target_faction):
		return false
	if combatant != null and not combatant.can_receive_damage():
		return false
	var resolved_damage := hit.damage
	last_damage = resolved_damage
	if combatant != null and not combatant.apply_damage(hit, resolved_damage):
		last_damage = 0.0
		return false
	# A rejected hit in a synchronous health callback must not erase this result.
	last_damage = resolved_damage
	hit_received.emit(hit)
	last_damage = resolved_damage
	hit_resolved.emit(hit, resolved_damage)
	# Signals may synchronously accept or reject another hit on this receiver.
	last_damage = resolved_damage
	last_error = ""
	return true


func get_combatant() -> Combatant:
	if healthless_target or combatant_path.is_empty():
		return null
	return get_node_or_null(combatant_path) as Combatant


func validate() -> Array[String]:
	var errors: Array[String] = []
	if not healthless_target and get_combatant() == null:
		errors.append("combatant_path '%s' must point to a Combatant" % combatant_path)
	return errors


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(validate())


func _refresh_configuration_warnings() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
