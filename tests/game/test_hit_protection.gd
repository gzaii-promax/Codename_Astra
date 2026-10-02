extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const ENEMY_ATTACK: SkillDefinition = preload("res://skills/definitions/enemy_attack.tres")


class ProtectionTickSampler:
	extends Node

	signal completed

	var health: Combatant
	var receiver: DamageReceiver
	var hit: HitData
	var start_frame: int = -1
	var initial_accepted: bool = false
	var samples: Dictionary = {}
	var ticks: Array[Dictionary] = []

	func _physics_process(_delta: float) -> void:
		var engine_frame := Engine.get_physics_frames()
		ticks.append({"physics": engine_frame, "process": Engine.get_process_frames()})
		if start_frame < 0:
			initial_accepted = receiver.receive_hit(hit)
			start_frame = engine_frame
			return
		var elapsed := engine_frame - start_frame
		if elapsed not in [12, 29, 30]:
			return
		var sample := {
			"elapsed": elapsed,
			"remaining": health.get_hit_protection_remaining(),
			"can_receive": health.can_receive_damage(),
			"process_frame": Engine.get_process_frames(),
		}
		if elapsed in [12, 30]:
			sample["accepted"] = receiver.receive_hit(hit)
			sample["after_remaining"] = health.get_hit_protection_remaining()
			sample["after_health"] = health.current_health
		samples[elapsed] = sample
		if elapsed == 30:
			set_physics_process(false)
			completed.emit()


var _original_scene: Node
var _original_process_mode: Node.ProcessMode
var _original_max_fps: int


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_original_process_mode = process_mode
	_original_max_fps = Engine.max_fps
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _original_scene
	process_mode = _original_process_mode
	Engine.max_fps = _original_max_fps
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func test_hit_protection_defaults_match_public_config_and_real_actors() -> void:
	var arena := _arena()
	assert_eq(CombatConfig.PLAYER_HIT_PROTECTION_SECONDS, 0.5)
	assert_eq(CombatConfig.DEFAULT_HIT_PROTECTION_SECONDS, 0.0)
	assert_eq(arena.player.get_combatant().hit_protection_seconds, 0.5)
	assert_eq(arena.enemy.get_combatant().hit_protection_seconds, 0.0)
	assert_eq(arena.player.get_combatant().get_hit_protection_remaining(), 0.0)
	assert_eq(arena.enemy.get_combatant().get_hit_protection_remaining(), 0.0)
	assert_eq(arena.dummy.get_receiver().get_combatant(), arena.dummy.get_combatant())
	assert_eq(arena.dummy.get_combatant().hit_protection_seconds, 0.0)
	assert_eq(arena.dummy.get_combatant().max_health, 10.0)
	assert_eq(arena.dummy.get_combatant().zero_health_behavior, Combatant.ZeroHealthBehavior.REFILL)
	var default_health := Combatant.new()
	autofree(default_health)
	assert_eq(default_health.hit_protection_seconds, 0.0)


func test_zero_protection_bypasses_consecutive_hits_for_enemy_and_dummy() -> void:
	var arena := _arena()
	var enemy := arena.enemy.get_combatant()
	for index in range(3):
		assert_true(arena.enemy.get_receiver().receive_hit(_hit(arena.player, 0.5)))
		assert_eq(enemy.current_health, 3.0 - 0.5 * (index + 1))
		assert_eq(enemy.get_hit_protection_remaining(), 0.0)
		assert_true(arena.dummy.get_receiver().receive_hit(_hit(arena.player, 0.5)))
		assert_eq(arena.dummy.get_combatant().current_health, 10.0 - 0.5 * (index + 1))
		assert_eq(arena.dummy.get_combatant().get_hit_protection_remaining(), 0.0)
	assert_eq(arena.dummy.hit_count, 3)
	assert_eq(arena.dummy.total_damage, 1.5)
	var health := _actor(0.5).get_node("Combatant") as Combatant
	assert_true(health.apply_damage(_hit(null, 0.5), 0.5))
	health.hit_protection_seconds = 0.0
	assert_true(health.can_receive_damage(), "Zero configuration bypasses a previous timer")
	assert_true(health.apply_damage(_hit(null, 0.5), 0.5))
	assert_eq(health.current_health, 2.0)


