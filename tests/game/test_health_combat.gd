extends GutTest

const FACTIONS := [Combatant.Faction.FRIENDLY, Combatant.Faction.ENEMY, Combatant.Faction.NEUTRAL]


class FixtureActor:
	extends Node2D

	var facing_direction: float = 1.0

	func get_combatant() -> Combatant:
		return get_node("Combatant") as Combatant

	func get_attack_origin() -> Vector2:
		return global_position


var _original_scene: Node
var _original_language: String
var _original_process_mode: Node.ProcessMode


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_original_language = Localization.current_language
	_original_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _original_scene
	Localization.set_language(_original_language, false)
	process_mode = _original_process_mode
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func test_health_and_damage_target_defaults_match_approved_rules() -> void:
	var actor := _actor(_rig(), Combatant.Faction.NEUTRAL)
	var health := actor.get_combatant()
	var hit := HitData.new()
	var definition := SkillDefinition.new()
	assert_eq(health.max_health, 100.0)
	assert_eq(health.current_health, 100.0)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(health.zero_health_behavior, Combatant.ZeroHealthBehavior.DEATH)
	assert_false(health.invulnerable)
	assert_eq(hit.target_policy, HitData.TargetPolicy.OTHER_FACTIONS)
	assert_eq(hit.self_reduction, 0.5)
	assert_eq(hit.same_faction_reduction, 0.5)
	assert_eq(definition.target_policy, HitData.TargetPolicy.OTHER_FACTIONS)
	assert_eq(definition.self_reduction, 0.5)
	assert_eq(definition.same_faction_reduction, 0.5)


func test_four_target_policies_cover_self_same_and_all_three_factions() -> void:
	var rig := _rig()
	for source_faction in FACTIONS:
		var source := _actor(rig, source_faction)
		var same := _actor(rig, source_faction)
		for policy in [
			HitData.TargetPolicy.OTHER_FACTIONS,
			HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF,
			HitData.TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION,
			HitData.TargetPolicy.ALL,
		]:
			_assert_policy(source, source, policy, [0.0, 5.0, 5.0, 10.0][policy])
			_assert_policy(source, same, policy, [0.0, 0.0, 5.0, 10.0][policy])
			for target_faction in FACTIONS:
				if target_faction != source_faction:
					_assert_policy(source, _actor(rig, target_faction), policy, 10.0)


func test_self_fire_damage_adds_twenty_percent_resistance_and_fifty_percent_reduction() -> void:
	var actor := _actor(_rig(), Combatant.Faction.FRIENDLY)
	actor.get_combatant().resistances = {&"fire": 0.2}
	var hit := _hit(actor, 100.0, HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF)
	hit.damage_type = &"fire"
	assert_true(_receiver(actor).receive_hit(hit))
	assert_almost_eq(_receiver(actor).last_damage, 30.0, 0.0001)
	assert_almost_eq(actor.get_combatant().current_health, 70.0, 0.0001)


func test_same_faction_reduction_adds_to_general_and_type_reductions() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.ENEMY)
	target.get_combatant().resistances = {&"ice": 0.2}
	target.get_combatant().general_reduction = 0.1
	var hit := _hit(source, 100.0, HitData.TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION)
	hit.damage_type = &"ice"
	assert_true(_receiver(target).receive_hit(hit))
	assert_almost_eq(_receiver(target).last_damage, 20.0, 0.0001)
	assert_almost_eq(target.get_combatant().current_health, 80.0, 0.0001)


func test_different_faction_does_not_receive_self_or_same_faction_reduction() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.FRIENDLY)
	var target := _actor(rig, Combatant.Faction.NEUTRAL)
	target.get_combatant().resistances = {&"fire": 0.2}
	for policy in [
		HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF,
		HitData.TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION,
	]:
		target.get_combatant().reset_state()
		var hit := _hit(source, 100.0, policy)
		hit.damage_type = &"fire"
		assert_true(_receiver(target).receive_hit(hit))
		assert_almost_eq(target.get_combatant().current_health, 20.0, 0.0001)


func test_additive_reduction_caps_at_zero_damage_without_healing() -> void:
	var actor := _actor(_rig(), Combatant.Faction.FRIENDLY)
	var health := actor.get_combatant()
	health.resistances = {&"fire": 0.8}
	health.general_reduction = 0.4
	var hit := _hit(actor, 100.0, HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF)
	hit.damage_type = &"fire"
	assert_true(
		_receiver(actor).receive_hit(hit), "Eligible contact remains accepted at zero damage"
	)
	assert_eq(_receiver(actor).last_damage, 0.0)
	assert_eq(health.current_health, 100.0)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)


