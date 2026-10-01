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
	assert_eq(player.get_combatant().current_health, 100.0, "No early attack before full interval")
	await wait_physics_frames(65)
	assert_lt(player.get_combatant().current_health, 100.0, "Real enemy attack damages player")
	var first_health := player.get_combatant().current_health
	await wait_physics_frames(100)
	assert_lt(player.get_combatant().current_health, first_health, "Attacks repeat")
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
	assert_eq(enemy.get_combatant().current_health, 80.0)
	player.reset_state(enemy.global_position + Vector2(-90.0, 0.0))
	player.set_control_input(0.0)
	for expected_health in [45.0, 10.0, 0.0]:
		assert_true(player.request_fireball())
		await wait_physics_frames(85)
		assert_eq(enemy.get_combatant().current_health, expected_health)
	assert_eq(enemy.get_combatant().life_state, Combatant.LifeState.DEAD)
	enemy.attack_enabled = true
	await wait_physics_frames(120)
	assert_eq(player.get_combatant().current_health, 100.0, "Dead enemy cannot attack")
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
	var hit := _hit(arena.enemy, 10.0, HitData.TargetPolicy.ALL_WITH_SAME_FACTION_REDUCTION)
	assert_true(arena.dummy.get_receiver().receive_hit(hit))
	assert_eq(arena.dummy.hit_count, 1)
	assert_eq(arena.dummy.total_damage, 5.0, "Neutral same-faction dummy counts settled damage")
	assert_eq(arena.dummy.last_hit, hit)
	assert_eq(hit.damage, 10.0, "Settling receiver damage preserves the reusable hit payload")


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
		assert_true(_receiver(player).receive_hit(_hit(enemy, 5.0)))
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
			100.0 if interruptible else 80.0,
			"A cancelled window cannot hit a target entering its old reach"
		)


func test_training_reset_restores_both_units_and_restarts_enemy_attack_clock() -> void:
	var arena := _arena()
	await wait_physics_frames(80)
	arena.player.get_combatant().force_death()
	arena.enemy.get_combatant().force_death()
	arena.reset_training()
	assert_eq(arena.player.get_combatant().current_health, 100.0)
	assert_eq(arena.enemy.get_combatant().current_health, 100.0)
	assert_eq(arena.player.get_combatant().life_state, Combatant.LifeState.ACTIVE)
	assert_eq(arena.enemy.get_combatant().life_state, Combatant.LifeState.ACTIVE)
	assert_eq(arena.enemy.actions.phase, ActionController.Phase.IDLE)
	assert_eq(arena.enemy.global_position, Vector2(656.0, 440.0))
	arena.player.reset_state(arena.enemy.global_position + Vector2(-50.0, 0.0))
	arena.player.set_control_input(0.0)
	await wait_physics_frames(60)
	assert_eq(
		arena.player.get_combatant().current_health, 100.0, "Reset does not retain old elapsed time"
	)
	await wait_physics_frames(65)
	assert_lt(arena.player.get_combatant().current_health, 100.0)


func test_pause_menu_freezes_enemy_attack_and_optional_recovery_timer() -> void:
	var arena := _arena()
	var hud := arena.get_node("HUD") as TrainingHUD
	var player := arena.player
	player.reset_state(arena.enemy.global_position + Vector2(-50.0, 0.0))
	player.set_control_input(0.0)
	await wait_physics_frames(60)
	hud.open_menu()
	await wait_physics_frames(130)
	assert_eq(player.get_combatant().current_health, 100.0, "Menu freezes enemy attack clock")
	hud.close_menu()
	await wait_physics_frames(60)
	assert_lt(player.get_combatant().current_health, 100.0)
	arena.enemy.attack_enabled = false
	var health := player.get_combatant()
	health.zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(player).receive_hit(_hit(arena.enemy, 200.0)))
	assert_true(health.schedule_recovery(0.15, 30.0))
	hud.open_menu()
	await wait_physics_frames(20)
	assert_eq(health.life_state, Combatant.LifeState.DOWNED, "Paused recovery does not expire")
	hud.close_menu()
	await wait_physics_frames(20)
	assert_eq(health.life_state, Combatant.LifeState.ACTIVE)
	assert_eq(health.current_health, 30.0)


func test_both_health_bars_follow_damage_state_reset_and_three_language_fonts() -> void:
	var arena := _arena()
	arena.enemy.attack_enabled = false
	arena.player.reset_state(arena.enemy.global_position + Vector2(-50.0, 0.0))
	arena.player.set_control_input(0.0)
	var player_bar := arena.player.get_node("HealthBar") as HealthBar
	var enemy_bar := arena.enemy.get_node("HealthBar") as HealthBar
	assert_not_null(player_bar)
	assert_not_null(enemy_bar)
	assert_eq(player_bar.get_fill_ratio(), 1.0)
	assert_eq(enemy_bar.get_fill_ratio(), 1.0)
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 25.0)))
	assert_true(_receiver(arena.enemy).receive_hit(_hit(arena.player, 40.0)))
	assert_almost_eq(player_bar.get_fill_ratio(), 0.75, 0.0001)
	assert_almost_eq(enemy_bar.get_fill_ratio(), 0.6, 0.0001)
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(3)
		assert_true(player_bar.get_display_text().contains("75"))
		assert_true(enemy_bar.get_display_text().contains("60"))
		_assert_bar_text_visible(player_bar, locale)
		_assert_bar_text_visible(enemy_bar, locale)
		_assert_bars_do_not_overlap(player_bar, enemy_bar, locale)
	arena.enemy.get_combatant().force_death()
	assert_eq(enemy_bar.get_fill_ratio(), 0.0)
	assert_true(enemy_bar.get_display_text().contains(Localization.text("health.dead")))
	arena.player.get_combatant().zero_health_behavior = Combatant.ZeroHealthBehavior.KNOCKDOWN
	assert_true(_receiver(arena.player).receive_hit(_hit(arena.enemy, 200.0)))
	for locale in ["zh_CN", "en", "ja"]:
		assert_true(Localization.set_language(locale, false))
		await wait_frames(3)
		assert_true(player_bar.get_display_text().contains(Localization.text("health.downed")))
		assert_true(enemy_bar.get_display_text().contains(Localization.text("health.dead")))
		_assert_bar_text_visible(player_bar, locale)
		_assert_bar_text_visible(enemy_bar, locale)
		_assert_bars_do_not_overlap(player_bar, enemy_bar, locale)
	arena.reset_training()
	assert_eq(player_bar.get_fill_ratio(), 1.0)
	assert_eq(enemy_bar.get_fill_ratio(), 1.0)


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


func _assert_bars_do_not_overlap(
	player_bar: HealthBar, enemy_bar: HealthBar, locale: String
) -> void:
	assert_false(
		_bar_draw_rect(player_bar).intersects(_bar_draw_rect(enemy_bar)),
		"Both full health readouts remain separate at melee distance in %s" % locale
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
	var fill_rect := Rect2(-bar.bar_width * 0.5, 0.0, bar.bar_width, bar.bar_height).grow(1.0)
	return bar.global_transform * text_rect.merge(fill_rect)
