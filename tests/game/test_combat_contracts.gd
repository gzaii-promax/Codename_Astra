extends GutTest


class NestedActor:
	extends Node2D

	var health: Combatant

	func get_combatant() -> Combatant:
		return health


class InvalidProvider:
	extends Node

	var candidate: Variant

	func get_combatant() -> Variant:
		return candidate


func test_combat_source_provider_survives_nested_and_renamed_components() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var hit := _hit(actor)
	assert_eq(
		hit.get_source_faction(),
		Combatant.Faction.ENEMY,
		"MECHANISM: Source faction follows the public provider, not a child name"
	)
	actor.health.faction = Combatant.Faction.NEUTRAL
	assert_eq(hit.get_source_faction(), Combatant.Faction.NEUTRAL)


func test_combat_missing_or_wrong_receiver_binding_rejects_contact() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var receiver := DamageReceiver.new()
	actor.add_child(receiver)
	watch_signals(receiver)
	var hit := _hit(actor.health)
	hit.target_policy = HitData.TargetPolicy.ALL
	assert_false(
		receiver.receive_hit(hit), "MECHANISM: Missing health binding is not a healthless target"
	)
	receiver.combatant_path = ^".."
	assert_false(receiver.receive_hit(hit), "MECHANISM: Wrong-type health binding rejects damage")
	assert_eq(actor.health.current_health, 3.0)
	assert_signal_not_emitted(receiver, "hit_received")
	assert_false(receiver.validate().is_empty())
	assert_true(receiver.last_error.contains("combatant_path"))
	assert_false(receiver._get_configuration_warnings().is_empty())


func test_combat_outer_result_survives_rejection_in_hit_listener() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var receiver := _receiver(actor)
	var hit := _hit(actor)
	hit.target_policy = HitData.TargetPolicy.ALL
	var rejected := _hit(actor)
	rejected.damage = -0.5
	receiver.hit_received.connect(func(_hit_data: HitData): receiver.receive_hit(rejected))
	assert_true(receiver.receive_hit(hit))
	assert_eq(receiver.last_damage, 0.5, "MECHANISM: A completed outer contact owns its result")


func test_combat_dummy_statistics_do_not_depend_on_listener_order() -> void:
	var dummy := load("res://world/training_dummy.tscn").instantiate() as TrainingDummy
	var rejected := HitData.new()
	rejected.damage = -0.5
	var receiver := dummy.get_node("DamageReceiver") as DamageReceiver
	receiver.hit_received.connect(func(_hit_data: HitData): receiver.receive_hit(rejected))
	get_tree().root.add_child(dummy)
	autofree(dummy)
	var actor := _nested_actor(Combatant.Faction.FRIENDLY)
	assert_true(receiver.receive_hit(_hit(actor)))
	assert_eq(dummy.hit_count, 1)
	assert_eq(dummy.total_damage, 0.5, "MECHANISM: Earlier listeners cannot erase settled damage")
	assert_eq(dummy.get_damage_label_texts(), ["0.5"])


func test_combat_healthless_contact_requires_explicit_mode() -> void:
	var receiver := DamageReceiver.new()
	get_tree().root.add_child(receiver)
	autofree(receiver)
	var hit := HitData.new()
	hit.set_environment()
	hit.damage = 1.0
	assert_false(receiver.receive_hit(hit))
	receiver.healthless_target = true
	assert_eq(receiver.validate(), [])
	watch_signals(receiver)
	assert_true(receiver.receive_hit(hit))
	assert_eq(receiver.last_damage, 1.0)
	assert_eq(receiver.last_error, "")
	assert_signal_emit_count(receiver, "hit_resolved", 1)
	receiver.healthless_target = false
	assert_false(receiver.receive_hit(hit))
	assert_eq(receiver.last_damage, 0.0)


func test_combat_unknown_or_broken_source_is_rejected_with_diagnostics() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var receiver := _receiver(actor)
	var hit := HitData.new()
	hit.damage = 0.5
	assert_false(hit.is_valid())
	assert_false(receiver.receive_hit(hit))
	assert_true(receiver.last_error.contains("source"))
	var unknown := Node.new()
	get_tree().root.add_child(unknown)
	autofree(unknown)
	hit.set_source(unknown)
	assert_false(hit.is_valid())
	assert_false(receiver.receive_hit(hit))
	var provider := InvalidProvider.new()
	get_tree().root.add_child(provider)
	autofree(provider)
	for invalid in [42, "not a component", null, RefCounted.new(), {}]:
		provider.candidate = invalid
		hit.set_source(provider)
		assert_false(
			hit.is_valid(), "MECHANISM: Invalid provider returns reject without cast errors"
		)
		assert_false(receiver.receive_hit(hit))
		assert_true(receiver.last_error.contains("source"))
	provider.candidate = actor.health
	hit.set_source(provider)
	assert_true(hit.is_valid())
	provider.candidate = 42
	assert_false(
		hit.is_valid(), "MECHANISM: Live broken providers cannot reuse valid cached identity"
	)
	assert_false(receiver.receive_hit(hit))
	for component in [Node.new(), Combatant.new()]:
		provider.candidate = component
		hit.set_source(provider)
		component.free()
		assert_false(
			hit.is_valid(), "MECHANISM: Freed provider results reject without engine errors"
		)
		assert_false(receiver.receive_hit(hit))
		hit.set_source(provider)
		assert_false(hit.is_valid())
	assert_eq(actor.health.current_health, 3.0)
	hit.set_source(actor)
	assert_true(hit.is_valid())
	actor.health = null
	assert_false(hit.is_valid(), "MECHANISM: A live broken provider cannot reuse stale identity")
	assert_false(receiver.receive_hit(hit))
	hit.set_environment()
	assert_true(hit.is_valid())
	assert_true(receiver.receive_hit(hit))


