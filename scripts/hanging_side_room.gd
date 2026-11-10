extends "res://scripts/left_wing_interior.gd"

const MAIN_HALL_PATH := "res://scenes/InteriorPlaceholder.tscn"
const WET_FOOTPRINT_ROUTE_SCENE = preload("res://scenes/story/YuelanFootprintRoute.tscn")
const RETURN_INVESTIGATION_SCRIPT = preload("res://scripts/hanging_room_return_investigation.gd")
const DOOR_STORY_SCRIPT = preload("res://scripts/hanging_room_door_story.gd")
const CODA_SCRIPT = preload("res://scripts/hanging_room_coda.gd")
var wet_footprint_route: Node3D
var return_investigation: Node
var door_story: DOOR_STORY_SCRIPT
var coda: CODA_SCRIPT
var door_view_weight := 0.0
var truth_glance_weight := 0.0
const ROOM_X := 2.72
const ROOM_NEAR_Z := 7.30
const ROOM_FAR_Z := -10.80
const WARNING_TALISMAN_ID := "wang_warning_talisman"
const WARNING_TALISMAN_POSITION := Vector3(-0.58, 0.055, -3.32)
var near_rope := false
var near_stool := false
var near_incense := false
var near_warning_talisman := false
var rope_visual: Node3D
var flutter_papers: Array[Node3D] = []
var warning_talisman: Node3D
var warning_read_overlay: Control
var warning_read_open := false
var room_reaction := 0.0
var reaction_started_at := -10.0
var incense_smoke: GPUParticles3D
var incense_embers: Array[MeshInstance3D] = []
var paper_audio: AudioStreamPlayer
var beam_creak_audio: AudioStreamPlayer3D

func _ready() -> void:
	door_story = DOOR_STORY_SCRIPT.new()
	super._ready()
	wet_footprint_route = WET_FOOTPRINT_ROUTE_SCENE.instantiate()
	add_child(wet_footprint_route)
	wet_footprint_route.call("setup", self, get_node("/root/GameState"), "hanging")
	return_investigation = RETURN_INVESTIGATION_SCRIPT.new()
	return_investigation.name = "HangingRoomReturnInvestigation"
	add_child(return_investigation)
	return_investigation.call("setup", self, get_node("/root/GameState"))
	door_story.name = "WestWingDoorCry"
	add_child(door_story)
	door_story.setup(self, get_node("/root/GameState"), return_investigation)
	return_investigation.call("begin_truth_if_ready")
	coda = CODA_SCRIPT.new()
	coda.name = "ShenYuelanCoda"
	add_child(coda)
	coda.setup(self, GameState, return_investigation.confession_spot)

func _exit_tree() -> void:
	# Explicitly release the looping room ambience before scene replacement.
	if is_instance_valid(rain_audio):
		rain_audio.stop()
		rain_audio.stream = null

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.007, 0.009, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.205, 0.245, 0.30)
	env.ambient_light_energy = 1.04
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.055, 0.065)
	env.fog_light_energy = 0.28
	env.fog_density = 0.016
	env.fog_height = 0.80
	env.fog_height_density = 0.34
	world.environment = env
	add_child(world)
	var cold_roof := DirectionalLight3D.new()
	cold_roof.name = "MoonlessRoofStructureFill"
	cold_roof.light_color = Color(0.25, 0.31, 0.38)
	cold_roof.light_energy = 0.30
	cold_roof.rotation_degrees = Vector3(-61.0, -18.0, 0.0)
	cold_roof.shadow_enabled = false
	add_child(cold_roof)

func _build_room() -> void:
	var room := Node3D.new()
	room.name = "HangingRoom"
	add_child(room)
	var architecture := _module(room, "Architecture")
	var horror_focus := _module(room, "HorrorFocus")
	var papers := _module(room, "Papers")
	var lighting := _module(room, "Lighting")
	var atmosphere := _module(room, "Atmosphere")
	var props := _module(room, "Props")
	var plaster := (load("res://materials/architecture/interior_ritual_plaster.tres") as Material).duplicate(true)
	var wood := (load("res://materials/architecture/wet_old_wood.tres") as Material).duplicate(true)
	var floor_mat := (load("res://materials/ground/interior_wet_brick.tres") as Material).duplicate(true)
	if plaster is ShaderMaterial:
		plaster.set_shader_parameter("world_tile_scale", Vector2(0.31, 0.38))
		plaster.set_shader_parameter("plaster_tint", Color(0.49, 0.47, 0.41, 1))
		plaster.set_shader_parameter("damp_tint", Color(0.095, 0.115, 0.112, 1))
		plaster.set_shader_parameter("albedo_gain", 1.08)
		plaster.set_shader_parameter("normal_strength", 0.58)
		plaster.set_shader_parameter("weathering_strength", 0.79)
		plaster.set_shader_parameter("root_dampness", 0.88)
		plaster.set_shader_parameter("streak_strength", 0.67)
	if wood is ShaderMaterial:
		wood.set_shader_parameter("uv_repeat", Vector2(1.18, 2.75))
		wood.set_shader_parameter("material_tint", Color(0.32, 0.235, 0.17, 1))
		wood.set_shader_parameter("normal_strength", 0.78)
		wood.set_shader_parameter("wetness_amount", 0.48)
	if floor_mat is ShaderMaterial:
		floor_mat.set_shader_parameter("tile_repeat", Vector2(1.18, 1.04))
		floor_mat.set_shader_parameter("brick_tint", Color(0.44, 0.48, 0.48, 1))
		floor_mat.set_shader_parameter("albedo_gain", 1.02)
		floor_mat.set_shader_parameter("normal_strength", 0.88)
		floor_mat.set_shader_parameter("wetness_amount", 0.48)
	var dark_wood := _material(Color(0.035, 0.023, 0.017), 0.83)
	var damp := _material(Color(0.018, 0.024, 0.025), 0.96)
	var bronze := _material(Color(0.105, 0.075, 0.042), 0.65)
	bronze.metallic = 0.22
	var yellow_paper := _aged_paper(Color(0.49, 0.37, 0.19))
	var white_paper := _aged_paper(Color(0.53, 0.52, 0.47))
	var cinnabar := _material(Color(0.23, 0.025, 0.014), 0.92)
	var rope_mat := ShaderMaterial.new()
	rope_mat.shader = preload("res://shaders/old_hemp_surface.gdshader")
	var wax := _material(Color(0.25, 0.055, 0.025), 0.84)
	_build_shell(architecture, plaster, wood, floor_mat, dark_wood, damp)
	_build_noose(horror_focus, rope_mat, wood)
	_build_kicked_stool(horror_focus, wood, dark_wood)
	_build_paper_scatter(papers, yellow_paper, white_paper, cinnabar)
	_build_warning_talisman(papers, yellow_paper, cinnabar)
	_build_incense_focus(horror_focus, bronze, dark_wood)
	_build_candle_pool(lighting, Vector3(-2.10, 0.72, -1.0), wax, bronze, dark_wood, 1.06)
	_build_candle_pool(lighting, Vector3(2.08, 0.82, -6.35), wax, bronze, dark_wood, 1.02)
	_build_narrative_lighting(lighting)
	_build_sparse_props(props, wood, dark_wood, damp)
	_build_air(atmosphere)
	_build_clue_audio()

