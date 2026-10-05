extends GutTest
## Saved world configuration must drive runtime placement, collision and debug commands.

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const WORLD: PackedScene = preload("res://world/map_world.tscn")

var _original_scene: Node
var _files: Array[String] = []


func before_each() -> void:
	_original_scene = get_tree().current_scene
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	Input.action_release("toggle_fireball_level")
	await wait_physics_frames(2)
	get_tree().current_scene = _original_scene
	for path in _files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_files.clear()


func test_training_scene_contains_saved_geometry_and_spawn_markers_before_tree_entry() -> void:
	var arena := autofree(ARENA.instantiate()) as TrainingArena
	assert_not_null(arena.get_node_or_null("Geometry/Floor"), "MECHANISM: editable floor is saved")
	for actor in ["Player", "TrainingDummy", "PeriodicEnemy"]:
		assert_true(
			arena.get_node_or_null("Spawns/" + actor) is Marker2D,
			"MECHANISM: editable spawn marker is saved for %s" % actor
		)


func test_saved_training_spawns_and_floor_drive_start_physics_and_reset() -> void:
	var source := ARENA.instantiate() as TrainingArena
	var spawns := source.get_node_or_null("Spawns")
	if spawns == null:
		spawns = Node2D.new()
		spawns.name = "Spawns"
		source.add_child(spawns)
		spawns.owner = source
	for entry in [["Player", 300.0], ["TrainingDummy", 560.0], ["PeriodicEnemy", 640.0]]:
		var marker := spawns.get_node_or_null(entry[0]) as Marker2D
		if marker == null:
			marker = Marker2D.new()
			marker.name = entry[0]
			spawns.add_child(marker)
			marker.owner = source
		marker.position = Vector2(entry[1], 424.0)
	spawns.name = "ConfiguredSpawns"
	if source.has_method("validate_spawns"):
		source.set("player_spawn_path", NodePath("ConfiguredSpawns/Player"))
		source.set("dummy_spawn_path", NodePath("ConfiguredSpawns/TrainingDummy"))
		source.set("enemy_spawn_path", NodePath("ConfiguredSpawns/PeriodicEnemy"))
	var geometry := source.get_node_or_null("Geometry")
	if geometry == null:
		geometry = Node2D.new()
		geometry.name = "Geometry"
		source.add_child(geometry)
		geometry.owner = source
		var solid := GrayboxSolid.create(Rect2(224, 424, 512, 16), Color.GRAY, "Floor")
		geometry.add_child(solid)
		_set_owner(solid, source)
	else:
		(geometry.get_node("Floor") as Node2D).position.y -= 16.0
	var arena := _reload(source) as TrainingArena
	_add_world(arena)
	arena.enemy.attack_enabled = false
	assert_eq(arena.player.global_position, Vector2(300, 424), "MECHANISM: saved player spawn")
	assert_eq(arena.dummy.global_position, Vector2(560, 424), "MECHANISM: saved dummy spawn")
	assert_eq(arena.enemy.global_position, Vector2(640, 424), "MECHANISM: saved enemy spawn")
	await wait_physics_frames(6)
	assert_true(arena.player.is_on_floor(), "MECHANISM: saved floor has real collision")
	assert_almost_eq(arena.player.global_position.y, 424.0, 0.1, "MECHANISM: saved floor height")
	arena.player.reset_state(Vector2(330, 400))
	arena.enemy.position = Vector2(680, 400)
	arena.dummy.position = Vector2(580, 400)
	arena.reset_training()
	assert_eq(
		arena.player.global_position, Vector2(300, 424), "MECHANISM: reset reads saved marker"
	)
	assert_eq(arena.enemy.global_position, Vector2(640, 424), "MECHANISM: enemy reset reads marker")
	# Training reset preserves a dummy deliberately repositioned by the test operator.
	assert_eq(
		arena.dummy.global_position, Vector2(580, 400), "MECHANISM: dummy reset keeps position"
	)
	await wait_physics_frames(3)
	assert_true(arena.player.is_on_floor(), "MECHANISM: reset remains on saved floor")


