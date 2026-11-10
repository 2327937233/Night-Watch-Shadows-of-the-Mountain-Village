extends Node3D
class_name LeftBoundaryClosureV3

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
const WING_INTERIOR_HEIGHT = 2.35

const BOUNDARY_THICKNESS = 0.42
const BOUNDARY_HEIGHT = 3.45
const BOUNDARY_BASE_HEIGHT = 0.38
const CAP_HEIGHT = 0.32

var _materials: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_clear_generated()
	_materials = _build_materials()

	var wing = Node3D.new()
	wing.name = "LeftWingClosedVolume"
	add_child(wing)
	_build_left_wing_closure(wing)

	var boundary = Node3D.new()
	boundary.name = "LeftBoundaryWall"
	add_child(boundary)
	_build_boundary_wall(boundary)


func get_diagnosis() -> String:
	return "The left wing was primarily a courtyard-facing facade/open test structure: rear wall, side walls, and a real left boundary wall were missing, so the camera could see the map exterior. Added thick opaque rear/side walls, a full boundary wall, wall-cap tiles, simplified collision, and non-transparent PBR-style materials."


func _clear_generated() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _build_materials() -> Dictionary:
	return {
		"plaster": _load_or_make_material("res://materials/walls/courtyard_wall_plaster_wet.tres", Color(0.24, 0.225, 0.20, 1.0), 0.82),
		"brick": _load_or_make_material("res://materials/walls/courtyard_wall_brick_old.tres", Color(0.12, 0.13, 0.125, 1.0), 0.76),
		"stone": _load_or_make_material("res://materials/walls/courtyard_wall_stone_base.tres", Color(0.16, 0.18, 0.18, 1.0), 0.64),
		"tile": _load_or_make_material("res://materials/roof/wall_cap_tiles_wet.tres", Color(0.055, 0.065, 0.07, 1.0), 0.38),
		"interior": _load_or_make_material("res://materials/walls/interior_dark_wet.tres", Color(0.025, 0.028, 0.03, 1.0), 0.9),
		"moss": _load_or_make_material("res://materials/walls/moss_dark_wet.tres", Color(0.055, 0.09, 0.055, 1.0), 0.72),
		"stain": _load_or_make_material("res://materials/walls/rain_stain_wet.tres", Color(0.035, 0.038, 0.035, 1.0), 0.66),
		"distant": _load_or_make_material("res://materials/walls/distant_tree_mist.tres", Color(0.02, 0.035, 0.04, 1.0), 0.95),
	}


