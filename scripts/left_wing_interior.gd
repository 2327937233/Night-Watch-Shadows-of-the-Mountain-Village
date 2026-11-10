extends Node3D

const COURTYARD_SCENE_PATH = "res://scenes/Courtyard3D.tscn"
const ANIMATION_ROOT = "res://assets/characters/animations_dehalo"
const EXTERIOR_HUD_SCENE = preload("res://scenes/UI/ExteriorHUD.tscn")
const WALK_SPEED = 1.72
const MAIN_KEY_ID = "main_house_key"
# SideCabinetTop surface is 1.10 + 0.09 / 2 metres high.
const KEY_PICKUP_POSITION = Vector3(1.85, 1.145, -1.65)
const KEY_VISUAL_SCALE = 0.28
const FOOTSTEP_PATHS = [
	"res://assets/audio/footstep_stone_01.wav",
	"res://assets/audio/footstep_stone_02.wav",
	"res://assets/audio/footstep_stone_03.wav",
	"res://assets/audio/footstep_stone_04.wav",
	"res://assets/audio/footstep_stone_05.wav",
	"res://assets/audio/footstep_stone_06.wav",
]

var player: CharacterBody3D
var character_sprite: AnimatedSprite3D
var flashlight_origin: Node3D
var flashlight: SpotLight3D
var camera: Camera3D
var hud: Control
var rain_audio: AudioStreamPlayer
var footstep_players: Array[AudioStreamPlayer] = []
var footstep_streams: Array[AudioStream] = []
var footstep_voice_index := 0
var last_footstep_index := -1
var facing = "back"
var candle_lights: Array[OmniLight3D] = []
var candle_energy: Array[float] = []
var near_altar := false
var near_exit := false
var near_key := false
var story_stage := -1
var hud_interaction_target := ""
var key_pickup: Node3D


func _ready() -> void:
	randomize()
	_build_environment()
	_build_room()
	_build_player()
	_build_camera()
	_build_hud()
	_build_audio()


func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() * 0.001
	for index in range(candle_lights.size()):
		var pulse = sin(time * (7.1 + index * 0.37) + index * 1.83) * 0.075
		candle_lights[index].light_energy = candle_energy[index] * (0.91 + pulse + randf_range(-0.018, 0.018))


func _physics_process(delta: float) -> void:
	var input_2d = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = Vector3(input_2d.x, 0.0, input_2d.y)
	var target = direction.normalized() * WALK_SPEED if direction.length_squared() > 0.01 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, target.x, 7.5 * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, 7.5 * delta)
	player.velocity.y = -0.2
	var before = player.global_position
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -2.12, 2.12)
	player.global_position.z = clampf(player.global_position.z, -10.00, 7.35)
	var surface_height = 0.18 if player.global_position.z < -9.72 else (0.10 if player.global_position.z < -9.35 else 0.02)
	player.global_position.y = move_toward(player.global_position.y, surface_height, delta * 1.8)
	var speed = Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length() / maxf(delta, 0.0001)
	_update_facing(direction)
	_update_animation(speed > 0.055, speed)
	_update_flashlight()
	_update_camera(delta, speed)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and near_exit:
		get_viewport().set_input_as_handled()
		_return_from_left_wing()
	elif event.is_action_pressed("interact") and near_key:
		get_viewport().set_input_as_handled()
		_pick_up_main_house_key()
	elif event.is_action_pressed("interact") and near_altar:
		if hud != null and hud.has_method("set_story_caption"):
			hud.call("set_story_caption", "香灰还是温的。最中间的牌位背后，刻着一个新名字。", true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_from_left_wing()


func _return_from_left_wing() -> void:
	GameState.return_to_courtyard_from_left_wing = true
	_change_scene(COURTYARD_SCENE_PATH)


func _toggle_flashlight() -> void:
	GameState.flashlight_enabled = not GameState.flashlight_enabled
	flashlight.visible = GameState.flashlight_enabled
	if hud != null and hud.has_method("set_flashlight_enabled"):
		hud.call("set_flashlight_enabled", flashlight.visible)


func _build_environment() -> void:
	var world = WorldEnvironment.new()
	world.name = "OppressiveInteriorEnvironment"
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.003, 0.004, 0.005)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.145, 0.17, 0.205)
	environment.ambient_light_energy = 0.64
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.055, 0.06, 0.065)
	environment.fog_light_energy = 0.20
	environment.fog_density = 0.018
	world.environment = environment
	add_child(world)


