extends Node

const CLOSURE_SCRIPT = preload("res://scripts/left_boundary_closure_v4.gd")
const FINAL_CLOSURE_NAME = "LeftBoundaryClosureSystemFinal"
const LEGACY_CLOSURE_NAMES = [
	"LeftBoundaryClosureSystem",
	"LeftBoundaryClosureSystemV2",
	"LeftBoundaryClosureSystemV3",
	"LeftBoundaryClosureV3",
]

var _installed_scene: Node
var _retry_time = 0.0


func _ready() -> void:
	call_deferred("_try_install")


func _process(delta: float) -> void:
	_retry_time -= delta
	if _retry_time > 0.0:
		return
	_retry_time = 0.75
	_try_install()


func _try_install() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	if not _looks_like_courtyard(scene):
		_installed_scene = null
		return

	_remove_legacy_closures(scene)
	if _has_final_closure(scene):
		_installed_scene = scene
		_harden_wall_materials(scene)
		_soften_rain(scene)
		return

	var closure: Node3D = CLOSURE_SCRIPT.new()
	closure.name = FINAL_CLOSURE_NAME
	scene.add_child(closure)
	closure.owner = scene.owner

	_installed_scene = scene
	_harden_wall_materials(scene)
	_soften_rain(scene)


func _looks_like_courtyard(scene: Node) -> bool:
	if _has_player_character(scene) and _has_camera_3d(scene):
		return true

	var text = str(scene.name).to_lower()
	var scene_file = ""
	if "scene_file_path" in scene:
		scene_file = str(scene.scene_file_path).to_lower()
	var combined = text + " " + scene_file
	for keyword in ["courtyard", "yard", "interior", "house", "院", "庭", "宅"]:
		if combined.find(keyword) != -1:
			return true

	for node in _flatten(scene):
		if node is Label:
			var label_text = str(node.text)
			if label_text.find("穿过庭院") != -1 or label_text.find("前往主屋") != -1:
				return true

	return false


func _has_player_character(root: Node) -> bool:
	for node in _flatten(root):
		var name_text = str(node.name).to_lower()
		if name_text.find("player") != -1 or name_text.find("chenmo") != -1 or name_text.find("chen_mo") != -1:
			return true
	return false


func _has_camera_3d(root: Node) -> bool:
	for node in _flatten(root):
		if node is Camera3D:
			return true
	return false


func _has_final_closure(root: Node) -> bool:
	for node in _flatten(root):
		if node.name == FINAL_CLOSURE_NAME:
			return true
	return false


func _remove_legacy_closures(root: Node) -> void:
	for node in _flatten(root):
		if node.name in LEGACY_CLOSURE_NAMES:
			node.queue_free()


func _harden_wall_materials(root: Node) -> void:
	for node in _flatten(root):
		if not (node is MeshInstance3D):
			continue

		var mesh_instance = node as MeshInstance3D
		if not _is_wall_like(mesh_instance):
			continue

		_fix_mesh_material(mesh_instance)


func _fix_mesh_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	var surface_count = mesh_instance.mesh.get_surface_count()
	for surface in range(surface_count):
		var material = mesh_instance.get_surface_override_material(surface)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(surface)
		if material == null:
			continue
		if not (material is StandardMaterial3D):
			continue

		var fixed = material.duplicate(true) as StandardMaterial3D
		fixed.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		fixed.albedo_color.a = 1.0
		fixed.metallic = 0.0
		fixed.roughness = max(fixed.roughness, 0.36)
		fixed.cull_mode = BaseMaterial3D.CULL_BACK

		var c = fixed.albedo_color
		if c.r < 0.025 and c.g < 0.025 and c.b < 0.025:
			fixed.albedo_color = Color(0.06, 0.052, 0.045, 1.0)

		mesh_instance.set_surface_override_material(surface, fixed)


func _is_wall_like(node: MeshInstance3D) -> bool:
	var text = (str(node.name) + " " + str(node.get_parent().name if node.get_parent() else "")).to_lower()
	for keyword in ["wall", "plaster", "brick", "pillar", "column", "roof", "tile", "door", "window", "beam", "柱", "墙", "瓦", "门", "窗", "梁"]:
		if text.find(keyword) != -1:
			return true
	return false


func _soften_rain(root: Node) -> void:
	for node in _flatten(root):
		var node_name = str(node.name).to_lower()
		if node_name.find("rain") == -1 and node_name.find("雨") == -1:
			continue

		if node is GPUParticles3D:
			var particles = node as GPUParticles3D
			particles.amount = min(particles.amount, 850)
			particles.visibility_aabb = AABB(Vector3(-18.0, -1.0, -28.0), Vector3(36.0, 8.0, 48.0))


func _flatten(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	_collect_nodes(root, result)
	return result


func _collect_nodes(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child in node.get_children():
		_collect_nodes(child, result)
