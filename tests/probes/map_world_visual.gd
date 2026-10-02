extends SceneTree
## Non-headless three-language room captures; screenshot success is not a playtest verdict.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var output_root := arguments[0]
	if DirAccess.make_dir_recursive_absolute(output_root) != OK:
		quit(1)
		return
	var world: Node = load("res://world/map_world.tscn").instantiate()
	if world == null:
		quit(1)
		return
	root.add_child(world)
	current_scene = world
	var captures: Array[Dictionary] = []
	var views: Array[Dictionary] = []
	for locale in ["en", "ja", "zh_CN"]:
		for room_id in [&"room_a", &"room_b", &"room_c"]:
			views.append({"locale": locale, "room": room_id, "entrance": &"west", "suffix": ""})
	views.append({"locale": "zh_CN", "room": &"room_b", "entrance": &"east", "suffix": "_right"})
	(
		views
		. append(
			{
				"locale": "zh_CN",
				"room": &"room_a",
				"entrance": &"west",
				"suffix": "_debug",
				"debug": true,
			}
		)
	)
	for view in views:
		if (
			not root.get_node("Localization").set_language(view["locale"], false)
			or not world.enter_room(view["room"], view["entrance"])
		):
			quit(1)
			return
		world.set_collision_debug(false)
		if view.get("debug", false):
			_send_f6(true)
			_send_f6(false)
		world.player.set_control_input(0.0)
		for _frame in range(8):
			await physics_frame
		await RenderingServer.frame_post_draw
		var name := "%s_%s%s" % [view["locale"], view["room"], view["suffix"]]
		var capture := _capture(world, output_root, name, view["locale"])
		if capture.is_empty():
			quit(1)
			return
		captures.append(capture)
	var report := FileAccess.open(output_root.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	var evidence := {
		"status": "pass",
		"scope": "map_world_viewport_capture",
		"review_status": "pending",
		"headless": false,
		"renderer": RenderingServer.get_video_adapter_name(),
		"captures": captures,
	}
	report.store_string(JSON.stringify(evidence, "\t") + "\n")
	report.close()
	print("MAP_WORLD_VISUAL=" + JSON.stringify(evidence))
	quit(0)


func _capture(world: Node, output_root: String, view: String, locale: String) -> Dictionary:
	var viewport_image := root.get_texture().get_image()
	var filename := output_root.path_join(view + ".png")
	if viewport_image.save_png(filename) != OK:
		return {}
	var bounds: Rect2 = world.current_room.bounds
	var player_position: Vector2 = world.player.global_position
	var camera_position: Vector2 = world.camera.global_position
	var screen_center: Vector2 = world.camera.get_screen_center_position()
	var debug_overlay := world.get_node("CollisionDebug")
	return {
		"view": view,
		"language": locale,
		"room_id": String(world.current_room_id),
		"file": filename,
		"image_size": [viewport_image.get_width(), viewport_image.get_height()],
		"player_feet": [player_position.x, player_position.y],
		"camera_position": [camera_position.x, camera_position.y],
		"camera_screen_center": [screen_center.x, screen_center.y],
		"camera_zoom": [world.camera.zoom.x, world.camera.zoom.y],
		"room_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"visited_rooms": world.get_visited_rooms(),
		"collision_debug_visible": debug_overlay.visible,
		"collision_polygon_count": debug_overlay.get_debug_polygon_count(),
	}


func _send_f6(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F6
	event.pressed = pressed
	root.push_input(event)
