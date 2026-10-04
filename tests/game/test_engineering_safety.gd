extends GutTest

const PLAYER: PackedScene = preload("res://player/player_character.tscn")

var _original_events: Array[InputEvent] = []
var _original_deadzone: float = 0.5
var _original_setting: Variant
var _setting_existed: bool = false
var _files: Array[String] = []
var _directories: Array[String] = []


func before_each() -> void:
	InputSetup.ensure_actions()
	_original_events = InputMap.action_get_events(&"basic_attack")
	_original_deadzone = InputMap.action_get_deadzone(&"basic_attack")
	_setting_existed = ProjectSettings.has_setting("input/basic_attack")
	_original_setting = ProjectSettings.get_setting("input/basic_attack", null)


func after_each() -> void:
	InputMap.action_erase_events(&"basic_attack")
	InputMap.action_set_deadzone(&"basic_attack", _original_deadzone)
	for event in _original_events:
		InputMap.action_add_event(&"basic_attack", event)
	ProjectSettings.set_setting(
		"input/basic_attack", _original_setting if _setting_existed else null
	)
	for path in _files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_files.clear()
	for path in _directories:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_directories.clear()


func test_input_initialization_preserves_custom_and_empty_editor_bindings() -> void:
	InputMap.action_erase_events(&"basic_attack")
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_P
	InputMap.action_add_event(&"basic_attack", custom)
	InputSetup.ensure_actions()
	assert_eq(InputMap.action_get_events(&"basic_attack").size(), 1)
	assert_true(InputMap.action_has_event(&"basic_attack", custom))
	InputMap.action_erase_events(&"basic_attack")
	InputSetup.ensure_actions()
	assert_true(InputMap.action_get_events(&"basic_attack").is_empty())


func test_input_saved_project_setting_survives_reload_and_initialization() -> void:
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_P
	ProjectSettings.set_setting("input/basic_attack", {"deadzone": 0.25, "events": [custom]})
	var path := "user://engineering-input-%d.godot" % Time.get_ticks_usec()
	_files.append(path)
	assert_eq(ProjectSettings.save_custom(path), OK)
	var saved := ConfigFile.new()
	assert_eq(saved.load(path), OK)
	var binding: Dictionary = saved.get_value("input", "basic_attack")
	InputMap.action_erase_events(&"basic_attack")
	InputMap.action_set_deadzone(&"basic_attack", binding.deadzone)
	for event: InputEvent in binding.events:
		InputMap.action_add_event(&"basic_attack", event)
	InputSetup.ensure_actions()
	assert_eq(InputMap.action_get_events(&"basic_attack").size(), 1)
	assert_true(InputMap.action_has_event(&"basic_attack", custom))
	assert_eq(InputMap.action_get_deadzone(&"basic_attack"), 0.25)
	# A fresh engine must initialize InputMap from the actual saved project file.
	var directory := "user://engineering-input-project-%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_absolute(directory), OK)
	_directories.append(directory)
	saved.erase_section("autoload")
	saved.erase_section_key("application", "run/main_scene")
	var project_path := directory.path_join("project.godot")
	var script_path := directory.path_join("probe.gd")
	var result_path := directory.path_join("result.json")
	_files.append_array([project_path, script_path, result_path])
	assert_eq(saved.save(project_path), OK)
	var probe := FileAccess.open(script_path, FileAccess.WRITE)
	probe.store_string(
		(
			"extends SceneTree\nfunc _initialize():\n"
			+ (
				"\tload(%s).ensure_actions()\n"
				% var_to_str(ProjectSettings.globalize_path("res://shared/input_setup.gd"))
			)
			+ "\tvar events = InputMap.action_get_events('basic_attack')\n"
			+ "\tvar result = {'count': events.size(), 'key': events[0].physical_keycode,\n"
			+ "\t\t'deadzone': InputMap.action_get_deadzone('basic_attack')}\n"
			+ "\tvar file = FileAccess.open('res://result.json', FileAccess.WRITE)\n"
			+ "\tfile.store_string(JSON.stringify(result))\n\tquit()\n"
		)
	)
	probe.close()
	var output: Array = []
	assert_eq(
		OS.execute(
			OS.get_executable_path(),
			[
				"--headless",
				"--path",
				ProjectSettings.globalize_path(directory),
				"--script",
				"res://probe.gd"
			],
			output,
			true
		),
		0,
		str(output)
	)
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(result_path))
	assert_eq(int(result.count), 1)
	assert_eq(int(result.key), KEY_P)
	assert_eq(float(result.deadzone), 0.25)


