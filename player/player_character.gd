class_name PlayerCharacter
extends CharacterBody2D
## Owns locomotion; action policies supply constraints without skill-specific branches.

const BASIC_ATTACK: SkillDefinition = preload("res://skills/definitions/basic_attack.tres")
const FIREBALL: SkillDefinition = preload("res://skills/definitions/fireball.tres")

@export var move_speed: float = 1.5 * GameUnits.PIXELS_PER_UNIT
@export var acceleration: float = 12.0 * GameUnits.PIXELS_PER_UNIT
@export var deceleration: float = 16.0 * GameUnits.PIXELS_PER_UNIT
@export var gravity: float = 25.0 * GameUnits.PIXELS_PER_UNIT
@export var min_jump_height: float = 1.0 * GameUnits.PIXELS_PER_UNIT
@export var max_jump_height: float = 2.5 * GameUnits.PIXELS_PER_UNIT
@export var max_fall_speed: float = 25.0 * GameUnits.PIXELS_PER_UNIT
@export var coyote_seconds: float = 0.1
@export var jump_buffer_seconds: float = 0.1

var facing_direction: float = 1.0
var fireball_level: int = 1

var _motion_velocity: Vector2 = Vector2.ZERO
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _external_control: bool = false
var _external_axis: float = 0.0
var _external_jump: bool = false
var _external_jump_held: bool = false
var _variable_jump_active: bool = false
var _jump_cut_applied: bool = false
var _jump_release_pending: bool = false
var _jump_origin_y: float = 0.0

@onready var actions: ActionController = $Actions
@onready var visual: PlayerVisual = $Visual
@onready var combatant: Combatant = $Combatant


func _ready() -> void:
	InputSetup.ensure_actions()
	actions.bind_action(&"basic_attack", BASIC_ATTACK, SkillExecutors.melee)
	set_fireball_level(1)
	actions.phase_changed.connect(_on_phase_changed)
	combatant.state_changed.connect(_on_life_state_changed)
	combatant.damaged.connect(_on_damaged)


func _input(event: InputEvent) -> void:
	if not _external_control and _variable_jump_active and event.is_action_released("jump"):
		_jump_release_pending = true


func _physics_process(delta: float) -> void:
	if combatant.life_state != Combatant.LifeState.ACTIVE:
		_external_jump = false
		_external_jump_held = false
		_jump_release_pending = false
		_motion_velocity.x = 0.0
		_motion_velocity.y = minf(_motion_velocity.y + gravity * delta, max_fall_speed)
		velocity = _motion_velocity
		move_and_slide()
		if is_on_floor():
			_motion_velocity.y = 0.0
		visual.update_state(self, delta)
		return
	var axis := _external_axis if _external_control else Input.get_axis("move_left", "move_right")
	var wants_jump := _external_jump if _external_control else Input.is_action_just_pressed("jump")
	var jump_held := _external_jump_held if _external_control else Input.is_action_pressed("jump")
	var jump_released := _jump_release_pending
	_jump_release_pending = false
	_external_jump = false
	if not _external_control:
		if Input.is_action_just_pressed("basic_attack"):
			request_attack()
		if Input.is_action_just_pressed("fireball"):
			request_fireball()
	if (
		not is_zero_approx(axis)
		and actions.phase in [ActionController.Phase.IDLE, ActionController.Phase.WINDUP]
	):
		facing_direction = signf(axis)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	if wants_jump:
		_jump_buffer_remaining = jump_buffer_seconds
	_coyote_remaining = coyote_seconds if is_on_floor() else maxf(0.0, _coyote_remaining - delta)
	actions.tick(delta)
	var policy := actions.get_movement_policy()
	var target_speed := axis * move_speed * float(policy["control_scale"])
	var rate := acceleration if not is_zero_approx(axis) else deceleration
	_motion_velocity.x = move_toward(_motion_velocity.x, target_speed, rate * delta)
	if is_on_floor() and _motion_velocity.y > 0.0:
		_motion_velocity.y = 0.0
	_motion_velocity.y = minf(_motion_velocity.y + gravity * delta, max_fall_speed)
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0 and bool(policy["can_jump"]):
		_motion_velocity.y = -_jump_speed_for_height(max_jump_height, delta)
		_variable_jump_active = true
		_jump_cut_applied = false
		_jump_origin_y = global_position.y
		jump_released = false
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
	if _variable_jump_active and not _jump_cut_applied and (jump_released or not jump_held):
		# Release can shorten this ascent once; pressing again cannot restore it.
		var height_already_risen := _jump_origin_y - global_position.y
		var remaining_short_height := maxf(0.0, min_jump_height - height_already_risen)
		_motion_velocity.y = maxf(
			_motion_velocity.y, -_jump_speed_for_height(remaining_short_height, delta)
		)
		_jump_cut_applied = true
	var skill_velocity: Vector2 = policy["skill_velocity"]
	skill_velocity.x *= facing_direction
	velocity = _motion_velocity + skill_velocity
	move_and_slide()
	if is_on_wall():
		_motion_velocity.x = 0.0
	if is_on_floor() and velocity.y >= 0.0:
		_motion_velocity.y = 0.0
		_variable_jump_active = false
	if is_on_ceiling() and _motion_velocity.y < 0.0:
		_motion_velocity.y = 0.0
	if _motion_velocity.y >= 0.0:
		_variable_jump_active = false
	visual.update_state(self, delta)