func test_rejected_target_and_invulnerability_do_not_emit_damage_or_lose_health() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.FRIENDLY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var health := target.get_combatant()
	watch_signals(health)
	assert_false(_receiver(target).receive_hit(_hit(source, 100.0)))
	assert_eq(health.current_health, 100.0)
	assert_signal_not_emitted(health, "damaged")
	health.faction = Combatant.Faction.ENEMY
	health.invulnerable = true
	assert_false(_receiver(target).receive_hit(_hit(source, 100.0)))
	assert_eq(health.current_health, 100.0)
	assert_signal_not_emitted(health, "damaged")


func test_neutral_and_unowned_environment_damage_use_explicit_all_policy() -> void:
	var rig := _rig()
	var neutral_source := _actor(rig, Combatant.Faction.NEUTRAL)
	for faction in FACTIONS:
		var target := _actor(rig, faction)
		assert_true(
			_receiver(target).receive_hit(_hit(neutral_source, 10.0, HitData.TargetPolicy.ALL))
		)
		assert_eq(target.get_combatant().current_health, 90.0)
		var environment_hit := _hit(null, 15.0, HitData.TargetPolicy.ALL)
		environment_hit.set_environment()
		assert_true(environment_hit.is_environment)
		assert_true(_receiver(target).receive_hit(environment_hit))
		assert_eq(target.get_combatant().current_health, 75.0)


func test_faction_changes_and_reflection_rebinding_use_current_owner() -> void:
	var rig := _rig()
	var original := _actor(rig, Combatant.Faction.ENEMY)
	var reflector := _actor(rig, Combatant.Faction.FRIENDLY)
	var hit := _hit(original, 10.0)
	assert_true(_receiver(reflector).receive_hit(hit))
	original.get_combatant().faction = Combatant.Faction.FRIENDLY
	assert_false(
		_receiver(reflector).receive_hit(hit), "Pending hit follows current source faction"
	)
	original.get_combatant().faction = Combatant.Faction.ENEMY
	hit.set_source(reflector)
	assert_eq(hit.source, reflector, "Rebinding replaces the single current owner")
	assert_false(_receiver(reflector).receive_hit(hit))
	assert_true(_receiver(original).receive_hit(hit))
	assert_eq(original.get_combatant().current_health, 90.0)
	assert_eq(hit.damage, 10.0, "Ownership transfer does not multiply damage")


func test_destroyed_source_keeps_faction_identity_without_becoming_environment() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var ally := _actor(rig, Combatant.Faction.ENEMY)
	var opponent := _actor(rig, Combatant.Faction.FRIENDLY)
	var hit := _hit(source, 10.0)
	source.queue_free()
	await wait_frames(2)
	assert_false(is_instance_valid(source))
	assert_false(_receiver(ally).receive_hit(hit))
	assert_true(_receiver(opponent).receive_hit(hit))
	assert_eq(ally.get_combatant().current_health, 100.0)
	assert_eq(opponent.get_combatant().current_health, 90.0)


func test_zero_health_default_death_is_once_and_reset_restores_active_health() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var health := target.get_combatant()
	watch_signals(health)
	assert_true(_receiver(target).receive_hit(_hit(source, 250.0)))
	assert_eq(health.current_health, 0.0)
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_signal_emit_count(health, "state_changed", 1)
	assert_false(_receiver(target).receive_hit(_hit(source, 250.0)))
	health.force_death()
	assert_signal_emit_count(
		health, "state_changed", 1, "Repeated lethal events do not repeat death"
	)
	health.reset_state()
	assert_eq(health.current_health, 100.0)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)


func test_knockdown_blocks_finishing_damage_but_script_can_kill() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var health := target.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	watch_signals(health)
	assert_true(_receiver(target).receive_hit(_hit(source, 100.0)))
	assert_eq(health.current_health, 0.0)
	assert_eq(health.life_state, Combatant.LifeState.DOWNED)
	assert_false(_receiver(target).receive_hit(_hit(source, 1000.0, HitData.TargetPolicy.ALL)))
	assert_eq(health.life_state, Combatant.LifeState.DOWNED)
	assert_signal_emit_count(health, "state_changed", 1)
	health.force_death()
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_false(health.recover(30.0), "Getting up cannot resurrect a truly dead unit")


func test_script_death_bypasses_invulnerability_and_knockdown_configuration() -> void:
	var target := _actor(_rig(), Combatant.Faction.NEUTRAL)
	var health := target.get_combatant()
	health.invulnerable = true
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	health.force_death()
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_eq(health.current_health, 0.0)
	assert_true(health.invulnerable, "Story death does not need to remove protection first")


