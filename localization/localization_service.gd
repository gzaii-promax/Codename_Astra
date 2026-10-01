class_name LocalizationService
extends Node
## Owns only its Translation resources. UI and future dialogue use text(key, args).

signal language_changed(locale: String)

const DEFAULT_MANIFEST_PATH := "res://localization/languages.json"
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "localization"
const SETTINGS_KEY := "language"
const SettingsStore := preload("res://localization/settings_store.gd")

var current_language: String = "zh_CN"
var last_error: String = ""

var _initialized: bool = false
var _default_language: String = "zh_CN"
var _manifest_path: String = ""
var _settings_path: String = ""
var _languages: Array[Dictionary] = []
var _translations: Dictionary = {}
var _registered_translations: Array[Translation] = []
var _fonts: Dictionary = {}


func _ready() -> void:
	if not _initialized:
		initialize(OS.get_environment("ASTRA_SETTINGS_PATH"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for translation in _registered_translations:
			TranslationServer.remove_translation(translation)
		_registered_translations.clear()


func initialize(settings_path_override: String = "", manifest_path_override: String = "") -> bool:
	var settings_path := (
		DEFAULT_SETTINGS_PATH if settings_path_override.is_empty() else settings_path_override
	)
	var manifest_path := (
		DEFAULT_MANIFEST_PATH if manifest_path_override.is_empty() else manifest_path_override
	)
	if _initialized:
		if settings_path != _settings_path or manifest_path != _manifest_path:
			last_error = "Localization is already initialized with different paths"
			return false
		return true
	last_error = ""
	_settings_path = settings_path
	_manifest_path = manifest_path
	_languages.clear()
	_translations.clear()
	_fonts.clear()
	if not _load_manifest() or not _load_catalogs():
		return false
	current_language = _read_saved_language()
	for translation: Translation in _translations.values():
		TranslationServer.add_translation(translation)
		_registered_translations.append(translation)
	_initialized = true
	TranslationServer.set_locale(current_language)
	language_changed.emit(current_language)
	return true


func available_languages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for language in _languages:
		result.append(
			{"locale": language["locale"], "name": language["name"], "font": language["font"]}
		)
	return result


func get_settings_path() -> String:
	return _settings_path


func set_language(locale: String, persist: bool = true) -> bool:
	last_error = ""
	if not _initialized:
		last_error = "Localization is not initialized"
		return false
	if not _translations.has(locale):
		last_error = "Unsupported language: %s" % locale
		return false
	if persist and not _save_language(locale):
		return false
	if current_language != locale:
		current_language = locale
		TranslationServer.set_locale(locale)
		language_changed.emit(locale)
	return true


func text(key: String, args: Dictionary = {}) -> String:
	var message := _get_message(current_language, key)
	if message.is_empty():
		message = _get_message(_default_language, key)
	if message.is_empty():
		return key
	return message.format(args)


func get_font() -> Font:
	if _fonts.has(current_language):
		return _fonts[current_language] as Font
	var font_path := ""
	for language in _languages:
		if language["locale"] == current_language:
			font_path = language["font"]
			break
	var font: Font
	if not font_path.is_empty() and ResourceLoader.exists(font_path):
		font = load(font_path) as Font
		if font is FontFile:
			(font as FontFile).allow_system_fallback = false
	_fonts[current_language] = font
	return font


func _load_manifest() -> bool:
	var parsed: Variant = _read_json_dictionary(_manifest_path)
	if parsed == null:
		return false
	var manifest: Dictionary = parsed
	if manifest.get("schema_version") != 1 or not manifest.get("languages") is Array:
		last_error = "Invalid language manifest schema: %s" % _manifest_path
		return false
	var default_locale: Variant = manifest.get("default_language")
	if not default_locale is String or str(default_locale).is_empty():
		last_error = "Manifest requires a nonempty default_language"
		return false
	_default_language = default_locale
	var seen: Dictionary = {}
	for entry: Variant in manifest["languages"]:
		if not _append_language(entry, seen):
			return false
	if _languages.is_empty() or not seen.has(_default_language):
		last_error = "Manifest does not contain its default language"
		return false
	return true


func _append_language(entry: Variant, seen: Dictionary) -> bool:
	if not entry is Dictionary:
		last_error = "Every language manifest entry must be an object"
		return false
	for field in ["locale", "name", "catalog", "font"]:
		if not entry.get(field) is String:
			last_error = "Language entry requires string field: %s" % field
			return false
	var locale := str(entry["locale"])
	if locale.is_empty() or str(entry["name"]).is_empty() or str(entry["catalog"]).is_empty():
		last_error = "Language locale, name and catalog must not be empty"
		return false
	if seen.has(locale):
		last_error = "Duplicate language locale: %s" % locale
		return false
	seen[locale] = true
	(
		_languages
		. append(
			{
				"locale": locale,
				"name": entry["name"],
				"catalog": _resolve_path(entry["catalog"]),
				"font": _resolve_path(entry["font"]),
			}
		)
	)
	return true


func _load_catalogs() -> bool:
	var diagnostics: Array[String] = []
	for language in _languages:
		var parsed: Variant = _read_json_dictionary(language["catalog"])
		if parsed == null and language["locale"] == _default_language:
			return false
		var translation := Translation.new()
		translation.locale = language["locale"]
		if parsed == null:
			diagnostics.append(last_error)
		else:
			for key: Variant in parsed:
				var value: Variant = parsed[key]
				if not value is String:
					diagnostics.append(
						"Non-string translation skipped: %s / %s" % [language["locale"], key]
					)
				elif not str(value).strip_edges().is_empty():
					translation.add_message(StringName(str(key)), StringName(value))
		_translations[language["locale"]] = translation
	last_error = "\n".join(diagnostics)
	return true


func _read_saved_language() -> String:
	var result: Dictionary = SettingsStore.read_config(_settings_path)
	if not str(result["error"]).is_empty():
		_append_error(result["error"])
		return _default_language
	var config := result["config"] as ConfigFile
	var saved: Variant = config.get_value(SETTINGS_SECTION, SETTINGS_KEY, _default_language)
	if not saved is String or not _translations.has(saved):
		_append_error("Saved language is unsupported; using %s" % _default_language)
		return _default_language
	return saved


func _save_language(locale: String) -> bool:
	var result: Dictionary = SettingsStore.read_config(_settings_path)
	if not str(result["error"]).is_empty():
		last_error = result["error"]
		return false
	var config := result["config"] as ConfigFile
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, locale)
	var error := config.save(_settings_path)
	if error != OK:
		last_error = (
			"Cannot save language settings: %s (%s)" % [_settings_path, error_string(error)]
		)
		return false
	return true


func _get_message(locale: String, key: String) -> String:
	if not _translations.has(locale):
		return ""
	var translation := _translations[locale] as Translation
	return str(translation.get_message(StringName(key)))


func _read_json_dictionary(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = (
			"Cannot read language data: %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		)
		return null
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK or not json.data is Dictionary:
		last_error = (
			"Invalid language JSON: %s, line %d: %s"
			% [path, json.get_error_line(), json.get_error_message()]
		)
		return null
	return json.data


func _resolve_path(path: String) -> String:
	if (
		path.is_empty()
		or path.is_absolute_path()
		or path.begins_with("res://")
		or path.begins_with("user://")
	):
		return path
	return _manifest_path.get_base_dir().path_join(path)


func _append_error(message: String) -> void:
	last_error = message if last_error.is_empty() else last_error + "\n" + message