func _jump_speed_for_height(height: float, delta: float) -> float:
	# Account for the launch frame moving before the next gravity increment.
	var half_gravity_step := gravity * delta * 0.5
	return sqrt(2.0 * gravity * height + half_gravity_step * half_gravity_step) - half_gravity_step


func request_attack() -> bool:
	return (
		combatant.life_state == Combatant.LifeState.ACTIVE
		and actions.request_action(&"basic_attack", self)
	)


func request_fireball() -> bool:
	return (
		combatant.life_state == Combatant.LifeState.ACTIVE
		and actions.request_action(&"fireball", self)
	)


func get_combatant() -> Combatant:
	return combatant


func set_fireball_level(level: int) -> void:
	fireball_level = clampi(level, 1, 2)
	actions.bind_action(&"fireball", FIREBALL, SkillExecutors.fireball, fireball_level)


func get_action_controller() -> ActionController:
	return actions


func get_attack_origin() -> Vector2:
	return (
		global_position
		+ Vector2(facing_direction * 0.5 * GameUnits.PIXELS_PER_UNIT, -GameUnits.PIXELS_PER_UNIT)
	)


func set_control_input(
	horizontal: float, jump_requested: bool = false, jump_held: bool = false
) -> void:
	if _variable_jump_active and not jump_held:
		_jump_release_pending = true
	_external_control = true
	_external_axis = clampf(horizontal, -1.0, 1.0)
	_external_jump = _external_jump or jump_requested
	_external_jump_held = jump_held


func clear_control_override() -> void:
	_external_control = false
	_external_axis = 0.0
	_external_jump = false
	_external_jump_held = false
	_jump_release_pending = false


func reset_state(spawn_position: Vector2) -> void:
	combatant.reset_state()
	actions.reset_state()
	global_position = spawn_position
	velocity = Vector2.ZERO
	_motion_velocity = Vector2.ZERO
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_external_jump = false
	_external_jump_held = false
	_variable_jump_active = false
	_jump_cut_applied = false
	_jump_release_pending = false
	_jump_origin_y = 0.0
	facing_direction = 1.0


func _on_damaged(_hit: HitData, amount: float) -> void:
	if amount > 0.0 and actions.cancel(&"hit"):
		_clear_melee_windows()


func _on_life_state_changed(state: int) -> void:
	visual.modulate = Color.WHITE if state == Combatant.LifeState.ACTIVE else Color("85858f")
	if state == Combatant.LifeState.ACTIVE:
		return
	actions.reset_state()
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_external_jump = false
	_external_jump_held = false
	_variable_jump_active = false
	_jump_cut_applied = false
	_jump_release_pending = false
	_clear_melee_windows()


func _clear_melee_windows() -> void:
	# An already opened melee window must not keep hitting after death/knockdown.
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	for effect in spawn_parent.get_children():
		if effect is MeleeStrike and effect.hit != null and effect.hit.source == self:
			effect.set_physics_process(false)
			effect.queue_free()


func _on_phase_changed(_phase: int) -> void:
	var policy := actions.get_movement_policy()
	_motion_velocity.x *= float(policy["inertia_scale"])
