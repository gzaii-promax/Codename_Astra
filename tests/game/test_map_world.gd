# gdlint: disable=max-public-methods
extends GutTest
## Independent room graph and real engine acceptance for the approved three-room sample.

const WORLD: PackedScene = preload("res://world/map_world.tscn")
const SAMPLE: MapRegistry = preload("res://world/maps/sample_world.tres")
const LOCALES := ["en", "ja", "zh_CN"]

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
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball", "ui_cancel"]:
		Input.action_release(action)
	# Observe queued room/effect deletion before GUT measures orphan nodes.
	await wait_physics_frames(2)
	get_tree().current_scene = _original_scene
	Localization.set_language(_original_language, false)
	process_mode = _original_process_mode


func test_map_sample_registry_matches_three_rooms_and_five_directed_routes() -> void:
	assert_eq(SAMPLE.rooms.size(), 3)
	assert_eq(SAMPLE.connections.size(), 5)
	assert_eq(SAMPLE.initial_room_id, &"room_a")
	assert_eq(SAMPLE.initial_entrance_id, &"start")
	assert_eq(SAMPLE.validate(), PackedStringArray())
	for route in [
		[&"room_a", &"east", &"room_b", &"west"],
		[&"room_b", &"west", &"room_a", &"east"],
		[&"room_b", &"east", &"room_c", &"west"],
		[&"room_c", &"west", &"room_b", &"east"],
		[&"room_c", &"return", &"room_a", &"start"],
	]:
		var connection := SAMPLE.get_connection(route[0], route[1])
		assert_not_null(connection)
		if connection != null:
			assert_eq(connection.to_room_id, route[2])
			assert_eq(connection.entrance_id, route[3])
	assert_null(SAMPLE.get_connection(&"room_a", &"return"), "C to A has no implicit reverse")
	assert_null(SAMPLE.get_connection(&"missing", &"east"))


func test_map_shared_corridor_template_keeps_room_identity_and_visits_independent() -> void:
	assert_eq(SAMPLE.get_room(&"room_a").scene, SAMPLE.get_room(&"room_c").scene)
	assert_ne(SAMPLE.get_room(&"room_a").room_id, SAMPLE.get_room(&"room_c").room_id)
	var world := _world()
	await wait_physics_frames(6)
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.get_visited_rooms(), [&"room_a"])
	assert_false(world.has_visited(&"room_c"))
	assert_true(world.enter_room(&"room_c", &"west"))
	assert_eq(world.current_room_id, &"room_c")
	assert_true(world.has_visited(&"room_a"))
	assert_true(world.has_visited(&"room_c"))
	assert_false(world.has_visited(&"room_b"))
	assert_true(world.enter_room(&"room_c", &"east"))
	assert_eq(world.get_visited_rooms().size(), 2, "Re-entry cannot duplicate visited identity")
	assert_eq(SAMPLE.get_room(&"room_a").room_id, &"room_a", "Runtime does not rewrite template")


func test_map_prepare_keeps_target_off_tree_disabled_without_activating_or_marking_visit() -> void:
	var world := _world()
	var live_room := world.current_room
	var live_position := world.player.global_position
	var prepared := world.prepare_room(&"room_b")
	assert_not_null(prepared)
	if prepared == null:
		return
	assert_false(prepared.is_inside_tree(), "Prepared content cannot start physics or enemies")
	assert_eq(prepared.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(world.current_room, live_room)
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.player.global_position, live_position)
	assert_false(world.has_visited(&"room_b"))
	prepared.free()


