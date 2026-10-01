extends GutTest

const ARENA: PackedScene = preload("res://world/training_arena.tscn")

var _original_scene: Node
var _original_language: String
var _original_process_mode: Node.ProcessMode


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_original_language = Localization.current_language
	_original_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _original_scene
	Localization.set_language(_original_language, false)
	process_mode = _original_process_mode
	for action in ["move_left", "move_right", "jump", "basic_attack", "fireball"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func test_periodic_enemy_attacks_stationary_player_after_interval_without_chasing() -> void:
	var arena := _arena()
	var player := arena.player
	var enemy := arena.enemy
	player.reset_state(enemy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	var enemy_x := enemy.global_position.x
	await wait_physics_frames(60)
	assert_eq(player.get_combatant().current_health, 3.0, "No early attack before full interval")
	await wait_physics_frames(65)
	assert_eq(
		player.get_combatant().current_health, 2.5, "One real enemy attack removes half a heart"
	)
	var first_health := player.get_combatant().current_health
	await wait_physics_frames(100)
	assert_eq(
		player.get_combatant().current_health,
		first_health - 0.5,
		"Each repeat removes half a heart"
	)
	assert_almost_eq(enemy.global_position.x, enemy_x, 0.01, "Prototype does not chase")


func test_player_melee_and_fireball_damage_and_kill_real_enemy() -> void:
	var arena := _arena()
	var player := arena.player
	var enemy := arena.enemy
	enemy.attack_enabled = false
	player.reset_state(enemy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	assert_true(player.request_attack())
	await wait_physics_frames(30)
	assert_eq(enemy.get_combatant().current_health, 2.5)
	player.reset_state(enemy.global_position + Vector2(-90.0, 0.0))
	player.set_control_input(0.0)
	for expected_health in [1.5, 0.5, 0.0]:
		assert_true(player.request_fireball())
		await wait_physics_frames(85)
		assert_eq(enemy.get_combatant().current_health, expected_health)
	assert_eq(enemy.get_combatant().life_state, Combatant.LifeState.DEAD)
	enemy.attack_enabled = true
	await wait_physics_frames(120)
	assert_eq(player.get_combatant().current_health, 3.0, "Dead enemy cannot attack")
	assert_eq(enemy.actions.phase, ActionController.Phase.IDLE)


func test_dead_player_cannot_move_jump_or_start_attacks() -> void:
	var arena := _arena()
	var player := arena.player
	arena.enemy.attack_enabled = false
	await wait_physics_frames(6)
	player.get_combatant().force_death()
	var at := player.global_position
	player.set_control_input(1.0, true)
	assert_false(player.request_attack())
	assert_false(player.request_fireball())
	await wait_physics_frames(15)
	assert_eq(player.global_position, at)
	assert_eq(player.get_action_controller().phase, ActionController.Phase.IDLE)


func test_training_dummy_counts_resolved_damage_without_mutating_original_hit() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	arena.enemy.get_combatant().faction = Combatant.Faction.NEUTRAL
	var hit := _hit(arena.enemy, 0.5, HitData.TargetPolicy.ALL)
	assert_true(arena.dummy.get_receiver().receive_hit(hit))
	assert_eq(arena.dummy.hit_count, 1)
	assert_eq(arena.dummy.total_damage, 0.5, "Same-faction damage is counted without reduction")
	assert_eq(arena.dummy.last_hit, hit)
	assert_eq(hit.damage, 0.5, "Settling receiver damage preserves the reusable hit payload")


func test_real_active_melee_obeys_hit_interrupt_policy_and_preserves_cooldown() -> void:
	var arena := _arena()
	var player := arena.player
	var enemy := arena.enemy
	enemy.attack_enabled = false
	for interruptible in [true, false]:
		arena.reset_training()
		player.reset_state(Vector2(272.0, 440.0))
		player.set_control_input(0.0)
		var actions := player.get_action_controller()
		var definition := actions.get_definition(&"basic_attack").duplicate(true) as SkillDefinition
		definition.active_seconds = 0.4
		definition.cooldown_seconds = 0.9
		definition.active_policy.can_interrupt_hit = interruptible
		actions.bind_action(&"basic_attack", definition, SkillExecutors.melee)
		await wait_physics_frames(6)
		assert_true(player.request_attack())
		await wait_physics_frames(6)
		assert_eq(actions.phase, ActionController.Phase.ACTIVE)
		var windows: Array[MeleeStrike] = []
		for child in arena.get_children():
			if child is MeleeStrike and child.hit.source == player:
				windows.append(child)
		assert_eq(windows.size(), 1, "Real active melee window exists before receiving damage")
		assert_true(_receiver(player).receive_hit(_hit(enemy, 0.5)))
		assert_gt(actions.get_cooldown_remaining(&"basic_attack"), 0.0)
		enemy.global_position = player.global_position + Vector2(50.0, 0.0)
		if interruptible:
			assert_eq(actions.phase, ActionController.Phase.IDLE)
			for window in windows:
				assert_true(window.is_queued_for_deletion(), "Cancelled attack window is removed")
		else:
			assert_eq(actions.phase, ActionController.Phase.ACTIVE)
			for window in windows:
				assert_false(window.is_queued_for_deletion(), "Locked attack remains active")
		await wait_physics_frames(6)
		assert_eq(
			enemy.get_combatant().current_health,
			3.0 if interruptible else 2.5,
			"A cancelled window cannot hit a target entering its old reach"
		)


func test_training_reset_restores_both_units_and_restarts_enemy_attack_clock() -> void:
	var arena := _arena()
	await wait_physics_frames(80)
	arena.player.get_combatant().force_death()
	arena.enemy.get_combatant().force_death()
	arena.reset_training()
	assert_eq(arena.player.get_combatant().current_health, 3.0)
	assert_eq(arena.enemy.get_combatant().current_health, 3.0)
	assert_eq(arena.player.get_combatant().life_state, Combatant.LifeState.ACTIVE)
	assert_eq(arena.enemy.get_combatant().life_state, Combatant.LifeState.ACTIVE)
	assert_eq(arena.enemy.actions.phase, ActionController.Phase.IDLE)
	assert_eq(arena.enemy.global_position, Vector2(656.0, 440.0))
	arena.player.reset_state(arena.enemy.global_position + Vector2(-50.0, 0.0))
	arena.player.set_control_input(0.0)
	await wait_physics_frames(60)
	assert_eq(
		arena.player.get_combatant().current_health, 3.0, "Reset does not retain old elapsed time"
	)
	await wait_physics_frames(65)
	assert_lt(arena.player.get_combatant().current_health, 3.0)


func test_pause_menu_freezes_enemy_attack_and_optional_recovery_timer() -> void:
	var arena := _arena()
	var hud := arena.get_node("HUD") as TrainingHUD
	var player := arena.player
	player.reset_state(arena.enemy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(60)
	hud.open_menu()
	await wait_physics_frames(130)
	assert_eq(player.get_combatant().current_health, 3.0, "Menu freezes enemy attack clock")
	hud.close_menu()
	await wait_physics_frames(60)
	assert_lt(player.get_combatant().current_health, 3.0)
	arena.enemy.attack_enabled = false
	var health := player.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(player).receive_hit(_hit(arena.enemy, 3.0)))
	assert_true(health.schedule_recovery(0.15, 0.5))
	hud.open_menu()
	await wait_physics_frames(20)
	assert_eq(health.life_state, Combatant.LifeState.DOWNED, "Paused recovery does not expire")
	hud.close_menu()
	await wait_physics_frames(20)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(health.current_health, 0.5)


func test_both_health_bars_follow_damage_state_reset_and_three_language_fonts() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	arena.player.reset_state(arena.enemy.global_position + Vector2(-50.0, 0.0))
	arena.player.set_control_input(0.0)
	var player_bar := arena.player.get_node("HealthBar") as HealthBar
	var enemy_bar := arena.enemy.get_node("HealthBar") as HealthBar
	var dummy_bar := arena.dummy.get_node("HealthBar") as HealthBar
	assert_not_null(player_bar)
	assert_not_null(enemy_bar)
	assert_not_null(dummy_bar)
	assert_almost_eq(
		absf(arena.player.global_position.x - arena.enemy.global_position.x), 50.0, 0.01
	)
	assert_almost_eq(
		absf(arena.player.global_position.x - arena.dummy.global_position.x), 62.0, 0.01
	)
	assert_eq(player_bar.get_fill_ratio(), 1.0)
	assert_eq(enemy_bar.get_fill_ratio(), 1.0)
	assert_eq(player_bar.get_container_fills(), [1.0, 1.0, 1.0])
	assert_eq(enemy_bar.get_container_fills(), [1.0, 1.0, 1.0])
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 0.5)))
	assert_true(_receiver(arena.enemy).receive_hit(_hit(arena.player, 1.5)))
	assert_almost_eq(player_bar.get_fill_ratio(), 5.0 / 6.0, 0.0001)
	assert_almost_eq(enemy_bar.get_fill_ratio(), 0.5, 0.0001)
	assert_eq(player_bar.get_container_fills(), [1.0, 1.0, 0.5])
	assert_eq(enemy_bar.get_container_fills(), [1.0, 0.5, 0.0])
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(3)
		assert_true(player_bar.get_display_text().contains("2.5"))
		assert_true(enemy_bar.get_display_text().contains("1.5"))
		_assert_bar_text_visible(player_bar, locale)
		_assert_bar_text_visible(enemy_bar, locale)
		_assert_bar_text_visible(dummy_bar, locale)
		_assert_bars_do_not_overlap(player_bar, enemy_bar, locale)
		_assert_bars_do_not_overlap(player_bar, dummy_bar, locale)
		_assert_bars_do_not_overlap(dummy_bar, enemy_bar, locale)
	arena.enemy.get_combatant().force_death()
	assert_eq(enemy_bar.get_fill_ratio(), 0.0)
	assert_eq(enemy_bar.get_container_fills(), [0.0, 0.0, 0.0])
	assert_true(enemy_bar.get_display_text().contains(Localization.text("health.dead")))
	arena.player.get_combatant().zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 3.0)))
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(3)
		assert_true(player_bar.get_display_text().contains(Localization.text("health.downed")))
		assert_true(enemy_bar.get_display_text().contains(Localization.text("health.dead")))
		_assert_bar_text_visible(player_bar, locale)
		_assert_bar_text_visible(enemy_bar, locale)
		_assert_bar_text_visible(dummy_bar, locale)
		_assert_bars_do_not_overlap(player_bar, enemy_bar, locale)
		_assert_bars_do_not_overlap(player_bar, dummy_bar, locale)
		_assert_bars_do_not_overlap(dummy_bar, enemy_bar, locale)
	arena.reset_training()
	assert_eq(player_bar.get_fill_ratio(), 1.0)
	assert_eq(enemy_bar.get_fill_ratio(), 1.0)
	assert_eq(player_bar.get_container_fills(), [1.0, 1.0, 1.0])
	assert_eq(enemy_bar.get_container_fills(), [1.0, 1.0, 1.0])