func _build_room() -> void:
	var room = Node3D.new()
	room.name = "LeftWingLongRitualRoom"
	add_child(room)
	# World-projected plaster prevents the 21 m side walls from stretching one
	# texture into obvious bands, while keeping dampness continuous across bays.
	var plaster = load("res://materials/architecture/interior_ritual_plaster.tres") as Material
	var damp = _material(Color(0.028, 0.032, 0.030), 0.98)
	var wall_stain = _material(Color(0.055, 0.067, 0.061, 0.34), 0.96)
	wall_stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wood = (load("res://materials/architecture/wet_old_wood.tres") as Material).duplicate(true)
	if wood is ShaderMaterial:
		(wood as ShaderMaterial).set_shader_parameter("uv_repeat", Vector2(1.4, 3.2))
		(wood as ShaderMaterial).set_shader_parameter("material_tint", Color(0.43, 0.31, 0.22, 1.0))
	var dark_wood = _material(Color(0.035, 0.024, 0.019), 0.94)
	var stone = _material(Color(0.080, 0.088, 0.090), 0.84)
	var wet_stone = _material(Color(0.105, 0.120, 0.125), 0.46)
	var floor_brick = load("res://materials/ground/interior_wet_brick.tres") as Material
	var old_red = _material(Color(0.155, 0.035, 0.026), 0.96)
	var old_gold = _material(Color(0.25, 0.155, 0.055), 0.82)
	var ceramic = _material(Color(0.075, 0.070, 0.058), 0.72)
	var paper := ShaderMaterial.new()
	paper.shader = preload("res://shaders/aged_room_paper.gdshader")
	paper.set_shader_parameter("paper_tint", Color(0.49, 0.365, 0.18))
	var faded_cloth = _material(Color(0.095, 0.026, 0.022), 0.98)
	var exposed_earth = _material(Color(0.105, 0.085, 0.062), 0.96)

	# Wet, uneven brick floor and a continuous collision plane.
	_add_box(room, "FloorCollision", Vector3(5.30, 0.16, 21.0), Vector3(0.0, -0.10, -2.0), damp, true)
	for z_index in range(22):
		for x_index in range(5):
			var variation = (x_index * 17 + z_index * 11) % 7
			var x = -2.08 + x_index * 1.04 + (0.055 if z_index % 2 == 1 else 0.0) + sin(float(variation) * 1.7) * 0.012
			var z = 7.85 - z_index * 0.94 + cos(float(variation) * 1.3) * 0.014
			var width = 0.985 - float(variation % 3) * 0.012
			var depth = 0.895 - float((variation + 1) % 3) * 0.010
			var slab_y = 0.005 + float((variation + 2) % 4) * 0.0012
			var slab = _add_box(room, "OldWetFloorBrick", Vector3(width, 0.038, depth), Vector3(x, slab_y, z), floor_brick)
			slab.rotation_degrees.y = float(variation - 3) * 0.18

	# Thick mixed plaster-and-timber shell with a real doorway at the entrance.
	_add_box(room, "LeftDampPlasterWall", Vector3(0.38, 3.45, 21.0), Vector3(-2.70, 1.68, -2.0), plaster, true)
	_add_box(room, "RightDampPlasterWall", Vector3(0.38, 3.45, 21.0), Vector3(2.70, 1.68, -2.0), plaster, true)
	_add_box(room, "RearRitualWall", Vector3(5.75, 3.45, 0.42), Vector3(0.0, 1.68, -12.30), plaster, true)
	_add_box(room, "EntranceWallLeft", Vector3(1.92, 3.45, 0.38), Vector3(-1.92, 1.68, 8.32), plaster, true)
	_add_box(room, "EntranceWallRight", Vector3(1.92, 3.45, 0.38), Vector3(1.92, 1.68, 8.32), plaster, true)
	_add_box(room, "EntranceHeader", Vector3(2.05, 0.62, 0.42), Vector3(0.0, 3.08, 8.30), wood)
	for x in [-2.46, 2.46]:
		_add_box(room, "WallRootRottenTimber", Vector3(0.28, 3.34, 0.28), Vector3(x, 1.69, -2.0), wood, true)
	for z in [7.20, 3.40, -0.40, -4.20, -8.00, -11.65]:
		for x in [-2.47, 2.47]:
			_add_box(room, "OldLoadBearingPost", Vector3(0.30, 3.28, 0.30), Vector3(x, 1.66, z), wood, true)
		_add_box(room, "CeilingCrossBeam", Vector3(5.35, 0.24, 0.32), Vector3(0.0, 3.34, z), dark_wood)
	for x in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		_add_box(room, "LongRoofPurlin", Vector3(0.18, 0.18, 20.7), Vector3(x, 3.57, -2.0), dark_wood)
	_build_wall_finish(room, plaster, wood, dark_wood, damp, wall_stain, exposed_earth, paper)
	_build_ritual_dais(room, stone, wet_stone, dark_wood)

	# Uneven dampness, peeling substrate and rain-return streaks.
	for side in [-1.0, 1.0]:
		var wall_x = side * 2.49
		for data in [[6.1, 0.72, 0.62], [2.2, 1.65, 0.44], [-2.1, 0.92, 0.78], [-6.4, 1.92, 0.56], [-9.4, 0.68, 0.86]]:
			var mold_patch = _add_box(room, "IrregularMoldPatch", Vector3(0.025, float(data[2]), 0.62), Vector3(wall_x, float(data[1]), float(data[0])), wall_stain)
			mold_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for z in [5.3, 0.8, -3.7, -8.2]:
			var damp_streak = _add_box(room, "VerticalDampStreak", Vector3(0.022, 1.05, 0.07), Vector3(wall_x, 2.14, z), wall_stain)
			damp_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_entrance_props(room, wood, dark_wood, ceramic)
	_build_middle_ritual_traces(room, wood, dark_wood, paper, faded_cloth, old_gold)
	_build_key_pickup(room)
	_build_altar(room, wood, dark_wood, old_red, faded_cloth, old_gold, ceramic, paper)
	_build_dust_motes(room)

	# Weak cold rain spill from the open entrance; warm light remains at the altar.
	var entrance_light = SpotLight3D.new()
	entrance_light.name = "ColdRainLightFromCourtyard"
	entrance_light.position = Vector3(0.0, 2.50, 7.90)
	entrance_light.light_color = Color(0.27, 0.36, 0.46)
	entrance_light.light_energy = 1.75
	entrance_light.spot_range = 9.4
	entrance_light.spot_angle = 39.0
	entrance_light.spot_attenuation = 1.75
	entrance_light.shadow_enabled = true
	room.add_child(entrance_light)
	entrance_light.look_at(Vector3(0.0, 0.16, 0.25), Vector3.UP)
	# Three alternating wall bounces reveal construction without flattening the
	# centre aisle into evenly lit gameplay space.
	for data in [[-1.18, 1.52, 4.15, 1.32, 4.55], [1.22, 1.56, 0.15, 1.26, 4.45], [-1.18, 1.50, -3.85, 1.40, 4.55]]:
		var aisle_fill = OmniLight3D.new()
		aisle_fill.name = "AlternatingColdWallBounce"
		aisle_fill.position = Vector3(float(data[0]), float(data[1]), float(data[2]))
		aisle_fill.light_color = Color(0.26, 0.32, 0.38)
		aisle_fill.light_energy = float(data[3])
		aisle_fill.omni_range = float(data[4])
		aisle_fill.omni_attenuation = 1.58
		aisle_fill.shadow_enabled = false
		room.add_child(aisle_fill)
	# A restrained roof-leak sliver separates the ritual dais from the room. It
	# provides cold/warm contrast without implying an electric light source.
	var roof_leak = SpotLight3D.new()
	roof_leak.name = "WeakColdRoofLeak"
	roof_leak.position = Vector3(0.62, 3.42, -7.10)
	roof_leak.light_color = Color(0.27, 0.35, 0.43)
	roof_leak.light_energy = 0.58
	roof_leak.spot_range = 4.25
	roof_leak.spot_angle = 24.0
	roof_leak.spot_attenuation = 2.2
	roof_leak.shadow_enabled = false
	room.add_child(roof_leak)
	roof_leak.look_at(Vector3(-0.42, 0.08, -8.78), Vector3.UP)


