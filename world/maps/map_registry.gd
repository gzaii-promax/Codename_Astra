class_name MapRegistry
extends Resource
## Editable world catalog. Scene paths never serve as exploration identities.

@export var rooms: Array[MapRoomDefinition] = []
@export var connections: Array[MapConnection] = []
@export var initial_room_id: StringName = &"room_a"
@export var initial_entrance_id: StringName = &"start"


func get_room(room_id: StringName) -> MapRoomDefinition:
	for definition in rooms:
		if definition != null and definition.room_id == room_id:
			return definition
	return null


func get_connection(room_id: StringName, exit_id: StringName) -> MapConnection:
	for connection in connections:
		if (
			connection != null
			and connection.from_room_id == room_id
			and connection.exit_id == exit_id
		):
			return connection
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var templates: Dictionary = {}
	for definition in rooms:
		if definition == null or definition.room_id.is_empty() or definition.scene == null:
			errors.append("Room requires an identity and a scene.")
			continue
		if templates.has(definition.room_id):
			errors.append("Duplicate room: %s" % definition.room_id)
			continue
		var node := definition.scene.instantiate()
		if not node is MapRoom:
			errors.append("Room scene requires MapRoom: %s" % definition.room_id)
			node.free()
			continue
		var room := node as MapRoom
		templates[definition.room_id] = room
		for error in room.validate_room():
			errors.append("%s: %s" % [definition.room_id, error])
	if not templates.has(initial_room_id):
		errors.append("Initial room is missing.")
	elif (templates[initial_room_id] as MapRoom).get_entrance(initial_entrance_id) == null:
		errors.append("Initial entrance is missing.")
	var sources: Dictionary = {}
	for connection in connections:
		_validate_connection(connection, templates, sources, errors)
	for room in templates.values():
		(room as MapRoom).free()
	return errors


func _validate_connection(
	connection: MapConnection, templates: Dictionary, sources: Dictionary, errors: PackedStringArray
) -> void:
	if connection == null:
		errors.append("Null connection.")
		return
	if not templates.has(connection.from_room_id) or not templates.has(connection.to_room_id):
		errors.append("Connection references a missing room.")
		return
	var from_room := templates[connection.from_room_id] as MapRoom
	var to_room := templates[connection.to_room_id] as MapRoom
	if from_room.get_exit(connection.exit_id) == null:
		errors.append("Connection references a missing exit: %s" % connection.exit_id)
	if to_room.get_entrance(connection.entrance_id) == null:
		errors.append("Connection references a missing entrance: %s" % connection.entrance_id)
	var exits: Dictionary = sources.get(connection.from_room_id, {})
	if exits.has(connection.exit_id):
		errors.append(
			"Duplicate source exit: %s/%s" % [connection.from_room_id, connection.exit_id]
		)
	exits[connection.exit_id] = true
	sources[connection.from_room_id] = exits
