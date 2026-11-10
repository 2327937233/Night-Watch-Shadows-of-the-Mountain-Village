extends Node3D

const PLASTER_MAT = "res://materials/walls/courtyard_wall_plaster_wet.tres"
const BRICK_MAT = "res://materials/walls/courtyard_wall_brick_old.tres"
const STONE_MAT = "res://materials/walls/courtyard_wall_stone_base.tres"
const CAP_TILE_MAT = "res://materials/roof/wall_cap_tiles_wet.tres"
const INTERIOR_MAT = "res://materials/walls/interior_dark_wet.tres"
const MOSS_MAT = "res://materials/walls/moss_dark_wet.tres"
const RAIN_STAIN_MAT = "res://materials/walls/rain_stain_wet.tres"
const WEATHERED_PLASTER_MAT = "res://materials/architecture/peeling_plaster.tres"

const WING_X = -5.90
const WING_FRONT_Z = 9.80
const WING_BACK_Z = -18.50
const WING_DEPTH = 1.55
const WING_WALL_THICKNESS = 0.34
const WING_WALL_HEIGHT = 2.70

const BOUNDARY_X = -8.25
const BOUNDARY_Z_START = 11.50
const BOUNDARY_Z_END = -21.50
const BOUNDARY_THICKNESS = 0.42
const BOUNDARY_HEIGHT = 3.35

var _visual_root: Node3D
var _collision_root: Node3D
var _materials: Dictionary = {}


func _ready() -> void:
	call_deferred("_rebuild")


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()

	set_meta(
		"transparent_gap_cause",
		"Left wing was built as a courtyard-facing facade with missing rear and side closure plus no exterior boundary wall, so the camera could see the map exterior."
	)

	_prepare_materials()

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_collision_root = Node3D.new()
	_collision_root.name = "CollisionRoot"
	add_child(_collision_root)

	_build_left_wing_closed_volume()
	_build_left_boundary_wall()
	_build_wall_backdrop()


func _prepare_materials() -> void:
	_materials["plaster"] = _load_weathered_plaster()
	var return_plaster = _load_weathered_plaster().duplicate(true) as ShaderMaterial
	return_plaster.set_shader_parameter("uv_repeat", Vector2(0.86, 1.24))
	return_plaster.set_shader_parameter("weathering_repeat", Vector2(0.72, 0.94))
	return_plaster.set_shader_parameter("material_tint", Color(0.40, 0.43, 0.42, 1.0))
	return_plaster.set_shader_parameter("albedo_gain", 0.84)
	return_plaster.set_shader_parameter("weathering_strength", 0.94)
	return_plaster.set_shader_parameter("wall_root_dampness", 0.96)
	return_plaster.set_shader_parameter("rain_streak_strength", 0.76)
	return_plaster.set_shader_parameter("crack_strength", 0.55)
	_materials["return_plaster"] = return_plaster
	var boundary_inner_plaster = _load_weathered_plaster().duplicate(true) as ShaderMaterial
	# This surface runs for roughly 33 metres. Matching the right wing's UV
	# density prevents one texture sample being stretched into a flat brown wall.
	boundary_inner_plaster.set_shader_parameter("uv_repeat", Vector2(8.6, 1.28))
	boundary_inner_plaster.set_shader_parameter("weathering_repeat", Vector2(0.74, 0.96))
	boundary_inner_plaster.set_shader_parameter("material_tint", Color(0.43, 0.46, 0.45, 1.0))
	boundary_inner_plaster.set_shader_parameter("albedo_gain", 0.86)
	boundary_inner_plaster.set_shader_parameter("weathering_strength", 0.88)
	boundary_inner_plaster.set_shader_parameter("wall_root_dampness", 0.94)
	boundary_inner_plaster.set_shader_parameter("rain_streak_strength", 0.72)
	boundary_inner_plaster.set_shader_parameter("crack_strength", 0.52)
	_materials["boundary_inner_plaster"] = boundary_inner_plaster
	_materials["brick"] = _load_or_make_mat(BRICK_MAT, Color(0.18, 0.18, 0.17, 1.0), 0.74)
	_materials["stone"] = _load_or_make_mat(STONE_MAT, Color(0.16, 0.18, 0.19, 1.0), 0.68)
	_materials["cap_tiles"] = _load_or_make_mat(CAP_TILE_MAT, Color(0.08, 0.09, 0.09, 1.0), 0.38)
	_materials["interior"] = _load_or_make_mat(INTERIOR_MAT, Color(0.025, 0.022, 0.020, 1.0), 0.92)
	_materials["moss"] = _load_or_make_mat(MOSS_MAT, Color(0.07, 0.11, 0.07, 1.0), 0.78)
	_materials["rain_stain"] = _load_or_make_mat(RAIN_STAIN_MAT, Color(0.04, 0.045, 0.045, 1.0), 0.55)
	_materials["old_wood"] = _make_color_mat(Color(0.085, 0.058, 0.037, 1.0), 0.93)
	_materials["wet_wood"] = _make_color_mat(Color(0.035, 0.027, 0.022, 1.0), 0.64)
	_materials["paper_ghost"] = _make_color_mat(Color(0.16, 0.125, 0.075, 1.0), 0.98)
	_materials["soaked_paper"] = _make_color_mat(Color(0.075, 0.052, 0.033, 1.0), 0.99)