func test_invalid_hit_protection_configuration_and_damage_are_rejected() -> void:
	var actor := _actor(0.5)
	var health := actor.get_node("Combatant") as Combatant
	for duration in [-0.1, INF, NAN]:
		health.hit_protection_seconds = duration
		assert_gt(health.validate().size(), 0)
		assert_false(health.can_receive_damage())
		assert_false(_receiver(actor).receive_hit(_hit(null, 0.5)))
		assert_eq(health.get_hit_protection_remaining(), 0.0)
	health.hit_protection_seconds = 0.5
	assert_eq(health.validate().size(), 0)
	assert_false(health.apply_damage(null, 0.5))
	for amount in [-0.5, 0.25, 0.499999, INF, NAN]:
		assert_false(health.apply_damage(_hit(null, 0.5), amount))
	assert_eq(health.current_health, 3.0)
	assert_eq(health.get_hit_protection_remaining(), 0.0)


func test_rejected_and_zero_settled_damage_do_not_start_hit_protection() -> void:
	var actor := _actor(0.5)
	var health := actor.get_node("Combatant") as Combatant
	var receiver := _receiver(actor)
	receiver.enabled = false
	assert_false(receiver.receive_hit(_hit(null, 0.5)))
	receiver.enabled = true
	assert_false(receiver.receive_hit(_hit(null, -1.0)))
	assert_false(receiver.receive_hit(_hit(actor, 0.5, HitData.TargetPolicy.OTHER_FACTIONS)))
	health.invulnerable = true
	assert_false(receiver.receive_hit(_hit(null, 0.5)))
	health.invulnerable = false
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	watch_signals(health)
	watch_signals(receiver)
	assert_true(receiver.receive_hit(_hit(null, 0.0)))
	assert_true(health.apply_damage(_hit(null, 0.0), 0.0))
	assert_eq(receiver.last_damage, 0.0)
	assert_eq(health.current_health, 3.0)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_signal_emit_count(health, "damaged", 2, "Zero settled damage remains accepted")
	assert_signal_emit_count(receiver, "hit_received", 1)
	assert_true(receiver.receive_hit(_hit(null, 0.5)))
	assert_eq(health.current_health, 2.5)
	assert_eq(health.get_hit_protection_remaining(), 0.5)
	assert_false(health.invulnerable, "Timed protection does not mutate manual invulnerability")


func test_protected_hit_has_no_damage_events_health_bar_change_or_action_interrupt() -> void:
	var arena := _arena()
	var player := arena.player
	var health := player.get_combatant()
	var receiver := _receiver(player)
	var bar := player.get_node("HealthBar") as HealthBar
	assert_true(receiver.receive_hit(_hit(arena.enemy, 0.5)))
	var actions := player.get_action_controller()
	var definition := actions.get_definition(&"basic_attack").duplicate(true) as SkillDefinition
	definition.windup_seconds = 0.0
	definition.active_seconds = 0.4
	definition.active_policy.can_interrupt_hit = true
	actions.bind_action(&"basic_attack", definition, SkillExecutors.melee)
	assert_true(player.request_attack())
	assert_eq(actions.phase, ActionController.Phase.ACTIVE)
	watch_signals(health)
	watch_signals(receiver)
	assert_false(health.can_receive_damage())
	assert_false(health.apply_damage(_hit(arena.enemy, 1.0), 1.0))
	assert_false(receiver.receive_hit(_hit(arena.enemy, 1.0)))
	assert_eq(receiver.last_damage, 0.0)
	assert_eq(health.current_health, 2.5)
	assert_almost_eq(bar.get_fill_ratio(), 5.0 / 6.0, 0.0001)
	assert_eq(bar.get_container_fills(), [1.0, 1.0, 0.5])
	assert_true(bar.get_display_text().contains("2.5"))
	assert_eq(actions.phase, ActionController.Phase.ACTIVE, "Rejected hit cannot interrupt")
	assert_signal_not_emitted(health, "health_changed")
	assert_signal_not_emitted(health, "state_changed")
	assert_signal_not_emitted(health, "damaged")
	assert_signal_not_emitted(receiver, "hit_received")


