extends Node

const CLOSURE_SCRIPT = preload("res://scripts/left_boundary_closure_final.gd")
const CLOSURE_NAME = "LeftBoundaryClosureSystemFinal"
const LEGACY_NAMES = [
	"LeftBoundaryClosureSystem",
	"LeftBoundaryClosureSystemV2",
	"LeftBoundaryClosureSystemV3",
	"LeftBoundaryClosureV3",
	"LeftBoundaryClosureSystemFinal"
]

var _attempts = 0


func _ready() -> void:
	call_deferred("_try_install")


func _process(_delta: float) -> void:
	if _attempts < 16:
		_attempts += 1
		_try_install()


func _try_install() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	if not _looks_like_courtyard(scene):
		return

	for legacy_name in LEGACY_NAMES:
		var legacy = scene.find_child(legacy_name, true, false)
		if legacy != null and legacy.name != CLOSURE_NAME:
			legacy.queue_free()

	var closure = scene.find_child(CLOSURE_NAME, true, false)
	if closure == null:
		closure = CLOSURE_SCRIPT.new()
		closure.name = CLOSURE_NAME
		scene.add_child(closure)
	elif closure.has_method("rebuild"):
		closure.rebuild()

	_harden_existing_building_materials(scene)
	_soften_global_rain(scene)


func _looks_like_courtyard(scene: Node) -> bool:
	var scene_file = str(scene.scene_file_path).to_lower()
	var scene_name = scene.name.to_lower()
	if scene_file.contains("courtyard") or scene_file.contains("yard") or scene_file.contains("interior") or scene_file.contains("house"):
		return true
	if scene_name.contains("courtyard") or scene_name.contains("yard") or scene_name.contains("interior") or scene_name.contains("house"):
		return true
	if scene.find_child("Player", true, false) != null and scene.find_child("Camera3D", true, false) != null:
		return true
	return _scene_has_task_text(scene)


func _scene_has_task_text(node: Node) -> bool:
	if node is Label:
		var text = str((node as Label).text)
		if text.contains("穿过庭院") or text.contains("前往主屋") or text.contains("荒宅"):
			return true
	for child in node.get_children():
		if _scene_has_task_text(child):
			return true
	return false


func _harden_existing_building_materials(root: Node) -> void:
	for node in _flatten(root):
		if not (node is MeshInstance3D):
			continue
		var mesh_instance = node as MeshInstance3D
		var lower_name = mesh_instance.name.to_lower()
		var is_building_part = lower_name.contains("wall") or lower_name.contains("pillar") or lower_name.contains("column") or lower_name.contains("roof") or lower_name.contains("tile") or lower_name.contains("door") or lower_name.contains("window") or lower_name.contains("beam") or lower_name.contains("墙") or lower_name.contains("柱") or lower_name.contains("瓦") or lower_name.contains("门") or lower_name.contains("窗") or lower_name.contains("梁")
		if not is_building_part:
			continue

		var material = mesh_instance.material_override
		if material == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			material = mesh_instance.mesh.surface_get_material(0)
		if material is StandardMaterial3D:
			var hardened = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			hardened.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			hardened.albedo_color.a = 1.0
			hardened.metallic = 0.0
			hardened.roughness = max(hardened.roughness, 0.38)
			hardened.cull_mode = BaseMaterial3D.CULL_BACK
			if hardened.albedo_color.r < 0.025 and hardened.albedo_color.g < 0.025 and hardened.albedo_color.b < 0.025:
				hardened.albedo_color = Color(0.085, 0.062, 0.048, 1.0)
			mesh_instance.material_override = hardened


func _soften_global_rain(root: Node) -> void:
	for node in _flatten(root):
		if node is GPUParticles3D:
			var particles = node as GPUParticles3D
			particles.amount = min(particles.amount, 340)
			particles.lifetime = min(particles.lifetime, 1.35)
			particles.visibility_aabb = AABB(Vector3(-22, -0.5, -28), Vector3(44, 9, 54))


func _flatten(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_flatten(child))
	return result