func test_map_room_sample_geometry_has_ground_and_approved_bounds() -> void:
	var world := _world()
	for room_id in [&"room_a", &"room_b", &"room_c"]:
		assert_true(world.enter_room(room_id, &"west"))
		await wait_physics_frames(6)
		var width := 768.0 if room_id == &"room_b" else 512.0
		assert_eq(world.current_room.bounds, Rect2(0.0, 0.0, width, 256.0))
		assert_true(world.player.is_on_floor(), "Actual collision ground in %s" % room_id)
		assert_almost_eq(world.player.global_position.y, 240.0, 0.1)
		assert_almost_eq(world.player.global_position.x, 80.0, 0.1)
		assert_eq(world.current_room.validate_room(), PackedStringArray())
		world.player.set_control_input(0.0, true, true)
		await wait_physics_frames(8)
		assert_lt(world.player.global_position.y, 220.0, "Existing jump works on room collision")
		world.player.set_control_input(0.0, false, false)
		await wait_physics_frames(55)
		assert_true(world.player.is_on_floor())


func test_map_player_jumps_onto_and_crosses_actual_corridor_and_hall_steps() -> void:
	var world := _world()
	for room_id in [&"room_a", &"room_b"]:
		assert_true(world.enter_room(room_id, &"west"))
		var step_left := 192.0 if room_id == &"room_b" else 160.0
		world.player.relocate_to(Vector2(step_left - 16.0, 240.0), 1.0)
		world.player.set_control_input(0.0)
		await wait_physics_frames(6)
		assert_true(world.player.is_on_floor())
		world.player.set_control_input(1.0, true, true)
		for _frame in 60:
			await get_tree().physics_frame
			if world.player.global_position.x >= step_left:
				world.player.set_control_input(0.0, false, true)
		assert_true(world.player.is_on_floor(), "Jump lands on actual step in %s" % room_id)
		assert_almost_eq(world.player.global_position.y, 224.0, 0.1)
		assert_gte(world.player.global_position.x, step_left)
		world.player.set_control_input(1.0, false, false)
		await wait_physics_frames(70)
		assert_gt(world.player.global_position.x, step_left + 24.0, "Player crosses the step")
		assert_almost_eq(world.player.global_position.y, 240.0, 0.1)
		assert_true(world.player.is_on_floor(), "Player returns to the ground past the step")
		world.player.set_control_input(0.0)


func test_map_entering_each_entrance_is_safe_and_does_not_bounce_back() -> void:
	var world := _world()
	for room_id in [&"room_a", &"room_b", &"room_c"]:
		for entrance_id in [&"start", &"west", &"east"]:
			assert_true(world.enter_room(room_id, entrance_id))
			var width := 768.0 if room_id == &"room_b" else 512.0
			var expected_x := width - 80.0 if entrance_id == &"east" else 80.0
			assert_almost_eq(world.player.global_position.x, expected_x, 0.1)
			await wait_physics_frames(12)
			assert_eq(world.current_room_id, room_id, "Safe entry does not trigger an exit")
			assert_almost_eq(world.player.global_position.x, expected_x, 0.1)


