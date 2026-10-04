class_name InputSetup
extends RefCounted
## Physical keys keep the prototype controls independent of keyboard layout.

const ACTION_KEYS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE, KEY_W, KEY_UP],
	&"basic_attack": [KEY_J],
	&"fireball": [KEY_K],
	&"reset_training": [KEY_R],
	&"toggle_fireball_level": [KEY_F2],
}


static func ensure_actions() -> void:
	for action: StringName in ACTION_KEYS:
		# Existing actions, including deliberately empty bindings, belong to the editor.
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for physical_key: int in ACTION_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = physical_key as Key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
