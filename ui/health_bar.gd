class_name HealthBar
extends Node2D
## Draw heart containers from the shared Combatant; this component never changes health.

const MAX_VISIBLE_CONTAINERS: int = 100

const HEART_PIXELS: Array[String] = [
	"..##..##..",
	".########.",
	"##########",
	"##########",
	".########.",
	"..######..",
	"...####...",
	"....##....",
]

@export var combatant_path: NodePath = ^"../Combatant"
@export_range(1.0, 3.0, 0.5) var heart_pixel_size: float = 1.0
@export_range(1, 10, 1) var containers_per_row: int = 5
@export_range(1.0, 8.0, 1.0) var container_gap: float = 2.0
@export_range(1.0, 8.0, 1.0) var row_gap: float = 2.0
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
	if combatant == null or not combatant.validate().is_empty():
		return 0.0
	return clampf(combatant.current_health / combatant.max_health, 0.0, 1.0)


func get_container_fills() -> Array[float]:
	var fills: Array[float] = []
	if combatant == null or not combatant.validate().is_empty():
		return fills
	for index in mini(int(combatant.max_health), MAX_VISIBLE_CONTAINERS):
		fills.append(clampf(combatant.current_health - index, 0.0, 1.0))
	return fills


func get_container_rects() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	var count := get_container_fills().size()
	var heart_size := Vector2(10.0, 8.0) * heart_pixel_size
	var columns := maxi(1, containers_per_row)
	for index in count:
		var row := floori(float(index) / columns)
		var row_count := mini(columns, count - row * columns)
		var row_width := row_count * heart_size.x + (row_count - 1) * container_gap
		var column := index % columns
		rectangles.append(
			Rect2(
				Vector2(
					-row_width * 0.5 + column * (heart_size.x + container_gap),
					row * (heart_size.y + row_gap)
				),
				heart_size
			)
		)
	return rectangles


func get_presentation_rect() -> Rect2:
	var rectangles := get_container_rects()
	if rectangles.is_empty():
		return Rect2()
	var bounds := rectangles[0]
	for rectangle in rectangles:
		bounds = bounds.merge(rectangle)
	var font := _font()
	var text_width := (
		font.get_string_size(get_display_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	var text_rect := Rect2(
		-text_width * 0.5, -4.0 - font.get_ascent(font_size), text_width, font.get_height(font_size)
	)
	return bounds.merge(text_rect.grow(3.0))


func get_display_text() -> String:
	if combatant == null or not combatant.validate().is_empty():
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
	if combatant == null or not combatant.validate().is_empty():
		return
	var fills := get_container_fills()
	var rectangles := get_container_rects()
	for index in fills.size():
		_draw_heart(rectangles[index].position, fills[index])
	var font := _font()
	var text := get_display_text()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_position := Vector2(-text_width * 0.5, -4.0)
	draw_string_outline(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_heart(origin: Vector2, fill: float) -> void:
	var outline := (
		Color("e4ded4") if combatant.life_state == Combatant.LifeState.ACTIVE else _fill_color()
	)
	for y in HEART_PIXELS.size():
		for x in HEART_PIXELS[y].length():
			if not _has_heart_pixel(x, y):
				continue
			var edge := (
				not _has_heart_pixel(x - 1, y)
				or not _has_heart_pixel(x + 1, y)
				or not _has_heart_pixel(x, y - 1)
				or not _has_heart_pixel(x, y + 1)
			)
			var color := _fill_color() if float(x) < fill * 10.0 else Color("302632")
			if edge:
				color = outline
			draw_rect(
				Rect2(origin + Vector2(x, y) * heart_pixel_size, Vector2.ONE * heart_pixel_size),
				color
			)


func _has_heart_pixel(x: int, y: int) -> bool:
	return (
		y >= 0
		and y < HEART_PIXELS.size()
		and x >= 0
		and x < HEART_PIXELS[y].length()
		and HEART_PIXELS[y][x] == "#"
	)


func _font() -> Font:
	var font := Localization.get_font()
	return font if font != null else ThemeDB.fallback_font


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
	return "%.0f" % value if value == floorf(value) else "%.1f" % value


func _on_health_changed(_current: float, _maximum: float) -> void:
	queue_redraw()


func _on_state_changed(_state: int) -> void:
	queue_redraw()


func _on_faction_changed(_faction: int) -> void:
	queue_redraw()


func _on_language_changed(_language: String) -> void:
	queue_redraw()
