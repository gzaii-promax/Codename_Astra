extends SceneTree
## Capture actual health presentation without compiling business classes before autoload.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or DisplayServer.get_name() == "headless":
		print("HEALTH_COMBAT_VISUAL=" + JSON.stringify({"status": "blocked"}))
		quit(1)
		return
	var output_root := arguments[0]
	if DirAccess.make_dir_recursive_absolute(output_root) != OK:
		quit(1)
		return
	var localization = root.get_node("Localization")
	var arena: Node = load("res://world/training_arena.tscn").instantiate()
	if arena == null:
		quit(1)
		return
	root.add_child(arena)
	current_scene = arena
	var captures: Array[Dictionary] = []
	for locale in ["zh_CN", "en", "ja"]:
		if not localization.set_language(locale, false) or not _prepare_units(arena):
			quit(1)
			return
		for view in ["damaged", "enemy_dead", "player_downed"]:
			var capture := await _capture_view(arena, locale, view, output_root)
			if capture.is_empty():
				quit(1)
				return
			captures.append(capture)
	var evidence := {
		"status": "pass",
		"scope": "health_combat_viewport_capture",
		"review_status": "pending",
		"renderer": RenderingServer.get_video_adapter_name(),
		"headless": false,
		"captures": captures,
	}
	quit(0 if _save_report(output_root, evidence) else 1)


func _prepare_units(arena: Node) -> bool:
	arena.reset_training()
	var player = arena.player
	var enemy = arena.enemy
	enemy.attack_enabled = false
	player.get_combatant().zero_health_behavior = 0
	player.reset_state(enemy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	return _deal_damage(enemy, player, 0.5) and _deal_damage(player, enemy, 1.0)


func _deal_damage(source: Node, target: Node, damage: float) -> bool:
	var hit = load("res://combat/hit_data.gd").new()
	hit.set_source(source)
	hit.damage = damage
	return target.get_node("DamageReceiver").receive_hit(hit)


func _capture_view(arena: Node, locale: String, view: String, output_root: String) -> Dictionary:
	var player = arena.player
	var enemy = arena.enemy
	if view == "enemy_dead":
		enemy.get_combatant().force_death()
	elif view == "player_downed":
		for _frame in range(31):
			await physics_frame
		await process_frame
		player.get_combatant().zero_health_behavior = 1
		if not _deal_damage(enemy, player, 3.0):
			return {}
	for _frame in range(6):
		await physics_frame
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	var file := output_root.path_join("%s-%s.png" % [locale, view])
	if viewport_image.save_png(file) != OK:
		return {}
	return {
		"locale": locale,
		"view": view,
		"file": file,
		"image_size": [viewport_image.get_width(), viewport_image.get_height()],
		"player": _unit_evidence(player),
		"enemy": _unit_evidence(enemy),
		"font_path": root.get_node("Localization").get_font().resource_path,
	}


func _save_report(output_root: String, evidence: Dictionary) -> bool:
	var report := FileAccess.open(output_root.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		return false
	report.store_string(JSON.stringify(evidence, "\t") + "\n")
	report.close()
	print("HEALTH_COMBAT_VISUAL=" + JSON.stringify(evidence))
	return true


func _unit_evidence(actor: Node) -> Dictionary:
	var health = actor.get_combatant()
	var bar = actor.get_node("HealthBar")
	return {
		"health": health.current_health,
		"max_health": health.max_health,
		"life_state": health.life_state,
		"bar_ratio": bar.get_fill_ratio(),
		"bar_text": bar.get_display_text(),
		"bar_position": [bar.global_position.x, bar.global_position.y],
	}
