extends GutTest

const FIREBALL_BASE: SkillDefinition = preload("res://skills/definitions/fireball.tres")

var _executions: Array[SkillDefinition] = []


func before_each() -> void:
	_executions.clear()


func test_fireball_level_changes_timing_without_mutating_base() -> void:
	var first := FIREBALL_BASE.resolve_level(1)
	var second := FIREBALL_BASE.resolve_level(2)
	assert_almost_eq(first.windup_seconds, 0.5, 0.0001)
	assert_almost_eq(second.windup_seconds, 0.2, 0.0001)
	assert_eq(second.damage, first.damage, "Level changes timing while damage stays constant")
	assert_almost_eq(FIREBALL_BASE.windup_seconds, 0.5, 0.0001)
	second.windup_policy.control_scale = 0.0
	assert_ne(second.windup_policy.control_scale, first.windup_policy.control_scale)
	assert_true(second.resolution_errors.is_empty())
	assert_eq(second.get_resolved_attributes()["level"], 2)


func test_invalid_skill_and_override_are_rejected() -> void:
	var definition := _definition()
	definition.windup_seconds = -0.1
	assert_false(definition.validate().is_empty())
	var controller := _controller(definition)
	assert_false(controller.request_action(&"test", _caster()))
	definition.windup_seconds = 0.2
	var invalid := SkillLevelOverride.new()
	invalid.level = 2
	invalid.values = {"unknown_attribute": 7}
	definition.level_overrides = [invalid]
	assert_false(definition.resolve_level(2).resolution_errors.is_empty())
	assert_false(definition.resolve_level(0).resolution_errors.is_empty())


func test_duplicate_upgrade_levels_are_rejected() -> void:
	var definition := _definition()
	var first := SkillLevelOverride.new()
	var second := SkillLevelOverride.new()
	first.level = 2
	second.level = 2
	first.values = {"damage": 20.0}
	second.values = {"damage": 30.0}
	definition.level_overrides = [first, second]
	assert_false(definition.resolve_level(2).resolution_errors.is_empty())


func test_windup_executes_once_then_active_and_recovery_complete() -> void:
	var controller := _controller(_definition())
	assert_true(controller.request_action(&"test", _caster()))
	controller.tick(0.199)
	assert_eq(_executions.size(), 0, "No early activation")
	assert_eq(controller.phase, ActionController.Phase.WINDUP)
	controller.tick(0.002)
	assert_eq(_executions.size(), 1)
	assert_eq(controller.phase, ActionController.Phase.ACTIVE)
	controller.tick(0.11)
	assert_eq(controller.phase, ActionController.Phase.RECOVERY)
	controller.tick(0.31)
	assert_eq(controller.phase, ActionController.Phase.IDLE)
	assert_eq(_executions.size(), 1, "Ticking phases never executes the action twice")


func test_large_tick_carries_time_through_all_phases() -> void:
	var controller := _controller(_definition())
	assert_true(controller.request_action(&"test", _caster()))
	controller.tick(0.61)
	assert_eq(_executions.size(), 2, "CI_FAILURE_PROBE")
	assert_eq(controller.phase, ActionController.Phase.IDLE)
	assert_almost_eq(controller.get_cooldown_remaining(&"test"), 0.19, 0.0001)


func test_zero_duration_phases_execute_once_without_stalling() -> void:
	var definition := _definition()
	definition.windup_seconds = 0.0
	definition.active_seconds = 0.0
	definition.recovery_seconds = 0.0
	var controller := _controller(definition)
	assert_true(controller.request_action(&"test", _caster()))
	assert_eq(_executions.size(), 1)
	assert_eq(controller.phase, ActionController.Phase.IDLE)
	controller.tick(0.0)
	assert_eq(_executions.size(), 1)


