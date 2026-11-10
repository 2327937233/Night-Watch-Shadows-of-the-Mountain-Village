extends "res://scripts/left_wing_interior.gd"

const MAIN_HALL_PATH := "res://scenes/InteriorPlaceholder.tscn"
const ROOM_X_LIMIT := 2.68
const ROOM_NEAR_Z := 7.30
const ROOM_FAR_Z := -8.95
const GENEALOGY_POS := Vector3(-0.18, 0.98, -1.08)
const DRAWER_POS := Vector3(0.76, 0.68, -0.58)
const TORN_PAGE_POS := Vector3(1.80, 0.055, -4.62)
const LETTER_POS := Vector3(0.48, 0.82, -0.44)
const KEY_POS := Vector3(1.02, 0.84, -0.48)
const LOCKED_BOX_POS := Vector3(-1.65, 0.34, -7.34)

var genealogy_visual: Node3D
var torn_page_visual: Node3D
var old_letter_visual: Node3D
var copper_key_visual: Node3D
var desk_drawer: Node3D
var falling_book: Node3D
var book_drop_audio: AudioStreamPlayer3D
var distant_door_audio: AudioStreamPlayer
var paper_audio: AudioStreamPlayer
var interaction_busy := false:
	set(value):
		interaction_busy = value
		if is_inside_tree():
			GameState.set_night_clock_hold(self, value)
var next_creak_at := 0.0


func _ready() -> void:
	super._ready()
	_finish_old_letter_reading()


func _state() -> Node:
	return get_node("/root/GameState")


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "StudyLowExposureEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.008, 0.011)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.235, 0.265, 0.305)
	env.ambient_light_energy = 1.18
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.052, 0.061, 0.071)
	env.fog_light_energy = 0.25
	env.fog_density = 0.011
	env.fog_height = 0.75
	env.fog_height_density = 0.22
	world.environment = env
	add_child(world)


func _build_room() -> void:
	var room := Node3D.new()
	room.name = "WangStudyRoom"
	add_child(room)
	var architecture := _module(room, "Architecture")
	var furniture := _module(room, "Furniture")
	var story_items := _module(room, "StoryItems")
	var props := _module(room, "Props")
	var lighting := _module(room, "Lighting")
	var atmosphere := _module(room, "Atmosphere")
	var plaster := (load("res://materials/architecture/interior_ritual_plaster.tres") as Material).duplicate(true)
	var wood := (load("res://materials/architecture/wet_old_wood.tres") as Material).duplicate(true)
	var desk_wood := (wood as Material).duplicate(true)
	var shelf_wood := (wood as Material).duplicate(true)
	var floor_mat := (load("res://materials/ground/interior_wet_brick.tres") as Material).duplicate(true)
	if plaster is ShaderMaterial:
		plaster.set_shader_parameter("world_tile_scale", Vector2(0.27, 0.34))
		plaster.set_shader_parameter("plaster_tint", Color(0.49, 0.465, 0.405, 1.0))
		plaster.set_shader_parameter("damp_tint", Color(0.105, 0.115, 0.105, 1.0))
		plaster.set_shader_parameter("albedo_gain", 1.02)
		plaster.set_shader_parameter("minimum_base_brightness", 0.48)
		plaster.set_shader_parameter("weathering_strength", 0.37)
		plaster.set_shader_parameter("root_dampness", 0.58)
	if wood is ShaderMaterial:
		wood.set_shader_parameter("uv_repeat", Vector2(1.22, 2.65))
		wood.set_shader_parameter("material_tint", Color(0.34, 0.25, 0.18, 1.0))
		wood.set_shader_parameter("normal_strength", 0.72)
		wood.set_shader_parameter("wetness_amount", 0.38)
	if desk_wood is ShaderMaterial:
		desk_wood.set_shader_parameter("uv_repeat", Vector2(1.55, 1.10))
		desk_wood.set_shader_parameter("material_tint", Color(0.46, 0.32, 0.21, 1.0))
		desk_wood.set_shader_parameter("albedo_gain", 1.02)
		desk_wood.set_shader_parameter("wetness_amount", 0.22)
		desk_wood.set_shader_parameter("roughness_floor", 0.76)
	if shelf_wood is ShaderMaterial:
		shelf_wood.set_shader_parameter("uv_repeat", Vector2(1.05, 2.10))
		shelf_wood.set_shader_parameter("material_tint", Color(0.39, 0.28, 0.19, 1.0))
		shelf_wood.set_shader_parameter("albedo_gain", 1.03)
		shelf_wood.set_shader_parameter("wetness_amount", 0.29)
	if floor_mat is ShaderMaterial:
		floor_mat.set_shader_parameter("tile_repeat", Vector2(1.16, 1.04))
		floor_mat.set_shader_parameter("brick_tint", Color(0.40, 0.435, 0.44, 1.0))
		floor_mat.set_shader_parameter("normal_strength", 0.82)
		floor_mat.set_shader_parameter("wetness_amount", 0.36)
	var mats := {
		"plaster": plaster,
		"wood": wood,
		"desk_wood": desk_wood,
		"shelf_wood": shelf_wood,
		"floor": floor_mat,
		"dark_wood": _material(Color(0.068, 0.045, 0.030), 0.84),
		"deep_wood": _material(Color(0.043, 0.030, 0.022), 0.92),
		"damp": _material(Color(0.020, 0.028, 0.029), 0.97),
		"paper": _material(Color(0.48, 0.39, 0.24), 0.98),
		"old_paper": _material(Color(0.33, 0.255, 0.135), 0.98),
		"linen": _material(Color(0.24, 0.205, 0.145), 0.97),
		"thread": _material(Color(0.17, 0.135, 0.085), 0.96),
		"indigo": _material(Color(0.055, 0.075, 0.091), 0.88),
		"faded_blue": _material(Color(0.085, 0.095, 0.097), 0.92),
		"faded_brown": _material(Color(0.145, 0.095, 0.055), 0.94),
		"ink": _material(Color(0.032, 0.026, 0.022), 0.94),
		"bronze": _material(Color(0.13, 0.09, 0.045), 0.62),
		"ceramic": _material(Color(0.055, 0.061, 0.058), 0.75),
		"talisman": _material(Color(0.40, 0.29, 0.075), 0.97),
		"cinnabar": _material(Color(0.20, 0.030, 0.018), 0.94),
		"wax": _material(Color(0.31, 0.14, 0.055), 0.86),
	}
	(mats.bronze as StandardMaterial3D).metallic = 0.22
	_build_architecture(architecture, mats)
	_build_main_desk(furniture, story_items, mats)
	_build_bookshelves(furniture, props, mats)
	_build_rear_archive(furniture, props, story_items, mats)
	_build_story_items(story_items, mats)
	_build_sparse_props(props, mats)
	_build_study_lighting(lighting, mats)
	_build_study_air(atmosphere)
	_build_study_audio()


