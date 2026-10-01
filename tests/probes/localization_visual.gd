extends SceneTree
## Capture the real viewport; this probe requires a graphics display.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or DisplayServer.get_name() == "headless":
		print("LOCALIZATION_VISUAL=" + JSON.stringify({"status": "blocked"}))
		quit(1)
		return
	var output_root := arguments[0]
	DirAccess.make_dir_recursive_absolute(output_root)
	# --script compiles before autoload globals are registered. Keep business classes
	# out of this script's static dependency graph and load the scene after startup.
	var localization = root.get_node("Localization")
	var arena: Node = load("res://world/training_arena.tscn").instantiate()
	if arena == null:
		quit(1)
		return
	root.add_child(arena)
	current_scene = arena
	var hud = arena.get_node("HUD")
	var captures: Array[Dictionary] = []
	for locale in ["zh_CN", "en", "ja"]:
		if not localization.set_language(locale, false):
			quit(1)
			return
		for view in ["hud", "menu", "help"]:
			hud.close_menu()
			if view == "menu":
				hud.open_menu()
			elif view == "help":
				hud.open_help()
			for _frame in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var viewport_image := root.get_texture().get_image()
			var file := output_root.path_join("%s-%s.png" % [locale, view])
			var error := viewport_image.save_png(file)
			if error != OK:
				quit(1)
				return
			var panel_name := {"hud": "HudPanel", "menu": "MenuPanel", "help": "HelpPanel"}
			var panel: Control = hud.get_ui_control(panel_name[view])
			(
				captures
				. append(
					{
						"locale": locale,
						"view": view,
						"file": file,
						"image_size": [viewport_image.get_width(), viewport_image.get_height()],
						"panel_position": [panel.global_position.x, panel.global_position.y],
						"panel_size": [panel.size.x, panel.size.y],
						"font_path": localization.get_font().resource_path,
					}
				)
			)
	hud.close_menu()
	var evidence := {
		"status": "pass",
		"scope": "viewport_capture",
		"review_status": "pending",
		"renderer": RenderingServer.get_video_adapter_name(),
		"headless": false,
		"captures": captures,
	}
	var report := FileAccess.open(output_root.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify(evidence, "\t") + "\n")
	report.close()
	print("LOCALIZATION_VISUAL=" + JSON.stringify(evidence))
	quit(0)
