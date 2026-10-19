extends SceneTree
## Render actual locomotion states and an enlarged native SpriteFrames preview.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var output := args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var arena: Node = load("res://world/training_arena.tscn").instantiate()
	if arena == null:
		quit(1)
		return
	root.add_child(arena)
	current_scene = arena
	arena.enemy.attack_enabled = false
	arena.player.set_control_input(0.0)
	var observations: Array[Dictionary] = []
	for state in ["stand", "idle", "run_right", "run_left", "jump"]:
		var ticks := 6 if state == "stand" else 45
		if state == "run_right":
			arena.player.set_control_input(1.0)
			ticks = 24
		elif state == "run_left":
			arena.player.set_control_input(-1.0)
			ticks = 40
		elif state == "jump":
			arena.player.set_control_input(1.0, true, true)
			ticks = 8
		for _tick in range(ticks):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(state + ".png"))
		var sprite := arena.player.visual.get_node("AnimatedSprite2D") as AnimatedSprite2D
		(
			observations
			. append(
				{
					"state": state,
					"animation": sprite.animation,
					"frame": sprite.frame,
					"flipped": sprite.flip_h,
					"on_floor": arena.player.is_on_floor(),
					"feet": [arena.player.position.x, arena.player.position.y],
				}
			)
		)
	arena.queue_free()
	await process_frame
	var preview := Node2D.new()
	root.add_child(preview)
	var frames := load("res://assets/characters/r4/locomotion.tres") as SpriteFrames
	for index in range(3):
		var animation: StringName = [&"stand", &"idle", &"run"][index]
		var sprite := _preview_sprite(frames, Vector2(185 + index * 295, 190), 0.8)
		preview.add_child(sprite)
		sprite.play(animation)
		var label := Label.new()
		label.text = "R4 / " + String(animation)
		label.position = Vector2(140 + index * 295, 25)
		preview.add_child(label)
	for index in range(8):
		var sprite := _preview_sprite(frames, Vector2(60 + index * 120, 440), 0.35)
		preview.add_child(sprite)
		sprite.animation = &"run"
		sprite.frame = index
	for _tick in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("animation-preview.png"))
	var report := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"observations": observations, "review": "pending"}, "\t"))
	print("R4_VISUAL=" + JSON.stringify(observations))
	quit(0)


func _preview_sprite(frames: SpriteFrames, point: Vector2, factor: float) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = point
	sprite.scale = Vector2.ONE * factor
	return sprite
