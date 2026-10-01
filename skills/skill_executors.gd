class_name SkillExecutors
extends RefCounted
## The only actor requirements are facing_direction and get_attack_origin().


static func melee(caster: Node, definition: SkillDefinition) -> void:
	if not caster is Node2D or not caster.is_inside_tree():
		return
	var strike := MeleeStrike.new()
	strike.setup(caster as Node2D, definition, _make_hit(caster, definition), _get_facing(caster))
	_get_spawn_parent(caster).add_child(strike)
	strike.global_position = _get_origin(caster)


static func fireball(caster: Node, definition: SkillDefinition) -> void:
	if not caster is Node2D or not caster.is_inside_tree():
		return
	var projectile := Fireball.new()
	var hit := _make_hit(caster, definition)
	projectile.setup(
		hit,
		hit.direction,
		definition.projectile_speed,
		definition.projectile_lifetime,
		definition.projectile_range
	)
	_get_spawn_parent(caster).add_child(projectile)
	projectile.global_position = _get_projectile_spawn(caster as Node2D, hit.direction)


static func _make_hit(caster: Node, definition: SkillDefinition) -> HitData:
	var hit := HitData.new()
	hit.set_source(caster)
	hit.skill_id = definition.id
	hit.damage = definition.damage
	hit.damage_type = definition.damage_type
	hit.target_policy = definition.target_policy
	hit.self_reduction = definition.self_reduction
	hit.same_faction_reduction = definition.same_faction_reduction
	hit.knockback = definition.knockback
	hit.origin = _get_origin(caster)
	hit.direction = Vector2(_get_facing(caster), 0.0)
	return hit


static func _get_facing(caster: Node) -> float:
	var facing: Variant = caster.get("facing_direction")
	return -1.0 if facing != null and float(facing) < 0.0 else 1.0


static func _get_origin(caster: Node) -> Vector2:
	if caster.has_method("get_attack_origin"):
		return caster.call("get_attack_origin")
	return (caster as Node2D).global_position


static func _get_projectile_spawn(caster: Node2D, direction: Vector2) -> Vector2:
	var attack_origin := _get_origin(caster)
	var launch_anchor := Vector2(caster.global_position.x, attack_origin.y)
	var desired_spawn := attack_origin + direction * 18.0
	var query := PhysicsRayQueryParameters2D.create(launch_anchor, desired_spawn, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if caster is CollisionObject2D:
		query.exclude = [(caster as CollisionObject2D).get_rid()]
	var barrier := caster.get_world_2d().direct_space_state.intersect_ray(query)
	return desired_spawn if barrier.is_empty() else launch_anchor


static func _get_spawn_parent(caster: Node) -> Node:
	if caster.get_tree().current_scene != null:
		return caster.get_tree().current_scene
	return caster.get_parent()
