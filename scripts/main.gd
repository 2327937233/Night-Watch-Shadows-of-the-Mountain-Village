extends Node

const START_MENU_PATH = "res://scenes/StartMenu.tscn"

@onready var current_scene_root: Node = $CurrentScene

var current_scene: Node


func _ready() -> void:
	_ensure_input_map()
	change_scene(START_MENU_PATH)


func change_scene(scene_path: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null and is_instance_valid(state.get("night_failure_screen")):
		return
	if scene_path.is_empty():
		push_warning("change_scene called with an empty scene path.")
		return

	if not ResourceLoader.exists(scene_path):
		push_warning("Scene does not exist: %s" % scene_path)
		return

	var packed_scene = load(scene_path)
	if not packed_scene is PackedScene:
		push_warning("Resource is not a PackedScene: %s" % scene_path)
		return

	for child in current_scene_root.get_children():
		current_scene_root.remove_child(child)
		child.queue_free()

	current_scene = packed_scene.instantiate()
	current_scene_root.add_child(current_scene)


func _ensure_input_map() -> void:
	# Kept here as a runtime safety net, so the demo still works if the
	# project input map is edited or regenerated later.
	_ensure_action("ui_up", [KEY_W, KEY_UP])
	_ensure_action("ui_down", [KEY_S, KEY_DOWN])
	_ensure_action("ui_left", [KEY_A, KEY_LEFT])
	_ensure_action("ui_right", [KEY_D, KEY_RIGHT])
	_ensure_action("ui_accept", [KEY_ENTER, KEY_SPACE])
	_ensure_action("ui_cancel", [KEY_ESCAPE])
	_ensure_action("interact", [KEY_E])
	_ensure_action("flashlight", [KEY_F])
	_ensure_action("inventory", [KEY_TAB])


func _ensure_action(action_name: String, key_codes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for key_code in key_codes:
		if not _action_has_key(action_name, key_code):
			var event = InputEventKey.new()
			event.keycode = key_code
			InputMap.action_add_event(action_name, event)


func _action_has_key(action_name: String, key_code: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == key_code:
			return true
	return false