func test_map_travel_uses_explicit_reverse_routes_and_single_return_route() -> void:
	var world := _world()
	assert_true(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_b")
	assert_almost_eq(world.player.global_position.x, 80.0, 0.1)
	assert_true(world.travel(&"west"))
	assert_eq(world.current_room_id, &"room_a")
	assert_almost_eq(world.player.global_position.x, 432.0, 0.1)
	assert_true(world.travel(&"east"))
	assert_true(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_c")
	assert_true(world.travel(&"return"))
	assert_eq(world.current_room_id, &"room_a")
	assert_almost_eq(world.player.global_position.x, 80.0, 0.1)
	assert_false(world.travel(&"return"), "No generated A to C reverse connection")
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.get_visited_rooms().size(), 3)


func test_map_actual_exit_area_and_mapped_input_drive_bidirectional_room_travel() -> void:
	var world := _world()
	await wait_physics_frames(6)
	assert_true(world.current_room.get_exit(&"east") is Area2D)
	world.player.relocate_to(Vector2(454.0, 240.0), 1.0)
	world.player.clear_control_override()
	Input.action_press("move_right")
	await _wait_for_room(world, &"room_b", 100)
	Input.action_release("move_right")
	assert_eq(world.current_room_id, &"room_b", "Real Area2D/body and mapped input trigger travel")
	await wait_physics_frames(10)
	assert_eq(world.current_room_id, &"room_b", "Entry does not immediately retrigger west exit")
	world.player.relocate_to(Vector2(58.0, 240.0), -1.0)
	Input.action_press("move_left")
	await _wait_for_room(world, &"room_a", 100)
	Input.action_release("move_left")
	assert_eq(world.current_room_id, &"room_a")
	await wait_physics_frames(10)
	assert_eq(world.current_room_id, &"room_a")


func test_map_invalid_room_entrance_and_exit_leave_live_world_unchanged() -> void:
	var world := _world()
	await wait_physics_frames(6)
	var live_room := world.current_room
	var live_player := world.player
	var live_position := world.player.global_position
	var visits := world.get_visited_rooms()
	for invalid in [[&"missing", &"start"], [&"room_b", &"missing"]]:
		assert_false(world.enter_room(invalid[0], invalid[1]))
		assert_eq(world.current_room, live_room)
		assert_eq(world.player, live_player)
		assert_eq(world.current_room_id, &"room_a")
		assert_eq(world.player.global_position, live_position)
		assert_eq(world.get_visited_rooms(), visits)
		assert_false(world.last_error.is_empty(), "Failure provides readable diagnostic")
	assert_false(world.travel(&"missing"))
	assert_eq(world.current_room, live_room)
	assert_eq(world.player.global_position, live_position)


func test_map_missing_or_wrong_scene_resource_fails_before_replacing_live_room() -> void:
	var world := _world()
	await wait_physics_frames(6)
	world.registry = SAMPLE.duplicate(true) as MapRegistry
	var definition := world.registry.get_room(&"room_b")
	var old_room := world.current_room
	var old_position := world.player.global_position
	definition.scene = null
	assert_false(world.enter_room(&"room_b", &"west"))
	assert_eq(world.current_room, old_room)
	assert_eq(world.player.global_position, old_position)
	var invalid_root := Node2D.new()
	var wrong_scene := PackedScene.new()
	assert_eq(wrong_scene.pack(invalid_root), OK)
	invalid_root.free()
	definition.scene = wrong_scene
	assert_false(world.enter_room(&"room_b", &"west"))
	assert_eq(world.current_room, old_room)
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.player.global_position, old_position)
	assert_false(world.has_visited(&"room_b"))


func test_map_bad_connection_target_entrance_fails_without_mutating_source() -> void:
	var world := _world()
	world.registry = SAMPLE.duplicate(true) as MapRegistry
	var connection := world.registry.get_connection(&"room_a", &"east")
	connection.entrance_id = &"missing"
	var old_room := world.current_room
	var old_position := world.player.global_position
	assert_false(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.current_room, old_room)
	assert_eq(world.player.global_position, old_position)
	assert_eq(world.get_visited_rooms(), [&"room_a"])


func test_map_queued_old_exit_cannot_travel_after_reset_to_same_room_identity() -> void:
	var world := _world()
	await wait_physics_frames(6)
	var old_room := world.current_room
	old_room.get_exit(&"east").exit_requested.emit(&"east")
	world.reset_world()
	assert_ne(world.current_room, old_room, "Reset creates another instance of room A")
	await wait_frames(3)
	assert_eq(world.current_room_id, &"room_a", "Old queued event cannot target replacement A")
	assert_almost_eq(world.player.global_position.x, 80.0, 0.1)
	assert_almost_eq(world.player.global_position.y, 240.0, 0.1)
	assert_eq(world.get_visited_rooms(), [&"room_a"])