func test_combat_direct_component_self_identity_survives_nested_ownership() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var receiver := _receiver(actor)
	var hit := _hit(actor.health)
	assert_true(hit.is_self(actor))
	assert_true(hit.is_self(receiver))
	assert_false(receiver.receive_hit(hit))
	hit.target_policy = HitData.TargetPolicy.OTHER_FACTIONS_AND_SELF
	assert_true(receiver.receive_hit(hit))
	assert_eq(actor.health.current_health, 2.5)
	var ally := _nested_actor(Combatant.Faction.ENEMY)
	assert_false(_receiver(ally).receive_hit(hit))


func test_combat_resolved_amount_survives_accepted_hit_in_earlier_listener() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var receiver := _receiver(actor)
	var outer := _hit(actor)
	outer.target_policy = HitData.TargetPolicy.ALL
	var inner := _hit(actor)
	inner.target_policy = HitData.TargetPolicy.ALL
	inner.damage = 1.0
	var results: Array[bool] = []
	var amounts: Array[float] = []
	receiver.hit_resolved.connect(
		func(_hit_data: HitData, amount: float):
			if amount == 0.5:
				results.append(receiver.receive_hit(inner))
	)
	receiver.hit_resolved.connect(func(_hit_data: HitData, amount: float): amounts.append(amount))
	assert_true(receiver.receive_hit(outer))
	assert_eq(results, [true])
	assert_eq(
		amounts, [1.0, 0.5], "MECHANISM: Each event retains its own settlement during reentry"
	)
	assert_eq(receiver.last_damage, 0.5)
	assert_eq(actor.health.current_health, 1.5)


func test_combat_resolved_amount_survives_rejected_hit_in_earlier_listener() -> void:
	var actor := _nested_actor(Combatant.Faction.ENEMY)
	var receiver := _receiver(actor)
	var hit := _hit(actor)
	hit.target_policy = HitData.TargetPolicy.ALL
	var rejected := _hit(actor)
	rejected.damage = -0.5
	var results: Array[bool] = []
	var amounts: Array[float] = []
	receiver.hit_resolved.connect(
		func(_hit_data: HitData, _amount: float): results.append(receiver.receive_hit(rejected))
	)
	receiver.hit_resolved.connect(func(_hit_data: HitData, amount: float): amounts.append(amount))
	assert_true(receiver.receive_hit(hit))
	assert_eq(results, [false])
	assert_eq(
		amounts, [0.5], "MECHANISM: Earlier rejection cannot erase a resolved signal argument"
	)
	assert_eq(receiver.last_damage, 0.5)
	assert_eq(receiver.last_error, "")
	assert_eq(actor.health.current_health, 2.5)


func test_combat_receiver_paths_and_explicit_mode_survive_scene_round_trip() -> void:
	for healthless in [false, true]:
		var actor := Node.new()
		var stats := Node.new()
		stats.name = "Stats"
		actor.add_child(stats)
		stats.owner = actor
		var health := Combatant.new()
		health.name = "Vitals"
		stats.add_child(health)
		health.owner = actor
		var boxes := Node.new()
		boxes.name = "Hurtboxes"
		actor.add_child(boxes)
		boxes.owner = actor
		var receiver := DamageReceiver.new()
		receiver.name = "Target"
		receiver.combatant_path = ^"../../Stats/Vitals"
		receiver.healthless_target = healthless
		boxes.add_child(receiver)
		receiver.owner = actor
		var packed := PackedScene.new()
		assert_eq(packed.pack(actor), OK)
		var path := OS.get_environment("ASTRA_SETTINGS_PATH").get_base_dir().path_join(
			"combat-receiver-%s.tscn" % str(healthless)
		)
		assert_eq(ResourceSaver.save(packed, path), OK)
		actor.free()
		var saved := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		var restored := (saved as PackedScene).instantiate()
		receiver = restored.get_node("Hurtboxes/Target") as DamageReceiver
		health = restored.get_node("Stats/Vitals") as Combatant
		assert_eq(receiver.combatant_path, ^"../../Stats/Vitals")
		assert_eq(receiver.healthless_target, healthless)
		get_tree().root.add_child(restored)
		autofree(restored)
		assert_eq(receiver.validate(), [])
		var hit := HitData.new()
		hit.set_environment()
		hit.damage = 0.5
		assert_true(receiver.receive_hit(hit))
		assert_eq(health.current_health, 3.0 if healthless else 2.5)
		health.reset_state()
		assert_eq(receiver.combatant_path, ^"../../Stats/Vitals")
		assert_eq(receiver.healthless_target, healthless)
		assert_true(receiver.receive_hit(hit))
		assert_eq(health.current_health, 3.0 if healthless else 2.5)


func _nested_actor(faction: Combatant.Faction) -> NestedActor:
	var actor := NestedActor.new()
	var stats := Node.new()
	stats.name = "Stats"
	actor.add_child(stats)
	actor.health = Combatant.new()
	actor.health.name = "Vitals"
	actor.health.faction = faction
	stats.add_child(actor.health)
	get_tree().root.add_child(actor)
	autofree(actor)
	return actor


func _receiver(actor: NestedActor) -> DamageReceiver:
	var receiver := DamageReceiver.new()
	receiver.combatant_path = ^"../Stats/Vitals"
	actor.add_child(receiver)
	return receiver


func _hit(source: Node) -> HitData:
	var hit := HitData.new()
	hit.set_source(source)
	hit.damage = 0.5
	return hit
