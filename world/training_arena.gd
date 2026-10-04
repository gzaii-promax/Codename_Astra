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

@onready var player: PlayerCharacter = $Player
@onready var dummy: TrainingDummy = $TrainingDummy
@onready var enemy: PeriodicEnemy = $PeriodicEnemy


func _enter_tree() -> void:
	AttackEffectLifecycle.register_world(self)
	InputSetup.ensure_actions()


func _ready() -> void:
	Localization.language_changed.connect(_on_language_changed)
	var geometry := Node2D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	move_child(geometry, 0)
	player.position = PLAYER_SPAWN
	dummy.position = DUMMY_SPAWN
	enemy.position = ENEMY_SPAWN
	var solids := [
		[Rect2(0, 15, 32, 1), Color("3e4652"), "Floor"],
		[Rect2(0, 1, 1, 14), Color("3e4652"), "LeftWall"],
		[Rect2(31, 1, 1, 14), Color("3e4652"), "RightWall"],
		[Rect2(0, 0, 32, 1), Color("3e4652"), "Ceiling"],
		[Rect2(8, 14, 4, 0.5), Color("56606c"), "Step"],
		[Rect2(13, 13, 3, 0.5), Color("56606c"), "Platform"],
	]
	for solid in solids:
		var unit_rect: Rect2 = solid[0]
		var pixel_rect := Rect2(ARENA_ORIGIN + unit_rect.position * UNIT, unit_rect.size * UNIT)
		geometry.add_child(GrayboxSolid.create(pixel_rect, solid[1], solid[2]))
	queue_redraw()


func _on_language_changed(_locale: String) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_training"):
		reset_training()
	elif event.is_action_pressed("toggle_fireball_level"):
		player.set_fireball_level(2 if player.fireball_level == 1 else 1)


func reset_training() -> void:
	AttackEffectLifecycle.clear_world(self)
	player.reset_state(PLAYER_SPAWN)
	enemy.reset_state(ENEMY_SPAWN)
	dummy.reset_stats()


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
	draw_line(DUMMY_SPAWN - Vector2(UNIT, 0), DUMMY_SPAWN + Vector2(UNIT, 0), Color("d1aa6a"), 3.0)
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
		DUMMY_SPAWN + Vector2(-48, 36),
		Localization.text("arena.target"),
		HORIZONTAL_ALIGNMENT_CENTER,
		96,
		12,
		Color("c6af85")
	)
	draw_string(
		font,
		ENEMY_SPAWN + Vector2(-48, 36),
		Localization.text("arena.enemy"),
		HORIZONTAL_ALIGNMENT_CENTER,
		96,
		12,
		Color("d78d91")
	)