func test_map_registry_rejects_duplicate_identity_routes_and_unknown_targets() -> void:
	var registry := SAMPLE.duplicate(true) as MapRegistry
	registry.rooms.append(registry.rooms[0])
	assert_false(registry.validate().is_empty(), "Duplicate room identity")
	registry = SAMPLE.duplicate(true) as MapRegistry
	registry.connections.append(registry.connections[0])
	assert_false(registry.validate().is_empty(), "Duplicate source room and exit is ambiguous")
	registry = SAMPLE.duplicate(true) as MapRegistry
	registry.connections[0].to_room_id = &"missing"
	assert_false(registry.validate().is_empty(), "Unknown target room")
	registry = SAMPLE.duplicate(true) as MapRegistry
	registry.initial_room_id = &"missing"
	assert_false(registry.validate().is_empty(), "Unknown initial room")


func test_map_transition_preserves_player_identity_health_level_cooldown_and_protection() -> void:
	var world := _world()
	await wait_physics_frames(6)
	var player := world.player
	player.set_fireball_level(2)
	assert_true(player.request_fireball())
	var hit := HitData.new()
	hit.damage = 0.5
	assert_true(player.get_combatant().apply_damage(hit, 0.5))
	var actions := player.get_action_controller()
	var cooldown := actions.get_cooldown_remaining(&"fireball")
	var protection := player.get_combatant().get_hit_protection_remaining()
	assert_gt(cooldown, 0.0)
	assert_gt(protection, 0.0)
	assert_true(world.travel(&"east"))
	assert_eq(world.player, player, "One persistent player instance")
	assert_eq(player.get_combatant().current_health, 2.5)
	assert_eq(player.fireball_level, 2)
	assert_eq(actions.get_cooldown_remaining(&"fireball"), cooldown)
	assert_eq(player.get_combatant().get_hit_protection_remaining(), protection)
	assert_eq(actions.phase, ActionController.Phase.IDLE)
	assert_false(player.request_fireball(), "Crossing cannot bypass skill cooldown")
	await wait_physics_frames(8)
	assert_lt(actions.get_cooldown_remaining(&"fireball"), cooldown)
	assert_lt(player.get_combatant().get_hit_protection_remaining(), protection)


func test_map_transition_clears_velocity_jump_buffer_action_and_old_effects() -> void:
	var world := _world()
	await wait_physics_frames(6)
	var player := world.player
	player.set_control_input(1.0, true, true)
	await wait_physics_frames(2)
	assert_lt(player.velocity.y, 0.0)
	assert_true(player.request_fireball())
	SkillExecutors.fireball(player, player.get_action_controller().get_definition(&"fireball"))
	SkillExecutors.melee(player, player.get_action_controller().get_definition(&"basic_attack"))
	var effects: Array[Node] = []
	for child in world.get_children():
		if child is Fireball or child is MeleeStrike:
			effects.append(child)
	assert_eq(effects.size(), 2)
	assert_true(world.travel(&"east"))
	assert_eq(player.velocity, Vector2.ZERO)
	assert_eq(player.get_action_controller().phase, ActionController.Phase.IDLE)
	for effect in effects:
		assert_false(effect.is_physics_processing(), "Removed effects stop immediately")
		assert_true(effect.is_queued_for_deletion())
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_almost_eq(player.global_position.y, 240.0, 0.1, "No buffered jump at destination")
	assert_true(player.is_on_floor())
	assert_eq(_effect_count(world), 0)


