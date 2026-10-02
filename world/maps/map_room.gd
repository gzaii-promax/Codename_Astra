@tool
class_name MapRoom
extends Node2D
## Editable room scene. Geometry, entrances and exits are authored in the scene.

@export var bounds := Rect2(0, 0, 512, 256):
	set(value):
		bounds = value
		queue_redraw()


func get_entrance(id: StringName) -> MapEntrance:
	for entrance in get_entrances():
		if entrance.entrance_id == id:
			return entrance
	return null


func get_exit(id: StringName) -> MapExit:
	for exit in get_exits():
		if exit.exit_id == id:
			return exit
	return null


func get_entrances() -> Array[MapEntrance]:
	var result: Array[MapEntrance] = []
	_collect_entrances(self, result)
	return result


func get_exits() -> Array[MapExit]:
	var result: Array[MapExit] = []
	_collect_exits(self, result)
	return result


func validate_room() -> PackedStringArray:
	var errors := PackedStringArray()
	if not bounds.position.is_finite() or not bounds.size.is_finite():
		errors.append("Room bounds must be finite")
	elif bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		errors.append("Room bounds must have positive dimensions")
	var entrance_ids: Dictionary = {}
	for entrance in get_entrances():
		if entrance.entrance_id == &"":
			errors.append("Entrance ID must not be empty")
		elif entrance_ids.has(entrance.entrance_id):
			errors.append("Duplicate entrance ID: %s" % entrance.entrance_id)
		entrance_ids[entrance.entrance_id] = true
		var point := _position_in_room(entrance)
		if not point.is_finite() or not bounds.has_point(point):
			errors.append("Entrance is outside room bounds: %s" % entrance.entrance_id)
		if entrance.facing_direction not in [-1.0, 1.0]:
			errors.append("Entrance facing must be -1 or 1: %s" % entrance.entrance_id)
	var exit_ids: Dictionary = {}
	for exit in get_exits():
		if exit.exit_id == &"":
			errors.append("Exit ID must not be empty")
		elif exit_ids.has(exit.exit_id):
			errors.append("Duplicate exit ID: %s" % exit.exit_id)
		exit_ids[exit.exit_id] = true
	return errors


func _collect_entrances(node: Node, result: Array[MapEntrance]) -> void:
	for child in node.get_children():
		if child is MapEntrance:
			result.append(child as MapEntrance)
		_collect_entrances(child, result)


func _collect_exits(node: Node, result: Array[MapExit]) -> void:
	for child in node.get_children():
		if child is MapExit:
			result.append(child as MapExit)
		_collect_exits(child, result)


func _position_in_room(node: Node2D) -> Vector2:
	var result := node.position
	var ancestor := node.get_parent()
	while ancestor != self and ancestor != null:
		if ancestor is Node2D:
			result = (ancestor as Node2D).transform * result
		ancestor = ancestor.get_parent()
	return result


func _draw() -> void:
	draw_rect(bounds, Color("18202d"))
	var unit := 16.0
	var color := Color(0.6, 0.68, 0.8, 0.075)
	for column in range(1, ceili(bounds.size.x / unit)):
		var x := bounds.position.x + column * unit
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), color)
	for row in range(1, ceili(bounds.size.y / unit)):
		var y := bounds.position.y + row * unit
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), color)