func test_training_missing_wrong_and_nonfinite_spawn_bindings_reject_reset_atomically() -> void:
	var arena := ARENA.instantiate() as TrainingArena
	_add_world(arena)
	assert_true(arena.has_method("validate_spawns"), "MECHANISM: spawn diagnostic API exists")
	if not arena.has_method("validate_spawns"):
		return
	arena.enemy.attack_enabled = false
	var old_position := arena.player.global_position
	var damage := HitData.new()
	damage.set_environment()
	damage.damage = 0.5
	arena.player.combatant.apply_damage(damage, 0.5)
	var health := arena.player.combatant.current_health
	for path in [NodePath("Missing"), NodePath("TrainingDummy")]:
		arena.set("player_spawn_path", path)
		assert_false(
			arena.call("validate_spawns").is_empty(), "MECHANISM: invalid binding diagnosed"
		)
		arena.reset_training()
		assert_false(
			str(arena.get("last_error")).is_empty(), "MECHANISM: reset reports binding error"
		)
		assert_eq(
			arena.player.global_position, old_position, "MECHANISM: failed reset leaves position"
		)
		assert_eq(
			arena.player.combatant.current_health, health, "MECHANISM: failed reset does not heal"
		)
	arena.set("player_spawn_path", NodePath("Spawns/Player"))
	var marker := arena.get_node("Spawns/Player") as Marker2D
	marker.position = Vector2(INF, 440.0)
	assert_false(arena.call("validate_spawns").is_empty(), "MECHANISM: invalid marker diagnosed")
	arena.reset_training()
	assert_eq(
		arena.player.global_position, old_position, "MECHANISM: invalid transform is rejected"
	)
	marker.position = Vector2(300, 440)
	arena.reset_training()
	assert_eq(arena.player.global_position, Vector2(300, 440), "MECHANISM: repaired binding works")
	assert_eq(arena.get("last_error"), "", "MECHANISM: repaired binding clears diagnostic")
	var source := ARENA.instantiate() as TrainingArena
	source.set("player_spawn_path", NodePath("Missing"))
	(source.get_node("Player") as Node2D).position = Vector2(320, 440)
	var saved_broken := _reload(source) as TrainingArena
	_add_world(saved_broken)
	assert_false(saved_broken.last_error.is_empty(), "MECHANISM: saved invalid binding diagnosed")
	assert_eq(
		saved_broken.player.position,
		Vector2(320, 440),
		"MECHANISM: startup cannot replace invalid saved spawn with a constant"
	)


func test_debug_child_handles_f2_in_both_scenes_and_freezes_while_paused() -> void:
	for scene in [ARENA, WORLD]:
		var world := scene.instantiate() as Node2D
		_add_world(world)
		var debug := world.get_node_or_null("DebugInput")
		assert_not_null(debug, "MECHANISM: scene owns explicit debug child")
		if debug == null:
			continue
		var player := world.get_node("Player") as PlayerCharacter
		_press_key(KEY_F2)
		await wait_frames(2)
		assert_eq(player.fireball_level, 2, "MECHANISM: mapped F2 changes next skill level once")
		get_tree().paused = true
		_press_key(KEY_F2)
		await wait_frames(2)
		assert_eq(player.fireball_level, 2, "MECHANISM: paused debug input cannot change skill")
		get_tree().paused = false
		world.free()


