class_name PhasePolicy
extends Resource
## Movement and cancellation rules for one action phase.

@export_range(0.0, 1.0, 0.05) var control_scale: float = 1.0
@export_range(0.0, 1.0, 0.05) var inertia_scale: float = 1.0
@export var skill_velocity: Vector2 = Vector2.ZERO
@export var can_jump: bool = true
@export var can_cancel_player: bool = true
@export var can_interrupt_hit: bool = true


func as_dictionary() -> Dictionary:
	return {
		"control_scale": control_scale,
		"inertia_scale": inertia_scale,
		"skill_velocity": skill_velocity,
		"can_jump": can_jump,
		"can_cancel_player": can_cancel_player,
		"can_interrupt_hit": can_interrupt_hit,
	}


func validate() -> Array[String]:
	var errors: Array[String] = []
	if not is_finite(control_scale) or control_scale < 0.0 or control_scale > 1.0:
		errors.append("control_scale must be finite and between 0 and 1")
	if not is_finite(inertia_scale) or inertia_scale < 0.0 or inertia_scale > 1.0:
		errors.append("inertia_scale must be finite and between 0 and 1")
	if not skill_velocity.is_finite():
		errors.append("skill_velocity must be finite")
	return errors
