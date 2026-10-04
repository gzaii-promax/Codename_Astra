class_name ActionController
extends Node
## The caller owns tick(delta). Skill behavior is supplied as a bound executor.

signal phase_changed(phase: int)
signal activated(action_id: StringName, definition: SkillDefinition, caster: Node)
signal completed(action_id: StringName, cancelled: bool)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

var phase: Phase = Phase.IDLE
var active_definition: SkillDefinition
var active_action_id: StringName = &""
var phase_remaining: float = 0.0

var _bindings: Dictionary = {}
var _cooldowns: Dictionary = {}
var _caster: Node
var _executor: Callable
var _action_generation: int = 0


func bind_action(
	action_id: StringName, definition: SkillDefinition, executor: Callable, level: int = 1
) -> void:
	var resolved := definition.resolve_level(level) if definition != null else null
	_bindings[action_id] = {"definition": resolved, "executor": executor}


func request_action(action_id: StringName, caster: Node) -> bool:
	if phase != Phase.IDLE or not _bindings.has(action_id) or not is_instance_valid(caster):
		return false
	if get_cooldown_remaining(action_id) > 0.0:
		return false
	var binding: Dictionary = _bindings[action_id]
	var definition := binding["definition"] as SkillDefinition
	var executor: Callable = binding["executor"]
	if definition == null or not definition.resolution_errors.is_empty() or not executor.is_valid():
		return false
	active_definition = definition
	_action_generation += 1
	var generation := _action_generation
	active_action_id = action_id
	_caster = caster
	_executor = executor
	_cooldowns[action_id] = definition.cooldown_seconds
	_enter_phase(Phase.WINDUP, definition.windup_seconds)
	_advance_zero_duration_phases(generation)
	return true


func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	for action_id in _cooldowns:
		_cooldowns[action_id] = maxf(0.0, float(_cooldowns[action_id]) - delta)
	if phase == Phase.IDLE:
		return
	if not is_instance_valid(_caster):
		_finish(true)
		return
	var remaining := delta
	var generation := _action_generation
	while phase != Phase.IDLE and generation == _action_generation:
		if phase_remaining > remaining:
			phase_remaining -= remaining
			break
		remaining -= phase_remaining
		_advance_phase()
		if remaining <= 0.0:
			_advance_zero_duration_phases(generation)
			break


func cancel(reason: StringName = &"player") -> bool:
	if phase == Phase.IDLE:
		return false
	var policy := _get_phase_policy()
	var permitted := false
	if policy != null:
		if reason == &"player":
			permitted = policy.can_cancel_player
		elif reason == &"hit":
			permitted = policy.can_interrupt_hit
	if permitted:
		_finish(true)
	return permitted


func reset_state() -> void:
	_cooldowns.clear()
	if phase != Phase.IDLE:
		_finish(true)
	else:
		_action_generation += 1
		active_definition = null
		active_action_id = &""
		phase_remaining = 0.0
		_caster = null
		_executor = Callable()


func finish_for_transition() -> void:
	# Room departure ends any phase regardless of cancel policy, retaining cooldowns.
	if phase != Phase.IDLE:
		_finish(true)


func get_movement_policy() -> Dictionary:
	var policy := _get_phase_policy()
	return policy.as_dictionary() if policy != null else PhasePolicy.new().as_dictionary()


func get_cooldown_remaining(action_id: StringName) -> float:
	return float(_cooldowns.get(action_id, 0.0))


func get_definition(action_id: StringName) -> SkillDefinition:
	if not _bindings.has(action_id):
		return null
	return _bindings[action_id]["definition"] as SkillDefinition


func _get_phase_policy() -> PhasePolicy:
	if active_definition == null:
		return null
	match phase:
		Phase.WINDUP:
			return active_definition.windup_policy
		Phase.ACTIVE:
			return active_definition.active_policy
		Phase.RECOVERY:
			return active_definition.recovery_policy
	return null


func _enter_phase(next_phase: Phase, duration: float) -> void:
	var generation := _action_generation
	phase = next_phase
	phase_remaining = duration
	phase_changed.emit(phase)
	if generation != _action_generation or phase != next_phase:
		return
	if next_phase == Phase.ACTIVE:
		var action_id := active_action_id
		var definition := active_definition
		var caster := _caster
		var executor := _executor
		activated.emit(action_id, definition, caster)
		if generation != _action_generation or phase != Phase.ACTIVE:
			return
		if not is_instance_valid(caster):
			_finish(true)
			return
		if executor.is_valid():
			executor.call(caster, definition)


func _advance_phase() -> void:
	match phase:
		Phase.WINDUP:
			_enter_phase(Phase.ACTIVE, active_definition.active_seconds)
		Phase.ACTIVE:
			_enter_phase(Phase.RECOVERY, active_definition.recovery_seconds)
		Phase.RECOVERY:
			_finish(false)


func _advance_zero_duration_phases(generation: int) -> void:
	while generation == _action_generation and phase != Phase.IDLE and phase_remaining <= 0.0:
		_advance_phase()


func _finish(cancelled: bool) -> void:
	var finished_id := active_action_id
	_action_generation += 1
	phase = Phase.IDLE
	phase_remaining = 0.0
	active_definition = null
	active_action_id = &""
	_caster = null
	_executor = Callable()
	phase_changed.emit(phase)
	completed.emit(finished_id, cancelled)