func test_hit_protection_expires_after_half_second_and_rejected_hits_do_not_extend_it() -> void:
	var actor := _actor(0.5)
	var health := actor.get_node("Combatant") as Combatant
	var receiver := _receiver(actor)
	if OS.get_environment("ASTRA_PROTECTION_SAMPLE_LOW_FPS") == "1":
		Engine.max_fps = 10
	var sampler := ProtectionTickSampler.new()
	sampler.process_mode = Node.PROCESS_MODE_ALWAYS
	# Read every real tick after Combatant has advanced, without waiting for a render frame.
	sampler.process_physics_priority = 100
	sampler.health = health
	sampler.receiver = receiver
	sampler.hit = _hit(null, 0.5)
	get_tree().root.add_child(sampler)
	autofree(sampler)
	await sampler.completed
	# Samples are already frozen; release the emitting callback before GUT frees the sampler.
	await get_tree().process_frame
	assert_true(sampler.initial_accepted)
	var twelfth: Dictionary = sampler.samples[12]
	assert_eq(twelfth["elapsed"], 12)
	assert_almost_eq(twelfth["remaining"], 0.3, 0.00001)
	assert_false(twelfth["accepted"])
	assert_eq(
		twelfth["after_remaining"], twelfth["remaining"], "Rejected hit keeps original expiry"
	)
	var twenty_ninth: Dictionary = sampler.samples[29]
	assert_eq(twenty_ninth["elapsed"], 29)
	assert_false(twenty_ninth["can_receive"], "29 frames are still less than 0.5 s")
	var thirtieth: Dictionary = sampler.samples[30]
	assert_eq(thirtieth["elapsed"], 30)
	assert_eq(thirtieth["remaining"], 0.0)
	assert_true(thirtieth["can_receive"], "Exactly 30 frames complete the 0.5 s interval")
	assert_true(thirtieth["accepted"])
	assert_eq(thirtieth["after_health"], 2.0)
	assert_eq(thirtieth["after_remaining"], 0.5)
	print(
		"HIT_PROTECTION_TICK_SAMPLES=",
		JSON.stringify(
			{"fps_limit": Engine.max_fps, "samples": sampler.samples, "ticks": sampler.ticks}
		)
	)


func test_hit_protection_prevents_same_frame_reentrant_signal_damage() -> void:
	var actor := _actor(0.5)
	var health := actor.get_node("Combatant") as Combatant
	var receiver := _receiver(actor)
	var hit := _hit(null, 0.5)
	var results: Array[bool] = []
	var settled_amounts: Array[float] = []
	health.health_changed.connect(
		func(_current: float, _maximum: float):
			if results.is_empty():
				results.append(false)
				results[0] = receiver.receive_hit(hit)
	)
	health.damaged.connect(
		func(_hit_data: HitData, _amount: float):
			if results.size() == 1:
				results.append(false)
				results[1] = health.apply_damage(hit, 0.5)
	)
	receiver.hit_received.connect(
		func(_hit_data: HitData): settled_amounts.append(receiver.last_damage)
	)
	watch_signals(health)
	watch_signals(receiver)
	assert_true(receiver.receive_hit(hit))
	assert_eq(results, [false, false], "Timer is installed before any damage signal callback")
	assert_eq(health.current_health, 2.5)
	assert_eq(health.get_hit_protection_remaining(), 0.5)
	assert_eq(settled_amounts, [0.5], "Outer accepted event retains its settled amount")
	assert_eq(receiver.last_damage, 0.5)
	assert_signal_emit_count(health, "health_changed", 1)
	assert_signal_emit_count(health, "damaged", 1)
	assert_signal_emit_count(receiver, "hit_received", 1)