func _load_weathered_plaster() -> Material:
	var source = load(WEATHERED_PLASTER_MAT) as ShaderMaterial
	if source == null:
		return _load_or_make_mat(PLASTER_MAT, Color(0.30, 0.29, 0.25, 1.0), 0.82)
	var material = source.duplicate(true) as ShaderMaterial
	material.set_shader_parameter("uv_repeat", Vector2(2.15, 1.35))
	material.set_shader_parameter("weathering_repeat", Vector2(1.22, 0.96))
	material.set_shader_parameter("material_tint", Color(0.47, 0.49, 0.47, 1.0))
	material.set_shader_parameter("albedo_gain", 0.92)
	material.set_shader_parameter("weathering_strength", 0.84)
	material.set_shader_parameter("wall_root_dampness", 0.91)
	material.set_shader_parameter("rain_streak_strength", 0.62)
	material.set_shader_parameter("crack_strength", 0.46)
	return material


func _make_color_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material


func _load_or_make_mat(path: String, color: Color, roughness: float) -> StandardMaterial3D:
	var mat = load(path) as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = 0.0
	return _make_opaque(mat)


func _make_opaque(mat: StandardMaterial3D) -> StandardMaterial3D:
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var albedo = mat.albedo_color
	albedo.a = 1.0
	mat.albedo_color = albedo
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat


func _build_left_wing_closed_volume() -> void:
	var wing = Node3D.new()
	wing.name = "LeftWingClosedVolume"
	_visual_root.add_child(wing)

	var z_mid = (WING_FRONT_Z + WING_BACK_Z) * 0.5
	var z_len = abs(WING_FRONT_Z - WING_BACK_Z)
	var interior_x = WING_X - WING_DEPTH * 0.5
	var rear_x = WING_X - WING_DEPTH

	_add_box(wing, "RearPlasterWall", Vector3(rear_x, 1.38, z_mid), Vector3(WING_WALL_THICKNESS, WING_WALL_HEIGHT, z_len), _materials["boundary_inner_plaster"])
	_add_box(wing, "RearStoneFoundation", Vector3(rear_x + 0.01, 0.22, z_mid), Vector3(WING_WALL_THICKNESS + 0.04, 0.44, z_len), _materials["stone"])
	_add_box(wing, "FrontInnerWeatheredWall", Vector3(interior_x, 1.32, z_mid), Vector3(0.20, 2.45, z_len), _materials["boundary_inner_plaster"])
	_add_box(wing, "NearEndSideWall", Vector3(interior_x, 1.35, WING_FRONT_Z), Vector3(WING_DEPTH, WING_WALL_HEIGHT, WING_WALL_THICKNESS), _materials["return_plaster"])
	_add_box(wing, "FarEndSideWall", Vector3(interior_x, 1.35, WING_BACK_Z), Vector3(WING_DEPTH, WING_WALL_HEIGHT, WING_WALL_THICKNESS), _materials["plaster"])
	_add_box(wing, "RearTopBeam", Vector3(rear_x + 0.02, 2.82, z_mid), Vector3(0.42, 0.28, z_len + 0.28), _materials["brick"])
	_add_box(wing, "CeilingDarkClosure", Vector3(interior_x, 2.86, z_mid), Vector3(WING_DEPTH, 0.18, z_len), _materials["interior"])

	_add_damage_patch(wing, Vector3(rear_x - 0.18, 1.45, z_mid + 4.2), Vector3(0.025, 0.72, 1.15), _materials["brick"])
	_add_damage_patch(wing, Vector3(rear_x - 0.18, 0.82, z_mid - 6.1), Vector3(0.025, 0.58, 0.92), _materials["brick"])
	_add_moss_strip(wing, Vector3(rear_x - 0.20, 0.08, z_mid), Vector3(0.03, 0.12, z_len * 0.92))
	_decorate_wing_near_end(wing, interior_x)

	_add_collision("LeftWingRearWallCollision", Vector3(rear_x, 1.50, z_mid), Vector3(0.58, 3.0, z_len + 0.5))
	_add_collision("LeftWingNearSideCollision", Vector3(interior_x, 1.45, WING_FRONT_Z), Vector3(WING_DEPTH + 0.25, 2.9, 0.58))
	_add_collision("LeftWingFarSideCollision", Vector3(interior_x, 1.45, WING_BACK_Z), Vector3(WING_DEPTH + 0.25, 2.9, 0.58))


