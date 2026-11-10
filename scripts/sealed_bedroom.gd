extends "res://scripts/left_wing_interior.gd"

const MAIN_HALL_PATH := "res://scenes/InteriorPlaceholder.tscn"
const ROOM_X_LIMIT := 3.64
const ROOM_NEAR_Z := 7.25
const ROOM_FAR_Z := -7.50
const DRESSER_POINT := Vector2(3.30, -3.90)
const MIRROR_POINT := Vector2(3.42, -4.18)
const HAIRPIN_POINT := Vector2(3.20, -3.48)
const BED_BOX_POINT := Vector2(-0.82, -3.64)
const WARDROBE_POINT := Vector2(-3.15, -4.85)

var room_busy := false:
	set(value):
		room_busy = value
		if is_inside_tree():
			GameState.set_night_clock_hold(self, value)
var narration_active := false
var mirror_cloth: Node3D
var mirror_root: Node3D
var mirror_afterimage: MeshInstance3D
var mirror_talisman: Node3D
var dressing_drawer: Node3D
var unsent_letter_visual: Node3D
var hairpin_visual: Node3D
var bed_box_root: Node3D
var bed_box_lid: Node3D
var photo_visual: Node3D
var next_wood_creak_at := 0.0
var mirror_event_earliest_at := 0.0
var rustle_audio: AudioStreamPlayer3D
var drawer_audio: AudioStreamPlayer3D
var floor_audio: AudioStreamPlayer3D
var candle_flames: Array[MeshInstance3D] = []
var final_chapter_trigger: Node3D
var final_corridor_light: OmniLight3D
var final_candle_factor := 1.0
var final_sequence_running := false


func _state() -> Node:
	return get_node("/root/GameState")