func test_missing_input_action_gets_defaults_once() -> void:
	InputMap.erase_action(&"basic_attack")
	InputSetup.ensure_actions()
	InputSetup.ensure_actions()
	assert_eq(InputMap.action_get_events(&"basic_attack").size(), 1)
	var event := InputMap.action_get_events(&"basic_attack")[0] as InputEventKey
	assert_eq(event.physical_keycode, KEY_J)
	var hardware := InputEventKey.new()
	hardware.device = InputEvent.DEVICE_ID_KEYBOARD
	hardware.physical_keycode = KEY_J
	assert_true(InputMap.event_is_action(hardware, &"basic_attack"))


func test_activated_restart_of_same_action_executes_only_replacement_instance() -> void:
	_check_restart(&"activated")


func test_phase_callback_restart_of_same_action_executes_only_replacement_instance() -> void:
	_check_restart(&"phase_changed")


func test_completion_restart_does_not_consume_previous_tick_remainder() -> void:
	var controller := autofree(ActionController.new()) as ActionController
	var caster := autofree(Node.new()) as Node
	var definition := SkillDefinition.new()
	definition.windup_seconds = 0.0
	definition.active_seconds = 0.1
	definition.recovery_seconds = 0.0
	definition.cooldown_seconds = 0.0
	var executions: Array[int] = []
	var restarted: Array[bool] = [false]
	controller.bind_action(&"same", definition, func(_c, _d): executions.append(1))
	controller.completed.connect(
		func(_id: StringName, _cancelled: bool):
			if not restarted[0]:
				restarted[0] = true
				controller.request_action(&"same", caster)
	)
	assert_true(controller.request_action(&"same", caster))
	controller.tick(1.0)
	assert_eq(executions.size(), 2, "One execution for each distinct action instance")
	assert_eq(controller.phase, ActionController.Phase.ACTIVE)
	assert_almost_eq(controller.phase_remaining, 0.1, 0.00001)


func test_invalid_jump_calculation_never_produces_nonfinite_velocity() -> void:
	var player := autofree(PlayerCharacter.new()) as PlayerCharacter
	assert_true(is_finite(player._jump_speed_for_height(-10.0, 1.0 / 60.0)))
	player.gravity = INF
	assert_true(is_finite(player._jump_speed_for_height(10.0, 1.0 / 60.0)))


func test_saved_movement_overrides_drive_physics_and_survive_reset() -> void:
	var source := PLAYER.instantiate() as PlayerCharacter
	source.move_speed = 19.0
	source.acceleration = 10000.0
	source.coyote_seconds = 0.0
	source.jump_buffer_seconds = 0.0
	var player := _reload_player(source)
	_add_floor_player(player)
	await wait_physics_frames(6)
	player.set_control_input(1.0)
	await wait_physics_frames(8)
	assert_almost_eq(player.velocity.x, 19.0, 0.01)
	assert_gt(player.position.x, 0.0)
	player.reset_state(Vector2.ZERO)
	assert_eq(player.move_speed, 19.0)
	assert_eq(player.coyote_seconds, 0.0)
	assert_eq(player.jump_buffer_seconds, 0.0)
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.is_on_floor())
	player.set_control_input(0.0, true, true)
	await wait_physics_frames(3)
	assert_lt(player.position.y, -1.0, "Zero grace times still permit a fresh grounded jump")


func test_saved_zero_speed_stays_stationary_with_finite_visual_after_reset() -> void:
	var source := PLAYER.instantiate() as PlayerCharacter
	source.move_speed = 0.0
	var player := _reload_player(source)
	_add_floor_player(player)
	player.set_control_input(1.0)
	await wait_physics_frames(10)
	assert_eq(player.move_speed, 0.0)
	assert_eq(player.velocity.x, 0.0)
	assert_almost_eq(player.position.x, 0.0, 0.01)
	var sprite := player.visual.get_child(0) as Sprite2D
	assert_true(sprite.transform.is_finite())
	player.reset_state(Vector2.ZERO)
	await wait_physics_frames(3)
	assert_eq(player.move_speed, 0.0)
	assert_true(sprite.transform.is_finite())