func test_pause_freezes_hit_protection_and_training_reset_clears_it() -> void:
	var arena := _arena()
	var health := arena.player.get_combatant()
	var hud := arena.get_node("HUD") as TrainingHUD
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 0.5)))
	await _physics_frames(6)
	var remaining := health.get_hit_protection_remaining()
	hud.open_menu()
	await _physics_frames(35)
	assert_eq(health.get_hit_protection_remaining(), remaining)
	assert_false(health.can_receive_damage(), "Paused time cannot consume protection")
	hud.close_menu()
	await _physics_frames(31)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 0.5)))
	arena.reset_training()
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_eq(health.current_health, 3.0)
	assert_true(health.can_receive_damage())
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 0.5)))


func test_death_knockdown_and_recovery_clear_protection_without_breaking_recovery_timer() -> void:
	var actor := _actor(0.5)
	var health := actor.get_node("Combatant") as Combatant
	var receiver := _receiver(actor)
	assert_true(receiver.receive_hit(_hit(null, 0.5)))
	health.invulnerable = true
	health.force_death()
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_true(health.invulnerable)
	health.invulnerable = false
	health.reset_state()
	assert_true(receiver.receive_hit(_hit(null, 3.0)))
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_eq(health.get_hit_protection_remaining(), 0.0, "Lethal hit cannot leave a timer")
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	health.reset_state()
	assert_true(receiver.receive_hit(_hit(null, 3.0)))
	assert_eq(health.life_state, Combatant.LifeState.DOWNED)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_true(health.recover(1.5))
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_true(receiver.receive_hit(_hit(null, 1.5)), "Recovered unit receives damage immediately")
	assert_true(health.schedule_recovery(0.1, 1.0))
	get_tree().paused = true
	await _physics_frames(12)
	assert_eq(health.life_state, Combatant.LifeState.DOWNED)
	get_tree().paused = false
	await _physics_frames(12)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(health.current_health, 1.0)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_true(receiver.receive_hit(_hit(null, 0.5)))
	assert_eq(health.current_health, 0.5)
	assert_eq(health.get_hit_protection_remaining(), 0.5)


