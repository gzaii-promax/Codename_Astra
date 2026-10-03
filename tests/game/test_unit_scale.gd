extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const BASELINE = preload("res://tests/support/design_baseline.gd")

var _original_scene: Node
var _design: Dictionary
var _scale: Dictionary
var _training: Dictionary


func before_all() -> void:
	_design = BASELINE.load_values()
	_scale = _design.get("unit_scale", {})
	_training = _design.get("training", {})
	print("DESIGN_BASELINE_ID=", _design.get("baseline_id", "missing"))


func before_each() -> void:
	assert_eq(_design.get("schema_version"), 1.0, "DESIGN_BASELINE: readable schema")
	assert_eq(_design.get("baseline_id"), "prototype-design-v1")
	_original_scene = get_tree().current_scene
	_release_keys()


func after_each() -> void:
	get_tree().current_scene = _original_scene
	_release_keys()


func test_unit_scale_matches_approved_player_and_dummy_collision_dimensions() -> void:
	var arena := _arena()
	await wait_physics_frames(6)
	var body := _collision_rect(arena.player.get_node("CollisionShape2D") as CollisionShape2D)
	var player_hurt := _collision_rect(
		arena.player.get_node("DamageReceiver/CollisionShape2D") as CollisionShape2D
	)
	var dummy_hurt := _collision_rect(
		arena.dummy.get_node("DamageReceiver/CollisionShape2D") as CollisionShape2D
	)
	for rect in [body, player_hurt, dummy_hurt]:
		assert_eq(rect.size, BASELINE.vector(_scale.body_size_px), "DESIGN_BASELINE: body size")
	# MECHANISM: shape placement is checked against independently observed feet.
	assert_almost_eq(body.end.y, arena.player.global_position.y, 0.01, "Body ends at feet")
	assert_almost_eq(player_hurt.end.y, arena.player.global_position.y, 0.01)
	assert_almost_eq(dummy_hurt.end.y, arena.dummy.global_position.y, 0.01)
	assert_almost_eq(arena.player.global_position.y, _training.jump_origin_px[1], 0.1)
	assert_eq(arena.dummy.global_position, BASELINE.vector(_training.dummy_feet_px))


func test_graybox_geometry_matches_approved_32_by_16_unit_envelope() -> void:
	var arena := _arena()
	var expected: Dictionary = _training.solid_rects_px
	var envelope := Rect2()
	for solid_name in expected:
		var solid := arena.get_node("Geometry/" + solid_name) as StaticBody2D
		assert_eq(solid.collision_layer, 1, "Boundary participates in world physics")
		var collision := solid.get_child(0) as CollisionShape2D
		assert_false(collision.disabled)
		var actual := _collision_rect(collision)
		assert_eq(
			actual, BASELINE.rectangle(expected[solid_name]), "DESIGN_BASELINE: %s" % solid_name
		)
		envelope = actual if not envelope.has_area() else envelope.merge(actual)
	assert_eq(envelope, BASELINE.rectangle(_training.envelope_px), "DESIGN_BASELINE: envelope")
	# MECHANISM: actual body contact must prevent crossing this independent fixture boundary.
	var left_wall := BASELINE.rectangle(expected.LeftWall)
	var half_width: float = _scale.body_size_px[0] * 0.5
	arena.player.reset_state(
		Vector2(left_wall.end.x + half_width + 4.0, _training.jump_origin_px[1])
	)
	arena.player.set_control_input(-1.0)
	var touched_wall := false
	for _frame in 40:
		await get_tree().physics_frame
		touched_wall = touched_wall or arena.player.is_on_wall()
	assert_gte(
		arena.player.global_position.x,
		left_wall.end.x + half_width - 0.1,
		"MECHANISM: no wall crossing"
	)
	assert_true(touched_wall, "Real wall contact occurs during movement")


func test_walk_speed_is_56_pixels_per_second_with_real_displacement() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	player.set_control_input(1.0)
	await wait_physics_frames(20)
	var expected_speed: float = _scale.walk_speed_px_per_second
	assert_almost_eq(player.velocity.x, expected_speed, 0.01, "DESIGN_BASELINE: walk speed")
	var sampled_velocity := player.velocity.x
	assert_gt(sampled_velocity, 0.0, "MECHANISM: right input produces positive velocity")
	var start := player.global_position.x
	var first_frame := Engine.get_physics_frames()
	for _frame in 60:
		await get_tree().physics_frame
	var elapsed_frames := Engine.get_physics_frames() - first_frame
	assert_gt(player.global_position.x, start, "MECHANISM: right input changes world position")
	assert_eq(elapsed_frames, 60, "Exactly 60 engine physics frames are sampled")
	assert_eq(Engine.physics_ticks_per_second, int(_scale.physics_ticks_per_second))
	assert_almost_eq(
		player.global_position.x - start,
		expected_speed,
		0.05,
		"DESIGN_BASELINE: one-second displacement"
	)
	assert_almost_eq(
		player.global_position.x - start,
		sampled_velocity * elapsed_frames / Engine.physics_ticks_per_second,
		0.05,
		"MECHANISM: observed velocity integrates into actual displacement"
	)
	assert_almost_eq(player.velocity.x, sampled_velocity, 0.01)
	player.set_control_input(-1.0)
	await wait_physics_frames(40)
	assert_almost_eq(player.velocity.x, -sampled_velocity, 0.01, "MECHANISM: direction symmetry")
	assert_lt(player.velocity.x, 0.0, "MECHANISM: left input reverses velocity")
	player.set_control_input(0.0)
	await wait_physics_frames(16)
	assert_almost_eq(player.velocity.x, 0.0, 0.01)


