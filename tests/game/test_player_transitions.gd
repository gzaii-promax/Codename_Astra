extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const PLAYER: PackedScene = preload("res://player/player_character.tscn")

var _original_scene: Node
var _original_process_mode: Node.ProcessMode


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_original_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS


func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _original_scene
	process_mode = _original_process_mode


func test_start_transition_advances_once_without_delaying_motion() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var sprite := _sprite(player)
	var origin := player.position.x
	player.set_control_input(1.0)
	await wait_physics_frames(4)
	assert_eq(sprite.animation, &"run_start")
	assert_gt(player.position.x, origin, "Animation does not lock movement")
	var before := sprite.frame + sprite.frame_progress
	await wait_physics_frames(3)
	assert_eq(sprite.animation, &"run_start")
	assert_gt(sprite.frame + sprite.frame_progress, before)
	await wait_physics_frames(18)
	assert_eq(sprite.animation, &"run")
	player.set_control_input(0.0)
	await wait_physics_frames(50)
	assert_eq(sprite.animation, &"idle")
	player.set_control_input(1.0)
	await wait_physics_frames(4)
	assert_eq(sprite.animation, &"run_start", "Idle also starts through anticipation")


func test_turn_retraces_on_reversal_and_completes_both_directions() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	player.set_control_input(1.0)
	await wait_physics_frames(30)
	var sprite := _sprite(player)
	player.set_control_input(-1.0)
	await wait_physics_frames(6)
	assert_eq(sprite.animation, &"turn")
	assert_false(sprite.flip_h, "Canonical right-to-left poses must not flip immediately")
	assert_eq(player.facing_direction, -1.0, "Gameplay facing still updates immediately")
	var before := sprite.frame + sprite.frame_progress
	player.set_control_input(1.0)
	await wait_physics_frames(2)
	assert_eq(sprite.animation, &"turn")
	assert_lt(sprite.frame + sprite.frame_progress, before, "Retrace current poses without restart")
	await wait_physics_frames(12)
	assert_eq(sprite.animation, &"run")
	assert_false(sprite.flip_h)
	player.set_control_input(-1.0)
	await wait_physics_frames(38)
	assert_eq(sprite.animation, &"run")
	assert_true(sprite.flip_h)
	player.set_control_input(1.0)
	await wait_physics_frames(5)
	assert_eq(sprite.animation, &"turn")
	assert_true(sprite.flip_h, "Mirror the whole left-to-right turn")
	await wait_physics_frames(33)
	assert_eq(sprite.animation, &"run")
	assert_false(sprite.flip_h)


func test_transitions_cancel_on_stop_jump_action_death_and_reset() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	var sprite := _sprite(player)
	player.set_control_input(1.0)
	await wait_physics_frames(4)
	player.set_control_input(0.0)
	await wait_physics_frames(8)
	assert_eq(sprite.animation, &"stand", "Short tap does not finish an obsolete start")
	player.set_control_input(-1.0)
	await wait_physics_frames(3)
	assert_eq(sprite.animation, &"turn")
	player.set_control_input(-1.0, true, true)
	await wait_physics_frames(2)
	assert_eq(sprite.animation, &"stand")
	assert_true(sprite.flip_h)
	player.reset_state(Vector2(300, 440))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	player.set_control_input(-1.0)
	await wait_physics_frames(3)
	assert_eq(sprite.animation, &"turn")
	assert_true(player.request_fireball())
	await wait_physics_frames(1)
	assert_eq(sprite.animation, &"stand")
	assert_eq(sprite.modulate, Color("ffcf9e"))
	player.reset_state(Vector2(300, 440))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	player.set_control_input(-1.0)
	await wait_physics_frames(3)
	player.combatant.life_state = Combatant.LifeState.DEAD
	await wait_physics_frames(2)
	assert_eq(sprite.animation, &"stand")
	player.relocate_to(Vector2(300, 440), 1.0)
	assert_eq(sprite.animation, &"stand")
	assert_false(sprite.flip_h)


func test_turn_freezes_on_pause_and_releases_to_idle_without_restarting() -> void:
	var player := _arena().player
	await wait_physics_frames(6)
	player.set_control_input(-1.0)
	await wait_physics_frames(5)
	var sprite := _sprite(player)
	assert_eq(sprite.animation, &"turn")
	var before := sprite.frame + sprite.frame_progress
	get_tree().paused = true
	await wait_seconds(0.2)
	assert_eq(sprite.frame + sprite.frame_progress, before)
	get_tree().paused = false
	player.set_control_input(0.0)
	await wait_physics_frames(65)
	assert_eq(sprite.animation, &"idle")
	assert_true(sprite.flip_h)


func test_saved_transition_timing_and_optional_legacy_frames() -> void:
	var original := PLAYER.instantiate() as PlayerCharacter
	var visual := original.get_node("Visual") as PlayerVisual
	visual.sprite_frames = visual.sprite_frames.duplicate(true) as SpriteFrames
	visual.sprite_frames.set_animation_speed(&"run_start", 12.0)
	visual.sprite_frames.set_frame(
		&"run_start", 0, visual.sprite_frames.get_frame_texture(&"run_start", 0), 2.0
	)
	var packed := PackedScene.new()
	assert_eq(packed.pack(original), OK)
	original.free()
	var path := OS.get_environment("ASTRA_SETTINGS_PATH").get_base_dir().path_join(
		"transition.tscn"
	)
	assert_eq(ResourceSaver.save(packed, path), OK)
	var loaded := (
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	)
	var player := loaded.instantiate() as PlayerCharacter
	_arena().add_child(player)
	player.reset_state(Vector2(300, 440))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	player.set_control_input(1.0)
	await wait_physics_frames(20)
	assert_eq(_sprite(player).animation, &"run_start", "Saved duration changes actual playback")
	await wait_physics_frames(15)
	assert_eq(_sprite(player).animation, &"run")
	player.reset_state(Vector2(300, 440))
	assert_eq(player.visual.sprite_frames.get_animation_speed(&"run_start"), 12.0)
	assert_eq(player.visual.sprite_frames.get_frame_duration(&"run_start", 0), 2.0)
	player.visual.sprite_frames.remove_animation(&"run_start")
	player.visual.sprite_frames.remove_animation(&"turn")
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	player.set_control_input(-1.0)
	await wait_physics_frames(4)
	assert_eq(_sprite(player).animation, &"run")
	assert_true(_sprite(player).flip_h)
	assert_eq(player.visual.configuration_error, "")


func test_transition_invalid_loop_and_speed_are_rejected() -> void:
	var player := _arena().player
	player.visual.sprite_frames = player.visual.sprite_frames.duplicate(true) as SpriteFrames
	player.visual.sprite_frames.set_animation_loop(&"turn", true)
	await wait_physics_frames(1)
	assert_string_contains(player.visual.configuration_error, "nonlooping")
	assert_false(_sprite(player).visible)
	player.visual.sprite_frames.set_animation_loop(&"turn", false)
	player.visual.sprite_frames.set_animation_speed(&"run_start", 0.0)
	await wait_physics_frames(1)
	assert_string_contains(player.visual.configuration_error, "positive speed")


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	autofree(arena)
	get_tree().current_scene = arena
	arena.enemy.attack_enabled = false
	arena.player.set_control_input(0.0)
	return arena


func _sprite(player: PlayerCharacter) -> AnimatedSprite2D:
	return player.visual.get_node("AnimatedSprite2D") as AnimatedSprite2D
