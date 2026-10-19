extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")
const PLAYER: PackedScene = preload("res://player/player_character.tscn")
const FRAMES: SpriteFrames = preload("res://assets/characters/r4/locomotion.tres")

var _original_scene: Node
var _original_process_mode: Node.ProcessMode


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_original_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _original_scene
	process_mode = _original_process_mode


func test_visual_stands_then_idles_with_continuous_frames() -> void:
	var player := _arena().player
	var sprite := _sprite(player)
	assert_eq(sprite.animation, &"stand")
	assert_false(sprite.is_playing())
	await wait_physics_frames(6)
	assert_true(player.is_on_floor())
	assert_eq(sprite.animation, &"stand")
	await wait_physics_frames(45)
	assert_eq(sprite.animation, &"idle")
	var before := sprite.frame + sprite.frame_progress
	await wait_seconds(0.3)
	assert_ne(sprite.frame + sprite.frame_progress, before, "Idle frames really advance")
	assert_almost_eq(sprite.scale.y * player.visual.frame_body_height, 32.0, 0.001)


func test_visual_runs_both_directions_stops_at_wall_and_keeps_frame_progress() -> void:
	var player := _arena().player
	var sprite := _sprite(player)
	await wait_physics_frames(6)
	player.set_control_input(1.0)
	await wait_physics_frames(20)
	assert_eq(sprite.animation, &"run")
	assert_false(sprite.flip_h)
	var before := sprite.frame + sprite.frame_progress
	await wait_physics_frames(8)
	assert_ne(sprite.frame + sprite.frame_progress, before, "State updates do not restart run")
	player.set_control_input(-1.0)
	await wait_physics_frames(35)
	assert_eq(sprite.animation, &"run")
	assert_true(sprite.flip_h)
	player.set_control_input(0.0)
	await wait_physics_frames(20)
	assert_eq(sprite.animation, &"stand")
	player.reset_state(Vector2(708.0, 440.0))
	player.set_control_input(1.0)
	await wait_physics_frames(30)
	var wall_position := player.position.x
	var touched_wall := false
	for _frame in range(40):
		await wait_physics_frames(1)
		touched_wall = touched_wall or player.is_on_wall()
		assert_almost_eq(player.position.x, wall_position, 0.1, "Wall blocks real movement")
		assert_ne(sprite.animation, &"run", "Held input against a wall must not run in place")
	assert_true(touched_wall)
	assert_eq(sprite.animation, &"idle", "Recovery jitter must not restart the idle delay")


func test_visual_air_action_death_and_relocation_use_standing_fallback() -> void:
	var player := _arena().player
	var sprite := _sprite(player)
	await wait_physics_frames(6)
	player.set_control_input(1.0, true, true)
	await wait_physics_frames(5)
	assert_false(player.is_on_floor())
	assert_eq(sprite.animation, &"stand")
	player.reset_state(Vector2(300.0, 440.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.request_fireball())
	await wait_physics_frames(1)
	assert_eq(sprite.animation, &"stand")
	assert_eq(sprite.modulate, Color("ffcf9e"), "Existing charge cue remains visible")
	player.relocate_to(Vector2(300.0, 440.0), -1.0)
	assert_eq(sprite.animation, &"stand")
	assert_true(sprite.flip_h)
	assert_eq(sprite.modulate, Color.WHITE)
	player.combatant.life_state = Combatant.LifeState.DEAD
	await wait_physics_frames(50)
	assert_eq(sprite.animation, &"stand", "Inactive characters do not breathe or run")
	player.reset_state(Vector2(300.0, 440.0))
	assert_eq(sprite.animation, &"stand")
	assert_false(sprite.flip_h)


func test_visual_animation_freezes_with_pause_and_resumes() -> void:
	var player := _arena().player
	player.visual.idle_delay = 0.0
	await wait_physics_frames(8)
	var sprite := _sprite(player)
	assert_eq(sprite.animation, &"idle")
	get_tree().paused = true
	var before := sprite.frame + sprite.frame_progress
	await wait_seconds(0.25)
	assert_eq(sprite.frame + sprite.frame_progress, before)
	get_tree().paused = false
	await wait_seconds(0.25)
	assert_ne(sprite.frame + sprite.frame_progress, before)


func test_visual_saved_overrides_survive_reload_ready_behavior_and_reset() -> void:
	var original := PLAYER.instantiate() as PlayerCharacter
	var visual := original.get_node("Visual") as PlayerVisual
	visual.display_height = 40.0
	visual.idle_delay = 0.0
	visual.run_threshold = 0.0
	visual.frame_body_height = 300.0
	visual.frame_feet_y = 320.0
	var packed := PackedScene.new()
	assert_eq(packed.pack(original), OK)
	original.free()
	var directory := OS.get_environment("ASTRA_SETTINGS_PATH").get_base_dir()
	var path := directory.path_join("r4-saved-player.tscn")
	assert_eq(ResourceSaver.save(packed, path), OK)
	var loaded := (
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	)
	assert_not_null(loaded)
	var player := loaded.instantiate() as PlayerCharacter
	var arena := _arena()
	arena.add_child(player)
	player.reset_state(Vector2(300.0, 440.0))
	player.set_control_input(0.0)
	await wait_physics_frames(8)
	var sprite := _sprite(player)
	assert_true(player.is_on_floor(), "Fixture is on the real arena floor")
	assert_eq(player.visual.configuration_error, "")
	assert_eq(sprite.animation, &"idle", "Saved zero delay takes effect")
	assert_almost_eq(sprite.scale.y, 40.0 / 300.0, 0.00001)
	player.set_control_input(1.0)
	await wait_physics_frames(2)
	assert_eq(
		sprite.animation, &"run_start", "Saved zero threshold enters the new start transition"
	)
	player.reset_state(Vector2(300.0, 440.0))
	assert_eq(player.visual.display_height, 40.0)
	assert_eq(player.visual.idle_delay, 0.0)
	assert_eq(player.visual.run_threshold, 0.0)
	assert_eq(player.visual.frame_body_height, 300.0)
	assert_eq(player.visual.frame_feet_y, 320.0)
	assert_eq(sprite.animation, &"stand")


func test_visual_rejects_incomplete_animation_and_invalid_runtime_configuration() -> void:
	var visual := PlayerVisual.new()
	visual.sprite_frames = FRAMES.duplicate() as SpriteFrames
	visual.sprite_frames.remove_animation(&"run")
	add_child_autofree(visual)
	assert_string_contains(visual.configuration_error, "run")
	assert_eq(visual.get_child_count(), 0)
	var player := _arena().player
	player.visual.idle_delay = NAN
	await wait_physics_frames(2)
	assert_string_contains(player.visual.configuration_error, "idle_delay")
	assert_false(_sprite(player).visible)
	assert_false(_sprite(player).is_playing())


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
