extends RefCounted
## ConfigFile owns Variant syntax; this module does not reimplement its parser.


static func read_config(path: String) -> Dictionary:
	var config := ConfigFile.new()
	var result: Dictionary = {"config": config, "error": ""}
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		result["error"] = "Settings path points to a directory: %s" % path
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		if FileAccess.get_open_error() != ERR_FILE_NOT_FOUND:
			result["error"] = (
				"Cannot read settings: %s (%s)" % [path, error_string(FileAccess.get_open_error())]
			)
		return result
	var content := file.get_as_text()
	# Corrupt user data is expected input, not a script failure. Only this synchronous
	# native parse suppresses its redundant console error; its Error is still returned.
	# No await, gameplay, initialization or save runs while this global flag is changed.
	var previous_error_printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var error := config.parse(content)
	Engine.print_error_messages = previous_error_printing
	if error != OK:
		result["error"] = (
			"Cannot parse settings; original file retained: %s (%s, code %d)"
			% [path, error_string(error), error]
		)
	return result