func _build_wall_finish(root: Node3D, plaster: Material, wood: Material, dark_wood: Material, damp: Material, wall_stain: Material, exposed_earth: Material, paper: Material) -> void:
	# Separate inner plaster bays and timber framing keep both walls readable as
	# architecture instead of one unbroken black surface.
	for side in [-1.0, 1.0]:
		var x = side * 2.485
		var side_name = "Left" if side < 0.0 else "Right"
		for bay in range(5):
			var z = 5.25 - float(bay) * 3.75
			_add_box(root, "InsetAgedPlasterBay_%s_%02d" % [side_name, bay], Vector3(0.032, 2.30, 3.26), Vector3(x, 1.82, z), plaster)
			_add_box(root, "WetTimberWainscot_%s_%02d" % [side_name, bay], Vector3(0.055, 0.68, 3.34), Vector3(x - side * 0.025, 0.46, z), dark_wood)
			_add_box(root, "BayUpperRail_%s_%02d" % [side_name, bay], Vector3(0.075, 0.13, 3.42), Vector3(x - side * 0.035, 3.00, z), wood)

	# Local failures reveal mud substrate and timber laths without turning the
	# walls into a uniform noisy texture.
	for data in [[-1.0, 2.08, 2.10], [1.0, 1.72, -3.82], [-1.0, 1.22, -7.45]]:
		var side = float(data[0])
		var x = side * 2.455
		var z = float(data[2])
		_add_box(root, "ExposedMudSubstrate", Vector3(0.038, 0.88, 1.08), Vector3(x, float(data[1]), z), exposed_earth)
		for strip in range(4):
			var lath = _add_box(root, "ExposedWallLath", Vector3(0.052, 0.065, 0.94), Vector3(x - side * 0.028, float(data[1]) - 0.30 + strip * 0.20, z), wood)
			lath.rotation_degrees.x = -3.0 + strip * 2.0

	for data in [[-1.0, 2.25, 5.72, -24.0], [1.0, 2.00, 0.15, 19.0], [-1.0, 1.76, -5.55, 31.0], [1.0, 2.38, -8.40, -17.0]]:
		var side = float(data[0])
		var crack = _add_box(root, "HairlineWallCrack", Vector3(0.046, 0.72, 0.035), Vector3(side * 2.43, float(data[1]), float(data[2])), wall_stain)
		crack.rotation_degrees.x = float(data[3])
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A handful of soaked ritual papers act as narrative accents, not wallpaper.
	for data in [[-1.0, 1.75, -0.85, -8.0], [1.0, 2.16, -5.02, 6.0], [-1.0, 2.32, -8.72, 11.0]]:
		var side = float(data[0])
		var remnant = _add_box(root, "WallSoakedTalismanRemnant", Vector3(0.045, 0.48, 0.22), Vector3(side * 2.405, float(data[1]), float(data[2])), paper)
		remnant.rotation_degrees.x = float(data[3])

	# Sparse cobweb strands catch only the strongest side light.
	var web_material = _material(Color(0.34, 0.35, 0.33, 0.24), 1.0)
	web_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for corner in [[-2.28, 3.15, 6.72], [2.28, 3.14, -7.62]]:
		for angle in [-38.0, 0.0, 38.0]:
			var strand = _add_box(root, "DustyCobwebStrand", Vector3(0.018, 0.018, 0.76), Vector3(float(corner[0]), float(corner[1]), float(corner[2])), web_material)
			strand.rotation_degrees.x = angle


func _build_ritual_dais(root: Node3D, stone: Material, wet_stone: Material, dark_wood: Material) -> void:
	_add_box(root, "RitualDaisLowerStep", Vector3(4.78, 0.08, 0.52), Vector3(0.0, 0.04, -9.46), wet_stone)
	_add_box(root, "RitualDaisUpperStep", Vector3(4.52, 0.08, 0.46), Vector3(0.0, 0.12, -9.86), stone)
	_add_box(root, "RaisedRitualPlatform", Vector3(4.64, 0.16, 2.18), Vector3(0.0, 0.16, -10.96), dark_wood)
	for x in [-2.12, 2.12]:
		_add_box(root, "DaisEdgeBand", Vector3(0.12, 0.22, 2.16), Vector3(x, 0.20, -10.96), stone)


func _build_entrance_props(root: Node3D, wood: Material, dark_wood: Material, ceramic: Material) -> void:
	# Broken cabinet, stool, basket and jars keep the centre aisle readable.
	_add_box(root, "BrokenCabinetBody", Vector3(0.78, 1.36, 1.28), Vector3(-2.08, 0.69, 5.55), dark_wood, true)
	_add_box(root, "CabinetRaisedTop", Vector3(0.92, 0.10, 1.42), Vector3(-2.08, 1.41, 5.55), wood)
	for z in [5.13, 5.55, 5.97]:
		_add_box(root, "CabinetFrontDivider", Vector3(0.07, 1.10, 0.06), Vector3(-1.64, 0.79, z), wood)
	for y in [0.46, 0.85, 1.22]:
		var drawer = _add_box(root, "HalfOpenDrawer", Vector3(0.50, 0.22, 0.94), Vector3(-1.62, y, 5.55), wood, true)
		drawer.rotation_degrees.y = -4.0
	_add_box(root, "OldLowStool", Vector3(0.58, 0.46, 0.58), Vector3(1.86, 0.24, 6.10), wood, true)
	_add_cylinder(root, "EntranceClayJar", 0.38, 0.72, Vector3(1.94, 0.36, 4.86), ceramic, true)
	_add_cylinder(root, "CollapsedBambooBasket", 0.43, 0.62, Vector3(-1.92, 0.31, 3.88), wood, true)
	for data in [[2.02, 1.02, 4.05, -10.0], [2.12, 0.82, 3.72, 8.0]]:
		var board = _add_box(root, "LeaningRottenBoard", Vector3(0.16, 1.58, 0.34), Vector3(float(data[0]), float(data[1]), float(data[2])), wood, true)
		board.rotation_degrees.z = float(data[3])