func test_invalid_saved_movement_fails_closed_without_replacing_configuration() -> void:
	var source := PLAYER.instantiate() as PlayerCharacter
	source.min_jump_height = -10.0
	var player := _reload_player(source)
	_add_floor_player(player)
	player.set_control_input(1.0, true, true)
	await wait_physics_frames(3)
	assert_false(player.configuration_error.is_empty())
	assert_eq(player.velocity, Vector2.ZERO)
	assert_eq(player.position, Vector2.ZERO)
	assert_false(player.request_attack())
	player.reset_state(Vector2.ZERO)
	assert_eq(player.min_jump_height, -10.0)
	for field in ["gravity", "move_speed"]:
		player.min_jump_height = 16.0
		player.set(field, NAN)
		player._physics_process(1.0 / 60.0)
		assert_false(player.validate_movement().is_empty())
		assert_true(player.velocity.is_finite())
		player.set(field, INF)
		player._physics_process(1.0 / 60.0)
		assert_true(player.velocity.is_finite())
		player.set(field, 400.0 if field == "gravity" else 56.0)


func test_invalid_visual_geometry_has_readable_errors_and_no_invalid_sprite() -> void:
	for region in [Rect2(0, 0, 10, 0), Rect2(0, 0, -1, 10), Rect2(NAN, 0, 10, 10)]:
		var visual := PlayerVisual.new()
		visual.texture_region = region
		add_child_autofree(visual)
		assert_false(visual.configuration_error.is_empty())
		assert_eq(visual.get_child_count(), 0)
	var visual := PlayerVisual.new()
	visual.display_height = INF
	add_child_autofree(visual)
	assert_false(visual.validate_visual().is_empty())
	assert_eq(visual.get_child_count(), 0)
	var oversized := PlayerVisual.new()
	oversized.display_height = 1e100
	add_child_autofree(oversized)
	assert_false(oversized.validate_visual().is_empty())
	assert_eq(oversized.get_child_count(), 0)


func test_idle_phase_restart_keeps_replacement_tick_budget() -> void:
	var controller := autofree(ActionController.new()) as ActionController
	var caster := autofree(Node.new()) as Node
	var definition := SkillDefinition.new()
	definition.windup_seconds = 0.0
	definition.active_seconds = 0.1
	definition.recovery_seconds = 0.0
	definition.cooldown_seconds = 0.0
	var executions: Array[int] = []
	var restarted: Array[bool] = [false]
	controller.bind_action(&"same", definition, func(_c, _d): executions.append(1))
	controller.phase_changed.connect(
		func(phase: int):
			if phase == ActionController.Phase.IDLE and not restarted[0]:
				restarted[0] = true
				controller.request_action(&"same", caster)
	)
	assert_true(controller.request_action(&"same", caster))
	controller.tick(1.0)
	assert_eq(executions.size(), 2)
	assert_eq(controller.phase, ActionController.Phase.ACTIVE)
	assert_almost_eq(controller.phase_remaining, 0.1, 0.00001)


func _reload_player(source: PlayerCharacter) -> PlayerCharacter:
	var packed := PackedScene.new()
	assert_eq(packed.pack(source), OK)
	var path := "user://engineering-player-%d.tscn" % Time.get_ticks_usec()
	_files.append(path)
	assert_eq(ResourceSaver.save(packed, path), OK)
	source.free()
	var saved := (
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	)
	return saved.instantiate() as PlayerCharacter


func _add_floor_player(player: PlayerCharacter) -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	world.add_child(GrayboxSolid.create(Rect2(-500, 0, 1000, 20), Color.GRAY, "Floor"))
	world.add_child(player)
	player.set_control_input(0.0)


func _check_restart(event: StringName) -> void:
	var controller := autofree(ActionController.new()) as ActionController
	var caster := autofree(Node.new()) as Node
	var definition := SkillDefinition.new()
	definition.windup_seconds = 0.0
	definition.active_seconds = 0.1
	var executions: Array[int] = []
	var restarted: Array[bool] = [false]
	controller.bind_action(&"same", definition, func(_c, _d): executions.append(1))
	var restart := func():
		if not restarted[0]:
			restarted[0] = true
			controller.reset_state()
			controller.request_action(&"same", caster)
	if event == &"activated":
		controller.activated.connect(func(_id, _definition, _caster): restart.call())
	else:
		controller.phase_changed.connect(
			func(phase: int):
				if phase == ActionController.Phase.ACTIVE:
					restart.call()
		)
	assert_true(controller.request_action(&"same", caster))
	assert_eq(executions.size(), 1, "Cancelled action stack must not execute replacement again")
	assert_eq(controller.phase, ActionController.Phase.ACTIVE)
