extends GutTest

const FIXTURE_MANIFEST := "res://tests/fixtures/localization/languages.json"
const INVALID_MANIFEST := "res://tests/fixtures/localization/invalid_manifest.json"
const BROKEN_CATALOG_MANIFEST := "res://tests/fixtures/localization/languages_broken_catalog.json"
const PRODUCTION_MANIFEST := "res://localization/languages.json"
const TEMP_DIRECTORY := "user://automated_test_settings"

var _temporary_paths: Array[String] = []
var _original_error_printing: bool = true


func before_each() -> void:
	_original_error_printing = Engine.print_error_messages


func after_each() -> void:
	Engine.print_error_messages = _original_error_printing
	for filename in _temporary_paths:
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	_temporary_paths.clear()


func test_language_manifest_supports_a_fourth_locale_without_code_changes() -> void:
	var service := _service(_settings_path())
	var locales: Array[String] = []
	for language in service.available_languages():
		locales.append(language["locale"])
	assert_eq(locales, ["en", "ja", "zh_CN", "fr"])
	assert_true(service.set_language("fr", false))
	assert_eq(service.text("greeting", {"name": "Ada"}), "Bonjour Ada.")
	assert_eq(service.text("fallback.absent"), "Default missing-entry text")


func test_language_selection_persists_and_a_new_service_restores_it() -> void:
	var filename := _settings_path()
	var unrelated := ConfigFile.new()
	unrelated.set_value("other_module", "keep", "independent setting")
	assert_eq(unrelated.save(filename), OK)
	var first := _service(filename)
	watch_signals(first)
	assert_true(first.set_language("ja"))
	assert_signal_emitted(first, "language_changed")
	assert_true(FileAccess.file_exists(filename))
	var second := _service(filename)
	assert_eq(second.current_language, "ja", "A newly constructed service restores saved choice")
	assert_eq(second.text("greeting", {"name": "Ada"}), "こんにちは、Ada。")
	var restored := ConfigFile.new()
	assert_eq(restored.load(filename), OK)
	assert_eq(restored.get_value("other_module", "keep"), "independent setting")


func test_missing_empty_and_whitespace_translations_fall_back_to_default() -> void:
	var service := _service(_settings_path())
	assert_true(service.set_language("ja", false))
	assert_eq(service.text("fallback.absent"), "Default missing-entry text")
	assert_eq(service.text("fallback.empty"), "Default empty-entry text")
	assert_eq(service.text("fallback.whitespace"), "Default whitespace-entry text")
	assert_eq(service.text("totally.unknown.key"), "totally.unknown.key")
	assert_eq(service.text("unknown.{name}", {"name": "Ada"}), "unknown.{name}")


func test_named_placeholders_substitute_values_and_preserve_missing_arguments() -> void:
	var service := _service(_settings_path())
	assert_eq(
		service.text("skill.damage", {"damage": 42, "seconds": 0.5}), "Damage: 42; windup: 0.5s"
	)
	assert_eq(service.text("args.required", {"name": "Ada"}), "Hello Ada; unknown {missing}.")
	assert_true(service.set_language("zh_CN", false))
	assert_eq(service.text("greeting", {"name": "Ada"}), "你好，Ada。")


func test_unknown_locale_does_not_change_state_or_saved_preference() -> void:
	var filename := _settings_path()
	var service := _service(filename)
	assert_true(service.set_language("ja"))
	var saved := FileAccess.get_file_as_string(filename)
	assert_false(service.set_language("does_not_exist"))
	assert_eq(service.current_language, "ja")
	assert_eq(FileAccess.get_file_as_string(filename), saved)
	assert_false(service.last_error.is_empty())


func test_failed_settings_save_preserves_current_language() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIRECTORY))
	var service := _service(TEMP_DIRECTORY)
	var initial: String = service.current_language
	assert_false(service.set_language("ja"), "Existing directory cannot be a settings file")
	assert_eq(service.current_language, initial)
	assert_false(service.last_error.is_empty())


func test_corrupt_settings_and_unsupported_saved_locale_use_default_with_diagnostics() -> void:
	var corrupt_path := _settings_path()
	var invalid_content := "[localization\nlanguage=unclosed malformed setting"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string(invalid_content)
	file.close()
	var corrupt := _service(corrupt_path)
	assert_eq(corrupt.current_language, "en")
	assert_false(corrupt.last_error.is_empty())
	assert_eq(Engine.print_error_messages, _original_error_printing)
	assert_false(corrupt.set_language("ja"), "Invalid settings are not overwritten by a new choice")
	assert_eq(corrupt.current_language, "en")
	assert_eq(FileAccess.get_file_as_string(corrupt_path), invalid_content)
	assert_eq(
		Engine.print_error_messages, _original_error_printing, "Bad save restores error printing"
	)
	Engine.print_error_messages = false
	var silent_corrupt := _service(corrupt_path)
	var restored_flag := Engine.print_error_messages
	Engine.print_error_messages = _original_error_printing
	assert_false(restored_flag, "Local parse preserves an already-disabled error printing flag")
	assert_false(silent_corrupt.last_error.is_empty())
	var unknown_path := _settings_path()
	var config := ConfigFile.new()
	config.set_value("localization", "language", "unsupported_saved_locale")
	assert_eq(config.save(unknown_path), OK)
	var unknown := _service(unknown_path)
	assert_eq(unknown.current_language, "en")
	assert_false(unknown.last_error.is_empty())