func _build_middle_ritual_traces(root: Node3D, wood: Material, dark_wood: Material, paper: Material, old_red: Material, old_gold: Material) -> void:
	_add_box(root, "SideOfferingCabinet", Vector3(0.82, 1.05, 1.55), Vector3(2.02, 0.54, -1.25), dark_wood, true)
	_add_box(root, "SideCabinetTop", Vector3(0.96, 0.09, 1.70), Vector3(2.02, 1.10, -1.25), wood)
	_add_box(root, "OldOfferingPlate", Vector3(0.42, 0.05, 0.42), Vector3(1.78, 1.10, -1.20), old_gold)
	_add_candle(root, Vector3(1.92, 1.34, -0.82), old_red, dark_wood, 0.72)
	var curtain = _add_box(root, "TornRitualCurtain", Vector3(0.035, 2.25, 1.20), Vector3(-2.47, 2.05, -3.10), old_red)
	curtain.rotation_degrees.x = -3.0
	# A half-collapsed screen narrows the sightline but leaves the centre route open.
	for panel in range(3):
		var screen = _add_box(root, "BrokenFoldingScreenPanel", Vector3(0.10, 1.64, 0.68), Vector3(-2.05 + panel * 0.18, 0.84, -1.30 - panel * 0.68), dark_wood, true)
		screen.rotation_degrees.y = 5.0 + panel * 6.0
		_add_box(root, "ScreenTornPaper", Vector3(0.025, 1.18, 0.49), screen.position + Vector3(0.07, 0.08, 0.0), paper)
	for z in [1.30, -4.90]:
		_add_cylinder(root, "AbandonedKneelingCushion", 0.42, 0.09, Vector3(1.35 if z > 0.0 else -1.25, 0.07, z), old_red)
	for index in range(3):
		_add_box(root, "WallSideStorageCrate", Vector3(0.68, 0.52, 0.76), Vector3(2.12, 0.27 + index * 0.08, 2.20 - index * 0.64), wood, true)
	for data in [[-1.85, 0.045, 0.2, -5.0], [1.55, 0.048, -2.8, 12.0], [-0.75, 0.05, -4.0, -9.0]]:
		var talisman = _add_box(root, "FallenSoakedTalisman", Vector3(0.24, 0.018, 0.48), Vector3(float(data[0]), float(data[1]), float(data[2])), paper)
		talisman.rotation_degrees.y = float(data[3])
	for data in [[1.72, 0.052, 3.35, -14.0], [-1.62, 0.051, -2.75, 8.0], [0.72, 0.052, -6.15, 21.0]]:
		var scrap = _add_box(root, "ScatteredFamilyRecordScrap", Vector3(0.34, 0.016, 0.28), Vector3(float(data[0]), float(data[1]), float(data[2])), paper)
		scrap.rotation_degrees.y = float(data[3])
	for x in [-1.1, -0.85, 0.95]:
		_add_box(root, "IncenseAshTrace", Vector3(0.24, 0.012, 0.11), Vector3(x, 0.038, -5.05 + x * 0.12), old_gold)


func _build_key_pickup(root: Node3D) -> void:
	key_pickup = Node3D.new()
	key_pickup.name = "MainHouseKeyPickup"
	key_pickup.position = KEY_PICKUP_POSITION
	key_pickup.rotation_degrees.y = -16.0
	# About 21 cm long; visual scale must not shrink the pickup reach.
	key_pickup.scale = Vector3.ONE * KEY_VISUAL_SCALE
	root.add_child(key_pickup)
	var bronze = _material(Color(0.34, 0.22, 0.10), 0.62)
	bronze.metallic = 0.72
	var ring = MeshInstance3D.new()
	ring.name = "OldKeyRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.075
	torus.outer_radius = 0.135
	torus.rings = 18
	torus.ring_segments = 12
	torus.material = bronze
	ring.mesh = torus
	ring.position = Vector3(-0.20, 0.035, 0.0)
	key_pickup.add_child(ring)
	_add_box(key_pickup, "OldKeyShaft", Vector3(0.48, 0.045, 0.065), Vector3(0.10, 0.035, 0.0), bronze)
	_add_box(key_pickup, "OldKeyToothLong", Vector3(0.065, 0.045, 0.16), Vector3(0.30, 0.035, 0.055), bronze)
	_add_box(key_pickup, "OldKeyToothShort", Vector3(0.065, 0.045, 0.12), Vector3(0.38, 0.035, 0.035), bronze)
	# No solid rectangular fake shadow: it made the prop look like a plaque.
	# A tiny, shadowless bounce keeps the key readable behind the candle stand.
	var glint = OmniLight3D.new()
	glint.name = "RestrainedKeyGlint"
	glint.position = Vector3(0.0, 0.34, 0.0)
	glint.light_color = Color(0.67, 0.47, 0.26)
	glint.light_energy = 0.28
	glint.omni_range = 1.05
	glint.omni_attenuation = 1.4
	glint.shadow_enabled = false
	key_pickup.add_child(glint)
	key_pickup.visible = not _has_main_house_key()


func _pick_up_main_house_key() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("add_item"):
		return
	if not bool(game_state.call("add_item", MAIN_KEY_ID)):
		return
	if key_pickup != null:
		key_pickup.visible = false
	near_key = false
	hud_interaction_target = ""
	if hud.has_method("set_door_prompt_visible"):
		hud.call("set_door_prompt_visible", false)
	if hud.has_method("set_objective"):
		hud.call("set_objective", "使用钥匙打开主屋大门")
	if hud.has_method("set_story_caption"):
		hud.call("set_story_caption", "获得：主屋铜钥匙。钥齿间还沾着未冷的香灰。", true, true)


func _has_main_house_key() -> bool:
	var game_state = get_node_or_null("/root/GameState")
	return game_state != null and game_state.has_method("has_item") and bool(game_state.call("has_item", MAIN_KEY_ID))