func _module(parent: Node3D, module_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = module_name
	parent.add_child(node)
	return node


func _build_architecture(root: Node3D, mats: Dictionary) -> void:
	_add_box(root, "StudyFloorCollision", Vector3(6.35, 0.18, 17.4), Vector3(0.0, -0.10, -1.0), mats.damp, true)
	var tile := BoxMesh.new()
	tile.size = Vector3(0.73, 0.038, 0.86)
	tile.material = mats.floor
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tile
	mm.instance_count = 8 * 19
	for zi in range(19):
		for xi in range(8):
			var i := zi * 8 + xi
			var seed := (i * 11 + zi * 5) % 7
			var x := -2.56 + xi * 0.73 + (0.035 if zi % 2 else 0.0)
			var z := 6.92 - zi * 0.86
			var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(float(seed - 3) * 0.28), 0.0))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.008 + (seed % 3) * 0.0016, z)))
	var tiles := MultiMeshInstance3D.new()
	tiles.name = "WornStudyBrickFloor_MultiMesh"
	tiles.multimesh = mm
	root.add_child(tiles)
	_add_box(root, "LeftThickArchiveWall", Vector3(0.34, 3.65, 17.5), Vector3(-3.08, 1.78, -1.0), mats.plaster, true)
	_add_box(root, "RightThickArchiveWall", Vector3(0.34, 3.65, 17.5), Vector3(3.08, 1.78, -1.0), mats.plaster, true)
	_add_box(root, "RearDampArchiveWall", Vector3(6.45, 3.65, 0.36), Vector3(0.0, 1.78, -9.42), mats.plaster, true)
	_add_box(root, "StudyCeilingMass", Vector3(6.4, 0.14, 17.4), Vector3(0.0, 3.69, -1.0), mats.shelf_wood)
	for z in [6.75, 3.85, 0.95, -1.95, -4.85, -7.75, -9.18]:
		_add_box(root, "BlackenedCrossBeam", Vector3(6.4, 0.28, 0.34), Vector3(0.0, 3.43, z), mats.dark_wood)
		for x in [-2.80, 2.80]:
			_add_box(root, "OldLoadPost", Vector3(0.30, 3.52, 0.30), Vector3(x, 1.76, z), mats.wood, true)
	for x in [-2.2, -1.1, 0.0, 1.1, 2.2]:
		_add_box(root, "RoofPurlin", Vector3(0.17, 0.15, 17.0), Vector3(x, 3.57, -1.0), mats.wood)
	# Proper entrance thickness keeps the room from reading as a black box.
	for x in [-2.05, 2.05]:
		_add_box(root, "EntranceWallMass", Vector3(2.10, 3.60, 0.34), Vector3(x, 1.76, 7.55), mats.plaster, true)
		_add_box(root, "EntranceDoorJamb", Vector3(0.30, 3.25, 0.40), Vector3(signf(x) * 1.17, 1.62, 7.38), mats.wood)
	_add_box(root, "EntranceHeavyLintel", Vector3(2.65, 0.30, 0.42), Vector3(0.0, 3.22, 7.38), mats.dark_wood)
	# Damp blooms and revealed timber structure; small, asymmetric overlays avoid tiling.
	var mould := _material(Color(0.028, 0.044, 0.041, 0.48), 0.98)
	mould.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var earth := _material(Color(0.12, 0.095, 0.067), 0.96)
	for side in [-1.0, 1.0]:
		for data in [[5.4, 0.55, 0.74], [1.8, 1.35, 0.52], [-2.4, 0.72, 0.88], [-6.4, 1.72, 0.62]]:
			_add_box(root, "IrregularStudyMould", Vector3(0.035, float(data[2]), 0.94), Vector3(side * 2.89, float(data[1]), float(data[0])), mould)
		for y in [0.52, 2.84]:
			_add_box(root, "VisibleWallTimberRail", Vector3(0.18, 0.14, 16.55), Vector3(side * 2.87, y, -0.90), mats.wood)
	for data in [[-2.87,1.62,3.2], [2.87,1.08,-0.8], [-2.87,1.02,-6.8]]:
		var patch := _add_box(root, "PeelingPlasterEarthLayer", Vector3(0.04, 0.86, 1.08), Vector3(float(data[0]), float(data[1]), float(data[2])), earth)
		patch.rotation_degrees.x = float(data[2]) * 1.2
	# Traditional lattice window and shallow rain-night exterior recess.
	_add_box(root, "WindowColdRecess", Vector3(0.09, 1.92, 1.42), Vector3(2.89, 1.95, -6.72), mats.deep_wood)
	for y in [1.10, 1.58, 2.06, 2.54, 2.94]:
		_add_box(root, "WindowHorizontalLattice", Vector3(0.10, 0.055, 1.45), Vector3(2.82, y, -6.72), mats.wood)
	for z in [-7.25, -6.90, -6.55, -6.20]:
		_add_box(root, "WindowVerticalLattice", Vector3(0.10, 1.92, 0.055), Vector3(2.82, 1.95, z), mats.wood)
	# Restricted damp sheen near the window, not a mirror floor.
	var wet := _material(Color(0.075, 0.097, 0.105, 0.25), 0.25)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for data in [[2.20,-6.25,0.62,1.28], [1.72,-7.45,0.44,0.85], [-2.15,4.6,0.38,0.70]]:
		_add_box(root, "LocalIndoorDampSheen", Vector3(float(data[2]), 0.008, float(data[3])), Vector3(float(data[0]), 0.035, float(data[1])), wet)