func test_invalid_manifest_is_rejected_with_a_readable_diagnostic() -> void:
	var service := LocalizationService.new()
	autofree(service)
	assert_false(service.initialize(_settings_path(), INVALID_MANIFEST))
	assert_false(service.last_error.is_empty())


func test_broken_optional_catalog_falls_back_without_engine_errors() -> void:
	var service := LocalizationService.new()
	autofree(service)
	assert_true(service.initialize(_settings_path(), BROKEN_CATALOG_MANIFEST))
	assert_false(service.last_error.is_empty())
	assert_true(service.set_language("de", false))
	assert_eq(service.text("greeting", {"name": "Ada"}), "Hello Ada.")


func test_initialize_is_idempotent_and_cannot_silently_change_storage_path() -> void:
	var filename := _settings_path()
	var service := _service(filename)
	assert_true(service.set_language("ja", false))
	assert_true(service.initialize(filename, FIXTURE_MANIFEST))
	assert_eq(service.current_language, "ja")
	assert_false(service.initialize(_settings_path(), FIXTURE_MANIFEST))
	assert_eq(service.current_language, "ja")


func test_production_catalogs_cover_three_languages_and_all_declared_strings() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PRODUCTION_MANIFEST))
	var expected_keys: Array[String] = []
	var catalogs: Dictionary = {}
	var locales: Array[String] = []
	for language in manifest["languages"]:
		var locale: String = language["locale"]
		locales.append(locale)
		var catalog: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(language["catalog"])
		)
		catalogs[locale] = catalog
		for key in catalog:
			if key not in expected_keys:
				expected_keys.append(key)
	assert_gte(locales.size(), 3, "Shipped languages remain available when new locales are added")
	for locale in ["en", "ja", "zh_CN"]:
		assert_true(locales.has(locale))
		var missing: Array[String] = []
		for key in expected_keys:
			if not catalogs[locale].has(key) or str(catalogs[locale][key]).strip_edges().is_empty():
				missing.append(key)
		assert_eq(missing, [], "Every shipped text has a nonempty %s translation" % locale)
		for key in expected_keys:
			assert_eq(
				_placeholder_names(str(catalogs[locale].get(key, ""))),
				_placeholder_names(str(catalogs["en"].get(key, ""))),
				"Named arguments remain compatible: %s / %s" % [locale, key]
			)
	assert_gt(
		expected_keys.size(), 15, "Actual UI and help corpus is checked, not an empty catalog"
	)


func test_bundled_fonts_have_glyphs_for_the_entire_three_language_corpus() -> void:
	var service := LocalizationService.new()
	autofree(service)
	assert_true(service.initialize(_settings_path(), PRODUCTION_MANIFEST))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PRODUCTION_MANIFEST))
	for language in manifest["languages"]:
		var locale: String = language["locale"]
		assert_true(service.set_language(locale, false))
		var font: Font = service.get_font()
		assert_not_null(font, "Bundled font is loaded for %s" % locale)
		if font == null:
			continue
		var font_file := font as FontFile
		assert_not_null(font_file)
		if font_file == null:
			continue
		assert_false(font_file.allow_system_fallback, "Glyph coverage uses bundled font only")
		var catalog: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(language["catalog"])
		)
		var missing: Array[String] = []
		var checked: Dictionary = {}
		for key in catalog:
			var text: String = catalog[key]
			for index in text.length():
				var code := text.unicode_at(index)
				if code <= 32 or checked.has(code):
					continue
				checked[code] = true
				if not font.has_char(code):
					missing.append("%s U+%04X (%s)" % [text[index], code, key])
		assert_eq(missing, [], "All %s catalog glyphs exist in selected font" % locale)
		assert_gt(checked.size(), 20)


func _service(filename: String) -> LocalizationService:
	var service := LocalizationService.new()
	autofree(service)
	assert_true(service.initialize(filename, FIXTURE_MANIFEST))
	return service


func _settings_path() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIRECTORY))
	var filename := "%s/localization-%d-%d.cfg" % [TEMP_DIRECTORY, Time.get_ticks_usec(), randi()]
	_temporary_paths.append(filename)
	return filename


func _placeholder_names(text: String) -> Array[String]:
	var pattern := RegEx.new()
	pattern.compile("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	var names: Array[String] = []
	for match in pattern.search_all(text):
		var name := match.get_string(1)
		if name not in names:
			names.append(name)
	names.sort()
	return names