func _build_altar(root: Node3D, wood: Material, dark_wood: Material, old_red: Material, faded_cloth: Material, old_gold: Material, ceramic: Material, paper: Material) -> void:
	# The rear plaster remains visible between separate rotten drapes; the old
	# single red slab read as a stage backdrop instead of a shrine assembled in
	# a decaying room.
	for data in [[-1.64, 2.08, 0.54, 2.46, -2.0], [1.60, 2.02, 0.61, 2.34, 3.0]]:
		var drape = _add_box(root, "FadedShrineSideDrape", Vector3(float(data[2]), float(data[3]), 0.055), Vector3(float(data[0]), float(data[1]), -12.035), faded_cloth)
		drape.rotation_degrees.z = float(data[4])
	_add_box(root, "ShrineRottenUpperValance", Vector3(3.68, 0.30, 0.065), Vector3(-0.04, 3.18, -12.01), faded_cloth)
	for data in [[-1.28, 2.82, 0.22, 0.78, -3.0], [-0.86, 2.90, 0.17, 0.56, 2.0], [1.02, 2.86, 0.20, 0.70, -2.0], [1.38, 2.94, 0.16, 0.48, 4.0]]:
		var torn_tail = _add_box(root, "TornShrineClothTail", Vector3(float(data[2]), float(data[3]), 0.06), Vector3(float(data[0]), float(data[1]), -11.96), faded_cloth)
		torn_tail.rotation_degrees.z = float(data[4])
	for x in [-2.02, 2.02]:
		_add_box(root, "ShrineBackdropPost", Vector3(0.24, 2.94, 0.28), Vector3(x, 2.00, -11.92), wood)
	_add_box(root, "ShrineBackdropLintel", Vector3(4.35, 0.28, 0.30), Vector3(0.0, 3.39, -11.92), dark_wood)
	_add_box(root, "ShrineInnerCanopy", Vector3(3.52, 0.18, 0.48), Vector3(0.0, 2.96, -11.78), wood)
	for x in [-1.48, -0.74, 0.0, 0.74, 1.48]:
		var bracket = _add_box(root, "ShrineCanopyBracket", Vector3(0.18, 0.34, 0.22), Vector3(x, 2.79, -11.66), dark_wood)
		bracket.rotation_degrees.z = 45.0
	for x in [-1.72, 1.72]:
		_add_box(root, "ShrineInnerPost", Vector3(0.15, 2.36, 0.20), Vector3(x, 1.94, -11.76), dark_wood)
	var clan_mark = Label3D.new()
	clan_mark.name = "FadedWangClanMark"
	clan_mark.text = "王"
	clan_mark.font = load("res://assets/fonts/watchnight_chinese.tres") as Font
	clan_mark.font_size = 96
	clan_mark.pixel_size = 0.0062
	clan_mark.modulate = Color(0.25, 0.16, 0.085, 0.58)
	clan_mark.outline_modulate = Color(0.025, 0.012, 0.009, 0.70)
	clan_mark.outline_size = 7
	clan_mark.position = Vector3(0.0, 2.76, -11.79)
	root.add_child(clan_mark)
	# Multi-layered tabletop, apron frames and feet make the altar read as a
	# heavy piece of joinery rather than a dark rectangular block.
	_add_box(root, "AncestorAltarTop", Vector3(3.82, 0.24, 1.10), Vector3(0.0, 1.34, -10.82), wood, true)
	_add_box(root, "AncestorAltarFrontLip", Vector3(3.98, 0.13, 0.16), Vector3(0.0, 1.39, -10.23), dark_wood)
	_add_box(root, "AncestorAltarRearLip", Vector3(3.78, 0.10, 0.13), Vector3(0.0, 1.40, -11.37), dark_wood)
	for z in [-11.14, -10.79, -10.44]:
		_add_box(root, "AgedTabletopBoardSeam", Vector3(3.54, 0.018, 0.025), Vector3(0.0, 1.468, z), dark_wood)
	_add_box(root, "AncestorAltarApron", Vector3(3.52, 0.48, 0.18), Vector3(0.0, 1.04, -10.30), dark_wood, true)
	_add_box(root, "AncestorAltarLowerStretcher", Vector3(3.18, 0.16, 0.22), Vector3(0.0, 0.53, -10.72), wood)
	for panel_index in range(3):
		var x = -1.16 + float(panel_index) * 1.16
		_add_box(root, "AltarApronPanelTop", Vector3(0.86, 0.055, 0.035), Vector3(x, 1.21, -10.19), wood)
		_add_box(root, "AltarApronPanelBottom", Vector3(0.86, 0.055, 0.035), Vector3(x, 0.88, -10.19), wood)
		for side_offset in [-0.41, 0.41]:
			_add_box(root, "AltarApronPanelSide", Vector3(0.045, 0.35, 0.035), Vector3(x + side_offset, 1.045, -10.19), wood)
		if panel_index != 1:
			var relief_size = 0.24 if panel_index == 0 else 0.21
			var carving = _add_box(root, "AltarApronFadedRelief", Vector3(relief_size, relief_size, 0.045), Vector3(x + (0.015 if panel_index == 2 else -0.01), 1.045, -10.165), old_gold)
			carving.rotation_degrees.z = 42.0 if panel_index == 0 else 49.0
		else:
			# The central ornament has split and partly fallen away.
			var broken_relief = _add_box(root, "AltarApronBrokenRelief", Vector3(0.09, 0.24, 0.045), Vector3(x - 0.055, 1.045, -10.165), old_gold)
			broken_relief.rotation_degrees.z = 38.0
	for x in [-1.55, 1.55]:
		_add_box(root, "AncestorAltarLeg", Vector3(0.30, 1.18, 0.34), Vector3(x, 0.73, -10.82), dark_wood, true)
		_add_box(root, "AncestorAltarFoot", Vector3(0.58, 0.16, 0.54), Vector3(x, 0.28, -10.74), wood, true)
		_add_box(root, "AncestorAltarKneeBrace", Vector3(0.18, 0.50, 0.24), Vector3(x - signf(x) * 0.22, 0.94, -10.67), wood).rotation_degrees.z = signf(x) * 33.0

	var tablets = [
		[-1.34, 0.30, 0.68, ""], [-0.88, 0.34, 0.80, "王\n氏\n宗\n亲\n之\n灵\n位"],
		[-0.43, 0.34, 0.88, ""], [0.0, 0.46, 1.08, "王\n氏\n先\n祖\n之\n位"],
		[0.46, 0.34, 0.88, ""], [0.90, 0.34, 0.80, "王\n氏\n宗\n亲\n之\n灵\n位"],
		[1.34, 0.30, 0.68, ""]
	]
	for index in range(tablets.size()):
		var data = tablets[index]
		_build_spirit_tablet(root, index, float(data[0]), float(data[1]), float(data[2]), str(data[3]), wood, dark_wood, old_gold)

	_add_cylinder(root, "CentralIncenseBurner", 0.34, 0.40, Vector3(0.0, 1.66, -10.28), ceramic)
	_add_cylinder(root, "IncenseBurnerRim", 0.42, 0.08, Vector3(0.0, 1.84, -10.28), old_gold)
	_add_cylinder(root, "IncenseAshBed", 0.31, 0.025, Vector3(0.0, 1.89, -10.28), paper)
	for x in [-0.41, 0.41]:
		var burner_handle = _add_cylinder(root, "IncenseBurnerAgedHandle", 0.055, 0.24, Vector3(x, 1.74, -10.28), old_gold)
		burner_handle.rotation_degrees.z = 90.0
	for offset in [[-0.17, 0.0], [0.08, -0.12], [0.12, 0.12]]:
		_add_cylinder(root, "IncenseBurnerFoot", 0.045, 0.16, Vector3(float(offset[0]), 1.44, -10.28 + float(offset[1])), old_gold)
	for x in [-0.09, 0.0, 0.09]:
		_add_cylinder(root, "BurningIncenseStick", 0.014, 0.82, Vector3(x, 2.18, -10.28), old_red)
		_add_cylinder(root, "IncenseAshTip", 0.015, 0.08, Vector3(x, 2.61, -10.28), paper)
	_build_incense_smoke(root, Vector3(0.0, 2.60, -10.28))
	_add_candle(root, Vector3(-1.48, 1.90, -10.24), old_red, dark_wood, 1.44)
	_add_candle(root, Vector3(1.42, 1.86, -10.30), old_red, dark_wood, 1.32)
	for x in [-0.78, 0.76]:
		_add_cylinder(root, "DustyOfferingBowl", 0.26, 0.13, Vector3(x, 1.55, -10.22), ceramic)
		for offset in [-0.10, 0.08]:
			var fruit = _add_sphere(root, "ShriveledOfferingFruit", 0.115, Vector3(x + offset, 1.69, -10.22 + absf(offset) * 0.3), paper)
			fruit.scale = Vector3(0.92, 0.72 + absf(offset) * 0.7, 1.04)
			var stem = _add_cylinder(root, "DriedOfferingFruitStem", 0.009, 0.08, fruit.position + Vector3(0.0, 0.115, 0.0), dark_wood)
			stem.rotation_degrees.z = 9.0 + offset * 40.0
	for x in [-1.05, 1.05]:
		_add_cylinder(root, "OldTeaCup", 0.10, 0.14, Vector3(x, 1.55, -10.02), ceramic)
	for x in [-1.65, -0.25, 0.38, 1.62]:
		_add_box(root, "OldCandleWax", Vector3(0.07, 0.025, 0.13), Vector3(x, 1.475, -10.18), paper)
	for data in [[-0.55, -10.03, -6.0], [0.32, -10.00, 12.0]]:
		var yellow_paper = _add_box(root, "AltarFoldedYellowPaper", Vector3(0.34, 0.022, 0.26), Vector3(float(data[0]), 1.475, float(data[1])), paper)
		yellow_paper.rotation_degrees.y = float(data[2])
	_build_family_register(root, wood, old_gold, paper)
	var altar_focus = SpotLight3D.new()
	altar_focus.name = "RestrainedAltarFocus"
	altar_focus.position = Vector3(0.0, 2.85, -7.55)
	altar_focus.light_color = Color(0.70, 0.43, 0.24)
	altar_focus.light_energy = 0.88
	altar_focus.spot_range = 4.8
	altar_focus.spot_angle = 37.0
	altar_focus.spot_attenuation = 2.05
	altar_focus.shadow_enabled = true
	root.add_child(altar_focus)
	altar_focus.look_at(Vector3(0.0, 1.70, -10.72), Vector3.UP)
	for x in [-1.42, 1.42]:
		var apron_bounce = OmniLight3D.new()
		apron_bounce.name = "WeakAltarApronBounce"
		apron_bounce.position = Vector3(x, 1.12, -9.95)
		apron_bounce.light_color = Color(0.60, 0.36, 0.20)
		apron_bounce.light_energy = 0.16
		apron_bounce.omni_range = 1.75
		apron_bounce.omni_attenuation = 1.85
		apron_bounce.shadow_enabled = false
		root.add_child(apron_bounce)


