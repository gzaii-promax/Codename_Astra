class_name GrayboxSolid
extends RefCounted
## Reusable static rectangle. Geometry and rendering share the same dimensions.


static func create(rect: Rect2, color: Color, node_name: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var polygon := Polygon2D.new()
	var half := rect.size * 0.5
	polygon.polygon = PackedVector2Array(
		[Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	)
	polygon.color = color
	body.add_child(polygon)
	return body
