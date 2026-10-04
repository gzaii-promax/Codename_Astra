extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")

var _original_scene: Node
var _outside_hits: int = 0


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_outside_hits = 0


func after_each() -> void:
	get_tree().current_scene = _original_scene
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball"]:
		Input.action_release(action)


func test_main_scene_has_playable_nodes_and_real_input_bindings() -> void:
	var arena := _arena()
	await wait_physics_frames(6)
	assert_true(arena.player.is_on_floor())
	assert_not_null(arena.dummy.get_receiver())
	assert_not_null(arena.player.get_action_controller().get_definition(&"fireball"))
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball"]:
		assert_true(InputMap.has_action(action))
		assert_gt(InputMap.action_get_events(action).size(), 0, "Mapped input: %s" % action)


func test_player_moves_changes_facing_and_stops_with_no_input() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var start := player.global_position.x
	player.set_control_input(1.0)
	await wait_physics_frames(20)
	assert_gt(player.global_position.x, start + 5.0)
	assert_eq(player.facing_direction, 1.0)
	player.set_control_input(-1.0)
	await wait_physics_frames(20)
	assert_eq(player.facing_direction, -1.0)
	assert_lt(player.velocity.x, 0.0)
	player.set_control_input(0.0)
	await wait_physics_frames(20)
	assert_almost_eq(player.velocity.x, 0.0, 0.01)


func test_mapped_input_drives_player_without_control_override() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var start := player.global_position.x
	Input.action_press("move_right")
	await wait_physics_frames(20)
	Input.action_release("move_right")
	assert_gt(player.global_position.x, start + 5.0)


func test_jump_leaves_floor_and_returns_to_graybox_ground() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var ground_y := player.global_position.y
	player.set_control_input(0.0, true, true)
	await wait_physics_frames(8)
	assert_false(player.is_on_floor())
	assert_lt(player.global_position.y, ground_y - 20.0)
	await wait_physics_frames(65)
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, ground_y, 0.1)


func test_second_jump_in_air_cannot_reset_vertical_velocity() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	player.set_control_input(0.0, true, true)
	await wait_physics_frames(10)
	var rising_velocity := player.velocity.y
	assert_lt(rising_velocity, 0.0)
	player.set_control_input(0.0, true, true)
	await wait_physics_frames(2)
	assert_gt(player.velocity.y, rising_velocity, "Gravity continues; no second air jump")


func test_graybox_wall_blocks_character_movement() -> void:
	var player := _arena().player
	player.reset_state(Vector2(708.0, 440.0))
	player.set_control_input(1.0)
	await wait_physics_frames(30)
	assert_lte(player.global_position.x, 712.1, "16 px body cannot cross wall at x = 720")
	assert_true(player.is_on_wall())


func test_player_melee_hits_actual_training_dummy_once() -> void:
	var arena := _arena()
	var player := arena.player
	player.reset_state(arena.dummy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.request_attack())
	await wait_physics_frames(35)
	assert_eq(arena.dummy.hit_count, 1)
	assert_eq(arena.dummy.total_damage, 0.5)
	assert_eq(arena.dummy.last_hit.skill_id, &"basic_attack")


func test_player_fireball_waits_for_windup_then_hits_actual_dummy() -> void:
	var arena := _arena()
	var player := arena.player
	player.reset_state(arena.dummy.global_position + Vector2(-56.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.request_fireball())
	await wait_physics_frames(20)
	assert_eq(arena.dummy.hit_count, 0, "No hit before first-level windup completes")
	assert_eq(_projectile_count(arena), 0, "No early projectile spawn")
	await wait_physics_frames(45)
	assert_eq(arena.dummy.hit_count, 1)
	assert_eq(arena.dummy.total_damage, 1.0)
	assert_eq(arena.dummy.last_hit.skill_id, &"fireball")
	assert_eq(_projectile_count(arena), 0, "Projectile removed on impact")


func test_player_upgrade_rebinds_shorter_windup_with_same_damage() -> void:
	var player := _arena().player
	player.set_fireball_level(2)
	var definition := player.get_action_controller().get_definition(&"fireball")
	assert_almost_eq(definition.windup_seconds, 0.2, 0.0001)
	assert_eq(definition.damage, 1.0)
	assert_eq(definition.resolved_level, 2)
	player.set_fireball_level(1)
	assert_almost_eq(
		player.get_action_controller().get_definition(&"fireball").windup_seconds, 0.5, 0.0001
	)


func test_training_reset_clears_projectiles_damage_action_and_cooldown() -> void:
	var arena := _arena()
	var player := arena.player
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.request_fireball())
	await wait_physics_frames(34)
	assert_eq(_projectile_count(arena), 1)
	var hit := HitData.new()
	hit.source = player
	hit.damage = 0.5
	assert_true(arena.dummy.get_receiver().receive_hit(hit))
	arena.reset_training()
	await wait_physics_frames(3)
	assert_eq(_projectile_count(arena), 0)
	assert_eq(arena.dummy.hit_count, 0)
	assert_eq(arena.dummy.total_damage, 0.0)
	assert_eq(player.get_action_controller().phase, ActionController.Phase.IDLE)
	assert_eq(player.get_action_controller().get_cooldown_remaining(&"fireball"), 0.0)
	assert_almost_eq(player.global_position.x, 272.0, 0.1)