func _build_spirit_tablet(root: Node3D, index: int, x: float, width: float, height: float, inscription: String, wood: Material, dark_wood: Material, old_gold: Material) -> void:
	var base_y = 1.50
	_add_box(root, "TabletBase_%02d" % index, Vector3(width + 0.16, 0.10, 0.28), Vector3(x, base_y, -10.88), wood)
	_add_box(root, "TabletSteppedBase_%02d" % index, Vector3(width + 0.07, 0.09, 0.22), Vector3(x, base_y + 0.09, -10.89), dark_wood)
	_add_box(root, "AncestorSpiritTablet_%02d" % index, Vector3(width, height, 0.14), Vector3(x, base_y + 0.14 + height * 0.5, -10.92), dark_wood)
	_add_box(root, "TabletShoulder_%02d" % index, Vector3(width + 0.06, 0.085, 0.16), Vector3(x, base_y + 0.13 + height, -10.92), dark_wood)
	_add_box(root, "TabletInsetFace_%02d" % index, Vector3(width * 0.72, height * 0.70, 0.025), Vector3(x, base_y + 0.15 + height * 0.50, -10.835), dark_wood)
	for side in [-1.0, 1.0]:
		var shoulder = _add_box(root, "TabletCarvedShoulder_%02d" % index, Vector3(0.065, 0.125, 0.17), Vector3(x + side * (width * 0.5 + 0.025), base_y + 0.11 + height, -10.92), dark_wood)
		shoulder.rotation_degrees.z = side * 34.0
	# Two worn sloping pieces form a traditional peaked crown. The previous
	# circular caps looked like detached heads when read from the aisle.
	for side in [-1.0, 1.0]:
		var crown_bar = _add_box(root, "TabletPeakedCrown_%02d" % index, Vector3(width * 0.44, 0.065, 0.17), Vector3(x + side * width * 0.10, base_y + 0.185 + height, -10.92), dark_wood)
		crown_bar.rotation_degrees.z = -side * 27.0
	_add_box(root, "TabletCrownSpine_%02d" % index, Vector3(0.045, 0.12, 0.16), Vector3(x, base_y + 0.235 + height, -10.92), dark_wood)
	if inscription.is_empty():
		_add_box(root, "TabletFadedInscription_%02d" % index, Vector3(0.028, height * 0.54, 0.018), Vector3(x, base_y + 0.15 + height * 0.50, -10.805), old_gold)
		return
	var label = Label3D.new()
	label.name = "TabletReadableInscription_%02d" % index
	label.text = inscription
	label.font = load("res://assets/fonts/watchnight_chinese.tres") as Font
	label.font_size = 42
	label.pixel_size = 0.00225 if index == 3 else 0.00185
	label.modulate = Color(0.69, 0.43, 0.16, 0.94)
	label.outline_modulate = Color(0.025, 0.012, 0.006, 0.90)
	label.outline_size = 5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(x, base_y + 0.14 + height * 0.50, -10.795)
	root.add_child(label)


func _build_family_register(root: Node3D, wood: Material, old_gold: Material, paper: Material) -> void:
	var book = _add_box(root, "WangClanGenealogyBook", Vector3(0.54, 0.085, 0.38), Vector3(1.18, 1.515, -10.05), wood)
	book.rotation_degrees.y = -11.0
	_add_box(root, "GenealogyAgedPageBlock", Vector3(0.48, 0.035, 0.33), Vector3(1.18, 1.565, -10.05), paper).rotation_degrees.y = -11.0
	var title = Label3D.new()
	title.name = "WangClanGenealogyTitle"
	title.text = "王氏家谱"
	title.font = load("res://assets/fonts/watchnight_chinese.tres") as Font
	title.font_size = 40
	title.pixel_size = 0.0020
	title.modulate = Color(0.64, 0.39, 0.13, 0.96)
	title.outline_modulate = Color(0.04, 0.018, 0.008, 0.9)
	title.outline_size = 4
	title.position = Vector3(1.18, 1.615, -10.02)
	title.rotation_degrees = Vector3(-67.0, 0.0, -11.0)
	root.add_child(title)
	_add_box(root, "GenealogyBrokenClasp", Vector3(0.08, 0.025, 0.10), Vector3(1.38, 1.617, -10.02), old_gold)


