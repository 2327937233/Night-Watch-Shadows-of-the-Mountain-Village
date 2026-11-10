extends Node3D

const WOOD_MATERIAL: Material = preload("res://materials/architecture/wet_old_wood.tres")
const PLASTER_MATERIAL: Material = preload("res://materials/architecture/peeling_plaster.tres")
const ROOF_MATERIAL: Material = preload("res://materials/architecture/wet_gray_roof_tile.tres")

# One 2.4 m entrance bay. The rest of the wing deliberately remains greybox
# until this sample is approved.
const WALL_X = -6.36
const COLUMN_X = -5.08
const BAY_CENTER_Z = 5.05
const BAY_LENGTH = 2.4
const COLUMN_Z = [6.25, 3.85]

var lantern_light: OmniLight3D
var lantern_time = 0.0


func build() -> void:
	name = "LeftWingArtTest_EntranceSingleBay"
	var materials = _build_support_materials()
	_build_plinth(materials)
	_build_wing_transition(materials)
	_build_wall_and_openings(materials)
	_build_timber_frame(materials)
	_build_eave(materials)
	_build_lantern(materials)
	_build_props(materials)
	_build_wet_age_details(materials)
	set_process(true)


func _process(delta: float) -> void:
	if lantern_light == null:
		return
	lantern_time += delta
	# Imperfect oil flame, kept subtle enough that the room does not pulse.
	lantern_light.light_energy = 1.28 + sin(lantern_time * 2.1) * 0.024 + sin(lantern_time * 5.7) * 0.012


func _build_support_materials() -> Dictionary:
	var return_wall_material = PLASTER_MATERIAL.duplicate(true) as ShaderMaterial
	return_wall_material.set_shader_parameter("uv_repeat", Vector2(0.92, 1.18))
	return_wall_material.set_shader_parameter("weathering_repeat", Vector2(0.74, 0.96))
	return_wall_material.set_shader_parameter("weathering_strength", 0.90)
	return_wall_material.set_shader_parameter("wall_root_dampness", 0.92)
	return_wall_material.set_shader_parameter("rain_streak_strength", 0.72)
	return_wall_material.set_shader_parameter("crack_strength", 0.52)
	return_wall_material.set_shader_parameter("moss_amount", 0.56)
	var materials = {
		"stone": _make_material(Color(0.18, 0.19, 0.19), 0.62),
		"stone_edge": _make_material(Color(0.115, 0.125, 0.125), 0.72),
		"exposed_brick": _make_material(Color(0.105, 0.105, 0.098), 0.82),
		"dark_recess": _make_material(Color(0.014, 0.013, 0.012), 0.96),
		"iron": _make_material(Color(0.075, 0.068, 0.06), 0.7, 0.02),
		"ceramic": _make_material(Color(0.14, 0.075, 0.043), 0.58),
		"ceramic_edge": _make_material(Color(0.22, 0.12, 0.065), 0.62),
		"vegetation": _make_material(Color(0.09, 0.115, 0.065), 0.92),
		"mud": _make_material(Color(0.055, 0.046, 0.036), 0.8),
		"lantern_paper": _make_material(
			Color(0.62, 0.50, 0.34), 0.82, 0.0,
			Color(0.88, 0.58, 0.28), 0.68
		),
		"lantern_core": _make_material(
			Color(0.68, 0.43, 0.19), 0.66, 0.0,
			Color(0.96, 0.62, 0.28), 0.58
		),
		"lantern_frame": _make_material(Color(0.16, 0.085, 0.035), 0.68),
		"lantern_stain": _make_material(Color(0.19, 0.105, 0.05), 0.9),
		"return_wall": return_wall_material,
	}
	# Keep the paper shaded so its cylindrical volume and timber cage remain visible.
	# A small emissive core inside supplies the weak internal glow.
	var paper = materials.lantern_paper as StandardMaterial3D
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Thin paper faces otherwise turn almost black when the gameplay camera sees
	# their back side at an oblique angle. The cage and stains retain the shape.
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return materials


