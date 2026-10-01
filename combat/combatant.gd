class_name Combatant
extends Node
## Reusable life state; invulnerability blocks damage but never blocks story death.

signal health_changed(current: float, maximum: float)
signal state_changed(state: LifeState)
signal faction_changed(new_faction: Faction)
signal damaged(hit: HitData, amount: float)

enum Faction { FRIENDLY, ENEMY, NEUTRAL }
enum LifeState { ACTIVE, DOWNED, DEAD }
enum ZeroHealthBehavior { DEATH, KNOCKDOWN }

@export var faction: Faction = Faction.NEUTRAL:
	set(value):
		if faction == value:
			return
		faction = value
		faction_changed.emit(faction)
@export_range(1.0, 100000.0, 1.0) var max_health: float = 100.0
@export var invulnerable: bool = false
@export_range(0.0, 60.0, 0.05, "or_greater")
var hit_protection_seconds: float = CombatConfig.DEFAULT_HIT_PROTECTION_SECONDS:
	set(value):
		hit_protection_seconds = value
		if value == 0.0:
			_clear_hit_protection()
@export var zero_health_behavior: ZeroHealthBehavior = ZeroHealthBehavior.DEATH
@export_range(0.0, 1.0, 0.01) var general_reduction: float = 0.0
@export var resistances: Dictionary = {}

var current_health: float = 100.0
var life_state: LifeState = LifeState.ACTIVE

var _recovery_remaining: float = -1.0
var _recovery_health: float = 0.0
var _hit_protection_remaining: float = 0.0


func _ready() -> void:
	reset_state()


func _process(delta: float) -> void:
	if life_state != LifeState.DOWNED:
		cancel_recovery()
		return
	_recovery_remaining -= delta
	if _recovery_remaining <= 0.0:
		recover(_recovery_health)


func _physics_process(delta: float) -> void:
	_hit_protection_remaining = maxf(0.0, _hit_protection_remaining - delta)
	if is_zero_approx(_hit_protection_remaining):
		_clear_hit_protection()


func validate() -> Array[String]:
	var errors: Array[String] = []
	if not is_finite(max_health) or max_health <= 0.0:
		errors.append("max_health must be finite and positive")
	if not is_finite(hit_protection_seconds) or hit_protection_seconds < 0.0:
		errors.append("hit_protection_seconds must be finite and nonnegative")
	if faction not in Faction.values():
		errors.append("faction must be a declared Faction")
	if zero_health_behavior not in ZeroHealthBehavior.values():
		errors.append("zero_health_behavior must be a declared ZeroHealthBehavior")
	if not _valid_reduction(general_reduction):
		errors.append("general_reduction must be finite and within 0..1")
	for category in resistances:
		var value: Variant = resistances[category]
		if (
			(typeof(category) != TYPE_STRING and typeof(category) != TYPE_STRING_NAME)
			or str(category).is_empty()
			or (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT)
		):
			errors.append("resistance entries require a damage type and numeric reduction")
		elif not _valid_reduction(float(value)):
			errors.append("resistance %s must be finite and within 0..1" % category)
	return errors


func reset_state() -> void:
	cancel_recovery()
	_clear_hit_protection()
	if not validate().is_empty():
		return
	current_health = max_health
	life_state = LifeState.ACTIVE
	health_changed.emit(current_health, max_health)
	state_changed.emit(life_state)


func can_receive_damage() -> bool:
	return (
		life_state == LifeState.ACTIVE
		and not invulnerable
		and current_health > 0.0
		and (hit_protection_seconds == 0.0 or _hit_protection_remaining == 0.0)
		and validate().is_empty()
	)


func get_hit_protection_remaining() -> float:
	return _hit_protection_remaining


func get_type_reduction(damage_type: StringName) -> float:
	return float(resistances.get(damage_type, 0.0))


func apply_damage(hit: HitData, amount: float) -> bool:
	if not can_receive_damage() or hit == null or not is_finite(amount) or amount < 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	var previous_state := life_state
	if current_health == 0.0:
		life_state = (
			LifeState.DEAD if zero_health_behavior == ZeroHealthBehavior.DEATH else LifeState.DOWNED
		)
		cancel_recovery()
		_clear_hit_protection()
	elif amount > 0.0 and hit_protection_seconds > 0.0:
		# Signals are synchronous: protect before a callback can apply another hit.
		_hit_protection_remaining = hit_protection_seconds
		set_physics_process(true)
	health_changed.emit(current_health, max_health)
	if previous_state != life_state:
		state_changed.emit(life_state)
	damaged.emit(hit, amount)
	return true


func force_death() -> void:
	cancel_recovery()
	_clear_hit_protection()
	if life_state == LifeState.DEAD:
		return
	current_health = 0.0
	life_state = LifeState.DEAD
	health_changed.emit(current_health, max_health)
	state_changed.emit(life_state)


func recover(positive_health: float) -> bool:
	if (
		life_state != LifeState.DOWNED
		or not is_finite(positive_health)
		or positive_health <= 0.0
		or not validate().is_empty()
	):
		return false
	cancel_recovery()
	_clear_hit_protection()
	current_health = minf(positive_health, max_health)
	life_state = LifeState.ACTIVE
	health_changed.emit(current_health, max_health)
	state_changed.emit(life_state)
	return true


func assist_recover(helper: Combatant, positive_health: float) -> bool:
	if (
		not is_instance_valid(helper)
		or helper == self
		or helper.life_state != LifeState.ACTIVE
		or helper.faction != faction
	):
		return false
	return recover(positive_health)


func schedule_recovery(delay: float, positive_health: float) -> bool:
	if (
		life_state != LifeState.DOWNED
		or not is_finite(delay)
		or delay < 0.0
		or not is_finite(positive_health)
		or positive_health <= 0.0
		or not validate().is_empty()
	):
		return false
	if delay == 0.0:
		return recover(positive_health)
	_recovery_remaining = delay
	_recovery_health = positive_health
	set_process(true)
	return true


func cancel_recovery() -> void:
	_recovery_remaining = -1.0
	_recovery_health = 0.0
	set_process(false)


func _clear_hit_protection() -> void:
	_hit_protection_remaining = 0.0
	set_physics_process(false)


func _valid_reduction(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= 1.0
