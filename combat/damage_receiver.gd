class_name DamageReceiver
extends Area2D
## Attach a CollisionShape2D; its owning actor handles the accepted hit signal.

signal hit_received(hit: HitData)

@export var enabled: bool = true


func _init() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive_hit(hit: HitData) -> bool:
	if not enabled or hit == null or not hit.is_valid():
		return false
	if is_instance_valid(hit.source) and (hit.source == self or hit.source.is_ancestor_of(self)):
		return false
	hit_received.emit(hit)
	return true
