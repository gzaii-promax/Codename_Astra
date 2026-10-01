class_name PlayerVisual
extends Node2D
## Replace the texture or this visual node without changing physics or combat.

@export var texture: Texture2D = preload("res://assets/hero_placeholder.png")
@export var texture_region: Rect2 = Rect2(348, 46, 578, 1173)
@export var display_height: float = 2.0 * GameUnits.PIXELS_PER_UNIT

var _clock: float = 0.0
var _charging: bool = false
var _facing: float = 1.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.region_enabled = true
	_sprite.region_rect = texture_region
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * display_height / texture_region.size.y
	_sprite.position = Vector2(0.0, -display_height * 0.5)
	add_child(_sprite)


func update_state(actor: PlayerCharacter, delta: float) -> void:
	_clock += delta
	_facing = actor.facing_direction
	_sprite.flip_h = _facing < 0.0
	var moving := absf(actor.velocity.x) > 8.0 and actor.is_on_floor()
	var bob := sin(_clock * 18.0) * 0.8 if moving else 0.0
	_sprite.position.y = -display_height * 0.5 + bob
	_sprite.rotation = clampf(actor.velocity.x / actor.move_speed, -1.0, 1.0) * 0.035
	var actions := actor.get_action_controller()
	_charging = (
		actions.phase == ActionController.Phase.WINDUP and actions.active_action_id == &"fireball"
	)
	_sprite.modulate = Color("ffcf9e") if _charging else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if _charging:
		var pulse := 5.0 + sin(_clock * 24.0) * 1.5
		var charge_origin := Vector2(
			_facing * 0.5 * GameUnits.PIXELS_PER_UNIT, -GameUnits.PIXELS_PER_UNIT
		)
		draw_circle(charge_origin, pulse, Color("ee863d"))
		draw_circle(charge_origin, 3.0, Color("ffe09e"))
