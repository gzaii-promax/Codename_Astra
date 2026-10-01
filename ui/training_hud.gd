extends CanvasLayer
## Passive diagnostic UI; it never drives gameplay state.

var _status: Label
var _target: Label
var _phase: Label
var _player: PlayerCharacter
var _dummy: TrainingDummy


func _ready() -> void:
	_player = get_parent().get_node("Player") as PlayerCharacter
	_dummy = get_parent().get_node("TrainingDummy") as TrainingDummy
	var top := Panel.new()
	top.position = Vector2(20, 20)
	top.size = Vector2(920, 132)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19202c")
	style.border_color = Color("3b475a")
	style.set_border_width_all(1)
	top.add_theme_stylebox_override("panel", style)
	add_child(top)
	_add_label(top, Vector2(18, 10), "EMBER TRIAL  /  战斗原型 01", 22, Color("e3c28c"))
	_add_label(top, Vector2(18, 43), "A / D 或 ← → 移动    空格 / W 跳跃    J 普攻    K 火球术", 16)
	_add_label(top, Vector2(18, 69), "R 重置训练场    F2 切换火球等级（仅调试）", 14, Color("9eaec2"))
	_status = _add_label(top, Vector2(18, 97), "", 14, Color("d8b98a"))
	_target = _add_label(top, Vector2(645, 45), "", 16)
	_phase = _add_label(top, Vector2(645, 98), "", 14, Color("9eaec2"))


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var actions := _player.get_action_controller()
	var definition := actions.get_definition(&"fireball")
	_status.text = (
		"火球 Lv.%d  |  伤害 %.0f  ·  前摇 %.2fs  ·  后摇 %.2fs  ·  冷却 %.2fs"
		% [
			_player.fireball_level,
			definition.damage,
			definition.windup_seconds,
			definition.recovery_seconds,
			definition.cooldown_seconds
		]
	)
	_target.text = "稻草人  /  无限生命\n总伤害 %.0f    命中 %d" % [_dummy.total_damage, _dummy.hit_count]
	var phase_names := ["待机", "前摇", "执行", "后摇"]
	_phase.text = (
		"动作：%s   火球 CD：%.1fs"
		% [phase_names[actions.phase], actions.get_cooldown_remaining(&"fireball")]
	)


func _add_label(
	parent: Control, at: Vector2, text: String, font_size: int, color: Color = Color("d8e0ea")
) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
