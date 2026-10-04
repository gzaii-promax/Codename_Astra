class_name AttackEffectLifecycle
extends RefCounted
## Each effect declares its world, source and interruption policy independently of hierarchy.

const WORLD_GROUP: StringName = &"astra_attack_worlds"
const BINDING_META: StringName = &"_astra_attack_effect_binding"
const REGISTRY_META: StringName = &"_astra_attack_effect_registry"


class Binding:
	extends RefCounted

	var world: WeakRef
	var source: WeakRef
	var cancel_with_source: bool

	func _init(owner_world: Node, owner_source: Node, follows_source: bool) -> void:
		world = weakref(owner_world)
		source = weakref(owner_source)
		cancel_with_source = follows_source


class Registry:
	extends RefCounted

	var effects: Array[WeakRef] = []

	func track(effect: Node) -> void:
		if effect not in get_live_effects():
			effects.append(weakref(effect))

	func get_live_effects() -> Array[Node]:
		var live: Array[Node] = []
		var retained: Array[WeakRef] = []
		for reference in effects:
			var effect := reference.get_ref() as Node
			if effect != null:
				live.append(effect)
				retained.append(reference)
		effects = retained
		return live


static func register_world(world: Node) -> void:
	world.add_to_group(WORLD_GROUP)


static func find_world(caster: Node) -> Node:
	var ancestor := caster
	while ancestor != null:
		if ancestor.is_in_group(WORLD_GROUP):
			return ancestor
		ancestor = ancestor.get_parent()
	return null


static func register(effect: Node, world: Node, source: Node, cancel_with_source: bool) -> bool:
	if (
		not is_instance_valid(effect)
		or not is_instance_valid(world)
		or not is_instance_valid(source)
	):
		return false
	if world.is_inside_tree() and source.is_inside_tree() and source.get_tree() != world.get_tree():
		return false
	if world.is_inside_tree() and effect.is_inside_tree() and effect.get_tree() != world.get_tree():
		return false
	effect.set_meta(BINDING_META, Binding.new(world, source, cancel_with_source))
	_get_registry(world).track(effect)
	_get_registry(source).track(effect)
	return true


static func clear_world(world: Node) -> void:
	if not is_instance_valid(world):
		return
	for effect in _get_registry(world).get_live_effects():
		var binding := effect.get_meta(BINDING_META, null) as Binding
		if binding != null and binding.world.get_ref() == world:
			_remove(effect)


static func cancel_source(source: Node) -> void:
	if not is_instance_valid(source):
		return
	for effect in _get_registry(source).get_live_effects():
		var binding := effect.get_meta(BINDING_META, null) as Binding
		if binding != null and binding.cancel_with_source and binding.source.get_ref() == source:
			_remove(effect)


static func _get_registry(owner: Node) -> Registry:
	var registry: Registry
	if owner.has_meta(REGISTRY_META):
		registry = owner.get_meta(REGISTRY_META) as Registry
	if registry == null:
		registry = Registry.new()
		owner.set_meta(REGISTRY_META, registry)
	return registry


static func _remove(effect: Node) -> void:
	effect.process_mode = Node.PROCESS_MODE_DISABLED
	effect.set_process(false)
	effect.set_physics_process(false)
	effect.queue_free()