func _module(parent: Node3D, module_name: String) -> Node3D:
	var module := Node3D.new()
	module.name = module_name
	parent.add_child(module)
	return module

func _build_shell(root_node: Node3D, plaster: Material, wood: Material, floor_mat: Material, dark_wood: Material, damp: Material) -> void:
	_add_box(root_node, "WetBrickFloorMass", Vector3(6.1, 0.18, 19.0), Vector3(0, -0.10, -1.70), damp, true)
	var tile := BoxMesh.new()
	tile.size = Vector3(0.72, 0.035, 0.88)
	tile.material = floor_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tile
	mm.instance_count = 7 * 20
	for z_i in range(20):
		for x_i in range(7):
			var i := z_i * 7 + x_i
			var angle := deg_to_rad(float((i * 7) % 5 - 2) * 0.45)
			mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0, angle, 0)), Vector3(-2.25 + x_i * 0.75, 0.008 + (i % 3) * 0.002, 6.65 - z_i * 0.89)))
	var tiles := MultiMeshInstance3D.new()
	tiles.name = "UnevenOldWetFloorTiles"
	tiles.multimesh = mm
	root_node.add_child(tiles)
	_add_box(root_node, "LeftDampPlasterWall", Vector3(0.32, 3.55, 19.0), Vector3(-3.0, 1.75, -1.70), plaster, true)
	_add_box(root_node, "RightDampPlasterWall", Vector3(0.32, 3.55, 19.0), Vector3(3.0, 1.75, -1.70), plaster, true)
	_add_box(root_node, "RearMouldWall", Vector3(6.3, 3.55, 0.34), Vector3(0, 1.75, -11.20), plaster, true)
	_add_box(root_node, "LowOppressiveCeiling", Vector3(6.15, 0.16, 19.0), Vector3(0, 3.62, -1.70), dark_wood)
	for z in [6.8, 3.8, 0.8, -2.2, -5.2, -8.2, -10.9]:
		_add_box(root_node, "HeavyCrackedCrossBeam", Vector3(6.3, 0.28, 0.34), Vector3(0, 3.34, z), dark_wood)
	for x in [-2.25, -1.12, 0.0, 1.12, 2.25]:
		_add_box(root_node, "LongOldRoofPurlin", Vector3(0.16, 0.15, 18.5), Vector3(x, 3.46, -1.7), wood)
	var damp_overlay := _material(Color(0.025,0.041,0.038,0.46),0.98)
	damp_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1.0, 1.0]:
		for z in [6.7, 1.0, -4.8, -10.6]:
			_add_box(root_node, "RottenWallPost", Vector3(0.30, 3.45, 0.34), Vector3(side * 2.78, 1.72, z), wood, true)
		for z in [4.1, -0.5, -7.8]:
			_add_box(root_node, "IrregularWallDampPatch", Vector3(0.035, 1.05, 1.25), Vector3(side * 2.82, 0.78 + absf(z) * 0.025, z), damp_overlay)
		# Raised timber rails make both walls read as old infill construction.
		for y in [0.55, 2.72]:
			_add_box(root_node, "AgedWallTimberRail", Vector3(0.20, 0.15, 18.25), Vector3(side * 2.80, y, -1.68), wood)
	var exposed_earth := _material(Color(0.115, 0.094, 0.072), 0.96)
	var mould := _material(Color(0.025, 0.041, 0.038, 0.48), 0.98)
	mould.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var soot := _material(Color(0.025, 0.021, 0.018, 0.78), 0.96)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for data in [[-2.81,1.46,2.8,0.68],[-2.81,1.08,-2.3,0.90],[2.81,1.72,1.4,0.62],[2.81,1.02,-4.8,1.05]]:
		var patch := _add_box(root_node, "PeelingPlasterEarthExposure", Vector3(0.04, float(data[3]), 0.92), Vector3(float(data[0]), float(data[1]), float(data[2])), exposed_earth)
		patch.rotation_degrees.x = float(int(absf(float(data[2])) * 7.0) % 7 - 3)
	for side in [-1.0, 1.0]:
		for z in [5.2, 2.0, -1.8, -5.8, -9.3]:
			_add_box(root_node, "RootDampMouldBand", Vector3(0.045, 0.34 + float(int(absf(z)) % 3) * 0.10, 1.22), Vector3(side * 2.79, 0.24, z), mould)
	# Rear wall is a material endpoint rather than an empty black plane.
	_add_box(root_node, "RearWallCentralWaterBloom", Vector3(2.55, 1.34, 0.045), Vector3(-0.18, 1.52, -11.01), mould)
	for x in [-2.12, -1.30, 0.72, 1.82]:
		var crack := _add_box(root_node, "RearWallHairlineCrack", Vector3(0.035, 0.86, 0.04), Vector3(x, 1.70 + absf(x) * 0.14, -10.98), damp)
		crack.rotation_degrees.z = x * 7.0
	# Soot blooms connect candle light to the architecture.
	_add_box(root_node, "LeftCandleSootBloom", Vector3(0.035, 0.92, 0.66), Vector3(-2.80, 1.52, -1.0), soot)
	_add_box(root_node, "RightCandleSootBloom", Vector3(0.035, 0.92, 0.66), Vector3(2.80, 1.62, -6.35), soot)
	# Restrained wet accents: most bricks remain rough, only these catch light.
	var puddle := _material(Color(0.075, 0.10, 0.11, 0.34), 0.23)
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for data in [[-1.75,4.65,0.72,0.25],[1.82,-0.48,0.86,0.31],[-1.22,-6.85,0.64,0.24],[0.72,-9.35,0.78,0.28]]:
		var wet := _add_box(root_node, "SmallIrregularFloorWetness", Vector3(float(data[2]), 0.008, float(data[3])), Vector3(float(data[0]), 0.034, float(data[1])), puddle)
		wet.rotation_degrees.y = float(data[0]) * 13.0
	# Entrance frame and cold rain spill establish the return direction.
	for x in [-1.28, 1.28]:
		_add_box(root_node, "EntranceDoorJamb", Vector3(0.30, 3.15, 0.38), Vector3(x, 1.58, 7.55), wood)
	_add_box(root_node, "EntranceLintel", Vector3(2.86, 0.30, 0.40), Vector3(0, 3.18, 7.55), dark_wood)
	door_story.build_inside(self, root_node, wood, dark_wood, plaster)
	var cold := OmniLight3D.new()
	cold.name = "WeakRainLightThroughDoor"
	cold.position = Vector3(0, 1.85, 6.65)
	cold.light_color = Color(0.20, 0.31, 0.43)
	cold.light_energy = 1.08
	cold.omni_range = 4.6
	cold.shadow_enabled = false
	root_node.add_child(cold)
	door_story.spill = cold
	var wall_fill := OmniLight3D.new()
	wall_fill.name = "ColdWallStructureReadability"
	wall_fill.position = Vector3(0, 2.35, -1.1)
	wall_fill.light_color = Color(0.18, 0.235, 0.30)
	wall_fill.light_energy = 0.88
	wall_fill.omni_range = 6.2
	wall_fill.omni_attenuation = 1.55
	wall_fill.shadow_enabled = false
	root_node.add_child(wall_fill)