func _build_left_boundary_wall() -> void:
	var wall = Node3D.new()
	wall.name = "LeftBoundaryWall"
	_visual_root.add_child(wall)

	var z_mid = (BOUNDARY_Z_START + BOUNDARY_Z_END) * 0.5
	var z_len = abs(BOUNDARY_Z_START - BOUNDARY_Z_END)

	_add_box(wall, "StoneFoundation", Vector3(BOUNDARY_X, 0.22, z_mid), Vector3(BOUNDARY_THICKNESS + 0.12, 0.44, z_len), _materials["stone"])
	_add_box(wall, "BrickCore", Vector3(BOUNDARY_X, 1.20, z_mid), Vector3(BOUNDARY_THICKNESS, 1.50, z_len), _materials["brick"])
	_add_box(wall, "PlasterSurfaceInner", Vector3(BOUNDARY_X + BOUNDARY_THICKNESS * 0.52, 1.85, z_mid), Vector3(0.06, 2.45, z_len), _materials["boundary_inner_plaster"])
	_add_box(wall, "PlasterSurfaceOuter", Vector3(BOUNDARY_X - BOUNDARY_THICKNESS * 0.52, 1.85, z_mid), Vector3(0.06, 2.45, z_len), _materials["plaster"])
	_add_box(wall, "WallCapBase", Vector3(BOUNDARY_X, BOUNDARY_HEIGHT + 0.03, z_mid), Vector3(BOUNDARY_THICKNESS + 0.25, 0.16, z_len + 0.25), _materials["cap_tiles"])
	_add_wall_cap_tiles(wall, BOUNDARY_X, BOUNDARY_HEIGHT + 0.18, z_mid, z_len)
	var near_return_x = (BOUNDARY_X + WING_X) * 0.5
	var near_return_width = abs(BOUNDARY_X - WING_X) + 0.45
	_add_box(wall, "NearReturnWall", Vector3(near_return_x, 1.55, BOUNDARY_Z_START), Vector3(near_return_width, 3.10, BOUNDARY_THICKNESS), _materials["return_plaster"])
	_add_box(wall, "FarReturnWall", Vector3((BOUNDARY_X + WING_X) * 0.5, 1.55, BOUNDARY_Z_END), Vector3(abs(BOUNDARY_X - WING_X) + 0.45, 3.10, BOUNDARY_THICKNESS), _materials["plaster"])
	_decorate_near_return_wall(wall, near_return_x, near_return_width)
	_add_left_rear_cold_fill(wall)

	for i in range(9):
		var z = BOUNDARY_Z_START - 2.0 - float(i) * 3.0
		_add_damage_patch(wall, Vector3(BOUNDARY_X + 0.24, 1.05 + 0.18 * float(i % 3), z), Vector3(0.035, 0.45 + 0.08 * float(i % 2), 0.8), _materials["brick"])
		_add_rain_stain(wall, Vector3(BOUNDARY_X + 0.255, 2.20, z + 0.55), Vector3(0.025, 1.25, 0.22))

	_add_moss_strip(wall, Vector3(BOUNDARY_X + 0.27, 0.11, z_mid), Vector3(0.035, 0.18, z_len * 0.95))
	_add_grass_tufts(wall, BOUNDARY_X + 0.40, z_mid, z_len)

	_add_collision("LeftBoundaryWallCollision", Vector3(BOUNDARY_X, 1.80, z_mid), Vector3(BOUNDARY_THICKNESS + 0.20, 3.60, z_len + 0.60))
	_add_collision("LeftBoundaryNearReturnCollision", Vector3((BOUNDARY_X + WING_X) * 0.5, 1.70, BOUNDARY_Z_START), Vector3(abs(BOUNDARY_X - WING_X) + 0.60, 3.40, BOUNDARY_THICKNESS + 0.20))
	_add_collision("LeftBoundaryFarReturnCollision", Vector3((BOUNDARY_X + WING_X) * 0.5, 1.70, BOUNDARY_Z_END), Vector3(abs(BOUNDARY_X - WING_X) + 0.60, 3.40, BOUNDARY_THICKNESS + 0.20))