func _build_main_desk(root: Node3D, story_root: Node3D, mats: Dictionary) -> void:
	var desk := Node3D.new()
	desk.name = "MainInvestigationDesk"
	root.add_child(desk)
	_add_box(desk, "ThickWornWritingTop", Vector3(2.40, 0.18, 1.48), Vector3(0.0, 0.91, -1.10), mats.desk_wood, true)
	_add_box(desk, "DeskFrontApron", Vector3(2.18, 0.38, 0.16), Vector3(0.0, 0.70, -0.38), mats.desk_wood, true)
	_add_box(desk, "DeskFrontShadowRebate", Vector3(2.22, 0.035, 0.035), Vector3(0.0, 0.51, -0.28), mats.deep_wood)
	for x in [-1.04, 1.04]:
		_add_box(desk, "WornEdgeCap", Vector3(0.045, 0.19, 1.50), Vector3(x, 0.91, -1.10), mats.dark_wood)
	for z in [-1.82, -0.38]:
		_add_box(desk, "WornDesktopLip", Vector3(2.34, 0.045, 0.045), Vector3(0.0, 0.99, z), mats.dark_wood)
	for x in [-0.65, 0.0, 0.65]:
		_add_box(desk, "OldApronPanelGroove", Vector3(0.022, 0.28, 0.012), Vector3(x, 0.71, -0.289), mats.deep_wood)
	# Joinery sits proud of the apron; the working drawer keeps its original travel.
	for data in [[-0.72, 0.60], [-0.04, 0.64]]:
		var x := float(data[0])
		var span := float(data[1])
		_add_box(desk, "RecessedWritingDeskPanel", Vector3(span, 0.25, 0.024), Vector3(x, 0.71, -0.286), mats.dark_wood)
		for y in [0.61, 0.81]:
			_add_box(desk, "ApronWornBead", Vector3(span - 0.05, 0.025, 0.029), Vector3(x, y, -0.269), mats.desk_wood)
		for edge in [-1.0, 1.0]:
			_add_box(desk, "ApronPanelMitre", Vector3(0.025, 0.22, 0.029), Vector3(x + edge * (span * 0.5 - 0.027), 0.71, -0.269), mats.desk_wood)
	for x in [-0.96, 0.96]:
		for z in [-1.62, -0.58]:
			_add_box(desk, "DeskSquareLeg", Vector3(0.25, 0.88, 0.25), Vector3(x, 0.44, z), mats.desk_wood, true)
			_add_box(desk, "DarkWornFoot", Vector3(0.253, 0.09, 0.253), Vector3(x, 0.055, z), mats.dark_wood)
	_add_box(desk, "DeskLowerStretcher", Vector3(1.78, 0.13, 0.18), Vector3(0.0, 0.30, -1.48), mats.desk_wood)
	# The right drawer is a separately animated real volume, not a texture.
	desk_drawer = Node3D.new()
	desk_drawer.name = "JammedRightDrawer"
	desk_drawer.position = Vector3(0.76, 0.68, -0.46 if _state().study_drawer_open else -0.86)
	desk.add_child(desk_drawer)
	_add_box(desk_drawer, "DrawerBody", Vector3(0.66, 0.28, 0.58), Vector3.ZERO, mats.desk_wood)
	_add_box(desk_drawer, "DrawerFrontInset", Vector3(0.52, 0.19, 0.018), Vector3(0.0, 0.0, 0.304), mats.dark_wood)
	_add_cylinder(desk_drawer, "OxidizedDrawerPull", 0.055, 0.055, Vector3(0.0, 0.0, 0.31), mats.bronze)
	# One quiet chair and footstool retain a believable working arrangement.
	_add_box(root, "OldScholarChairSeat", Vector3(1.02, 0.14, 0.86), Vector3(0.0, 0.55, -2.40), mats.wood, true)
	for x in [-0.42, 0.42]:
		_add_box(root, "ScholarChairBackPost", Vector3(0.14, 1.42, 0.14), Vector3(x, 1.22, -2.72), mats.dark_wood)
	_add_box(root, "ScholarChairBackRail", Vector3(0.98, 0.34, 0.12), Vector3(0.0, 1.52, -2.72), mats.wood)
	for x in [-0.40, 0.40]:
		for z in [-2.68, -2.12]:
			_add_box(root, "ScholarChairLeg", Vector3(0.14, 0.58, 0.14), Vector3(x, 0.29, z), mats.dark_wood)
	# Desk props are intentionally clustered, leaving visible negative space.
	_add_cylinder(root, "InkStoneWell", 0.19, 0.055, Vector3(0.79, 1.04, -1.32), mats.ink)
	_add_box(root, "HalfUsedInkBlock", Vector3(0.13, 0.035, 0.08), Vector3(0.86, 1.035, -1.03), mats.ink)
	_add_cylinder(root, "OldCeramicBrushCup", 0.13, 0.34, Vector3(0.91, 1.16, -1.57), mats.ceramic)
	for i in range(4):
		var brush := _add_cylinder(root, "DryWritingBrush", 0.014, 0.52 + i * 0.025, Vector3(0.84 + i * 0.052, 1.52, -1.57), mats.dark_wood)
		brush.rotation_degrees.z = -5.0 + i * 4.0
	for data in [[-0.83,-1.48,0.36,0.25,-6.0], [0.58,-0.70,0.46,0.31,4.0]]:
		var paper := _add_box(root, "InterruptedLedgerPaper", Vector3(float(data[2]), 0.012, float(data[3])), Vector3(float(data[0]), 1.02, float(data[1])), mats.paper)
		paper.rotation_degrees.y = float(data[4])
	# Small, irregular work clusters leave the open genealogy legible in the center.
	for data in [[-0.83, -1.53, -6.0], [0.48, -1.53, 9.0]]:
		for layer in range(3):
			var old_book := _add_box(root, "ClosedThreadBoundRegister", Vector3(0.39 - layer * 0.015, 0.045, 0.28), Vector3(float(data[0]), 1.045 + layer * 0.046, float(data[1])), mats.faded_blue if layer == 1 else mats.old_paper)
			old_book.rotation_degrees.y = float(data[2]) + layer * 2.0
	for roll in range(2):
		var scroll := _add_cylinder(root, "HalfUnrolledArchiveScroll", 0.045, 0.48, Vector3(-0.77 + roll * 0.10, 1.075, -0.63), mats.paper)
		scroll.rotation_degrees.z = 91.0
	_add_box(root, "SmallDeskDocumentBox", Vector3(0.34, 0.16, 0.27), Vector3(0.80, 1.09, -0.65), mats.dark_wood)
	_add_box(root, "DocumentBoxRaisedLid", Vector3(0.35, 0.045, 0.29), Vector3(0.80, 1.18, -0.70), mats.desk_wood)