func _build_noose(root_node: Node3D, rope_mat: Material, wood: Material) -> void:
	# One pivot at the binding point gives the entire rope a barely perceptible sway.
	rope_visual = Node3D.new()
	rope_visual.name = "HangingRope"
	rope_visual.position = Vector3(0, 3.44, -5.20)
	root_node.add_child(rope_visual)
	var drop_points: Array[Vector3] = []
	for i in range(13):
		var t := float(i) / 12.0
		drop_points.append(Vector3(sin(t * 7.2) * 0.007, -t * 1.20, sin(t * 4.3) * 0.005))
	_add_segmented_rope(rope_visual, "NooseRopeDrop", drop_points, 0.036, rope_mat)
	var loop_points: Array[Vector3] = []
	for i in range(33):
		var a := TAU * float(i) / 32.0
		var wobble := 1.0 + sin(a * 3.0 + 0.7) * 0.045
		loop_points.append(Vector3(sin(a) * 0.285 * wobble, -1.67 + cos(a) * 0.47, sin(a * 2.0) * 0.018))
	_add_segmented_rope(rope_visual, "HangingNooseLoop", loop_points, 0.038, rope_mat)
	# Uneven compressed turns read as a real knot rather than a perfect torus.
	for ring_index in range(4):
		var knot_points: Array[Vector3] = []
		for i in range(13):
			var a := TAU * float(i) / 12.0
			knot_points.append(Vector3(cos(a) * (0.060 + ring_index * 0.004), -1.20 - ring_index * 0.045, sin(a) * 0.050))
		_add_segmented_rope(rope_visual, "CoarseNooseKnot", knot_points, 0.025, rope_mat)
	# Two visible wraps pass around the actual load beam before the drop begins.
	for wrap_index in range(2):
		var wrap_points: Array[Vector3] = []
		for i in range(17):
			var a := TAU * float(i) / 16.0
			wrap_points.append(Vector3(-0.055 + wrap_index * 0.11, -0.09 + cos(a) * 0.16, sin(a) * 0.22))
		_add_segmented_rope(rope_visual, "RopeWrappedAroundLoadBeam", wrap_points, 0.030, rope_mat)
	# Scuffed binding block merges the rope visually into the beam surface.
	_add_box(root_node, "RopeBeamAbrasion", Vector3(0.30, 0.09, 0.36), Vector3(0, 3.24, -5.20), wood)

func _add_segmented_rope(root_node: Node3D, segment_name: String, points: Array[Vector3], radius: float, material: Material) -> void:
	for i in range(points.size() - 1):
		var start := points[i]
		var finish := points[i + 1]
		var direction := finish - start
		var length := direction.length()
		if length < 0.001:
			continue
		var y_axis := direction / length
		var x_axis := y_axis.cross(Vector3.FORWARD)
		if x_axis.length_squared() < 0.01:
			x_axis = y_axis.cross(Vector3.RIGHT)
		x_axis = x_axis.normalized()
		var z_axis := x_axis.cross(y_axis).normalized()
		var mesh := CylinderMesh.new()
		var segment_radius := radius * (0.92 + float(i % 4) * 0.035)
		mesh.top_radius = segment_radius
		mesh.bottom_radius = segment_radius * 1.03
		mesh.height = length * 1.08
		mesh.radial_segments = 7
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.name = segment_name if i == 0 else segment_name + "Segment"
		instance.mesh = mesh
		instance.transform = Transform3D(Basis(x_axis, y_axis, z_axis), (start + finish) * 0.5)
		root_node.add_child(instance)

func _build_kicked_stool(root_node: Node3D, wood: Material, dark_wood: Material) -> void:
	var stool := Node3D.new()
	stool.name = "KickedOldStool"
	stool.position = Vector3(0.48, 0.14, -4.15)
	stool.rotation_degrees = Vector3(5, -18, 18)
	root_node.add_child(stool)
	_add_box(stool, "WornSeat", Vector3(0.72, 0.13, 0.46), Vector3(0, 0.65, 0), wood, true)
	var worn_edge := _material(Color(0.24,0.165,0.105),0.82)
	_add_box(stool, "ExposedWornSeatEdge", Vector3(0.67,0.035,0.43), Vector3(0,0.724,0), worn_edge)
	for x in [-0.25, 0.25]:
		for z in [-0.14, 0.14]:
			_add_box(stool, "SplayedLeg", Vector3(0.09, 0.62, 0.09), Vector3(x, 0.31, z), dark_wood)
	for z in [-0.15,0.15]:
		_add_box(stool,"StoolCrackedCrossRung",Vector3(0.48,0.055,0.055),Vector3(0,0.30,z),wood)
	var scratch := _material(Color(0.10, 0.075, 0.052, 0.68), 0.90)
	scratch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for data in [[0.62,-3.65,0.52,-22.0],[0.92,-4.00,0.42,-10.0],[0.20,-4.42,0.36,-31.0]]:
		var mark := _add_box(root_node, "DisturbedDustAndStoolScratch", Vector3(0.035, 0.009, float(data[2])), Vector3(float(data[0]), 0.041, float(data[1])), scratch)
		mark.rotation_degrees.y = float(data[3])
	var dry_stain := _material(Color(0.105, 0.055, 0.035, 0.30), 0.94)
	dry_stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var stain := _add_box(root_node, "RestrainedOldBrownStain", Vector3(0.34, 0.007, 0.18), Vector3(-0.12, 0.040, -4.46), dry_stain)
	stain.rotation_degrees.y = 17.0

func _aged_paper(tint: Color) -> ShaderMaterial:
	var paper := ShaderMaterial.new()
	paper.shader = preload("res://shaders/aged_room_paper.gdshader")
	paper.set_shader_parameter("paper_tint", tint)
	return paper


