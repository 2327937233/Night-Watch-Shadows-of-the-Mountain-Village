extends Node3D
class_name LeftBoundaryClosureSeal

const WING_FRONT_X = -5.35
const WING_REAR_X = -7.05
const BOUNDARY_X = -8.55
const WING_START_Z = 12.0
const WING_END_Z = -22.0
const BOUNDARY_START_Z = 13.5
const BOUNDARY_END_Z = -24.0
const WING_WALL_THICKNESS = 0.34
const WING_WALL_HEIGHT = 2.65
const WING_BASE_HEIGHT = 0.28
const BOUNDARY_THICKNESS = 0.42
const BOUNDARY_HEIGHT = 3.45
const BOUNDARY_BASE_HEIGHT = 0.38
const CAP_HEIGHT = 0.32

var materials: Dictionary = {}


func _ready() -> void:
	rebuild()


func get_diagnosis() -> String:
	return "左侧厢房主要问题是建筑只完成了面向庭院的局部立面，缺少连续后墙、端部侧墙和庭院左侧外围墙；玩家或摄像机靠近左侧时会直接看见地图外暗背景。材质透明不是主要原因。"


func rebuild() -> void:
	for child_name in ["LeftWingClosedVolume", "LeftBoundaryWall"]:
		var old_child = get_node_or_null(child_name)
		if old_child:
			old_child.queue_free()

	_prepare_materials()
	_build_left_wing_closed_volume()
	_build_left_boundary_wall()


func _prepare_materials() -> void:
	materials.clear()
	materials["old_wood"] = _make_material("wet_old_dark_wood", Color(0.105, 0.071, 0.047, 1.0), 0.58)
	materials["plaster"] = _make_material("wet_plaster_gray", Color(0.245, 0.242, 0.218, 1.0), 0.74)
	materials["wet_plaster"] = _make_material("plaster_water_stain", Color(0.105, 0.116, 0.105, 1.0), 0.46)
	materials["brick"] = _make_material("old_blue_brick", Color(0.118, 0.132, 0.127, 1.0), 0.68)
	materials["stone"] = _make_material("wet_stone_foundation", Color(0.105, 0.125, 0.132, 1.0), 0.52)
	materials["tile"] = _make_material("wet_small_roof_tile", Color(0.055, 0.069, 0.076, 1.0), 0.38)
	materials["dark_room"] = _make_material("sealed_dark_room_volume", Color(0.018, 0.019, 0.018, 1.0), 0.9)
	materials["moss"] = _make_material("dark_wall_moss", Color(0.046, 0.079, 0.047, 1.0), 0.82)
	materials["water_stain"] = _make_material("vertical_rain_stain", Color(0.052, 0.061, 0.058, 1.0), 0.42)


