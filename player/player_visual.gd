class_name PlayerVisual
extends Node2D
## SpriteFrames own artwork; this node maps actor state without changing physics/combat.

@export_group("Animation")
@export var sprite_frames: SpriteFrames
@export_range(0.1, 10000.0, 0.1, "or_greater") var frame_body_height: float = 288.0
@export_range(0.0, 10000.0, 0.1, "or_greater") var frame_feet_y: float = 324.0
@export_range(0.0, 10.0, 0.01, "or_greater") var idle_delay: float = 0.6
@export_range(0.0, 1000.0, 0.1, "or_greater") var run_threshold: float = 1.0
@export_group("Static fallback")
@export var texture: Texture2D = preload("res://assets/hero_placeholder.png")
@export var texture_region: Rect2 = Rect2(348, 46, 578, 1173)
@export_group("Display")
@export_range(0.1, 10000.0, 0.1, "or_greater")
var display_height: float = 2.0 * GameUnits.PIXELS_PER_UNIT

var configuration_error: String = ""

var _clock: float = 0.0
var _charging: bool = false
var _facing: float = 1.0
var _sprite: Sprite2D
var _animated_sprite: AnimatedSprite2D
var _rest_seconds: float = 0.0
var _visual_facing: float = 1.0
var _was_moving: bool = false
var _was_available: bool = false
var _transition: StringName = &""
var _transition_position: float = 0.0
var _turn_from: float = 1.0


func _ready() -> void:
	configuration_error = "\n".join(validate_visual())
	if not configuration_error.is_empty():
		return
	if sprite_frames != null:
		_create_animation()
		return
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.region_enabled = true
	_sprite.region_rect = texture_region
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * (display_height / texture_region.size.y)
	_sprite.position = Vector2(0.0, -display_height * 0.5)
	add_child(_sprite)


func _create_animation() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "AnimatedSprite2D"
	_animated_sprite.sprite_frames = sprite_frames
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var factor := display_height / frame_body_height
	var canvas := sprite_frames.get_frame_texture(&"stand", 0).get_size()
	_animated_sprite.scale = Vector2.ONE * factor
	_animated_sprite.position.y = (canvas.y * 0.5 - frame_feet_y) * factor
	add_child(_animated_sprite)
	reset_visual()


func update_state(actor: PlayerCharacter, delta: float) -> void:
	configuration_error = "\n".join(validate_visual())
	var rendered: CanvasItem = _animated_sprite if _animated_sprite != null else _sprite
	if rendered == null:
		return
	rendered.visible = configuration_error.is_empty()
	if (
		not configuration_error.is_empty()
		or not actor.velocity.is_finite()
		or not is_finite(delta)
		or delta < 0.0
	):
		_charging = false
		if _animated_sprite != null:
			_animated_sprite.pause()
		queue_redraw()
		return
	_clock += delta
	_facing = actor.facing_direction
	if _animated_sprite != null:
		_update_animation(actor, delta)
	else:
		_update_static(actor)
	var actions := actor.get_action_controller()
	_charging = (
		actions.phase == ActionController.Phase.WINDUP and actions.active_action_id == &"fireball"
	)
	rendered.modulate = Color("ffcf9e") if _charging else Color.WHITE
	queue_redraw()