func _build_paper_scatter(root_node: Node3D, yellow: Material, white: Material, cinnabar: Material) -> void:
	var talismans := _clustered_paper_transforms(30, false, 9147)
	var money := _clustered_paper_transforms(38, true, 4219)
	var yellow_variants: Array[Material] = [
		yellow, _aged_paper(Color(0.43,0.32,0.16)), _aged_paper(Color(0.35,0.28,0.16)),
		_aged_paper(Color(0.47,0.355,0.18)), _aged_paper(Color(0.34,0.265,0.15))
	]
	var white_variants: Array[Material] = [
		white, _aged_paper(Color(0.47,0.46,0.40)), _aged_paper(Color(0.39,0.39,0.36)),
		_aged_paper(Color(0.51,0.49,0.42))
	]
	_build_paper_multimeshes(root_node, "TalismanCluster", talismans, yellow_variants, Vector3(0.28,0.009,0.48))
	_build_paper_multimeshes(root_node, "GhostMoneyCluster", money, white_variants, Vector3(0.34,0.008,0.25))
	var symbol_transforms: Array[Transform3D] = []
	for transform in talismans:
		var symbol_transform: Transform3D = transform
		symbol_transform.origin.y += 0.010
		symbol_transforms.append(symbol_transform)
	_build_paper_multimeshes(root_node, "VariedFadedCinnabarMarks", symbol_transforms, [cinnabar], Vector3(0.030,0.010,0.31))
	var money_holes: Array[Transform3D] = []
	for i in range(money.size()):
		if i % 4 != 0:
			var hole_transform: Transform3D = money[i]
			hole_transform.origin.y += 0.009
			money_holes.append(hole_transform)
	var money_cut := _material(Color(0.075,0.070,0.060),1.0)
	_build_paper_multimeshes(root_node, "GhostMoneySquareCut", money_holes, [money_cut], Vector3(0.085,0.009,0.075))
	# Dark contact cards sit only millimetres beneath the paper, grounding it.
	var contact := _material(Color(0.006,0.007,0.007,0.30),1.0)
	contact.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var contact_transforms: Array[Transform3D] = []
	for transform in talismans + money:
		var shadow_transform: Transform3D = transform
		shadow_transform.origin.y = 0.034
		contact_transforms.append(shadow_transform)
	_build_paper_multimeshes(root_node, "PaperContactShadow", contact_transforms, [contact], Vector3(0.33,0.004,0.38))
	# Only two loose sheets move; everything else remains heavy with moisture.
	for data in [[-1.42,-5.52,-14.0],[1.62,-3.88,21.0]]:
		var flutter := Node3D.new()
		flutter.name = "BarelyMovingLoosePaper"
		flutter.position = Vector3(float(data[0]), 0.052, float(data[1]))
		flutter.rotation_degrees.y = float(data[2])
		root_node.add_child(flutter)
		_add_box(flutter, "FoldedGhostMoneyHalfA", Vector3(0.18,0.010,0.27), Vector3(-0.09,0,0), white)
		var half := _add_box(flutter, "FoldedGhostMoneyHalfB", Vector3(0.18,0.010,0.27), Vector3(0.09,0.025,0), white)
		half.rotation_degrees.z = 7.0
		flutter_papers.append(flutter)
	# Two failed seals remain half attached to the walls.
	for side in [-1.0, 1.0]:
		var remnant := _add_box(root_node, "HalfDetachedWallTalisman", Vector3(0.025,0.42,0.22), Vector3(side * 2.79,1.38,-7.18 + side * 0.42), yellow)
		remnant.rotation_degrees.z = side * 11.0

func _build_warning_talisman(root_node: Node3D, yellow: Material, cinnabar: Material) -> void:
	warning_talisman = Node3D.new()
	warning_talisman.name = "ReadableWangWarningTalisman"
	warning_talisman.position = WARNING_TALISMAN_POSITION
	warning_talisman.rotation_degrees.y = -13.0
	root_node.add_child(warning_talisman)
	var old_paper := _material(Color(0.38, 0.265, 0.075), 0.93)
	var damp_edge := _material(Color(0.105, 0.067, 0.032), 0.98)
	var ink := _material(Color(0.085, 0.045, 0.028), 0.97)
	# A thicker, irregular silhouette separates the clue from the decorative sheets.
	_add_box(warning_talisman, "BrittleDampPaperBody", Vector3(0.46, 0.012, 0.72), Vector3.ZERO, old_paper)
	for data in [[-0.19,-0.27,18.0],[0.18,-0.31,-22.0],[-0.20,0.29,-14.0],[0.19,0.25,25.0]]:
		var burn := _add_box(warning_talisman, "ScorchedBrokenCorner", Vector3(0.085,0.016,0.11), Vector3(float(data[0]),0.004,float(data[1])), damp_edge)
		burn.rotation_degrees.y = float(data[2])
	# Two raised strips imply water-warped, curling paper without adding collision.
	var curl_a := _add_box(warning_talisman, "WaterCurledEdge", Vector3(0.055,0.015,0.54), Vector3(-0.215,0.018,0.015), yellow)
	curl_a.rotation_degrees.z = -7.0
	var curl_b := _add_box(warning_talisman, "BurntRolledTip", Vector3(0.19,0.014,0.07), Vector3(0.105,0.025,-0.335), damp_edge)
	curl_b.rotation_degrees.x = 9.0
	# Faded seal above, hurried handwritten strokes below. Full prose is shown in the reading view.
	for data in [[0.0,-0.21,0.28,0.023],[-0.09,-0.13,0.19,0.022],[0.09,-0.06,0.19,0.022],[0.0,0.02,0.31,0.020]]:
		var seal := _add_box(warning_talisman, "FadedCinnabarSealStroke", Vector3(float(data[2]),0.017,float(data[3])), Vector3(float(data[0]),0.014,float(data[1])), cinnabar)
		seal.rotation_degrees.y = float(data[0]) * 35.0
	for z in [0.105, 0.165, 0.225, 0.285]:
		_add_box(warning_talisman, "HurriedWarningInk", Vector3(0.29 - z * 0.18,0.016,0.014), Vector3(-0.015,0.014,z), ink)
	var clue_fill := OmniLight3D.new()
	clue_fill.name = "FlashlightCatchOnOldPaper"
	clue_fill.position = Vector3(0,0.22,0)
	clue_fill.light_color = Color(0.36,0.29,0.16)
	clue_fill.light_energy = 0.20
	clue_fill.omni_range = 0.82
	clue_fill.shadow_enabled = false
	warning_talisman.add_child(clue_fill)
	warning_talisman.visible = not _has_warning_talisman()

