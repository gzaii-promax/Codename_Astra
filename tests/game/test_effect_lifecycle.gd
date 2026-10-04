extends GutTest
## Lifecycle boundaries remain valid after ordinary scene hierarchy changes.

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const WORLD: PackedScene = preload("res://world/map_world.tscn")


class FixtureEffect:
	extends Node2D

	var physics_ticks: int = 0

	func _physics_process(_delta: float) -> void:
		physics_ticks += 1


var _original_scene: Node


func before_each() -> void:
	_original_scene = get_tree().current_scene
	get_tree().paused = false


func after_each() -> void:
	await wait_physics_frames(2)
	get_tree().current_scene = _original_scene


func test_training_reset_clears_attacks_reparented_into_effects_container() -> void:
	var arena := _arena()
	var effects := _nested_attacks(arena.player, arena)
	arena.reset_training()
	_assert_stopped(effects)
	await wait_physics_frames(2)
	for effect in effects:
		assert_false(is_instance_valid(effect), "MECHANISM: reset frees nested attacks")
	assert_eq(arena.dummy.hit_count, 0, "MECHANISM: reset statistics remain clear")


func test_room_transition_clears_attacks_reparented_into_effects_container() -> void:
	var world := _world()
	var effects := _nested_attacks(world.player, world)
	assert_true(world.travel(&"east"), "MECHANISM: normal room transition succeeds")
	_assert_stopped(effects)
	await wait_physics_frames(2)
	for effect in effects:
		assert_false(is_instance_valid(effect), "MECHANISM: transition frees nested attacks")


func test_enemy_interrupt_clears_nested_melee_and_preserves_launched_fireball() -> void:
	var arena := _arena()
	var effects := _nested_attacks(arena.enemy, arena)
	var melee := effects[0] as MeleeStrike
	var fireball := effects[1] as Fireball
	arena.enemy.attack_enabled = false
	_assert_stopped([melee])
	assert_false(fireball.is_queued_for_deletion(), "MECHANISM: launched fireball is independent")
	assert_true(fireball.is_physics_processing(), "MECHANISM: launched fireball keeps moving")


func test_effect_world_boundary_is_independent_of_current_scene() -> void:
	var first := _arena()
	var first_effects := _nested_attacks(first.player, first)
	var second := _arena()
	get_tree().current_scene = first
	var second_effects := _nested_attacks(second.player, second)
	first.reset_training()
	_assert_stopped(first_effects)
	for effect in second_effects:
		assert_false(effect.is_queued_for_deletion(), "MECHANISM: other world retains its attacks")
		assert_true(effect.is_physics_processing(), "MECHANISM: other world stays active")
	second.reset_training()
	_assert_stopped(second_effects)


func test_world_reset_clears_new_effect_type_without_clearing_unregistered_content() -> void:
	var arena := _arena()
	var container := Node2D.new()
	arena.add_child(container)
	var effect := _effect(container, arena, arena.player, true)
	var decoration := FixtureEffect.new()
	container.add_child(decoration)
	arena.reset_training()
	_assert_stopped([effect])
	assert_false(decoration.is_queued_for_deletion(), "MECHANISM: unregistered scene content stays")
	assert_true(decoration.is_physics_processing(), "MECHANISM: scene content keeps processing")
	var ticks := effect.physics_ticks
	await wait_physics_frames(2)
	assert_false(is_instance_valid(effect), "MECHANISM: generic effect is freed")
	assert_eq(ticks, 0, "MECHANISM: no effect tick between registration and reset")
	assert_gt(decoration.physics_ticks, 0, "MECHANISM: unrelated content actually processes")