func test_short_medium_and_long_holds_produce_16_to_40_pixel_jumps() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var short_height: float = await _measure_override_jump(player, 0)
	var medium_height: float = await _measure_override_jump(player, 9)
	var long_height: float = await _measure_override_jump(player, 72)
	assert_almost_eq(
		short_height, _scale.short_jump_px, _scale.jump_tolerance_px, "DESIGN_BASELINE: short jump"
	)
	assert_almost_eq(
		long_height, _scale.long_jump_px, _scale.jump_tolerance_px, "DESIGN_BASELINE: long jump"
	)
	assert_gt(medium_height, short_height + 1.0, "Holding longer produces an intermediate height")
	assert_lt(medium_height, long_height - 1.0)
	print("UNIT_SCALE_JUMP_HEIGHTS=", [short_height, medium_height, long_height])


func test_physical_key_press_release_drives_variable_height_jump() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var short_height: float = await _measure_keyboard_jump(player, 1)
	var long_height: float = await _measure_keyboard_jump(player, 72)
	assert_almost_eq(
		short_height,
		_scale.short_jump_px,
		_scale.jump_tolerance_px,
		"DESIGN_BASELINE: keyboard short"
	)
	assert_almost_eq(
		long_height, _scale.long_jump_px, _scale.jump_tolerance_px, "DESIGN_BASELINE: keyboard long"
	)
	assert_false(Input.is_action_pressed("jump"))
	print("UNIT_SCALE_KEYBOARD_JUMP_HEIGHTS=", [short_height, long_height])


func test_repress_during_ascent_does_not_restore_long_jump() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var released_height: float = await _measure_override_jump(player, 9)
	var repressed_height: float = await _measure_override_jump(player, 9, true)
	var held_height: float = await _measure_override_jump(player, 72)
	assert_almost_eq(repressed_height, released_height, 0.8, "First release fixes this jump")
	assert_lt(repressed_height, held_height - 1.0, "MECHANISM: repress cannot restore held ascent")


func test_holding_jump_through_landing_does_not_auto_jump_again() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var ground_y := player.global_position.y
	_press_space(true)
	var was_on_floor := true
	var takeoffs := 0
	for _frame in 90:
		await get_tree().physics_frame
		if was_on_floor and not player.is_on_floor():
			takeoffs += 1
		was_on_floor = player.is_on_floor()
	assert_eq(takeoffs, 1, "One press must cause only one jump, including after landing")
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, ground_y, 0.1, "MECHANISM: return to takeoff ground")
	_press_space(false)
	await wait_physics_frames(2)
	_press_space(true)
	for _frame in 3:
		await get_tree().physics_frame
	assert_false(player.is_on_floor(), "A new press after release can start another jump")
	_press_space(false)


func test_training_reset_clears_variable_jump_and_pending_input() -> void:
	var arena := _arena()
	var player := arena.player
	await wait_physics_frames(6)
	var normal_short_height: float = await _measure_override_jump(player, 0)
	var ground_y := player.global_position.y
	player.set_control_input(0.0, true, true)
	for _frame in 3:
		await get_tree().physics_frame
	assert_false(player.is_on_floor())
	player.set_control_input(0.0, true, true)
	arena.reset_training()
	player.set_control_input(0.0, false, true)
	await wait_physics_frames(6)
	assert_true(player.is_on_floor(), "Reset clears pending request and previous held-jump state")
	assert_almost_eq(player.global_position.y, ground_y, 0.1)
	assert_almost_eq(player.velocity.y, 0.0, 0.01)
	var height: float = await _measure_override_jump(player, 0)
	assert_almost_eq(height, normal_short_height, 0.8, "MECHANISM: reset clears jump state")