func _load_or_make_material(path: String, color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is StandardMaterial3D:
			material = loaded
	if material == null:
		material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = roughness
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


func _build_left_wing_closure(root: Node3D) -> void:
	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	var length = abs(WING_START_Z - WING_END_Z)
	var mid_z = (WING_START_Z + WING_END_Z) * 0.5

	_add_box(visual, "RearWallStoneBase", Vector3(WING_REAR_X, WING_BASE_HEIGHT * 0.5, mid_z), Vector3(WING_WALL_THICKNESS, WING_BASE_HEIGHT, length), _materials["stone"])
	_add_box(visual, "RearWallBrickCore", Vector3(WING_REAR_X, 1.15, mid_z), Vector3(WING_WALL_THICKNESS, 1.55, length), _materials["brick"])
	_add_box(visual, "RearWallPlasterSurface", Vector3(WING_REAR_X + 0.012, 1.62, mid_z), Vector3(0.055, 2.05, length - 0.45), _materials["plaster"])

	_add_box(visual, "NearSideWall", Vector3((WING_FRONT_X + WING_REAR_X) * 0.5, 1.35, WING_START_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 2.7, WING_WALL_THICKNESS), _materials["plaster"])
	_add_box(visual, "FarSideWall", Vector3((WING_FRONT_X + WING_REAR_X) * 0.5, 1.35, WING_END_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 2.7, WING_WALL_THICKNESS), _materials["plaster"])

	_add_box(visual, "InteriorDarkVolume", Vector3((WING_FRONT_X + WING_REAR_X) * 0.5, 1.15, mid_z), Vector3(abs(WING_FRONT_X - WING_REAR_X) - 0.18, WING_INTERIOR_HEIGHT, length - 0.45), _materials["interior"])
	_add_box(visual, "CeilingDarkVolume", Vector3((WING_FRONT_X + WING_REAR_X) * 0.5, 2.62, mid_z), Vector3(abs(WING_FRONT_X - WING_REAR_X) + 0.12, 0.16, length), _materials["interior"])
	_add_box(visual, "RoofBackClosureBeam", Vector3(WING_REAR_X, 2.78, mid_z), Vector3(0.44, 0.28, length), _materials["tile"])

	_add_damage_patches(visual, WING_REAR_X + 0.055, mid_z, length)
	_add_static_box(collision, "RearWallCollision", Vector3(WING_REAR_X, 1.6, mid_z), Vector3(WING_WALL_THICKNESS, 3.2, length))
	_add_static_box(collision, "NearSideWallCollision", Vector3((WING_FRONT_X + WING_REAR_X) * 0.5, 1.55, WING_START_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 3.1, WING_WALL_THICKNESS))
	_add_static_box(collision, "FarSideWallCollision", Vector3((WING_FRONT_X + WING_REAR_X) * 0.5, 1.55, WING_END_Z), Vector3(abs(WING_FRONT_X - WING_REAR_X), 3.1, WING_WALL_THICKNESS))


func _build_boundary_wall(root: Node3D) -> void:
	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	var length = abs(BOUNDARY_START_Z - BOUNDARY_END_Z)
	var mid_z = (BOUNDARY_START_Z + BOUNDARY_END_Z) * 0.5

	_add_box(visual, "StoneFoundation", Vector3(BOUNDARY_X, BOUNDARY_BASE_HEIGHT * 0.5, mid_z), Vector3(BOUNDARY_THICKNESS, BOUNDARY_BASE_HEIGHT, length), _materials["stone"])
	_add_box(visual, "BrickCore", Vector3(BOUNDARY_X, 1.55, mid_z), Vector3(BOUNDARY_THICKNESS, 2.55, length), _materials["brick"])
	_add_box(visual, "PlasterSurface_CourtyardSide", Vector3(BOUNDARY_X + 0.025, 1.78, mid_z), Vector3(0.06, 2.75, length - 0.35), _materials["plaster"])
	_add_box(visual, "PlasterSurface_BackSide", Vector3(BOUNDARY_X - 0.025, 1.78, mid_z), Vector3(0.06, 2.75, length - 0.35), _materials["plaster"])

	_add_wall_cap_tiles(visual, BOUNDARY_X, 3.54, BOUNDARY_START_Z, BOUNDARY_END_Z)
	_add_grass_tufts(visual, BOUNDARY_X + 0.22, BOUNDARY_START_Z, BOUNDARY_END_Z)
	_add_distant_silhouettes(visual, BOUNDARY_X - 1.05, BOUNDARY_START_Z, BOUNDARY_END_Z)

	_add_box(visual, "NearCornerReturnWall", Vector3((BOUNDARY_X + WING_REAR_X) * 0.5, 1.58, BOUNDARY_START_Z), Vector3(abs(BOUNDARY_X - WING_REAR_X), 3.1, BOUNDARY_THICKNESS), _materials["brick"])
	_add_box(visual, "FarCornerReturnWall", Vector3((BOUNDARY_X + WING_REAR_X) * 0.5, 1.58, BOUNDARY_END_Z), Vector3(abs(BOUNDARY_X - WING_REAR_X), 3.1, BOUNDARY_THICKNESS), _materials["brick"])

	_add_static_box(collision, "WallCollision_01", Vector3(BOUNDARY_X, 1.85, mid_z), Vector3(BOUNDARY_THICKNESS, 3.7, length))
	_add_static_box(collision, "NearCornerCollision", Vector3((BOUNDARY_X + WING_REAR_X) * 0.5, 1.65, BOUNDARY_START_Z), Vector3(abs(BOUNDARY_X - WING_REAR_X), 3.3, BOUNDARY_THICKNESS))
	_add_static_box(collision, "FarCornerCollision", Vector3((BOUNDARY_X + WING_REAR_X) * 0.5, 1.65, BOUNDARY_END_Z), Vector3(abs(BOUNDARY_X - WING_REAR_X), 3.3, BOUNDARY_THICKNESS))


func _add_wall_cap_tiles(parent: Node3D, x: float, y: float, z_start: float, z_end: float) -> void:
	var cap_root = Node3D.new()
	cap_root.name = "WallCapTiles"
	parent.add_child(cap_root)

	var step: float = 0.62
	var z_start_f: float = float(z_start)
	var z_end_f: float = float(z_end)
	var count: int = int(ceil(abs(z_start_f - z_end_f) / step))
	var dir: float = float(sign(z_end_f - z_start_f))
	if is_equal_approx(dir, 0.0):
		dir = -1.0
	for i in range(count):
		var z: float = z_start_f + dir * (float(i) + 0.5) * step
		var width = 0.58 + 0.06 * sin(float(i) * 1.7)
		var height = CAP_HEIGHT + 0.035 * sin(float(i) * 0.9)
		var tile = _add_box(cap_root, "CapTile_%02d" % i, Vector3(x, y + height * 0.5, z), Vector3(BOUNDARY_THICKNESS + 0.23, height, width), _materials["tile"])
		tile.rotation_degrees.z = 1.2 * sin(float(i) * 0.8)


func _add_damage_patches(parent: Node3D, x: float, mid_z: float, length: float) -> void:
	var decals = Node3D.new()
	decals.name = "DamageMeshes"
	parent.add_child(decals)
	for i in range(14):
		var z = mid_z - length * 0.45 + fmod(float(i) * 2.73, length * 0.9)
		var y = 0.55 + fmod(float(i) * 0.37, 1.65)
		var size_z = 0.32 + fmod(float(i) * 0.19, 0.55)
		var size_y = 0.18 + fmod(float(i) * 0.11, 0.42)
		var mat = _materials["stain"] if i % 3 != 0 else _materials["moss"]
		_add_box(decals, "Patch_%02d" % i, Vector3(x + 0.018, y, z), Vector3(0.018, size_y, size_z), mat, false)


func _add_grass_tufts(parent: Node3D, x: float, z_start: float, z_end: float) -> void:
	var grass = Node3D.new()
	grass.name = "MossAndGrass"
	parent.add_child(grass)
	var length = abs(z_start - z_end)
	for i in range(18):
		var z = z_start + sign(z_end - z_start) * fmod(float(i) * 1.91, length)
		var h = 0.18 + fmod(float(i) * 0.07, 0.22)
		var blade = _add_box(grass, "GrassTuft_%02d" % i, Vector3(x + 0.04 * sin(float(i)), h * 0.5, z), Vector3(0.035, h, 0.16), _materials["moss"], false)
		blade.rotation_degrees.z = -8.0 + fmod(float(i) * 6.0, 16.0)


func _add_distant_silhouettes(parent: Node3D, x: float, z_start: float, z_end: float) -> void:
	var distant = Node3D.new()
	distant.name = "DistantTreeMist"
	parent.add_child(distant)
	var length = abs(z_start - z_end)
	for i in range(7):
		var z = z_start + sign(z_end - z_start) * (float(i) + 0.5) * length / 7.0
		var h = 2.7 + fmod(float(i) * 0.83, 1.5)
		var w = 0.08 + fmod(float(i) * 0.03, 0.06)
		var trunk = _add_box(distant, "TreeSilhouette_%02d" % i, Vector3(x - 0.15 * sin(float(i) * 2.1), h * 0.5, z), Vector3(w, h, 0.16), _materials["distant"], false)
		trunk.rotation_degrees.z = -4.0 + fmod(float(i) * 2.7, 8.0)


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material, cast_shadow = true) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var instance = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_static_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3) -> StaticBody3D:
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
