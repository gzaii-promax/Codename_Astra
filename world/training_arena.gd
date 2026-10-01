class_name TrainingArena
extends Node2D

const PLAYER_SPAWN := Vector2(150.0, 430.0)
const ARENA_WIDTH: float = 960.0

@onready var player: PlayerCharacter = $Player
@onready var dummy: TrainingDummy = $TrainingDummy


func _enter_tree() -> void:
	InputSetup.ensure_actions()


func _ready() -> void:
	Localization.language_changed.connect(_on_language_changed)
	var geometry := Node2D.new()
	geometry.name = "Geometry"
	geometry.show_behind_parent = true
	add_child(geometry)
	var solids := [
		[Rect2(0, 430, 960, 110), Color("3e4652"), "Floor"],
		[Rect2(0, 140, 20, 290), Color("3e4652"), "LeftWall"],
		[Rect2(940, 140, 20, 290), Color("3e4652"), "RightWall"],
		[Rect2(275, 366, 145, 18), Color("56606c"), "Step"],
		[Rect2(760, 350, 120, 18), Color("56606c"), "Platform"],
	]
	for solid in solids:
		geometry.add_child(GrayboxSolid.create(solid[0], solid[1], solid[2]))
	queue_redraw()


func _on_language_changed(_locale: String) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_training"):
		reset_training()
	elif event.is_action_pressed("toggle_fireball_level"):
		player.set_fireball_level(2 if player.fireball_level == 1 else 1)


func reset_training() -> void:
	for child in get_children():
		if child is Fireball or child is MeleeStrike:
			child.set_physics_process(false)
			child.queue_free()
	player.reset_state(PLAYER_SPAWN)
	dummy.reset_stats()


func _draw() -> void:
	for x in range(20, 960, 40):
		draw_line(Vector2(x, 168), Vector2(x, 430), Color(0.6, 0.65, 0.7, 0.04))
	for y in range(190, 430, 40):
		draw_line(Vector2(20, y), Vector2(940, y), Color(0.6, 0.65, 0.7, 0.04))
	draw_line(Vector2(20, 429), Vector2(940, 429), Color("8392a2"), 2.0)
	draw_line(Vector2(565, 430), Vector2(725, 430), Color("d1aa6a"), 3.0)
	var font := Localization.get_font()
	draw_string(
		font, Vector2(24, 488), Localization.text("arena.room"), 0, 490, 14, Color("8a96a8")
	)
	draw_string(
		font,
		Vector2(565, 465),
		Localization.text("arena.target"),
		HORIZONTAL_ALIGNMENT_CENTER,
		160,
		12,
		Color("c6af85")
	)