func test_death_and_knockdown_recovery_clear_variable_jump_state() -> void:
	var arena := _arena()
	var player := arena.player
	var health := player.get_combatant()
	var normal_short_height: float = await _measure_override_jump(player, 0)
	var ground_y := player.global_position.y
	for downed in [false, true]:
		arena.reset_training()
		await wait_physics_frames(6)
		player.set_control_input(0.0, true, true)
		for _frame in 3:
			await get_tree().physics_frame
		assert_false(player.is_on_floor())
		if downed:
			health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
			var hit := HitData.new()
			hit.set_source(arena.enemy)
			hit.damage = 3.0
			assert_true((player.get_node("DamageReceiver") as DamageReceiver).receive_hit(hit))
			assert_eq(health.life_state, Combatant.LifeState.DOWNED)
		else:
			health.force_death()
			assert_eq(health.life_state, Combatant.LifeState.DEAD)
		player.set_control_input(0.0, true, true)
		await wait_physics_frames(60)
		assert_true(player.is_on_floor(), "Inactive unit still falls to real ground")
		if downed:
			assert_true(health.recover(1.5))
			assert_eq(health.current_health, 1.5)
		else:
			health.reset_state()
		player.set_control_input(0.0, false, true)
		await wait_physics_frames(6)
		assert_true(player.is_on_floor(), "Recovery cannot replay a request made while inactive")
		assert_almost_eq(player.global_position.y, ground_y, 0.1)
		var height: float = await _measure_override_jump(player, 0)
		assert_almost_eq(height, normal_short_height, 0.8, "MECHANISM: recovery clears jump state")


func test_coyote_jump_succeeds_just_after_walking_off_a_real_platform() -> void:
	var arena := _arena()
	var player := arena.player
	var ledge_y: float = await _walk_off_platform(arena)
	assert_false(player.is_on_floor())
	player.set_control_input(1.0, true, true)
	for _frame in 3:
		await get_tree().physics_frame
	assert_lt(player.velocity.y, 0.0, "A request just after leaving the ledge still jumps")
	assert_lt(player.global_position.y, ledge_y, "Real body rises above the departed platform")


func test_coyote_jump_expires_after_the_documented_point_one_seconds() -> void:
	var arena := _arena()
	var player := arena.player
	var ledge_y: float = await _walk_off_platform(arena)
	await wait_physics_frames(8)
	assert_false(player.is_on_floor())
	player.set_control_input(1.0, true, true)
	await wait_physics_frames(2)
	assert_gt(player.velocity.y, 0.0, "More than 0.1 seconds off the ledge cannot start a jump")
	assert_gt(player.global_position.y, ledge_y, "Expired request does not reverse real falling")


func test_released_short_jump_buffer_fires_on_landing_at_one_unit_height() -> void:
	var player := _arena().player
	var normal_short_height: float = await _measure_override_jump(player, 0)
	var ground_y := player.global_position.y
	var falling_origin := BASELINE.vector(_training.jump_origin_px) - Vector2(0.0, 20.0)
	player.reset_state(falling_origin)
	player.set_control_input(0.0)
	for _frame in 30:
		await get_tree().physics_frame
		if player.global_position.y > ground_y - 4.0:
			break
	assert_false(player.is_on_floor(), "Request is made while falling, before landing")
	assert_gt(player.global_position.y, ground_y - 4.0)
	player.set_control_input(0.0, true, false)
	var minimum_y := player.global_position.y
	var saw_floor := false
	var saw_buffered_ascent := false
	for _frame in 72:
		await get_tree().physics_frame
		minimum_y = minf(minimum_y, player.global_position.y)
		saw_floor = saw_floor or player.is_on_floor()
		if saw_floor and player.velocity.y < 0.0:
			saw_buffered_ascent = true
		if saw_buffered_ascent and player.is_on_floor():
			break
	assert_true(saw_buffered_ascent, "Landing consumes the pending released jump request")
	assert_almost_eq(
		ground_y - minimum_y, normal_short_height, 0.8, "MECHANISM: buffer retains released press"
	)
	assert_true(player.is_on_floor())


func test_real_ceiling_collision_stops_a_held_jump_and_returns_to_ground() -> void:
	var arena := _arena()
	var player := arena.player
	# Controlled obstacle fixture: independently positioned 8 px above the accepted body.
	var origin := BASELINE.vector(_training.jump_origin_px)
	var body_size := BASELINE.vector(_scale.body_size_px)
	var ceiling := Rect2(origin.x - 16.0, origin.y - body_size.y - 16.0, 32.0, 8.0)
	arena.add_child(GrayboxSolid.create(ceiling, Color.WHITE, "TestCeiling"))
	await wait_physics_frames(6)
	var takeoff_y := player.global_position.y
	var minimum_y := takeoff_y
	var hit_ceiling := false
	player.set_control_input(0.0, true, true)
	for _frame in 60:
		await get_tree().physics_frame
		minimum_y = minf(minimum_y, player.global_position.y)
		hit_ceiling = hit_ceiling or player.is_on_ceiling()
		if hit_ceiling and player.is_on_floor():
			break
	assert_true(hit_ceiling, "Actual StaticBody2D blocks the rising CharacterBody2D")
	assert_gt(takeoff_y - minimum_y, 0.0)
	assert_lte(takeoff_y - minimum_y, 8.2, "32 px body has only 8 px overhead clearance")
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, takeoff_y, 0.1)


