extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const LOCALES := ["en", "ja", "zh_CN"]
const LABEL_KEYS := {
	"AppTitle": "app.title",
	"Controls": "hud.controls",
	"DebugControls": "hud.debug_controls",
	"MenuTitle": "menu.title",
	"LanguageLabel": "menu.language",
	"MenuHint": "menu.hint",
	"HelpTitle": "manual.title",
}
const BUTTON_KEYS := {
	"MenuButton": "menu.open",
	"ResumeButton": "menu.resume",
	"ResetButton": "menu.reset",
	"HelpButton": "menu.help",
	"HelpCloseButton": "menu.close",
}

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
	get_tree().current_scene = _original_scene
	Localization.set_language(_original_language, false)
	process_mode = _original_process_mode
	Input.action_release("ui_cancel")


func test_actual_ui_switches_menu_hud_skill_and_manual_text_in_three_languages() -> void:
	var arena := _arena()
	var hud := arena.get_node("HUD") as TrainingHUD
	await wait_frames(4)
	for locale in LOCALES:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(4)
		for name in LABEL_KEYS:
			var label := hud.get_ui_control(name) as Label
			assert_eq(label.text, Localization.text(LABEL_KEYS[name]), "%s in %s" % [name, locale])
			assert_eq(
				label.get_theme_font("font").resource_path, Localization.get_font().resource_path
			)
		for name in BUTTON_KEYS:
			var button := hud.get_ui_control(name) as Button
			assert_eq(button.text, Localization.text(BUTTON_KEYS[name]))
		var skill_stats := hud.get_ui_control("SkillStats") as Label
		assert_true(skill_stats.text.contains(Localization.text("skill.fireball.name")))
		assert_eq(
			skill_stats.text,
			(
				Localization
				. text(
					"hud.skill_stats",
					{
						"skill": Localization.text("skill.fireball.name"),
						"level": 1,
						"windup": "0.50",
						"recovery": "0.22",
						"cooldown": "0.90",
						"damage": "1",
					}
				)
			)
		)
		assert_false(skill_stats.text.contains("{"), "HUD named arguments are resolved")
		assert_eq(
			(hud.get_ui_control("TargetStats") as Label).text,
			Localization.text("hud.target", {"damage": "0", "hits": 0})
		)
		assert_true(
			(hud.get_ui_control("PhaseStats") as Label).text.contains(
				Localization.text("phase.idle")
			)
		)
		hud.open_help()
		await wait_frames(4)
		var manual := (hud.get_ui_control("HelpText") as Label).text
		for key in ["manual.movement", "manual.combat", "manual.training", "manual.languages"]:
			assert_true(manual.contains(Localization.text(key)), "Manual includes %s" % key)
		for action_id in [&"basic_attack", &"fireball"]:
			var definition := arena.player.get_action_controller().get_definition(action_id)
			assert_true(manual.contains(Localization.text(definition.name_key)))
			assert_true(manual.contains(Localization.text(definition.description_key)))
		hud.close_menu()


func test_actual_language_picker_updates_ui_and_saves_isolated_preference() -> void:
	var arena := _arena()
	var hud := arena.get_node("HUD") as TrainingHUD
	hud.open_menu()
	var picker := hud.get_ui_control("LanguagePicker") as OptionButton
	var selected := -1
	for index in picker.item_count:
		if picker.get_item_metadata(index) == "ja":
			selected = index
	assert_gte(selected, 0)
	assert_eq(picker.item_count, Localization.available_languages().size())
	if selected < 0:
		return
	picker.item_selected.emit(selected)
	await wait_frames(4)
	assert_eq(Localization.current_language, "ja")
	assert_eq((hud.get_ui_control("MenuTitle") as Label).text, Localization.text("menu.title"))
	assert_eq(picker.get_item_metadata(picker.selected), "ja")
	assert_eq(
		picker.get_popup().get_theme_font("font").resource_path,
		Localization.get_font().resource_path
	)
	var filename: String = Localization.get_settings_path()
	assert_false(filename.is_empty())
	assert_eq(
		filename, OS.get_environment("ASTRA_SETTINGS_PATH"), "Runner isolates real picker save"
	)
	var config := ConfigFile.new()
	assert_eq(config.load(filename), OK)
	assert_eq(config.get_value("localization", "language"), "ja")
	hud.close_menu()


func test_open_menu_pauses_gameplay_and_resume_button_restores_movement() -> void:
	var arena := _arena()
	var hud := arena.get_node("HUD") as TrainingHUD
	await wait_physics_frames(6)
	arena.player.set_control_input(1.0)
	hud.get_ui_control("MenuButton").emit_signal("pressed")
	assert_true(hud.is_menu_open())
	assert_true(get_tree().paused)
	var paused_position := arena.player.global_position
	await wait_physics_frames(8)
	assert_eq(arena.player.global_position, paused_position, "Paused scene cannot move")
	hud.get_ui_control("ResumeButton").emit_signal("pressed")
	assert_false(hud.is_menu_open())
	assert_false(get_tree().paused)
	await wait_physics_frames(8)
	assert_gt(arena.player.global_position.x, paused_position.x)


