extends Node3D
class_name LeftBoundaryClosureV4

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

var mat_plaster: StandardMaterial3D
var mat_brick: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_tile: StandardMaterial3D
var mat_dark_room: StandardMaterial3D
var mat_moss: StandardMaterial3D
var mat_water_stain: StandardMaterial3D
var mat_tree: StandardMaterial3D


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	_build_materials()
	_build_left_wing_closed_volume()
	_build_boundary_wall()


func get_diagnosis() -> String:
	return "左侧透明空白的根本原因是左侧厢房主要由面向庭院的立面、柱廊、屋檐和道具组成，背后与外侧没有完整封闭建筑体积；摄像机绕到背侧后会看到单面或缺失墙面后的地图外黑色背景。本脚本补齐了有厚度的厢房后墙、两端侧墙、暗室体积、左侧外围墙、转角闭合墙和简化碰撞。"


func _build_materials() -> void:
	mat_plaster = _load_or_make("res://materials/walls/left_boundary_plaster_wet_final.tres", _make_material("left_boundary_plaster_runtime", Color(0.34, 0.34, 0.31, 1.0), 0.76))
	mat_brick = _load_or_make("res://materials/walls/left_boundary_brick_old_final.tres", _make_material("left_boundary_brick_runtime", Color(0.18, 0.19, 0.18, 1.0), 0.72))
	mat_stone = _load_or_make("res://materials/walls/left_boundary_stone_base_final.tres", _make_material("left_boundary_stone_runtime", Color(0.19, 0.23, 0.24, 1.0), 0.58))
	mat_tile = _load_or_make("res://materials/roof/left_boundary_cap_tiles_wet_final.tres", _make_material("left_boundary_cap_tiles_runtime", Color(0.08, 0.10, 0.11, 1.0), 0.38))
	mat_dark_room = _load_or_make("res://materials/walls/left_boundary_dark_interior_final.tres", _make_material("left_boundary_dark_room_runtime", Color(0.025, 0.028, 0.028, 1.0), 0.88))
	mat_moss = _load_or_make("res://materials/walls/left_boundary_moss_wet_final.tres", _make_material("left_boundary_moss_runtime", Color(0.05, 0.095, 0.065, 1.0), 0.82))
	mat_water_stain = _load_or_make("res://materials/walls/left_boundary_water_stain_final.tres", _make_material("left_boundary_water_stain_runtime", Color(0.055, 0.065, 0.062, 1.0), 0.44))
	mat_tree = _make_material("left_boundary_distant_trees_runtime", Color(0.018, 0.026, 0.025, 1.0), 0.94)


func _load_or_make(path: String, fallback: StandardMaterial3D) -> StandardMaterial3D:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is StandardMaterial3D:
			return loaded
	return fallback


