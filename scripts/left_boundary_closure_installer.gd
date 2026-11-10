extends Node

const CLOSURE_SCRIPT = preload("res://scripts/left_boundary_closure_v3.gd")

var _timer = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.35:
		return
	_timer = 0.0

	var scene = get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return
	if scene.has_node("LeftBoundaryClosureV3"):
		return
	if not _looks_like_courtyard(scene):
		return

	var closure = CLOSURE_SCRIPT.new()
	closure.name = "LeftBoundaryClosureV3"
	scene.add_child(closure)
	print("[LeftBoundaryClosure] Installed thick opaque left-wing rear walls and left boundary wall.")


func _looks_like_courtyard(scene: Node) -> bool:
	var scene_path = String(scene.scene_file_path).to_lower()
	var scene_name = String(scene.name).to_lower()
	if scene_path.contains("courtyard") or scene_path.contains("yard") or scene_path.contains("interior") or scene_path.contains("house"):
		return true
	if scene_name.contains("courtyard") or scene_name.contains("yard") or scene_name.contains("interior") or scene_name.contains("house"):
		return true
	return _has_named(scene, "player") and (_has_named(scene, "rain") or _has_text_hint(scene, "穿过庭院"))


func _has_named(root: Node, needle: String) -> bool:
	if String(root.name).to_lower().contains(needle.to_lower()):
		return true
	for child in root.get_children():
		if child is Node and _has_named(child, needle):
			return true
	return false


func _has_text_hint(root: Node, text: String) -> bool:
	if root is Label and String(root.text).contains(text):
		return true
	if root is RichTextLabel and String(root.text).contains(text):
		return true
	for child in root.get_children():
		if child is Node and _has_text_hint(child, text):
			return true
	return false
