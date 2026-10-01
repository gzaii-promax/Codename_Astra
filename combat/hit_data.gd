class_name HitData
extends RefCounted
## A single hit payload. Receivers never need to know the attacking skill's implementation.

var source: Node
var skill_id: StringName = &""
var damage: float = 0.0
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var knockback: float = 0.0
var damage_type: StringName = &"physical"


func is_valid() -> bool:
	return (
		is_finite(damage)
		and damage >= 0.0
		and is_finite(knockback)
		and knockback >= 0.0
		and origin.is_finite()
		and direction.is_finite()
	)