func test_reverse_input_during_melee_keeps_facing_and_attack_origin_consistent() -> void:
	var arena := _arena()
	var player := arena.player
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.request_attack())
	await wait_physics_frames(7)
	assert_eq(player.get_action_controller().phase, ActionController.Phase.ACTIVE)
	player.set_control_input(-1.0)
	await wait_physics_frames(2)
	assert_eq(
		player.facing_direction, 1.0, "Execution locks facing while accepting reverse movement"
	)
	assert_gt(player.get_attack_origin().x, player.global_position.x)
	var strikes: Array[MeleeStrike] = []
	for child in arena.get_children():
		if child is MeleeStrike:
			strikes.append(child)
	assert_eq(strikes.size(), 1)
	if not strikes.is_empty():
		assert_eq(strikes[0].facing, player.facing_direction)
		assert_almost_eq(strikes[0].global_position.x, player.get_attack_origin().x, 0.01)
	await wait_physics_frames(30)
	assert_eq(player.facing_direction, -1.0, "Turning resumes after action completion")


func test_reset_disables_old_effects_before_next_physics_hit() -> void:
	var arena := _arena()
	var player := arena.player
	player.reset_state(arena.dummy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	SkillExecutors.fireball(player, player.get_action_controller().get_definition(&"fireball"))
	SkillExecutors.melee(player, player.get_action_controller().get_definition(&"basic_attack"))
	var effects: Array[Node] = []
	for child in arena.get_children():
		if child is Fireball or child is MeleeStrike:
			effects.append(child)
	assert_eq(effects.size(), 2, "Both effects are placed close enough to hit next physics frame")
	arena.reset_training()
	for effect in effects:
		assert_false(effect.is_physics_processing(), "Reset stops physics immediately")
		assert_true(effect.is_queued_for_deletion())
	await wait_physics_frames(6)
	assert_eq(arena.dummy.hit_count, 0, "Old effects cannot contaminate cleared statistics")
	assert_eq(arena.dummy.total_damage, 0.0)


func test_fireball_cannot_spawn_beyond_right_wall() -> void:
	var arena := _arena()
	var player := arena.player
	_outside_receiver(arena, Vector2(760.0, 424.0))
	player.reset_state(Vector2(712.0, 440.0))
	player.set_control_input(1.0)
	await wait_physics_frames(4)
	player.set_control_input(0.0)
	player.set_fireball_level(2)
	assert_true(player.request_fireball())
	await wait_physics_frames(45)
	assert_eq(_outside_hits, 0, "Cast origin must not teleport past solid wall")
	assert_eq(_projectile_count(arena), 0, "Wall consumes cast projectile")


func test_fireball_cannot_spawn_beyond_left_wall() -> void:
	var arena := _arena()
	var player := arena.player
	_outside_receiver(arena, Vector2(200.0, 424.0))
	player.reset_state(Vector2(248.0, 440.0))
	player.set_control_input(-1.0)
	await wait_physics_frames(4)
	player.set_control_input(0.0)
	player.set_fireball_level(2)
	assert_eq(player.facing_direction, -1.0)
	assert_true(player.request_fireball())
	await wait_physics_frames(45)
	assert_eq(_outside_hits, 0, "Cast origin must not teleport past solid wall")
	assert_eq(_projectile_count(arena), 0, "Wall consumes cast projectile")


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	autofree(arena)
	get_tree().current_scene = arena
	return arena


func _projectile_count(arena: TrainingArena) -> int:
	var count := 0
	for child in arena.get_children():
		if child is Fireball:
			count += 1
	return count


func _outside_receiver(arena: TrainingArena, at: Vector2) -> void:
	var receiver := DamageReceiver.new()
	receiver.healthless_target = true
	receiver.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 50.0)
	collision.shape = shape
	receiver.add_child(collision)
	receiver.hit_received.connect(func(_hit: HitData): _outside_hits += 1)
	arena.add_child(receiver)
