extends Node3D
class_name LeftBoundaryClosureSealRuntime

const NODE_LEFT_WING = "LeftWingClosedVolume_Runtime"
const NODE_BOUNDARY = "LeftBoundaryWall_Runtime"
const NODE_REMOTE_TREE = "LeftBoundaryDistantTreeLine_Runtime"

var _materials: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child_name in [NODE_LEFT_WING, NODE_BOUNDARY, NODE_REMOTE_TREE]:
		var old_node = get_node_or_null(child_name)
		if old_node:
			old_node.queue_free()

	_materials = _build_materials()
	_build_left_wing_closed_volume()
	_build_left_boundary_wall()
	_build_distant_tree_line()


func _build_materials() -> Dictionary:
	return {
		"plaster": _make_mat(Color(0.36, 0.35, 0.31), 0.0, 0.78, Color(0.07, 0.075, 0.07), false),
		"plaster_dark": _make_mat(Color(0.18, 0.18, 0.16), 0.0, 0.84, Color(0.03, 0.035, 0.035), false),
		"brick": _make_mat(Color(0.18, 0.19, 0.18), 0.0, 0.72, Color(0.05, 0.055, 0.05), false),
		"stone": _make_mat(Color(0.23, 0.27, 0.29), 0.0, 0.55, Color(0.04, 0.05, 0.055), false),
		"wood": _make_mat(Color(0.17, 0.105, 0.065), 0.0, 0.52, Color(0.035, 0.025, 0.018), false),
		"wood_dark": _make_mat(Color(0.08, 0.055, 0.04), 0.0, 0.68, Color(0.018, 0.015, 0.012), false),
		"tile": _make_mat(Color(0.075, 0.085, 0.088), 0.0, 0.36, Color(0.018, 0.023, 0.026), false),
		"moss": _make_mat(Color(0.065, 0.105, 0.07), 0.0, 0.86, Color(0.012, 0.025, 0.012), false),
		"mud": _make_mat(Color(0.07, 0.052, 0.038), 0.0, 0.93, Color(0.015, 0.011, 0.008), false),
		"dark_room": _make_mat(Color(0.025, 0.023, 0.022), 0.0, 0.96, Color(0.0, 0.0, 0.0), false),
		"paper": _make_mat(Color(0.9, 0.68, 0.38), 0.0, 0.46, Color(1.0, 0.46, 0.14), true)
	}


func _make_mat(albedo: Color, metallic: float, roughness: float, emission: Color, use_emission: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, 1.0)
	mat.metallic = metallic
	mat.roughness = roughness
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	if use_emission:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 0.45
	return mat


func _build_left_wing_closed_volume() -> void:
	var root = Node3D.new()
	root.name = NODE_LEFT_WING
	add_child(root)

	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	# Coordinate choice follows the existing courtyard: negative X is the left wing,
	# Z runs from entrance toward the main hall. The added walls sit behind the facade.
	var x_back = -7.15
	var z_mid = 0.0
	var length = 19.2
	var wall_height = 2.65
	var wall_thick = 0.34

	_add_box(visual, "RearWall_StoneBase", Vector3(wall_thick, 0.48, length), Vector3(x_back, 0.24, z_mid), _materials["stone"])
	_add_box(visual, "RearWall_PlasterBody", Vector3(wall_thick, wall_height, length), Vector3(x_back, 1.55, z_mid), _materials["plaster"])
	_add_box(visual, "RearWall_TopBeam", Vector3(0.42, 0.20, length + 0.24), Vector3(x_back + 0.01, 2.95, z_mid), _materials["wood_dark"])
	_add_box(visual, "RearWall_InteriorShadow", Vector3(0.06, 2.2, length - 0.9), Vector3(x_back + 0.19, 1.55, z_mid), _materials["dark_room"])

	for z in [-9.75, 9.75]:
		_add_box(visual, "SideWall_%s_StoneBase" % z, Vector3(1.95, 0.48, wall_thick), Vector3(-6.25, 0.24, z), _materials["stone"])
		_add_box(visual, "SideWall_%s_PlasterBody" % z, Vector3(1.95, wall_height, wall_thick), Vector3(-6.25, 1.55, z), _materials["plaster_dark"])
		_add_box(visual, "SideWall_%s_EavesSeal" % z, Vector3(2.25, 0.24, 0.44), Vector3(-6.13, 2.93, z), _materials["wood_dark"])

	for z in [-7.2, -3.5, 0.8, 4.9, 8.1]:
		_add_box(visual, "RearWall_WaterStain_%s" % z, Vector3(0.025, 1.05, 0.33), Vector3(x_back + 0.181, 1.12, z), _materials["mud"])
		_add_box(visual, "RearWall_BrickExpose_%s" % z, Vector3(0.028, 0.44, 0.62), Vector3(x_back + 0.183, 1.48, z + 0.35), _materials["brick"])
		_add_box(visual, "RearWall_Moss_%s" % z, Vector3(0.03, 0.16, 1.1), Vector3(x_back + 0.185, 0.53, z - 0.15), _materials["moss"])

	_add_static_box(collision, "ClosedVolumeCollision_Back", Vector3(wall_thick, wall_height + 0.5, length), Vector3(x_back, 1.5, z_mid))
	_add_static_box(collision, "ClosedVolumeCollision_FrontLeftEdge", Vector3(0.62, wall_height + 0.5, length), Vector3(-5.05, 1.5, z_mid))
	_add_static_box(collision, "ClosedVolumeCollision_SideA", Vector3(2.4, wall_height + 0.5, wall_thick), Vector3(-6.12, 1.5, -9.75))
	_add_static_box(collision, "ClosedVolumeCollision_SideB", Vector3(2.4, wall_height + 0.5, wall_thick), Vector3(-6.12, 1.5, 9.75))


