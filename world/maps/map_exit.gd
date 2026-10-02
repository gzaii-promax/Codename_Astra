@tool
class_name MapExit
extends Area2D
## Emits an exit identity; routing belongs to MapWorld, not to the room template.

signal exit_requested(exit_id: StringName)

@export var exit_id: StringName = &"":
	set(value):
		exit_id = value
		queue_redraw()
@export var label_key: String = "map.exit_east":
	set(value):
		label_key = value
		queue_redraw()
@export var marker_color := Color("7fb3e3"):
	set(value):
		marker_color = value
		queue_redraw()
@export var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()
		if is_inside_tree() and not Engine.is_editor_hint():
			_apply_enabled.call_deferred()


func _enter_tree() -> void:
	collision_layer = 0
	collision_mask = 2
	if Engine.is_editor_hint():
		return
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)


func _ready() -> void:
	if not Engine.is_editor_hint():
		_apply_enabled()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.disconnect(_on_language_changed)


func _apply_enabled() -> void:
	if is_inside_tree():
		monitoring = enabled


func _on_body_entered(body: Node2D) -> void:
	if not enabled or not body is PlayerCharacter:
		return
	var player := body as PlayerCharacter
	if player.get_combatant().life_state == Combatant.LifeState.ACTIVE:
		exit_requested.emit(exit_id)


func _on_language_changed(_locale: String) -> void:
	queue_redraw()


func _draw() -> void:
	var color := marker_color if enabled else Color("546174")
	draw_rect(Rect2(-8, -24, 16, 48), Color(color, 0.12))
	draw_rect(Rect2(-8, -24, 16, 48), Color(color, 0.65), false, 1.0)
	var direction := -1.0 if exit_id == &"west" else 1.0
	draw_line(Vector2(-direction * 5.0, -4), Vector2(direction * 5.0, -4), color, 2.0)
	draw_line(Vector2(direction * 5.0, -4), Vector2(direction, -8), color, 2.0)
	draw_line(Vector2(direction * 5.0, -4), Vector2(direction, 0), color, 2.0)
	var text := label_key
	var font: Font = ThemeDB.fallback_font
	if not Engine.is_editor_hint():
		text = Localization.text(label_key)
		font = Localization.get_font()
	if font == null:
		font = ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, Vector2(-text_width / 2.0, -29), text, 0, -1, 9, color)