func _clustered_paper_transforms(count: int, is_money: bool, seed_value: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(count):
		var center := Vector2(0.15, -4.65)
		var spread := Vector2(2.15, 1.85)
		if i >= int(count * 0.58):
			center = Vector2(-0.10, -2.45)
			spread = Vector2(1.85, 1.25)
		if i >= int(count * 0.88):
			center = Vector2(0.0, 2.40)
			spread = Vector2(2.15, 2.40)
		var x := clampf(center.x + rng.randfn(0.0, spread.x * 0.42), -2.35, 2.35)
		var z := clampf(center.y + rng.randfn(0.0, spread.y * 0.48), -9.70, 5.70)
		var yaw := rng.randf_range(-PI, PI)
		var tilt_x := rng.randf_range(-0.025, 0.025) if i % 6 != 0 else rng.randf_range(-0.09,0.09)
		var tilt_z := rng.randf_range(-0.020, 0.020)
		var scale_x := rng.randf_range(0.82,1.13)
		var scale_z := rng.randf_range(0.82,1.16) if is_money else rng.randf_range(0.88,1.12)
		var basis := Basis.from_euler(Vector3(tilt_x,yaw,tilt_z)).scaled(Vector3(scale_x,1.0,scale_z))
		result.append(Transform3D(basis, Vector3(x,0.043 + float(i % 4) * 0.002,z)))
	return result

func _build_paper_multimeshes(root_node: Node3D, node_name: String, transforms: Array[Transform3D], materials: Array, size: Vector3) -> void:
	for variant in range(materials.size()):
		var selected: Array[Transform3D] = []
		for i in range(transforms.size()):
			if i % materials.size() == variant:
				selected.append(transforms[i])
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = materials[variant]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = selected.size()
		for i in range(selected.size()):
			mm.set_instance_transform(i, selected[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_Variant%d" % [node_name, variant]
		instance.multimesh = mm
		root_node.add_child(instance)

func _build_incense_focus(root_node: Node3D, bronze: Material, dark_wood: Material) -> void:
	_add_cylinder(root_node, "OldIncenseBurner", 0.31, 0.34, Vector3(0, 0.19, -2.62), bronze, true)
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.25
	rim_mesh.outer_radius = 0.31
	rim_mesh.rings = 20
	rim_mesh.ring_segments = 9
	rim_mesh.material = bronze
	var rim := MeshInstance3D.new()
	rim.name = "OxidizedBurnerRim"
	rim.mesh = rim_mesh
	rim.position = Vector3(0,0.37,-2.62)
	root_node.add_child(rim)
	var ash := _material(Color(0.31,0.30,0.27),0.99)
	_add_cylinder(root_node, "DeepAccumulatedIncenseAsh", 0.245, 0.055, Vector3(0, 0.385, -2.62), ash)
	for x in [-0.10, 0.0, 0.09, 0.16]:
		var incense := _add_cylinder(root_node, "RecentlyBurningIncense", 0.008, 0.50 - absf(x) * 0.4, Vector3(x, 0.65 - absf(x) * 0.2, -2.62 + x * 0.16), _material(Color(0.18,0.045,0.022),0.94))
		incense.rotation_degrees.z = x * 20.0
	for x in [-0.10,0.0,0.09]:
		var ember := _add_sphere(root_node, "FaintIncenseEmber", 0.013, Vector3(x,0.905 - absf(x) * 0.2,-2.62 + x * 0.16), _material(Color(0.30,0.035,0.012),0.75,Color(0.35,0.035,0.008)))
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		incense_embers.append(ember)
	_build_incense_smoke(root_node, Vector3(0, 0.86, -2.62))
	for side in [-1.0,1.0]:
		_add_sphere(root_node, "BurnerClawFoot", 0.065, Vector3(side * 0.20,0.055,-2.62), bronze)

func _build_incense_smoke(root_node: Node3D, position: Vector3) -> void:
	var smoke := GPUParticles3D.new()
	incense_smoke = smoke
	smoke.name = "ThinIncenseSmoke"
	smoke.position = position
	smoke.amount = 18
	smoke.lifetime = 5.8
	smoke.preprocess = 5.8
	smoke.randomness = 0.48
	smoke.visibility_aabb = AABB(Vector3(-0.55,-0.15,-0.5),Vector3(1.1,1.8,1.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.05,1.0,0.015)
	process.spread = 4.5
	process.initial_velocity_min = 0.075
	process.initial_velocity_max = 0.115
	process.gravity = Vector3(0.020,0.012,-0.004)
	process.scale_min = 0.55
	process.scale_max = 1.15
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.10,0.46,0.76,1.0])
	fade.colors = PackedColorArray([Color(0.55,0.59,0.62,0),Color(0.55,0.59,0.62,0.28),Color(0.48,0.52,0.56,0.18),Color(0.42,0.47,0.51,0.08),Color(0.4,0.45,0.5,0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.062,0.20)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.albedo_color = Color(0.54,0.58,0.61,0.27)
	smoke_mat.albedo_texture = _soft_particle_texture()
	smoke_mat.vertex_color_use_as_albedo = true
	quad.material = smoke_mat
	smoke.draw_pass_1 = quad
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_node.add_child(smoke)
	smoke.emitting = true

func _build_candle_pool(root_node: Node3D, position: Vector3, wax: Material, metal: Material, shelf_material: Material, energy: float) -> void:
	_add_box(root_node, "OldCandleWallShelf", Vector3(0.48,0.09,0.38), position + Vector3(0,-0.47,0), shelf_material, true)
	_add_candle(root_node, position, wax, metal, energy)

func _build_sparse_props(root_node: Node3D, wood: Material, dark_wood: Material, damp: Material) -> void:
	_add_box(root_node, "LeftWarpedCabinet", Vector3(0.58, 1.42, 1.10), Vector3(-2.48, 0.71, -7.9), dark_wood, true)
	var board := _add_box(root_node, "LeaningBrokenDoorPanel", Vector3(0.12, 1.72, 0.74), Vector3(2.60, 0.86, -8.7), wood)
	board.rotation_degrees.z = -8.0
	_add_cylinder(root_node, "AbandonedDarkJar", 0.30, 0.66, Vector3(-2.48, 0.33, 2.50), damp, true)
	# A sealed side window provides structure and history without becoming an exit.
	_add_box(root_node, "RightSealedWindowRecess", Vector3(0.12,1.38,1.62), Vector3(2.78,1.75,0.42), dark_wood)
	for z in [-0.18,0.22,0.62,1.02]:
		_add_box(root_node, "WindowOldVerticalLattice", Vector3(0.16,1.18,0.055), Vector3(2.69,1.75,z), wood)
	for y in [1.30,1.72,2.14]:
		_add_box(root_node, "WindowOldHorizontalLattice", Vector3(0.16,0.055,1.48), Vector3(2.68,y,0.42), wood)
	var sealing_board := _add_box(root_node, "DiagonalWindowSealingBoard", Vector3(0.13,0.16,1.72), Vector3(2.62,1.72,0.42), wood)
	sealing_board.rotation_degrees.x = 23.0
	# One fallen broom and one cracked bamboo sieve support domestic history.
	var broom := Node3D.new()
	broom.name = "FallenOldBroom"
	broom.position = Vector3(-2.35,0.12,-8.85)
	broom.rotation_degrees = Vector3(78,-16,0)
	root_node.add_child(broom)
	_add_cylinder(broom,"BroomHandle",0.026,1.45,Vector3(0,0.65,0),wood)
	for x in [-0.10,-0.05,0.0,0.05,0.10]:
		var straw := _add_box(broom,"WornBroomStraw",Vector3(0.025,0.48,0.025),Vector3(x,-0.12,0),dark_wood)
		straw.rotation_degrees.z = x * 55.0
	var sieve_mesh := TorusMesh.new()
	sieve_mesh.inner_radius = 0.34
	sieve_mesh.outer_radius = 0.39
	sieve_mesh.rings = 24
	sieve_mesh.ring_segments = 8
	sieve_mesh.material = wood
	var sieve := MeshInstance3D.new()
	sieve.name = "CrackedBambooSieve"
	sieve.mesh = sieve_mesh
	sieve.position = Vector3(2.68,0.72,-8.95)
	sieve.rotation_degrees.z = 90.0
	root_node.add_child(sieve)

func _build_air(root_node: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 34
	dust.lifetime = 9.0
	dust.position = Vector3(0, 1.6, -3.0)
	dust.visibility_aabb = AABB(Vector3(-3,-2,-9), Vector3(6,4,18))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(2.5,1.2,7.8)
	process.gravity = Vector3(0,-0.005,0)
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.014,0.014)
	var mat := _material(Color(0.42,0.43,0.42,0.12),1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	dust.draw_pass_1 = quad
	root_node.add_child(dust)
	dust.emitting = true

func _build_narrative_lighting(root_node: Node3D) -> void:
	var rope_rim := OmniLight3D.new()
	rope_rim.name = "ColdNooseRimLight"
	rope_rim.position = Vector3(0.0, 2.20, -5.72)
	rope_rim.light_color = Color(0.37, 0.44, 0.51)
	rope_rim.light_energy = 2.18
	rope_rim.omni_range = 3.65
	rope_rim.omni_attenuation = 1.78
	rope_rim.shadow_enabled = true
	root_node.add_child(rope_rim)
	var noose_key := SpotLight3D.new()
	noose_key.name = "RestrainedNooseFocus"
	noose_key.position = Vector3(-0.35, 2.65, -0.35)
	noose_key.light_color = Color(0.43, 0.39, 0.31)
	noose_key.light_energy = 3.0
	noose_key.spot_range = 7.6
	noose_key.spot_angle = 19.0
	noose_key.spot_attenuation = 1.7
	noose_key.shadow_enabled = true
	root_node.add_child(noose_key)
	noose_key.look_at(Vector3(0.0, 1.55, -4.75), Vector3.UP)
	var incense_fill := OmniLight3D.new()
	incense_fill.name = "IncenseColdVisibilityFill"
	incense_fill.position = Vector3(0.0, 1.15, -2.25)
	incense_fill.light_color = Color(0.23, 0.29, 0.34)
	incense_fill.light_energy = 1.42
	incense_fill.omni_range = 3.3
	incense_fill.omni_attenuation = 1.9
	incense_fill.shadow_enabled = false
	root_node.add_child(incense_fill)
	var rear_readability := OmniLight3D.new()
	rear_readability.name = "VeryWeakRearWallReadability"
	rear_readability.position = Vector3(0,2.15,-9.55)
	rear_readability.light_color = Color(0.16,0.205,0.25)
	rear_readability.light_energy = 0.72
	rear_readability.omni_range = 4.2
	rear_readability.omni_attenuation = 1.65
	rear_readability.shadow_enabled = false
	root_node.add_child(rear_readability)
	var beam_fill := OmniLight3D.new()
	beam_fill.name = "WeakColdBeamReadability"
	beam_fill.position = Vector3(0,3.05,-2.25)
	beam_fill.light_color = Color(0.17,0.215,0.28)
	beam_fill.light_energy = 0.76
	beam_fill.omni_range = 7.4
	beam_fill.omni_attenuation = 1.55
	beam_fill.shadow_enabled = false
	root_node.add_child(beam_fill)
	var entrance_beam_fill := OmniLight3D.new()
	entrance_beam_fill.name = "EntranceRoofColdSeparation"
	entrance_beam_fill.position = Vector3(0,3.05,4.35)
	entrance_beam_fill.light_color = Color(0.16,0.205,0.27)
	entrance_beam_fill.light_energy = 0.84
	entrance_beam_fill.omni_range = 4.7
	entrance_beam_fill.omni_attenuation = 1.62
	entrance_beam_fill.shadow_enabled = false
	root_node.add_child(entrance_beam_fill)

func _build_clue_audio() -> void:
	paper_audio = AudioStreamPlayer.new()
	paper_audio.name = "DampPaperRustle"
	paper_audio.volume_db = -9.5
	paper_audio.stream = _make_paper_rustle_stream()
	add_child(paper_audio)
	beam_creak_audio = AudioStreamPlayer3D.new()
	beam_creak_audio.name = "SubtleBeamCreak"
	beam_creak_audio.position = Vector3(0,3.28,-5.20)
	beam_creak_audio.volume_db = -13.0
	beam_creak_audio.unit_size = 3.0
	beam_creak_audio.max_distance = 12.0
	beam_creak_audio.stream = _make_beam_creak_stream()
	add_child(beam_creak_audio)

func _make_paper_rustle_stream() -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * 0.58)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19027
	var previous := 0.0
	for i in range(frames):
		var t := float(i) / float(rate)
		var envelope := sin(PI * clampf(t / 0.58,0.0,1.0)) * (0.65 + sin(t * 64.0) * 0.18)
		var noise := rng.randf_range(-1.0,1.0)
		previous = lerpf(previous,noise,0.34)
		bytes.encode_s16(i * 2, int(clampf(previous * envelope * 9200.0,-32767.0,32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_beam_creak_stream() -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * 1.34)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var envelope := pow(maxf(0.0,1.0 - t / 1.34),1.7) * minf(1.0,t * 14.0)
		var pitch_slide := 76.0 - t * 22.0 + sin(t * 9.0) * 3.0
		var tone := sin(TAU * pitch_slide * t) * 0.72 + sin(TAU * (pitch_slide * 2.03) * t) * 0.18
		var grain := sin(TAU * 347.0 * t) * sin(t * 31.0) * 0.08
		bytes.encode_s16(i * 2, int(clampf((tone + grain) * envelope * 5900.0,-32767.0,32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _process(delta: float) -> void:
	super._process(delta)
	var time := Time.get_ticks_msec() * 0.001
	var reaction_elapsed := time - reaction_started_at
	room_reaction = clampf(1.0 - reaction_elapsed / 3.8,0.0,1.0) if reaction_elapsed >= 0.0 else 0.0
	if rope_visual != null and not _return_investigation_active():
		rope_visual.rotation_degrees.z = sin(time * 0.43) * 0.78 + sin(time * 0.17 + 1.2) * 0.22 + sin(reaction_elapsed * 2.4) * room_reaction * 0.92
		rope_visual.rotation_degrees.x = sin(time * 0.31 + 0.7) * 0.16 + sin(reaction_elapsed * 1.7) * room_reaction * 0.26
	if incense_smoke != null:
		incense_smoke.rotation_degrees.z = room_reaction * 12.0
		incense_smoke.rotation_degrees.x = room_reaction * -3.0
	if room_reaction > 0.0:
		for index in range(candle_lights.size()):
			var nervous_flicker := 0.74 + absf(sin(time * (13.0 + index))) * 0.23
			candle_lights[index].light_energy *= lerpf(1.0,nervous_flicker,room_reaction)
	for i in range(flutter_papers.size()):
		var paper := flutter_papers[i]
		var stir: float = coda.paper_stir if coda != null else 0.0
		paper.rotation_degrees.z = sin(time * (0.38 + i * 0.07) + i * 2.1) * 0.72 + sin(time * 2.1 + i) * stir * 5.0
		paper.position.y = 0.052 + maxf(0.0,sin(time * 0.34 + i * 1.7)) * 0.004 + stir * (0.013 + 0.009 * sin(time * 1.8 + i))

func _build_player() -> void:
	super._build_player()
	character_sprite.modulate = Color(0.79,0.83,0.88)
	flashlight.light_color = Color(0.72,0.81,0.92)
	flashlight.light_energy = 3.55
	flashlight.spot_angle = 34.0
	flashlight.spot_attenuation = 1.78
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(0.72,0.38)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0.002,0.003,0.004,0.46)
	shadow_mesh.material = shadow_material
	var contact := MeshInstance3D.new()
	contact.name = "PlayerSoftContactShadow"
	contact.mesh = shadow_mesh
	contact.position = Vector3(0,0.025,0.02)
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(contact)

func _physics_process(delta: float) -> void:
	if coda != null and coda.busy:
		coda.update_player_and_camera(delta)
		return
	if warning_read_open:
		player.velocity = Vector3.ZERO
		_update_animation(false,0.0)
		_update_flashlight()
		_update_camera(delta,0.0)
		return
	var input_2d := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_2d.x, 0.0, input_2d.y)
	var target := direction.normalized() * WALK_SPEED if direction.length_squared() > 0.01 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, target.x, 7.5 * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, 7.5 * delta)
	player.velocity.y = -0.2
	var before := player.global_position
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -ROOM_X, ROOM_X)
	player.position.z = clampf(player.position.z, ROOM_FAR_Z, ROOM_NEAR_Z)
	player.position.y = move_toward(player.position.y, 0.02, delta * 1.8)
	var speed := Vector2(player.position.x - before.x, player.position.z - before.z).length() / maxf(delta, 0.0001)
	_update_facing(direction)
	_update_animation(speed > 0.055, speed)
	_update_flashlight()
	_update_camera(delta, speed)
	_update_hud()

func _build_hud() -> void:
	super._build_hud()
	hud.call("set_objective", "调查王氏旧事的来源" if _has_warning_talisman() else "调查吊绳房间的异常痕迹")
	_build_warning_read_overlay()

func _build_warning_read_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WarningTalismanReadingLayer"
	layer.layer = 90
	add_child(layer)
	var overlay := Control.new()
	overlay.name = "WarningTalismanReading"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	layer.add_child(overlay)
	warning_read_overlay = overlay
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.005,0.007,0.009,0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dimmer)
	var paper := TextureRect.new()
	paper.name = "OldWarningPaperCloseup"
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.offset_left = -305.0
	paper.offset_top = -360.0
	paper.offset_right = 305.0
	paper.offset_bottom = 200.0
	paper.rotation = deg_to_rad(-0.55)
	paper.texture = load("res://assets/ui/reader_old_paper.png") as Texture2D
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.add_child(paper)
	var close_button := Button.new()
	close_button.name = "CloseWarningTalismanReading"
	close_button.text = "×"
	close_button.position = Vector2(548,14)
	close_button.size = Vector2(44,44)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size",30)
	close_button.add_theme_color_override("font_color",Color(0.70,0.66,0.60,0.90))
	close_button.add_theme_color_override("font_hover_color",Color(0.89,0.79,0.64,1.0))
	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = Color(0.06,0.05,0.04,0.78)
	close_normal.border_color = Color(0.28,0.24,0.20,0.72)
	close_normal.set_border_width_all(1)
	var close_hover := close_normal.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.13,0.10,0.08,0.86)
	close_hover.border_color = Color(0.48,0.40,0.30,0.78)
	close_button.add_theme_stylebox_override("normal",close_normal)
	close_button.add_theme_stylebox_override("hover",close_hover)
	close_button.add_theme_stylebox_override("pressed",close_hover)
	close_button.pressed.connect(_close_warning_reading)
	paper.add_child(close_button)
	var font := load("res://assets/fonts/watchnight_chinese.tres") as Font
	var body := _clue_label(paper,"ForbiddenWarning","绳下莫立，香灭即退。\n\n子时之后，勿呼其名。\n\n若闻门后有步声，切莫回头。\n\n王氏旧事，不可再问。",Vector2(94,101),Vector2(432,352),27,Color(0.13,0.095,0.065,0.97),HORIZONTAL_ALIGNMENT_LEFT,font)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var narration_back := Panel.new()
	narration_back.name = "InnerVoicePanel"
	narration_back.set_anchors_preset(Control.PRESET_CENTER)
	narration_back.offset_left = -500.0
	narration_back.offset_top = 214.0
	narration_back.offset_right = 500.0
	narration_back.offset_bottom = 346.0
	var narration_style := StyleBoxFlat.new()
	narration_style.bg_color = Color(0.025,0.021,0.017,0.88)
	narration_style.border_color = Color(0.34,0.245,0.125,0.48)
	narration_style.set_border_width_all(1)
	narration_back.add_theme_stylebox_override("panel",narration_style)
	overlay.add_child(narration_back)
	var narration := _clue_label(narration_back,"ChenMoInnerVoice","纸已经受潮发脆，字迹却异常清楚。\n这不像普通符咒，更像是谁留下的警告。\n‘王氏旧事，不可再问’……\n看来这间房里发生过的事，还远没有结束。",Vector2(32,14),Vector2(936,102),20,Color(0.74,0.68,0.58,0.96),HORIZONTAL_ALIGNMENT_CENTER,font)
	narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clue_label(overlay,"CloseReadingHint","E / ESC  收起黄纸",Vector2(0,0),Vector2(250,30),16,Color(0.61,0.52,0.38,0.86),HORIZONTAL_ALIGNMENT_CENTER,font).set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM,Control.PRESET_MODE_KEEP_SIZE,12)

func _clue_label(parent: Control, node_name: String, label_text: String, position: Vector2, size: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = label_text
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	if font != null:
		label.add_theme_font_override("font",font)
	parent.add_child(label)
	return label

func _update_camera(delta: float, speed: float) -> void:
	# Keep the usual view through the scripted beats. Looking back toward the
	# door as the player walks to it keeps the camera on the inside of the leaf.
	var inspect_door := door_story.stage() >= GameState.HangingDoorStage.PLAYING and player.position.z > 1.75
	if not inspect_door and door_view_weight < 0.002:
		super._update_camera(delta, speed)
		var glance: bool = return_investigation != null and return_investigation.glance_up and player.position.z < -2.15
		truth_glance_weight = lerpf(truth_glance_weight, 1.0 if glance else 0.0, 1.0 - exp(-delta * 3.1))
		camera.rotate_object_local(Vector3.RIGHT, 0.13 * truth_glance_weight)
		return
	truth_glance_weight = 0.0
	var weight := 1.0 - exp(-delta * 4.0)
	door_view_weight = lerpf(door_view_weight, 1.0 if inspect_door else 0.0, weight)
	var p := player.global_position
	var usual := Vector3(clampf(p.x * 0.34, -0.72, 0.72), p.y + 2.72, minf(p.z + 5.30, 10.55))
	var inside := Vector3(clampf(p.x + 1.56, -1.85, 2.12), p.y + 2.20, minf(p.z - 3.35, 4.05))
	var at := p + Vector3(0, 1.02, -2.15)
	var look_in := Basis.looking_at(at - usual, Vector3.UP)
	var look_back := Basis.looking_at(Vector3(p.x * 0.18, 1.23, 7.45) - inside, Vector3.UP)
	camera.global_position = camera.global_position.lerp(usual.lerp(inside, door_view_weight), weight)
	camera.global_basis = look_in.slerp(look_back, door_view_weight)


func _return_target() -> String:
	if coda != null and coda.busy:
		return ""
	var door_target := door_story.inside_target(player.position)
	if not door_target.is_empty():
		return door_target
	return return_investigation.interaction_target(player.position)


func _update_hud() -> void:
	near_exit = player.position.z > 6.70
	if _return_investigation_active():
		var return_target := _return_target()
		if return_target != hud_interaction_target:
			hud_interaction_target = return_target
			hud.call("set_door_prompt_visible", not return_target.is_empty())
			match return_target:
				"exit": hud.call("set_interaction_text", "返回主大堂")
				"inspect_west_door": hud.call("set_interaction_text", "调查房门")
				"open_west_door": hud.call("set_interaction_text", "打开房门")
				_: hud.call("set_interaction_text", return_investigation.prompt_for(return_target))
		return
	near_warning_talisman = warning_talisman != null and warning_talisman.visible and Vector2(player.position.x,player.position.z).distance_to(Vector2(WARNING_TALISMAN_POSITION.x,WARNING_TALISMAN_POSITION.z)) < 1.18
	near_rope = Vector2(player.position.x, player.position.z).distance_to(Vector2(0,-4.85)) < 1.25
	near_stool = Vector2(player.position.x, player.position.z).distance_to(Vector2(0.42,-4.02)) < 1.05
	near_incense = Vector2(player.position.x, player.position.z).distance_to(Vector2(0,-2.62)) < 1.05
	var target := "exit" if near_exit else ("warning_talisman" if near_warning_talisman else ("rope" if near_rope else ("stool" if near_stool else ("incense" if near_incense else ""))))
	if target != hud_interaction_target:
		hud_interaction_target = target
		hud.call("set_door_prompt_visible", not target.is_empty())
		match target:
			"exit": hud.call("set_interaction_text", "返回主大堂")
			"warning_talisman": hud.call("set_interaction_text", "捡起地上的黄纸")
			"rope": hud.call("set_interaction_text", "调查房梁上的吊绳")
			"stool": hud.call("set_interaction_text", "查看被踢倒的木凳")
			"incense": hud.call("set_interaction_text", "查看仍在冒烟的香炉")
			_: hud.call("set_interaction_text", "")
	var stage := 0
	var caption := "门后的雨声突然远了，空气里全是潮湿纸灰的味道"
	if player.position.z < -4.2:
		stage = 2
		caption = "绳圈正对着木凳，梁上的麻绳却像刚被人重新系过"
	elif player.position.z < 0.2:
		stage = 1
		caption = "满地符纸和纸钱之间，三炷香还没有熄灭"
	if stage != story_stage:
		story_stage = stage
		hud.call("set_story_caption", caption, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if warning_read_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_close_warning_reading()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var target := _return_target() if _return_investigation_active() else hud_interaction_target
		if target.is_empty():
			return
		# The scene may be freed by _change_scene(), so consume the event first.
		get_viewport().set_input_as_handled()
		if _return_investigation_active() and target != "exit":
			if target == "inspect_west_door" or target == "open_west_door":
				door_story.interact_inside(target)
			else:
				return_investigation.interact(target)
			return
		match target:
			"exit":
				get_node("/root/GameState").set("return_to_hall_side_door", true)
				_change_scene(MAIN_HALL_PATH)
			"rope": hud.call("set_story_caption", "绳结内侧沾着新鲜木屑，有人不久前动过房梁。", true, true)
			"stool": hud.call("set_story_caption", "凳脚向外折了一道，像是被人仓促踢开。", true, true)
			"incense": hud.call("set_story_caption", "香灰仍有余温。白色纸钱下面压着半张写有陈默名字的黄符。", true, true)
			"warning_talisman": _pick_up_warning_talisman()
			_: pass
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_node("/root/GameState").set("return_to_hall_side_door", true)
		_change_scene(MAIN_HALL_PATH)

func _has_warning_talisman() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and state.has_method("has_item") and bool(state.call("has_item",WARNING_TALISMAN_ID))

func _return_investigation_active() -> bool:
	return return_investigation != null and bool(return_investigation.get("active"))

func _pick_up_warning_talisman() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("add_item"):
		return
	state.call("add_item",WARNING_TALISMAN_ID)
	if warning_talisman != null:
		warning_talisman.visible = false
	near_warning_talisman = false
	hud_interaction_target = ""
	hud.call("set_door_prompt_visible",false)
	hud.call("set_interaction_text","")
	if paper_audio != null:
		paper_audio.play()
	_begin_room_reaction()
	_open_warning_reading()

func _open_warning_reading() -> void:
	warning_read_open = true
	if hud != null:
		hud.set_process_input(false)
	if warning_read_overlay != null:
		warning_read_overlay.visible = true
		warning_read_overlay.modulate.a = 0.0
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_property(warning_read_overlay,"modulate:a",1.0,0.24)
	if rain_audio != null:
		create_tween().tween_property(rain_audio,"volume_db",-22.0,0.32)

func _close_warning_reading() -> void:
	warning_read_open = false
	if hud != null:
		hud.set_process_input(true)
	if warning_read_overlay != null:
		warning_read_overlay.visible = false
	if _return_investigation_active():
		hud.call("set_objective", "调查吊绳房的异常")
		return
	if rain_audio != null:
		create_tween().tween_property(rain_audio,"volume_db",-9.0,0.85)
	hud.call("set_objective","调查王氏旧事的来源")
	hud.call("set_story_caption","王氏旧事被人刻意封住了。主屋里的家谱和旧记录，也许还留着答案。",true,true)
	if wet_footprint_route != null and bool(wet_footprint_route.get("active")):
		wet_footprint_route.call("_sync_objective")

func _begin_room_reaction() -> void:
	if _return_investigation_active():
		return
	reaction_started_at = Time.get_ticks_msec() * 0.001
	var sequence := create_tween()
	sequence.tween_interval(0.30)
	sequence.tween_callback(func() -> void:
		if beam_creak_audio != null:
			beam_creak_audio.play()
	)