func _module(parent: Node3D, module_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = module_name
	parent.add_child(node)
	return node


func _add_no_clip_guard(parent: Node3D, guard_name: String, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = guard_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _fabric_material(base: Color, damp: Color, weave: float, damage: float) -> ShaderMaterial:
	var fabric := ShaderMaterial.new()
	fabric.shader = load("res://shaders/aged_bedroom_fabric.gdshader") as Shader
	fabric.set_shader_parameter("fabric_tint", base)
	fabric.set_shader_parameter("damp_tint", damp)
	fabric.set_shader_parameter("weave_scale", weave)
	fabric.set_shader_parameter("damage_amount", damage)
	return fabric


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "SealedBedroomRainNightEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.011, 0.017)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.23, 0.26, 0.30)
	env.ambient_light_energy = 1.43
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.052, 0.063, 0.076)
	env.fog_light_energy = 0.18
	env.fog_density = 0.008
	world.environment = env
	add_child(world)


func _build_room() -> void:
	var room := _module(self, "SealedBedroom")
	var architecture := _module(room, "Architecture")
	var furniture := _module(room, "Furniture")
	var mirror_area := _module(room, "MirrorArea")
	var story_items := _module(room, "StoryItems")
	var lighting := _module(room, "Lighting")
	var atmosphere := _module(room, "Atmosphere")
	var props := _module(room, "Props")
	var plaster := (load("res://materials/architecture/interior_ritual_plaster.tres") as Material).duplicate(true)
	var wood := (load("res://materials/architecture/wet_old_wood.tres") as Material).duplicate(true)
	var floor_mat := (load("res://materials/ground/interior_wet_brick.tres") as Material).duplicate(true)
	if plaster is ShaderMaterial:
		plaster.set_shader_parameter("world_tile_scale", Vector2(0.25, 0.32))
		plaster.set_shader_parameter("plaster_tint", Color(0.59, 0.56, 0.50))
		plaster.set_shader_parameter("damp_tint", Color(0.13, 0.145, 0.14))
		plaster.set_shader_parameter("minimum_base_brightness", 0.54)
		plaster.set_shader_parameter("weathering_strength", 0.40)
		plaster.set_shader_parameter("root_dampness", 0.76)
		plaster.set_shader_parameter("streak_strength", 0.55)
	if wood is ShaderMaterial:
		wood.set_shader_parameter("uv_repeat", Vector2(1.18, 2.20))
		wood.set_shader_parameter("material_tint", Color(0.48, 0.35, 0.26))
		wood.set_shader_parameter("wetness_amount", 0.38)
	var aged_wood := wood.duplicate(true)
	if aged_wood is ShaderMaterial:
		aged_wood.set_shader_parameter("material_tint", Color(0.40, 0.29, 0.22))
		aged_wood.set_shader_parameter("albedo_gain", 1.03)
	if floor_mat is ShaderMaterial:
		floor_mat.set_shader_parameter("brick_tint", Color(0.52, 0.52, 0.51))
		floor_mat.set_shader_parameter("damp_tint", Color(0.17, 0.19, 0.20))
		floor_mat.set_shader_parameter("albedo_gain", 1.02)
		floor_mat.set_shader_parameter("wetness_amount", 0.34)
		floor_mat.set_shader_parameter("side_dampness", 0.43)
	var mats := {
		"plaster": plaster,
		"wood": wood,
		"aged_wood": aged_wood,
		"floor": floor_mat,
		"dark_wood": _material(Color(0.068, 0.045, 0.032), 0.83),
		"deep_wood": _material(Color(0.035, 0.025, 0.022), 0.94),
		"cloth_red": _fabric_material(Color(0.31, 0.15, 0.14), Color(0.13, 0.09, 0.09), 12.0, 0.49),
		"cloth_fold": _fabric_material(Color(0.23, 0.11, 0.11), Color(0.09, 0.07, 0.07), 13.0, 0.52),
		"linen": _fabric_material(Color(0.34, 0.32, 0.29), Color(0.15, 0.17, 0.17), 18.0, 0.35),
		"bed_linen": _fabric_material(Color(0.27, 0.27, 0.25), Color(0.12, 0.14, 0.14), 18.0, 0.47),
		"mirror_cloth": _fabric_material(Color(0.49, 0.44, 0.37), Color(0.24, 0.25, 0.23), 22.0, 0.46),
		"linen_stain": _material(Color(0.21, 0.21, 0.19), 0.99),
		"paper": _material(Color(0.47, 0.40, 0.28), 0.98),
		"paper_ash": _material(Color(0.44, 0.42, 0.37), 0.99),
		"paper_window": _material(Color(0.45, 0.43, 0.36), 0.99),
		"bronze": _material(Color(0.17, 0.14, 0.095), 0.76),
		"silver": _material(Color(0.28, 0.29, 0.27), 0.72),
		"ceramic": _material(Color(0.078, 0.083, 0.078), 0.80),
		"window_night": _material(Color(0.025, 0.045, 0.067), 0.95),
		"rain_line": _material(Color(0.16, 0.22, 0.28), 0.92),
		"dust": _material(Color(0.13, 0.125, 0.11), 0.98),
	}
	(mats.mirror_cloth as ShaderMaterial).set_shader_parameter("faint_self_light", 0.16)
	(mats.cloth_red as ShaderMaterial).set_shader_parameter("faint_self_light", 0.035)
	mats["hemmed_cloth"] = (mats.cloth_red as ShaderMaterial).duplicate()
	mats.hemmed_cloth.set_shader_parameter("hem_pattern", 0.78)
	mats["quilt_fabric"] = _fabric_material(Color(0.33, 0.245, 0.205), Color(0.13, 0.12, 0.115), 19.0, 0.56)
	mats.quilt_fabric.set_shader_parameter("hem_pattern", 0.45)
	(mats.bronze as StandardMaterial3D).metallic = 0.19
	(mats.silver as StandardMaterial3D).metallic = 0.31
	var oxidized_mirror := ShaderMaterial.new()
	oxidized_mirror.shader = preload("res://shaders/tarnished_bedroom_mirror.gdshader")
	mats["oxidized_mirror"] = oxidized_mirror
	(mats.window_night as StandardMaterial3D).emission_enabled = true
	(mats.window_night as StandardMaterial3D).emission = Color(0.058, 0.095, 0.145)
	(mats.window_night as StandardMaterial3D).emission_energy_multiplier = 0.85
	(mats.paper_window as StandardMaterial3D).emission_enabled = true
	(mats.paper_window as StandardMaterial3D).emission = Color(0.035, 0.043, 0.048)
	(mats.paper_window as StandardMaterial3D).emission_energy_multiplier = 0.42
	(mats.rain_line as StandardMaterial3D).emission_enabled = true
	(mats.rain_line as StandardMaterial3D).emission = Color(0.11, 0.15, 0.20)
	(mats.rain_line as StandardMaterial3D).emission_energy_multiplier = 0.55
	_build_architecture(architecture, mats)
	_build_bed(furniture, props, mats)
	_build_wardrobe(furniture, mats)
	_build_dressing_table(furniture, mirror_area, story_items, mats)
	_build_small_props(props, story_items, mats)
	_build_lighting(lighting, mats)
	_build_atmosphere(atmosphere)
	_build_story_audio()


func _build_architecture(root: Node3D, mats: Dictionary) -> void:
	_add_box(root, "OldBedroomFloorCollision", Vector3(8.30, 0.17, 15.75), Vector3(0.0, -0.10, 0.0), mats.deep_wood, true)
	var tile := BoxMesh.new()
	tile.size = Vector3(0.92, 0.035, 0.91)
	tile.material = mats.floor
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tile
	mm.instance_count = 9 * 17
	for zi in range(17):
		for xi in range(9):
			var index := zi * 9 + xi
			var x := -3.68 + xi * 0.92 + (0.035 if zi % 2 else 0.0)
			var z := 7.16 - zi * 0.91
			var variation := float((xi * 7 + zi * 11) % 5) * 0.0012
			mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, 0.008 + variation, z)))
	var floor_tiles := MultiMeshInstance3D.new()
	floor_tiles.name = "UnevenIndoorStoneBrick_MultiMesh"
	floor_tiles.multimesh = mm
	root.add_child(floor_tiles)
	# The left wall is built around a genuine opening, not a lit rectangle on a solid slab.
	_add_box(root, "LeftWallNearWindow", Vector3(0.32, 3.68, 4.70), Vector3(-4.13, 1.84, 5.35), mats.plaster, true)
	_add_box(root, "LeftWallBeyondWindow", Vector3(0.32, 3.68, 8.45), Vector3(-4.13, 1.84, -3.92), mats.plaster, true)
	_add_box(root, "WindowLowDampWall", Vector3(0.32, 1.15, 2.72), Vector3(-4.13, 0.58, 1.66), mats.plaster, true)
	_add_box(root, "WindowWallLintel", Vector3(0.32, 0.92, 2.72), Vector3(-4.13, 3.21, 1.66), mats.plaster, true)
	_add_box(root, "RightBedroomWall", Vector3(0.32, 3.68, 15.65), Vector3(4.13, 1.84, 0.0), mats.plaster, true)
	_add_box(root, "RearBedroomWall", Vector3(8.34, 3.68, 0.35), Vector3(0.0, 1.84, -7.90), mats.plaster, true)
	_add_box(root, "CeilingOldWoodMass", Vector3(8.30, 0.15, 15.75), Vector3(0.0, 3.69, 0.0), mats.aged_wood)
	for z in [6.85, 3.75, 0.65, -2.45, -5.55, -7.76]:
		_add_box(root, "HeavyCrossBeam", Vector3(8.24, 0.25, 0.32), Vector3(0.0, 3.46, z), mats.aged_wood)
		for x in [-3.91, 3.91]:
			_add_box(root, "OldLoadPost", Vector3(0.28, 3.40, 0.28), Vector3(x, 1.70, z), mats.wood, true)
	for x in [-2.9, -1.65, -0.4, 0.85, 2.10, 3.35]:
		_add_box(root, "RoofPurlin", Vector3(0.12, 0.13, 15.30), Vector3(x, 3.55, 0.0), mats.wood)
	for x in [-2.83, 2.83]:
		_add_box(root, "ThickEntranceInfill", Vector3(2.65, 3.50, 0.30), Vector3(x, 1.75, 7.71), mats.plaster, true)
		_add_box(root, "EntranceOldDoorJamb", Vector3(0.28, 3.25, 0.40), Vector3(signf(x) * 1.46, 1.62, 7.53), mats.wood, true)
	_add_box(root, "EntranceTimberLintel", Vector3(3.02, 0.26, 0.40), Vector3(0.0, 3.23, 7.53), mats.aged_wood)
	# Low, uneven wall framing gives the long room the depth of a lived-in timber house.
	for z in [-6.65, -4.85, -3.05, -1.25, 0.55, 2.35, 4.15, 5.95]:
		_add_box(root, "RightOldDadoBatten", Vector3(0.075, 0.82, 0.11), Vector3(3.91, 0.48, z), mats.aged_wood)
	for z in [-6.65, -4.85, -3.05, -1.25, 3.92, 5.72]:
		_add_box(root, "LeftOldDadoBatten", Vector3(0.075, 0.82, 0.11), Vector3(-3.91, 0.48, z), mats.aged_wood)
	for x in [-3.91, 3.91]:
		_add_box(root, "DampLowerWallFootRail", Vector3(0.065, 0.12, 15.14), Vector3(x, 0.16, 0.0), mats.aged_wood)
		_add_box(root, "WornWallDadoCap", Vector3(0.09, 0.075, 15.14), Vector3(x, 0.91, 0.0), mats.wood)
	for x in [-2.90, 2.90]:
		_add_box(root, "RearTimberWallFootRail", Vector3(2.52, 0.12, 0.07), Vector3(x, 0.16, -7.68), mats.aged_wood)
		_add_box(root, "RearWornTimberWallCap", Vector3(2.52, 0.075, 0.08), Vector3(x, 0.91, -7.68), mats.wood)
	# A roofed lattice window; rain exists outside the room's traversable volume.
	_add_box(root, "RainNightBeyondWindow", Vector3(0.035, 1.60, 2.48), Vector3(-4.43, 1.88, 1.66), mats.window_night)
	_add_box(root, "OutsideSaggingEaveSilhouette", Vector3(0.09, 0.10, 2.55), Vector3(-4.39, 2.79, 1.65), mats.dark_wood)
	for i in range(3):
		var branch_z := 0.63 + float(i) * 0.83
		var bamboo := _add_box(root, "DistantWetBambooShadow", Vector3(0.022, 1.13 + float(i % 2) * 0.27, 0.027), Vector3(-4.37, 1.68, branch_z), mats.deep_wood)
		bamboo.rotation_degrees.x = float(i - 1) * 7.0
		for leaf in range(3):
			var leaf_angle := float(leaf - 1) * 22.0 + float(i) * 9.0
			var thin_leaf := _add_box(root, "SparseBambooLeafShadow", Vector3(0.019, 0.024, 0.28 - float(leaf % 2) * 0.06), Vector3(-4.35, 1.66 + float(leaf) * 0.29, branch_z + (0.16 if leaf % 2 == 0 else -0.14)), mats.deep_wood)
			thin_leaf.rotation_degrees.x = leaf_angle
	for y in [1.11, 1.52, 1.94, 2.36, 2.70]:
		_add_box(root, "WindowHorizontalLattice", Vector3(0.11, 0.060, 2.78), Vector3(-4.00, y, 1.66), mats.wood)
	for z in [0.32, 0.86, 1.40, 1.94, 2.48, 2.98]:
		_add_box(root, "WindowVerticalLattice", Vector3(0.11, 1.70, 0.064), Vector3(-4.00, 1.88, z), mats.wood)
	# Only a few old paper cells remain; the gaps expose the cold wet darkness.
	for data in [[1.29,0.62,0.38,0.44,-2.5], [2.10,1.46,0.35,0.42,3.0], [2.56,2.23,0.31,0.39,-4.0]]:
		var paper_cell := _add_box(root, "TornAgedWindowPaperCell", Vector3(0.012, float(data[2]), float(data[3])), Vector3(-4.17, float(data[1]), float(data[0])), mats.paper_window)
		paper_cell.rotation_degrees.x = float(data[4])
	_add_box(root, "BrokenWindowLatticeSlat", Vector3(0.095, 0.70, 0.055), Vector3(-3.97, 2.16, 0.34), mats.aged_wood).rotation_degrees.x = 9.0
	for i in range(13):
		var z := 0.48 + float((i * 17) % 23) * 0.105
		var y := 1.21 + float((i * 7) % 13) * 0.105
		var drop := _add_box(root, "ExteriorRainTrace", Vector3(0.007, 0.18 + float(i % 3) * 0.06, 0.010), Vector3(-4.37, y, z), mats.rain_line)
		drop.rotation_degrees.x = 13.0
	for data in [[-3.93,0.62,4.45], [3.93,0.54,-1.10], [-3.93,1.18,-6.85]]:
		_add_box(root, "ExposedDampWallBase", Vector3(0.04, 0.64, 0.96), Vector3(float(data[0]), float(data[1]), float(data[2])), mats.dust)
	# A torn, almost-erased wedding paper remnant is worldbuilding, not a new objective.
	_add_box(root, "OldWeddingPaperAdhesiveShadow", Vector3(0.035, 0.68, 0.62), Vector3(3.95, 2.48, -0.65), mats.linen_stain)
	_add_box(root, "SingleFadedRedWeddingPaperCorner", Vector3(0.038, 0.18, 0.17), Vector3(3.91, 2.18, -0.86), mats.cloth_fold)
	_add_box(root, "OldNailShadowByRemovedPortrait", Vector3(0.026, 0.25, 0.018), Vector3(3.95, 2.11, 1.77), mats.dust)
	_add_cylinder(root, "DarkNailByRemovedPortrait", 0.012, 0.055, Vector3(3.90, 2.16, 1.77), mats.bronze).rotation_degrees.z = 90.0