func test_map_pause_and_inactive_player_cannot_travel() -> void:
	var world := _world()
	await wait_physics_frames(6)
	get_tree().paused = true
	assert_false(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_a")
	get_tree().paused = false
	world.player.get_combatant().force_death()
	assert_false(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.player.get_combatant().life_state, Combatant.LifeState.DEAD)
	world.reset_world()
	var combatant := world.player.get_combatant()
	combatant.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	var hit := HitData.new()
	hit.damage = 3.0
	assert_true(combatant.apply_damage(hit, 3.0))
	assert_eq(combatant.life_state, Combatant.LifeState.DOWNED)
	assert_false(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_a")


func test_map_world_reset_restores_start_and_health_and_clears_session_visits() -> void:
	var world := _world()
	assert_true(world.travel(&"east"))
	assert_true(world.travel(&"east"))
	var player := world.player
	player.set_fireball_level(2)
	assert_true(player.request_fireball())
	player.get_combatant().force_death()
	assert_eq(world.get_visited_rooms().size(), 3)
	world.reset_world()
	assert_eq(world.player, player)
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.get_visited_rooms(), [&"room_a"])
	assert_eq(player.get_combatant().current_health, 3.0)
	assert_eq(player.get_combatant().life_state, Combatant.LifeState.ACTIVE)
	assert_eq(player.get_combatant().get_hit_protection_remaining(), 0.0)
	assert_eq(player.get_action_controller().get_cooldown_remaining(&"fireball"), 0.0)
	assert_eq(player.get_action_controller().phase, ActionController.Phase.IDLE)
	assert_almost_eq(player.global_position.x, 80.0, 0.1)
	assert_almost_eq(player.global_position.y, 240.0, 0.1)


func test_map_camera_matches_zoom_and_clamps_actual_view_to_room_bounds() -> void:
	var world := _world()
	assert_eq(world.camera.zoom, Vector2(2.0, 2.0))
	for target in [[&"room_a", &"west"], [&"room_b", &"east"], [&"room_c", &"east"]]:
		assert_true(world.enter_room(target[0], target[1]))
		await wait_physics_frames(6)
		var bounds := world.current_room.bounds
		var viewport_size := world.get_viewport_rect().size
		var map_screen := Rect2(0.0, 160.0, viewport_size.x, viewport_size.y - 160.0)
		var visible_map := world.get_viewport().get_canvas_transform().affine_inverse() * map_screen
		if bounds.size.x >= visible_map.size.x:
			assert_gte(visible_map.position.x, bounds.position.x - 0.1)
			assert_lte(visible_map.end.x, bounds.end.x + 0.1)
		else:
			assert_almost_eq(visible_map.get_center().x, bounds.get_center().x, 0.1)
		if bounds.size.y >= visible_map.size.y:
			assert_gte(visible_map.position.y, bounds.position.y - 0.1)
			assert_lte(visible_map.end.y, bounds.end.y + 0.1)
		else:
			assert_almost_eq(visible_map.get_center().y, bounds.get_center().y, 0.1)


func test_map_capability_gate_has_one_query_without_implementing_climbing() -> void:
	var world := _world()
	world.registry = SAMPLE.duplicate(true) as MapRegistry
	var route := world.registry.get_connection(&"room_a", &"east")
	assert_true(world.can_travel(route), "Default empty requirement permits passage")
	assert_false(world.has_capability(&"climb"), "First version does not grant climbing")
	route.required_capability = &"climb"
	assert_false(world.can_travel(route))
	assert_false(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_a")
	route.required_capability = &""
	assert_true(world.travel(&"east"))
	assert_eq(world.current_room_id, &"room_b")


func test_map_f6_overlay_tracks_real_collision_geometry_and_active_room_routes() -> void:
	var world := _world()
	await wait_physics_frames(6)
	var overlay := world.get_node("CollisionDebug") as MapCollisionOverlay
	assert_not_null(overlay)
	if overlay == null:
		return
	assert_false(overlay.visible)
	_send_physical_key(KEY_F6, true)
	_send_physical_key(KEY_F6, false)
	await wait_physics_frames(3)
	assert_true(overlay.visible, "Actual F6 event enables debug drawing")
	var polygons := overlay.collect_debug_polygons()
	assert_true(_has_polygon_rect(polygons, Rect2(0.0, 240.0, 16.0, 16.0)))
	assert_true(_has_polygon_rect(polygons, Rect2(72.0, 208.0, 16.0, 32.0)))
	assert_true(_has_polygon_rect(polygons, Rect2(472.0, 192.0, 16.0, 48.0)))
	assert_false(_has_polygon_rect(polygons, Rect2(24.0, 192.0, 16.0, 48.0)), "A west has no route")
	assert_false(
		_has_polygon_rect(polygons, Rect2(248.0, 192.0, 16.0, 48.0)), "A return has no route"
	)
	world.player.relocate_to(Vector2(120.0, 240.0), 1.0)
	await wait_physics_frames(3)
	polygons = overlay.collect_debug_polygons()
	assert_true(_has_polygon_rect(polygons, Rect2(112.0, 208.0, 16.0, 32.0)))
	assert_false(_has_polygon_rect(polygons, Rect2(72.0, 208.0, 16.0, 32.0)))
	assert_true(world.enter_room(&"room_b", &"east"))
	await wait_physics_frames(6)
	assert_true(overlay.visible, "Debug mode stays enabled while room content changes")
	polygons = overlay.collect_debug_polygons()
	assert_true(_has_polygon_rect(polygons, Rect2(752.0, 240.0, 16.0, 16.0)))
	assert_true(_has_polygon_rect(polygons, Rect2(680.0, 208.0, 16.0, 32.0)))
	assert_true(_has_polygon_rect(polygons, Rect2(24.0, 192.0, 16.0, 48.0)))
	assert_true(_has_polygon_rect(polygons, Rect2(728.0, 192.0, 16.0, 48.0)))
	assert_false(_has_polygon_rect(polygons, Rect2(472.0, 192.0, 16.0, 48.0)))
	_send_physical_key(KEY_F6, true)
	_send_physical_key(KEY_F6, false)
	await wait_physics_frames(3)
	assert_false(overlay.visible, "Second actual F6 event disables debug drawing")


func test_map_hud_and_menu_localize_rooms_visits_and_fit_three_languages() -> void:
	var world := _world()
	var hud := world.get_node("HUD") as TrainingHUD
	await wait_frames(4)
	for locale in LOCALES:
		assert_true(Localization.set_language(locale, false))
		for room_id in [&"room_a", &"room_b", &"room_c"]:
			assert_true(world.enter_room(room_id, &"west"))
			await wait_frames(4)
			var title := hud.get_ui_control("AppTitle") as Label
			assert_eq(title.text, Localization.text("map.title"))
			var status := hud.get_ui_control("TargetStats") as Label
			assert_true(status.text.contains(Localization.text("map." + String(room_id))))
			assert_eq(
				status.text,
				(
					Localization
					. text(
						"map.target",
						{
							"room": Localization.text("map." + String(room_id)),
							"visited": world.get_visited_rooms().size(),
							"total": 3,
						}
					)
				)
			)
			assert_false(status.text.contains("{"), "Room and exploration arguments are resolved")
			assert_eq(
				status.get_theme_font("font").resource_path, Localization.get_font().resource_path
			)
			_assert_control_inside(
				hud.get_ui_control("HudPanel"), get_viewport().get_visible_rect(), locale
			)
			assert_lte(
				hud.get_ui_control("HudPanel").get_global_rect().end.y,
				160.0,
				"HUD remains inside the 160 px space reserved by camera (%s)" % locale
			)
			_assert_label_fits(status, locale)
		assert_eq(world.get_visited_rooms().size(), 3)
		hud.open_menu()
		await wait_frames(4)
		assert_true(get_tree().paused)
		assert_false(world.travel(&"west"), "Pause menu also blocks scripted travel")
		assert_eq(
			(hud.get_ui_control("WorldModeButton") as Button).text,
			Localization.text("map.enter_training")
		)
		assert_eq(
			(hud.get_ui_control("ResetButton") as Button).text, Localization.text("map.reset")
		)
		_assert_control_inside(
			hud.get_ui_control("MenuPanel"), get_viewport().get_visible_rect(), locale
		)
		for name in ["WorldModeButton", "ResetButton", "ResumeButton", "LanguagePicker"]:
			_assert_control_inside(
				hud.get_ui_control(name), hud.get_ui_control("MenuPanel").get_global_rect(), locale
			)
		hud.open_help()
		await wait_frames(4)
		var manual := hud.get_ui_control("HelpText") as Label
		for section in ["movement", "combat", "navigation", "debug", "languages"]:
			assert_true(manual.text.contains(Localization.text("map.manual." + section)))
		_assert_control_inside(
			hud.get_ui_control("HelpPanel"), get_viewport().get_visible_rect(), locale
		)
		_assert_label_fits(manual, locale)
		hud.get_ui_control("HelpCloseButton").emit_signal("pressed")
		hud.get_ui_control("ResumeButton").emit_signal("pressed")
		assert_false(get_tree().paused)
		assert_false(hud.is_menu_open())
	assert_true(world.enter_room(&"room_c", &"west"))
	hud.open_menu()
	hud.get_ui_control("ResetButton").emit_signal("pressed")
	assert_eq(world.current_room_id, &"room_a")
	assert_eq(world.get_visited_rooms(), [&"room_a"])
	assert_false(get_tree().paused)
	assert_false(hud.is_menu_open())


func test_map_menu_switches_to_retained_training_scene_and_back() -> void:
	var world := _world()
	var hud := world.get_node("HUD") as TrainingHUD
	hud.open_menu()
	hud.get_ui_control("WorldModeButton").emit_signal("pressed")
	await wait_frames(6)
	var training := get_tree().current_scene as TrainingArena
	assert_not_null(training, "Existing combat training remains accessible")
	assert_false(get_tree().paused)
	if training == null:
		return
	training.enemy.attack_enabled = false
	var training_hud := training.get_node("HUD") as TrainingHUD
	training_hud.open_menu()
	training_hud.get_ui_control("WorldModeButton").emit_signal("pressed")
	await wait_frames(6)
	var returned := get_tree().current_scene as MapWorld
	assert_not_null(returned)
	assert_false(get_tree().paused)
	if returned != null:
		autofree(returned)
		assert_eq(returned.current_room_id, &"room_a")


func _world() -> MapWorld:
	var world := WORLD.instantiate() as MapWorld
	get_tree().root.add_child(world)
	autofree(world)
	get_tree().current_scene = world
	return world


func _wait_for_room(world: MapWorld, room_id: StringName, maximum_frames: int) -> void:
	for _frame in range(maximum_frames):
		await wait_physics_frames(1)
		if world.current_room_id == room_id:
			return


func _effect_count(world: MapWorld) -> int:
	var total := 0
	for child in world.get_children():
		if child is Fireball or child is MeleeStrike:
			total += 1
	return total


func _send_physical_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	get_viewport().push_input(event)


func _has_polygon_rect(polygons: Array[PackedVector2Array], expected: Rect2) -> bool:
	for polygon in polygons:
		if polygon.is_empty():
			continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		if bounds.is_equal_approx(expected):
			return true
	return false


func _assert_control_inside(control: Control, bounds: Rect2, locale: String) -> void:
	var actual := control.get_global_rect()
	assert_gte(actual.position.x, bounds.position.x - 1.0, "%s left (%s)" % [control.name, locale])
	assert_gte(actual.position.y, bounds.position.y - 1.0, "%s top (%s)" % [control.name, locale])
	assert_lte(actual.end.x, bounds.end.x + 1.0, "%s right (%s)" % [control.name, locale])
	assert_lte(actual.end.y, bounds.end.y + 1.0, "%s bottom (%s)" % [control.name, locale])


func _assert_label_fits(label: Label, locale: String) -> void:
	var measured := label.get_theme_font("font").get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		label.size.x,
		label.get_theme_font_size("font_size"),
		-1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	assert_lte(measured.x, label.size.x + 1.0, "%s rendered width (%s)" % [label.name, locale])
	assert_lte(measured.y, label.size.y + 1.0, "%s rendered height (%s)" % [label.name, locale])
