class_name TrainingHUD
extends CanvasLayer
## Localized training readout and pause/help navigation; combat stays in its own modules.

const PHASE_KEYS := ["phase.idle", "phase.windup", "phase.active", "phase.recovery"]

var _player: PlayerCharacter
var _dummy: TrainingDummy
var _interface: Control
var _hud_panel: PanelContainer
var _pause_overlay: ColorRect
var _menu_panel: PanelContainer
var _help_panel: PanelContainer
var _title: Label
var _controls: Label
var _debug_controls: Label
var _status: Label
var _target: Label
var _phase: Label
var _menu_title: Label
var _language_label: Label
var _menu_hint: Label
var _save_error: Label
var _help_title: Label
var _help_text: Label
var _menu_button: Button
var _resume_button: Button
var _reset_button: Button
var _help_button: Button
var _help_close_button: Button
var _language_picker: OptionButton
var _ui_theme: Theme
var _languages: Array[Dictionary] = []
var _menu_open: bool = false
var _help_open: bool = false
var _paused_before_menu: bool = false
var _language_error: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent().get_node("Player") as PlayerCharacter
	_dummy = get_parent().get_node("TrainingDummy") as TrainingDummy
	_build_interface()
	Localization.language_changed.connect(_on_language_changed)
	get_viewport().size_changed.connect(_resize_interface)
	_resize_interface()
	_refresh_text()


func _process(_delta: float) -> void:
	_refresh_readout()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _help_open:
			close_help()
		elif _menu_open:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _menu_open:
		get_tree().paused = _paused_before_menu


func open_menu() -> void:
	if _menu_open:
		return
	_paused_before_menu = get_tree().paused
	_menu_open = true
	_help_open = false
	_pause_overlay.show()
	_menu_panel.show()
	_help_panel.hide()
	get_tree().paused = true
	_refresh_text()
	_resume_button.grab_focus()


func close_menu() -> void:
	if not _menu_open:
		return
	_menu_open = false
	_help_open = false
	_pause_overlay.hide()
	_help_panel.hide()
	_menu_panel.show()
	get_tree().paused = _paused_before_menu
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func is_menu_open() -> bool:
	return _menu_open


func open_help() -> void:
	open_menu()
	_help_open = true
	_menu_panel.hide()
	_help_panel.show()
	_refresh_text()
	_help_close_button.grab_focus()


func close_help() -> void:
	if not _help_open:
		return
	_help_open = false
	_help_panel.hide()
	_menu_panel.show()
	_help_button.grab_focus()


func is_help_open() -> bool:
	return _help_open


func get_ui_control(node_name: String) -> Control:
	return _interface.find_child(node_name, true, false) as Control


func _build_interface() -> void:
	_ui_theme = Theme.new()
	_ui_theme.default_font_size = 14
	_interface = Control.new()
	_interface.name = "Interface"
	_interface.theme = _ui_theme
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_interface)
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	_build_pause_overlay()