func _build_bookshelves(root: Node3D, props: Node3D, mats: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		for z_center in [2.25, -2.50, -6.15]:
			_build_bookshelf(root, props, side, z_center, mats)


func _build_bookshelf(root: Node3D, props: Node3D, side: float, z_center: float, mats: Dictionary) -> void:
	var x := side * 2.54
	var shelf := Node3D.new()
	shelf.name = ("Left" if side < 0 else "Right") + "SolidArchiveShelf"
	root.add_child(shelf)
	_add_box(shelf, "ShelfBackBoard", Vector3(0.18, 2.70, 3.46), Vector3(x, 1.48, z_center), mats.deep_wood, true)
	for edge in [-1.0, 1.0]:
		_add_box(shelf, "ShelfSideFrame", Vector3(0.40, 2.86, 0.20), Vector3(x - side * 0.14, 1.48, z_center + edge * 1.69), mats.shelf_wood, true)
		_add_box(shelf, "WornFrontStile", Vector3(0.085, 2.83, 0.085), Vector3(x - side * 0.38, 1.48, z_center + edge * 1.68), mats.dark_wood)
	for level in range(6):
		var y := 0.18 + level * 0.50
		_add_box(shelf, "WarpedShelfBoard", Vector3(0.52, 0.095, 3.36), Vector3(x - side * 0.17, y, z_center), mats.shelf_wood)
		_add_box(shelf, "DarkUndersideShelfLip", Vector3(0.047, 0.025, 3.27), Vector3(x - side * 0.455, y - 0.030, z_center), mats.dark_wood)
	for z_divider in [-0.53, 0.60]:
		_add_box(shelf, "ArchiveBayDivider", Vector3(0.30, 2.65, 0.075), Vector3(x - side * 0.16, 1.48, z_center + z_divider), mats.shelf_wood)
	# Five distinct spine widths and inconsistent empty bays break the former regular cuboid pattern.
	var book_colors := [Color("#343d44"), Color("#645341"), Color("#4a5051"), Color("#513628"), Color("#625744")]
	for variant in range(5):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.28, 0.31 + variant * 0.027, 0.046 + variant * 0.008)
		var book_material := ShaderMaterial.new()
		book_material.shader = preload("res://shaders/archive_book.gdshader")
		book_material.set_shader_parameter("cover_tint", book_colors[variant])
		book_material.set_shader_parameter("half_extents", mesh.size * 0.5)
		book_material.set_shader_parameter("right_shelf", side > 0.0)
		mesh.material = book_material
		var placements: Array[Transform3D] = []
		for level in range(5):
			for bay in range(3):
				if (level * 3 + bay * 2 + int(absf(z_center))) % 7 == 0:
					continue
				var count := 2 + (level * 7 + bay * 3 + int(absf(z_center) * 2.0) + (1 if side > 0.0 else 0)) % 4
				for i in range(count):
					if (i * 3 + level + bay + int(absf(z_center))) % 5 != variant:
						continue
					var z := z_center - 1.43 + bay * 1.08 + i * 0.081 + (level % 2) * 0.025
					var height_scale := 0.81 + float((i * 13 + level * 5 + bay * 3) % 7) * 0.028
					var height := mesh.size.y * height_scale
					var y := 0.18 + level * 0.50 + 0.048 + height * 0.5
					var tilt := deg_to_rad(float((level * 11 + bay * 7 + i * 5 + variant * 3) % 9 - 4) * 1.45)
					var basis := Basis.from_euler(Vector3(tilt, 0.0, 0.0)).scaled_local(Vector3(1.0, height_scale, 1.0))
					placements.append(Transform3D(basis, Vector3(x - side * (0.26 + 0.014 * float(i % 3)), y, z)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = placements.size()
		for i in range(placements.size()):
			mm.set_instance_transform(i, placements[i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "IrregularClothBoundVolume%d_MultiMesh" % variant
		batch.multimesh = mm
		props.add_child(batch)
	# Different archival forms fill only part of each bay: stitched ledgers, scrolls and tied packets.
	for level in range(1, 5):
		var bay := (level + int(absf(z_center))) % 3
		var stack_z := z_center - 1.08 + bay * 1.06
		if level % 2 == 0:
			for layer in range(2 + level % 3):
				var ledger := _add_box(shelf, "UnevenHorizontalLedger", Vector3(0.31, 0.047, 0.42 - layer * 0.025), Vector3(x - side * 0.27, 0.18 + level * 0.50 + 0.075 + layer * 0.050, stack_z), mats.old_paper if layer % 2 == 0 else mats.faded_blue)
				ledger.rotation_degrees.y = float(layer * 3 - 4)
		else:
			for roll in range(3):
				var scroll := _add_cylinder(shelf, "BoundArchiveScroll", 0.050 + roll * 0.006, 0.29, Vector3(x - side * 0.27, 0.18 + level * 0.50 + 0.10 + roll * 0.095, stack_z + roll * 0.11), mats.paper if roll == 1 else mats.old_paper)
				scroll.rotation_degrees.z = 90.0
		_add_box(shelf, "FadedRegisterLabel", Vector3(0.012, 0.19, 0.075), Vector3(x - side * 0.478, 0.18 + level * 0.50 + 0.23, stack_z - 0.32), mats.paper)
	var parcel_z := z_center + (0.95 if side < 0.0 else -0.90)
	_add_box(shelf, "StringTiedArchivePacket", Vector3(0.28, 0.23, 0.47), Vector3(x - side * 0.27, 0.35, parcel_z), mats.linen)
	_add_box(shelf, "PacketCord", Vector3(0.29, 0.018, 0.02), Vector3(x - side * 0.27, 0.48, parcel_z), mats.thread)
	_add_box(shelf, "SmallBoxAmongRegisters", Vector3(0.29, 0.27, 0.48), Vector3(x - side * 0.27, 2.91, z_center - 0.88), mats.dark_wood)
	for data in [["旧账", 1.42, -1.29], ["族录", 2.42, 0.91]]:
		_add_box(shelf, "AgeStainedArchiveSpineLabel", Vector3(0.011, 0.25, 0.068), Vector3(x - side * 0.47, float(data[1]), z_center + float(data[2])), mats.old_paper)
		_add_vertical_label(shelf, str(data[0]), Vector3(x - side * 0.481, float(data[1]), z_center + float(data[2])), 0.00074, Color(0.10, 0.075, 0.045, 0.90), Vector3(0.0, -side * 90.0, 0.0))
	# The marked falling book belongs to the middle right shelf.
	if side > 0.0 and is_equal_approx(z_center, -2.50):
		falling_book = Node3D.new()
		falling_book.name = "BookThatFallsAfterGenealogy"
		falling_book.position = Vector3(2.22, 1.84, -4.20) if not _state().study_book_dropped else Vector3(1.80, 0.12, -4.62)
		root.add_child(falling_book)
		var book_mesh := _add_box(falling_book, "LooseIndigoRegister", Vector3(0.40, 0.12, 0.58), Vector3.ZERO, mats.indigo)
		book_mesh.rotation_degrees.y = -8.0
		if _state().study_book_dropped:
			falling_book.rotation_degrees = Vector3(0.0, -18.0, 9.0)


func _build_rear_archive(root: Node3D, props: Node3D, story_root: Node3D, mats: Dictionary) -> void:
	_add_box(root, "RearArchiveCabinet", Vector3(2.55, 1.55, 0.72), Vector3(0.15, 0.78, -8.88), mats.shelf_wood, true)
	for x in [-0.72, 0.15, 1.02]:
		_add_box(root, "CabinetPanel", Vector3(0.70, 1.20, 0.055), Vector3(x, 0.76, -8.48), mats.desk_wood)
		_add_box(root, "RecessedCabinetPanel", Vector3(0.56, 0.98, 0.014), Vector3(x, 0.76, -8.44), mats.dark_wood)
		_add_cylinder(root, "CabinetOldPull", 0.036, 0.05, Vector3(x, 0.78, -8.43), mats.bronze)
	for y in [0.11, 1.43]:
		_add_box(root, "WornCabinetHorizontalRail", Vector3(2.60, 0.095, 0.08), Vector3(0.15, y, -8.46), mats.desk_wood)
	# Damp landscape scroll is a subdued rear compositional anchor.
	_add_box(root, "WaterDamagedScrollPaper", Vector3(2.70, 1.42, 0.035), Vector3(-0.15, 2.55, -9.20), mats.old_paper)
	_build_faded_ink_landscape(root)
	_add_box(root, "ScrollTopRod", Vector3(3.02, 0.08, 0.08), Vector3(-0.15, 3.31, -9.18), mats.wood)
	_add_box(root, "ScrollBottomRod", Vector3(3.02, 0.08, 0.08), Vector3(-0.15, 1.79, -9.18), mats.wood)
	# Small document coffer, intentionally not a gamey treasure chest.
	_add_box(root, "LockedDocumentCoffer", Vector3(1.14, 0.60, 0.72), LOCKED_BOX_POS, mats.dark_wood, true)
	_add_box(root, "CofferLid", Vector3(1.18, 0.13, 0.76), LOCKED_BOX_POS + Vector3(0, 0.36, 0), mats.wood)
	_add_box(root, "CofferOxidizedLock", Vector3(0.18, 0.26, 0.06), LOCKED_BOX_POS + Vector3(0, 0.08, 0.39), mats.bronze)


func _build_faded_ink_landscape(root: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.66, 0.56, 0.39, 0.84)
	material.albedo_texture = load("res://assets/art/study_faded_landscape.svg") as Texture2D
	material.roughness = 0.96
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(2.62, 1.34)
	quad.material = material
	var painting := MeshInstance3D.new()
	painting.name = "WaterDamagedInkLandscapeFace"
	painting.mesh = quad
	painting.position = Vector3(-0.15, 2.55, -9.165)
	painting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(painting)


func _build_story_items(root: Node3D, mats: Dictionary) -> void:
	genealogy_visual = Node3D.new()
	genealogy_visual.name = "WangGenealogyInteraction"
	genealogy_visual.position = GENEALOGY_POS
	genealogy_visual.rotation_degrees.y = -3.5
	root.add_child(genealogy_visual)
	# An open, handled genealogy makes the desk's clue readable from the doorway.
	for side in [-1.0, 1.0]:
		var cover := _add_box(genealogy_visual, "SpreadIndigoClothCover", Vector3(0.44, 0.045, 0.61), Vector3(side * 0.225, 0.032, 0.0), mats.indigo)
		cover.rotation_degrees.z = side * 2.2
		var pages := _add_box(genealogy_visual, "WaterStainedOpenPages", Vector3(0.405, 0.045, 0.565), Vector3(side * 0.215, 0.073, 0.0), mats.paper)
		pages.rotation_degrees.z = side * 2.2
		for column in range(3):
			var ink_x := float(side) * 0.22 + (column - 1) * 0.098
			var text_line: String = ["世系旧录", "王氏历代之记", "婚嗣并载"][column] if side < 0.0 else ["其妻姓名", "旧录已佚", "此页有改"][column]
			_add_vertical_label(genealogy_visual, text_line, Vector3(ink_x, 0.116, 0.025), 0.00135, Color(0.19, 0.125, 0.081, 0.71), Vector3(-90, 0, 0))
	_add_box(genealogy_visual, "CrackedBookSpine", Vector3(0.052, 0.061, 0.61), Vector3(0.0, 0.040, 0.0), mats.faded_brown)
	for z in [-0.22, -0.08, 0.08, 0.22]:
		_add_box(genealogy_visual, "VisibleStitchedBinding", Vector3(0.055, 0.007, 0.015), Vector3(0.0, 0.079, z), mats.thread)
	_add_box(genealogy_visual, "DeliberatelyErasedName", Vector3(0.033, 0.005, 0.12), Vector3(0.123, 0.124, 0.158), mats.ink)
	# Residual page remains hidden beneath the book until the anomaly fires.
	torn_page_visual = Node3D.new()
	torn_page_visual.name = "TornGenealogyPageInteraction"
	torn_page_visual.position = TORN_PAGE_POS
	torn_page_visual.rotation_degrees.y = 11.0
	root.add_child(torn_page_visual)
	_add_box(torn_page_visual, "WormEatenTornPage", Vector3(0.62, 0.012, 0.45), Vector3.ZERO, mats.paper)
	for z in [-0.13, 0.0, 0.13]:
		_add_box(torn_page_visual, "FadedPageText", Vector3(0.36, 0.006, 0.016), Vector3(0.02, 0.011, z), mats.ink)
	torn_page_visual.visible = _state().study_book_dropped and not _state().has_item("torn_genealogy_page")
	old_letter_visual = Node3D.new()
	old_letter_visual.name = "OldLetterInteraction"
	old_letter_visual.position = LETTER_POS
	root.add_child(old_letter_visual)
	_add_box(old_letter_visual, "FoldedServantLetter", Vector3(0.48, 0.025, 0.34), Vector3.ZERO, mats.paper)
	_add_cylinder(old_letter_visual, "DarkWaxLetterSeal", 0.06, 0.025, Vector3(0.06, 0.027, 0.0), mats.cinnabar)
	old_letter_visual.visible = _state().study_drawer_open and not _state().has_item("old_servant_letter")
	copper_key_visual = Node3D.new()
	copper_key_visual.name = "OldCopperKeyInteraction"
	copper_key_visual.position = KEY_POS
	copper_key_visual.rotation_degrees.y = -18.0
	root.add_child(copper_key_visual)
	_add_cylinder(copper_key_visual, "OldKeyBow", 0.095, 0.024, Vector3(-0.16, 0.02, 0), mats.bronze)
	_add_box(copper_key_visual, "LongKeyShaft", Vector3(0.34, 0.025, 0.038), Vector3(0.07, 0.02, 0), mats.bronze)
	_add_box(copper_key_visual, "UnevenKeyTooth", Vector3(0.06, 0.025, 0.10), Vector3(0.22, 0.02, 0.03), mats.bronze)
	copper_key_visual.visible = _state().study_drawer_open and _state().study_letter_read and not _state().has_item("study_old_copper_key")
	# Sparse warding papers imply intentional archival sealing, not a second ritual room.
	for data in [[-2.73,1.75,2.70,-4.0], [2.73,2.10,-1.65,3.0], [-1.72,0.82,-8.45,-5.0], [1.88,1.36,-8.43,4.0], [0.92,2.45,7.34,-2.0]]:
		var talisman := _add_box(root, "SparseArchiveWardingTalisman", Vector3(0.014, 0.46, 0.18), Vector3(float(data[0]), float(data[1]), float(data[2])), mats.talisman)
		talisman.rotation_degrees.z = float(data[3])


func _add_vertical_label(root: Node3D, text_value: String, position: Vector3, pixel_size: float, color: Color, rotation: Vector3) -> void:
	var chars := PackedStringArray()
	for i in range(text_value.length()):
		chars.append(text_value.substr(i, 1))
	var label := Label3D.new()
	label.name = "HandWrittenChineseLabel"
	label.text = "\n".join(chars)
	label.font = load("res://assets/fonts/watchnight_chinese.tres") as Font
	label.font_size = 36
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_modulate = Color(0.02, 0.012, 0.008, 0.7)
	label.outline_size = 2
	label.position = position
	label.rotation_degrees = rotation
	root.add_child(label)


func _build_sparse_props(root: Node3D, mats: Dictionary) -> void:
	for data in [[-2.22,5.0,0.82,0.58], [2.18,3.95,0.66,0.48]]:
		_add_box(root, "ArchivePaperParcel", Vector3(float(data[2]), 0.26, float(data[3])), Vector3(float(data[0]), 0.16, float(data[1])), mats.old_paper)
	_add_cylinder(root, "CrackedInkWashJar", 0.28, 0.58, Vector3(-2.36, 0.29, -7.45), mats.ceramic, true)
	_add_box(root, "LowInvestigationStool", Vector3(0.68, 0.13, 0.60), Vector3(-1.42, 0.48, 0.75), mats.wood, true)
	for x in [-1.68, -1.16]:
		for z in [0.50, 1.0]:
			_add_box(root, "StoolLeg", Vector3(0.11, 0.48, 0.11), Vector3(x, 0.24, z), mats.dark_wood)
	# Only a handful of loose pages, concentrated by shelves.
	for data in [[-2.15,3.25,-8.0], [2.05,1.64,12.0], [2.26,-5.30,-4.0], [-2.20,-7.90,7.0], [1.75,-7.28,18.0]]:
		var page := _add_box(root, "NaturallyScatteredArchivePage", Vector3(0.48, 0.009, 0.34), Vector3(float(data[0]), 0.048, float(data[1])), mats.paper)
		page.rotation_degrees.y = float(data[2])


func _build_study_lighting(root: Node3D, mats: Dictionary) -> void:
	_add_candle(root, Vector3(-0.94, 1.03, -0.75), mats.wax, mats.bronze, 0.91)
	_add_candle(root, Vector3(0.98, 1.60, -8.72), mats.wax, mats.bronze, 0.46)
	var desk_focus := OmniLight3D.new()
	desk_focus.name = "WarmDeskInvestigationPool"
	desk_focus.position = Vector3(-0.75, 1.50, -0.82)
	desk_focus.light_color = Color(0.93, 0.50, 0.22)
	desk_focus.light_energy = 1.30
	desk_focus.omni_range = 4.35
	desk_focus.omni_attenuation = 2.0
	desk_focus.shadow_enabled = true
	root.add_child(desk_focus)
	var window_fill := SpotLight3D.new()
	window_fill.name = "ColdRainWindowEdgeLight"
	window_fill.position = Vector3(2.65, 2.35, -6.72)
	window_fill.light_color = Color(0.27, 0.39, 0.54)
	window_fill.light_energy = 2.05
	window_fill.spot_range = 6.0
	window_fill.spot_angle = 46.0
	window_fill.spot_attenuation = 1.75
	window_fill.shadow_enabled = false
	root.add_child(window_fill)
	window_fill.look_at(Vector3(0.35, 0.45, -5.75), Vector3.UP)
	var entrance_fill := SpotLight3D.new()
	entrance_fill.name = "WeakMainHallSpill"
	entrance_fill.position = Vector3(0.0, 2.45, 7.12)
	entrance_fill.light_color = Color(0.30, 0.30, 0.31)
	entrance_fill.light_energy = 1.25
	entrance_fill.spot_range = 7.2
	entrance_fill.spot_angle = 41.0
	entrance_fill.shadow_enabled = false
	root.add_child(entrance_fill)
	entrance_fill.look_at(Vector3(0.0, 0.65, 0.10), Vector3.UP)
	for data in [[-1.55,1.75,2.2,1.02], [1.55,1.82,1.85,0.61], [1.55,1.82,-2.70,0.88], [-1.55,1.58,-7.7,0.72]]:
		var side_light := OmniLight3D.new()
		side_light.name = "RestrainedArchiveShelfReadability"
		side_light.position = Vector3(float(data[0]), float(data[1]), float(data[2]))
		side_light.light_color = Color(0.28, 0.33, 0.39) if float(data[2]) < -4.0 else Color(0.39, 0.32, 0.25)
		side_light.light_energy = float(data[3])
		side_light.omni_range = 3.9
		side_light.omni_attenuation = 1.9
		side_light.shadow_enabled = false
		root.add_child(side_light)
	var roof_readability := DirectionalLight3D.new()
	roof_readability.name = "ColdBeamAndShelfSeparation"
	roof_readability.light_color = Color(0.26, 0.31, 0.38)
	roof_readability.light_energy = 0.61
	roof_readability.rotation_degrees = Vector3(-58.0, -25.0, 0.0)
	roof_readability.shadow_enabled = false
	root.add_child(roof_readability)
	var beam_bounce := SpotLight3D.new()
	beam_bounce.name = "WeakColdBounceOnExposedTimbers"
	beam_bounce.position = Vector3(0.0, 2.35, -1.85)
	beam_bounce.light_color = Color(0.21, 0.27, 0.33)
	beam_bounce.light_energy = 0.58
	beam_bounce.spot_range = 6.2
	beam_bounce.spot_angle = 62.0
	beam_bounce.spot_attenuation = 2.5
	beam_bounce.shadow_enabled = false
	root.add_child(beam_bounce)
	beam_bounce.look_at(Vector3(0.0, 3.55, -1.85), Vector3.BACK)
	var rear_fill := OmniLight3D.new()
	rear_fill.name = "SubtleRearArchiveReadability"
	rear_fill.position = Vector3(-0.35, 2.10, -7.45)
	rear_fill.light_color = Color(0.25, 0.29, 0.35)
	rear_fill.light_energy = 1.08
	rear_fill.omni_range = 4.55
	rear_fill.omni_attenuation = 1.85
	rear_fill.shadow_enabled = false
	root.add_child(rear_fill)
	var floor_bounce := OmniLight3D.new()
	floor_bounce.name = "CoolFloorAndLowerFurnitureBounce"
	floor_bounce.position = Vector3(0.25, 0.52, -2.7)
	floor_bounce.light_color = Color(0.18, 0.235, 0.30)
	floor_bounce.light_energy = 0.96
	floor_bounce.omni_range = 6.2
	floor_bounce.omni_attenuation = 1.65
	floor_bounce.shadow_enabled = false
	root.add_child(floor_bounce)


func _build_study_air(root: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "SparseArchiveDust"
	dust.position = Vector3(0.0, 1.75, -1.0)
	dust.amount = 34
	dust.lifetime = 11.0
	dust.randomness = 0.88
	dust.visibility_aabb = AABB(Vector3(-3.2, -1.8, -8.6), Vector3(6.4, 4.0, 17.2))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(2.65, 1.55, 7.65)
	process.direction = Vector3(0.04, -0.08, 0.02)
	process.spread = 62.0
	process.initial_velocity_min = 0.006
	process.initial_velocity_max = 0.022
	process.gravity = Vector3(0.0, -0.002, 0.0)
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.56, 0.52, 0.43, 0.15)
	material.albedo_texture = _soft_particle_texture()
	quad.material = material
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dust)
	dust.emitting = true


func _build_study_audio() -> void:
	book_drop_audio = AudioStreamPlayer3D.new()
	book_drop_audio.name = "BookDropSFX"
	book_drop_audio.position = TORN_PAGE_POS
	book_drop_audio.stream = _make_book_drop_stream()
	book_drop_audio.volume_db = -8.0
	add_child(book_drop_audio)
	distant_door_audio = AudioStreamPlayer.new()
	distant_door_audio.name = "DistantHallDoorSFX"
	distant_door_audio.stream = load("res://assets/audio/public_effects/door_push.wav") as AudioStream
	distant_door_audio.volume_db = -17.0
	add_child(distant_door_audio)
	paper_audio = AudioStreamPlayer.new()
	paper_audio.name = "DryPaperHandlingSFX"
	paper_audio.stream = load("res://assets/audio/menu_confirm.ogg") as AudioStream
	paper_audio.volume_db = -16.0
	add_child(paper_audio)


func _make_book_drop_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := 6615
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 43017
	for i in range(sample_count):
		var t := float(i) / 22050.0
		var thud := sin(TAU * 92.0 * t) * exp(-t * 27.0) * 0.45
		var slap := random.randf_range(-1.0, 1.0) * exp(-t * 52.0) * 0.24
		data.encode_s16(i * 2, int(clampf(thud + slap, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream


func _build_hud() -> void:
	super._build_hud()
	if hud.has_signal("document_closed"):
		hud.document_closed.connect(_on_document_closed)
	_update_objective()


func _build_audio() -> void:
	super._build_audio()
	rain_audio.volume_db = -17.0
	next_creak_at = Time.get_ticks_msec() * 0.001 + randf_range(10.0, 18.0)


func _process(delta: float) -> void:
	super._process(delta)
	var now := Time.get_ticks_msec() * 0.001
	if now >= next_creak_at and distant_door_audio != null and not distant_door_audio.playing:
		distant_door_audio.volume_db = -27.0
		distant_door_audio.pitch_scale = randf_range(0.72, 0.88)
		distant_door_audio.play()
		next_creak_at = now + randf_range(14.0, 27.0)


func _physics_process(delta: float) -> void:
	if interaction_busy:
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
	_update_hud()


func _interaction_target() -> String:
	var p := Vector2(player.position.x, player.position.z)
	if player.position.z > 6.76:
		return "exit"
	if not _state().study_genealogy_read and p.distance_to(Vector2(GENEALOGY_POS.x, GENEALOGY_POS.z)) < 1.20:
		return "genealogy"
	if torn_page_visual != null and torn_page_visual.visible and p.distance_to(Vector2(TORN_PAGE_POS.x, TORN_PAGE_POS.z)) < 1.10:
		return "torn_page"
	if _state().study_drawer_open:
		if old_letter_visual.visible and p.distance_to(Vector2(LETTER_POS.x, LETTER_POS.z)) < 0.92:
			return "letter"
		if copper_key_visual.visible and p.distance_to(Vector2(KEY_POS.x, KEY_POS.z)) < 0.92:
			return "copper_key"
	if p.distance_to(Vector2(DRAWER_POS.x, DRAWER_POS.z)) < 1.15:
		return "drawer"
	if p.distance_to(Vector2(LOCKED_BOX_POS.x, LOCKED_BOX_POS.z)) < 1.20:
		return "locked_box"
	return ""


func _update_hud() -> void:
	var target := _interaction_target()
	if target != hud_interaction_target:
		hud_interaction_target = target
		hud.call("set_door_prompt_visible", not target.is_empty())
		var prompt := ""
		match target:
			"exit": prompt = "返回主大堂"
			"genealogy": prompt = "查看《王氏家谱》"
			"torn_page": prompt = "拾取被藏起的家谱残页"
			"drawer": prompt = "再次拉开卡住的抽屉" if _state().study_drawer_attempted and not _state().study_drawer_open else ("查看书桌抽屉" if not _state().study_drawer_open else "查看已经打开的抽屉")
			"letter": prompt = "拾取抽屉里的旧信"
			"copper_key": prompt = "拾取旧铜钥匙"
			"locked_box": prompt = "查看上锁的小木匣"
		hud.call("set_interaction_text", prompt)
	var stage := 0
	var caption := "主堂的雨声退到门外，积灰的纸页没有一丝动静"
	if player.position.z < -6.4:
		stage = 3
		caption = "后柜与木匣像是被人匆忙封存过"
	elif player.position.z < -2.8:
		stage = 2
		caption = "书架间空了一格，那里原本似乎放着重要记录"
	elif player.position.z < 1.5:
		stage = 1
		caption = "桌上的家谱摊在烛光里，封面落着一层薄灰"
	if stage != story_stage:
		story_stage = stage
		hud.call("set_story_caption", caption, true)
	_update_objective()


func _update_objective() -> void:
	if hud == null:
		return
	var objective := "调查王家的旧书房"
	if _state().has_item("study_old_copper_key"):
		objective = "寻找旧铜钥匙能够打开的门"
	elif _state().has_item("old_servant_letter") and not _state().study_letter_read:
		objective = "读完背包中的旧仆信"
	elif _state().study_genealogy_read:
		objective = "调查王氏旧事" if _state().has_item("torn_genealogy_page") else "搜索被删除的记录"
	elif player != null and player.position.z < 2.0:
		objective = "查看《王氏家谱》"
	hud.call("set_objective", objective)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if interaction_busy:
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
		_leave_study()


func _handle_interaction(target: String) -> void:
	match target:
		"exit": _leave_study()
		"genealogy":
			_state().add_item("wang_genealogy")
			_state().study_genealogy_read = true
			paper_audio.play()
			hud.call("open_document_item", "wang_genealogy")
		"torn_page":
			if _state().add_item("torn_genealogy_page"):
				_state().study_torn_page_found = true
				torn_page_visual.hide()
				paper_audio.play()
				hud.call("open_document_item", "torn_genealogy_page")
		"drawer": _interact_drawer()
		"letter":
			if _state().add_item("old_servant_letter"):
				old_letter_visual.hide()
				paper_audio.play()
				hud.call("open_document_item", "old_servant_letter")
		"copper_key":
			if copper_key_visual.visible and _state().add_item("study_old_copper_key"):
				_state().study_old_key_taken = true
				copper_key_visual.hide()
				hud.call("set_story_caption", "获得：旧铜钥匙。钥齿完整，却不像是这只木匣的锁。", true, true)
				_update_objective()
		"locked_box":
			var text := "木匣被一把更细的旧锁锁住。手里的铜钥匙并不匹配。" if _state().has_item("study_old_copper_key") else "这是保存契据的小木匣，铜锁已经发黑；现在还打不开。"
			hud.call("set_story_caption", text, true, true)


func _interact_drawer() -> void:
	if _state().study_drawer_open:
		hud.call("set_story_caption", "抽屉深处有一道暗格，信与钥匙曾被压在账册下面。", true, true)
		return
	if not _state().study_drawer_attempted:
		_state().study_drawer_attempted = true
		hud.call("set_story_caption", "抽屉受潮卡死了。再用力一次，也许能拉开。", true, true)
		return
	interaction_busy = true
	player.velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(desk_drawer, "position:z", -0.46, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_state().study_drawer_open = true
	old_letter_visual.show()
	copper_key_visual.hide()
	interaction_busy = false
	hud.call("set_story_caption", "木头发出一声闷响。抽屉夹层里压着一封旧信和一把铜钥匙。", true, true)


func _on_document_closed(item_id: String) -> void:
	if item_id == "wang_genealogy" and not _state().study_book_dropped:
		_trigger_book_drop()
	elif item_id == "old_servant_letter":
		_finish_old_letter_reading()


func _finish_old_letter_reading() -> void:
	var state := _state()
	if state.study_letter_read or not state.has_completed_document("old_servant_letter"):
		return
	state.study_letter_read = true
	state.study_distant_door_ajar = true
	if state.study_drawer_open and not state.has_item("study_old_copper_key"):
		copper_key_visual.show()
	distant_door_audio.volume_db = -13.0
	distant_door_audio.pitch_scale = 0.78
	distant_door_audio.play()
	hud.call("set_story_caption", "主堂深处传来一声木门合页响。那里原本没有风。", true, true)
	_update_objective()


func _trigger_book_drop() -> void:
	interaction_busy = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(falling_book, "position", TORN_PAGE_POS + Vector3(0.0, 0.07, 0.0), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(falling_book, "rotation_degrees", Vector3(0.0, -18.0, 9.0), 0.48)
	await tween.finished
	book_drop_audio.play()
	_state().study_book_dropped = true
	torn_page_visual.show()
	interaction_busy = false
	hud.call("set_story_caption", "右侧书架上一本旧册忽然落下，下面压着一张被撕走的家谱页。", true, true)
	_update_objective()


func _leave_study() -> void:
	_state().return_to_hall_study_door = true
	_change_scene(MAIN_HALL_PATH)