func _update_animation(actor: PlayerCharacter, delta: float) -> void:
	var available := (
		actor.is_on_floor()
		and actor.combatant.life_state == Combatant.LifeState.ACTIVE
		and actor.get_action_controller().phase == ActionController.Phase.IDLE
	)
	var distance := absf(actor.get_position_delta().x)
	var speed := absf(actor.get_real_velocity().x)
	var moving := available and distance > actor.safe_margin and speed > run_threshold
	if not available:
		_clear_transition()
		_visual_facing = _facing
	elif _transition == &"turn":
		_advance_transition(delta)
	elif _facing != _visual_facing and sprite_frames.has_animation(&"turn"):
		_turn_from = _visual_facing
		_begin_transition(&"turn")
	elif _transition == &"run_start":
		if moving:
			_advance_transition(delta)
		else:
			_clear_transition()
	elif moving and not _was_moving and _was_available:
		_visual_facing = _facing
		if sprite_frames.has_animation(&"run_start"):
			_begin_transition(&"run_start")
	else:
		_visual_facing = _facing
	_was_moving = moving
	_was_available = available
	_rest_seconds = _rest_seconds + delta if available and not moving else 0.0
	if _transition != &"":
		_rest_seconds = 0.0
		_show_transition()
		return
	_animated_sprite.flip_h = _visual_facing < 0.0
	_animated_sprite.speed_scale = 1.0
	if moving:
		_play_animation(&"run")
		_animated_sprite.speed_scale = (
			clampf(speed / actor.move_speed, 0.35, 1.8) if actor.move_speed > 0.0 else 1.0
		)
	else:
		_play_animation(&"idle" if available and _rest_seconds >= idle_delay else &"stand")


func _begin_transition(animation: StringName) -> void:
	_transition = animation
	_transition_position = 0.0


func _clear_transition() -> void:
	_transition = &""
	_transition_position = 0.0


func _transition_length() -> float:
	var total := 0.0
	for index in range(sprite_frames.get_frame_count(_transition)):
		total += sprite_frames.get_frame_duration(_transition, index)
	return total


func _advance_transition(delta: float) -> void:
	# The canonical turn goes right -> front -> left. Reversal retraces the same poses.
	var direction := -1.0 if _transition == &"turn" and _facing == _turn_from else 1.0
	_transition_position += delta * sprite_frames.get_animation_speed(_transition) * direction
	if (
		_transition_position >= _transition_length()
		or (direction < 0.0 and _transition_position <= 0.0)
	):
		_visual_facing = _facing
		_clear_transition()


func _show_transition() -> void:
	_animated_sprite.animation = _transition
	_animated_sprite.pause()
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.flip_h = (_turn_from if _transition == &"turn" else _visual_facing) < 0.0
	var remaining := _transition_position
	var last := sprite_frames.get_frame_count(_transition) - 1
	for index in range(last + 1):
		var duration := sprite_frames.get_frame_duration(_transition, index)
		if remaining < duration or index == last:
			_animated_sprite.set_frame_and_progress(index, clampf(remaining / duration, 0.0, 1.0))
			return
		remaining -= duration


func _play_animation(animation: StringName) -> void:
	if _animated_sprite.animation != animation:
		_animated_sprite.play(animation)
	if animation == &"stand":
		_animated_sprite.set_frame_and_progress(0, 0.0)
		_animated_sprite.pause()
	elif not _animated_sprite.is_playing():
		_animated_sprite.play()


func reset_visual(facing: float = 1.0) -> void:
	_clock = 0.0
	_rest_seconds = 0.0
	_charging = false
	_facing = facing
	_visual_facing = facing
	_turn_from = facing
	_was_moving = false
	_was_available = false
	_clear_transition()
	if _animated_sprite != null:
		_play_animation(&"stand")
		_animated_sprite.flip_h = facing < 0.0
		_animated_sprite.speed_scale = 1.0
		_animated_sprite.modulate = Color.WHITE
	if _sprite != null:
		_sprite.flip_h = facing < 0.0
		_sprite.rotation = 0.0
		_sprite.position.y = -display_height * 0.5
		_sprite.modulate = Color.WHITE
	queue_redraw()


func _update_static(actor: PlayerCharacter) -> void:
	_sprite.flip_h = _facing < 0.0
	var moving := absf(actor.velocity.x) > 8.0 and actor.is_on_floor()
	var bob := sin(_clock * 18.0) * 0.8 if moving else 0.0
	_sprite.position.y = -display_height * 0.5 + bob
	var lean := actor.velocity.x / actor.move_speed if actor.move_speed > 0.0 else 0.0
	_sprite.rotation = clampf(lean, -1.0, 1.0) * 0.035