func _decorate_wing_near_end(parent: Node3D, center_x: float) -> void:
	# The wing end faces the gameplay camera. Layering real geometry over this
	# plane prevents it from reading as a flat black plug when the lantern falls off.
	var face_z = WING_FRONT_Z + WING_WALL_THICKNESS * 0.52 + 0.012
	_add_box(parent, "WingEndWetStoneSkirt", Vector3(center_x, 0.24, face_z), Vector3(WING_DEPTH * 0.92, 0.46, 0.035), _materials["stone"])
	_add_box(parent, "WingEndBrokenPlasterLow", Vector3(center_x - 0.34, 0.68, face_z + 0.012), Vector3(0.48, 0.38, 0.025), _materials["brick"])
	_add_box(parent, "WingEndBlackDampPocket", Vector3(center_x + 0.38, 0.58, face_z + 0.018), Vector3(0.34, 0.66, 0.022), _materials["rain_stain"])
	_add_box(parent, "WingEndRainTraceA", Vector3(center_x - 0.48, 1.65, face_z + 0.018), Vector3(0.08, 1.34, 0.02), _materials["rain_stain"])
	_add_box(parent, "WingEndRainTraceB", Vector3(center_x + 0.18, 2.02, face_z + 0.018), Vector3(0.055, 0.92, 0.02), _materials["rain_stain"])
	var paper = _add_box(parent, "WingEndRottenPaperRemnant", Vector3(center_x + 0.28, 1.52, face_z + 0.025), Vector3(0.22, 0.38, 0.018), _materials["soaked_paper"])
	paper.rotation_degrees.z = -7.0
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _decorate_near_return_wall(parent: Node3D, center_x: float, width: float) -> void:
	# A blind, waterlogged service recess gives the left-rear corner depth and an
	# implied history without adding a literal horror symbol or jump-scare prop.
	var face_z = BOUNDARY_Z_START + BOUNDARY_THICKNESS * 0.52 + 0.014
	var recess_x = center_x + 0.18
	_add_box(parent, "NearReturnWetStoneBase", Vector3(center_x, 0.23, face_z), Vector3(width * 0.94, 0.46, 0.045), _materials["stone"])
	_add_box(parent, "BlindServiceRecess", Vector3(recess_x, 1.24, face_z + 0.014), Vector3(0.92, 1.66, 0.04), _materials["interior"])
	_add_box(parent, "RecessTopBeam", Vector3(recess_x, 2.11, face_z + 0.042), Vector3(1.10, 0.12, 0.10), _materials["wet_wood"])
	_add_box(parent, "RecessLeftPost", Vector3(recess_x - 0.52, 1.26, face_z + 0.042), Vector3(0.12, 1.82, 0.10), _materials["old_wood"])
	_add_box(parent, "RecessRightPost", Vector3(recess_x + 0.52, 1.26, face_z + 0.042), Vector3(0.12, 1.82, 0.10), _materials["old_wood"])
	var brace = _add_box(parent, "WarpedCrossBrace", Vector3(recess_x, 1.22, face_z + 0.074), Vector3(1.06, 0.10, 0.09), _materials["wet_wood"])
	brace.rotation_degrees.z = -18.0

	_add_box(parent, "ReturnWallPlasterLossA", Vector3(center_x - width * 0.35, 0.78, face_z + 0.03), Vector3(0.46, 0.54, 0.028), _materials["brick"])
	_add_box(parent, "ReturnWallPlasterLossB", Vector3(center_x + width * 0.38, 2.34, face_z + 0.03), Vector3(0.32, 0.42, 0.028), _materials["brick"])
	_add_box(parent, "ReturnWallDampBloom", Vector3(center_x - width * 0.30, 1.44, face_z + 0.034), Vector3(0.56, 0.92, 0.024), _materials["rain_stain"])
	for data in [
		[-0.72, 2.10, 0.07, 1.08],
		[0.73, 1.92, 0.055, 0.86],
		[-0.91, 1.58, 0.045, 0.62]
	]:
		_add_box(parent, "ReturnWallIrregularRainTrace", Vector3(center_x + float(data[0]), float(data[1]), face_z + 0.042), Vector3(float(data[2]), float(data[3]), 0.018), _materials["rain_stain"])

	var adhesive_ghost = _add_box(parent, "FadedPaperAdhesiveGhost", Vector3(center_x - 0.74, 1.84, face_z + 0.052), Vector3(0.27, 0.43, 0.014), _materials["paper_ghost"])
	adhesive_ghost.rotation_degrees.z = 4.0
	var soaked_fragment = _add_box(parent, "SoakedPaperCorner", Vector3(center_x - 0.70, 1.76, face_z + 0.064), Vector3(0.15, 0.19, 0.012), _materials["soaked_paper"])
	soaked_fragment.rotation_degrees.z = -11.0
	_add_moss_strip(parent, Vector3(center_x - width * 0.18, 0.09, face_z + 0.038), Vector3(width * 0.42, 0.16, 0.025))

	# A few fallen boards break the perfectly horizontal floor/wall junction.
	for data in [[-0.86, -14.0, 0.86], [0.82, 10.0, 0.66]]:
		var board = _add_box(parent, "DiscardedRottenBoard", Vector3(center_x + float(data[0]), 0.13, face_z + 0.25), Vector3(float(data[2]), 0.10, 0.10), _materials["wet_wood"])
		board.rotation_degrees.z = float(data[1])


