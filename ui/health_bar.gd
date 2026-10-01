class_name HealthBar
extends Node2D
## A presentation-only health readout shared by player, enemies and future units.

@export var combatant_path: NodePath = ^"../Combatant"
@export_range(16.0, 240.0, 1.0) var bar_width: float = 54.0
@export_range(3.0, 24.0, 1.0) var bar_height: float = 6.0
@export_range(8, 24, 1) var font_size: int = 12

@onready var combatant: Combatant = get_node_or_null(combatant_path) as Combatant


func _ready() -> void:
	if combatant != null:
		combatant.health_changed.connect(_on_health_changed)
		combatant.state_changed.connect(_on_state_changed)
		combatant.faction_changed.connect(_on_faction_changed)
	Localization.language_changed.connect(_on_language_changed)
	queue_redraw()


func get_fill_ratio() -> float:
	if combatant == null or combatant.max_health <= 0.0:
		return 0.0
	return clampf(combatant.current_health / combatant.max_health, 0.0, 1.0)


func get_display_text() -> String:
	if combatant == null:
		return ""
	var text := (
		Localization
		. text(
			"health.values",
			{
				"current": _number_text(combatant.current_health),
				"max": _number_text(combatant.max_health),
			}
		)
	)
	match combatant.life_state:
		Combatant.LifeState.DOWNED:
			text += " " + Localization.text("health.downed")
		Combatant.LifeState.DEAD:
			text += " " + Localization.text("health.dead")
	return text


func _draw() -> void:
	if combatant == null:
		return
	var background := Rect2(-bar_width * 0.5, 0.0, bar_width, bar_height)
	var outline_color := (
		Color("e4ded4") if combatant.life_state == Combatant.LifeState.ACTIVE else _fill_color()
	)
	draw_rect(background.grow(1.0), outline_color)
	draw_rect(background, Color("292932"))
	draw_rect(
		Rect2(background.position, Vector2(bar_width * get_fill_ratio(), bar_height)), _fill_color()
	)
	var font := Localization.get_font()
	if font == null:
		font = ThemeDB.fallback_font
	var text := get_display_text()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_position := Vector2(-text_width * 0.5, -4.0)
	draw_string_outline(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _fill_color() -> Color:
	match combatant.life_state:
		Combatant.LifeState.DOWNED:
			return Color("e8bf62")
		Combatant.LifeState.DEAD:
			return Color("777783")
	match combatant.faction:
		Combatant.Faction.FRIENDLY:
			return Color("75d4a2")
		Combatant.Faction.ENEMY:
			return Color("ee7777")
	return Color("e4c781")


func _number_text(value: float) -> String:
	return "%.0f" % value if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _on_health_changed(_current: float, _maximum: float) -> void:
	queue_redraw()


func _on_state_changed(_state: int) -> void:
	queue_redraw()


func _on_faction_changed(_faction: int) -> void:
	queue_redraw()


func _on_language_changed(_language: String) -> void:
	queue_redraw()