func _build_hud() -> void:
	_hud_panel = _panel("HudPanel")
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panel.minimum_size_changed.connect(_on_hud_minimum_size_changed)
	_interface.add_child(_hud_panel)
	var rows := _column("HudRows", _hud_panel, 4)
	var heading := HBoxContainer.new()
	heading.name = "HudHeading"
	rows.add_child(heading)
	_title = _label("AppTitle", heading, 18, Color("e3c28c"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_button = _button("MenuButton", heading, open_menu)
	_menu_button.custom_minimum_size.y = 28.0
	var columns := HBoxContainer.new()
	columns.name = "ReadoutColumns"
	columns.add_theme_constant_override("separation", 20)
	rows.add_child(columns)
	var left := _column("ReadoutLeft", columns, 3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.4
	_controls = _label("Controls", left, 14)
	_debug_controls = _label("DebugControls", left, 13, Color("9eaec2"))
	_status = _label("SkillStats", left, 13, Color("d8b98a"))
	var right := _column("ReadoutRight", columns, 5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	_target = _label("TargetStats", right, 14)
	_phase = _label("PhaseStats", right, 13, Color("9eaec2"))


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0.02, 0.025, 0.04, 0.85)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_interface.add_child(_pause_overlay)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.name = "OverlayMargin"
	_pause_overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var center := CenterContainer.new()
	center.name = "OverlayCenter"
	margin.add_child(center)
	_build_menu(center)
	_build_help(center)
	_pause_overlay.hide()


func _build_menu(parent: Control) -> void:
	_menu_panel = _panel("MenuPanel")
	parent.add_child(_menu_panel)
	var content := _column("MenuRows", _menu_panel, 10)
	_menu_title = _label("MenuTitle", content, 24, Color("e3c28c"))
	_resume_button = _button("ResumeButton", content, close_menu)
	_reset_button = _button("ResetButton", content, _on_reset_pressed)
	var language_row := HBoxContainer.new()
	language_row.name = "LanguageRow"
	language_row.add_theme_constant_override("separation", 12)
	content.add_child(language_row)
	_language_label = _label("LanguageLabel", language_row, 16)
	_language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language_picker = OptionButton.new()
	_language_picker.name = "LanguagePicker"
	_language_picker.custom_minimum_size = Vector2(170.0, 38.0)
	_language_picker.item_selected.connect(_on_language_selected)
	language_row.add_child(_language_picker)
	_language_picker.get_popup().theme = _ui_theme
	_help_button = _button("HelpButton", content, open_help)
	_menu_hint = _label("MenuHint", content, 13, Color("9eaec2"))
	_save_error = _label("SaveError", content, 13, Color("f9a58c"))
	_save_error.hide()


func _build_help(parent: Control) -> void:
	_help_panel = _panel("HelpPanel")
	parent.add_child(_help_panel)
	var content := _column("HelpRows", _help_panel, 10)
	_help_title = _label("HelpTitle", content, 24, Color("e3c28c"))
	var scroll := ScrollContainer.new()
	scroll.name = "HelpScroll"
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 240.0
	content.add_child(scroll)
	_help_text = _label("HelpText", scroll, 16)
	_help_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_close_button = _button("HelpCloseButton", content, close_help)
	_help_panel.hide()


func _refresh_text() -> void:
	_ui_theme.default_font = Localization.get_font()
	_title.text = Localization.text("app.title")
	_controls.text = Localization.text("hud.controls")
	_debug_controls.text = Localization.text("hud.debug_controls")
	_menu_button.text = Localization.text("menu.open")
	_menu_title.text = Localization.text("menu.title")
	_resume_button.text = Localization.text("menu.resume")
	_reset_button.text = Localization.text("menu.reset")
	_language_label.text = Localization.text("menu.language")
	_help_button.text = Localization.text("menu.help")
	_menu_hint.text = Localization.text("menu.hint")
	_help_title.text = Localization.text("manual.title")
	_help_close_button.text = Localization.text("menu.close")
	var manual: Array[String] = []
	for key in ["manual.movement", "manual.combat", "manual.training", "manual.languages"]:
		manual.append(Localization.text(key))
	for action_id in [&"basic_attack", &"fireball"]:
		var definition := _player.get_action_controller().get_definition(action_id)
		manual.append(Localization.text(definition.name_key))
		manual.append(Localization.text(definition.description_key))
	_help_text.text = "\n\n".join(manual)
	_languages = Localization.available_languages()
	_language_picker.clear()
	for index in _languages.size():
		var language := _languages[index]
		_language_picker.add_item(str(language["name"]))
		_language_picker.set_item_metadata(index, language["locale"])
		if language["locale"] == Localization.current_language:
			_language_picker.select(index)
	_save_error.visible = not _language_error.is_empty()
	if _save_error.visible:
		_save_error.text = Localization.text("menu.save_error", {"error": _language_error})
	_refresh_readout()


func _refresh_readout() -> void:
	if not is_instance_valid(_player):
		return
	var actions := _player.get_action_controller()
	var definition := actions.get_definition(&"fireball")
	_status.text = (
		Localization
		. text(
			"hud.skill_stats",
			{
				"skill": Localization.text(definition.name_key),
				"level": _player.fireball_level,
				"damage": "%.0f" % definition.damage,
				"windup": "%.2f" % definition.windup_seconds,
				"recovery": "%.2f" % definition.recovery_seconds,
				"cooldown": "%.2f" % definition.cooldown_seconds,
			}
		)
	)
	_target.text = Localization.text(
		"hud.target", {"damage": "%.0f" % _dummy.total_damage, "hits": _dummy.hit_count}
	)
	_phase.text = (
		Localization
		. text(
			"hud.phase",
			{
				"phase": Localization.text(PHASE_KEYS[actions.phase]),
				"cooldown": "%.1f" % actions.get_cooldown_remaining(&"fireball"),
			}
		)
	)


func _resize_interface() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_fit_hud()
	_menu_panel.custom_minimum_size = Vector2(minf(500.0, viewport_size.x - 48.0), 0.0)
	_help_panel.custom_minimum_size = Vector2(
		minf(840.0, viewport_size.x - 48.0), minf(450.0, viewport_size.y - 48.0)
	)


func _on_hud_minimum_size_changed() -> void:
	_fit_hud.call_deferred()


func _fit_hud() -> void:
	# Auto-wrap can initially grow the minimum height before containers assign widths.
	# Reapply the desired size after reflow so a reduced minimum also shrinks this panel.
	var viewport_size := get_viewport().get_visible_rect().size
	_hud_panel.position = Vector2(16.0, 12.0)
	_hud_panel.size = Vector2(maxf(0.0, viewport_size.x - 32.0), 145.0)


func _on_language_changed(_locale: String) -> void:
	_language_error = ""
	_refresh_text()


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= _languages.size():
		return
	var locale := str(_languages[index]["locale"])
	_language_error = ""
	if not Localization.set_language(locale):
		_language_error = Localization.last_error
	_refresh_text()


func _on_reset_pressed() -> void:
	get_parent().reset_training()
	close_menu()


func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19202c")
	style.border_color = Color("3b475a")
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _column(node_name: String, parent: Node, separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _label(
	node_name: String, parent: Node, font_size: int, color: Color = Color("d8e0ea")
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(node_name: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size.y = 40.0
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