func _make_material(resource_name: String, albedo: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.resource_name = resource_name
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color = albedo
	material.metallic = 0.0
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.vertex_color_use_as_albedo = false
	return material


func _build_left_wing_closed_volume() -> void:
	var root = Node3D.new()
	root.name = "LeftWingClosedVolume"
	add_child(root)

	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	var wing_length = absf(WING_START_Z - WING_END_Z)
	var center_z = (WING_START_Z + WING_END_Z) * 0.5
	var center_x = (WING_FRONT_X + WING_REAR_X) * 0.5

	_add_box(visual, "RearWall_StoneFoundation", Vector3(WING_REAR_X, WING_BASE_HEIGHT * 0.5, center_z), Vector3(WING_WALL_THICKNESS, WING_BASE_HEIGHT, wing_length), materials["stone"])
	_add_box(visual, "RearWall_OldBrickCore", Vector3(WING_REAR_X, 0.72, center_z), Vector3(WING_WALL_THICKNESS, 0.88, wing_length), materials["brick"])
	_add_box(visual, "RearWall_WetPlasterSurface", Vector3(WING_REAR_X, 1.78, center_z), Vector3(WING_WALL_THICKNESS + 0.02, 1.78, wing_length), materials["plaster"])
	_add_box(visual, "RearWall_RootWetBand", Vector3(WING_REAR_X - 0.018, 0.48, center_z), Vector3(0.035, 0.52, wing_length - 0.35), materials["wet_plaster"])
	_add_box(visual, "RearUpperWoodBeam", Vector3(WING_REAR_X - 0.02, 2.62, center_z), Vector3(0.28, 0.22, wing_length), materials["old_wood"])

	_add_box(visual, "EntrySideWall_ClosedThickness", Vector3(center_x, 1.36, WING_START_Z), Vector3(absf(WING_FRONT_X - WING_REAR_X), WING_WALL_HEIGHT, WING_WALL_THICKNESS), materials["plaster"])
	_add_box(visual, "FarSideWall_ClosedThickness", Vector3(center_x, 1.36, WING_END_Z), Vector3(absf(WING_FRONT_X - WING_REAR_X), WING_WALL_HEIGHT, WING_WALL_THICKNESS), materials["plaster"])
	_add_box(visual, "InteriorDarkBackVolume", Vector3(center_x, 1.18, center_z), Vector3(absf(WING_FRONT_X - WING_REAR_X) - 0.2, 2.14, wing_length - 0.45), materials["dark_room"])
	_add_box(visual, "InteriorCeilingClosure", Vector3(center_x, 2.55, center_z), Vector3(absf(WING_FRONT_X - WING_REAR_X), 0.16, wing_length - 0.2), materials["old_wood"])

	for i in range(10):
		var z = lerpf(WING_START_Z - 1.2, WING_END_Z + 1.2, float(i) / 9.0)
		_add_box(visual, "RearWall_WoodStud_%02d" % i, Vector3(WING_REAR_X - 0.04, 1.58, z), Vector3(0.12, 2.18, 0.09), materials["old_wood"])

	for i in range(8):
		var z_damage = lerpf(WING_START_Z - 1.7, WING_END_Z + 1.4, float(i) / 7.0)
		var y_damage = 0.95 + float(i % 3) * 0.42
		var h = 0.34 + float(i % 2) * 0.22
		_add_box(visual, "RearWall_PlasterDamage_%02d" % i, Vector3(WING_REAR_X - 0.055, y_damage, z_damage), Vector3(0.045, h, 0.62), materials["brick"])

	for i in range(12):
		var z_grass = lerpf(WING_START_Z - 0.6, WING_END_Z + 0.7, float(i) / 11.0)
		_add_grass_cluster(visual, Vector3(WING_REAR_X - 0.32, 0.08, z_grass), "RearWall_Grass_%02d" % i)

	_add_static_box(collision, "RearWallCollision", Vector3(WING_REAR_X, 1.34, center_z), Vector3(WING_WALL_THICKNESS, 2.68, wing_length))
	_add_static_box(collision, "EntrySideWallCollision", Vector3(center_x, 1.34, WING_START_Z), Vector3(absf(WING_FRONT_X - WING_REAR_X), 2.68, WING_WALL_THICKNESS))
	_add_static_box(collision, "FarSideWallCollision", Vector3(center_x, 1.34, WING_END_Z), Vector3(absf(WING_FRONT_X - WING_REAR_X), 2.68, WING_WALL_THICKNESS))


func _build_left_boundary_wall() -> void:
	var root = Node3D.new()
	root.name = "LeftBoundaryWall"
	add_child(root)

	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	var wall_length = absf(BOUNDARY_START_Z - BOUNDARY_END_Z)
	var center_z = (BOUNDARY_START_Z + BOUNDARY_END_Z) * 0.5

	_add_box(visual, "StoneFoundation", Vector3(BOUNDARY_X, BOUNDARY_BASE_HEIGHT * 0.5, center_z), Vector3(BOUNDARY_THICKNESS, BOUNDARY_BASE_HEIGHT, wall_length), materials["stone"])
	_add_box(visual, "OldBrickCore", Vector3(BOUNDARY_X, 1.05, center_z), Vector3(BOUNDARY_THICKNESS, 1.35, wall_length), materials["brick"])
	_add_box(visual, "WetPlasterSurface", Vector3(BOUNDARY_X + 0.015, 2.08, center_z), Vector3(BOUNDARY_THICKNESS + 0.03, 2.05, wall_length), materials["plaster"])
	_add_box(visual, "WallRootWetBand", Vector3(BOUNDARY_X + 0.04, 0.55, center_z), Vector3(0.05, 0.64, wall_length - 0.4), materials["wet_plaster"])
	_add_box(visual, "WallCapBase", Vector3(BOUNDARY_X, BOUNDARY_HEIGHT + 0.04, center_z), Vector3(BOUNDARY_THICKNESS + 0.18, 0.16, wall_length + 0.2), materials["tile"])

	_build_wall_cap_tiles(visual, BOUNDARY_START_Z, BOUNDARY_END_Z)
	_add_boundary_return(visual, collision, BOUNDARY_START_Z, "Entry")
	_add_boundary_return(visual, collision, BOUNDARY_END_Z, "Far")

	for i in range(14):
		var z_damage = lerpf(BOUNDARY_START_Z - 1.0, BOUNDARY_END_Z + 1.0, float(i) / 13.0)
		var y_damage = 0.92 + float((i * 7) % 5) * 0.34
		var width = 0.42 + float(i % 3) * 0.16
		_add_box(visual, "PlasterDamage_%02d" % i, Vector3(BOUNDARY_X + 0.055, y_damage, z_damage), Vector3(0.045, 0.36, width), materials["brick"])

	for i in range(18):
		var z_stain = lerpf(BOUNDARY_START_Z - 0.5, BOUNDARY_END_Z + 0.5, float(i) / 17.0)
		var h = 0.55 + float(i % 4) * 0.18
		_add_box(visual, "VerticalRainStain_%02d" % i, Vector3(BOUNDARY_X + 0.064, 1.75, z_stain), Vector3(0.032, h, 0.09), materials["water_stain"])

	for i in range(22):
		var z_grass = lerpf(BOUNDARY_START_Z, BOUNDARY_END_Z, float(i) / 21.0)
		_add_grass_cluster(visual, Vector3(BOUNDARY_X + 0.36, 0.08, z_grass), "BoundaryGrass_%02d" % i)

	_add_distant_silhouettes(visual)

	_add_static_box(collision, "BoundaryWallCollision", Vector3(BOUNDARY_X, 1.72, center_z), Vector3(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, wall_length))


func _add_boundary_return(visual: Node3D, collision: Node3D, z_pos: float, suffix: String) -> void:
	var center_x = (BOUNDARY_X + WING_REAR_X) * 0.5
	var length_x = absf(BOUNDARY_X - WING_REAR_X)
	_add_box(visual, "%sReturn_StoneFoundation" % suffix, Vector3(center_x, BOUNDARY_BASE_HEIGHT * 0.5, z_pos), Vector3(length_x, BOUNDARY_BASE_HEIGHT, BOUNDARY_THICKNESS), materials["stone"])
	_add_box(visual, "%sReturn_OldBrickCore" % suffix, Vector3(center_x, 1.05, z_pos), Vector3(length_x, 1.35, BOUNDARY_THICKNESS), materials["brick"])
	_add_box(visual, "%sReturn_WetPlasterSurface" % suffix, Vector3(center_x, 2.08, z_pos), Vector3(length_x, 2.05, BOUNDARY_THICKNESS), materials["plaster"])
	_add_box(visual, "%sReturn_WallCap" % suffix, Vector3(center_x, BOUNDARY_HEIGHT + 0.05, z_pos), Vector3(length_x + 0.15, 0.18, BOUNDARY_THICKNESS + 0.16), materials["tile"])
	_add_static_box(collision, "%sReturnWallCollision" % suffix, Vector3(center_x, 1.72, z_pos), Vector3(length_x, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS))


func _build_wall_cap_tiles(visual: Node3D, z_start: float, z_end: float) -> void:
	var count = 44
	for i in range(count):
		var t = float(i) / float(count - 1)
		var z = lerpf(z_start, z_end, t)
		var y = BOUNDARY_HEIGHT + CAP_HEIGHT * 0.5 + sin(t * TAU * 5.0) * 0.012
		var tile_size = Vector3(BOUNDARY_THICKNESS + 0.32, CAP_HEIGHT, 0.46)
		_add_box(visual, "WallCapTile_%02d" % i, Vector3(BOUNDARY_X, y, z), tile_size, materials["tile"], 0.0)


func _add_distant_silhouettes(visual: Node3D) -> void:
	var silhouette_material = _make_material("distant_wet_tree_silhouette", Color(0.018, 0.028, 0.031, 1.0), 0.92)
	var mist_material = _make_material("left_wall_distant_cold_mist", Color(0.04, 0.054, 0.058, 1.0), 0.95)
	var wall_length = absf(BOUNDARY_START_Z - BOUNDARY_END_Z)
	var center_z = (BOUNDARY_START_Z + BOUNDARY_END_Z) * 0.5
	_add_box(visual, "DistantTreeMassBehindWall", Vector3(BOUNDARY_X - 1.35, 3.2, center_z), Vector3(0.22, 2.8, wall_length + 3.0), silhouette_material)
	_add_box(visual, "DistantUpperMistLayer", Vector3(BOUNDARY_X - 1.12, 4.55, center_z), Vector3(0.12, 1.15, wall_length + 2.0), mist_material)


func _add_grass_cluster(visual: Node3D, origin: Vector3, prefix: String) -> void:
	for blade_index in range(3):
		var height = 0.22 + float(blade_index) * 0.06
		var x_offset = (float(blade_index) - 1.0) * 0.055
		var z_offset = float((blade_index * 5) % 3 - 1) * 0.055
		_add_box(visual, "%s_blade_%d" % [prefix, blade_index], origin + Vector3(x_offset, height * 0.5, z_offset), Vector3(0.025, height, 0.035), materials["moss"], 0.12 * float(blade_index - 1))


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var node = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.rotation.y = rot_y
	node.set_surface_override_material(0, material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


func _add_static_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation.y = rot_y
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body