func test_active_action_and_cooldown_reject_repeated_requests() -> void:
	var controller := _controller(_definition())
	var caster := _caster()
	assert_true(controller.request_action(&"test", caster))
	assert_false(controller.request_action(&"test", caster))
	controller.tick(0.61)
	assert_false(controller.request_action(&"test", caster), "Action ended but cooldown remains")
	controller.tick(0.2)
	assert_true(controller.request_action(&"test", caster))
	assert_false(controller.request_action(&"missing", caster))


func test_player_cancel_and_hit_interrupt_have_separate_rules() -> void:
	var definition := _definition()
	definition.windup_policy.can_cancel_player = false
	definition.windup_policy.can_interrupt_hit = true
	var controller := _controller(definition)
	assert_true(controller.request_action(&"test", _caster()))
	assert_false(controller.cancel(&"player"))
	assert_eq(controller.phase, ActionController.Phase.WINDUP)
	assert_true(controller.cancel(&"hit"))
	assert_eq(controller.phase, ActionController.Phase.IDLE)
	assert_eq(_executions.size(), 0)
	assert_gt(controller.get_cooldown_remaining(&"test"), 0.0, "Cancel does not bypass cooldown")


func test_recovery_policy_can_allow_cancel_after_locked_windup() -> void:
	var definition := _definition()
	definition.windup_policy.can_cancel_player = false
	definition.recovery_policy.can_cancel_player = true
	definition.windup_policy.control_scale = 0.2
	definition.recovery_policy.control_scale = 0.8
	var controller := _controller(definition)
	assert_true(controller.request_action(&"test", _caster()))
	assert_almost_eq(controller.get_movement_policy()["control_scale"], 0.2, 0.0001)
	controller.tick(0.31)
	assert_eq(controller.phase, ActionController.Phase.RECOVERY)
	assert_almost_eq(controller.get_movement_policy()["control_scale"], 0.8, 0.0001)
	assert_true(controller.cancel(&"player"))


func test_new_skill_uses_same_controller_and_independent_binding() -> void:
	var controller := _controller(_definition())
	var alternative := _definition()
	alternative.id = &"alternative"
	alternative.windup_seconds = 0.0
	alternative.damage = 90.0
	controller.bind_action(&"second", alternative, _capture)
	assert_true(controller.request_action(&"second", _caster()))
	assert_eq(_executions.size(), 1)
	assert_eq(_executions[0].damage, 90.0)
	assert_eq(controller.get_definition(&"test").damage, 10.0)
	assert_eq(controller.get_cooldown_remaining(&"test"), 0.0)


func test_reset_clears_action_and_cooldown_but_keeps_skill_bindings() -> void:
	var definition := _definition()
	definition.windup_policy.can_cancel_player = false
	var controller := _controller(definition)
	assert_true(controller.request_action(&"test", _caster()))
	controller.reset_state()
	assert_eq(controller.phase, ActionController.Phase.IDLE)
	assert_eq(controller.get_cooldown_remaining(&"test"), 0.0)
	assert_not_null(controller.get_definition(&"test"))
	assert_true(controller.request_action(&"test", _caster()))


func test_nonfinite_or_negative_tick_cannot_advance_action() -> void:
	var controller := _controller(_definition())
	assert_true(controller.request_action(&"test", _caster()))
	controller.tick(-1.0)
	controller.tick(INF)
	assert_eq(controller.phase, ActionController.Phase.WINDUP)
	assert_almost_eq(controller.phase_remaining, 0.2, 0.0001)
	assert_eq(_executions.size(), 0)


func _definition() -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = &"test"
	definition.windup_seconds = 0.2
	definition.active_seconds = 0.1
	definition.recovery_seconds = 0.3
	definition.cooldown_seconds = 0.8
	return definition


func _controller(definition: SkillDefinition) -> ActionController:
	var controller := ActionController.new()
	autofree(controller)
	controller.bind_action(&"test", definition, _capture)
	return controller


func _caster() -> Node:
	return autofree(Node.new()) as Node


func _capture(_caster_node: Node, definition: SkillDefinition) -> void:
	_executions.append(definition)
