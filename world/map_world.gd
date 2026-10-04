class_name MapWorld
extends Node2D
## Retains the player while preparing and activating editable room scenes.

signal room_changed(room_id: StringName)

@export var registry: MapRegistry

var current_room: MapRoom
var current_room_id: StringName
var last_error: String = ""
var _visited: Array[StringName] = []
var _changing: bool = false
var _room_generation: int = 0

@onready var player: PlayerCharacter = $Player
@onready var camera: Camera2D = $Camera
@onready var collision_debug: MapCollisionOverlay = $CollisionDebug


func _enter_tree() -> void:
	AttackEffectLifecycle.register_world(self)


func _ready() -> void:
	InputSetup.ensure_actions()
	if registry == null:
		last_error = "World registry is missing."
		return
	var errors := registry.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return
	enter_room(registry.initial_room_id, registry.initial_entrance_id)


func _physics_process(_delta: float) -> void:
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("reset_training"):
		reset_world()
	elif event.is_action_pressed("toggle_fireball_level"):
		player.set_fireball_level(2 if player.fireball_level == 1 else 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F3:
				debug_enter_room(&"room_a")
			KEY_F4:
				debug_enter_room(&"room_b")
			KEY_F5:
				debug_enter_room(&"room_c")
			KEY_F6:
				set_collision_debug(not collision_debug.visible)


func set_collision_debug(enabled: bool) -> void:
	collision_debug.visible = enabled
	collision_debug.queue_redraw()


func enter_room(room_id: StringName, entrance_id: StringName) -> bool:
	if not _can_change_room():
		return false
	var prepared := prepare_room(room_id)
	if prepared == null:
		return false
	return _activate_room(room_id, prepared, entrance_id)


func prepare_room(room_id: StringName) -> MapRoom:
	# Prepared scenes remain off-tree and disabled. Future loading can run earlier.
	var definition := registry.get_room(room_id) if registry != null else null
	if definition == null or definition.scene == null:
		last_error = "Unknown room: %s" % room_id
		return null
	var node := definition.scene.instantiate()
	if not node is MapRoom:
		last_error = "Room template is not a MapRoom: %s" % room_id
		node.free()
		return null
	var prepared := node as MapRoom
	var errors := prepared.validate_room()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		prepared.free()
		return null
	prepared.process_mode = Node.PROCESS_MODE_DISABLED
	return prepared


func travel(exit_id: StringName) -> bool:
	if not _can_change_room() or registry == null:
		return false
	var connection := registry.get_connection(current_room_id, exit_id)
	if not can_travel(connection):
		last_error = "Exit has no available route: %s" % exit_id
		return false
	return enter_room(connection.to_room_id, connection.entrance_id)


func can_travel(connection: MapConnection) -> bool:
	return (
		connection != null
		and connection.from_room_id == current_room_id
		and (
			connection.required_capability.is_empty()
			or has_capability(connection.required_capability)
		)
	)


func has_capability(_capability: StringName) -> bool:
	# Movement abilities are supplied by a later skill integration, not by rooms.
	return false


func debug_enter_room(room_id: StringName) -> bool:
	return enter_room(room_id, &"start")


func get_room_title() -> String:
	var definition := registry.get_room(current_room_id) if registry != null else null
	return Localization.text(definition.title_key) if definition != null else ""


func get_visited_rooms() -> Array[StringName]:
	return _visited.duplicate()


func has_visited(room_id: StringName) -> bool:
	return room_id in _visited


func reset_world() -> void:
	if registry == null or _changing:
		return
	var prepared := prepare_room(registry.initial_room_id)
	if prepared == null:
		return
	if prepared.get_entrance(registry.initial_entrance_id) == null:
		last_error = "Initial entrance is missing."
		prepared.free()
		return
	_visited.clear()
	player.reset_state(player.global_position)
	_activate_room(registry.initial_room_id, prepared, registry.initial_entrance_id)


func _can_change_room() -> bool:
	return (
		not _changing
		and is_instance_valid(player)
		and player.combatant.life_state == Combatant.LifeState.ACTIVE
		and not get_tree().paused
	)


func _activate_room(room_id: StringName, prepared: MapRoom, entrance_id: StringName) -> bool:
	var entrance := prepared.get_entrance(entrance_id)
	if entrance == null:
		last_error = "Missing entrance: %s/%s" % [room_id, entrance_id]
		prepared.free()
		return false
	_changing = true
	_clear_effects()
	if is_instance_valid(current_room):
		remove_child(current_room)
		current_room.queue_free()
	current_room = prepared
	current_room_id = room_id
	_room_generation += 1
	add_child(current_room)
	move_child(current_room, 0)
	for exit in current_room.get_exits():
		exit.enabled = registry.get_connection(room_id, exit.exit_id) != null
		exit.visible = exit.enabled
		exit.exit_requested.connect(_queue_exit.bind(room_id, _room_generation))
	player.relocate_to(entrance.global_position, entrance.facing_direction)
	current_room.process_mode = Node.PROCESS_MODE_INHERIT
	if room_id not in _visited:
		_visited.append(room_id)
	last_error = ""
	_update_camera()
	camera.reset_smoothing()
	camera.force_update_scroll()
	_changing = false
	room_changed.emit(room_id)
	return true


func _queue_exit(exit_id: StringName, source_room_id: StringName, generation: int) -> void:
	_travel_if_current.call_deferred(exit_id, source_room_id, generation)


func _travel_if_current(exit_id: StringName, source_room_id: StringName, generation: int) -> void:
	if source_room_id == current_room_id and generation == _room_generation:
		travel(exit_id)


func _clear_effects() -> void:
	AttackEffectLifecycle.clear_world(self)


func _update_camera() -> void:
	if not is_instance_valid(current_room) or not is_instance_valid(player):
		return
	var bounds := current_room.bounds
	var visible_size := get_viewport_rect().size / camera.zoom
	# The top HUD uses 160 logical screen pixels; clamp the remaining map view.
	var hud_offset := Vector2(0.0, 80.0) / camera.zoom
	var available := visible_size - Vector2(0.0, 160.0) / camera.zoom
	var half := available * 0.5
	var center := player.global_position
	for axis in range(2):
		if bounds.size[axis] <= available[axis]:
			center[axis] = bounds.get_center()[axis]
		else:
			center[axis] = clampf(
				center[axis], bounds.position[axis] + half[axis], bounds.end[axis] - half[axis]
			)
	camera.position = center - hud_offset
