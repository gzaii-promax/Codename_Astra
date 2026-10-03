extends RefCounted
## Test-owned expectations. This helper never reads production scripts or resources.

const PATH := "res://tests/baselines/design-v1.json"


static func load_values() -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATH)) != OK:
		return {}
	if not parser.data is Dictionary:
		return {}
	return parser.data


static func vector(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


static func rectangle(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