func _build_left_boundary_wall() -> void:
	var root = Node3D.new()
	root.name = NODE_BOUNDARY
	add_child(root)

	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	var x = -8.55
	var length = 26.5
	var height = 3.25
	var thick = 0.42

	_add_box(visual, "StoneFoundation", Vector3(thick, 0.46, length), Vector3(x, 0.23, 0.0), _materials["stone"])
	_add_box(visual, "BrickCore", Vector3(thick * 0.92, 1.35, length), Vector3(x, 1.08, 0.0), _materials["brick"])
	_add_box(visual, "WetPlasterSurface", Vector3(thick * 0.96, 2.2, length), Vector3(x + 0.02, 1.82, 0.0), _materials["plaster_dark"])
	_add_box(visual, "WallCapBody", Vector3(thick + 0.24, 0.18, length + 0.25), Vector3(x, height + 0.08, 0.0), _materials["tile"])

	for z in [-12.7, 12.7]:
		_add_box(visual, "BoundaryTurn_%s_Stone" % z, Vector3(3.0, 0.46, thick), Vector3(-7.25, 0.23, z), _materials["stone"])
		_add_box(visual, "BoundaryTurn_%s_Plaster" % z, Vector3(3.0, 2.65, thick), Vector3(-7.25, 1.55, z), _materials["plaster_dark"])
		_add_static_box(collision, "BoundaryTurnCollision_%s" % z, Vector3(3.0, 3.45, thick), Vector3(-7.25, 1.72, z))

	for z in [-11.5, -8.2, -5.4, -2.1, 1.9, 5.7, 9.8, 12.1]:
		_add_box(visual, "Boundary_WaterStain_%s" % z, Vector3(0.035, 1.25, 0.40), Vector3(x + 0.235, 1.25, z), _materials["mud"])
		_add_box(visual, "Boundary_PlasterDamage_%s" % z, Vector3(0.038, 0.65, 0.78), Vector3(x + 0.238, 1.95, z + 0.22), _materials["brick"])
		_add_box(visual, "Boundary_MossBase_%s" % z, Vector3(0.04, 0.18, 1.45), Vector3(x + 0.245, 0.53, z - 0.2), _materials["moss"])

	# Small cap tiles read as individual wet clay ridges without creating heavy geometry.
	for i in range(34):
		var z_pos = -12.8 + float(i) * 0.78
		var tile = _add_box(visual, "WallCapTile_%02d" % i, Vector3(0.62, 0.11, 0.46), Vector3(x + 0.01, height + 0.23, z_pos), _materials["tile"])
		tile.rotation_degrees.z = -4.0 + float(i % 3) * 4.0

	_add_static_box(collision, "BoundaryCollision_Long", Vector3(thick, 3.55, length), Vector3(x, 1.78, 0.0))


func _build_distant_tree_line() -> void:
	var root = Node3D.new()
	root.name = NODE_REMOTE_TREE
	add_child(root)

	var mat = _make_mat(Color(0.018, 0.027, 0.026), 0.0, 0.94, Color.BLACK, false)
	for i in range(10):
		var h = 2.0 + float(i % 4) * 0.55
		var z = -12.0 + float(i) * 2.7
		var x = -9.45 - float(i % 3) * 0.35
		var trunk = _add_box(root, "DistantTreeTrunk_%02d" % i, Vector3(0.16, h, 0.16), Vector3(x, h * 0.5, z), mat)
		trunk.rotation_degrees.z = -4.0 + float(i % 5)
		_add_box(root, "DistantTreeCrown_%02d" % i, Vector3(0.85, 0.95, 0.22), Vector3(x - 0.12, h + 0.35, z), mat)


func _add_box(parent: Node, node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var node = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.set_surface_override_material(0, material)
	parent.add_child(node)
	return node


func _add_static_box(parent: Node, node_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body