func test_actual_dummy_refills_from_twenty_melee_then_ten_fireballs_without_losing_stats() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	var player := arena.player
	var dummy_health := arena.dummy.get_combatant()
	assert_eq(dummy_health.max_health, 10.0)
	assert_eq(dummy_health.current_health, 10.0)
	assert_eq(dummy_health.zero_health_behavior, Combatant.ZeroHealthBehavior.REFILL)
	watch_signals(dummy_health)
	player.reset_state(arena.dummy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	for index in 20:
		assert_true(player.request_attack())
		await wait_physics_frames(26)
		assert_eq(arena.dummy.hit_count, index + 1)
		assert_eq(arena.dummy.total_damage, (index + 1) * 0.5)
		assert_eq(dummy_health.current_health, 10.0 if index == 19 else 10.0 - (index + 1) * 0.5)
		assert_eq(dummy_health.life_state, Combatant.LifeState.ACTIVE)
		assert_eq(arena.dummy.last_hit.skill_id, &"basic_attack")
	player.reset_state(arena.dummy.global_position + Vector2(-56.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(6)
	for index in 10:
		assert_true(player.request_fireball())
		await wait_physics_frames(85)
		assert_eq(arena.dummy.hit_count, 21 + index)
		assert_eq(arena.dummy.total_damage, 11.0 + index)
		assert_eq(dummy_health.current_health, 10.0 if index == 9 else 9.0 - index)
		assert_eq(dummy_health.life_state, Combatant.LifeState.ACTIVE)
		assert_eq(arena.dummy.last_hit.skill_id, &"fireball")
	assert_signal_emit_count(dummy_health, "damaged", 30)
	assert_signal_not_emitted(dummy_health, "state_changed")


func test_dummy_overkill_refills_without_carry_and_training_reset_clears_statistics() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	var health := arena.dummy.get_combatant()
	var strong_hit := _hit(arena.player, 12.0)
	assert_true(arena.dummy.get_receiver().receive_hit(strong_hit))
	assert_eq(health.current_health, 10.0)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(arena.dummy.total_damage, 12.0)
	assert_eq(arena.dummy.hit_count, 1)
	assert_eq(strong_hit.damage, 12.0)
	assert_true(arena.dummy.get_receiver().receive_hit(_hit(arena.player, 0.5)))
	assert_eq(health.current_health, 9.5)
	assert_eq(arena.dummy.total_damage, 12.5)
	assert_eq(arena.dummy.hit_count, 2)
	arena.reset_training()
	assert_eq(health.current_health, 10.0)
	assert_eq(arena.dummy.total_damage, 0.0)
	assert_eq(arena.dummy.hit_count, 0)
	assert_null(arena.dummy.last_hit)
	# Formatting accepts large half-heart values without rendering an enormous container grid.
	health.max_health = 100001.0
	health.reset_state()
	assert_true(arena.dummy.get_receiver().receive_hit(_hit(arena.player, 50000.5)))
	assert_eq(health.current_health, 50000.5)
	assert_eq(arena.dummy.total_damage, 50000.5)
	assert_eq(arena.dummy.get_damage_label_texts(), ["50000.5"])
	var hearts := arena.dummy.get_node("HealthBar") as HealthBar
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		assert_eq(
			hearts.get_display_text(),
			Localization.text("health.values", {"current": "50000.5", "max": "100001"})
		)
	health.max_health = 10.0
	health.reset_state()
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(3)
		assert_eq(
			(arena.get_node("HUD") as TrainingHUD).get_ui_control("TargetStats").get("text"),
			Localization.text("hud.target", {"damage": "50000.5", "hits": 1})
		)
	arena.reset_training()


func test_ten_dummy_containers_wrap_and_show_half_heart_values_in_three_languages() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	var hearts := arena.dummy.get_node("HealthBar") as HealthBar
	assert_not_null(hearts)
	if hearts == null:
		return
	assert_eq(hearts.get_container_fills().size(), 10)
	for fill in hearts.get_container_fills():
		assert_eq(fill, 1.0)
	assert_true(arena.dummy.get_receiver().receive_hit(_hit(arena.player, 0.5)))
	assert_eq(hearts.get_container_fills(), [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.5])
	var rectangles := hearts.get_container_rects()
	assert_eq(rectangles.size(), 10)
	for index in 5:
		assert_eq(rectangles[index].position.y, rectangles[0].position.y)
		assert_eq(rectangles[index + 5].position.y, rectangles[5].position.y)
	assert_gt(rectangles[5].position.y, rectangles[0].end.y)
	for first in rectangles.size():
		for second in range(first + 1, rectangles.size()):
			assert_false(rectangles[first].intersects(rectangles[second]))
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(3)
		assert_eq(
			hearts.get_display_text(),
			Localization.text("health.values", {"current": "9.5", "max": "10"})
		)
		_assert_bar_text_visible(hearts, locale)
		assert_eq(
			(arena.get_node("HUD") as TrainingHUD).get_ui_control("TargetStats").get("text"),
			Localization.text("hud.target", {"damage": "0.5", "hits": 1})
		)
		assert_eq(arena.dummy.get_combatant().current_health, 9.5)


func _receiver(actor: Node) -> DamageReceiver:
	return actor.get_node("DamageReceiver") as DamageReceiver


func _hit(
	source: Node, damage: float, policy: HitData.TargetPolicy = HitData.TargetPolicy.OTHER_FACTIONS
) -> HitData:
	var hit := HitData.new()
	hit.set_source(source)
	hit.damage = damage
	hit.target_policy = policy
	return hit


func _arena() -> TrainingArena:
	var arena := ARENA.instantiate() as TrainingArena
	get_tree().root.add_child(arena)
	autofree(arena)
	get_tree().current_scene = arena
	return arena


func _assert_bar_text_visible(bar: HealthBar, locale: String) -> void:
	var font := Localization.get_font()
	var text := bar.get_display_text()
	assert_false(text.is_empty(), "Health bar exposes readable text")
	assert_false(text.contains("{"), "Health parameters resolve in %s" % locale)
	for character in text:
		assert_true(font.has_char(character.unicode_at(0)), "Health glyph exists in %s" % locale)
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, bar.font_size)
	var viewport := get_viewport().get_visible_rect()
	assert_gte(bar.global_position.x - measured.x * 0.5, viewport.position.x)
	assert_lte(bar.global_position.x + measured.x * 0.5, viewport.end.x)
	assert_gte(bar.global_position.y - measured.y - 4.0, viewport.position.y)
	var presentation := bar.global_transform * bar.get_presentation_rect()
	assert_gte(
		presentation.position.x, viewport.position.x, "Heart/text bounds left in %s" % locale
	)
	assert_gte(presentation.position.y, viewport.position.y, "Heart/text bounds top in %s" % locale)
	assert_lte(presentation.end.x, viewport.end.x, "Heart/text bounds right in %s" % locale)
	assert_lte(presentation.end.y, viewport.end.y, "Heart/text bounds bottom in %s" % locale)


func _assert_bars_do_not_overlap(
	first_bar: HealthBar, second_bar: HealthBar, locale: String
) -> void:
	assert_false(
		_bar_draw_rect(first_bar).intersects(_bar_draw_rect(second_bar)),
		(
			"%s and %s complete heart/text bounds stay separate in %s"
			% [first_bar.get_parent().name, second_bar.get_parent().name, locale]
		)
	)


func _bar_draw_rect(bar: HealthBar) -> Rect2:
	var font := Localization.get_font()
	var width := (
		font
		. get_string_size(bar.get_display_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, bar.font_size)
		. x
	)
	var text_rect := (
		Rect2(
			Vector2(-width * 0.5, -4.0 - font.get_ascent(bar.font_size)),
			Vector2(width, font.get_height(bar.font_size))
		)
		. grow(3.0)
	)
	var bounds := text_rect
	for heart_rect in bar.get_container_rects():
		bounds = bounds.merge(heart_rect)
	return bar.global_transform * bounds