func validate_visual() -> Array[String]:
	var errors: Array[String] = []
	if not is_finite(display_height) or display_height <= 0.0:
		errors.append("display_height must be finite and positive")
	if sprite_frames != null:
		_validate_animation(errors)
		return errors
	if texture == null:
		errors.append("texture must be configured")
	if not texture_region.position.is_finite() or not texture_region.size.is_finite():
		errors.append("texture_region must be finite")
	elif texture_region.size.x <= 0.0 or texture_region.size.y <= 0.0:
		errors.append("texture_region must have positive dimensions")
	if not is_finite(display_height) or display_height <= 0.0:
		errors.append("display_height must be finite and positive")
	elif texture_region.size.y > 0.0 and not is_finite(display_height / texture_region.size.y):
		errors.append("display scale must be finite")
	elif texture_region.size.y > 0.0:
		var scale_value := Vector2.ONE * (display_height / texture_region.size.y)
		var position_value := Vector2(0.0, -display_height * 0.5)
		if not scale_value.is_finite() or not position_value.is_finite():
			errors.append("display transform must fit finite Vector2 components")
	return errors


func _validate_animation(errors: Array[String]) -> void:
	for field in ["idle_delay", "run_threshold", "frame_feet_y"]:
		var value := float(get(field))
		if not is_finite(value) or value < 0.0:
			errors.append("%s must be finite and nonnegative" % field)
	if not is_finite(frame_body_height) or frame_body_height <= 0.0:
		errors.append("frame_body_height must be finite and positive")
		return
	var canvas := Vector2.ZERO
	for animation in [&"stand", &"idle", &"run", &"run_start", &"turn"]:
		var transition: bool = animation in [&"run_start", &"turn"]
		if transition and not sprite_frames.has_animation(animation):
			continue
		if (
			not sprite_frames.has_animation(animation)
			or sprite_frames.get_frame_count(animation) == 0
		):
			errors.append("sprite_frames needs a nonempty %s animation" % animation)
			continue
		if transition:
			var fps := sprite_frames.get_animation_speed(animation)
			if not is_finite(fps) or fps <= 0.0 or sprite_frames.get_animation_loop(animation):
				errors.append("%s must be nonlooping with finite positive speed" % animation)
		for index in range(sprite_frames.get_frame_count(animation)):
			var duration := sprite_frames.get_frame_duration(animation, index)
			if transition and (not is_finite(duration) or duration <= 0.0):
				errors.append("%s frame duration must be finite and positive" % animation)
			var frame := sprite_frames.get_frame_texture(animation, index)
			if frame == null or frame.get_width() <= 0 or frame.get_height() <= 0:
				errors.append("%s frame %d needs a texture" % [animation, index])
				continue
			if canvas == Vector2.ZERO:
				canvas = frame.get_size()
			elif frame.get_size() != canvas:
				errors.append("animation frames must share one canvas size")
	if frame_feet_y > canvas.y:
		errors.append("frame_feet_y must fit the animation canvas")
	var factor := display_height / frame_body_height
	if (
		not is_finite(factor)
		or not (Vector2.ONE * factor).is_finite()
		or not (canvas * factor).is_finite()
		or not Vector2(0.0, (canvas.y * 0.5 - frame_feet_y) * factor).is_finite()
	):
		errors.append("animation display transform must be finite")


func _draw() -> void:
	if _charging:
		var pulse := 5.0 + sin(_clock * 24.0) * 1.5
		var charge_origin := Vector2(
			_facing * 0.5 * GameUnits.PIXELS_PER_UNIT, -GameUnits.PIXELS_PER_UNIT
		)
		draw_circle(charge_origin, pulse, Color("ee863d"))
		draw_circle(charge_origin, 3.0, Color("ffe09e"))