func _bed_drape_point(center_x: float, side: float, column: int, row: int) -> Vector3:
	var u := float(column) / 8.0
	var v := float(row) / 10.0
	var gathered := pow(maxf(0.0, sin(v * PI)), 1.35) * side * 0.24
	var fold := sin(u * TAU * 2.55 + v * 1.3) * (0.039 + v * 0.020)
	var torn_hem := sin(float(column) * 2.27) * 0.055 + cos(float(column) * 4.31) * 0.022
	return Vector3(center_x + (u - 0.5) * (0.56 - sin(v * PI) * 0.24 + v * 0.08) + gathered, 2.76 - v * 1.79 + v * torn_hem, -3.59 + fold)


func _bed_drape_vertex(surface: SurfaceTool, center_x: float, side: float, column: int, row: int) -> void:
	var dusty := 0.79 + float((column * 11 + row * 5) % 7) * 0.024
	surface.set_color(Color(dusty, dusty * 0.93, dusty * 0.90))
	surface.set_uv(Vector2(float(column) / 8.0, float(row) / 10.0))
	surface.add_vertex(_bed_drape_point(center_x, side, column, row))


func _build_bed_side_drape(root: Node3D, center_x: float, side: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(10):
		for column in range(8):
			_bed_drape_vertex(surface, center_x, side, column, row)
			_bed_drape_vertex(surface, center_x, side, column + 1, row)
			_bed_drape_vertex(surface, center_x, side, column, row + 1)
			_bed_drape_vertex(surface, center_x, side, column + 1, row)
			_bed_drape_vertex(surface, center_x, side, column + 1, row + 1)
			_bed_drape_vertex(surface, center_x, side, column, row + 1)
	surface.generate_normals()
	var drape := MeshInstance3D.new()
	drape.name = "FadedGatheredSideBedCurtain"
	drape.mesh = surface.commit()
	drape.material_override = material
	drape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(drape)


func _quilt_point(column: int, row: int, center_x: float) -> Vector3:
	var u := float(column) / 16.0
	var v := float(row) / 12.0
	var rumple := sin(u * TAU * 3.2 + v * 2.3) * 0.032 + sin(v * TAU * 2.2 - u * 2.3) * 0.025
	var disturbed := exp(-pow((u - 0.35) * 4.4, 2.0) - pow((v - 0.48) * 4.5, 2.0)) * 0.12
	var fall := smoothstep(0.81, 1.0, v)
	# Clear the front face of the mattress before letting the cloth hang down.
	var forward := lerpf(-5.65, -3.67, minf(v / 0.81, 1.0)) + fall * 0.14
	var drop := fall * (0.33 + sin(u * TAU + 0.35) * 0.075)
	return Vector3(center_x + (u - 0.5) * (2.36 - fall * 0.24) + v * 0.13, maxf(0.808, 0.854 + rumple + disturbed) - drop, forward + sin(u * 15.0) * 0.025)


func _add_rumpled_quilt(root: Node3D, center_x: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(12):
		for column in range(16):
			for cell in [[column, row], [column + 1, row], [column, row + 1], [column + 1, row], [column + 1, row + 1], [column, row + 1]]:
				var u := float(cell[0]) / 16.0
				var v := float(cell[1]) / 12.0
				var faded := 0.84 + float((int(cell[0]) * 3 + int(cell[1]) * 5) % 7) * 0.018
				surface.set_color(Color(faded, faded * 0.91, faded * 0.89))
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(_quilt_point(int(cell[0]), int(cell[1]), center_x))
	surface.generate_normals()
	var quilt := MeshInstance3D.new()
	quilt.name = "RumpledFadedBedQuilt"
	quilt.mesh = surface.commit()
	quilt.material_override = material
	quilt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(quilt)


func _valance_point(column: int, row: int, center_x: float) -> Vector3:
	var u := float(column) / 24.0
	var v := float(row) / 4.0
	var worn_edge := sin(float(column) * 2.13) * 0.036 + sin(float(column) * 5.81) * 0.016
	return Vector3(center_x + (u - 0.5) * 2.78, 2.77 - v * (0.24 + worn_edge), -3.605 + sin(u * TAU * 4.0) * v * 0.025)


func _add_torn_canopy_valance(root: Node3D, center_x: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(4):
		for column in range(24):
			for cell in [[column, row], [column + 1, row], [column, row + 1], [column + 1, row], [column + 1, row + 1], [column, row + 1]]:
				var fading := 0.77 + float((int(cell[0]) * 11 + int(cell[1]) * 3) % 7) * 0.019
				surface.set_color(Color(fading, fading * 0.91, fading * 0.87))
				surface.set_uv(Vector2(float(cell[0]) / 24.0, float(cell[1]) / 4.0))
				surface.add_vertex(_valance_point(int(cell[0]), int(cell[1]), center_x))
	surface.generate_normals()
	var valance := MeshInstance3D.new()
	valance.name = "TornContinuousCanopyValance"
	valance.mesh = surface.commit()
	valance.material_override = material
	valance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(valance)


func _build_bed(root: Node3D, props: Node3D, mats: Dictionary) -> void:
	var bed := _module(root, "OldCanopyBed")
	var cx := -0.46
	var cz := -5.05
	_add_box(bed, "HeavyRaisedBedPlatform", Vector3(3.05, 0.31, 3.01), Vector3(cx, 0.44, cz), mats.aged_wood, true)
	# A continuous guard behind the hanging fabric prevents the 2.5D character
	# sprite and capsule from visually entering the bed or passing through drapes.
	_add_no_clip_guard(bed, "CanopyBedNoClipVolume", Vector3(3.34, 2.34, 3.22), Vector3(cx, 1.17, cz))
	_add_no_clip_guard(bed, "CanopyFrontDrapeNoClipRail", Vector3(3.46, 2.22, 0.36), Vector3(cx, 1.12, -3.55))
	_add_box(bed, "BedFrontWornApron", Vector3(3.20, 0.34, 0.15), Vector3(cx, 0.45, -3.48), mats.wood)
	_add_box(bed, "OldUnmadeMattress", Vector3(2.83, 0.19, 2.65), Vector3(cx, 0.70, cz), mats.bed_linen)
	for x in [cx - 1.43, cx + 1.43]:
		for z in [-6.43, -3.68]:
			_add_box(bed, "CanopyBedUpright", Vector3(0.18, 2.65, 0.18), Vector3(x, 1.65, z), mats.wood, true)
	for z in [-6.43, -3.68]:
		_add_box(bed, "CanopyCrossCrown", Vector3(3.04, 0.20, 0.20), Vector3(cx, 2.96, z), mats.aged_wood)
	for x in [cx - 1.43, cx + 1.43]:
		_add_box(bed, "CanopyLongCrown", Vector3(0.20, 0.18, 2.88), Vector3(x, 2.96, cz), mats.aged_wood)
	for x in [cx - 1.43, cx + 1.43]:
		_add_sphere(bed, "DulledCanopyCornerFinial", 0.14, Vector3(x, 3.09, -3.68), mats.aged_wood).scale = Vector3(0.65, 1.30, 0.65)
		var brace := _add_box(bed, "OldCanopyCornerBrace", Vector3(0.12, 0.58, 0.12), Vector3(x + (0.18 if x < cx else -0.18), 2.66, -3.68), mats.wood)
		brace.rotation_degrees.z = 34.0 if x < cx else -34.0
	_add_box(bed, "CarvedBedHeadboard", Vector3(2.73, 1.07, 0.12), Vector3(cx, 1.16, -6.39), mats.aged_wood)
	for x in [-1.55, -0.92, -0.28, 0.35, 0.79]:
		_add_box(bed, "WornHeadboardLattice", Vector3(0.065, 0.67, 0.027), Vector3(x, 1.30, -6.31), mats.dark_wood)
	for x in [cx - 1.02, cx - 0.51, cx, cx + 0.51, cx + 1.02]:
		_add_box(bed, "ShallowCarvedHeadboardInsert", Vector3(0.32, 0.14, 0.024), Vector3(x, 1.64, -6.29), mats.wood)
	_add_box(bed, "FrontCanopyCarvedLintel", Vector3(2.79, 0.19, 0.13), Vector3(cx, 2.82, -3.67), mats.aged_wood)
	for x in [cx - 1.11, cx + 1.11]:
		_add_box(bed, "InsetCanopyCornerFret", Vector3(0.38, 0.055, 0.055), Vector3(x, 2.54, -3.64), mats.wood)
		_add_box(bed, "InsetCanopyDropFret", Vector3(0.055, 0.32, 0.055), Vector3(x + (0.14 if x < cx else -0.14), 2.64, -3.64), mats.wood)
	# The old wine-red bed curtain has weight and irregular folds, not a bright wedding canopy.
	_add_box(bed, "FadedCanopyTopCloth", Vector3(2.82, 0.042, 2.75), Vector3(cx, 2.80, cz), mats.cloth_fold)
	for x in [cx - 1.29, cx + 1.29]:
		for i in range(3):
			var hanging := _add_box(bed, "AgedHangingBedDrape", Vector3(0.08, 1.52 - i * 0.10, 0.26), Vector3(x, 1.90 + i * 0.04, -3.91 - i * 0.25), mats.cloth_red if i % 2 == 0 else mats.cloth_fold)
			hanging.rotation_degrees.x = float(i - 1) * 5.0
	_build_bed_side_drape(bed, cx - 1.18, -1.0, mats.hemmed_cloth)
	_build_bed_side_drape(bed, cx + 1.18, 1.0, mats.hemmed_cloth)
	_add_torn_canopy_valance(bed, cx, mats.hemmed_cloth)
	_add_rumpled_quilt(bed, cx - 0.10, mats.quilt_fabric)
	for data in [[-0.61, -5.91, -12.0], [0.58, -6.01, 7.0]]:
		var pillow := _add_sphere(bed, "SlumpedOldLinenPillow", 0.50, Vector3(cx + float(data[0]), 0.845, float(data[1])), mats.linen)
		pillow.scale = Vector3(0.91, 0.22, 0.50)
		pillow.rotation_degrees.y = float(data[2])
	for y in [0.35, 0.57]:
		_add_box(bed, "WornBedApronBeading", Vector3(2.94, 0.032, 0.04), Vector3(cx, y, -3.391), mats.aged_wood)
	_add_box(props, "UnevenBedFootStool", Vector3(0.66, 0.15, 0.52), Vector3(-0.64, 0.44, -2.63), mats.wood, true)
	for x in [-0.90, -0.38]:
		for z in [-2.82, -2.45]:
			_add_box(props, "StoolWornLeg", Vector3(0.10, 0.43, 0.10), Vector3(x, 0.22, z), mats.dark_wood)
	for x in [-1.23, -0.76]:
		_add_box(props, "SmallOldClothShoe", Vector3(0.19, 0.085, 0.38), Vector3(x, 0.09, -3.16), mats.cloth_fold)


func _build_wardrobe(root: Node3D, mats: Dictionary) -> void:
	var wardrobe := _module(root, "LeftOldWardrobe")
	_add_box(wardrobe, "DampWardrobeCarcass", Vector3(0.77, 2.48, 1.38), Vector3(-3.38, 1.24, -4.83), mats.aged_wood, true)
	for z in [-5.15, -4.50]:
		_add_box(wardrobe, "InsetWardrobeDoor", Vector3(0.055, 2.19, 0.55), Vector3(-2.95, 1.23, z), mats.wood)
		_add_box(wardrobe, "RecessedWardrobePanel", Vector3(0.018, 1.57, 0.39), Vector3(-2.915, 1.26, z), mats.dark_wood)
		_add_cylinder(wardrobe, "OxidizedWardrobePull", 0.031, 0.05, Vector3(-2.88, 1.30, z + 0.11), mats.bronze)
	_add_box(wardrobe, "WarpedWardrobeCrown", Vector3(0.93, 0.14, 1.56), Vector3(-3.38, 2.50, -4.83), mats.wood)
	_add_box(wardrobe, "OldGarmentOnWardrobeHook", Vector3(0.065, 0.83, 0.33), Vector3(-2.94, 1.72, -5.66), mats.cloth_red)


func _mirror_cover_point(column: int, row: int) -> Vector3:
	var across := float(column) / 12.0
	var down := float(row) / 8.0
	var scallop := sin(float(column) * 2.3) * 0.032 + sin(float(column) * 4.7) * 0.012
	var width := lerpf(0.49, 0.55, down) + sin(float(row) * 1.35) * 0.012
	var fold := sin(across * TAU * 3.0) * (0.022 + down * 0.018)
	var drape := sin(down * PI) * 0.027
	return Vector3(-0.032 - fold - drape, 0.53 - down * 1.04 + down * scallop, (across * 2.0 - 1.0) * width)


func _mirror_cover_vertex(surface: SurfaceTool, column: int, row: int) -> void:
	var fading := 0.85 + float((column * 7 + row * 3) % 6) * 0.022
	surface.set_color(Color(fading, fading * 0.98, fading * 0.94))
	surface.set_uv(Vector2(float(column) / 12.0, float(row) / 8.0))
	surface.add_vertex(_mirror_cover_point(column, row))


func _build_mirror_cover(parent: Node3D, cloth_material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(8):
		for column in range(12):
			_mirror_cover_vertex(surface, column, row)
			_mirror_cover_vertex(surface, column, row + 1)
			_mirror_cover_vertex(surface, column + 1, row)
			_mirror_cover_vertex(surface, column + 1, row)
			_mirror_cover_vertex(surface, column, row + 1)
			_mirror_cover_vertex(surface, column + 1, row + 1)
	surface.generate_normals()
	var drape := MeshInstance3D.new()
	drape.name = "IrregularDampWovenMirrorDrape"
	drape.mesh = surface.commit()
	drape.material_override = cloth_material
	drape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(drape)


func _build_dressing_table(root: Node3D, mirror_area: Node3D, story_items: Node3D, mats: Dictionary) -> void:
	var dresser := _module(root, "OldDressingTable")
	# One solid furniture volume closes the gaps between legs, drawer and mirror
	# stand so the player cannot clip behind the table as shown in the report.
	_add_no_clip_guard(dresser, "DressingTableMirrorNoClipVolume", Vector3(1.18, 2.52, 2.18), Vector3(3.42, 1.26, -4.02))
	_add_box(dresser, "DresserWornTop", Vector3(0.81, 0.14, 1.86), Vector3(3.40, 0.86, -4.02), mats.wood, true)
	_add_box(dresser, "DresserSolidRear", Vector3(0.16, 0.75, 1.72), Vector3(3.78, 0.43, -4.02), mats.aged_wood)
	for z in [-4.79, -3.25]:
		_add_box(dresser, "DresserLeg", Vector3(0.16, 0.83, 0.16), Vector3(3.16, 0.42, z), mats.wood, true)
	_add_box(dresser, "DresserFrontDrawerRail", Vector3(0.07, 0.34, 1.45), Vector3(3.04, 0.61, -4.02), mats.aged_wood)
	dressing_drawer = _module(dresser, "SearchableDressingDrawer")
	dressing_drawer.position = Vector3(2.82 if _state().bedroom_drawer_open else 3.13, 0.63, -4.02)
	_add_box(dressing_drawer, "DrawerWoodenVolume", Vector3(0.56, 0.22, 0.75), Vector3.ZERO, mats.wood)
	_add_box(dressing_drawer, "InsetDrawerFront", Vector3(0.035, 0.16, 0.57), Vector3(-0.30, 0.0, 0.0), mats.dark_wood)
	_add_cylinder(dressing_drawer, "DarkCopperDrawerPull", 0.038, 0.048, Vector3(-0.34, 0.0, 0.0), mats.bronze)
	unsent_letter_visual = _module(story_items, "UnsentLetterInDrawer")
	unsent_letter_visual.position = Vector3(2.78, 0.77, -4.02)
	_add_box(unsent_letter_visual, "FoldedWaterStainedLetter", Vector3(0.31, 0.017, 0.43), Vector3.ZERO, mats.paper)
	_add_box(unsent_letter_visual, "DriedDarkWaxDot", Vector3(0.055, 0.009, 0.052), Vector3(-0.07, 0.013, 0.0), mats.cloth_fold)
	unsent_letter_visual.visible = _state().bedroom_drawer_open and not _state().has_item("bedroom_unsent_letter")
	# Each small grooming object occupies the table where it would have been used.
	_add_box(dresser, "OxidizedCombBack", Vector3(0.07, 0.022, 0.27), Vector3(3.07, 0.96, -3.47), mats.bronze)
	for i in range(8):
		_add_box(dresser, "MissingTeethOldComb", Vector3(0.045, 0.016, 0.008), Vector3(3.025, 0.96, -3.57 + i * 0.027), mats.dark_wood)
	_add_box(dresser, "ClosedSmallJewelryBox", Vector3(0.30, 0.16, 0.36), Vector3(3.36, 1.00, -4.62), mats.aged_wood)
	_add_box(dresser, "JewelryBoxOxidizedCorner", Vector3(0.035, 0.17, 0.035), Vector3(3.22, 1.0, -4.79), mats.bronze)
	_add_cylinder(dresser, "SmallDriedFlowerVase", 0.11, 0.25, Vector3(3.45, 1.05, -3.28), mats.ceramic)
	for i in range(3):
		var stem := _add_cylinder(dresser, "DryFlowerStem", 0.005, 0.39 + i * 0.10, Vector3(3.43 + i * 0.025, 1.36 + i * 0.04, -3.28), mats.dark_wood)
		stem.rotation_degrees.z = float(i - 1) * 13.0
	hairpin_visual = _module(story_items, "BrokenSilverHairpinInteraction")
	hairpin_visual.position = Vector3(3.18, 0.99, -3.76)
	# Only the flower-head half remains here.  Its asymmetric break is the
	# inverse of the shaft fragment hidden in the ancestor altar side niche.
	var flower_half := _add_cylinder(hairpin_visual, "FlowerHeadSilverHairpinHalf", 0.013, 0.22, Vector3(0.04, 0.0, 0.14), mats.silver)
	flower_half.rotation_degrees.x = 90.0
	_add_sphere(hairpin_visual, "BlackenedHairpinFlowerHead", 0.045, Vector3(0.04, 0.018, 0.27), mats.silver)
	var complementary_lip := _add_cylinder(hairpin_visual, "ComplementaryRecessedFractureLip", 0.0075, 0.038, Vector3(0.033, 0.0, 0.018), mats.silver)
	complementary_lip.rotation_degrees.x = 90.0
	var fracture_shadow := _add_box(hairpin_visual, "DarkHalfMoonFractureShadow", Vector3(0.010, 0.008, 0.020), Vector3(0.048, 0.009, 0.022), mats.dust)
	fracture_shadow.rotation_degrees.z = -19.0
	for offset in [0.095, 0.205]:
		var bedroom_oxide := _add_sphere(hairpin_visual, "OldSilverOxidationPatch", 0.010, Vector3(0.046, 0.009, offset), mats.dust)
		bedroom_oxide.scale = Vector3(0.58, 0.30, 1.45)
	hairpin_visual.visible = not _state().bedroom_hairpin_examined \
		and not _state().has_item("broken_silver_hairpin") \
		and not _state().has_item("complete_silver_hairpin")
	# The mirror is an aged oval object angled towards the entrance, not a clear camera feed.
	mirror_root = _module(mirror_area, "CoveredOxidizedCopperMirror")
	mirror_root.position = Vector3(3.66, 0.0, -4.13)
	mirror_root.rotation_degrees.y = 210.0 if _state().bedroom_hidden_note_found else 30.0
	var rim := _add_sphere(mirror_root, "PittedCopperOvalFrame", 0.66, Vector3(0.0, 1.99, 0.0), mats.bronze)
	rim.scale = Vector3(0.19, 1.10, 0.83)
	var metal := _add_sphere(mirror_root, "BlackenedMirrorSurface", 0.58, Vector3(-0.12, 1.99, 0.0), mats.oxidized_mirror)
	metal.scale = Vector3(0.08, 1.11, 0.80)
	for z in [-0.39, 0.40]:
		_add_box(mirror_root, "OldMirrorStandUpright", Vector3(0.075, 1.23, 0.07), Vector3(0.06, 1.45, z), mats.wood)
	_add_box(mirror_root, "MirrorBaseFoot", Vector3(0.43, 0.09, 0.92), Vector3(0.06, 0.98, 0.0), mats.wood)
	var silhouette_material := StandardMaterial3D.new()
	silhouette_material.albedo_texture = load("res://assets/art/bedroom_mirror_afterimage.svg") as Texture2D
	silhouette_material.albedo_color = Color(0.39, 0.44, 0.45, 0.28)
	silhouette_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silhouette_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var silhouette_quad := QuadMesh.new()
	silhouette_quad.size = Vector2(0.53, 0.98)
	silhouette_quad.material = silhouette_material
	mirror_afterimage = MeshInstance3D.new()
	mirror_afterimage.name = "OnlyInMirrorDistantWomanAfterimage"
	mirror_afterimage.mesh = silhouette_quad
	mirror_afterimage.position = Vector3(-0.205, 1.96, 0.03)
	mirror_afterimage.rotation_degrees.y = -90.0
	mirror_afterimage.transparency = 1.0
	mirror_afterimage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mirror_root.add_child(mirror_afterimage)
	mirror_cloth = _module(mirror_root, "MoistOldCottonMirrorCover")
	mirror_cloth.position = Vector3(-0.23, 2.03 if not _state().bedroom_mirror_uncovered or _state().bedroom_mirror_recovered else 0.96, 0.0)
	_build_mirror_cover(mirror_cloth, mats.mirror_cloth)
	mirror_talisman = _module(mirror_root, "OneHiddenMirrorBackingTalisman")
	mirror_talisman.position = Vector3(0.17, 1.85, 0.0)
	_add_box(mirror_talisman, "SingleFadedYellowTalisman", Vector3(0.018, 0.48, 0.16), Vector3.ZERO, mats.paper)
	_add_box(mirror_talisman, "BlackenedCinnabarStroke", Vector3(0.021, 0.22, 0.018), Vector3(-0.015, 0.03, 0.0), mats.cloth_fold)
	mirror_talisman.visible = _state().bedroom_hidden_note_found


func _build_small_props(root: Node3D, story_items: Node3D, mats: Dictionary) -> void:
	_add_box(root, "LeftWallOldClothesChest", Vector3(0.88, 0.58, 1.34), Vector3(-3.38, 0.29, 1.35), mats.aged_wood, true)
	_add_box(root, "ChestHeavyLid", Vector3(0.91, 0.09, 1.39), Vector3(-3.38, 0.63, 1.35), mats.wood)
	_add_box(root, "ChestWornFrontRail", Vector3(0.035, 0.07, 1.18), Vector3(-2.92, 0.48, 1.35), mats.wood)
	_add_box(root, "ChestOldCopperHasp", Vector3(0.025, 0.15, 0.065), Vector3(-2.90, 0.42, 1.35), mats.bronze)
	_add_box(root, "FoldedOldGarmentOnChest", Vector3(0.68, 0.065, 0.70), Vector3(-3.38, 0.70, 1.43), mats.cloth_red)
	_add_box(root, "ForgottenFabricTailOverChest", Vector3(0.08, 0.36, 0.34), Vector3(-2.92, 0.50, 1.66), mats.cloth_fold).rotation_degrees.x = -8.0
	_add_cylinder(root, "OxidizedWashBasin", 0.32, 0.14, Vector3(-3.14, 0.26, -1.35), mats.bronze)
	_add_cylinder(root, "DarkTarnishedBasinLip", 0.33, 0.026, Vector3(-3.14, 0.34, -1.35), mats.bronze)
	_add_box(root, "WashBasinLowStand", Vector3(0.50, 0.20, 0.50), Vector3(-3.14, 0.10, -1.35), mats.wood)
	_add_box(root, "AgedBedsideCandleStand", Vector3(0.42, 0.61, 0.46), Vector3(1.44, 0.31, -5.98), mats.aged_wood)
	var dresser_stool := _module(root, "SlightlyMisalignedDressingStool")
	dresser_stool.position = Vector3(3.30, 0.0, -2.78)
	dresser_stool.rotation_degrees.y = -11.0
	_add_box(dresser_stool, "StoolDentedSeat", Vector3(0.50, 0.10, 0.46), Vector3(0.0, 0.47, 0.0), mats.wood)
	for x in [-0.18, 0.18]:
		for z in [-0.16, 0.16]:
			_add_box(dresser_stool, "StoolUnsteadyFoot", Vector3(0.075, 0.42, 0.075), Vector3(x, 0.21, z), mats.aged_wood)
	_add_box(root, "DiscardedOldHandkerchiefAtDresser", Vector3(0.23, 0.008, 0.24), Vector3(3.22, 0.96, -4.23), mats.mirror_cloth).rotation_degrees.y = 18.0
	bed_box_root = _module(root, "OptionalBoxUnderCanopyBed")
	bed_box_root.position = Vector3(-0.82, 0.13, -3.48 if _state().bedroom_bed_box_open else -3.79)
	_add_box(bed_box_root, "DustyLowWoodBox", Vector3(0.70, 0.25, 0.47), Vector3.ZERO, mats.dark_wood)
	bed_box_lid = _module(bed_box_root, "SmallBoxHingedLid")
	bed_box_lid.position = Vector3(0.0, 0.16, -0.17)
	_add_box(bed_box_lid, "ThinCopperCorneredLid", Vector3(0.74, 0.055, 0.50), Vector3(0.0, 0.0, 0.17), mats.wood)
	bed_box_lid.rotation_degrees.x = -83.0 if _state().bedroom_bed_box_open else 0.0
	photo_visual = _module(story_items, "ScratchedFamilyPhotoAndEmbroidery")
	photo_visual.position = Vector3(-0.82, 0.29, -3.49)
	var photo_mat := StandardMaterial3D.new()
	photo_mat.albedo_texture = load("res://assets/art/bedroom_scratched_photo.png") as Texture2D
	photo_mat.roughness = 0.97
	photo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var photo_quad := QuadMesh.new()
	photo_quad.size = Vector2(0.40, 0.30)
	photo_quad.material = photo_mat
	var photo := MeshInstance3D.new()
	photo.name = "ActuallyScrapedOldFamilyPhotograph"
	photo.mesh = photo_quad
	photo.position = Vector3(0.0, 0.0, 0.0)
	photo.rotation_degrees.x = -90.0
	photo_visual.add_child(photo)
	_add_box(photo_visual, "SmallFadedEmbroideryScrap", Vector3(0.22, 0.011, 0.20), Vector3(0.22, -0.01, 0.13), mats.cloth_red)
	photo_visual.visible = _state().bedroom_bed_box_open and not _state().bedroom_photo_found
	# Small remnants cluster at furniture and walls; the route from the door stays empty.
	for data in [[-2.72,5.22,-8.0,0.30,0], [2.56,4.52,13.0,0.21,1], [-2.63,2.91,4.0,0.25,1], [3.05,0.38,-17.0,0.28,0], [-3.06,-0.58,7.0,0.22,1], [2.78,-1.52,23.0,0.31,1], [-2.34,-2.31,-11.0,0.23,0], [2.25,-2.65,9.0,0.19,1], [-2.48,-5.55,-20.0,0.27,0], [2.42,-5.95,16.0,0.24,1]]:
		var size := float(data[3])
		var paper_material: Material = mats.paper_ash if int(data[4]) == 1 else mats.paper
		var loose := _add_box(root, "ScatteredDampBedroomPaper", Vector3(size, 0.006, size * 0.70), Vector3(float(data[0]), 0.034, float(data[1])), paper_material)
		loose.rotation_degrees.y = float(data[2])


func _add_private_room_candle(root: Node3D, mats: Dictionary, base: Vector3, prefix: String, energy: float, casts_shadow: bool) -> void:
	_add_cylinder(root, prefix + "OxidizedCandleFoot", 0.09, 0.12, base + Vector3(0.0, 0.07, 0.0), mats.bronze)
	_add_cylinder(root, prefix + "OldCandleWax", 0.054, 0.24, base + Vector3(0.0, 0.24, 0.0), mats.linen)
	_add_cylinder(root, prefix + "CharredWick", 0.004, 0.031, base + Vector3(0.0, 0.38, 0.0), mats.deep_wood)
	for i in range(3):
		var angle := float(i) * 2.15
		_add_cylinder(root, prefix + "UnevenOldWaxDrip", 0.008, 0.05 + float(i) * 0.02, base + Vector3(cos(angle) * 0.051, 0.23, sin(angle) * 0.051), mats.linen)
	var flame := MeshInstance3D.new()
	flame.name = prefix + "SmallUnsteadyFlame"
	flame.position = base + Vector3(0.0, 0.42, 0.0)
	var flame_quad := QuadMesh.new()
	flame_quad.size = Vector2(0.065, 0.10)
	var flame_material := ShaderMaterial.new()
	flame_material.shader = load("res://shaders/ritual_candle_flame.gdshader") as Shader
	flame_quad.material = flame_material
	flame.mesh = flame_quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flame)
	candle_flames.append(flame)
	var light := OmniLight3D.new()
	light.name = prefix + "RestrainedWarmPool"
	light.position = base + Vector3(0.0, 0.48, 0.0)
	light.light_color = Color(0.96, 0.61, 0.35)
	light.light_energy = energy
	light.omni_range = 3.05 if energy > 0.60 else 2.35
	light.omni_attenuation = 1.8
	light.shadow_enabled = casts_shadow
	root.add_child(light)
	candle_lights.append(light)
	candle_energy.append(energy)


func _build_lighting(root: Node3D, mats: Dictionary) -> void:
	_add_private_room_candle(root, mats, Vector3(3.15, 0.95, -4.51), "Dresser", 0.88, true)
	_add_private_room_candle(root, mats, Vector3(1.44, 0.61, -5.98), "Bedside", 0.42, false)
	var room_structure_fill := DirectionalLight3D.new()
	room_structure_fill.name = "VeryWeakColdStructuralFill"
	room_structure_fill.rotation_degrees = Vector3(-47.0, -19.0, 0.0)
	room_structure_fill.light_color = Color(0.34, 0.39, 0.47)
	room_structure_fill.light_energy = 0.32
	room_structure_fill.shadow_enabled = false
	root.add_child(room_structure_fill)
	var cold_window := SpotLight3D.new()
	cold_window.name = "ColdRainWindowMoonlight"
	cold_window.position = Vector3(-3.88, 2.26, 1.66)
	cold_window.light_color = Color(0.34, 0.45, 0.61)
	cold_window.light_energy = 2.55
	cold_window.spot_range = 9.3
	cold_window.spot_angle = 60.0
	cold_window.spot_attenuation = 1.65
	cold_window.shadow_enabled = false
	root.add_child(cold_window)
	cold_window.look_at(Vector3(-0.40, 1.10, -4.65), Vector3.UP)
	var bed_rim := SpotLight3D.new()
	bed_rim.name = "FocusedColdBedCanopyReadability"
	bed_rim.position = Vector3(-1.86, 2.48, -2.55)
	bed_rim.light_color = Color(0.36, 0.43, 0.53)
	bed_rim.light_energy = 2.68
	bed_rim.spot_range = 5.7
	bed_rim.spot_angle = 43.0
	bed_rim.spot_attenuation = 1.55
	bed_rim.shadow_enabled = false
	root.add_child(bed_rim)
	bed_rim.look_at(Vector3(-0.46, 1.28, -5.10), Vector3.UP)
	var rafters_bounce := OmniLight3D.new()
	rafters_bounce.name = "BarelyVisibleBeamBounce"
	rafters_bounce.position = Vector3(0.0, 2.73, -2.35)
	rafters_bounce.light_color = Color(0.30, 0.34, 0.39)
	rafters_bounce.light_energy = 0.30
	rafters_bounce.omni_range = 8.8
	rafters_bounce.omni_attenuation = 2.1
	rafters_bounce.shadow_enabled = false
	root.add_child(rafters_bounce)
	final_corridor_light = OmniLight3D.new()
	final_corridor_light.name = "FaintMainHallThresholdSpill"
	final_corridor_light.position = Vector3(0.0, 2.25, 6.85)
	final_corridor_light.light_color = Color(0.27, 0.29, 0.31)
	final_corridor_light.light_energy = 0.86
	final_corridor_light.omni_range = 5.6
	final_corridor_light.omni_attenuation = 2.0
	final_corridor_light.shadow_enabled = false
	root.add_child(final_corridor_light)


func _build_atmosphere(root: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "SparsePrivateRoomDust"
	dust.position = Vector3(0.0, 1.8, -1.5)
	dust.amount = 23
	dust.lifetime = 12.0
	dust.randomness = 0.82
	dust.visibility_aabb = AABB(Vector3(-4.2, -1.8, -6.2), Vector3(8.4, 3.8, 14.8))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(3.2, 1.4, 6.8)
	process.direction = Vector3(0.01, -0.05, 0.02)
	process.spread = 68.0
	process.initial_velocity_min = 0.006
	process.initial_velocity_max = 0.018
	process.gravity = Vector3(0.0, -0.002, 0.0)
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.014, 0.014)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mat.albedo_color = Color(0.57, 0.56, 0.51, 0.14)
	dust_mat.albedo_texture = _soft_particle_texture()
	quad.material = dust_mat
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dust)
	dust.emitting = true


func _make_room_friction_stream(seed_value: int, pitch: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := 5500
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i in range(sample_count):
		var t := float(i) / 22050.0
		var envelope := sin(PI * minf(t / 0.25, 1.0)) * exp(-t * 8.5)
		var noise := random.randf_range(-1.0, 1.0) * envelope * 0.14
		var wood := sin(TAU * pitch * t) * exp(-t * 18.0) * 0.16
		data.encode_s16(i * 2, int(clampf(noise + wood, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream


func _build_story_audio() -> void:
	rustle_audio = AudioStreamPlayer3D.new()
	rustle_audio.name = "OldMirrorClothRustle"
	rustle_audio.position = Vector3(3.25, 1.45, -4.12)
	rustle_audio.stream = _make_room_friction_stream(18816, 92.0)
	rustle_audio.volume_db = -17.0
	add_child(rustle_audio)
	drawer_audio = AudioStreamPlayer3D.new()
	drawer_audio.name = "OldDresserDrawerFriction"
	drawer_audio.position = Vector3(3.20, 0.65, -4.02)
	drawer_audio.stream = _make_room_friction_stream(59372, 121.0)
	drawer_audio.volume_db = -16.0
	add_child(drawer_audio)
	floor_audio = AudioStreamPlayer3D.new()
	floor_audio.name = "SingleUnexplainedFloorCreak"
	floor_audio.position = Vector3(-0.45, 0.15, -4.8)
	floor_audio.stream = _make_room_friction_stream(67103, 64.0)
	floor_audio.volume_db = -24.0
	add_child(floor_audio)


func _ready() -> void:
	super._ready()
	next_wood_creak_at = Time.get_ticks_msec() * 0.001 + randf_range(13.0, 23.0)
	final_chapter_trigger = Node3D.new()
	final_chapter_trigger.name = "FinalChapterTrigger"
	final_chapter_trigger.set_script(preload("res://scripts/final_chapter_trigger.gd"))
	add_child(final_chapter_trigger)
	final_chapter_trigger.call("setup", self)
	_finish_unsent_letter_reading()


func _build_hud() -> void:
	super._build_hud()
	hud.document_closed.connect(_on_document_closed)
	_update_objective()


func _build_audio() -> void:
	super._build_audio()
	rain_audio.volume_db = -21.0


func _process(delta: float) -> void:
	super._process(delta)
	for light in candle_lights:
		light.light_energy *= final_candle_factor
	var now := Time.get_ticks_msec() * 0.001
	if not final_sequence_running and not _state().final_chapter_started and now >= next_wood_creak_at and not floor_audio.playing:
		floor_audio.volume_db = -27.0
		floor_audio.pitch_scale = randf_range(0.68, 0.90)
		floor_audio.play()
		next_wood_creak_at = now + randf_range(17.0, 31.0)


func _physics_process(delta: float) -> void:
	if room_busy:
		_update_animation(false, 0.0)
		return
	var input_2d := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_2d.x, 0.0, input_2d.y)
	var target := direction.normalized() * WALK_SPEED if direction.length_squared() > 0.01 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, target.x, 7.5 * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, 7.5 * delta)
	player.velocity.y = -0.2
	var before := player.global_position
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -ROOM_X_LIMIT, ROOM_X_LIMIT)
	player.global_position.z = clampf(player.global_position.z, ROOM_FAR_Z, ROOM_NEAR_Z)
	player.global_position.y = move_toward(player.global_position.y, 0.02, delta * 1.8)
	var speed := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length() / maxf(delta, 0.0001)
	_update_facing(direction)
	_update_animation(speed > 0.055, speed)
	_update_flashlight()
	_update_camera(delta, speed)
	if _state().bedroom_letter_read and _state().bedroom_mirror_uncovered and not _state().bedroom_mirror_event_seen and Time.get_ticks_msec() * 0.001 >= mirror_event_earliest_at:
		if Vector2(player.position.x, player.position.z).distance_to(MIRROR_POINT) < 1.68:
			_trigger_mirror_afterimage()
	if not _state().final_chapter_started and _state().bedroom_hidden_note_found and _state().bedroom_letter_read and not _state().bedroom_exit_event_done and player.position.z > 6.18:
		_trigger_exit_event()
	_update_hud()


func _interaction_target() -> String:
	var p := Vector2(player.position.x, player.position.z)
	if player.position.z > 6.72:
		return "" if final_sequence_running else "exit"
	if not _state().bedroom_photo_found and p.distance_to(BED_BOX_POINT) < 1.08:
		return "bed_box" if not _state().bedroom_bed_box_open else "photo"
	if not _state().bedroom_hairpin_examined \
		and not _state().has_item("broken_silver_hairpin") \
		and not _state().has_item("complete_silver_hairpin") \
		and p.distance_to(HAIRPIN_POINT) < 0.95:
		return "hairpin"
	if unsent_letter_visual.visible and p.distance_to(DRESSER_POINT) < 1.12:
		return "unsent_letter"
	if p.distance_to(MIRROR_POINT) < 1.15:
		if not _state().bedroom_mirror_inspected:
			return "mirror_inspect"
		if not _state().bedroom_mirror_uncovered or _state().bedroom_mirror_recovered:
			return "mirror_uncover"
		if _state().bedroom_mirror_event_seen and not _state().bedroom_hidden_note_found:
			return "mirror_back"
		return "mirror_view"
	if p.distance_to(DRESSER_POINT) < 1.36:
		return "dresser_drawer"
	if p.distance_to(WARDROBE_POINT) < 1.17:
		return "wardrobe"
	if p.distance_to(Vector2(-0.46, -3.0)) < 1.14:
		return "bed"
	return ""


func _update_hud() -> void:
	var target := _interaction_target()
	if target != hud_interaction_target:
		hud_interaction_target = target
		hud.call("set_door_prompt_visible", not target.is_empty())
		var prompt := ""
		match target:
			"exit": prompt = "返回主大堂"
			"hairpin": prompt = "调查断裂的发簪"
			"mirror_inspect": prompt = "调查被遮住的铜镜"
			"mirror_uncover": prompt = "掀开镜布"
			"mirror_view": prompt = "查看氧化的铜镜"
			"mirror_back": prompt = "检查铜镜背面"
			"dresser_drawer": prompt = "调查梳妆台抽屉" if not _state().bedroom_drawer_open else "查看已经打开的抽屉"
			"unsent_letter": prompt = "拾取未寄出的信"
			"bed_box": prompt = "查看床底的小木盒"
			"photo": prompt = "拾取残缺旧照片与绣布"
			"wardrobe": prompt = "调查老旧衣柜"
			"bed": prompt = "查看凌乱的床铺"
		hud.call("set_interaction_text", prompt)
	if not narration_active:
		var stage := 0
		var caption := "门后的雨声变得很远，房间像是突然停止了生活"
		if player.position.z < -3.05:
			stage = 2
			caption = "床幔已经褪色；梳妆台上的东西却还留在原位"
		elif player.position.z < 1.5:
			stage = 1
			caption = "窗边有潮湿的冷气，屋里的衣物积着很久的灰"
		if stage != story_stage:
			story_stage = stage
			hud.call("set_story_caption", caption, true)
	_update_objective()


func _update_objective() -> void:
	if hud == null:
		return
	var objective := "调查上锁的旧卧房"
	if _state().final_chapter_objective_revealed:
		objective = GameState.APPROACH_HALL_OBJECTIVE
	elif _state().bedroom_hidden_note_found:
		if not _state().bedroom_hairpin_examined:
			objective = "检查梳妆台上的断裂银簪"
		elif not _state().bedroom_photo_found:
			objective = "寻找卧房主人留下的物件"
		elif not _state().bedroom_photo_inscription_revealed:
			objective = "仔细查看背包里的旧合影"
		else:
			objective = "对照旧绣布上的字迹"
	elif _state().bedroom_letter_read:
		objective = "调查这个房间原来的主人" if not _state().bedroom_mirror_event_seen else "检查封镜背后的异样"
	elif _state().has_item("bedroom_unsent_letter"):
		objective = "读完背包中的未寄出的信"
	elif _state().bedroom_mirror_uncovered:
		objective = "搜索梳妆台里未寄出的东西"
	hud.call("set_objective", objective)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if room_busy:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		var target := _interaction_target()
		if not target.is_empty():
			get_viewport().set_input_as_handled()
			_handle_interaction(target)
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_bedroom()


func _handle_interaction(target: String) -> void:
	match target:
		"exit": _leave_bedroom()
		"hairpin":
			_state().bedroom_hairpin_examined = true
			if _state().add_item("broken_silver_hairpin"):
				hairpin_visual.hide()
				if _state().has_item("complete_silver_hairpin"):
					hud.call("set_story_caption", "两截银簪的断口完全吻合。", true, true)
				else:
					hud.call("set_story_caption", "半截簪身已经发黑，断口却很整齐，不像自然损坏。", true, true)
			_try_begin_final_chapter()
		"mirror_inspect":
			_state().bedroom_mirror_inspected = true
			hud.call("set_story_caption", "为什么要把镜子盖起来？布上压着一层潮灰。", true, true)
		"mirror_uncover": _uncover_mirror()
		"mirror_view": hud.call("set_story_caption", "铜面氧化得太厉害，只照出不完整的暗影。", true, true)
		"mirror_back": _inspect_mirror_back()
		"dresser_drawer": _open_dresser_drawer()
		"unsent_letter":
			if _state().add_item("bedroom_unsent_letter"):
				unsent_letter_visual.hide()
				hud.call("open_document_item", "bedroom_unsent_letter")
		"bed_box": _open_bed_box()
		"photo":
			if _state().add_item("scratched_family_photo"):
				_state().add_item("old_embroidery_cloth")
				_state().bedroom_photo_found = true
				photo_visual.hide()
				hud.call("open_document_item", "scratched_family_photo")
		"wardrobe": hud.call("set_story_caption", "衣柜里只剩一件潮湿旧衣。挂钩上原本还该有别的东西。", true, true)
		"bed": hud.call("set_story_caption", "被褥停在被人匆忙掀开的位置。枕边落灰更浅。", true, true)


func _uncover_mirror() -> void:
	if room_busy:
		return
	room_busy = true
	player.velocity = Vector3.ZERO
	rustle_audio.play()
	var tween := create_tween()
	tween.tween_property(mirror_cloth, "position:y", 0.96, 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_state().bedroom_mirror_inspected = true
	_state().bedroom_mirror_uncovered = true
	_state().bedroom_mirror_recovered = false
	room_busy = false
	hud.call("set_story_caption", "布落到梳妆台边。镜面发黑，看不清完整的人影。", true, true)
	mirror_event_earliest_at = Time.get_ticks_msec() * 0.001 + 1.7


func _open_dresser_drawer() -> void:
	if _state().bedroom_drawer_open:
		hud.call("set_story_caption", "抽屉深处留着一道比其他地方干净的纸痕。", true, true)
		return
	room_busy = true
	player.velocity = Vector3.ZERO
	drawer_audio.play()
	var tween := create_tween()
	tween.tween_property(dressing_drawer, "position:x", 2.82, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_state().bedroom_drawer_open = true
	unsent_letter_visual.visible = not _state().has_item("bedroom_unsent_letter")
	room_busy = false
	hud.call("set_story_caption", "抽屉里压着一封从未寄出的信，纸张已被潮气粘住。" if unsent_letter_visual.visible else "抽屉底只剩一处被信纸遮过的浅色方痕。", true, true)


func _trigger_mirror_afterimage() -> void:
	if _state().bedroom_mirror_event_seen or mirror_afterimage.transparency < 1.0:
		return
	_state().bedroom_mirror_event_seen = true
	rustle_audio.volume_db = -27.0
	rustle_audio.play()
	var tween := create_tween()
	tween.tween_property(mirror_afterimage, "transparency", 0.35, 0.25)
	tween.tween_interval(0.86)
	tween.tween_property(mirror_afterimage, "transparency", 1.0, 0.33)
	await tween.finished
	floor_audio.volume_db = -28.0
	floor_audio.play()
	hud.call("set_story_caption", "镜里似乎掠过一道身影。回头看时，床边什么也没有。", true, true)
	_update_objective()


func _inspect_mirror_back() -> void:
	if room_busy or not _state().bedroom_mirror_event_seen:
		return
	room_busy = true
	var tween := create_tween()
	tween.tween_property(mirror_root, "rotation_degrees:y", 210.0, 0.96).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	mirror_talisman.show()
	_state().bedroom_hidden_note_found = true
	_state().add_item("lan_no_register_note")
	hud.call("set_story_caption", "镜背只压着一张失色的符。符后，是一片写过字的残纸。", true, true)
	_update_objective()
	final_chapter_trigger.call_deferred("play_mirror_warning")


func _on_mirror_warning_finished() -> void:
	room_busy = false
	if _state().has_item("lan_no_register_note") and not hud.inventory_document_is_open:
		hud.call("open_document_item", "lan_no_register_note")


func _open_bed_box() -> void:
	if _state().bedroom_bed_box_open or room_busy:
		return
	room_busy = true
	player.velocity = Vector3.ZERO
	drawer_audio.volume_db = -21.0
	drawer_audio.play()
	var tween := create_tween()
	tween.tween_property(bed_box_root, "position:z", -3.48, 0.40)
	tween.tween_property(bed_box_lid, "rotation_degrees:x", -83.0, 0.48)
	await tween.finished
	_state().bedroom_bed_box_open = true
	photo_visual.show()
	room_busy = false
	hud.call("set_story_caption", "木盒里是一张被刮坏的合影，下面还压着一小片旧绣布。", true, true)


func _on_document_closed(item_id: String) -> void:
	if item_id == "bedroom_unsent_letter":
		_finish_unsent_letter_reading()
	elif item_id == "scratched_family_photo":
		if not _try_begin_final_chapter():
			_narrate_photo_discovery()
	elif item_id == "old_embroidery_cloth":
		_state().bedroom_embroidery_examined = true
		if not _try_begin_final_chapter():
			hud.call("set_story_caption", "绣布背面没有拆净的针脚，只留下一个‘沈’字。", true, true)
	elif item_id == "lan_no_register_note":
		hud.call("set_story_caption", "‘兰娘’。有人让这个称呼从家谱上消失。", true, true)
		_update_objective()
		_try_begin_final_chapter()


func _finish_unsent_letter_reading() -> void:
	var state := _state()
	if state.bedroom_letter_read or not state.has_completed_document("bedroom_unsent_letter"):
		return
	state.bedroom_letter_read = true
	mirror_event_earliest_at = Time.get_ticks_msec() * 0.001 + 2.2
	_narrate_letter_discovery()


func _narrate_letter_discovery() -> void:
	if final_sequence_running or _state().final_chapter_started:
		return
	narration_active = true
	hud.call("set_story_caption", "绳子在她进去之前……就已经挂好了。", true, true, 10, 1.45)
	await get_tree().create_timer(1.45, false).timeout
	if final_sequence_running or _state().final_chapter_started:
		return
	hud.call("set_story_caption", "所以他们不是后来发现她死在那里。", true, true, 10, 1.50)
	await get_tree().create_timer(1.50, false).timeout
	if final_sequence_running or _state().final_chapter_started:
		return
	# The HUD retains the final line after free exploration resumes. Region
	# captions wait for its reading time instead of replacing it on movement.
	hud.call("set_story_caption", "他们是把她送进去的。", true, true, 10, 4.0)
	narration_active = false
	_update_objective()


func _narrate_photo_discovery() -> void:
	if final_sequence_running or _state().final_chapter_started:
		return
	narration_active = true
	hud.call("set_story_caption", "这个位置被人故意刮掉了。", true, true, 10, 1.35)
	await get_tree().create_timer(1.35, false).timeout
	if final_sequence_running or _state().final_chapter_started:
		return
	hud.call("set_story_caption", "但这支簪子……和梳妆台上的那一支很像。", true, true, 10, 4.0)
	narration_active = false


func _can_confirm_shen_yuelan_identity() -> bool:
	return not _state().final_chapter_started \
		and _state().bedroom_photo_inscription_revealed \
		and _state().bedroom_photo_found \
		and _state().bedroom_hairpin_examined \
		and _state().bedroom_letter_read \
		and _state().bedroom_hidden_note_found \
		and _state().has_item("old_embroidery_cloth")


func _try_begin_final_chapter() -> bool:
	if not _can_confirm_shen_yuelan_identity():
		return false
	# The cloth is acquired together with the photograph. Once its description
	# supplies the surname and the repeated photo inspection reveals “月兰”,
	# closing the photograph is the natural confirmation point for 沈月兰.
	_state().bedroom_embroidery_examined = true
	final_chapter_trigger.call_deferred("begin")
	return true


func _trigger_exit_event() -> void:
	if _state().bedroom_exit_event_done:
		return
	_state().bedroom_exit_event_done = true
	drawer_audio.volume_db = -24.0
	drawer_audio.pitch_scale = 0.72
	drawer_audio.play()
	if _state().bedroom_drawer_open:
		var drawer_tween := create_tween()
		drawer_tween.tween_property(dressing_drawer, "position:x", 3.13, 1.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_state().bedroom_drawer_open = false
	if _state().bedroom_mirror_uncovered:
		rustle_audio.volume_db = -25.0
		rustle_audio.play()
		var tween := create_tween()
		tween.tween_property(mirror_cloth, "position:y", 2.03, 1.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_state().bedroom_mirror_recovered = true
	hud.call("set_story_caption", "背后传来抽屉缓缓合上的声音。镜布不知何时又盖了回去。", true, true)
	_update_objective()


func _leave_bedroom() -> void:
	if final_sequence_running:
		return
	_state().return_to_hall_sealed_door = true
	_change_scene(MAIN_HALL_PATH)