func test_help_buttons_and_escape_follow_help_then_menu_close_order() -> void:
	var hud := _arena().get_node("HUD") as TrainingHUD
	hud.open_menu()
	hud.get_ui_control("HelpButton").emit_signal("pressed")
	assert_true(hud.is_help_open())
	assert_true(get_tree().paused)
	hud.get_ui_control("HelpCloseButton").emit_signal("pressed")
	assert_false(hud.is_help_open())
	assert_true(hud.is_menu_open())
	hud.open_help()
	_send_escape()
	await wait_frames(2)
	assert_false(hud.is_help_open())
	assert_true(hud.is_menu_open())
	_send_escape()
	await wait_frames(2)
	assert_false(hud.is_menu_open())
	assert_false(get_tree().paused)


func test_reset_button_resets_training_and_closes_pause_menu() -> void:
	var arena := _arena()
	var hud := arena.get_node("HUD") as TrainingHUD
	await wait_physics_frames(6)
	var hit := HitData.new()
	hit.source = arena.player
	hit.damage = 0.5
	assert_true(arena.dummy.get_receiver().receive_hit(hit))
	assert_true(arena.player.request_fireball())
	hud.open_menu()
	hud.get_ui_control("ResetButton").emit_signal("pressed")
	assert_eq(arena.dummy.total_damage, 0.0)
	assert_eq(arena.dummy.hit_count, 0)
	assert_eq(arena.player.get_action_controller().phase, ActionController.Phase.IDLE)
	assert_eq(arena.player.get_action_controller().get_cooldown_remaining(&"fireball"), 0.0)
	assert_false(hud.is_menu_open())
	assert_false(get_tree().paused)


func test_menu_close_preserves_a_preexisting_paused_state() -> void:
	var hud := _arena().get_node("HUD") as TrainingHUD
	get_tree().paused = true
	hud.open_menu()
	hud.close_menu()
	assert_true(get_tree().paused, "Menu does not resume a scene paused for another reason")
	get_tree().paused = false


func test_engine_measured_ui_bounds_and_text_fit_all_three_languages() -> void:
	var hud := _arena().get_node("HUD") as TrainingHUD
	await wait_frames(4)
	for locale in LOCALES:
		assert_true(Localization.set_language(locale, false))
		hud.open_menu()
		await wait_frames(5)
		_assert_inside_viewport(hud.get_ui_control("HudPanel"), locale)
		_assert_inside_viewport(hud.get_ui_control("MenuPanel"), locale)
		for name in ["ResumeButton", "ResetButton", "HelpButton", "LanguagePicker"]:
			_assert_inside_panel(hud.get_ui_control(name), hud.get_ui_control("MenuPanel"), locale)
		for name in LABEL_KEYS:
			var label := hud.get_ui_control(name) as Label
			if label.is_visible_in_tree():
				_assert_label_fits(label, locale)
		for name in ["SkillStats", "TargetStats", "PhaseStats"]:
			_assert_label_fits(hud.get_ui_control(name) as Label, locale)
		hud.open_help()
		await wait_frames(5)
		_assert_inside_viewport(hud.get_ui_control("HelpPanel"), locale)
		_assert_inside_panel(
			hud.get_ui_control("HelpScroll"), hud.get_ui_control("HelpPanel"), locale
		)
		_assert_inside_panel(
			hud.get_ui_control("HelpCloseButton"), hud.get_ui_control("HelpPanel"), locale
		)
		_assert_label_fits(hud.get_ui_control("HelpTitle") as Label, locale)
		var manual := hud.get_ui_control("HelpText") as Label
		var scroll := hud.get_ui_control("HelpScroll") as ScrollContainer
		assert_lte(manual.size.x, scroll.size.x + 1.0, "Manual remains inside scroll width")
		_assert_label_fits(manual, locale)
		if manual.size.y > scroll.size.y:
			scroll.scroll_vertical = int(manual.size.y)
			await wait_frames(2)
			assert_gt(scroll.scroll_vertical, 0, "Long manual can scroll to additional paragraphs")
		hud.close_menu()


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	autofree(arena)
	get_tree().current_scene = arena
	return arena


func _send_escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	get_viewport().push_input(event)


func _assert_inside_viewport(control: Control, locale: String) -> void:
	_assert_inside_rect(control, get_viewport().get_visible_rect(), locale)


func _assert_inside_panel(control: Control, panel: Control, locale: String) -> void:
	_assert_inside_rect(control, panel.get_global_rect(), locale)


func _assert_inside_rect(control: Control, bounds: Rect2, locale: String) -> void:
	var actual := control.get_global_rect()
	assert_gte(actual.position.x, bounds.position.x - 1.0, "%s left (%s)" % [control.name, locale])
	assert_gte(actual.position.y, bounds.position.y - 1.0, "%s top (%s)" % [control.name, locale])
	assert_lte(actual.end.x, bounds.end.x + 1.0, "%s right (%s)" % [control.name, locale])
	assert_lte(actual.end.y, bounds.end.y + 1.0, "%s bottom (%s)" % [control.name, locale])


func _assert_label_fits(label: Label, locale: String) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var measured := font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		label.size.x,
		font_size,
		-1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	assert_lte(measured.x, label.size.x + 1.0, "%s rendered width (%s)" % [label.name, locale])
	assert_lte(measured.y, label.size.y + 1.0, "%s rendered height (%s)" % [label.name, locale])