func test_release_and_repress_between_physics_samples_still_cuts_the_current_jump() -> void:
	var player := _arena().player
	var normal_short_height: float = await _measure_override_jump(player, 0)
	for use_keyboard in [false, true]:
		var height: float = await _measure_same_frame_repress(player, use_keyboard)
		assert_almost_eq(
			height,
			normal_short_height,
			0.8,
			"Release is retained even when held again before physics: keyboard=%s" % use_keyboard
		)


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	autofree(arena)
	get_tree().current_scene = arena
	arena.enemy.attack_enabled = false
	return arena


func _collision_rect(collision: CollisionShape2D) -> Rect2:
	var shape := collision.shape as RectangleShape2D
	return collision.global_transform * Rect2(-shape.size * 0.5, shape.size)


func _measure_override_jump(player: PlayerCharacter, held_frames: int, repress := false) -> float:
	player.reset_state(BASELINE.vector(_training.jump_origin_px))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	var takeoff_y := player.global_position.y
	var minimum_y := takeoff_y
	player.set_control_input(0.0, true, held_frames > 0)
	for frame in 72:
		await get_tree().physics_frame
		minimum_y = minf(minimum_y, player.global_position.y)
		if frame + 1 == held_frames:
			player.set_control_input(0.0, false, false)
		if repress and frame + 1 == held_frames + 1:
			player.set_control_input(0.0, false, true)
		if frame > 2 and player.is_on_floor():
			break
	assert_true(player.is_on_floor(), "Sampled jump returns to real floor")
	return takeoff_y - minimum_y


func _measure_keyboard_jump(player: PlayerCharacter, held_frames: int) -> float:
	player.reset_state(BASELINE.vector(_training.jump_origin_px))
	player.clear_control_override()
	await wait_physics_frames(6)
	var takeoff_y := player.global_position.y
	var minimum_y := takeoff_y
	_press_space(true)
	assert_true(Input.is_action_pressed("jump"), "Physical Space maps to jump action")
	var press_frame := Engine.get_physics_frames()
	for frame in 72:
		await get_tree().physics_frame
		minimum_y = minf(minimum_y, player.global_position.y)
		if frame + 1 == held_frames:
			assert_eq(Engine.get_physics_frames() - press_frame, held_frames)
			_press_space(false)
		if frame > 2 and player.is_on_floor():
			break
	_press_space(false)
	assert_true(player.is_on_floor(), "Physical-key jump returns to real floor")
	return takeoff_y - minimum_y


func _press_space(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _walk_off_platform(arena: TrainingArena) -> float:
	var player := arena.player
	# Fixture offsets are test setup, not production map layout expectations.
	var origin := BASELINE.vector(_training.jump_origin_px)
	var ledge := Rect2(origin.x - 16.0, origin.y - 80.0, 32.0, 8.0)
	arena.add_child(GrayboxSolid.create(ledge, Color.WHITE, "TestLedge"))
	player.reset_state(Vector2(ledge.end.x, ledge.position.y))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.is_on_floor(), "Real ledge supports the body before walking off")
	player.set_control_input(1.0)
	for _frame in 60:
		await get_tree().physics_frame
		if not player.is_on_floor():
			break
	assert_false(player.is_on_floor(), "Body walked past the real ledge edge")
	return ledge.position.y


func _measure_same_frame_repress(player: PlayerCharacter, use_keyboard: bool) -> float:
	_press_space(false)
	player.reset_state(BASELINE.vector(_training.jump_origin_px))
	player.set_control_input(0.0)
	if use_keyboard:
		player.clear_control_override()
	await wait_physics_frames(6)
	var takeoff_y := player.global_position.y
	if use_keyboard:
		_press_space(true)
	else:
		player.set_control_input(0.0, true, true)
	for _frame in 3:
		await get_tree().physics_frame
	var minimum_y := player.global_position.y
	assert_false(player.is_on_floor())
	if use_keyboard:
		_press_space(false)
		_press_space(true)
	else:
		player.set_control_input(0.0, false, false)
		player.set_control_input(0.0, false, true)
	for _frame in 72:
		await get_tree().physics_frame
		minimum_y = minf(minimum_y, player.global_position.y)
		if player.is_on_floor():
			break
	_press_space(false)
	assert_true(player.is_on_floor())
	return takeoff_y - minimum_y


func _release_keys() -> void:
	_press_space(false)
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball"]:
		if InputMap.has_action(action):
			Input.action_release(action)
