class_name Fireball
extends Area2D
## A swept ray is used in addition to the visual radius to prevent fast projectiles tunnelling.

signal impacted(collider: Node, hit: HitData)

var hit: HitData
var direction: Vector2 = Vector2.RIGHT
var speed: float = 430.0
var remaining_lifetime: float = 2.0
var max_range: float = 900.0
var traveled: float = 0.0
var spent: bool = false


func _init() -> void:
	collision_layer = 8
	collision_mask = 5
	monitoring = false
	monitorable = false
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	collision.shape = circle
	add_child(collision)


func setup(
	new_hit: HitData, new_direction: Vector2, new_speed: float, lifetime: float, range_pixels: float
) -> void:
	hit = new_hit
	direction = new_direction.normalized() if not new_direction.is_zero_approx() else Vector2.RIGHT
	speed = maxf(0.0, new_speed)
	remaining_lifetime = maxf(0.0, lifetime)
	max_range = maxf(0.0, range_pixels)
	traveled = 0.0
	spent = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if spent or is_queued_for_deletion():
		return
	if hit == null or not hit.is_valid():
		_expire()
		return
	var live_delta := minf(delta, remaining_lifetime)
	var distance := minf(speed * live_delta, maxf(0.0, max_range - traveled))
	var destination := global_position + direction * distance
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = [get_rid()]
	if is_instance_valid(hit.source) and hit.source is CollisionObject2D:
		query.exclude.append((hit.source as CollisionObject2D).get_rid())
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result["position"]
		var collider := result["collider"] as Node
		if collider != null and collider.has_method("receive_hit"):
			collider.call("receive_hit", hit)
		spent = true
		impacted.emit(collider, hit)
		queue_free()
		return
	global_position = destination
	traveled += distance
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0 or traveled >= max_range:
		_expire()
	else:
		queue_redraw()


func _draw() -> void:
	var flip := signf(direction.x) if not is_zero_approx(direction.x) else 1.0
	draw_rect(Rect2(Vector2(-14.0 * flip, -3.0), Vector2(12.0, 6.0)), Color("dd493f"))
	draw_rect(Rect2(-7.0, -6.0, 14.0, 12.0), Color("f48434"))
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), Color("ffdd78"))
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), Color("fff0cf"))


func _expire() -> void:
	spent = true
	queue_free()
