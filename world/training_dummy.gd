class_name TrainingDummy
extends Node2D
## Immortal target: collect accepted damage without adding enemy AI or health rules.

signal stats_changed

var total_damage: float = 0.0
var hit_count: int = 0
var last_hit: HitData

var _flash_remaining: float = 0.0
var _damage_labels: Array[Dictionary] = []

@onready var receiver: DamageReceiver = $DamageReceiver


func _ready() -> void:
	receiver.hit_received.connect(_on_hit_received)


func _process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	for label in _damage_labels:
		label["time"] = float(label["time"]) - delta
	_damage_labels = _damage_labels.filter(
		func(label: Dictionary) -> bool: return label["time"] > 0.0
	)
	queue_redraw()


func reset_stats() -> void:
	total_damage = 0.0
	hit_count = 0
	last_hit = null
	_flash_remaining = 0.0
	_damage_labels.clear()
	stats_changed.emit()


func get_receiver() -> DamageReceiver:
	return receiver


func _on_hit_received(hit: HitData) -> void:
	var final_damage := receiver.last_damage
	total_damage += final_damage
	hit_count += 1
	last_hit = hit
	_flash_remaining = 0.15
	_damage_labels.append({"damage": final_damage, "time": 0.65})
	stats_changed.emit()


func _draw() -> void:
	var straw := Color("ead6a2") if _flash_remaining > 0.0 else Color("a9a28b")
	draw_rect(Rect2(-3, -57, 6, 57), Color("665f53"))
	draw_rect(Rect2(-23, -43, 46, 6), Color("827563"))
	draw_rect(Rect2(-12, -46, 24, 30), straw)
	draw_rect(Rect2(-11, -65, 22, 18), straw)
	draw_rect(Rect2(-15, -68, 30, 5), Color("827563"))
	draw_rect(Rect2(-6, -59, 3, 3), Color("393b40"))
	draw_rect(Rect2(4, -59, 3, 3), Color("393b40"))
	draw_line(Vector2(-8, -24), Vector2(8, -24), Color("6d665b"), 2.0)
	draw_circle(Vector2(0, -33), 7.0, Color("574f48"), false, 2.0)
	draw_rect(Rect2(-14, -3, 28, 3), Color("827563"))
	var font := ThemeDB.fallback_font
	for index in _damage_labels.size():
		var label := _damage_labels[index]
		var elapsed := 0.65 - float(label["time"])
		var color := Color("ffd38d")
		color.a = minf(1.0, float(label["time"]) * 4.0)
		draw_string(
			font,
			Vector2(-10.0 + index * 8, -76.0 - elapsed * 35.0),
			"%.0f" % label["damage"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			color
		)
