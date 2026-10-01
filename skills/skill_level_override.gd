class_name SkillLevelOverride
extends Resource
## Values are incremental: omitted fields inherit the preceding level.

@export_range(1, 99, 1) var level: int = 2
@export var values: Dictionary = {}
