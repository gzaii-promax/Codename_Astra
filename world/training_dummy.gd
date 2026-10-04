class_name TrainingDummy
extends Node2D
## A refillable heart target; statistics persist across automatic refills.

signal stats_changed

var total_damage: float = 0.0
var hit_count: int = 0
var last_hit: HitData

var _flash_remaining: float = 0.0
var _damage_labels: Array[Dictionary] = []

@onready var receiver: DamageReceiver = $DamageReceiver
@onready var combatant: Combatant = $Combatant


func _ready() -> void:
	receiver.hit_resolved.connect(_on_hit_resolved)


func _process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	for label in _damage_labels:
		label["time"] = float(label["time"]) - delta
	_damage_labels = _damage_labels.filter(
		func(label: Dictionary) -> bool: return label["time"] > 0.0
	)
	queue_redraw()


func reset_stats() -> void:
	combatant.reset_state()
	total_damage = 0.0
	hit_count = 0
	last_hit = null
	_flash_remaining = 0.0
	_damage_labels.clear()
	stats_changed.emit()


func get_receiver() -> DamageReceiver:
	return receiver


func get_combatant() -> Combatant:
	return combatant


func get_damage_label_texts() -> Array[String]:
	var texts: Array[String] = []
	for label in _damage_labels:
		texts.append(_heart_number(float(label["damage"])))
	return texts


func _on_hit_resolved(hit: HitData, final_damage: float) -> void:
	total_damage += final_damage
	hit_count += 1
	last_hit = hit
	_flash_remaining = 0.15
	_damage_labels.append({"damage": final_damage, "time": 0.65})
	stats_changed.emit()


func _draw() -> void:
	var straw := Color("ead6a2") if _flash_remaining > 0.0 else Color("a9a28b")
	draw_rect(Rect2(-2, -27, 4, 27), Color("665f53"))
	draw_rect(Rect2(-12, -21, 24, 3), Color("827563"))
	draw_rect(Rect2(-7, -23, 14, 15), straw)
	draw_rect(Rect2(-6, -31, 12, 8), straw)
	draw_rect(Rect2(-8, -32, 16, 3), Color("827563"))
	draw_rect(Rect2(-4, -28, 2, 2), Color("393b40"))
	draw_rect(Rect2(2, -28, 2, 2), Color("393b40"))
	draw_line(Vector2(-4, -12), Vector2(4, -12), Color("6d665b"), 1.0)
	draw_circle(Vector2(0, -16), 4.0, Color("574f48"), false, 1.0)
	draw_rect(Rect2(-8, -2, 16, 2), Color("827563"))
	var font := Localization.get_font()
	if font == null:
		font = ThemeDB.fallback_font
	var damage_texts := get_damage_label_texts()
	var latest_elapsed := 0.0
	if not _damage_labels.is_empty():
		latest_elapsed = 0.65 - float(_damage_labels.back()["time"])
	for index in _damage_labels.size():
		var label := _damage_labels[index]
		var row := _damage_labels.size() - 1 - index
		var text_width := (
			font.get_string_size(damage_texts[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		)
		var color := Color("ffd38d")
		color.a = minf(1.0, float(label["time"]) * 4.0)
		draw_string(
			font,
			Vector2(-text_width * 0.5, -142.0 - row * 24.0 - latest_elapsed * 35.0),
			damage_texts[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			color
		)


func _heart_number(value: float) -> String:
	return "%.0f" % value if value == floorf(value) else "%.1f" % value
