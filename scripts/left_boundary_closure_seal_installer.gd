extends Node

const SEAL_SCRIPT = preload("res://scripts/left_boundary_closure_seal.gd")
const SEAL_NAME = "LeftBoundaryClosureSeal"
const LEGACY_CLOSURE_NAMES = [
	"LeftBoundaryClosureSystem",
	"LeftBoundaryClosureSystemV2",
	"LeftBoundaryClosureSystemV3",
	"LeftBoundaryClosureSystemV4",
	"LeftBoundaryClosureSystemFinal",
	"LeftBoundaryClosureFinal",
	"LeftBoundaryBlackBlocker",
]

var _last_scene_id = 0
var _retry_frames = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_retry_frames = 30


func _process(_delta: float) -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return

	var scene_id = scene.get_instance_id()
	if scene_id != _last_scene_id:
		_last_scene_id = scene_id
		_retry_frames = 30

	if _retry_frames <= 0:
		return

	_retry_frames -= 1
	if not _should_attach_to_scene(scene):
		return

	_remove_legacy_flat_blockers(scene)
	_harden_left_wing_materials(scene)
	_ensure_seal(scene)
	_soften_rain_lines(scene)


func _should_attach_to_scene(scene: Node) -> bool:
	var lower_name = scene.name.to_lower()
	if lower_name.contains("courtyard") or lower_name.contains("interior") or lower_name.contains("house"):
		return true

	var player = scene.find_child("Player", true, false)
	var camera = scene.find_child("Camera3D", true, false)
	if player != null and camera != null:
		return true

	var left_wing = scene.find_child("LeftWing", true, false)
	return left_wing != null


func _ensure_seal(scene: Node) -> void:
	if scene.find_child(SEAL_NAME, false, false) != null:
		return

	var seal = SEAL_SCRIPT.new()
	seal.name = SEAL_NAME
	scene.add_child(seal)


func _remove_legacy_flat_blockers(scene: Node) -> void:
	var to_remove: Array[Node] = []
	_collect_legacy_nodes(scene, to_remove)
	for node in to_remove:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


func _collect_legacy_nodes(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if String(child.name) in LEGACY_CLOSURE_NAMES:
			result.append(child)
		else:
			_collect_legacy_nodes(child, result)


func _harden_left_wing_materials(scene: Node) -> void:
	_harden_node_recursive(scene)


func _harden_node_recursive(node: Node) -> void:
	if node is MeshInstance3D and _is_left_wing_surface(node):
		_harden_mesh_instance(node)

	for child in node.get_children():
		_harden_node_recursive(child)


func _is_left_wing_surface(node: Node) -> bool:
	var lower_name = String(node.name).to_lower()
	var parent_name = ""
	if node.get_parent() != null:
		parent_name = String(node.get_parent().name).to_lower()
	var path_text = String(node.get_path()).to_lower()

	var has_left_context = lower_name.contains("left") or parent_name.contains("left") or path_text.contains("leftwing") or path_text.contains("left_wing")
	var has_arch_token = false
	for token in ["wall", "pillar", "column", "roof", "tile", "door", "window", "beam", "lantern", "jar", "chair", "plaster", "brick", "wood", "瓦", "墙", "门", "窗", "柱", "梁", "灯", "缸"]:
		if lower_name.contains(token) or parent_name.contains(token) or path_text.contains(token):
			has_arch_token = true
			break

	return has_left_context and has_arch_token


func _harden_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var surface_count = mesh_instance.mesh.get_surface_count()
	for surface_index in range(surface_count):
		var material = mesh_instance.get_surface_override_material(surface_index)
		if material == null:
			material = mesh_instance.get_active_material(surface_index)
		if material is StandardMaterial3D:
			var duplicate = material.duplicate()
			_harden_standard_material(duplicate)
			mesh_instance.set_surface_override_material(surface_index, duplicate)


func _harden_standard_material(material: StandardMaterial3D) -> void:
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color.a = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if material.roughness < 0.25:
		material.roughness = 0.42


func _soften_rain_lines(scene: Node) -> void:
	for node in scene.find_children("*", "GPUParticles3D", true, false):
		var particles = node as GPUParticles3D
		var lower_name = String(particles.name).to_lower()
		if lower_name.contains("rain") or lower_name.contains("雨"):
			particles.amount = min(particles.amount, 260)
			particles.lifetime = max(particles.lifetime, 1.0)