func _build_dust_motes(root: Node3D) -> void:
	var dust = GPUParticles3D.new()
	dust.name = "SlowDustAndAshMotes"
	dust.position = Vector3(0.0, 1.65, -2.2)
	dust.amount = 52
	dust.lifetime = 9.0
	dust.randomness = 0.72
	dust.visibility_aabb = AABB(Vector3(-2.6, -1.6, -9.4), Vector3(5.2, 3.3, 18.8))
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(2.35, 1.45, 8.7)
	process.direction = Vector3(0.12, 0.22, -0.05)
	process.spread = 42.0
	process.initial_velocity_min = 0.006
	process.initial_velocity_max = 0.025
	process.gravity = Vector3(0.0, -0.004, 0.0)
	dust.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(0.018, 0.018)
	var dust_material = StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.albedo_color = Color(0.57, 0.54, 0.46, 0.20)
	dust_material.albedo_texture = _soft_particle_texture()
	quad.material = dust_material
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dust)
	dust.emitting = true


func _add_candle(root: Node3D, position: Vector3, wax: Material, metal: Material, energy: float) -> void:
	_add_cylinder(root, "OldCandleStand", 0.12, 0.42, position - Vector3(0.0, 0.23, 0.0), metal, true)
	_add_cylinder(root, "DrippingWaxCandle", 0.075, 0.48, position + Vector3(0.0, 0.20, 0.0), wax)
	var wick_material = _material(Color(0.045, 0.032, 0.023), 0.95)
	_add_cylinder(root, "CharredCandleWick", 0.005, 0.034, position + Vector3(0.0, 0.452, 0.0), wick_material)
	for index in range(4):
		var angle = index * 1.61 + candle_lights.size() * 0.8
		var length = 0.07 + float(index % 3) * 0.038
		_add_cylinder(root, "HardenedWaxDrip", 0.009, length, position + Vector3(cos(angle) * 0.069, 0.40 - length * 0.5, sin(angle) * 0.069), wax)
	var flame = MeshInstance3D.new()
	flame.name = "SmallCandleFlame"
	flame.position = position + Vector3(0.0, 0.502, 0.0)
	var flame_quad = QuadMesh.new()
	flame_quad.size = Vector2(0.095, 0.13)
	var flame_material = ShaderMaterial.new()
	flame_material.shader = preload("res://shaders/ritual_candle_flame.gdshader")
	flame_material.set_shader_parameter("phase", float(candle_lights.size()) * 1.83)
	flame_quad.material = flame_material
	flame.mesh = flame_quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flame)
	var light = OmniLight3D.new()
	light.name = "UnstableCandleLight_%02d" % candle_lights.size()
	light.position = position + Vector3(0.0, 0.48, 0.08)
	light.light_color = Color(1.0, 0.58, 0.29)
	light.light_energy = energy * 0.78
	light.omni_range = 3.25 if energy > 1.0 else 2.25
	light.omni_attenuation = 1.95
	# Only the two altar candles cast dynamic shadows; the side candle is an
	# emission-led storytelling light and does not need another shadow map.
	light.shadow_enabled = energy > 1.0
	root.add_child(light)
	candle_lights.append(light)
	# Store the calibrated value used by the flicker loop. Keeping the original
	# input here silently restored the over-bright orange light every frame.
	candle_energy.append(energy * 0.78)


func _build_incense_smoke(root: Node3D, position: Vector3) -> void:
	var smoke = GPUParticles3D.new()
	smoke.name = "ThinIncenseSmoke"
	smoke.position = position
	smoke.amount = 24
	smoke.lifetime = 5.0
	smoke.visibility_aabb = AABB(Vector3(-0.5, -0.2, -0.5), Vector3(1.0, 2.5, 1.0))
	var process = ParticleProcessMaterial.new()
	process.direction = Vector3(0.05, 1.0, 0.02)
	process.spread = 7.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.13
	process.gravity = Vector3(0.008, 0.015, 0.0)
	var fade = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var fade_texture = GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(0.10, 0.23)
	var smoke_material = StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.albedo_color = Color(0.35, 0.33, 0.28, 0.15)
	smoke_material.albedo_texture = _soft_particle_texture()
	smoke_material.vertex_color_use_as_albedo = true
	quad.material = smoke_material
	smoke.draw_pass_1 = quad
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)
	smoke.emitting = true


