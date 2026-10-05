class_name WorldDebugInput
extends Node
## Scene-local debug commands use explicit bindings, independent of the host's child names.

@export var enabled: bool = true
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Node2D") var world_path: NodePath
@export_node_path("Node2D") var collision_overlay_path: NodePath
@export var room_shortcuts: Dictionary[int, StringName] = {}
@export var collision_key: Key = KEY_F6

var last_error: String = ""


func _ready() -> void:
	last_error = "\n".join(validate_bindings())


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or get_tree().paused:
		return
	last_error = "\n".join(validate_bindings())
	if not last_error.is_empty():
		return
	var player := _player()
	if event.is_action_pressed("toggle_fireball_level"):
		player.set_fireball_level(2 if player.fireball_level == 1 else 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		if room_shortcuts.has(event.physical_keycode):
			get_node(world_path).call("debug_enter_room", room_shortcuts[event.physical_keycode])
		elif event.physical_keycode == collision_key and not collision_overlay_path.is_empty():
			var overlay := get_node(collision_overlay_path) as MapCollisionOverlay
			overlay.visible = not overlay.visible
			overlay.queue_redraw()


func validate_bindings() -> Array[String]:
	var errors: Array[String] = []
	if _player() == null:
		errors.append("player_path '%s' must point to a PlayerCharacter" % player_path)
	if not room_shortcuts.is_empty():
		var world := get_node_or_null(world_path) if not world_path.is_empty() else null
		if world == null or not world.has_method("debug_enter_room"):
			errors.append("world_path '%s' must provide debug_enter_room" % world_path)
		for key in room_shortcuts:
			if key <= 0 or room_shortcuts[key].is_empty():
				errors.append("room_shortcuts must map positive physical keys to nonempty room IDs")
		if room_shortcuts.has(collision_key) and not collision_overlay_path.is_empty():
			errors.append("room_shortcuts must not override the collision toggle key")
	if not collision_overlay_path.is_empty():
		if not get_node_or_null(collision_overlay_path) is MapCollisionOverlay:
			errors.append(
				(
					"collision_overlay_path '%s' must point to a MapCollisionOverlay"
					% collision_overlay_path
				)
			)
		if collision_key <= 0:
			errors.append("collision_key must be a positive physical key")
	return errors


func _player() -> PlayerCharacter:
	return get_node_or_null(player_path) as PlayerCharacter if not player_path.is_empty() else null