func test_debug_paths_and_custom_room_key_survive_saved_nested_configuration() -> void:
	var source := WORLD.instantiate() as MapWorld
	var debug := source.get_node_or_null("DebugInput")
	assert_not_null(debug, "MECHANISM: debug node exists before entry")
	if debug == null:
		source.free()
		return
	var container := Node.new()
	container.name = "DeveloperTools"
	source.add_child(container)
	container.owner = source
	debug.owner = null
	debug.reparent(container)
	debug.owner = source
	debug.set("player_path", NodePath("../../Player"))
	debug.set("world_path", NodePath("../.."))
	debug.set("collision_overlay_path", NodePath("../../CollisionDebug"))
	var shortcuts: Dictionary[int, StringName] = {KEY_F7: &"room_b"}
	debug.set("room_shortcuts", shortcuts)
	debug.set("enabled", false)
	var world := _reload(source) as MapWorld
	_add_world(world)
	var saved_debug := world.get_node("DeveloperTools/DebugInput")
	assert_false(saved_debug.enabled, "MECHANISM: saved false debug setting survives startup")
	_press_key(KEY_F7)
	await wait_frames(2)
	assert_eq(world.current_room_id, &"room_a", "MECHANISM: saved disabled debug does not travel")
	saved_debug.set("enabled", true)
	_press_key(KEY_F7)
	await wait_frames(2)
	assert_eq(world.current_room_id, &"room_b", "MECHANISM: saved key map drives room command")
	_press_key(KEY_F3)
	await wait_frames(2)
	assert_eq(world.current_room_id, &"room_b", "MECHANISM: removed sample key is not hardcoded")
	_press_key(KEY_F6)
	await wait_frames(2)
	assert_true(world.collision_debug.visible, "MECHANISM: nested overlay binding works")


func test_debug_missing_wrong_and_disabled_bindings_reject_commands_with_diagnostics() -> void:
	var world := WORLD.instantiate() as MapWorld
	_add_world(world)
	var debug := world.get_node_or_null("DebugInput")
	assert_not_null(debug, "MECHANISM: debug node has explicit bindings")
	if debug == null:
		return
	for path in [NodePath("Missing"), NodePath("../Camera")]:
		debug.set("player_path", path)
		_press_key(KEY_F2)
		await wait_frames(2)
		assert_eq(world.player.fireball_level, 1, "MECHANISM: broken binding cannot act")
		assert_false(str(debug.get("last_error")).is_empty(), "MECHANISM: broken binding diagnosed")
	debug.set("player_path", NodePath("../Player"))
	for property in ["world_path", "collision_overlay_path"]:
		var original: NodePath = debug.get(property)
		for path in [NodePath("Missing"), NodePath("../Camera")]:
			debug.set(property, path)
			_press_key(KEY_F4)
			_press_key(KEY_F6)
			await wait_frames(2)
			assert_eq(world.current_room_id, &"room_a", "MECHANISM: bad target cannot travel")
			assert_false(world.collision_debug.visible, "MECHANISM: bad target cannot toggle")
			assert_false(str(debug.get("last_error")).is_empty(), "MECHANISM: bad target diagnosed")
		debug.set(property, original)
	debug.set("enabled", false)
	_press_key(KEY_F2)
	_press_key(KEY_F4)
	_press_key(KEY_F6)
	await wait_frames(2)
	assert_eq(world.player.fireball_level, 1, "MECHANISM: disabled debug does not alter level")
	assert_eq(world.current_room_id, &"room_a", "MECHANISM: disabled debug does not travel")
	assert_false(world.collision_debug.visible, "MECHANISM: disabled debug does not toggle overlay")
	debug.set("enabled", true)
	_press_key(KEY_F2)
	await wait_frames(2)
	assert_eq(world.player.fireball_level, 2, "MECHANISM: repaired debug binding works")
	assert_eq(debug.get("last_error"), "", "MECHANISM: repaired debug clears diagnostic")


func _reload(source: Node) -> Node:
	var packed := PackedScene.new()
	assert_eq(packed.pack(source), OK, "MECHANISM: actual scene packing succeeds")
	var path := "user://world-editing-%d.tscn" % Time.get_ticks_usec()
	_files.append(path)
	assert_eq(ResourceSaver.save(packed, path), OK, "MECHANISM: scene file is saved")
	source.free()
	var saved := (
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	)
	return saved.instantiate()


func _set_owner(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_set_owner(child, owner_node)


func _add_world(world: Node) -> void:
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	autofree(world)
	(world.get_node("Player") as PlayerCharacter).set_control_input(0.0)


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