func test_effect_reparent_keeps_explicit_world_source_and_interruption_policy() -> void:
	var first := _rig()
	var second := _rig()
	var first_source := Node2D.new()
	var other_source := Node2D.new()
	first.add_child(first_source)
	second.add_child(other_source)
	var follows_source := _effect(first, first, first_source, true)
	var independent := _effect(first, first, first_source, false)
	var other := _effect(second, second, other_source, true)
	follows_source.reparent(second)
	AttackEffectLifecycle.cancel_source(first_source)
	_assert_stopped([follows_source])
	assert_false(independent.is_queued_for_deletion(), "MECHANISM: source keeps independent effect")
	assert_false(other.is_queued_for_deletion(), "MECHANISM: source cannot cancel another source")
	AttackEffectLifecycle.clear_world(second)
	_assert_stopped([other])
	assert_false(independent.is_queued_for_deletion(), "MECHANISM: clear respects bound world")
	AttackEffectLifecycle.clear_world(first)
	_assert_stopped([independent])


func test_effect_registration_survives_detach_and_source_release() -> void:
	var world := _rig()
	var source := Node2D.new()
	world.add_child(source)
	var source_reference: WeakRef = weakref(source)
	var container := Node2D.new()
	world.add_child(container)
	var effect := _effect(container, world, source, true)
	world.remove_child(container)
	assert_false(effect.is_inside_tree(), "MECHANISM: fixture temporarily detaches effect")
	world.add_child(container)
	source.free()
	assert_null(source_reference.get_ref(), "MECHANISM: registration does not retain dead source")
	var replacement := Node2D.new()
	world.add_child(replacement)
	AttackEffectLifecycle.cancel_source(replacement)
	assert_false(effect.is_queued_for_deletion(), "MECHANISM: released source cannot alias new one")
	AttackEffectLifecycle.clear_world(world)
	_assert_stopped([effect])


func test_reparented_effect_keeps_world_ownership_until_explicit_reregistration() -> void:
	var first := _rig()
	var second := _rig()
	var source := Node2D.new()
	first.add_child(source)
	var effect := _effect(first, first, source, true)
	effect.reparent(second)
	AttackEffectLifecycle.clear_world(second)
	assert_false(effect.is_queued_for_deletion(), "MECHANISM: hierarchy alone cannot change owner")
	assert_true(
		AttackEffectLifecycle.register(effect, second, source, false),
		"MECHANISM: intentional ownership transfer is explicit"
	)
	AttackEffectLifecycle.clear_world(first)
	assert_false(
		effect.is_queued_for_deletion(), "MECHANISM: previous owner no longer clears effect"
	)
	AttackEffectLifecycle.cancel_source(source)
	assert_false(effect.is_queued_for_deletion(), "MECHANISM: new interruption policy is effective")
	AttackEffectLifecycle.clear_world(second)
	_assert_stopped([effect])


func test_world_clear_in_melee_callback_stops_remaining_contacts_this_frame() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	arena.player.reset_state(Vector2(500.0, arena.FLOOR_Y))
	arena.dummy.position = Vector2(520.0, arena.FLOOR_Y)
	arena.enemy.position = Vector2(530.0, arena.FLOOR_Y)
	await wait_physics_frames(3)
	SkillExecutors.melee(
		arena.player, arena.player.get_action_controller().get_definition(&"basic_attack")
	)
	var melee := arena.get_child(arena.get_child_count() - 1) as MeleeStrike
	var contacts := [0]
	melee.receiver_hit.connect(
		func(_receiver: Node, _hit: HitData):
			contacts[0] += 1
			AttackEffectLifecycle.clear_world(arena)
	)
	await wait_physics_frames(2)
	assert_eq(contacts[0], 1, "MECHANISM: cancelled scan cannot resolve a second contact")
	var damaged_units := arena.dummy.hit_count
	if arena.enemy.combatant.current_health < arena.enemy.combatant.max_health:
		damaged_units += 1
	assert_eq(damaged_units, 1, "MECHANISM: only the contact before world clear deals damage")