func _make_material(material_name: String, albedo: Color, roughness: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.resource_name = material_name
	mat.albedo_color = albedo
	mat.metallic = 0.0
	mat.roughness = roughness
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.vertex_color_use_as_albedo = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat


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

	var length = abs(WING_START_Z - WING_END_Z)
	var mid_z = (WING_START_Z + WING_END_Z) * 0.5
	var depth = abs(WING_FRONT_X - WING_REAR_X)
	var mid_x = (WING_FRONT_X + WING_REAR_X) * 0.5
	var wall_y = WING_BASE_HEIGHT + WING_WALL_HEIGHT * 0.5

	_add_box(visual, "RearWall_ThickPlaster", Vector3(WING_REAR_X, wall_y, mid_z), Vector3(WING_WALL_THICKNESS, WING_WALL_HEIGHT, length), mat_plaster)
	_add_box(visual, "RearWall_StoneFooting", Vector3(WING_REAR_X + 0.01, BOUNDARY_BASE_HEIGHT * 0.5, mid_z), Vector3(WING_WALL_THICKNESS + 0.04, BOUNDARY_BASE_HEIGHT, length), mat_stone)
	_add_box(visual, "LeftEndSideWall", Vector3(mid_x, wall_y, WING_START_Z), Vector3(depth + WING_WALL_THICKNESS, WING_WALL_HEIGHT, WING_WALL_THICKNESS), mat_plaster)
	_add_box(visual, "FarEndSideWall", Vector3(mid_x, wall_y, WING_END_Z), Vector3(depth + WING_WALL_THICKNESS, WING_WALL_HEIGHT, WING_WALL_THICKNESS), mat_plaster)
	_add_box(visual, "InteriorDarkBackVolume", Vector3(mid_x, 1.25, mid_z), Vector3(depth - 0.22, 2.35, length - 0.5), mat_dark_room, false)
	_add_box(visual, "InteriorCeilingClosure", Vector3(mid_x, 2.72, mid_z), Vector3(depth + 0.12, 0.16, length), mat_dark_room)
	_add_box(visual, "RearWallTopBeam", Vector3(WING_REAR_X + 0.16, 2.78, mid_z), Vector3(0.24, 0.22, length), mat_tile)

	_add_damage_patches(visual, WING_REAR_X + 0.18, WING_START_Z - 0.8, WING_END_Z + 0.8, 18)
	_add_grass_tufts(visual, WING_REAR_X + 0.35, WING_START_Z - 1.0, WING_END_Z + 1.0, 20)

	_add_static_box(collision, "RearWallCollision", Vector3(WING_REAR_X, 1.55, mid_z), Vector3(WING_WALL_THICKNESS, 3.1, length))
	_add_static_box(collision, "EntrySideWallCollision", Vector3(mid_x, 1.55, WING_START_Z), Vector3(depth + WING_WALL_THICKNESS, 3.1, WING_WALL_THICKNESS))
	_add_static_box(collision, "FarSideWallCollision", Vector3(mid_x, 1.55, WING_END_Z), Vector3(depth + WING_WALL_THICKNESS, 3.1, WING_WALL_THICKNESS))


func _build_boundary_wall() -> void:
	var root = Node3D.new()
	root.name = "LeftBoundaryWall"
	add_child(root)

	var visual = Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)

	var collision = Node3D.new()
	collision.name = "CollisionRoot"
	root.add_child(collision)

	var length = abs(BOUNDARY_START_Z - BOUNDARY_END_Z)
	var mid_z = (BOUNDARY_START_Z + BOUNDARY_END_Z) * 0.5
	var wall_y = BOUNDARY_BASE_HEIGHT + (BOUNDARY_HEIGHT - BOUNDARY_BASE_HEIGHT) * 0.5

	_add_box(visual, "StoneFoundation", Vector3(BOUNDARY_X, BOUNDARY_BASE_HEIGHT * 0.5, mid_z), Vector3(BOUNDARY_THICKNESS + 0.08, BOUNDARY_BASE_HEIGHT, length), mat_stone)
	_add_box(visual, "BrickCore", Vector3(BOUNDARY_X, BOUNDARY_BASE_HEIGHT + 0.68, mid_z), Vector3(BOUNDARY_THICKNESS, 1.36, length), mat_brick)
	_add_box(visual, "PlasterSurface", Vector3(BOUNDARY_X + 0.025, wall_y, mid_z), Vector3(BOUNDARY_THICKNESS + 0.05, BOUNDARY_HEIGHT - BOUNDARY_BASE_HEIGHT, length), mat_plaster)
	_add_box(visual, "InnerWetShadowStrip", Vector3(BOUNDARY_X + 0.245, 0.9, mid_z), Vector3(0.035, 1.15, length - 0.8), mat_water_stain)

	_add_wall_cap_tiles(visual, BOUNDARY_START_Z, BOUNDARY_END_Z)
	_add_damage_patches(visual, BOUNDARY_X + 0.245, BOUNDARY_START_Z - 0.6, BOUNDARY_END_Z + 0.6, 26)
	_add_grass_tufts(visual, BOUNDARY_X + 0.38, BOUNDARY_START_Z - 0.8, BOUNDARY_END_Z + 0.8, 28)
	_add_distant_silhouettes(visual, BOUNDARY_START_Z, BOUNDARY_END_Z)

	_build_boundary_returns(visual, collision)

	_add_static_box(collision, "MainBoundaryCollision", Vector3(BOUNDARY_X, 1.85, mid_z), Vector3(BOUNDARY_THICKNESS, 3.7, length))


