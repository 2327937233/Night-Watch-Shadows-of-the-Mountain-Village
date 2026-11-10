extends Node3D
class_name LeftBoundaryClosureFinal

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

var _materials: Dictionary = {}


func _ready() -> void:
	rebuild()


func get_diagnosis() -> String:
	return "透明空白的主要原因不是材质 Alpha，而是左侧厢房此前更接近单面立面：后墙、侧墙和外侧庭院边界没有形成封闭体积，摄像机靠近后会直接看到地图外黑色背景。"


func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	_prepare_materials()
	_build_left_wing_closed_volume()
	_build_left_boundary_wall()


func _prepare_materials() -> void:
	_materials.clear()
	_materials["old_wood"] = _make_material(Color(0.135, 0.095, 0.065, 1.0), 0.0, 0.58)
	_materials["wet_wood"] = _make_material(Color(0.095, 0.068, 0.048, 1.0), 0.0, 0.38)
	_materials["plaster"] = _make_material(Color(0.275, 0.255, 0.215, 1.0), 0.0, 0.72)
	_materials["wet_plaster"] = _make_material(Color(0.145, 0.142, 0.125, 1.0), 0.0, 0.48)
	_materials["old_brick"] = _make_material(Color(0.155, 0.155, 0.145, 1.0), 0.0, 0.68)
	_materials["stone_base"] = _make_material(Color(0.135, 0.155, 0.16, 1.0), 0.0, 0.52)
	_materials["tile"] = _make_material(Color(0.078, 0.085, 0.085, 1.0), 0.0, 0.36)
	_materials["dark_room"] = _make_material(Color(0.018, 0.017, 0.015, 1.0), 0.0, 0.92)
	_materials["moss"] = _make_material(Color(0.06, 0.095, 0.055, 1.0), 0.0, 0.83)
	_materials["water_stain"] = _make_material(Color(0.055, 0.062, 0.06, 1.0), 0.0, 0.34)


