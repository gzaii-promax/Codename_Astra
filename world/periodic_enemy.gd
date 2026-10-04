class_name PeriodicEnemy
extends Node2D
## A stationary training opponent: fixed attack cadence without targeting or movement AI.

const ENEMY_ATTACK: SkillDefinition = preload("res://skills/definitions/enemy_attack.tres")

@export_range(0.1, 20.0, 0.05) var attack_interval: float = 1.5
@export var attack_enabled: bool = true:
	set(value):
		attack_enabled = value
		if is_node_ready():
			_attack_remaining = _get_interval()
			if not attack_enabled:
				_stop_attack()
@export var facing_direction: float = -1.0

var _attack_remaining: float = 0.0
var _flash_remaining: float = 0.0
var _initial_facing: float = -1.0

@onready var actions: ActionController = $Actions
@onready var combatant: Combatant = $Combatant
@onready var receiver: DamageReceiver = $DamageReceiver


func _ready() -> void:
	_initial_facing = -1.0 if facing_direction < 0.0 else 1.0
	facing_direction = _initial_facing
	_attack_remaining = _get_interval()
	actions.bind_action(&"enemy_attack", ENEMY_ATTACK, SkillExecutors.melee)
	actions.phase_changed.connect(_on_phase_changed)
	combatant.state_changed.connect(_on_state_changed)
	combatant.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if combatant.life_state == Combatant.LifeState.ACTIVE and attack_enabled:
		actions.tick(delta)
		_attack_remaining -= delta
		if _attack_remaining <= 0.0:
			request_attack()
			while _attack_remaining <= 0.0:
				_attack_remaining += _get_interval()
	queue_redraw()


func request_attack() -> bool:
	if not attack_enabled or combatant.life_state != Combatant.LifeState.ACTIVE:
		return false
	return actions.request_action(&"enemy_attack", self)


func get_combatant() -> Combatant:
	return combatant


func get_receiver() -> DamageReceiver:
	return receiver


func get_action_controller() -> ActionController:
	return actions


func get_attack_origin() -> Vector2:
	return global_position + Vector2(facing_direction * 15.0, -28.0)


func reset_state(spawn_position: Vector2) -> void:
	_stop_attack()
	global_position = spawn_position
	facing_direction = _initial_facing
	_attack_remaining = _get_interval()
	_flash_remaining = 0.0
	combatant.reset_state()
	queue_redraw()


func _get_interval() -> float:
	return maxf(0.1, attack_interval) if is_finite(attack_interval) else 1.5


func _stop_attack() -> void:
	actions.reset_state()
	_cancel_source_effects()


func _cancel_source_effects() -> void:
	AttackEffectLifecycle.cancel_source(self)


func _on_state_changed(state: int) -> void:
	_attack_remaining = _get_interval()
	if state != Combatant.LifeState.ACTIVE:
		_stop_attack()
	queue_redraw()


func _on_damaged(_hit: HitData, amount: float) -> void:
	if amount > 0.0 and actions.cancel(&"hit"):
		_cancel_source_effects()
	_flash_remaining = 0.15
	queue_redraw()


func _on_phase_changed(_phase: int) -> void:
	queue_redraw()


func _draw() -> void:
	if combatant == null:
		return
	if combatant.life_state != Combatant.LifeState.ACTIVE:
		var fallen_color := (
			Color("d3a257")
			if combatant.life_state == Combatant.LifeState.DOWNED
			else Color("6d5360")
		)
		draw_rect(Rect2(-26, -13, 38, 12), fallen_color)
		draw_rect(Rect2(12, -16, 15, 14), fallen_color.lightened(0.15))
		draw_rect(Rect2(-28, -3, 58, 3), Color("392f38"))
		return
	var body_color := Color("ffd9ba") if _flash_remaining > 0.0 else Color("bf5f62")
	draw_rect(Rect2(-12, -42, 24, 26), body_color)
	draw_rect(Rect2(-10, -64, 20, 20), body_color.lightened(0.15))
	draw_rect(Rect2(-13, -66, 26, 5), Color("773d4d"))
	draw_rect(Rect2(-11, -16, 8, 16), Color("5f4454"))
	draw_rect(Rect2(3, -16, 8, 16), Color("5f4454"))
	draw_rect(Rect2(-15, -3, 14, 3), Color("302b36"))
	draw_rect(Rect2(1, -3, 14, 3), Color("302b36"))
	draw_rect(Rect2(facing_direction * 4.0 - 2.0, -56, 4, 3), Color("282935"))
	var arm_x := facing_direction * 16.0
	draw_rect(Rect2(arm_x - 4.0, -39, 8, 17), body_color)
	var weapon_color := (
		Color("f7c56f") if actions.phase == ActionController.Phase.WINDUP else Color("b9b7c6")
	)
	draw_rect(Rect2(arm_x + facing_direction * 6.0 - 2.0, -49, 4, 30), weapon_color)