func test_friendly_assistance_recovers_knockdown_with_positive_capped_health() -> void:
	var rig := _rig()
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var helper := _actor(rig, Combatant.Faction.FRIENDLY)
	var opponent := _actor(rig, Combatant.Faction.ENEMY)
	var health := target.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(target).receive_hit(_hit(opponent, 100.0)))
	assert_false(health.assist_recover(opponent.get_combatant(), 30.0))
	assert_false(health.recover(0.0))
	assert_false(health.recover(-1.0))
	assert_true(health.assist_recover(helper.get_combatant(), 30.0))
	assert_eq(health.current_health, 30.0)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_true(_receiver(target).receive_hit(_hit(opponent, 100.0)))
	assert_true(health.recover(200.0))
	assert_eq(health.current_health, 100.0)


func test_knockdown_has_no_default_timer_and_explicit_recovery_can_be_cancelled() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var health := target.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(target).receive_hit(_hit(source, 100.0)))
	await wait_physics_frames(12)
	assert_eq(health.life_state, Combatant.LifeState.DOWNED)
	assert_true(health.schedule_recovery(0.1, 25.0))
	health.cancel_recovery()
	await wait_physics_frames(12)
	assert_eq(health.life_state, Combatant.LifeState.DOWNED)
	assert_true(health.schedule_recovery(0.1, 25.0))
	await wait_physics_frames(12)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(health.current_health, 25.0)


func test_script_death_cancels_pending_knockdown_recovery() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var health := target.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(target).receive_hit(_hit(source, 100.0)))
	assert_true(health.schedule_recovery(0.1, 25.0))
	health.force_death()
	await wait_physics_frames(12)
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_eq(health.current_health, 0.0)


func test_skill_level_resolution_preserves_and_validates_target_configuration() -> void:
	var definition := SkillDefinition.new()
	definition.target_policy = HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF
	var upgrade := SkillLevelOverride.new()
	upgrade.level = 2
	upgrade.values = {"self_reduction": 0.25, "same_faction_reduction": 0.75}
	definition.level_overrides = [upgrade]
	var level_two := definition.resolve_level(2)
	assert_eq(level_two.resolution_errors.size(), 0)
	assert_eq(level_two.target_policy, HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF)
	assert_eq(level_two.self_reduction, 0.25)
	assert_eq(level_two.same_faction_reduction, 0.75)
	assert_eq(definition.self_reduction, 0.5, "Resolving upgrades preserves base values")
	assert_eq(level_two.get_resolved_attributes()["self_reduction"], 0.25)
	definition.self_reduction = 1.1
	assert_gt(definition.validate().size(), 0, "Reduction outside 0..1 is rejected")
	var invalid := HitData.new()
	invalid.same_faction_reduction = -0.1
	assert_false(invalid.is_valid())


func test_executors_carry_target_configuration_into_real_melee_and_fireball() -> void:
	var rig := _rig()
	get_tree().current_scene = rig
	var source := _actor(rig, Combatant.Faction.FRIENDLY)
	var definition := SkillDefinition.new()
	definition.target_policy = HitData.TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION
	definition.self_reduction = 0.25
	definition.same_faction_reduction = 0.75
	SkillExecutors.melee(source, definition)
	SkillExecutors.fireball(source, definition)
	var count := 0
	for child in rig.get_children():
		if child is MeleeStrike or child is Fireball:
			var hit: HitData = child.get("hit")
			assert_eq(hit.target_policy, HitData.TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION)
			assert_eq(hit.self_reduction, 0.25)
			assert_eq(hit.same_faction_reduction, 0.75)
			assert_eq(hit.source, source)
			count += 1
	assert_eq(count, 2, "Both real executor paths preserve configuration")


func _rig() -> Node2D:
	var rig := Node2D.new()
	get_tree().root.add_child(rig)
	autofree(rig)
	return rig


func _actor(rig: Node2D, faction: Combatant.Faction) -> FixtureActor:
	var actor := FixtureActor.new()
	var health := Combatant.new()
	health.name = "Combatant"
	health.faction = faction
	actor.add_child(health)
	var receiver := DamageReceiver.new()
	receiver.name = "DamageReceiver"
	actor.add_child(receiver)
	rig.add_child(actor)
	return actor


func _receiver(actor: Node) -> DamageReceiver:
	return actor.get_node("DamageReceiver") as DamageReceiver


func _hit(
	source: Node, damage: float, policy: HitData.TargetPolicy = HitData.TargetPolicy.OTHER_FACTIONS
) -> HitData:
	var hit := HitData.new()
	hit.set_source(source)
	hit.damage = damage
	hit.target_policy = policy
	return hit


func _assert_policy(
	source: FixtureActor, target: FixtureActor, policy: HitData.TargetPolicy, expected_damage: float
) -> void:
	var health := target.get_combatant()
	health.reset_state()
	assert_eq(_receiver(target).receive_hit(_hit(source, 10.0, policy)), expected_damage > 0.0)
	assert_eq(health.current_health, 100.0 - expected_damage)
