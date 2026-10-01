class_name Combatant
extends Node
## Heart containers and life state; internal storage uses integer half-hearts.

signal health_changed(current: float, maximum: float)
signal state_changed(state: LifeState)
signal faction_changed(new_faction: Faction)
signal damaged(hit: HitData, amount: float)

enum Faction { FRIENDLY, ENEMY, NEUTRAL }
enum LifeState { ACTIVE, DOWNED, DEAD }
enum ZeroHealthBehavior { DEATH, KNOCKDOWN, REFILL }

@export var faction: Faction = Faction.NEUTRAL:
	set(value):
		if faction == value:
			return
		faction = value
		faction_changed.emit(faction)
@export_range(1.0, 100000.0, 1.0, "or_greater") var max_health: float = 3.0
@export var invulnerable: bool = false
@export_range(0.0, 60.0, 0.05, "or_greater")
var hit_protection_seconds: float = CombatConfig.DEFAULT_HIT_PROTECTION_SECONDS:
	set(value):
		hit_protection_seconds = value
		if value == 0.0:
			_clear_hit_protection()
@export var zero_health_behavior: ZeroHealthBehavior = ZeroHealthBehavior.DEATH

var current_health: float:
	get:
		return float(_current_half_hearts) / 2.0
var life_state: LifeState = LifeState.ACTIVE

var _current_half_hearts: int = 6
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
	if not is_finite(max_health) or max_health <= 0.0 or max_health != floorf(max_health):
		errors.append("max_health must be a finite positive integer of heart containers")
	elif max_health > 4503599627370495.0:
		errors.append("max_health exceeds exact half-heart storage range")
	if not is_finite(hit_protection_seconds) or hit_protection_seconds < 0.0:
		errors.append("hit_protection_seconds must be finite and nonnegative")
	if faction not in Faction.values():
		errors.append("faction must be a declared Faction")
	if zero_health_behavior not in ZeroHealthBehavior.values():
		errors.append("zero_health_behavior must be a declared ZeroHealthBehavior")
	return errors


func reset_state() -> void:
	cancel_recovery()
	_clear_hit_protection()
	if not validate().is_empty():
		return
	_current_half_hearts = int(max_health * 2.0)
	life_state = LifeState.ACTIVE
	health_changed.emit(current_health, max_health)
	state_changed.emit(life_state)


func can_receive_damage() -> bool:
	return (
		life_state == LifeState.ACTIVE
		and not invulnerable
		and _current_half_hearts > 0
		and (hit_protection_seconds == 0.0 or _hit_protection_remaining == 0.0)
		and validate().is_empty()
	)


func get_hit_protection_remaining() -> float:
	return _hit_protection_remaining


func apply_damage(hit: HitData, amount: float) -> bool:
	if (
		not can_receive_damage()
		or hit == null
		or not hit.is_valid()
		or not HitData.is_valid_damage(amount)
	):
		return false
	# Clamp before converting so arbitrary overkill cannot overflow integer storage.
	var spent_half_hearts := int(minf(amount, current_health) * 2.0)
	_current_half_hearts -= spent_half_hearts
	var previous_state := life_state
	if _current_half_hearts == 0:
		cancel_recovery()
		_clear_hit_protection()
		match zero_health_behavior:
			ZeroHealthBehavior.DEATH:
				life_state = LifeState.DEAD
			ZeroHealthBehavior.KNOCKDOWN:
				life_state = LifeState.DOWNED
			ZeroHealthBehavior.REFILL:
				_current_half_hearts = int(max_health * 2.0)
	if life_state == LifeState.ACTIVE and amount > 0.0 and hit_protection_seconds > 0.0:
		# Install protection before signals, including a refill caused by this hit.
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
	_current_half_hearts = 0
	life_state = LifeState.DEAD
	health_changed.emit(current_health, max_health)
	state_changed.emit(life_state)


func recover(positive_health: float) -> bool:
	if (
		life_state != LifeState.DOWNED
		or not HitData.is_valid_damage(positive_health)
		or positive_health <= 0.0
		or not validate().is_empty()
	):
		return false
	cancel_recovery()
	_clear_hit_protection()
	_current_half_hearts = int(minf(positive_health, max_health) * 2.0)
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
		or not HitData.is_valid_damage(positive_health)
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
