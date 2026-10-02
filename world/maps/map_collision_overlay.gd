class_name MapCollisionOverlay
extends Node2D
## Runtime debug drawing reads collision resources instead of editor-only debug hints.

const WORLD_COLOR := Color("69a9ed")
const PLAYER_COLOR := Color("7ad99c")
const RECEIVER_COLOR := Color("e8db71")
const EXIT_COLOR := Color("e7b769")
const CIRCLE_SEGMENTS: int = 24


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func collect_debug_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for geometry in _collect_geometry():
		polygons.append(geometry["points"] as PackedVector2Array)
	return polygons


func get_debug_polygon_count() -> int:
	return _collect_geometry().size()


func _collect_geometry() -> Array[Dictionary]:
	var geometry: Array[Dictionary] = []
	var world := get_parent()
	if world == null:
		return geometry
	var room := world.get("current_room") as Node2D
	var player := world.get("player") as Node2D
	if is_instance_valid(room):
		_collect_nodes(room, geometry)
	if is_instance_valid(player):
		_collect_nodes(player, geometry)
	return geometry


func _collect_nodes(node: Node, geometry: Array[Dictionary]) -> void:
	if node is TileMapLayer:
		_collect_tiles(node as TileMapLayer, geometry)
	elif node is CollisionShape2D:
		_collect_shape(node as CollisionShape2D, geometry)
	for child in node.get_children():
		_collect_nodes(child, geometry)


func _collect_tiles(layer: TileMapLayer, geometry: Array[Dictionary]) -> void:
	if not layer.collision_enabled or layer.tile_set == null:
		return
	var tiles := layer.tile_set
	var to_overlay := global_transform.affine_inverse() * layer.global_transform
	for cell in layer.get_used_cells():
		var data := layer.get_cell_tile_data(cell)
		if data == null:
			continue
		var center := layer.map_to_local(cell)
		var alternative := layer.get_cell_alternative_tile(cell)
		for physics_layer in range(tiles.get_physics_layers_count()):
			if tiles.get_physics_layer_collision_layer(physics_layer) & 1 == 0:
				continue
			for polygon_index in range(data.get_collision_polygons_count(physics_layer)):
				var polygon := data.get_collision_polygon_points(physics_layer, polygon_index)
				var points := PackedVector2Array()
				for vertex in polygon:
					var transformed := vertex
					if alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
						transformed = Vector2(transformed.y, transformed.x)
					if alternative & TileSetAtlasSource.TRANSFORM_FLIP_H:
						transformed.x = -transformed.x
					if alternative & TileSetAtlasSource.TRANSFORM_FLIP_V:
						transformed.y = -transformed.y
					points.append(to_overlay * (center + transformed))
				_append_polygon(points, WORLD_COLOR, geometry)


func _collect_shape(collision: CollisionShape2D, geometry: Array[Dictionary]) -> void:
	if collision.disabled or collision.shape == null:
		return
	var object := collision.get_parent() as CollisionObject2D
	if object == null:
		return
	var color: Color
	if object is MapExit:
		var exit := object as MapExit
		if not exit.enabled or not exit.is_visible_in_tree() or not exit.monitoring:
			return
		color = EXIT_COLOR
	elif object.collision_layer & 2:
		color = PLAYER_COLOR
	elif object.collision_layer & 4:
		color = RECEIVER_COLOR
	elif object.collision_layer & 1:
		color = WORLD_COLOR
	else:
		return
	var polygon := _shape_polygon(collision.shape)
	var to_overlay := global_transform.affine_inverse() * collision.global_transform
	_append_polygon(to_overlay * polygon, color, geometry)


func _shape_polygon(shape: Shape2D) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		polygon = PackedVector2Array(
			[Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
		)
	elif shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		for segment in range(CIRCLE_SEGMENTS):
			var angle := TAU * float(segment) / float(CIRCLE_SEGMENTS)
			polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon


func _append_polygon(points: PackedVector2Array, color: Color, geometry: Array[Dictionary]) -> void:
	if points.size() >= 3:
		geometry.append({"points": points, "color": color})


func _draw() -> void:
	for geometry in _collect_geometry():
		var points: PackedVector2Array = geometry["points"]
		var color: Color = geometry["color"]
		draw_colored_polygon(points, Color(color, 0.18))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, color, 1.0)