func _add_left_rear_cold_fill(parent: Node3D) -> void:
	# Very weak rain bounce: enough to reveal surface history, never a visible
	# modern light source and never bright enough to flatten the lantern contrast.
	var light = SpotLight3D.new()
	light.name = "ColdRainBounceBehindLeftWing"
	light.position = Vector3(-4.45, 2.35, 13.10)
	light.light_color = Color(0.25, 0.34, 0.43)
	light.light_energy = 0.82
	light.spot_range = 8.0
	light.spot_angle = 42.0
	light.spot_attenuation = 1.75
	light.shadow_enabled = false
	parent.add_child(light)
	light.look_at(Vector3(-7.05, 1.25, 10.35), Vector3.UP)


func _build_wall_backdrop() -> void:
	var root = Node3D.new()
	root.name = "DistantTreeAndMistSilhouette"
	_visual_root.add_child(root)

	_add_box(root, "VeryDarkTreeMassBehindWall", Vector3(BOUNDARY_X - 1.10, 2.65, -4.0), Vector3(0.20, 3.40, 33.0), _materials["interior"])
	_add_box(root, "SoftFogBandBehindWall", Vector3(BOUNDARY_X - 0.98, 2.05, -4.0), Vector3(0.04, 1.20, 29.0), _materials["rain_stain"])


func _add_box(parent: Node3D, name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size

	var instance = MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_collision(name: String, position: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = name
	body.position = position

	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box

	body.add_child(shape)
	_collision_root.add_child(body)


func _add_wall_cap_tiles(parent: Node3D, x: float, y: float, z_mid: float, z_len: float) -> void:
	var count = int(z_len / 0.42)
	var start_z = z_mid - z_len * 0.5 + 0.22
	for i in range(count):
		var tile = _add_box(parent, "CapTile_%02d" % i, Vector3(x, y + 0.015 * float(i % 2), start_z + float(i) * 0.42), Vector3(0.68, 0.10, 0.34), _materials["cap_tiles"])
		tile.rotation_degrees.x = -4.0 if i % 2 == 0 else 3.0


func _add_damage_patch(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
	var patch = _add_box(parent, "BrokenPlasterExposeBrick", position, size, material)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_rain_stain(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var stain = _add_box(parent, "VerticalRainStain", position, size, _materials["rain_stain"])
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_moss_strip(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var moss = _add_box(parent, "WallRootMossAndBlackMud", position, size, _materials["moss"])
	moss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_grass_tufts(parent: Node3D, x: float, z_mid: float, z_len: float) -> void:
	for i in range(14):
		var z = z_mid - z_len * 0.45 + float(i) * (z_len * 0.90 / 13.0)
		var grass = _add_box(parent, "SparseWallGrass_%02d" % i, Vector3(x + 0.05 * float(i % 3), 0.20, z), Vector3(0.04, 0.38 + 0.05 * float(i % 2), 0.04), _materials["moss"])
		grass.rotation_degrees.y = 20.0 * float(i % 4)
