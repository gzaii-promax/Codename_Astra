extends SceneTree
## Capture real scene proportions and near-apex frames with a graphics display.


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
	var arena: Node = load("res://world/training_arena.tscn").instantiate()
	if arena == null:
		quit(1)
		return
	root.add_child(arena)
	current_scene = arena
	arena.enemy.attack_enabled = false
	root.get_node("Localization").set_language("zh_CN", false)
	var captures: Array[Dictionary] = []
	for view in ["rest", "short_apex", "long_apex"]:
		arena.reset_training()
		arena.player.set_control_input(0.0)
		for _frame in range(6):
			await physics_frame
		var takeoff_y: float = arena.player.global_position.y
		var minimum_y := takeoff_y
		if view != "rest":
			arena.player.set_control_input(0.0, true, view == "long_apex")
			var reached_apex := false
			for frame in range(60):
				await physics_frame
				minimum_y = minf(minimum_y, arena.player.global_position.y)
				if frame > 1 and arena.player.velocity.y >= 0.0:
					reached_apex = true
					break
			if not reached_apex:
				quit(1)
				return
		await RenderingServer.frame_post_draw
		var viewport_image := root.get_texture().get_image()
		var file := output_root.path_join(view + ".png")
		if viewport_image.save_png(file) != OK:
			quit(1)
			return
		(
			captures
			. append(
				{
					"view": view,
					"file": file,
					"image_size": [viewport_image.get_width(), viewport_image.get_height()],
					"peak_height_pixels": takeoff_y - minimum_y,
					"player_feet": [arena.player.global_position.x, arena.player.global_position.y],
				}
			)
		)
	var evidence := {
		"status": "pass",
		"scope": "scale_movement_viewport_capture",
		"review_status": "pending",
		"headless": false,
		"renderer": RenderingServer.get_video_adapter_name(),
		"captures": captures,
	}
	var report := FileAccess.open(output_root.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify(evidence, "\t") + "\n")
	report.close()
	print("SCALE_MOVEMENT_VISUAL=" + JSON.stringify(evidence))
	quit(0)