func _build_plinth(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "StonePlinth_026m_And_145mVeranda"
	add_child(group)
	_add_box(group, "RaisedStonePlinth", Vector3(1.68, 0.26, 2.72), Vector3(-5.68, 0.13, BAY_CENTER_Z), materials.stone_edge)
	_add_box(group, "CourtyardFacingStep", Vector3(0.42, 0.13, 2.56), Vector3(-4.62, 0.065, BAY_CENTER_Z), materials.stone_edge)
	for index in range(3):
		var slab = _add_box(
			group, "VerandaStoneSlab_%02d" % index,
			Vector3(1.42, 0.045, 0.76),
			Vector3(-5.68, 0.285 + float(index % 2) * 0.006, 4.25 + index * 0.8),
			materials.stone
		)
		slab.rotation_degrees.y = -0.8 + index * 0.75
	_add_box(group, "DoorThreshold", Vector3(0.34, 0.16, 0.92), Vector3(-6.14, 0.37, 5.62), materials.stone_edge)


func _build_wing_transition(materials: Dictionary) -> void:
	# This short restoration segment closes the missing five-metre void between the
	# approved sample and the distant greybox. It intentionally has no second door,
	# window or lantern, so the single art-test bay remains the only detailed bay.
	var group = Node3D.new()
	group.name = "RestoredWallTransition_NotASecondArtBay"
	add_child(group)
	var center_z = 2.98
	var length = 1.58

	_add_box(group, "ContinuousStonePlinth", Vector3(1.68, 0.26, length), Vector3(-5.68, 0.13, center_z), materials.stone_edge)
	_add_box(group, "ContinuousCourtyardStep", Vector3(0.42, 0.13, length - 0.08), Vector3(-4.62, 0.065, center_z), materials.stone_edge)
	_add_box(group, "RestoredPeelingPlasterWall", Vector3(0.34, 2.58, length), Vector3(WALL_X, 1.58, center_z), PLASTER_MATERIAL)
	_add_box(group, "WallRootDampBand", Vector3(0.025, 0.34, length - 0.08), Vector3(WALL_X + 0.175, 0.47, center_z), materials.mud)
	_add_box(group, "ExposedBrickAtJoin", Vector3(0.035, 0.52, 0.38), Vector3(WALL_X + 0.18, 0.86, 2.55), materials.exposed_brick)

	var join_column_z = 2.24
	_add_cylinder(group, "TransitionOldWoodColumn_0280mm", 0.14, 2.72, Vector3(COLUMN_X, 1.72, join_column_z), WOOD_MATERIAL)
	_add_cylinder(group, "TransitionStoneColumnBase", 0.23, 0.2, Vector3(COLUMN_X, 0.38, join_column_z), materials.stone)
	_add_cylinder(group, "TransitionStoneBaseFoot", 0.27, 0.08, Vector3(COLUMN_X, 0.3, join_column_z), materials.stone_edge)
	_add_box(group, "TransitionColumnCapital", Vector3(0.4, 0.14, 0.4), Vector3(COLUMN_X, 3.03, join_column_z), WOOD_MATERIAL)
	_add_box(group, "TransitionFrontBeam", Vector3(0.28, 0.26, length + 0.14), Vector3(COLUMN_X, 3.19, center_z), WOOD_MATERIAL)
	_add_box(group, "TransitionRearBeam", Vector3(0.24, 0.24, length + 0.14), Vector3(-6.2, 3.13, center_z), WOOD_MATERIAL)
	_add_box(group, "TransitionEavePurlin", Vector3(0.22, 0.18, length + 0.22), Vector3(-4.72, 3.36, center_z), WOOD_MATERIAL)

	var backing = _add_box(group, "TransitionRoofUnderlay", Vector3(0.62, 0.025, length + 0.06), Vector3(-6.1, 3.475, center_z), ROOF_MATERIAL)
	backing.rotation_degrees.z = -10.0
	for x_index in range(13):
		var x = -4.56 - float(x_index) * 0.16
		var slope_y = 3.34 + float(x_index) * 0.028
		for z_index in range(4):
			var z = 2.23 + float(z_index) * 0.49 + float(x_index % 2) * 0.035
			var tile = _add_cylinder(group, "TransitionGrayTile_%02d_%02d" % [x_index, z_index], 0.073, 0.55, Vector3(x, slope_y, z), ROOF_MATERIAL, 0.058)
			tile.rotation_degrees.x = 90.0
	for z_index in range(8):
		var z = 2.2 + float(z_index) * 0.22
		var drip = _add_cylinder(group, "TransitionDripTile_%02d" % z_index, 0.085, 0.22, Vector3(-4.53, 3.31, z), ROOF_MATERIAL, 0.068)
		drip.rotation_degrees.z = 90.0
	for index in range(4):
		var z = 2.32 + float(index) * 0.45
		var rafter = _add_box(group, "TransitionRafter_%02d" % index, Vector3(1.92, 0.075, 0.095), Vector3(-5.5, 3.31, z), WOOD_MATERIAL)
		rafter.rotation_degrees.z = -10.0

	var readability_fill = OmniLight3D.new()
	readability_fill.name = "TransitionStructureReadabilityFill"
	readability_fill.position = Vector3(-4.72, 1.55, 3.0)
	readability_fill.light_color = Color(0.28, 0.34, 0.4)
	readability_fill.light_energy = 0.3
	readability_fill.omni_range = 3.15
	readability_fill.omni_attenuation = 1.8
	group.add_child(readability_fill)


func _build_wall_and_openings(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "PeelingPlasterWall_DoorAndBrokenWindow"
	add_child(group)

	# Continuous wall regions close the facade around the openings. The previous
	# narrow strips exposed the interior void from oblique courtyard angles.
	_add_box(group, "WallTopBand", Vector3(0.34, 0.48, 2.76), Vector3(WALL_X, 2.73, BAY_CENTER_Z), PLASTER_MATERIAL)
	_add_box(group, "WallBottomBand", Vector3(0.34, 0.28, 2.76), Vector3(WALL_X, 0.43, BAY_CENTER_Z), PLASTER_MATERIAL)
	_add_box(group, "WallNearEnd", Vector3(0.34, 2.58, 0.22), Vector3(WALL_X, 1.58, 6.30), PLASTER_MATERIAL)
	_add_box(group, "WallDoorWindowPier", Vector3(0.34, 2.58, 0.22), Vector3(WALL_X, 1.58, 5.03), PLASTER_MATERIAL)
	_add_box(group, "WallFarEnd", Vector3(0.34, 2.58, 0.22), Vector3(WALL_X, 1.58, 3.80), PLASTER_MATERIAL)
	_add_box(group, "WallBelowWindow", Vector3(0.34, 0.68, 0.82), Vector3(WALL_X, 0.78, 4.31), PLASTER_MATERIAL)
	_add_box(group, "WallAboveWindow", Vector3(0.34, 0.50, 0.82), Vector3(WALL_X, 2.38, 4.31), PLASTER_MATERIAL)
	_add_box(group, "NearReturnWall", Vector3(1.30, 2.45, 0.18), Vector3(-5.72, 1.52, 6.39), materials.return_wall)
	_add_box(group, "FarReturnWall", Vector3(1.30, 2.45, 0.18), Vector3(-5.72, 1.52, 3.71), PLASTER_MATERIAL)
	_build_old_door(group, materials)
	_build_broken_lattice_window(group, materials)

	# A few shallow exposed-brick patches break the repeated plaster texture.
	for data in [[0.76, 6.12, 0.3, 0.34], [1.02, 4.92, 0.42, 0.25], [0.57, 3.9, 0.27, 0.31]]:
		_add_box(group, "ExposedMasonryPatch", Vector3(0.035, float(data[2]), float(data[3])), Vector3(WALL_X + 0.18, float(data[0]), float(data[1])), materials.exposed_brick)


func _build_old_door(parent: Node3D, materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "ThickWeatheredDoubleDoor_2080mm"
	parent.add_child(group)
	var x = WALL_X + 0.2
	var center_z = 5.65
	_add_box(group, "DoorRecess", Vector3(0.18, 2.28, 1.02), Vector3(x - 0.13, 1.48, center_z), materials.dark_recess)
	for side in [-1.0, 1.0]:
		var leaf_z: float = center_z + float(side) * 0.235
		_add_box(group, "DoorLeaf", Vector3(0.18, 2.08, 0.44), Vector3(x, 1.46, leaf_z), WOOD_MATERIAL)
		for y in [0.83, 1.48, 2.13]:
			_add_box(group, "DoorPanelRail", Vector3(0.055, 0.055, 0.36), Vector3(x + 0.115, y, leaf_z), WOOD_MATERIAL)
	_add_box(group, "DoorFrameTop", Vector3(0.3, 0.2, 1.24), Vector3(x, 2.58, center_z), WOOD_MATERIAL)
	for side in [-1.0, 1.0]:
		_add_box(group, "DoorFrameSide", Vector3(0.3, 2.28, 0.15), Vector3(x, 1.49, center_z + side * 0.55), WOOD_MATERIAL)
		var ring = _add_cylinder(group, "RustDoorKnocker", 0.048, 0.024, Vector3(x + 0.13, 1.5, center_z + side * 0.13), materials.iron)
		ring.rotation_degrees.z = 90.0
	_add_box(group, "WaterDarkenedDoorFoot", Vector3(0.025, 0.33, 0.84), Vector3(x + 0.105, 0.57, center_z), materials.mud)


func _build_broken_lattice_window(parent: Node3D, materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "BrokenThickLatticeWindow"
	parent.add_child(group)
	var x = WALL_X + 0.2
	var center_z = 4.31
	_add_box(group, "UnlitInterior", Vector3(0.14, 1.32, 0.9), Vector3(x - 0.12, 1.72, center_z), materials.dark_recess)
	for y in [1.08, 2.36]:
		_add_box(group, "WindowHorizontalFrame", Vector3(0.28, 0.13, 1.04), Vector3(x, y, center_z), WOOD_MATERIAL)
	for side in [-1.0, 1.0]:
		_add_box(group, "WindowVerticalFrame", Vector3(0.28, 1.42, 0.13), Vector3(x, 1.72, center_z + side * 0.46), WOOD_MATERIAL)
	for offset in [-0.25, 0.0, 0.25]:
		if is_zero_approx(offset):
			continue
		_add_box(group, "LatticeVertical", Vector3(0.12, 1.1, 0.045), Vector3(x + 0.15, 1.72, center_z + offset), WOOD_MATERIAL)
	for y in [1.4, 1.72, 2.04]:
		_add_box(group, "LatticeHorizontal", Vector3(0.12, 0.045, 0.8), Vector3(x + 0.15, y, center_z), WOOD_MATERIAL)
	var broken = _add_box(group, "BrokenLatticeSliver", Vector3(0.12, 0.045, 0.42), Vector3(x + 0.15, 1.88, center_z + 0.05), WOOD_MATERIAL)
	broken.rotation_degrees.x = 24.0


func _build_timber_frame(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "TwoSlenderColumns_0280mm_AndLayeredBeams"
	add_child(group)
	for index in range(COLUMN_Z.size()):
		var z: float = COLUMN_Z[index]
		_add_cylinder(group, "WetOldWoodColumn_%02d" % index, 0.14, 2.72, Vector3(COLUMN_X, 1.72, z), WOOD_MATERIAL)
		_add_cylinder(group, "StoneColumnBase_%02d" % index, 0.23, 0.2, Vector3(COLUMN_X, 0.38, z), materials.stone)
		_add_cylinder(group, "StoneBaseFoot_%02d" % index, 0.27, 0.08, Vector3(COLUMN_X, 0.3, z), materials.stone_edge)
		_add_box(group, "ColumnCapital_%02d" % index, Vector3(0.4, 0.14, 0.4), Vector3(COLUMN_X, 3.03, z), WOOD_MATERIAL)
		_add_box(group, "TransverseBeam_%02d" % index, Vector3(1.55, 0.15, 0.2), Vector3(-5.72, 3.08, z), WOOD_MATERIAL)
		_add_box(group, "Bracket_%02d" % index, Vector3(0.38, 0.13, 0.34), Vector3(-5.25, 2.94, z), WOOD_MATERIAL, Vector3(0.0, 0.0, -11.0))
	_add_box(group, "CourtyardLongitudinalBeam", Vector3(0.28, 0.26, 2.7), Vector3(COLUMN_X, 3.19, BAY_CENTER_Z), WOOD_MATERIAL)
	_add_box(group, "RearLongitudinalBeam", Vector3(0.24, 0.24, 2.7), Vector3(-6.2, 3.13, BAY_CENTER_Z), WOOD_MATERIAL)
	_add_box(group, "EavePurlin", Vector3(0.22, 0.18, 2.82), Vector3(-4.72, 3.36, BAY_CENTER_Z), WOOD_MATERIAL)
	# Narrow return frames close the sample cleanly without extending it into a second bay.
	for z in [3.77, 6.33]:
		_add_box(group, "BayEndReturnPost", Vector3(0.24, 2.48, 0.18), Vector3(-6.18, 1.62, z), WOOD_MATERIAL)
		_add_box(group, "BayEndReturnBeam", Vector3(1.46, 0.16, 0.18), Vector3(-5.57, 2.8, z), WOOD_MATERIAL)
		var brace = _add_box(group, "EaveKneeBrace", Vector3(0.62, 0.1, 0.12), Vector3(-5.16, 2.82, z), WOOD_MATERIAL)
		brace.rotation_degrees.z = -28.0


func _build_eave(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "GeometricGrayTileEave_075mOverhang"
	add_child(group)
	# A recessed dark underlay only closes tile gaps; visible roof form comes from
	# the overlapping geometric tiles and exposed rafters.
	var backing = _add_box(group, "RoofUnderlay", Vector3(0.62, 0.025, 2.48), Vector3(-6.1, 3.475, BAY_CENTER_Z), ROOF_MATERIAL)
	backing.rotation_degrees.z = -10.0
	# Short overlapping channels expose individual tile laps instead of reading as
	# a smooth metal sheet. Every second row is offset slightly like hand-laid tiles.
	for x_index in range(13):
		var x: float = -4.56 - float(x_index) * 0.16
		var slope_y: float = 3.34 + float(x_index) * 0.028
		for z_index in range(6):
			var z: float = 3.82 + float(z_index) * 0.49 + float(x_index % 2) * 0.035
			var tile = _add_cylinder(
				group, "OverlappingGrayTile_%02d_%02d" % [x_index, z_index],
				0.073, 0.55, Vector3(x, slope_y + float(z_index % 2) * 0.004, z),
				ROOF_MATERIAL, 0.058
			)
			tile.rotation_degrees.x = 90.0
	# Repeated short curved caps make the courtyard edge read as traditional drip tiles.
	for z_index in range(13):
		var z: float = 3.75 + float(z_index) * 0.215
		var drip = _add_cylinder(group, "DripEdgeTile_%02d" % z_index, 0.085, 0.22, Vector3(-4.53, 3.31, z), ROOF_MATERIAL, 0.068)
		drip.rotation_degrees.z = 90.0
	# A restrained ridge row closes the rear roof line and gives the silhouette depth.
	for z_index in range(12):
		var z: float = 3.82 + float(z_index) * 0.225
		var ridge = _add_cylinder(group, "RearRidgeCap_%02d" % z_index, 0.09, 0.25, Vector3(-6.55, 3.69, z), ROOF_MATERIAL, 0.072)
		ridge.rotation_degrees.z = 90.0
	_add_box(group, "WeatheredEaveFascia", Vector3(0.1, 0.15, 2.86), Vector3(-4.49, 3.275, BAY_CENTER_Z), WOOD_MATERIAL)
	for index in range(7):
		var z = 3.78 + index * 0.42
		var rafter = _add_box(group, "ExposedRafter_%02d" % index, Vector3(1.92, 0.075, 0.095), Vector3(-5.5, 3.31, z), WOOD_MATERIAL)
		rafter.rotation_degrees.z = -10.0


func _build_lantern(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "WeatheredPaperLantern_WithWoodFrame"
	add_child(group)
	# Hang the lantern against the plaster pier between the door and lattice,
	# rather than over the black door recess where its silhouette disappears.
	var p = Vector3(-4.78, 2.48, 5.02)
	_add_box(group, "HangingRod", Vector3(0.04, 0.42, 0.04), p + Vector3(0.0, 0.44, 0.0), materials.lantern_frame)
	# A single complete paper volume prevents oblique camera angles from exposing
	# gaps between separate faces. The thin wood strips below provide the frame.
	var paper_shade = _add_box(
		group, "CompleteAgedPaperShade", Vector3(0.34, 0.54, 0.34),
		p, materials.lantern_paper
	)
	paper_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light_core = _add_cylinder(
		group, "SmallInternalLightCore", 0.065, 0.34, p, materials.lantern_core
	)
	light_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [-0.32, 0.32]:
		_add_box(group, "LanternTopBottomFrame", Vector3(0.42, 0.045, 0.42), p + Vector3(0.0, y, 0.0), materials.lantern_frame)
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			_add_box(group, "LanternCornerFrame", Vector3(0.035, 0.66, 0.035), p + Vector3(x, 0.0, z), materials.lantern_frame)
	_add_box(group, "CourtyardPanelVerticalMullion", Vector3(0.025, 0.54, 0.026), p + Vector3(0.192, 0.0, 0.0), materials.lantern_frame)
	for y in [-0.17, 0.0, 0.17]:
		_add_box(group, "CourtyardPanelHorizontalMullion", Vector3(0.026, 0.025, 0.33), p + Vector3(0.192, y, 0.0), materials.lantern_frame)
	for side_z in [-0.192, 0.192]:
		_add_box(group, "SidePanelVerticalMullion", Vector3(0.025, 0.54, 0.025), p + Vector3(0.0, 0.0, side_z), materials.lantern_frame)
		for y in [-0.17, 0.0, 0.17]:
			_add_box(group, "SidePanelHorizontalMullion", Vector3(0.33, 0.025, 0.026), p + Vector3(0.0, y, side_z), materials.lantern_frame)
	_add_box(group, "PaperWaterStain", Vector3(0.012, 0.18, 0.11), p + Vector3(0.177, -0.16, 0.08), materials.lantern_stain)
	_add_box(group, "BottomTassel", Vector3(0.025, 0.28, 0.025), p + Vector3(0.0, -0.48, 0.0), materials.lantern_frame)
	lantern_light = OmniLight3D.new()
	lantern_light.name = "LocalizedWarmLanternLight_3m"
	lantern_light.position = p + Vector3(0.16, -0.05, 0.0)
	lantern_light.light_color = Color(1.0, 0.68, 0.39)
	lantern_light.light_energy = 1.28
	lantern_light.omni_range = 3.4
	lantern_light.omni_attenuation = 1.92
	lantern_light.shadow_enabled = true
	group.add_child(lantern_light)
	var cool_fill = OmniLight3D.new()
	cool_fill.name = "SubtleStormFill"
	cool_fill.position = Vector3(-4.62, 2.25, BAY_CENTER_Z)
	cool_fill.light_color = Color(0.3, 0.38, 0.46)
	cool_fill.light_energy = 0.82
	cool_fill.omni_range = 4.8
	cool_fill.omni_attenuation = 1.5
	group.add_child(cool_fill)
	var base_fill = OmniLight3D.new()
	base_fill.name = "VeryLowBayBaseFill"
	base_fill.position = Vector3(-4.62, 0.82, BAY_CENTER_Z)
	base_fill.light_color = Color(0.38, 0.42, 0.43)
	base_fill.light_energy = 0.62
	base_fill.omni_range = 2.8
	base_fill.omni_attenuation = 1.9
	base_fill.shadow_enabled = false
	group.add_child(base_fill)
	var roof_fill = OmniLight3D.new()
	roof_fill.name = "WetTileEdgeFill"
	roof_fill.position = Vector3(-4.48, 3.82, BAY_CENTER_Z)
	roof_fill.light_color = Color(0.32, 0.4, 0.48)
	roof_fill.light_energy = 0.52
	roof_fill.omni_range = 2.6
	roof_fill.omni_attenuation = 1.8
	roof_fill.shadow_enabled = false
	group.add_child(roof_fill)
	var facade_fill = SpotLight3D.new()
	facade_fill.name = "CourtyardSideFacadeFill"
	facade_fill.position = Vector3(-3.7, 2.35, BAY_CENTER_Z)
	facade_fill.light_color = Color(0.35, 0.42, 0.48)
	facade_fill.light_energy = 1.18
	facade_fill.spot_range = 5.2
	facade_fill.spot_angle = 50.0
	facade_fill.spot_attenuation = 1.45
	facade_fill.shadow_enabled = false
	group.add_child(facade_fill)
	facade_fill.look_at(Vector3(-6.28, 1.45, BAY_CENTER_Z), Vector3.UP)


func _build_props(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "AsymmetricBayProps"
	add_child(group)
	# Consolidate abandoned furniture below the broken-window side of the bay;
	# the doorway/threshold zone remains visually legible and physically clear.
	_build_jar(group, Vector3(-5.72, 0.49, 4.08), materials)
	# Keep a full capsule-width route between the courtyard step and the door.
	# The chair used to intrude into that route, so its solid legs could catch the
	# player even though the doorway itself still looked open.
	_build_crooked_chair(group, Vector3(-5.74, 0.58, 4.72))
	var board_a = _add_box(group, "LeaningBoardTall", Vector3(0.1, 1.38, 0.24), Vector3(-6.0, 1.0, 4.0), WOOD_MATERIAL)
	board_a.rotation_degrees = Vector3(-3.0, 12.0, -9.0)
	var board_b = _add_box(group, "LeaningBoardShort", Vector3(0.08, 1.12, 0.2), Vector3(-5.82, 0.86, 3.88), WOOD_MATERIAL)
	board_b.rotation_degrees = Vector3(2.0, -7.0, -7.0)
	for cluster in [Vector3(-4.7, 0.3, 3.91), Vector3(-6.06, 0.34, 4.85), Vector3(-4.68, 0.31, 6.1)]:
		_build_grass_cluster(group, cluster, materials.vegetation)
	for index in range(4):
		var shard = _add_box(group, "BrokenTile_%02d" % index, Vector3(0.2, 0.035, 0.1), Vector3(-4.68 - index * 0.12, 0.17, 4.3 + index * 0.17), ROOF_MATERIAL)
		shard.rotation_degrees = Vector3(0.0, index * 27.0, float(index % 2) * 6.0)


func _build_jar(parent: Node3D, position: Vector3, materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "WeatheredBrownGlazedJar_600mm"
	parent.add_child(group)
	_add_cylinder(group, "JarBody", 0.28, 0.50, position, materials.ceramic, 0.23)
	_add_cylinder(group, "JarShoulder", 0.235, 0.13, position + Vector3(0.0, 0.29, 0.0), materials.ceramic, 0.18)
	_add_cylinder(group, "JarNeck", 0.145, 0.10, position + Vector3(0.0, 0.39, 0.0), materials.ceramic, 0.14)
	_add_cylinder(group, "WornJarRim", 0.175, 0.05, position + Vector3(0.0, 0.46, 0.0), materials.ceramic_edge, 0.145)


func _build_crooked_chair(parent: Node3D, position: Vector3) -> void:
	var chair = Node3D.new()
	chair.name = "CrookedOldWoodChair"
	chair.position = position
	chair.rotation_degrees = Vector3(0.0, -16.0, 3.0)
	parent.add_child(chair)
	_add_box(chair, "Seat", Vector3(0.48, 0.08, 0.46), Vector3.ZERO, WOOD_MATERIAL)
	for x in [-0.19, 0.19]:
		for z in [-0.17, 0.17]:
			_add_box(chair, "Leg", Vector3(0.065, 0.52, 0.065), Vector3(x, -0.29, z), WOOD_MATERIAL)
	for z in [-0.19, 0.19]:
		_add_box(chair, "BackPost", Vector3(0.065, 0.72, 0.065), Vector3(-0.19, 0.38, z), WOOD_MATERIAL)
	_add_box(chair, "BackRail", Vector3(0.07, 0.11, 0.46), Vector3(-0.19, 0.58, 0.0), WOOD_MATERIAL)


func _build_grass_cluster(parent: Node3D, position: Vector3, material: Material) -> void:
	for index in range(5):
		var blade = _add_box(parent, "SparseWetWeed", Vector3(0.025, 0.36 + index * 0.045, 0.03), position + Vector3(float(index % 3) * 0.08, 0.0, float(index / 3) * 0.09), material)
		blade.rotation_degrees.z = -13.0 + index * 5.0


func _build_wet_age_details(materials: Dictionary) -> void:
	var group = Node3D.new()
	group.name = "WallRootDamp_Moss_AndDripMarks"
	add_child(group)
	_add_box(group, "WallRootBlackMud", Vector3(0.025, 0.34, 2.48), Vector3(WALL_X + 0.175, 0.47, BAY_CENTER_Z), materials.mud)
	for index in range(COLUMN_Z.size()):
		_add_cylinder(group, "ColumnFootMoss_%02d" % index, 0.155, 0.22, Vector3(COLUMN_X, 0.52, COLUMN_Z[index]), materials.mud)
	for data in [[0.82, 4.02, 0.55], [1.15, 5.12, 0.8], [0.72, 6.08, 0.48]]:
		_add_box(group, "IrregularRainStain", Vector3(0.025, float(data[2]), 0.11), Vector3(WALL_X + 0.178, float(data[0]), float(data[1])), materials.mud)

	# The entrance-facing return used to read as a clean beige slab under the
	# flashlight. Layered damp, exposed substrate, rain streaks and hairline
	# cracking give it the same restrained decay language as the right wing.
	var return_surface_z = 6.492
	for data in [[-6.02, 1.92, 0.055, 0.94], [-5.56, 1.80, 0.045, 0.68], [-5.24, 2.22, 0.038, 0.55]]:
		_add_box(
			group, "NearReturnVerticalRainStreak",
			Vector3(float(data[2]), float(data[3]), 0.018),
			Vector3(float(data[0]), float(data[1]), return_surface_z + 0.031),
			materials.mud
		)
	for data in [[-5.88, 1.18, 0.31, 19.0], [-5.74, 1.43, 0.27, -14.0], [-5.47, 2.26, 0.24, 11.0]]:
		var crack = _add_box(
			group, "NearReturnHairlineCrack",
			Vector3(0.018, float(data[2]), 0.014),
			Vector3(float(data[0]), float(data[1]), return_surface_z + 0.043),
			materials.dark_recess
		)
		crack.rotation_degrees.z = float(data[3])


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, rotation = Vector3.ZERO) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, top_radius = -1.0) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 3
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _make_material(color: Color, roughness: float, metallic = 0.0, emission = Color(0, 0, 0, 1), emission_energy = 1.0) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission.r + emission.g + emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material