func _make_material(albedo: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
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

	var center_z = (WING_START_Z + WING_END_Z) * 0.5
	var length_z = abs(WING_START_Z - WING_END_Z)
	var inner_x = (WING_FRONT_X + WING_REAR_X) * 0.5

	_add_box(visual, "RearStoneFoundation", Vector3(WING_REAR_X, WING_BASE_HEIGHT * 0.5, center_z), Vector3(WING_WALL_THICKNESS, WING_BASE_HEIGHT, length_z), "stone_base")
	_add_box(visual, "RearBrickCore", Vector3(WING_REAR_X, 1.02, center_z), Vector3(WING_WALL_THICKNESS * 0.96, 1.48, length_z), "old_brick")
	_add_box(visual, "RearWetPlasterSurface", Vector3(WING_REAR_X + 0.012, 1.42, center_z), Vector3(WING_WALL_THICKNESS * 0.98, 2.26, length_z), "plaster")
	_add_box(visual, "RearWallWetRootBand", Vector3(WING_REAR_X + 0.025, 0.48, center_z), Vector3(0.045, 0.55, length_z), "wet_plaster")

	_add_box(visual, "EntrySideWallStoneBase", Vector3(inner_x, WING_BASE_HEIGHT * 0.5, WING_START_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), WING_BASE_HEIGHT, WING_WALL_THICKNESS), "stone_base")
	_add_box(visual, "EntrySideWallPlaster", Vector3(inner_x, 1.42, WING_START_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 2.26, WING_WALL_THICKNESS), "plaster")
	_add_box(visual, "FarSideWallStoneBase", Vector3(inner_x, WING_BASE_HEIGHT * 0.5, WING_END_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), WING_BASE_HEIGHT, WING_WALL_THICKNESS), "stone_base")
	_add_box(visual, "FarSideWallPlaster", Vector3(inner_x, 1.42, WING_END_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 2.26, WING_WALL_THICKNESS), "wet_plaster")

	_add_box(visual, "ClosedDarkInteriorVolume", Vector3(inner_x, 1.35, center_z), Vector3(1.22, 2.2, length_z - 0.55), "dark_room")
	_add_box(visual, "InteriorCeilingClosure", Vector3(inner_x, 2.68, center_z), Vector3(1.56, 0.16, length_z - 0.15), "dark_room")
	_add_box(visual, "RearUpperBeam", Vector3(WING_REAR_X + 0.08, 2.52, center_z), Vector3(0.22, 0.22, length_z), "wet_wood")

	for z in [10.6, 6.4, 1.8, -3.9, -9.7, -16.6, -21.0]:
		_add_box(visual, "RearEmbeddedVerticalWood_%s" % str(z), Vector3(WING_REAR_X + 0.09, 1.46, z), Vector3(0.16, 2.16, 0.18), "wet_wood")

	_add_wall_damage(visual, WING_REAR_X + 0.19, WING_START_Z - 2.4, -1.0, "WingRearDamageA")
	_add_wall_damage(visual, WING_REAR_X + 0.19, 2.0, -9.2, "WingRearDamageB")
	_add_wall_damage(visual, WING_REAR_X + 0.19, WING_END_Z + 3.5, -0.7, "WingRearDamageC")
	_add_grass_cluster(visual, "WingBackGrassA", WING_REAR_X + 0.34, 0.05, 8.8)
	_add_grass_cluster(visual, "WingBackGrassB", WING_REAR_X + 0.32, 0.05, -7.8)
	_add_grass_cluster(visual, "WingBackGrassC", WING_REAR_X + 0.33, 0.05, -18.6)

	_add_static_box(collision, "RearWallCollision", Vector3(WING_REAR_X, 1.35, center_z), Vector3(WING_WALL_THICKNESS, 2.7, length_z))
	_add_static_box(collision, "EntrySideWallCollision", Vector3(inner_x, 1.35, WING_START_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 2.7, WING_WALL_THICKNESS))
	_add_static_box(collision, "FarSideWallCollision", Vector3(inner_x, 1.35, WING_END_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 2.7, WING_WALL_THICKNESS))


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

	var center_z = (BOUNDARY_START_Z + BOUNDARY_END_Z) * 0.5
	var length_z = abs(BOUNDARY_START_Z - BOUNDARY_END_Z)
	var inner_face_x = BOUNDARY_X + BOUNDARY_THICKNESS * 0.5 + 0.01

	_add_box(visual, "StoneFoundation", Vector3(BOUNDARY_X, BOUNDARY_BASE_HEIGHT * 0.5, center_z), Vector3(BOUNDARY_THICKNESS, BOUNDARY_BASE_HEIGHT, length_z), "stone_base")
	_add_box(visual, "OldBrickCore", Vector3(BOUNDARY_X, 1.24, center_z), Vector3(BOUNDARY_THICKNESS * 0.94, 1.72, length_z), "old_brick")
	_add_box(visual, "WetPlasterSurface", Vector3(inner_face_x, 1.72, center_z), Vector3(0.055, 2.38, length_z), "plaster")
	_add_box(visual, "WallRootWetBand", Vector3(inner_face_x + 0.025, 0.48, center_z), Vector3(0.045, 0.58, length_z), "wet_plaster")
	_add_box(visual, "WallTopCapBase", Vector3(BOUNDARY_X, BOUNDARY_HEIGHT + CAP_HEIGHT * 0.5, center_z), Vector3(BOUNDARY_THICKNESS + 0.26, CAP_HEIGHT, length_z + 0.28), "tile")
	_build_wall_cap_tiles(visual, BOUNDARY_X, BOUNDARY_HEIGHT + CAP_HEIGHT + 0.04, center_z, length_z)

	for z in [12.1, 8.7, 4.3, -0.9, -5.1, -10.8, -15.7, -21.3]:
		_add_box(visual, "VerticalRainStain_%s" % str(z), Vector3(inner_face_x + 0.035, 1.58, z), Vector3(0.026, 1.55, 0.18), "water_stain")
	for z in [10.5, 2.6, -6.2, -13.7, -20.0]:
		_add_wall_damage(visual, inner_face_x + 0.045, z, -0.18, "BoundaryDamage_%s" % str(z))
	for z in [11.2, 6.0, -1.2, -8.6, -17.2, -22.4]:
		_add_grass_cluster(visual, "BoundaryGrass_%s" % str(z), inner_face_x + 0.1, 0.05, z)

	_add_boundary_return(visual, collision, BOUNDARY_START_Z, "EntryReturnWall")
	_add_boundary_return(visual, collision, BOUNDARY_END_Z, "FarReturnWall")
	_add_distant_silhouettes(visual)

	_add_static_box(collision, "BoundaryWallCollision", Vector3(BOUNDARY_X, BOUNDARY_HEIGHT * 0.5, center_z), Vector3(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, length_z))