func test_real_enemy_melee_and_fireball_obey_player_hit_protection() -> void:
	var arena := _arena()
	var player := arena.player
	var enemy := arena.enemy
	player.reset_state(enemy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await _physics_frames(3)
	SkillExecutors.melee(enemy, ENEMY_ATTACK)
	await _physics_frames(3)
	assert_eq(player.get_combatant().current_health, 2.5, "Actual melee opens protection")
	watch_signals(_receiver(player))
	SkillExecutors.melee(enemy, ENEMY_ATTACK)
	var fireball := SkillDefinition.new()
	fireball.damage = 1.0
	SkillExecutors.fireball(enemy, fireball)
	var projectile := arena.get_child(arena.get_child_count() - 1) as Fireball
	assert_not_null(projectile)
	await _physics_frames(10)
	assert_eq(player.get_combatant().current_health, 2.5)
	assert_false(is_instance_valid(projectile), "Protected contact still consumes a fireball")
	assert_signal_not_emitted(_receiver(player), "hit_received")
	var long_melee := ENEMY_ATTACK.duplicate(true) as SkillDefinition
	long_melee.active_seconds = 0.8
	SkillExecutors.melee(enemy, long_melee)
	await _physics_frames(31)
	assert_eq(player.get_combatant().current_health, 2.0, "Long window first hits after expiry")
	assert_signal_emit_count(_receiver(player), "hit_received", 1)
	await _physics_frames(20)
	assert_eq(player.get_combatant().current_health, 2.0, "Same window still hits only once")
	assert_signal_emit_count(_receiver(player), "hit_received", 1)
	SkillExecutors.fireball(enemy, fireball)
	await _physics_frames(6)
	assert_eq(player.get_combatant().current_health, 1.0, "Actual projectile damages after expiry")
	assert_signal_emit_count(_receiver(player), "hit_received", 2)


func test_refill_with_nonzero_protection_blocks_reentry_and_force_death_clears_it() -> void:
	var arena := _arena()
	var dummy := arena.dummy
	var health := dummy.get_combatant()
	var receiver := dummy.get_receiver()
	health.hit_protection_seconds = 0.5
	var refill_hit := _hit(arena.player, 12.0)
	var followup_hit := _hit(arena.player, 0.5)
	var reentrant_results: Array[bool] = []
	health.health_changed.connect(
		func(_current: float, _maximum: float):
			if reentrant_results.is_empty():
				reentrant_results.append(false)
				reentrant_results[0] = receiver.receive_hit(followup_hit)
	)
	health.damaged.connect(
		func(_hit_data: HitData, _amount: float):
			if reentrant_results.size() == 1:
				reentrant_results.append(false)
				reentrant_results[1] = health.apply_damage(followup_hit, 0.5)
	)
	watch_signals(health)
	watch_signals(receiver)
	assert_true(receiver.receive_hit(refill_hit))
	assert_eq(health.current_health, 10.0, "Positive overkill immediately refills all containers")
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(health.get_hit_protection_remaining(), 0.5)
	assert_eq(reentrant_results, [false, false], "Refill installs protection before signals")
	assert_eq(receiver.last_damage, 12.0)
	assert_eq(dummy.total_damage, 12.0, "A refill keeps full overkill statistics exactly once")
	assert_eq(dummy.hit_count, 1)
	assert_signal_emit_count(health, "health_changed", 1)
	assert_signal_emit_count(health, "damaged", 1)
	assert_signal_emit_count(receiver, "hit_received", 1)
	assert_signal_not_emitted(health, "state_changed")
	assert_false(receiver.receive_hit(followup_hit))
	assert_eq(dummy.total_damage, 12.0)
	assert_eq(dummy.hit_count, 1)
	await _physics_frames(31)
	assert_true(receiver.receive_hit(followup_hit))
	assert_eq(health.current_health, 9.5)
	assert_eq(health.get_hit_protection_remaining(), 0.5)
	health.force_death()
	assert_eq(health.life_state, Combatant.LifeState.DEAD)
	assert_eq(health.current_health, 0.0)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	health.reset_state()
	assert_eq(health.current_health, 10.0)
	assert_eq(health.get_hit_protection_remaining(), 0.0)
	assert_true(receiver.receive_hit(followup_hit), "Reset removes the old refill protection")
	assert_eq(health.current_health, 9.5)


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	autofree(arena)
	get_tree().current_scene = arena
	arena.enemy.attack_enabled = false
	arena.player.set_control_input(0.0)
	return arena


func _actor(protection: float) -> Node2D:
	var actor := Node2D.new()
	var health := Combatant.new()
	health.name = "Combatant"
	health.hit_protection_seconds = protection
	actor.add_child(health)
	var receiver := DamageReceiver.new()
	receiver.name = "DamageReceiver"
	actor.add_child(receiver)
	get_tree().root.add_child(actor)
	autofree(actor)
	return actor


func _receiver(actor: Node) -> DamageReceiver:
	return actor.get_node("DamageReceiver") as DamageReceiver


func _hit(
	source: Node, damage: float, policy: HitData.TargetPolicy = HitData.TargetPolicy.ALL
) -> HitData:
	var hit := HitData.new()
	hit.set_source(source)
	hit.damage = damage
	hit.target_policy = policy
	return hit


func _physics_frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame
