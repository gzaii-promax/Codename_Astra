@tool
class_name MapEntrance
extends Marker2D
## A destination point. Position is the player's foot position in room coordinates.

@export var entrance_id: StringName = &"":
	set(value):
		entrance_id = value
		queue_redraw()
@export var facing_direction: float = 1.0:
	set(value):
		facing_direction = value
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color("65c9b3")
	draw_line(Vector2(-8, 0), Vector2(8, 0), color, 2.0)
	draw_line(Vector2.ZERO, Vector2(0, -32), Color(color, 0.45), 1.0)
	var direction := 1.0 if facing_direction >= 0.0 else -1.0
	draw_line(Vector2(0, -16), Vector2(direction * 12.0, -16), color, 2.0)
	draw_line(Vector2(direction * 12.0, -16), Vector2(direction * 8.0, -20), color, 2.0)
	draw_line(Vector2(direction * 12.0, -16), Vector2(direction * 8.0, -12), color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-20, -36), str(entrance_id), 0, -1, 9, color)
