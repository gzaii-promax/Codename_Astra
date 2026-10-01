class_name SkillDefinition
extends Resource
## Inspector-visible base values. resolve_level() creates an independent runtime definition.

const NUMERIC_FIELDS: Array[String] = [
	"damage",
	"knockback",
	"windup_seconds",
	"active_seconds",
	"recovery_seconds",
	"cooldown_seconds",
	"projectile_speed",
	"projectile_lifetime",
	"projectile_range",
	"melee_reach",
	"melee_height",
]
const POLICY_NAMES: Array[String] = ["windup_policy", "active_policy", "recovery_policy"]
const POLICY_NUMBERS: Array[String] = ["control_scale", "inertia_scale"]
const POLICY_FLAGS: Array[String] = ["can_jump", "can_cancel_player", "can_interrupt_hit"]

@export_group("Identity")
@export var id: StringName = &"skill"
@export var name_key: String = ""
@export var description_key: String = ""
@export var damage_type: StringName = &"physical"

@export_group("Hit")
@export_range(0.0, 10000.0, 0.5) var damage: float = 10.0
@export_range(0.0, 2000.0, 1.0) var knockback: float = 0.0

@export_group("Timing (seconds)")
@export_range(0.0, 10.0, 0.01) var windup_seconds: float = 0.1
@export_range(0.0, 10.0, 0.01) var active_seconds: float = 0.1
@export_range(0.0, 10.0, 0.01) var recovery_seconds: float = 0.1
@export_range(0.0, 60.0, 0.01) var cooldown_seconds: float = 0.3

@export_group("Phase rules")
@export var windup_policy: PhasePolicy = PhasePolicy.new()
@export var active_policy: PhasePolicy = PhasePolicy.new()
@export var recovery_policy: PhasePolicy = PhasePolicy.new()

@export_group("Melee (pixels)")
@export_range(1.0, 500.0, 1.0) var melee_reach: float = 48.0
@export_range(1.0, 500.0, 1.0) var melee_height: float = 42.0

@export_group("Projectile")
@export_range(1.0, 4000.0, 1.0) var projectile_speed: float = 430.0
@export_range(0.01, 30.0, 0.01) var projectile_lifetime: float = 2.0
@export_range(1.0, 10000.0, 1.0) var projectile_range: float = 900.0

@export_group("Progression")
@export var level_overrides: Array[SkillLevelOverride] = []

var resolved_level: int = 1
var resolution_errors: Array[String] = []


func resolve_level(level: int) -> SkillDefinition:
	var resolved := duplicate(true) as SkillDefinition
	resolved.resolved_level = maxi(1, level)
	resolved.resolution_errors = []
	if level < 1:
		resolved.resolution_errors.append("requested level must be at least 1")
	var ordered: Array[SkillLevelOverride] = []
	var declared_levels: Dictionary = {}
	for override in level_overrides:
		if override == null:
			resolved.resolution_errors.append("level override must not be null")
			continue
		if override.level < 1 or declared_levels.has(override.level):
			resolved.resolution_errors.append("override levels must be unique positive integers")
		declared_levels[override.level] = true
		if override.level <= resolved.resolved_level:
			ordered.append(override)
	ordered.sort_custom(
		func(a: SkillLevelOverride, b: SkillLevelOverride): return a.level < b.level
	)
	for override in ordered:
		for key in override.values:
			resolved._apply_override(str(key), override.values[key])
	resolved.resolution_errors.append_array(resolved.validate())
	return resolved


func validate() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id must not be empty")
	for field in NUMERIC_FIELDS:
		var value := float(get(field))
		if not is_finite(value) or value < 0.0:
			errors.append("%s must be finite and nonnegative" % field)
	for field in [
		"melee_reach", "melee_height", "projectile_speed", "projectile_lifetime", "projectile_range"
	]:
		if float(get(field)) <= 0.0:
			errors.append("%s must be positive" % field)
	for policy_name in POLICY_NAMES:
		var policy := get(policy_name) as PhasePolicy
		if policy == null:
			errors.append("%s must be configured" % policy_name)
		else:
			for error in policy.validate():
				errors.append("%s.%s" % [policy_name, error])
	return errors


func get_resolved_attributes() -> Dictionary:
	var attributes: Dictionary = {
		"id": id, "name_key": name_key, "description_key": description_key, "level": resolved_level
	}
	for field in NUMERIC_FIELDS:
		attributes[field] = get(field)
	attributes["damage_type"] = damage_type
	for policy_name in POLICY_NAMES:
		var policy := get(policy_name) as PhasePolicy
		attributes[policy_name] = policy.as_dictionary() if policy != null else {}
	return attributes


func _apply_override(field: String, value: Variant) -> void:
	if field in NUMERIC_FIELDS:
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			set(field, float(value))
		else:
			resolution_errors.append("%s override must be numeric" % field)
		return
	var parts := field.split(".")
	if parts.size() != 2 or parts[0] not in POLICY_NAMES:
		resolution_errors.append("unsupported override field: %s" % field)
		return
	var policy := get(parts[0]) as PhasePolicy
	if policy == null:
		resolution_errors.append("%s override requires a phase policy" % field)
		return
	if parts[1] in POLICY_NUMBERS and (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT):
		policy.set(parts[1], float(value))
	elif parts[1] in POLICY_FLAGS and typeof(value) == TYPE_BOOL:
		policy.set(parts[1], value)
	elif parts[1] == "skill_velocity" and typeof(value) == TYPE_VECTOR2:
		policy.skill_velocity = value
	else:
		resolution_errors.append("unsupported or mistyped override field: %s" % field)