func _soft_particle_texture() -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)])
	var texture = GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "ChenMo"
	player.position = Vector3(0.0, 0.02, 6.65)
	add_child(player)
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.50
	collision.shape = capsule
	collision.position.y = 0.76
	player.add_child(collision)
	character_sprite = AnimatedSprite3D.new()
	character_sprite.name = "CharacterSprite"
	character_sprite.position = Vector3(0.0, 0.92, 0.0)
	character_sprite.pixel_size = 0.00242
	character_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	character_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	character_sprite.alpha_scissor_threshold = 0.16
	character_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	character_sprite.shaded = false
	character_sprite.modulate = Color(0.84, 0.87, 0.90)
	character_sprite.sprite_frames = _build_character_frames()
	character_sprite.frame_changed.connect(_on_character_frame_changed)
	player.add_child(character_sprite)
	var edge_blend := Node.new()
	edge_blend.name = "CharacterEdgeBlend"
	edge_blend.set_script(preload("res://scripts/character_edge_blend.gd"))
	character_sprite.add_child(edge_blend)
	character_sprite.play("idle_back")
	flashlight_origin = Node3D.new()
	player.add_child(flashlight_origin)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.76, 0.84, 0.94)
	flashlight.light_energy = 3.85
	flashlight.spot_range = 10.6
	flashlight.spot_angle = 31.5
	flashlight.spot_attenuation = 1.45
	flashlight.shadow_enabled = true
	flashlight.visible = GameState.flashlight_enabled
	flashlight_origin.add_child(flashlight)
	for path in FOOTSTEP_PATHS:
		var stream = load(path) as AudioStream
		if stream != null:
			footstep_streams.append(stream)
	for index in range(2):
		var step_player = AudioStreamPlayer.new()
		step_player.name = "InteriorFootstep%d" % (index + 1)
		step_player.volume_db = -13.5
		player.add_child(step_player)
		footstep_players.append(step_player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "InteriorFollowCamera"
	camera.current = true
	camera.fov = 50.0
	camera.position = player.position + Vector3(0.0, 2.72, 5.30)
	add_child(camera)
	camera.look_at(player.position + Vector3(0.0, 1.02, -2.2), Vector3.UP)


func _build_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "HUDLayer"
	add_child(canvas)
	hud = EXTERIOR_HUD_SCENE.instantiate() as Control
	hud.name = "InteriorHUD"
	canvas.add_child(hud)
	if hud.has_method("set_objective"):
		hud.call("set_objective", "使用钥匙打开主屋大门" if _has_main_house_key() else "在厢房祭台附近寻找线索")
	if hud.has_method("set_flashlight_enabled"):
		hud.call("set_flashlight_enabled", flashlight.visible)
	if hud.has_method("set_door_prompt_visible"):
		hud.call("set_door_prompt_visible", false, true)


func _build_audio() -> void:
	rain_audio = AudioStreamPlayer.new()
	rain_audio.bus = &"Ambience"
	rain_audio.name = "MuffledRainOutside"
	rain_audio.volume_db = -9.0
	add_child(rain_audio)
	var stream = load("res://assets/audio/thunderstorm_2min_loop.mp3") as AudioStream
	if stream is AudioStreamMP3:
		stream.loop = true
	rain_audio.stream = stream
	if rain_audio.stream != null:
		rain_audio.play()


func _update_facing(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return
	if absf(direction.x) > absf(direction.z):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "back" if direction.z < 0.0 else "front"


func _update_animation(moving: bool, speed: float) -> void:
	var animation = ("walk_" if moving else "idle_") + facing
	if character_sprite.animation != animation:
		var preserve_phase := moving and str(character_sprite.animation).begins_with("walk_")
		var phase_frame := character_sprite.frame
		var phase_progress := character_sprite.frame_progress
		character_sprite.play(animation)
		if preserve_phase:
			character_sprite.set_frame_and_progress(phase_frame, phase_progress)
	var target_scale := clampf(speed / WALK_SPEED, 0.35, 1.05) if moving else 1.0
	character_sprite.speed_scale = lerpf(character_sprite.speed_scale, target_scale, 1.0 - exp(-get_physics_process_delta_time() * 12.0))


func _update_flashlight() -> void:
	match facing:
		"front": flashlight_origin.rotation_degrees = Vector3(-12.0, 180.0, 0.0)
		"left": flashlight_origin.rotation_degrees = Vector3(-12.0, 90.0, 0.0)
		"right": flashlight_origin.rotation_degrees = Vector3(-12.0, -90.0, 0.0)
		_: flashlight_origin.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	flashlight_origin.position = Vector3(0.24 if facing != "left" else -0.24, 0.92, -0.05)


func _update_camera(delta: float, speed: float) -> void:
	var desired = player.global_position + Vector3(0.0, 2.72, 5.30)
	desired.x = clampf(desired.x * 0.34, -0.72, 0.72)
	desired.z = minf(desired.z, 10.55)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.5))
	var bob = sin(Time.get_ticks_msec() * 0.012) * 0.008 * clampf(speed / WALK_SPEED, 0.0, 1.0)
	camera.look_at(player.global_position + Vector3(0.0, 1.02 + bob, -2.15), Vector3.UP)


func _update_hud() -> void:
	near_exit = player.global_position.z > 6.78
	near_altar = player.global_position.z < -9.25 and absf(player.global_position.x) < 1.55
	near_key = key_pickup != null and key_pickup.visible and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(KEY_PICKUP_POSITION.x, KEY_PICKUP_POSITION.z)) <= 1.28
	var interaction_target = "exit" if near_exit else ("key" if near_key else ("altar" if near_altar else ""))
	if interaction_target != hud_interaction_target:
		hud_interaction_target = interaction_target
		if hud.has_method("set_door_prompt_visible"):
			hud.call("set_door_prompt_visible", not interaction_target.is_empty())
		if hud.has_method("set_interaction_text"):
			match interaction_target:
				"exit": hud.call("set_interaction_text", "返回雨夜庭院")
				"key": hud.call("set_interaction_text", "拾取主屋铜钥匙")
				"altar": hud.call("set_interaction_text", "查看供桌上的牌位")
				_: hud.call("set_interaction_text", "")
	var stage = 0
	var text = "雨声被木门隔在身后，屋里只剩潮湿的霉味"
	if player.global_position.z < -7.0:
		stage = 2
		text = "尽头的香火……似乎不久前才有人续过"
	elif player.global_position.z < 0.5:
		stage = 1
		text = "地上的黄符都朝着供桌的方向"
	if stage != story_stage:
		story_stage = stage
		if hud.has_method("set_story_caption"):
			hud.call("set_story_caption", text, true)


func _on_character_frame_changed() -> void:
	if not character_sprite.animation.begins_with("walk_") or character_sprite.frame not in [0, 4]:
		return
	if footstep_players.is_empty() or footstep_streams.is_empty():
		return
	var index = randi_range(0, footstep_streams.size() - 1)
	if footstep_streams.size() > 1 and index == last_footstep_index:
		index = (index + randi_range(1, footstep_streams.size() - 1)) % footstep_streams.size()
	last_footstep_index = index
	var step_player = footstep_players[footstep_voice_index]
	footstep_voice_index = (footstep_voice_index + 1) % footstep_players.size()
	step_player.stream = footstep_streams[index]
	step_player.pitch_scale = randf_range(0.93, 1.02)
	step_player.volume_db = randf_range(-14.5, -12.5)
	step_player.play()


func _build_character_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for direction in ["front", "back", "left", "right"]:
		_add_character_sequence(frames, "idle_" + direction, "chen_mo_%s_idle" % direction, 6, 3.2)
		_add_character_sequence(frames, "walk_" + direction, "chen_mo_%s_walk" % direction, 8, 9.0)
	return frames


func _add_character_sequence(frames: SpriteFrames, animation: String, prefix: String, count: int, fps: float) -> void:
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, true)
	for index in range(count):
		var path = "%s/%s_%02d.png" % [ANIMATION_ROOT, prefix, index]
		if ResourceLoader.exists(path):
			frames.add_frame(animation, load(path) as Texture2D)


func _add_box(root: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	root.add_child(instance)
	if solid:
		var body = StaticBody3D.new()
		body.name = node_name + "Collision"
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(size.x + 0.08, size.y, size.z + 0.08)
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _add_cylinder(root: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	root.add_child(instance)
	if solid:
		var body = StaticBody3D.new()
		body.name = node_name + "Collision"
		var collision = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = radius + 0.06
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _add_sphere(root: Node3D, node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	root.add_child(instance)
	return instance


func _material(color: Color, roughness: float, emission := Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission.r + emission.g + emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.65
	return material


func _change_scene(path: String) -> void:
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", path)
	else:
		get_tree().change_scene_to_file(path)
