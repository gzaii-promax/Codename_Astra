class_name MeleeStrike
extends Node2D
## One strike scans throughout its active window; each receiver can be hit only once.

signal receiver_hit(receiver: Node, hit: HitData)

var hit: HitData
var facing: float = 1.0
var reach: float = 48.0
var height: float = 42.0
var remaining: float = 0.12

var _caster: Node2D
var _receivers_hit: Dictionary = {}
var _shape: RectangleShape2D = RectangleShape2D.new()


func setup(caster: Node2D, definition: SkillDefinition, new_hit: HitData, direction: float) -> void:
	_caster = caster
	hit = new_hit
	facing = -1.0 if direction < 0.0 else 1.0
	reach = definition.melee_reach
	height = definition.melee_height
	remaining = maxf(0.0, definition.active_seconds)
	_shape.size = Vector2(reach, height)
	_receivers_hit.clear()


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not is_instance_valid(_caster) or hit == null:
		queue_free()
		return
	if _caster.has_method("get_attack_origin"):
		global_position = _caster.call("get_attack_origin")
	else:
		global_position = _caster.global_position
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * reach * 0.5, 0.0))
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var contacts := get_world_2d().direct_space_state.intersect_shape(query, 32)
	for contact in contacts:
		var receiver := contact["collider"] as Node
		if receiver == null or not receiver.has_method("receive_hit"):
			continue
		var receiver_id := receiver.get_instance_id()
		if _receivers_hit.has(receiver_id):
			continue
		if bool(receiver.call("receive_hit", hit)):
			_receivers_hit[receiver_id] = true
			receiver_hit.emit(receiver, hit)
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var origin := Vector2(facing * 10.0, -height * 0.38)
	var endpoint := Vector2(facing * (reach - 2.0), height * 0.32)
	draw_line(origin, endpoint, Color("fff0cf"), 4.0)
	draw_line(origin + Vector2(0.0, 7.0), endpoint + Vector2(0.0, 4.0), Color("ca9f6c"), 2.0)