func test_effect_cleanup_while_detached_prevents_reentry_after_reset() -> void:
	var world := _rig()
	var source := Node2D.new()
	world.add_child(source)
	var container := Node2D.new()
	world.add_child(container)
	var follows_source := _effect(container, world, source, true)
	var independent := _effect(container, world, source, false)
	world.remove_child(container)
	AttackEffectLifecycle.cancel_source(source)
	_assert_stopped([follows_source])
	assert_false(
		independent.is_queued_for_deletion(), "MECHANISM: detached fireball stays independent"
	)
	AttackEffectLifecycle.clear_world(world)
	_assert_stopped([independent])
	world.add_child(container)
	_assert_stopped([follows_source, independent])
	await wait_physics_frames(2)
	assert_false(
		is_instance_valid(follows_source), "MECHANISM: cancelled detached effect cannot return"
	)
	assert_false(is_instance_valid(independent), "MECHANISM: reset detached effect cannot return")
	assert_eq(
		container.get_child_count(), 0, "MECHANISM: container reentry cannot revive old attacks"
	)
	var fresh := _effect(container, world, source, true)
	AttackEffectLifecycle.clear_world(world)
	_assert_stopped([fresh])
	assert_eq(
		world.get_meta(AttackEffectLifecycle.REGISTRY_META).effects.size(),
		1,
		"MECHANISM: owner registration prunes freed weak entries"
	)


func test_effect_can_bind_and_cancel_before_world_enters_tree() -> void:
	var world := Node2D.new()
	var source := Node2D.new()
	world.add_child(source)
	AttackEffectLifecycle.register_world(world)
	assert_eq(
		AttackEffectLifecycle.find_world(source), world, "MECHANISM: boundary exists off-tree"
	)
	var effect := FixtureEffect.new()
	assert_true(
		AttackEffectLifecycle.register(effect, world, source, true),
		"MECHANISM: ownership can be composed before tree entry"
	)
	world.add_child(effect)
	AttackEffectLifecycle.cancel_source(source)
	assert_true(
		effect.is_queued_for_deletion(), "MECHANISM: off-tree source cancellation is effective"
	)
	assert_eq(
		effect.process_mode, Node.PROCESS_MODE_DISABLED, "MECHANISM: effect cannot start on entry"
	)
	get_tree().root.add_child(world)
	autofree(world)
	await wait_physics_frames(2)
	assert_false(
		is_instance_valid(effect), "MECHANISM: cancelled pre-tree effect never becomes live"
	)


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	autofree(arena)
	arena.player.set_control_input(0.0)
	return arena


func _world() -> MapWorld:
	var world := WORLD.instantiate() as MapWorld
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	autofree(world)
	world.player.set_control_input(0.0)
	return world


func _rig() -> Node2D:
	var world := Node2D.new()
	get_tree().root.add_child(world)
	AttackEffectLifecycle.register_world(world)
	autofree(world)
	return world


func _effect(parent: Node, world: Node, source: Node, follows_source: bool) -> FixtureEffect:
	var effect := FixtureEffect.new()
	assert_true(
		AttackEffectLifecycle.register(effect, world, source, follows_source),
		"MECHANISM: register explicit effect ownership before publishing"
	)
	parent.add_child(effect)
	return effect


func _nested_attacks(caster: Node2D, world: Node2D) -> Array[Node]:
	var definition := load("res://skills/definitions/basic_attack.tres") as SkillDefinition
	SkillExecutors.melee(caster, definition)
	var melee := world.get_child(world.get_child_count() - 1)
	SkillExecutors.fireball(caster, load("res://skills/definitions/fireball.tres"))
	var fireball := world.get_child(world.get_child_count() - 1)
	var container := Node2D.new()
	container.name = "Effects"
	world.add_child(container)
	melee.reparent(container)
	fireball.reparent(container)
	return [melee, fireball]


func _assert_stopped(effects: Array) -> void:
	for effect: Node in effects:
		assert_false(effect.is_physics_processing(), "MECHANISM: removal stops physics this frame")
		assert_true(effect.is_queued_for_deletion(), "MECHANISM: removal queues every owned effect")
