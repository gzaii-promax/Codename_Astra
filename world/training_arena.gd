class_name TrainingArena
extends Node2D

const UNIT: float = GameUnits.PIXELS_PER_UNIT
const ARENA_ORIGIN := Vector2(224.0, 200.0)
const ARENA_WIDTH: float = 32.0 * UNIT
const ARENA_HEIGHT: float = 16.0 * UNIT
const FLOOR_Y: float = 15.0 * UNIT + ARENA_ORIGIN.y
const PLAYER_SPAWN := ARENA_ORIGIN + Vector2(3.0, 15.0) * UNIT
const DUMMY_SPAWN := ARENA_ORIGIN + Vector2(20.0, 15.0) * UNIT
const ENEMY_SPAWN := ARENA_ORIGIN + Vector2(27.0, 15.0) * UNIT

@export_group("Spawn markers")
@export_node_path("Marker2D") var player_spawn_path: NodePath = ^"Spawns/Player"
@export_node_path("Marker2D") var dummy_spawn_path: NodePath = ^"Spawns/TrainingDummy"
@export_node_path("Marker2D") var enemy_spawn_path: NodePath = ^"Spawns/PeriodicEnemy"

var last_error: String = ""

@onready var player: PlayerCharacter = $Player
@onready var dummy: TrainingDummy = $TrainingDummy
@onready var enemy: PeriodicEnemy = $PeriodicEnemy


func _enter_tree() -> void:
	AttackEffectLifecycle.register_world(self)
	InputSetup.ensure_actions()


func _ready() -> void:
	Localization.language_changed.connect(_on_language_changed)
	if not _check_spawns():
		return
	player.global_position = _spawn(player_spawn_path).global_position
	dummy.global_position = _spawn(dummy_spawn_path).global_position
	enemy.global_position = _spawn(enemy_spawn_path).global_position
	queue_redraw()


func _on_language_changed(_locale: String) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("reset_training"):
		reset_training()


func reset_training() -> void:
	if not _check_spawns():
		return
	# Capture configured positions before synchronous health/reset callbacks run.
	var player_spawn := _spawn(player_spawn_path).global_position
	var enemy_spawn := _spawn(enemy_spawn_path).global_position
	AttackEffectLifecycle.clear_world(self)
	player.reset_state(player_spawn)
	enemy.reset_state(enemy_spawn)
	dummy.reset_stats()
	queue_redraw()


func validate_spawns() -> Array[String]:
	var errors: Array[String] = []
	for property in ["player_spawn_path", "dummy_spawn_path", "enemy_spawn_path"]:
		var path: NodePath = get(property)
		var marker := _spawn(path)
		if marker == null:
			errors.append("%s '%s' must point to a Marker2D" % [property, path])
		elif not marker.global_transform.is_finite():
			errors.append("%s marker must have a finite transform" % property)
	return errors


func _check_spawns() -> bool:
	last_error = "\n".join(validate_spawns())
	return last_error.is_empty()


func _spawn(path: NodePath) -> Marker2D:
	return get_node_or_null(path) as Marker2D if not path.is_empty() else null


func _draw() -> void:
	draw_rect(Rect2(ARENA_ORIGIN, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), Color("171d28"))
	for column in range(1, 32):
		var x := ARENA_ORIGIN.x + column * UNIT
		draw_line(
			Vector2(x, ARENA_ORIGIN.y + UNIT), Vector2(x, FLOOR_Y), Color(0.6, 0.65, 0.7, 0.1)
		)
	for row in range(1, 15):
		var y := ARENA_ORIGIN.y + row * UNIT
		draw_line(
			Vector2(ARENA_ORIGIN.x + UNIT, y),
			Vector2(ARENA_ORIGIN.x + 31 * UNIT, y),
			Color(0.6, 0.65, 0.7, 0.1)
		)
	draw_line(
		Vector2(ARENA_ORIGIN.x + UNIT, FLOOR_Y - 1),
		Vector2(ARENA_ORIGIN.x + 31 * UNIT, FLOOR_Y - 1),
		Color("8392a2"),
		2.0
	)
	var dummy_spawn := _spawn(dummy_spawn_path)
	var enemy_spawn := _spawn(enemy_spawn_path)
	if dummy_spawn == null or enemy_spawn == null or not validate_spawns().is_empty():
		return
	var dummy_anchor := to_local(dummy_spawn.global_position)
	var enemy_anchor := to_local(enemy_spawn.global_position)
	draw_line(
		dummy_anchor - Vector2(UNIT, 0), dummy_anchor + Vector2(UNIT, 0), Color("d1aa6a"), 3.0
	)
	var font := Localization.get_font()
	draw_string(
		font,
		Vector2(ARENA_ORIGIN.x, 496),
		Localization.text("arena.room"),
		0,
		ARENA_WIDTH,
		14,
		Color("8a96a8")
	)
	draw_string(
		font,
		dummy_anchor + Vector2(-48, 36),
		Localization.text("arena.target"),
		HORIZONTAL_ALIGNMENT_CENTER,
		96,
		12,
		Color("c6af85")
	)
	draw_string(
		font,
		enemy_anchor + Vector2(-48, 36),
		Localization.text("arena.enemy"),
		HORIZONTAL_ALIGNMENT_CENTER,
		96,
		12,
		Color("d78d91")
	)