func _build_wall_cap_tiles(parent: Node, x: float, y: float, center_z: float, length_z: float) -> void:
	var count = int(length_z / 0.62)
	var start_z = center_z - length_z * 0.5
	for i in range(count):
		var z = start_z + float(i) * 0.62 + 0.31
		var tile = _add_box(parent, "WallCapTile_%02d" % i, Vector3(x, y, z), Vector3(0.64, 0.16, 0.44), "tile")
		tile.rotation_degrees.z = -4.0 if i % 2 == 0 else 4.0
		tile.rotation_degrees.y = -2.5 if i % 3 == 0 else 1.5


func _add_boundary_return(visual: Node, collision: Node, z: float, node_name: String) -> void:
	var center_x = (BOUNDARY_X + WING_REAR_X) * 0.5
	var length_x = abs(BOUNDARY_X - WING_REAR_X) + BOUNDARY_THICKNESS
	_add_box(visual, node_name + "_StoneFoundation", Vector3(center_x, BOUNDARY_BASE_HEIGHT * 0.5, z), Vector3(length_x, BOUNDARY_BASE_HEIGHT, BOUNDARY_THICKNESS), "stone_base")
	_add_box(visual, node_name + "_Plaster", Vector3(center_x, 1.72, z), Vector3(length_x, 2.38, BOUNDARY_THICKNESS), "wet_plaster")
	_add_box(visual, node_name + "_Cap", Vector3(center_x, BOUNDARY_HEIGHT + CAP_HEIGHT * 0.5, z), Vector3(length_x + 0.25, CAP_HEIGHT, BOUNDARY_THICKNESS + 0.16), "tile")
	_add_static_box(collision, node_name + "_Collision", Vector3(center_x, BOUNDARY_HEIGHT * 0.5, z), Vector3(length_x, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS))


func _add_distant_silhouettes(parent: Node) -> void:
	for i in range(7):
		var z = BOUNDARY_START_Z - 3.0 - float(i) * 5.2
		var trunk = _add_box(parent, "DistantTreeTrunk_%02d" % i, Vector3(BOUNDARY_X - 0.85, 2.0, z), Vector3(0.14, 4.0 + float(i % 3) * 0.6, 0.16), "dark_room")
		trunk.rotation_degrees.z = -8.0 + float(i % 4) * 4.0
		_add_box(parent, "DistantTreeCanopy_%02d" % i, Vector3(BOUNDARY_X - 0.95, 4.0, z + 0.2), Vector3(1.2, 1.0, 1.1), "dark_room")


func _add_wall_damage(parent: Node, x: float, z: float, y_offset: float, node_name: String) -> void:
	_add_box(parent, node_name + "_BrickExposure", Vector3(x, 1.35 + y_offset, z), Vector3(0.035, 0.72, 1.12), "old_brick")
	_add_box(parent, node_name + "_DarkWetEdge", Vector3(x + 0.018, 0.62 + y_offset * 0.2, z + 0.17), Vector3(0.022, 0.48, 0.86), "water_stain")


func _add_grass_cluster(parent: Node, node_name: String, x: float, y: float, z: float) -> void:
	var cluster = Node3D.new()
	cluster.name = node_name
	parent.add_child(cluster)
	for i in range(6):
		var blade = _add_box(cluster, "GrassBlade_%02d" % i, Vector3(float(i - 3) * 0.035, y + 0.18, float(i % 3) * 0.06), Vector3(0.018, 0.36 + float(i % 2) * 0.16, 0.018), "moss")
		blade.rotation_degrees.x = -12.0 + float(i) * 4.0
		blade.rotation_degrees.z = -18.0 + float(i % 4) * 11.0
	cluster.position = Vector3(x, 0.0, z)


func _add_box(parent: Node, node_name: String, position: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var instance = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	if _materials.has(material_key):
		instance.material_override = _materials[material_key]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_static_box(parent: Node, node_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = position
	var shape = CollisionShape3D.new()
	shape.name = node_name + "Shape"
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body
