extends SceneTree
## Two separate engine processes write/read one isolated ConfigFile.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3 or arguments[0] not in ["write", "read"]:
		_finish(false, {"reason": "expected write|read settings_path locale"})
		return
	var mode := arguments[0]
	var settings_path := arguments[1]
	var expected_locale := arguments[2]
	var service := LocalizationService.new()
	if not service.initialize(settings_path):
		_finish(false, {"reason": service.last_error})
		service.free()
		return
	root.add_child(service)
	var restored_locale := service.current_language
	var valid := true
	if mode == "write":
		valid = service.set_language(expected_locale)
	else:
		valid = restored_locale == expected_locale
	var translated := service.text("menu.title")
	valid = valid and service.current_language == expected_locale
	valid = valid and not translated.is_empty() and translated != "menu.title"
	var evidence := {
		"mode": mode,
		"settings_path": settings_path,
		"expected_locale": expected_locale,
		"restored_locale": restored_locale,
		"locale": service.current_language,
		"translated_menu_title": translated,
		"pid": OS.get_process_id(),
		"last_error": service.last_error,
	}
	service.free()
	_finish(valid, evidence)


func _finish(passed: bool, evidence: Dictionary) -> void:
	evidence["scope"] = "localization_restart"
	evidence["status"] = "pass" if passed else "fail"
	print("LOCALIZATION_RESTART=" + JSON.stringify(evidence))
	quit(0 if passed else 1)
