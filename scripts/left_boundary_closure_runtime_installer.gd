extends Node

const SEAL_SCRIPT_PATH = "res://scripts/left_boundary_closure_seal_runtime.gd"
const SEAL_NODE_NAME = "LeftBoundaryClosureSealRuntime"

const EXACT_BLOCKER_NAMES = [
	"LeftBoundaryBlackBlocker",
	"LeftVoidBlackPlane",
	"BlackVoidBlocker",
	"LeftOuterVoidMask",
	"LeftBoundaryVoidMask"
]

var _refreshing = false
var _refresh_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	_refresh_timer = Timer.new()
	_refresh_timer.name = "LeftBoundaryClosureRefreshTimer"
	_refresh_timer.wait_time = 1.0
	_refresh_timer.one_shot = false
	_refresh_timer.timeout.connect(_refresh_current_scene)
	add_child(_refresh_timer)
	_refresh_timer.start()
	call_deferred("_refresh_current_scene")


func _on_node_added(node: Node) -> void:
	if node == get_tree().current_scene:
		call_deferred("_refresh_current_scene")


func _refresh_current_scene() -> void:
	if _refreshing:
		return
	_refreshing = true
	await get_tree().process_frame

	var scene = get_tree().current_scene
	if scene != null and _is_courtyard_scene(scene):
		_remove_legacy_black_blockers(scene)
		_fix_left_wing_material_flags(scene)
		_reduce_overbright_rain(scene)
		_ensure_closure_seal(scene)

	_refreshing = false


func _is_courtyard_scene(scene: Node) -> bool:
	var scene_id = (scene.name + " " + scene.scene_file_path).to_lower()
	if _contains_any(scene_id, ["courtyard", "yard", "interior", "院", "庭"]):
		return true
	return _has_named_descendant(scene, ["leftwing", "left_wing", "left wing", "厢房", "wing"])


func _ensure_closure_seal(scene: Node) -> void:
	var existing = scene.get_node_or_null(SEAL_NODE_NAME)
	if existing != null:
		if existing.has_method("rebuild"):
			existing.call_deferred("rebuild")
		return

	var seal_script = load(SEAL_SCRIPT_PATH)
	if seal_script == null:
		push_warning("Left boundary closure script is missing: " + SEAL_SCRIPT_PATH)
		return

	var seal = (seal_script as Script).new()
	if seal == null:
		push_warning("Failed to create left boundary closure node.")
		return

	seal.name = SEAL_NODE_NAME
	scene.add_child(seal)


func _remove_legacy_black_blockers(root: Node) -> void:
	var nodes: Array = []
	_collect_nodes(root, nodes)
	for node in nodes:
		if node.name in EXACT_BLOCKER_NAMES:
			node.queue_free()


func _fix_left_wing_material_flags(root: Node) -> void:
	var nodes: Array = []
	_collect_nodes(root, nodes)
	for node in nodes:
		if not (node is MeshInstance3D):
			continue
		var mesh_node = node as MeshInstance3D
		var path_id = str(mesh_node.get_path()).to_lower()
		if not _looks_like_left_wing_piece(path_id):
			continue
		_harden_mesh_materials(mesh_node)


func _harden_mesh_materials(mesh_node: MeshInstance3D) -> void:
	var surface_count = 1
	if mesh_node.mesh != null:
		surface_count = max(1, mesh_node.mesh.get_surface_count())

	for surface_index in range(surface_count):
		var material = mesh_node.get_surface_override_material(surface_index)
		if material == null and mesh_node.mesh != null and surface_index < mesh_node.mesh.get_surface_count():
			material = mesh_node.mesh.surface_get_material(surface_index)
		if not (material is StandardMaterial3D):
			continue

		var fixed = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		fixed.resource_local_to_scene = true
		fixed.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		fixed.cull_mode = BaseMaterial3D.CULL_BACK
		fixed.metallic = 0.0
		fixed.roughness = clamp(fixed.roughness, 0.34, 0.92)
		var color = fixed.albedo_color
		color.a = 1.0
		fixed.albedo_color = color
		mesh_node.set_surface_override_material(surface_index, fixed)


func _reduce_overbright_rain(root: Node) -> void:
	var nodes: Array = []
	_collect_nodes(root, nodes)
	for node in nodes:
		var id = node.name.to_lower()
		if id.find("rain") == -1 and id.find("雨") == -1:
			continue
		if node is GPUParticles3D:
			var gpu_particles = node as GPUParticles3D
			gpu_particles.amount = min(gpu_particles.amount, 360)
			gpu_particles.speed_scale = min(gpu_particles.speed_scale, 0.82)
			gpu_particles.lifetime = min(gpu_particles.lifetime, 1.45)
		elif node is CPUParticles3D:
			var cpu_particles = node as CPUParticles3D
			cpu_particles.amount = min(cpu_particles.amount, 360)
			cpu_particles.speed_scale = min(cpu_particles.speed_scale, 0.82)
			cpu_particles.lifetime = min(cpu_particles.lifetime, 1.45)


func _looks_like_left_wing_piece(path_id: String) -> bool:
	var left_side = _contains_any(path_id, ["left", "左", "wing", "厢房"])
	if not left_side:
		return false
	return _contains_any(path_id, [
		"wall", "roof", "pillar", "column", "door", "window", "lantern", "beam",
		"墙", "屋", "柱", "门", "窗", "灯", "梁"
	])


func _has_named_descendant(root: Node, needles: Array) -> bool:
	var nodes: Array = []
	_collect_nodes(root, nodes)
	for node in nodes:
		if _contains_any(node.name.to_lower(), needles):
			return true
	return false


func _contains_any(text: String, needles: Array) -> bool:
	for needle in needles:
		if text.find(str(needle).to_lower()) != -1:
			return true
	return false


func _collect_nodes(root: Node, out: Array) -> void:
	out.append(root)
	for child in root.get_children():
		_collect_nodes(child, out)
