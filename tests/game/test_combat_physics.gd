extends GutTest


class FixtureCaster:
	extends Node2D

	var facing_direction: float = 1.0
	var combatant: Combatant

	func get_combatant() -> Combatant:
		return combatant

	func get_attack_origin() -> Vector2:
		return global_position


var _hit_ids: Array[StringName] = []


func before_each() -> void:
	_hit_ids.clear()


func test_fireball_sweeps_fast_movement_and_hits_only_once() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	_receiver(rig, Vector2(70.0, 0.0), &"target")
	await wait_physics_frames(3)
	var projectile := _projectile(rig, caster, Vector2.RIGHT, 20000.0)
	await wait_physics_frames(8)
	assert_eq(_hit_ids, [&"target"], "Fast projectile crosses and hits target once")
	assert_false(is_instance_valid(projectile), "Spent projectile is removed")


func test_fireball_facing_left_does_not_hit_target_on_right() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	_receiver(rig, Vector2(-100.0, 0.0), &"left")
	_receiver(rig, Vector2(100.0, 0.0), &"right")
	await wait_physics_frames(3)
	_projectile(rig, caster, Vector2.LEFT, 900.0)
	await wait_physics_frames(15)
	assert_eq(_hit_ids, [&"left"])


func test_wall_blocks_fireball_before_target() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	var wall := StaticBody2D.new()
	wall.position = Vector2(45.0, 0.0)
	wall.collision_layer = 1
	wall.collision_mask = 0
	_add_rectangle(wall, Vector2(10.0, 90.0))
	rig.add_child(wall)
	_receiver(rig, Vector2(100.0, 0.0), &"behind_wall")
	await wait_physics_frames(3)
	var projectile := _projectile(rig, caster, Vector2.RIGHT, 900.0)
	await wait_physics_frames(15)
	assert_eq(_hit_ids.size(), 0)
	assert_false(is_instance_valid(projectile), "Wall consumes projectile")


func test_fireball_lifetime_and_range_remove_unspent_projectiles() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	var short_lived := _projectile(rig, caster, Vector2.RIGHT, 300.0, 0.05, 1000.0)
	var short_range := _projectile(rig, caster, Vector2.LEFT, 300.0, 3.0, 25.0)
	await wait_physics_frames(15)
	assert_false(is_instance_valid(short_lived))
	assert_false(is_instance_valid(short_range))
	assert_eq(_hit_ids.size(), 0)


func test_fireball_executor_uses_caster_origin_facing_and_definition() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	caster.position = Vector2(160.0, 30.0)
	caster.facing_direction = -1.0
	var original_scene := get_tree().current_scene
	get_tree().current_scene = rig
	SkillExecutors.fireball(caster, load("res://skills/definitions/fireball.tres"))
	get_tree().current_scene = original_scene
	var projectile := rig.get_child(rig.get_child_count() - 1) as Fireball
	assert_not_null(projectile)
	if projectile != null:
		assert_eq(projectile.direction, Vector2.LEFT)
		assert_eq(projectile.global_position, Vector2(142.0, 30.0))
		assert_eq(projectile.hit.damage, 1.0)
		assert_eq(projectile.hit.source, caster)


func test_melee_hits_forward_target_once_per_swing() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	_receiver(rig, Vector2(30.0, 0.0), &"forward")
	await wait_physics_frames(3)
	_strike(rig, caster)
	await wait_physics_frames(15)
	assert_eq(_hit_ids, [&"forward"], "Persistent active window cannot multi-hit one receiver")
	_strike(rig, caster)
	await wait_physics_frames(15)
	assert_eq(_hit_ids.size(), 2, "A fresh swing can hit again")


func test_melee_does_not_hit_behind_or_outside_reach() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	_receiver(rig, Vector2(-45.0, 0.0), &"behind")
	_receiver(rig, Vector2(110.0, 0.0), &"far")
	await wait_physics_frames(3)
	_strike(rig, caster)
	await wait_physics_frames(15)
	assert_eq(_hit_ids.size(), 0)


func test_receiver_rejects_disabled_invalid_and_own_hits() -> void:
	var rig := _rig()
	var caster := _caster(rig)
	var receiver := _receiver(rig, Vector2(30.0, 0.0), &"target")
	var hit := _hit(caster)
	receiver.enabled = false
	assert_false(receiver.receive_hit(hit))
	receiver.enabled = true
	hit.damage = -1.0
	assert_false(receiver.receive_hit(hit))
	hit.damage = 0.5
	hit.source = receiver
	assert_false(receiver.receive_hit(hit), "A healthless target is not a valid attack source")
	hit.source = caster
	var own_receiver := _receiver(caster, Vector2.ZERO, &"own")
	assert_false(own_receiver.receive_hit(hit), "Caster ownership rejects its own descendant")
	assert_true(receiver.receive_hit(hit))
	assert_eq(_hit_ids, [&"target"])


func _rig() -> Node2D:
	var rig := Node2D.new()
	get_tree().root.add_child(rig)
	autofree(rig)
	return rig


func _caster(rig: Node2D) -> FixtureCaster:
	var caster := FixtureCaster.new()
	caster.combatant = Combatant.new()
	caster.combatant.faction = Combatant.Faction.FRIENDLY
	caster.add_child(caster.combatant)
	rig.add_child(caster)
	return caster


func _receiver(rig: Node2D, at: Vector2, tag: StringName) -> DamageReceiver:
	var receiver := DamageReceiver.new()
	receiver.healthless_target = true
	receiver.position = at
	_add_rectangle(receiver, Vector2(26.0, 50.0))
	receiver.hit_received.connect(func(_hit_data: HitData): _hit_ids.append(tag))
	rig.add_child(receiver)
	return receiver


func _add_rectangle(owner_node: Node, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	owner_node.add_child(collision)


func _hit(caster: Node) -> HitData:
	var hit := HitData.new()
	hit.source = caster
	hit.skill_id = &"fixture"
	hit.damage = 0.5
	return hit


func _projectile(
	rig: Node2D,
	caster: Node,
	direction: Vector2,
	speed: float,
	lifetime: float = 3.0,
	range_pixels: float = 1000.0
) -> Fireball:
	var projectile := Fireball.new()
	projectile.setup(_hit(caster), direction, speed, lifetime, range_pixels)
	rig.add_child(projectile)
	return projectile


func _strike(rig: Node2D, caster: Node2D) -> MeleeStrike:
	var definition := SkillDefinition.new()
	definition.active_seconds = 0.12
	var strike := MeleeStrike.new()
	strike.setup(caster, definition, _hit(caster), 1.0)
	rig.add_child(strike)
	return strike