func _build_boundary_returns(visual: Node3D, collision: Node3D) -> void:
	var return_width = abs(BOUNDARY_X - WING_REAR_X)
	var return_x = (BOUNDARY_X + WING_REAR_X) * 0.5
	var return_size = Vector3(return_width, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS)
	var return_y = BOUNDARY_HEIGHT * 0.5

	_add_box(visual, "EntryCornerReturnWall", Vector3(return_x, return_y, BOUNDARY_START_Z), return_size, mat_plaster)
	_add_box(visual, "FarCornerReturnWall", Vector3(return_x, return_y, BOUNDARY_END_Z), return_size, mat_plaster)
	_add_box(visual, "EntryCornerStoneBase", Vector3(return_x, BOUNDARY_BASE_HEIGHT * 0.5, BOUNDARY_START_Z), Vector3(return_width, BOUNDARY_BASE_HEIGHT, BOUNDARY_THICKNESS + 0.08), mat_stone)
	_add_box(visual, "FarCornerStoneBase", Vector3(return_x, BOUNDARY_BASE_HEIGHT * 0.5, BOUNDARY_END_Z), Vector3(return_width, BOUNDARY_BASE_HEIGHT, BOUNDARY_THICKNESS + 0.08), mat_stone)

	_add_static_box(collision, "EntryReturnCollision", Vector3(return_x, 1.85, BOUNDARY_START_Z), Vector3(return_width, 3.7, BOUNDARY_THICKNESS))
	_add_static_box(collision, "FarReturnCollision", Vector3(return_x, 1.85, BOUNDARY_END_Z), Vector3(return_width, 3.7, BOUNDARY_THICKNESS))


func _add_wall_cap_tiles(parent: Node3D, z_start: float, z_end: float) -> void:
	var count = 34
	var span = z_start - z_end
	var step = span / float(count)
	for i in range(count):
		var z = z_start - step * (float(i) + 0.5)
		var tile = _add_box(parent, "WallCapTile_%02d" % i, Vector3(BOUNDARY_X + 0.01, BOUNDARY_HEIGHT + CAP_HEIGHT * 0.5, z), Vector3(BOUNDARY_THICKNESS + 0.32, CAP_HEIGHT, step * 0.86), mat_tile)
		tile.rotation_degrees.z = 2.0 if i % 2 == 0 else -2.0
		tile.rotation_degrees.y = 1.0 if i % 3 == 0 else -0.7


func _add_damage_patches(parent: Node3D, x: float, z_start: float, z_end: float, count: int) -> void:
	var span = z_start - z_end
	for i in range(count):
		var t = (float(i) + 0.37) / float(count)
		var z = z_start - span * t
		var y = 0.8 + float((i * 37) % 140) / 100.0
		var h = 0.28 + float((i * 19) % 45) / 100.0
		var w = 0.55 + float((i * 13) % 50) / 100.0
		var patch_material = mat_brick if i % 3 != 0 else mat_water_stain
		var patch = _add_box(parent, "BrokenPlasterPatch_%02d" % i, Vector3(x, y, z), Vector3(0.035, h, w), patch_material, false)
		patch.rotation_degrees.x = float((i * 11) % 7) - 3.0


func _add_grass_tufts(parent: Node3D, x: float, z_start: float, z_end: float, count: int) -> void:
	var span = z_start - z_end
	for i in range(count):
		var t = (float(i) + 0.21) / float(count)
		var z = z_start - span * t
		var offset = float((i * 17) % 35) / 100.0
		var blade = _add_box(parent, "WallRootGrass_%02d" % i, Vector3(x + offset, 0.23, z), Vector3(0.025, 0.45 + float(i % 5) * 0.04, 0.055), mat_moss, false)
		blade.rotation_degrees.x = -12.0 + float((i * 9) % 25)
		blade.rotation_degrees.z = -8.0 + float((i * 7) % 16)


func _add_distant_silhouettes(parent: Node3D, z_start: float, z_end: float) -> void:
	var root = Node3D.new()
	root.name = "DistantTreeAndBambooSilhouettes"
	parent.add_child(root)

	var span = z_start - z_end
	for i in range(9):
		var z = z_start - span * ((float(i) + 0.3) / 9.0)
		var trunk_h = 2.2 + float((i * 31) % 90) / 100.0
		var trunk = _add_box(root, "DistantTrunk_%02d" % i, Vector3(BOUNDARY_X - 0.9 - float(i % 3) * 0.18, BOUNDARY_HEIGHT + trunk_h * 0.5 - 0.1, z), Vector3(0.08, trunk_h, 0.08), mat_tree, false)
		trunk.rotation_degrees.z = -8.0 + float((i * 5) % 17)
		_add_box(root, "DistantCanopy_%02d" % i, Vector3(BOUNDARY_X - 1.0, BOUNDARY_HEIGHT + trunk_h + 0.45, z), Vector3(0.12, 0.8, 0.95), mat_tree, false)


func _add_box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3, material: Material, cast_shadow: bool = true) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size

	var box = MeshInstance3D.new()
	box.name = node_name
	box.mesh = mesh
	box.position = position_value
	box.material_override = material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(box)
	return box


func _add_static_box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = position_value

	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape

	body.add_child(shape)
	parent.add_child(body)
	return body
