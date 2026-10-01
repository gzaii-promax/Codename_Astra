extends GutTest


class FixtureActor:
	extends Node2D

	func get_combatant() -> Combatant:
		return get_node("Combatant") as Combatant


func test_invalid_heart_container_counts_are_rejected_without_resetting_life() -> void:
	var health := _actor(_rig(), Combatant.Faction.FRIENDLY).get_combatant()
	for invalid in [0.0, -1.0, 0.5, 1.5, INF, NAN]:
		health.max_health = invalid
		assert_false(health.validate().is_empty(), "Invalid container count: %s" % invalid)
		health.reset_state()
		assert_eq(health.current_health, 3.0, "Bad configuration does not rewrite current health")
		assert_false(health.can_receive_damage())
	health.max_health = 10.0
	health.reset_state()
	assert_true(health.validate().is_empty())
	assert_eq(health.current_health, 10.0)


func test_quarter_hearts_and_other_invalid_damage_are_rejected_without_events() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	var health := target.get_combatant()
	watch_signals(health)
	for invalid in [0.25, 0.499999, -0.5, INF, NAN]:
		var hit := _hit(source, invalid)
		assert_false(hit.is_valid(), "Damage is not an exact half-heart value: %s" % invalid)
		assert_false(_receiver(target).receive_hit(hit))
		assert_false(health.apply_damage(_hit(source, 0.5), invalid))
		var definition := SkillDefinition.new()
		definition.damage = invalid
		assert_false(definition.validate().is_empty())
		var upgrade := SkillLevelOverride.new()
		upgrade.level = 2
		upgrade.values = {"damage": invalid}
		definition.damage = 0.5
		definition.level_overrides = [upgrade]
		assert_false(definition.resolve_level(2).resolution_errors.is_empty())
		assert_eq(health.current_health, 3.0)
	assert_signal_not_emitted(health, "damaged")
	assert_signal_not_emitted(health, "state_changed")


func test_six_half_heart_hits_exactly_empty_three_containers() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	for remaining in [2.5, 2.0, 1.5, 1.0, 0.5, 0.0]:
		assert_true(_receiver(target).receive_hit(_hit(source, 0.5)))
		assert_eq(target.get_combatant().current_health, remaining)
	assert_eq(target.get_combatant().life_state, Combatant.LifeState.DEAD)


func test_refill_repeats_twenty_half_hits_and_ten_whole_hits_without_death_events() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.FRIENDLY)
	var target := _actor(rig, Combatant.Faction.NEUTRAL, 10.0)
	var health := target.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.REFILL
	watch_signals(health)
	for attack in [{"damage": 0.5, "count": 20}, {"damage": 1.0, "count": 10}]:
		for index in attack.count:
			assert_true(_receiver(target).receive_hit(_hit(source, attack.damage)))
			var remaining: float = 10.0 - (index + 1) * float(attack.damage)
			assert_eq(health.current_health, 10.0 if remaining == 0.0 else remaining)
			assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_signal_emit_count(health, "damaged", 30)
	assert_signal_emit_count(health, "health_changed", 30)
	assert_signal_not_emitted(health, "state_changed")
	assert_true(_receiver(target).receive_hit(_hit(source, 12.0)))
	assert_eq(health.current_health, 10.0, "Overkill refills immediately without carrying damage")
	assert_eq(_receiver(target).last_damage, 12.0)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_signal_not_emitted(health, "state_changed")


func test_zero_damage_is_valid_contact_without_losing_or_healing_hearts() -> void:
	var rig := _rig()
	var source := _actor(rig, Combatant.Faction.ENEMY)
	var target := _actor(rig, Combatant.Faction.FRIENDLY)
	assert_true(_receiver(target).receive_hit(_hit(source, 0.5)))
	watch_signals(target.get_combatant())
	assert_true(_receiver(target).receive_hit(_hit(source, 0.0)))
	assert_eq(target.get_combatant().current_health, 2.5)
	assert_eq(_receiver(target).last_damage, 0.0)
	assert_signal_emit_count(target.get_combatant(), "damaged", 1)


func _rig() -> Node2D:
	var rig := Node2D.new()
	get_tree().root.add_child(rig)
	autofree(rig)
	return rig


func _actor(rig: Node2D, faction: Combatant.Faction, containers: float = 3.0) -> FixtureActor:
	var actor := FixtureActor.new()
	var health := Combatant.new()
	health.name = "Combatant"
	health.faction = faction
	health.max_health = containers
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
