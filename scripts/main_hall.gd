extends "res://scripts/left_wing_interior.gd"

# The courtyard already changes to InteriorPlaceholder.tscn. Keeping that path
# preserves the working key/door flow while replacing its black placeholder.
const HALL_X_LIMIT := 6.18
const HALL_NEAR_Z := 7.32
const HALL_FAR_Z := -11.66
const HANGING_ROOM_PATH := "res://scenes/HangingSideRoom.tscn"
const STUDY_ROOM_PATH := "res://scenes/WangStudyRoom.tscn"
const SEALED_BEDROOM_PATH := "res://scenes/SealedBedroom.tscn"
const FINAL_INVESTIGATION_SCRIPT = preload("res://scripts/main_hall_final_investigation.gd")
const WET_FOOTPRINT_ROUTE_SCENE = preload("res://scenes/story/YuelanFootprintRoute.tscn")
const DOOR_STORY_SCRIPT = preload("res://scripts/hanging_room_door_story.gd")
const HAMMER_POSITION := Vector3(-5.92, 0.555, -2.23)
const BREAK_DOOR_POSITION := Vector3(-6.77, 0.0, -4.32)
const STUDY_DOOR_POSITION := Vector3(6.77, 0.0, 0.20)
const SEALED_BEDROOM_DOOR_POSITION := Vector3(6.77, 0.0, -8.84)
var hammer_pickup: Node3D
var breakable_leaf: MeshInstance3D
var breakable_boards: Node3D
var breakable_blocker: StaticBody3D
var study_breakable_leaf: MeshInstance3D
var study_breakable_boards: Node3D
var study_breakable_blocker: StaticBody3D
var sealed_bedroom_leaf: MeshInstance3D
var hammer_busy := false:
	set(value):
		hammer_busy = value
		if is_inside_tree():
			GameState.set_night_clock_hold(self, value)
var final_investigation: Node
var wet_footprint_route: Node3D
var west_door_story: DOOR_STORY_SCRIPT
var final_empty_tablet_trace: Node3D
var final_altar_seam_visual: Node3D
var final_secret_panel: Node3D
var final_secret_compartment: Node3D
var final_confession_visual: Node3D
var final_burned_letter_visual: Node3D
var final_lock_plate_visual: Node3D
var final_hairpin_fragment_visual: Node3D
var final_rope_segment_visual: Node3D

func _ready() -> void:
	var returning_from_final_bedroom := bool(_hall_state().get("return_to_hall_sealed_door")) and bool(_hall_state().get("final_chapter_started"))
	super._ready()
	if bool(_hall_state().get("return_to_hall_study_door")):
		_hall_state().set("return_to_hall_study_door", false)
		player.position = Vector3(5.55, 0.02, 0.20)
		facing = "right"
		character_sprite.play("idle_right")
		camera.position = player.position + Vector3(-2.2, 2.65, 4.8)
		camera.look_at(player.position + Vector3(0.6, 1.0, 0.0), Vector3.UP)
		_update_flashlight()
	elif bool(_hall_state().get("return_to_hall_sealed_door")):
		_hall_state().set("return_to_hall_sealed_door", false)
		player.position = Vector3(5.55, 0.02, -8.84)
		facing = "right"
		character_sprite.play("idle_right")
		camera.position = player.position + Vector3(-2.2, 2.65, 4.8)
		camera.look_at(player.position + Vector3(0.6, 1.0, 0.0), Vector3.UP)
		_update_flashlight()
	elif bool(_hall_state().get("return_to_hall_side_door")):
		_hall_state().set("return_to_hall_side_door", false)
		player.position = Vector3(-5.55, 0.02, -4.32)
		facing = "left"
		character_sprite.play("idle_left")
		camera.position = player.position + Vector3(2.2, 2.65, 4.8)
		camera.look_at(player.position + Vector3(-0.6, 1.0, 0.0), Vector3.UP)
		_update_flashlight()
	if bool(_hall_state().get("final_chapter_started")):
		_apply_final_chapter_hall_state(returning_from_final_bedroom)
	GameState.begin_yuelan_trail_fade()
	final_investigation = FINAL_INVESTIGATION_SCRIPT.new()
	final_investigation.name = "FinalChapterAncestorAltarInvestigation"
	add_child(final_investigation)
	final_investigation.call(
		"setup",
		self,
		hud,
		_hall_state(),
		rain_audio,
		final_empty_tablet_trace,
		final_altar_seam_visual,
		final_secret_panel,
		final_secret_compartment,
		final_confession_visual,
		final_burned_letter_visual,
		final_lock_plate_visual,
		final_hairpin_fragment_visual,
		final_rope_segment_visual
	)
	wet_footprint_route = WET_FOOTPRINT_ROUTE_SCENE.instantiate()
	add_child(wet_footprint_route)
	wet_footprint_route.call("setup", self, _hall_state(), "hall")
	west_door_story = DOOR_STORY_SCRIPT.new()
	west_door_story.name = "WestWingDoorCry"
	add_child(west_door_story)
	west_door_story.setup(self, _hall_state())


func _exit_tree() -> void:
	if is_instance_valid(rain_audio):
		rain_audio.stop()
		rain_audio.stream = null


func _apply_final_chapter_hall_state(restoring_rain: bool) -> void:
	var lantern_lights := find_children("RestrainedGalleryLanternLight", "OmniLight3D", true, false)
	for index in range(lantern_lights.size()):
		if index % 2 == 0:
			var lamp := lantern_lights[index] as OmniLight3D
			lamp.light_energy *= 0.16 if GameState.has_hanging_coda_completed() else 0.0
	var lantern_cores := find_children("LanternAgedPaperCore", "MeshInstance3D", true, false)
	for index in range(lantern_cores.size()):
		if index % 2 == 0:
			var core := lantern_cores[index] as MeshInstance3D
			var material := core.get_active_material(0) as StandardMaterial3D
			if material != null:
				material.emission_energy_multiplier = 0.10 if GameState.has_hanging_coda_completed() else 0.04
				material.albedo_color = Color(0.12, 0.095, 0.070)
	var world := find_child("MainHallColdWarmEnvironment", true, false) as WorldEnvironment
	if world != null and world.environment != null:
		world.environment.adjustment_enabled = true
		world.environment.adjustment_saturation = 0.86
		world.environment.adjustment_brightness = 0.94
	if restoring_rain and rain_audio != null:
		rain_audio.volume_db = -80.0
		rain_audio.play()
		var rain_return := create_tween()
		rain_return.tween_property(rain_audio, "volume_db", -24.0, 2.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hall_state().set("final_chapter_rain_restored", true)
	elif rain_audio != null:
		rain_audio.volume_db = -24.0

func _hall_state() -> Node:
	return get_node("/root/GameState")

func _door_broken() -> bool:
	return bool(_hall_state().get("hall_side_door_broken"))

func _study_door_broken() -> bool:
	return bool(_hall_state().get("study_door_broken"))

func _build_hammer(root_node: Node3D, mats: Dictionary) -> void:
	hammer_pickup = Node3D.new()
	hammer_pickup.name = "OldHammerPickup"
	hammer_pickup.position = HAMMER_POSITION
	hammer_pickup.rotation_degrees.y = -24.0
	root_node.add_child(hammer_pickup)
	# A 36 cm hand tool resting on the existing chest/table, not floating.
	_add_box(hammer_pickup, "WornWoodHandle", Vector3(0.035, 0.035, 0.32), Vector3(0, 0.027, 0.04), mats.wood)
	var iron := _material(Color(0.23, 0.20, 0.16), 0.73)
	iron.metallic = 0.35
	_add_box(hammer_pickup, "ForgedIronHead", Vector3(0.17, 0.065, 0.07), Vector3(0, 0.034, -0.10), iron)
	_add_box(hammer_pickup, "IronHandleCollar", Vector3(0.045, 0.045, 0.06), Vector3(0, 0.029, -0.05), iron)
	hammer_pickup.visible = not _hall_state().has_item("old_hammer")

func _hammer_target() -> String:
	var p := Vector2(player.position.x, player.position.z)
	if hammer_pickup.visible and p.distance_to(Vector2(HAMMER_POSITION.x, HAMMER_POSITION.z)) < 1.15:
		return "hammer"
	if p.distance_to(Vector2(BREAK_DOOR_POSITION.x, BREAK_DOOR_POSITION.z)) < 1.35:
		if west_door_story != null and west_door_story.stage() == GameState.HangingDoorStage.LATCH:
			return "inspect_west_latch"
		return "enter_room" if _door_broken() else "break_door"
	if p.distance_to(Vector2(STUDY_DOOR_POSITION.x, STUDY_DOOR_POSITION.z)) < 1.35:
		return "enter_study_room" if _study_door_broken() else "break_study_door"
	if p.distance_to(Vector2(SEALED_BEDROOM_DOOR_POSITION.x, SEALED_BEDROOM_DOOR_POSITION.z)) < 1.35:
		return "enter_sealed_bedroom" if bool(_hall_state().get("sealed_bedroom_unlocked")) else "unlock_sealed_bedroom"
	return ""

func _play_wood_impact(impact_position: Vector3) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(11025 * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7281
	for i in range(11025):
		var t := float(i) / 22050.0
		var hit := sin(TAU * 135.0 * t) * exp(-t * 24.0) * 0.46
		hit += noise.randf_range(-1.0, 1.0) * exp(-t * 36.0) * 0.38
		hit += noise.randf_range(-1.0, 1.0) * exp(-absf(t - 0.16) * 65.0) * 0.17
		data.encode_s16(i * 2, int(clampf(hit, -1.0, 1.0) * 32767.0))
	stream.data = data
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.position = impact_position + Vector3(0, 1.2, 0)
	sound.volume_db = -8.0
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func _use_hammer_target(target: String) -> void:
	if hammer_busy or target != _hammer_target():
		return
	if target == "enter_room":
		_change_scene(HANGING_ROOM_PATH)
	elif target == "inspect_west_latch":
		west_door_story.inspect_outside()
	elif target == "enter_study_room":
		_change_scene(STUDY_ROOM_PATH)
	elif target == "enter_sealed_bedroom":
		_change_scene(SEALED_BEDROOM_PATH)
	elif target == "unlock_sealed_bedroom":
		if not _hall_state().unlock_sealed_bedroom():
			hud.call("set_story_caption", "无法打开：必须持有书房的旧铜钥匙。", true, true)
			return
		hammer_busy = true
		player.velocity = Vector3.ZERO
		hud.call("set_door_prompt_visible", false)
		hud.call("set_story_caption", "铜钥匙咬住锈蚀的锁芯。门后有一股久未流通的冷气。", true, true)
		_play_wood_impact(SEALED_BEDROOM_DOOR_POSITION)
		var sealed_tween := create_tween()
		sealed_tween.tween_property(sealed_bedroom_leaf, "rotation:y", 1.38, 0.76).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await sealed_tween.finished
		hammer_busy = false
		hud.call("set_objective", "进入封镜旧卧房")
	elif target == "hammer":
		if _hall_state().add_item("old_hammer"):
			hammer_pickup.visible = false
			hud.call("set_story_caption", "获得：旧木柄铁锤。旁边房门上的木条已经腐朽。", true, true)
			hud.call("set_objective", "用铁锤砸开左回廊偏室房门")
	elif target in ["break_door", "break_study_door"]:
		if not _hall_state().has_item("old_hammer"):
			hud.call("set_story_caption", "房门被木条封住了，你必须先找到一把锤子。", true, true)
			return
		hammer_busy = true
		var is_study := target == "break_study_door"
		var target_boards := study_breakable_boards if is_study else breakable_boards
		var target_leaf := study_breakable_leaf if is_study else breakable_leaf
		_play_wood_impact(STUDY_DOOR_POSITION if is_study else BREAK_DOOR_POSITION)
		player.velocity = Vector3.ZERO
		hud.call("set_door_prompt_visible", false)
		hud.call("set_story_caption", "木条应声断裂，门后涌出一股潮冷的气息。", true, true)
		var tween := create_tween()
		tween.tween_property(target_boards, "rotation:x", 0.12, 0.10)
		tween.tween_property(target_boards, "rotation:x", -0.09, 0.10)
		tween.tween_property(target_boards, "position:y", -1.30, 0.22)
		tween.tween_property(target_leaf, "rotation:y", 1.45 if is_study else -1.45, 0.55)
		await tween.finished
		if is_study:
			_hall_state().break_study_door()
		else:
			_hall_state().break_hall_side_door()
		target_boards.hide()
		hammer_busy = false
		hud.call("set_objective", "进入王家旧书房" if is_study else "调查已打开的左回廊偏室")


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "MainHallColdWarmEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.004, 0.006, 0.009)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.215, 0.245, 0.285)
	environment.ambient_light_energy = 1.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.055, 0.066, 0.078)
	environment.fog_light_energy = 0.31
	environment.fog_density = 0.012
	environment.fog_height = 1.0
	environment.fog_height_density = 0.22
	world.environment = environment
	add_child(world)


func _build_room() -> void:
	var hall := Node3D.new()
	hall.name = "MainHall_ExplorableStructure"
	add_child(hall)
	var plaster := (load("res://materials/architecture/interior_ritual_plaster.tres") as Material).duplicate(true)
	var wood := (load("res://materials/architecture/wet_old_wood.tres") as Material).duplicate(true)
	var floor_material := (load("res://materials/ground/interior_wet_brick.tres") as Material).duplicate(true)
	if plaster is ShaderMaterial:
		(plaster as ShaderMaterial).set_shader_parameter("world_tile_scale", Vector2(0.19, 0.24))
		(plaster as ShaderMaterial).set_shader_parameter("plaster_tint", Color(0.44, 0.43, 0.39, 1.0))
		(plaster as ShaderMaterial).set_shader_parameter("damp_tint", Color(0.075, 0.090, 0.085, 1.0))
		(plaster as ShaderMaterial).set_shader_parameter("albedo_gain", 1.08)
		(plaster as ShaderMaterial).set_shader_parameter("normal_strength", 0.52)
		(plaster as ShaderMaterial).set_shader_parameter("weathering_strength", 0.78)
		(plaster as ShaderMaterial).set_shader_parameter("root_dampness", 0.82)
		(plaster as ShaderMaterial).set_shader_parameter("streak_strength", 0.62)
	if wood is ShaderMaterial:
		(wood as ShaderMaterial).set_shader_parameter("uv_repeat", Vector2(1.15, 2.45))
		(wood as ShaderMaterial).set_shader_parameter("material_tint", Color(0.34, 0.255, 0.19, 1.0))
		(wood as ShaderMaterial).set_shader_parameter("normal_strength", 0.68)
		(wood as ShaderMaterial).set_shader_parameter("wetness_amount", 0.56)
	if floor_material is ShaderMaterial:
		(floor_material as ShaderMaterial).set_shader_parameter("tile_repeat", Vector2(1.18, 1.08))
		(floor_material as ShaderMaterial).set_shader_parameter("brick_tint", Color(0.42, 0.46, 0.47, 1.0))
		(floor_material as ShaderMaterial).set_shader_parameter("albedo_gain", 1.06)
		(floor_material as ShaderMaterial).set_shader_parameter("normal_strength", 0.84)
		(floor_material as ShaderMaterial).set_shader_parameter("wetness_amount", 0.60)
	var mats := {
		"plaster": plaster,
		"wood": wood,
		"floor": floor_material,
		"dark_wood": _material(Color(0.033, 0.022, 0.017), 0.88),
		"damp": _material(Color(0.018, 0.024, 0.025), 0.96),
		"stone": _material(Color(0.078, 0.086, 0.091), 0.76),
		"wet_stone": _material(Color(0.105, 0.116, 0.122), 0.43),
		"bronze": _material(Color(0.115, 0.086, 0.052), 0.63),
		"oxidized": _material(Color(0.055, 0.073, 0.063), 0.78),
		"old_red": _material(Color(0.13, 0.032, 0.024), 0.94),
		"old_gold": _material(Color(0.29, 0.18, 0.072), 0.80),
		"paper": _material(Color(0.30, 0.225, 0.12), 0.96),
		"ceramic": _material(Color(0.052, 0.055, 0.052), 0.72),
		"cloth": _material(Color(0.070, 0.021, 0.019), 0.98),
	}
	(mats.bronze as StandardMaterial3D).metallic = 0.18
	(mats.oxidized as StandardMaterial3D).metallic = 0.10
	_build_hall_floor(hall, mats)
	_build_wet_floor_accents(hall, mats)
	_build_hall_shell(hall, mats)
	_build_column_grid(hall, mats)
	_build_side_galleries(hall, mats)
	_build_hammer(hall, mats)
	_build_ritual_dais_and_shrine(hall, mats)
	_build_hall_lighting(hall)
	_build_hall_air(hall)


func _build_hall_floor(root_node: Node3D, mats: Dictionary) -> void:
	_add_box(root_node, "MainHallFloorCollision", Vector3(18.0, 0.18, 24.2), Vector3(0.0, -0.11, -3.45), mats.damp, true)
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(0.89, 0.045, 0.89)
	tile_mesh.material = mats.floor
	var columns := 19
	var rows := 26
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tile_mesh
	multimesh.instance_count = columns * rows
	var instance_index := 0
	for row in range(rows):
		for column in range(columns):
			var seed := (row * 13 + column * 7) % 9
			var x := -8.28 + float(column) * 0.92 + (0.035 if row % 2 == 1 else 0.0)
			var z := 8.0 - float(row) * 0.92
			var y := 0.004 + float(seed % 4) * 0.0014
			var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(float(seed - 4) * 0.18), 0.0))
			basis = basis.scaled(Vector3(0.97 + float(seed % 3) * 0.008, 1.0, 0.97 + float((seed + 1) % 3) * 0.008))
			multimesh.set_instance_transform(instance_index, Transform3D(basis, Vector3(x, y, z)))
			instance_index += 1
	var tiles := MultiMeshInstance3D.new()
	tiles.name = "UnevenWetStoneTiles_MultiMesh"
	tiles.multimesh = multimesh
	root_node.add_child(tiles)


func _build_wet_floor_accents(root_node: Node3D, mats: Dictionary) -> void:
	var puddle_material := StandardMaterial3D.new()
	puddle_material.albedo_color = Color(0.055, 0.075, 0.085, 0.26)
	puddle_material.roughness = 0.20
	puddle_material.metallic = 0.02
	puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for data in [
		[-5.15, 5.25, 1.75, 0.52, -7.0], [4.82, 3.35, 1.38, 0.38, 11.0],
		[-5.72, -0.65, 1.62, 0.44, 8.0], [5.32, -3.72, 1.92, 0.50, -10.0],
		[-2.25, -8.18, 1.20, 0.33, 5.0], [2.68, -9.12, 1.48, 0.36, -6.0]
	]:
		var puddle := _add_box(root_node, "IrregularLowPuddleGlint", Vector3(float(data[2]), 0.012, float(data[3])), Vector3(float(data[0]), 0.034, float(data[1])), puddle_material)
		puddle.rotation_degrees.y = float(data[4])
	# Restrained warm streaks make nearby lanterns read in the wet floor without
	# turning the entire nave into a mirror.
	var warm_glint := StandardMaterial3D.new()
	warm_glint.albedo_color = Color(0.31, 0.15, 0.055, 0.12)
	warm_glint.emission_enabled = true
	warm_glint.emission = Color(0.20, 0.075, 0.018)
	warm_glint.emission_energy_multiplier = 0.18
	warm_glint.roughness = 0.30
	warm_glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-4.75, 4.75]:
		_add_box(root_node, "BrokenLanternReflection", Vector3(0.16, 0.014, 1.72), Vector3(x, 0.038, -4.70), warm_glint)


func _build_hall_shell(root_node: Node3D, mats: Dictionary) -> void:
	_add_box(root_node, "MainHallLeftOuterWall", Vector3(0.42, 5.35, 24.3), Vector3(-9.05, 2.63, -3.45), mats.plaster, true)
	_add_box(root_node, "MainHallRightOuterWall", Vector3(0.42, 5.35, 24.3), Vector3(9.05, 2.63, -3.45), mats.plaster, true)
	_add_box(root_node, "MainHallRearWall", Vector3(18.45, 5.35, 0.46), Vector3(0.0, 2.63, -15.48), mats.plaster, true)
	_add_box(root_node, "EntranceReturnLeft", Vector3(6.95, 5.20, 0.40), Vector3(-5.72, 2.58, 8.47), mats.plaster, true)
	_add_box(root_node, "EntranceReturnRight", Vector3(6.95, 5.20, 0.40), Vector3(5.72, 2.58, 8.47), mats.plaster, true)
	_add_box(root_node, "EntranceHeadBeam", Vector3(4.65, 0.42, 0.52), Vector3(0.0, 4.83, 8.34), mats.wood)
	for x in [-2.34, 2.34]:
		_add_box(root_node, "EntranceThickDoorJamb", Vector3(0.38, 4.78, 0.48), Vector3(x, 2.38, 8.31), mats.wood, true)
	for side in [-1.0, 1.0]:
		var leaf := _add_box(root_node, "OpenedMainDoorLeaf", Vector3(2.04, 4.15, 0.20), Vector3(side * 3.18, 2.10, 7.94), mats.wood)
		leaf.rotation_degrees.y = side * 67.0
		for y in [-1.28, 0.0, 1.28]:
			_add_box(leaf, "DoorLeafOldCrossRail", Vector3(1.78, 0.11, 0.12), Vector3(0.0, y, -0.14), mats.dark_wood)
	_add_box(root_node, "HighDarkCeiling", Vector3(18.0, 0.20, 24.0), Vector3(0.0, 5.52, -3.45), mats.damp)
	for z in [6.55, 3.0, -0.55, -4.1, -7.65, -11.2, -14.55]:
		_add_box(root_node, "MassiveCeilingCrossBeam", Vector3(17.7, 0.30, 0.38), Vector3(0.0, 5.16, z), mats.dark_wood)
		for x in [-7.9, -5.4, -2.75, 0.0, 2.75, 5.4, 7.9]:
			var bracket := _add_box(root_node, "OldBeamBracket", Vector3(0.44, 0.34, 0.30), Vector3(x, 4.92, z), mats.wood)
			bracket.rotation_degrees.z = 45.0
	for x in [-7.55, -5.25, -2.70, 0.0, 2.70, 5.25, 7.55]:
		_add_box(root_node, "LongCeilingPurlin", Vector3(0.22, 0.20, 23.7), Vector3(x, 5.36, -3.45), mats.wood)
	# Dense, shallow rafters give the high roof a readable underside silhouette.
	var rafter_mesh := BoxMesh.new()
	rafter_mesh.size = Vector3(17.35, 0.09, 0.11)
	rafter_mesh.material = mats.wood
	var rafters := MultiMesh.new()
	rafters.transform_format = MultiMesh.TRANSFORM_3D
	rafters.mesh = rafter_mesh
	rafters.instance_count = 32
	for index in range(32):
		var z := 7.70 - float(index) * 0.72
		rafters.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.03, z)))
	var rafter_instances := MultiMeshInstance3D.new()
	rafter_instances.name = "HighRoofRafterRhythm_MultiMesh"
	rafter_instances.multimesh = rafters
	root_node.add_child(rafter_instances)
	# Physical weathering layers keep long walls from becoming pure black planes.
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 8.82
		_add_box(root_node, "ContinuousDampStoneWallBase", Vector3(0.13, 0.52, 23.4), Vector3(x - side * 0.04, 0.26, -3.45), mats.stone)
		for y in [1.02, 3.72]:
			_add_box(root_node, "LongAgedWallTimberRail", Vector3(0.16, 0.18, 23.25), Vector3(x - side * 0.055, y, -3.45), mats.wood)
		for z in [7.15, 3.35, -0.45, -4.25, -8.05, -11.85, -14.55]:
			_add_box(root_node, "ExposedWallTimberStud", Vector3(0.18, 3.42, 0.22), Vector3(x - side * 0.065, 2.34, z), mats.wood)
		for data in [[5.4, 1.05, 1.05], [1.25, 2.15, 0.72], [-3.1, 0.82, 1.26], [-7.2, 2.42, 0.82], [-11.6, 1.20, 1.08]]:
			_add_box(root_node, "WallDampPeelingPatch", Vector3(0.035, float(data[2]), 0.74), Vector3(x, float(data[1]), float(data[0])), mats.damp)
		for z in [6.1, 0.2, -5.7, -11.8]:
			_add_box(root_node, "VerticalRainReturnStain", Vector3(0.025, 1.15, 0.10), Vector3(x - side * 0.03, 1.72, z), mats.damp)


func _build_column_grid(root_node: Node3D, mats: Dictionary) -> void:
	for z in [5.65, 1.85, -1.95, -5.75, -9.55]:
		for x in [-3.45, 3.45]:
			_add_cylinder(root_node, "MassiveWetLoadColumn", 0.36, 4.72, Vector3(x, 2.70, z), mats.wood, true)
			_add_cylinder(root_node, "ColumnStoneFoot", 0.53, 0.30, Vector3(x, 0.16, z), mats.stone, true)
			_add_cylinder(root_node, "ColumnFootUpperRing", 0.45, 0.17, Vector3(x, 0.38, z), mats.stone)
			_add_box(root_node, "ColumnCapitalBlock", Vector3(0.72, 0.25, 0.72), Vector3(x, 4.90, z), mats.dark_wood)
			for direction in [-1.0, 1.0]:
				var brace := _add_box(root_node, "ColumnKneeBrace", Vector3(0.65, 0.14, 0.20), Vector3(x + direction * 0.30, 4.72, z), mats.wood)
				brace.rotation_degrees.z = direction * 32.0


func _build_side_galleries(root_node: Node3D, mats: Dictionary) -> void:
	var room_names := ["SideParlor", "OldStudy", "FamilyRitualSideRoom", "SealedBedroom"]
	var room_z := [4.72, 0.20, -4.32, -8.84]
	for side in [-1.0, 1.0]:
		_add_box(root_node, "GalleryUpperWallSpine", Vector3(0.34, 1.32, 22.7), Vector3(side * 6.98, 4.37, -3.25), mats.plaster)
		_add_box(root_node, "GalleryRootDampSpine", Vector3(0.34, 0.58, 22.7), Vector3(side * 6.98, 0.28, -3.25), mats.plaster)
		for index in range(room_z.size()):
			_build_room_door_module(root_node, side, room_z[index], index, room_names[index], mats)
		for data in [[3.05 + side * 0.18, 0.32], [-2.05 - side * 0.26, 0.46], [-7.05 + side * 0.34, 0.38]]:
			var z := float(data[0])
			var scale := float(data[1])
			_add_box(root_node, "GalleryOldStorageChest", Vector3(0.72, 0.54, 0.94), Vector3(side * 5.92, 0.27, z), mats.dark_wood, true)
			_add_cylinder(root_node, "GalleryDarkCeramicJar", scale, scale * 1.65, Vector3(side * 5.42, scale * 0.82, z - 0.78), mats.ceramic, true)
		_add_hall_lantern(root_node, Vector3(side * 4.82, 3.35, 2.82 + side * 0.18), mats, 1.18)
		_add_hall_lantern(root_node, Vector3(side * 4.82, 3.28, -5.98 - side * 0.24), mats, 0.90)


func _build_room_door_module(root_node: Node3D, side: float, z: float, index: int, room_title: String, mats: Dictionary) -> void:
	var module := Node3D.new()
	module.name = "%s_%s_RoomAnchor" % ["Left" if side < 0.0 else "Right", room_title]
	root_node.add_child(module)
	var x := side * 6.93
	# Each bay receives real infill wall mass and a shallow interior cell. This
	# removes the old continuous-black-strip look while retaining future room hooks.
	for edge in [-1.0, 1.0]:
		_add_box(module, "ThickMottledWallInfill", Vector3(0.30, 2.78, 1.20), Vector3(x, 1.68, z + edge * 1.52), mats.plaster, true)
		_add_box(module, "BayTimberBoundaryPost", Vector3(0.38, 3.30, 0.28), Vector3(x - side * 0.03, 1.76, z + edge * 2.12), mats.wood, true)
	_add_box(module, "RoomCellOldFloor", Vector3(1.86, 0.10, 3.92), Vector3(side * 7.92, 0.03, z), mats.floor)
	for edge in [-1.0, 1.0]:
		_add_box(module, "RoomCellSidePartition", Vector3(1.96, 3.30, 0.16), Vector3(side * 7.96, 1.68, z + edge * 2.02), mats.plaster)
	_add_box(module, "DeepUnlitRoomRecess", Vector3(0.22, 2.72, 1.56), Vector3(x, 1.68, z), mats.damp)
	for edge in [-1.0, 1.0]:
		_add_box(module, "ThickDoorFramePost", Vector3(0.34, 3.08, 0.20), Vector3(x - side * 0.03, 1.74, z + edge * 0.87), mats.wood)
	_add_box(module, "ThickDoorFrameLintel", Vector3(0.34, 0.27, 1.94), Vector3(x - side * 0.03, 3.24, z), mats.dark_wood)
	_add_box(module, "DoorStoneThreshold", Vector3(0.68, 0.15, 1.72), Vector3(x - side * 0.18, 0.075, z), mats.dark_wood)
	var variant := index + (1 if side > 0.0 else 0)
	var leaf_z := z + (-0.35 if variant % 2 == 0 else 0.30)
	var door_leaf := _add_box(module, "HalfClosedWarpedDoor", Vector3(0.16, 2.58, 0.72), Vector3(x - side * 0.16, 1.55, leaf_z), mats.wood)
	door_leaf.rotation_degrees.y = side * (31.0 if variant in [0, 2, 4] else 9.0)
	if side > 0.0 and index == 3:
		# The letter read in the archive changes a real world state: the remote
		# sealed bedroom is found slightly ajar on the player's return.
		door_leaf.rotation_degrees.y = 79.0 if bool(_hall_state().get("sealed_bedroom_unlocked")) else (5.0 if bool(_hall_state().get("study_distant_door_ajar")) else 0.0)
	for bar_index in range(4):
		_add_box(module, "DoorLatticeBar", Vector3(0.06, 2.22, 0.045), Vector3(x - side * 0.27, 1.60, leaf_z - 0.25 + bar_index * 0.17), mats.dark_wood)
	var torn_paper := _add_box(module, "TornWindowPaper", Vector3(0.025, 0.88, 0.52), Vector3(x - side * 0.30, 1.72, z + 0.44), mats.paper)
	torn_paper.rotation_degrees.z = float(variant - 2) * 2.5
	_add_room_story_prop(module, side, z, variant % 4, mats)
	if variant in [0, 2, 4]:
		var room_glow := OmniLight3D.new()
		room_glow.name = "WeakRoomCandleLeak"
		room_glow.position = Vector3(x + side * 0.35, 1.55, z)
		room_glow.light_color = Color(0.82, 0.43, 0.19)
		room_glow.light_energy = 0.72 if index == 0 else 0.48
		room_glow.omni_range = 3.15
		room_glow.omni_attenuation = 2.2
		room_glow.shadow_enabled = false
		module.add_child(room_glow)
	if (side < 0.0 and index == 2) or (side > 0.0 and index == 1):
		# Replace the decorative dark infill with an actual gated passage.
		var is_study_door := side > 0.0
		var is_open := _study_door_broken() if is_study_door else _door_broken()
		module.get_node("DeepUnlitRoomRecess").queue_free()
		for child in module.get_children():
			if str(child.name).begins_with("DoorLatticeBar") or child == torn_paper:
				child.queue_free()
		if is_study_door:
			study_breakable_leaf = door_leaf
		else:
			breakable_leaf = door_leaf
		(door_leaf.mesh as BoxMesh).size = Vector3(0.16, 2.58, 1.48)
		door_leaf.position.z = z
		door_leaf.rotation.y = side * 1.45 if is_open else 0.0
		if not is_study_door:
			DOOR_STORY_SCRIPT.dress_hall_door(self, module, door_leaf, z, mats)
		var sealing_boards := Node3D.new()
		sealing_boards.name = "StudyDoorRottenSealingBoards" if is_study_door else "RottenDoorSealingBoards"
		module.add_child(sealing_boards)
		for y in [1.05, 1.90]:
			_add_box(sealing_boards, "RottenCrossBoard", Vector3(0.09, 0.14, 1.65), Vector3(x - side * 0.31, y, z), mats.wood)
		sealing_boards.visible = not is_open
		var blocker_mesh := _add_box(module, "StudyDoorTransitionBlocker" if is_study_door else "BreakableDoorCollider", Vector3(0.24, 2.7, 1.68), Vector3(x - side * 0.16, 1.4, z), mats.wood, true)
		blocker_mesh.visible = false
		if is_study_door:
			study_breakable_boards = sealing_boards
			study_breakable_blocker = blocker_mesh.get_child(0) as StaticBody3D
		else:
			breakable_boards = sealing_boards
			breakable_blocker = blocker_mesh.get_child(0) as StaticBody3D
	elif side > 0.0 and index == 3:
		# A real locked threshold: the narrow old-letter gap is not a passage.
		module.get_node("DeepUnlitRoomRecess").queue_free()
		for child in module.get_children():
			if str(child.name).begins_with("DoorLatticeBar") or child == torn_paper:
				child.queue_free()
		(door_leaf.mesh as BoxMesh).size = Vector3(0.16, 2.58, 1.48)
		door_leaf.position.z = z
		sealed_bedroom_leaf = door_leaf
		_add_box(module, "OxidizedBedroomLockPlate", Vector3(0.055, 0.27, 0.15), Vector3(x - side * 0.27, 1.40, z + 0.42), mats.bronze)
		_add_box(module, "BlackKeyholeInLockPlate", Vector3(0.012, 0.12, 0.035), Vector3(x - side * 0.305, 1.40, z + 0.42), mats.damp)
		var transition := _add_box(module, "SealedBedroomTransitionBlocker", Vector3(0.25, 2.70, 1.66), Vector3(x - side * 0.16, 1.40, z), mats.wood, true)
		transition.visible = false


func _add_room_story_prop(module: Node3D, side: float, z: float, variant: int, mats: Dictionary) -> void:
	var inner_x := side * 7.75
	match variant:
		0:
			_add_box(module, "ParlorNarrowTable", Vector3(0.72, 0.72, 1.20), Vector3(inner_x, 0.40, z), mats.dark_wood)
			_add_cylinder(module, "ParlorAbandonedTeaJar", 0.17, 0.34, Vector3(inner_x - side * 0.18, 0.94, z + 0.20), mats.ceramic)
		1:
			_add_box(module, "StudyWritingDesk", Vector3(0.88, 0.78, 1.28), Vector3(inner_x, 0.42, z - 0.12), mats.wood)
			for shelf_y in [0.72, 1.23, 1.74]:
				_add_box(module, "StudyWarpedShelf", Vector3(0.32, 0.09, 1.34), Vector3(side * 8.48, shelf_y, z + 0.16), mats.dark_wood)
		2:
			_add_box(module, "SideRitualTable", Vector3(0.82, 0.86, 1.34), Vector3(inner_x, 0.45, z), mats.dark_wood)
			_add_cylinder(module, "SideRitualAshBowl", 0.22, 0.20, Vector3(inner_x - side * 0.20, 0.98, z), mats.bronze)
			_add_candle(module, Vector3(inner_x - side * 0.12, 0.96, z + 0.38), mats.old_red, mats.dark_wood, 0.54)
		3:
			_add_box(module, "SealedRoomLowBed", Vector3(1.35, 0.34, 1.72), Vector3(side * 8.12, 0.20, z), mats.dark_wood)
			var board := _add_box(module, "SealedRoomDiagonalBoard", Vector3(0.10, 2.20, 0.13), Vector3(side * 6.65, 1.70, z), mats.wood)
			board.rotation_degrees.x = 52.0


func _build_ritual_dais_and_shrine(root_node: Node3D, mats: Dictionary) -> void:
	# Walkable height is handled continuously in _physics_process. A solid block
	# here would create an invisible vertical face in front of the visible steps.
	_add_box(root_node, "ShrineDaisMass", Vector3(9.25, 0.54, 4.02), Vector3(0.0, 0.27, -13.30), mats.stone)
	for index in range(3):
		var step_width := 9.05 - float(index) * 0.30
		var step_z := -10.62 - float(index) * 0.46
		var step_y := 0.09 + float(index) * 0.18
		_add_box(root_node, "BroadWornShrineStep", Vector3(step_width, 0.18, 0.54), Vector3(0.0, step_y, step_z), mats.wet_stone)
		_add_box(root_node, "StepWetFrontEdge", Vector3(step_width * 0.96, 0.035, 0.06), Vector3(0.0, step_y + 0.095, step_z + 0.255), mats.wet_stone)
	for side in [-1.0, 1.0]:
		var drape := _add_box(root_node, "ShrineFadedSideDrape", Vector3(0.72, 3.60, 0.07), Vector3(side * 3.55, 3.12, -15.16), mats.cloth)
		drape.rotation_degrees.z = side * 3.5
		_add_box(root_node, "ShrineTallTimberPost", Vector3(0.34, 4.18, 0.38), Vector3(side * 4.15, 2.72, -14.84), mats.wood)
	_add_box(root_node, "ShrineHeavyLintel", Vector3(8.75, 0.38, 0.42), Vector3(0.0, 4.73, -14.86), mats.dark_wood)
	_add_box(root_node, "ShrineCanopy", Vector3(7.45, 0.24, 1.12), Vector3(0.0, 4.48, -14.30), mats.wood)
	for x in [-3.25, -2.15, -1.05, 0.0, 1.05, 2.15, 3.25]:
		var bracket := _add_box(root_node, "ShrineCanopyBracket", Vector3(0.20, 0.44, 0.28), Vector3(x, 4.20, -14.00), mats.dark_wood)
		bracket.rotation_degrees.z = 45.0
	var plaque := Label3D.new()
	plaque.name = "MainHallFadedPlaque"
	plaque.text = "王氏正堂"
	plaque.font = load("res://assets/fonts/watchnight_chinese.tres") as Font
	plaque.font_size = 84
	plaque.pixel_size = 0.0044
	plaque.modulate = Color(0.46, 0.31, 0.13, 0.82)
	plaque.outline_modulate = Color(0.025, 0.014, 0.008, 0.95)
	plaque.outline_size = 8
	plaque.position = Vector3(0.0, 4.76, -14.60)
	root_node.add_child(plaque)
	_build_guardian_deity(root_node, mats)
	_build_main_altar_table(root_node, mats)


func _build_guardian_deity(root_node: Node3D, mats: Dictionary) -> void:
	var statue := Node3D.new()
	statue.name = "WeatheredSeatedGuardianDeity"
	root_node.add_child(statue)
	# A corroded mandorla separates the silhouette from the mottled rear wall.
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.86
	halo_mesh.outer_radius = 1.02
	halo_mesh.rings = 28
	halo_mesh.ring_segments = 12
	halo_mesh.material = mats.oxidized
	var halo := MeshInstance3D.new()
	halo.name = "CorrodedGuardianHalo"
	halo.mesh = halo_mesh
	halo.position = Vector3(0.0, 3.15, -14.48)
	halo.rotation_degrees.x = 90.0
	statue.add_child(halo)
	_add_box(statue, "StatueSteppedPlinth", Vector3(3.15, 0.34, 1.62), Vector3(0.0, 0.78, -14.32), mats.dark_wood)
	_add_box(statue, "StatueUpperPlinth", Vector3(2.58, 0.24, 1.28), Vector3(0.0, 1.06, -14.30), mats.bronze)
	var lower_robe := _add_cylinder(statue, "HeavyFoldedLowerRobe", 0.86, 1.12, Vector3(0.0, 1.64, -14.28), mats.oxidized)
	lower_robe.scale = Vector3(1.34, 1.0, 0.74)
	var torso := _add_cylinder(statue, "GuardianTorso", 0.55, 1.28, Vector3(0.0, 2.53, -14.30), mats.bronze)
	torso.scale = Vector3(1.12, 1.0, 0.68)
	for side in [-1.0, 1.0]:
		var shoulder := _add_sphere(statue, "GuardianShoulder", 0.34, Vector3(side * 0.52, 2.85, -14.29), mats.bronze)
		shoulder.scale = Vector3(1.10, 0.82, 0.72)
		var arm := _add_cylinder(statue, "GuardianBentArm", 0.15, 0.92, Vector3(side * 0.56, 2.36, -14.12), mats.oxidized)
		arm.rotation_degrees.z = side * 17.0
		_add_sphere(statue, "GuardianHand", 0.16, Vector3(side * 0.37, 1.99, -13.86), mats.bronze)
	var head := _add_sphere(statue, "GuardianHead", 0.39, Vector3(0.0, 3.46, -14.24), mats.bronze)
	head.scale = Vector3(0.82, 1.05, 0.76)
	_add_cylinder(statue, "GuardianOldCrown", 0.31, 0.38, Vector3(0.0, 3.83, -14.25), mats.oxidized)
	_add_sphere(statue, "GuardianLeftEar", 0.095, Vector3(-0.31, 3.47, -14.22), mats.oxidized)
	_add_sphere(statue, "GuardianRightEar", 0.095, Vector3(0.31, 3.47, -14.22), mats.oxidized)
	_add_box(statue, "GuardianBrowShadow", Vector3(0.43, 0.055, 0.055), Vector3(0.0, 3.52, -13.95), mats.dark_wood)
	for x in [-0.13, 0.13]:
		_add_sphere(statue, "GuardianDarkEye", 0.035, Vector3(x, 3.48, -13.91), mats.dark_wood)
	var nose := _add_sphere(statue, "GuardianWornNose", 0.075, Vector3(0.0, 3.39, -13.88), mats.bronze)
	nose.scale = Vector3(0.62, 1.18, 0.72)
	_add_box(statue, "GuardianClosedMouth", Vector3(0.18, 0.025, 0.035), Vector3(0.0, 3.26, -13.91), mats.dark_wood)
	for x in [-0.22, 0.0, 0.22]:
		_add_box(statue, "GuardianCrownRidge", Vector3(0.075, 0.42 + (0.08 if x == 0.0 else 0.0), 0.08), Vector3(x, 3.92, -14.02), mats.old_gold)
	for side in [-1.0, 1.0]:
		var collar := _add_box(statue, "GuardianLayeredRobeCollar", Vector3(0.48, 0.10, 0.10), Vector3(side * 0.18, 3.02, -13.84), mats.oxidized)
		collar.rotation_degrees.z = side * 38.0
	_add_box(statue, "GuardianChestSeal", Vector3(0.48, 0.56, 0.08), Vector3(0.0, 2.63, -13.80), mats.oxidized)
	for x in [-0.48, -0.24, 0.0, 0.24, 0.48]:
		var fold := _add_box(statue, "RobeVerticalFold", Vector3(0.09, 1.36 - absf(x) * 0.30, 0.08), Vector3(x, 1.70, -13.74), mats.oxidized)
		fold.rotation_degrees.z = x * 8.0


func _build_main_altar_table(root_node: Node3D, mats: Dictionary) -> void:
	var lacquer := (mats.wood as ShaderMaterial).duplicate() as ShaderMaterial
	lacquer.set_shader_parameter("material_tint", Color(0.44, 0.30, 0.21))
	lacquer.set_shader_parameter("wetness_amount", 0.27)
	lacquer.set_shader_parameter("roughness_floor", 0.72)
	var rubbed_brass := _material(Color(0.20, 0.13, 0.076), 0.80)
	_add_box(root_node, "MainHallAncestorAltarTop", Vector3(5.35, 0.25, 1.18), Vector3(0.0, 1.76, -12.72), mats.wood, true)
	_add_box(root_node, "AltarTopLayeredEdge", Vector3(5.58, 0.08, 1.30), Vector3(0.0, 1.91, -12.70), mats.dark_wood)
	# The false panel occupies one original carved bay.  Splitting the apron
	# around it creates a genuine 42 cm deep recess instead of a dark decal.
	_add_box(root_node, "MainHallAltarFrontApronLeft", Vector3(3.09, 0.62, 0.20), Vector3(-0.995, 1.36, -12.08), mats.dark_wood, true)
	_add_box(root_node, "MainHallAltarFrontApronRight", Vector3(1.17, 0.62, 0.20), Vector3(1.955, 1.36, -12.08), mats.dark_wood, true)
	_add_box(root_node, "MainHallAltarLowerStretcher", Vector3(4.48, 0.17, 0.25), Vector3(0.0, 0.88, -12.52), mats.wood)
	for x in [-2.18, 2.18]:
		_add_box(root_node, "MainHallAltarLeg", Vector3(0.34, 1.38, 0.38), Vector3(x, 1.12, -12.70), mats.dark_wood, true)
		_add_box(root_node, "MainHallAltarFoot", Vector3(0.68, 0.17, 0.62), Vector3(x, 0.59, -12.62), mats.wood)
	for panel in range(5):
		var x := -1.92 + float(panel) * 0.96
		if panel == 3:
			continue
		_add_box(root_node, "AltarPanelTopRail", Vector3(0.76, 0.055, 0.04), Vector3(x, 1.61, -11.955), mats.wood)
		_add_box(root_node, "AltarPanelBottomRail", Vector3(0.76, 0.055, 0.04), Vector3(x, 1.13, -11.955), mats.wood)
		for edge in [-1.0, 1.0]:
			_add_box(root_node, "AltarPanelSideRail", Vector3(0.055, 0.50, 0.04), Vector3(x + edge * 0.39, 1.37, -11.955), mats.wood)
		var relief := _add_box(root_node, "AltarFadedDiamondRelief", Vector3(0.30, 0.30, 0.035), Vector3(x, 1.38, -11.965), lacquer)
		relief.rotation_degrees.z = 45.0
		var inset := _add_box(relief, "CarvedDarkReliefInset", Vector3(0.242, 0.242, 0.010), Vector3(0.0, 0.0, 0.022), mats.dark_wood)
		inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for petal_index in range(4):
			var angle := TAU * float(petal_index) / 4.0
			var petal := _add_box(relief, "WornCarvedPetal", Vector3(0.023, 0.066, 0.013), Vector3(-sin(angle) * 0.044, cos(angle) * 0.044, 0.035), rubbed_brass)
			petal.rotation.z = angle
			petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if panel == 1:
			relief.scale = Vector3(0.58, 0.76, 1.0)
			relief.position.x -= 0.07
	_build_secret_altar_compartment(root_node, mats)
	var runner := _add_box(root_node, "FadedRitualTableRunner", Vector3(0.88, 0.035, 1.42), Vector3(-0.10, 1.945, -12.54), mats.cloth)
	runner.rotation_degrees.y = -1.5
	_add_box(root_node, "TornRunnerFrontTail", Vector3(0.82, 0.72, 0.035), Vector3(-0.10, 1.58, -12.00), mats.cloth)
	# A shallow rear rail makes the ancestral arrangement belong to the altar
	# rather than float against the rear wall.  Its fifth bay carries a subtle
	# discoloration where a tablet stood for years.
	_add_box(root_node, "SpiritTabletRearBackingRail", Vector3(4.54, 0.72, 0.12), Vector3(0.0, 2.27, -13.19), mats.dark_wood)
	var tablet_names := [
		"王公德明之位",
		"王公绍文之位",
		"王公守义之位",
		"王氏历代先祖之位",
		"王承安之位",
		"",
		"王公德全之位",
	]
	for index in range(7):
		var x := (float(index) - 3.0) * 0.62
		if index == 5:
			continue
		var height := 0.94 if index == 3 else (0.73 if index in [2, 4] else 0.60)
		var width := 0.42 if index == 3 else 0.31
		var base := _add_box(root_node, "MainHallTabletBase", Vector3(width + 0.16, 0.10, 0.28), Vector3(x, 1.94, -13.02), mats.wood)
		var tablet := _add_box(root_node, "MainHallSpiritTablet", Vector3(width, height, 0.15), Vector3(x, 2.02 + height * 0.5, -13.04), lacquer)
		var face := _add_box(tablet, "SetBackLacquerTabletFace", Vector3(width - 0.046, height - 0.08, 0.016), Vector3(0.0, 0.0, 0.075), mats.dark_wood)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for edge in [-1.0, 1.0]:
			var bead := _add_box(tablet, "FadedTabletBeading", Vector3(0.012, height - 0.04, 0.018), Vector3(edge * (width * 0.5 - 0.014), 0.0, 0.078), rubbed_brass)
			bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if index == 4:
			base.name = "WangChenganTabletBase"
			tablet.name = "WangChenganSpiritTablet"
		for side in [-1.0, 1.0]:
			var crown := _add_box(root_node, "TabletPeakedCrown", Vector3(width * 0.58, 0.07, 0.16), Vector3(x + side * width * 0.10, 2.05 + height, -13.04), mats.dark_wood)
			crown.rotation_degrees.z = -side * 24.0
		_add_tablet_inscription(
			root_node,
			x,
			2.04 + height * 0.50,
			-12.945,
			str(tablet_names[index]),
			0.0029 if index == 3 else 0.00225
		)
	_build_removed_tablet_trace(root_node, mats, 1.24)
	_build_hidden_altar_seam(root_node, mats)
	_add_cylinder(root_node, "MainHallIncenseBurner", 0.38, 0.44, Vector3(0.0, 2.08, -12.18), mats.ceramic)
	_add_cylinder(root_node, "MainHallIncenseBurnerRim", 0.47, 0.08, Vector3(0.0, 2.28, -12.18), mats.old_gold)
	for x in [-0.10, 0.0, 0.10]:
		_add_cylinder(root_node, "SlowBurningIncense", 0.013, 0.82, Vector3(x, 2.70, -12.18), mats.old_red)
	_build_incense_smoke(root_node, Vector3(0.0, 3.12, -12.18))
	_add_candle(root_node, Vector3(-2.03, 2.03, -12.15), mats.old_red, mats.dark_wood, 1.20)
	_add_candle(root_node, Vector3(1.98, 2.00, -12.18), mats.old_red, mats.dark_wood, 1.12)
	for x in [-1.18, 1.14]:
		_add_cylinder(root_node, "MainHallOfferingPlate", 0.31, 0.10, Vector3(x, 1.94, -12.06), mats.ceramic)
		for offset in [-0.13, 0.10]:
			var fruit := _add_sphere(root_node, "DriedOfferingFruit", 0.13, Vector3(x + offset, 2.07, -12.06), mats.paper)
			fruit.scale.y = 0.78
	# Secondary vessels and dead branches widen the shrine silhouette and avoid a
	# perfectly mirrored showroom composition.
	for data in [[-2.78, -13.22, 0.29], [2.86, -13.34, 0.25]]:
		var urn_x := float(data[0])
		var urn_z := float(data[1])
		var urn_radius := float(data[2])
		_add_cylinder(root_node, "SootDarkenedRitualUrn", urn_radius, 0.58, Vector3(urn_x, 1.05, urn_z), mats.ceramic)
		_add_cylinder(root_node, "RitualUrnWornRim", urn_radius * 1.16, 0.08, Vector3(urn_x, 1.35, urn_z), mats.bronze)
		for branch_index in range(3):
			var branch := _add_box(root_node, "BrittleDeadBranch", Vector3(0.035, 0.78 + branch_index * 0.12, 0.035), Vector3(urn_x + (branch_index - 1) * 0.12, 1.74, urn_z), mats.dark_wood)
			branch.rotation_degrees.z = -14.0 + branch_index * 13.0
	# A fallen offering bowl supplies one controlled imperfection near the dais.
	var fallen_bowl := _add_cylinder(root_node, "FallenOfferingBowl", 0.22, 0.14, Vector3(3.34, 0.69, -11.44), mats.ceramic)
	fallen_bowl.rotation_degrees.z = 78.0


func _build_removed_tablet_trace(root_node: Node3D, mats: Dictionary, trace_x: float) -> void:
	final_empty_tablet_trace = Node3D.new()
	final_empty_tablet_trace.name = "RemovedTabletDustFootprint"
	root_node.add_child(final_empty_tablet_trace)
	var clean_wood := _material(Color(0.105, 0.068, 0.038), 0.91)
	var dust := _material(Color(0.030, 0.024, 0.019), 0.99)
	var abrasion := _material(Color(0.20, 0.125, 0.062), 0.86)
	# The footprint is deliberately low contrast: a cleaner rectangle held
	# inside a heavier dust rim, readable only when the flashlight grazes it.
	_add_box(final_empty_tablet_trace, "CleanerTabletBaseRectangle", Vector3(0.46, 0.009, 0.27), Vector3(trace_x, 1.944, -13.02), clean_wood)
	_add_box(final_empty_tablet_trace, "DustRimFront", Vector3(0.54, 0.012, 0.035), Vector3(trace_x, 1.951, -12.855), dust)
	_add_box(final_empty_tablet_trace, "DustRimBack", Vector3(0.54, 0.012, 0.035), Vector3(trace_x, 1.951, -13.185), dust)
	for side in [-1.0, 1.0]:
		_add_box(final_empty_tablet_trace, "DustRimSide", Vector3(0.035, 0.012, 0.29), Vector3(trace_x + side * 0.27, 1.951, -13.02), dust)
		var rub := _add_box(final_empty_tablet_trace, "RepeatedBaseRub", Vector3(0.22, 0.008, 0.018), Vector3(trace_x + side * 0.12, 1.958, -12.89), abrasion)
		rub.rotation_degrees.y = side * 7.0
	_add_box(final_empty_tablet_trace, "RearBoardFadedTabletShadow", Vector3(0.43, 0.49, 0.014), Vector3(trace_x, 2.26, -13.122), clean_wood)
	final_empty_tablet_trace.visible = false


func _build_hidden_altar_seam(root_node: Node3D, mats: Dictionary) -> void:
	final_altar_seam_visual = Node3D.new()
	final_altar_seam_visual.name = "SubtleMovedAltarPanelSeam"
	root_node.add_child(final_altar_seam_visual)
	var gap := _material(Color(0.006, 0.005, 0.004), 1.0)
	var worn_edge := _material(Color(0.125, 0.070, 0.035), 0.91)
	var raw_wood := _material(Color(0.21, 0.14, 0.075), 0.96)
	# Broken into three slightly misaligned pieces so it cannot read as a clean
	# modern drawer line or an obvious secret-door outline.
	for data in [[0.23, 0.47, -1.1], [0.81, 0.54, 0.6], [1.42, 0.45, -0.8]]:
		var segment := _add_box(final_altar_seam_visual, "UnevenPanelGap", Vector3(float(data[1]), 0.020, 0.018), Vector3(float(data[0]), 1.035, -11.922), gap)
		segment.rotation_degrees.z = float(data[2])
		var wear := _add_box(final_altar_seam_visual, "WornSlidingEdge", Vector3(float(data[1]) * 0.88, 0.014, 0.012), Vector3(float(data[0]), 1.064, -11.910), worn_edge)
		wear.rotation_degrees.z = float(data[2]) * 0.65
	_add_box(final_altar_seam_visual, "PanelEndGap", Vector3(0.020, 0.31, 0.018), Vector3(1.68, 1.17, -11.922), gap)
	for index in range(4):
		var scratch := _add_box(final_altar_seam_visual, "RepeatedPanelScratch", Vector3(0.19 + index * 0.025, 0.010, 0.010), Vector3(0.51 + index * 0.28, 1.105 + index * 0.045, -11.905), raw_wood)
		scratch.rotation_degrees.z = -10.0 + index * 5.0
	for index in range(5):
		var chip := _add_box(final_altar_seam_visual, "SmallOldWoodChip", Vector3(0.025 + (index % 2) * 0.018, 0.012, 0.05), Vector3(0.45 + index * 0.23, 0.575, -11.63 - (index % 2) * 0.07), raw_wood)
		chip.rotation_degrees.y = 17.0 + index * 23.0
	final_altar_seam_visual.visible = false


func _build_secret_altar_compartment(root_node: Node3D, mats: Dictionary) -> void:
	var cavity_dark := _material(Color(0.009, 0.008, 0.007), 1.0)
	var cavity_wood := _material(Color(0.027, 0.020, 0.015), 0.97)
	var raw_wear := _material(Color(0.17, 0.105, 0.054), 0.93)
	var old_paper := _material(Color(0.34, 0.245, 0.135), 0.98)
	var damp_paper := _material(Color(0.18, 0.125, 0.074), 1.0)
	var old_ink := _material(Color(0.030, 0.022, 0.017), 1.0)
	var scorched := _material(Color(0.042, 0.025, 0.016), 1.0)
	var lock_metal := _material(Color(0.090, 0.070, 0.045), 0.62)
	(lock_metal as StandardMaterial3D).metallic = 0.32
	# Kept identical to the old-bedroom fragment so the two halves visibly
	# belong to one blackened, low-lustre silver ornament.
	var old_silver := _material(Color(0.28, 0.29, 0.27), 0.72)
	(old_silver as StandardMaterial3D).metallic = 0.31
	var silver_oxidation := _material(Color(0.055, 0.065, 0.060), 0.94)
	(silver_oxidation as StandardMaterial3D).metallic = 0.12
	var dusty_cloth := _material(Color(0.105, 0.088, 0.071), 1.0)
	# A long-sealed, damp-darkened variant of the west-wing noose material.  It
	# keeps the same rough response and construction while losing the exposed
	# rope's warmer surface colour after years inside the altar.
	var rope_mat := _material(Color(0.19, 0.145, 0.090), 0.95, Color(0.030, 0.019, 0.009))
	(rope_mat as StandardMaterial3D).emission_energy_multiplier = 0.20
	var rope_damp := _material(Color(0.045, 0.038, 0.030), 0.99)

	final_secret_compartment = Node3D.new()
	final_secret_compartment.name = "AncestorAltarSecretCompartment_42cmDeep"
	final_secret_compartment.position = Vector3(0.96, 1.36, -12.16)
	root_node.add_child(final_secret_compartment)
	# Interior dimensions: 0.72 m wide, 0.50 m high, 0.42 m deep.
	_add_box(final_secret_compartment, "CompartmentBack", Vector3(0.72, 0.50, 0.05), Vector3(0.0, 0.0, -0.21), cavity_dark)
	_add_box(final_secret_compartment, "CompartmentFloor", Vector3(0.72, 0.055, 0.42), Vector3(0.0, -0.275, 0.0), cavity_wood)
	_add_box(final_secret_compartment, "CompartmentCeiling", Vector3(0.72, 0.055, 0.42), Vector3(0.0, 0.275, 0.0), cavity_wood)
	for side in [-1.0, 1.0]:
		_add_box(final_secret_compartment, "CompartmentSide", Vector3(0.055, 0.50, 0.42), Vector3(side * 0.385, 0.0, 0.0), cavity_wood)
		_add_box(final_secret_compartment, "CompartmentEdgeWear", Vector3(0.018, 0.44, 0.025), Vector3(side * 0.405, 0.0, 0.205), raw_wear)

	# The evidence is arranged deliberately, suggesting Wang Cheng'an returned
	# to the compartment rather than throwing everything inside.
	final_burned_letter_visual = Node3D.new()
	final_burned_letter_visual.name = "BurnedYuelanLetterBundle"
	final_burned_letter_visual.position = Vector3(-0.235, -0.235, 0.015)
	final_secret_compartment.add_child(final_burned_letter_visual)
	for index in range(3):
		var scrap := _add_box(final_burned_letter_visual, "ScorchedLetterScrap", Vector3(0.18 - index * 0.014, 0.009, 0.17), Vector3(index * 0.008, index * 0.010, -index * 0.008), old_paper if index == 1 else scorched)
		scrap.rotation_degrees.y = -5.0 + index * 5.0
	_add_box(final_burned_letter_visual, "CharredPaperEdge", Vector3(0.18, 0.012, 0.022), Vector3(0.0, 0.036, 0.075), scorched)

	final_confession_visual = Node3D.new()
	final_confession_visual.name = "WangChenganHandwrittenConfession"
	final_confession_visual.position = Vector3(0.0, -0.225, 0.025)
	final_confession_visual.rotation_degrees.y = -2.5
	final_secret_compartment.add_child(final_confession_visual)
	_add_box(final_confession_visual, "DampYellowedConfessionPaper", Vector3(0.25, 0.010, 0.25), Vector3.ZERO, old_paper)
	# Uneven damp margins and staggered ink strokes keep it from reading as a
	# clean modern card while remaining recognizable under the flashlight.
	_add_box(final_confession_visual, "ConfessionDampLeftEdge", Vector3(0.025, 0.013, 0.23), Vector3(-0.113, 0.009, 0.0), damp_paper)
	_add_box(final_confession_visual, "ConfessionTornCorner", Vector3(0.052, 0.013, 0.050), Vector3(0.105, 0.009, -0.102), damp_paper)
	for index in range(6):
		var ink_width := 0.13 - float(index % 3) * 0.016
		var ink := _add_box(final_confession_visual, "HandwrittenInkStroke", Vector3(ink_width, 0.006, 0.008), Vector3(0.012 - float(index % 2) * 0.018, 0.011, -0.078 + index * 0.031), old_ink)
		ink.rotation_degrees.y = -2.0 + index * 0.7

	# A 34 cm damp rope remnant is physically tucked beneath the confession.
	# The controller keeps it hidden and non-interactive until that paper has
	# been picked up, so the reveal is caused by removing the evidence above it.
	final_rope_segment_visual = Node3D.new()
	final_rope_segment_visual.name = "HiddenOldHempRopeSegmentUnderConfession"
	final_rope_segment_visual.position = Vector3(0.0, -0.215, 0.035)
	final_secret_compartment.add_child(final_rope_segment_visual)
	var rope_curve: Array[Vector3] = [
		Vector3(-0.145, 0.0, -0.055),
		Vector3(-0.105, 0.002, -0.094),
		Vector3(-0.048, 0.0, -0.104),
		Vector3(0.010, 0.003, -0.086),
		Vector3(0.058, 0.0, -0.044),
		Vector3(0.098, 0.002, 0.014),
		Vector3(0.120, 0.0, 0.078),
	]
	_add_altar_rope_segments(final_rope_segment_visual, "SameWeaveAsWestWingNoose", rope_curve, 0.036, rope_mat)
	# Sparse blackened fibres and uneven loose ends sell long damp storage
	# without turning the short evidence piece into a complete noose.
	for fibre_index in range(3):
		var fibre_offset := -0.010 + fibre_index * 0.010
		var dark_fibre: Array[Vector3] = []
		for point_index in range(rope_curve.size()):
			var source := rope_curve[point_index]
			dark_fibre.append(source + Vector3(fibre_offset, 0.031, sin(float(point_index + fibre_index) * 1.7) * 0.006))
		_add_altar_rope_segments(final_rope_segment_visual, "BlackenedTwistedFibre", dark_fibre, 0.0042, rope_damp)
	var start_point := rope_curve[0]
	var end_point := rope_curve[rope_curve.size() - 1]
	for strand_index in range(4):
		var side := -1.0 if strand_index % 2 == 0 else 1.0
		var start_fray: Array[Vector3] = [
			start_point,
			start_point + Vector3(-0.022 - strand_index * 0.004, 0.004 + strand_index * 0.003, side * (0.010 + strand_index * 0.003)),
		]
		var end_fray: Array[Vector3] = [
			end_point,
			end_point + Vector3(0.016 + strand_index * 0.004, 0.003 + strand_index * 0.002, side * (0.012 + strand_index * 0.002)),
		]
		_add_altar_rope_segments(final_rope_segment_visual, "RoughFrayedRopeEnd", start_fray, 0.0045, rope_damp)
		_add_altar_rope_segments(final_rope_segment_visual, "RoughFrayedRopeEnd", end_fray, 0.0045, rope_damp)
	for chip_index in range(4):
		var chip := _add_box(final_rope_segment_visual, "OldWoodDustBesideRope", Vector3(0.018 + chip_index * 0.004, 0.005, 0.010), Vector3(-0.11 + chip_index * 0.07, -0.012, 0.105 - (chip_index % 2) * 0.028), raw_wear)
		chip.rotation_degrees.y = -18.0 + chip_index * 13.0
	final_rope_segment_visual.visible = false

	final_lock_plate_visual = Node3D.new()
	final_lock_plate_visual.name = "WestWingOldLockPlateEvidence"
	final_lock_plate_visual.position = Vector3(0.245, -0.220, 0.015)
	final_secret_compartment.add_child(final_lock_plate_visual)
	_add_box(final_lock_plate_visual, "OxidizedLockPlate", Vector3(0.17, 0.025, 0.20), Vector3.ZERO, lock_metal)
	_add_box(final_lock_plate_visual, "WornLockTongue", Vector3(0.045, 0.040, 0.12), Vector3(-0.09, 0.015, 0.0), mats.oxidized)
	for z in [-0.065, 0.065]:
		_add_cylinder(final_lock_plate_visual, "OldLockRivet", 0.018, 0.014, Vector3(0.045, 0.025, z), mats.bronze)

	# A narrower secondary recess is let into the upper-right inner wall.  It
	# shares the main false panel, but its own worn frame makes it read as a
	# deliberately separated hiding place rather than a fourth loose prop.
	var side_niche := Node3D.new()
	side_niche.name = "NarrowSilverHairpinSideCompartment"
	side_niche.position = Vector3(0.255, 0.105, 0.0)
	final_secret_compartment.add_child(side_niche)
	_add_box(side_niche, "SideCompartmentShadowedBack", Vector3(0.205, 0.205, 0.025), Vector3(0.0, 0.0, -0.215), cavity_dark)
	_add_box(side_niche, "SideCompartmentDustyFloor", Vector3(0.215, 0.024, 0.17), Vector3(0.0, -0.112, -0.135), cavity_wood)
	_add_box(side_niche, "AgedClothLining", Vector3(0.175, 0.012, 0.135), Vector3(0.0, -0.094, -0.128), dusty_cloth)
	for side in [-1.0, 1.0]:
		_add_box(side_niche, "SideCompartmentWornFrame", Vector3(0.022, 0.225, 0.12), Vector3(side * 0.116, 0.0, -0.155), raw_wear)
	_add_box(side_niche, "SideCompartmentTopFrame", Vector3(0.25, 0.022, 0.12), Vector3(0.0, 0.116, -0.155), raw_wear)
	for index in range(3):
		var dust_line := _add_box(side_niche, "LongSealedDustTrace", Vector3(0.042 + index * 0.018, 0.006, 0.010), Vector3(-0.055 + index * 0.050, -0.083, -0.062 - index * 0.018), damp_paper)
		dust_line.rotation_degrees.y = -11.0 + index * 9.0

	final_hairpin_fragment_visual = Node3D.new()
	final_hairpin_fragment_visual.name = "OtherHalfSilverHairpinFragment"
	final_hairpin_fragment_visual.position = Vector3(0.0, -0.078, -0.126)
	final_hairpin_fragment_visual.rotation_degrees.y = 31.0
	side_niche.add_child(final_hairpin_fragment_visual)
	var shaft := _add_cylinder(final_hairpin_fragment_visual, "BlackenedSilverShaftHalf", 0.013, 0.19, Vector3(0.0, 0.0, -0.008), old_silver)
	shaft.rotation_degrees.x = 90.0
	var fracture_tooth := _add_cylinder(final_hairpin_fragment_visual, "ComplementaryRaisedFracture", 0.0075, 0.038, Vector3(0.007, 0.0, 0.102), old_silver)
	fracture_tooth.rotation_degrees.x = 90.0
	var pointed_tip := _add_cylinder(final_hairpin_fragment_visual, "WornHairpinPoint", 0.008, 0.055, Vector3(0.0, 0.0, -0.125), old_silver)
	pointed_tip.rotation_degrees.x = 90.0
	var tip_end := _add_sphere(final_hairpin_fragment_visual, "BluntedOldSilverTip", 0.009, Vector3(0.0, 0.0, -0.154), old_silver)
	tip_end.scale = Vector3(0.72, 0.72, 1.18)
	var fracture_notch := _add_box(final_hairpin_fragment_visual, "DarkHalfMoonFractureNotch", Vector3(0.010, 0.008, 0.020), Vector3(-0.008, 0.009, 0.098), silver_oxidation)
	fracture_notch.rotation_degrees.z = 19.0
	for offset in [-0.055, 0.018]:
		var oxide_patch := _add_sphere(final_hairpin_fragment_visual, "LongSealedOxidationPatch", 0.010, Vector3(0.006, 0.009, offset), silver_oxidation)
		oxide_patch.scale = Vector3(0.58, 0.30, 1.45)

	final_secret_panel = Node3D.new()
	final_secret_panel.name = "SlidingAncestorAltarFalsePanel"
	final_secret_panel.position = Vector3(0.96, 1.37, -11.905)
	root_node.add_child(final_secret_panel)
	_add_box(final_secret_panel, "FalsePanelOldWood", Vector3(0.78, 0.52, 0.09), Vector3.ZERO, mats.dark_wood)
	_add_box(final_secret_panel, "FalsePanelTopRail", Vector3(0.76, 0.055, 0.045), Vector3(0.0, 0.24, 0.055), mats.wood)
	_add_box(final_secret_panel, "FalsePanelBottomRail", Vector3(0.76, 0.055, 0.045), Vector3(0.0, -0.24, 0.055), mats.wood)
	for side in [-1.0, 1.0]:
		_add_box(final_secret_panel, "FalsePanelSideRail", Vector3(0.055, 0.50, 0.045), Vector3(side * 0.39, 0.0, 0.055), mats.wood)
		_add_box(final_secret_panel, "LongOpenedEdgeAbrasion", Vector3(0.018, 0.43, 0.020), Vector3(side * 0.405, 0.0, 0.062), raw_wear)
	var panel_relief := _add_box(final_secret_panel, "FalsePanelFadedDiamond", Vector3(0.30, 0.30, 0.040), Vector3(0.0, 0.0, 0.060), mats.old_gold)
	panel_relief.rotation_degrees.z = 45.0
	for index in range(5):
		var scrape := _add_box(final_secret_panel, "OldOpeningScrape", Vector3(0.12 + index * 0.018, 0.010, 0.010), Vector3(-0.17 + index * 0.08, -0.16 + index * 0.045, 0.068), raw_wear)
		scrape.rotation_degrees.z = -12.0 + index * 4.5


func _add_altar_rope_segments(root_node: Node3D, segment_name: String, points: Array[Vector3], radius: float, material: Material) -> void:
	# Same seven-sided, subtly uneven segmented construction as the hanging-room
	# rope, scaled only in length so diameter and weave language stay consistent.
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
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
		var segment_radius := radius * (0.92 + float(index % 4) * 0.035)
		mesh.top_radius = segment_radius
		mesh.bottom_radius = segment_radius * 1.03
		mesh.height = length * 1.08
		mesh.radial_segments = 7
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.name = segment_name if index == 0 else segment_name + "Segment"
		instance.mesh = mesh
		instance.transform = Transform3D(Basis(x_axis, y_axis, z_axis), (start + finish) * 0.5)
		root_node.add_child(instance)


func _add_tablet_inscription(root_node: Node3D, x: float, y: float, z: float, inscription: String, scale_value: float) -> void:
	var label := Label3D.new()
	label.name = "WeatheredSpiritTabletInscription"
	var vertical_characters: PackedStringArray = []
	for character_index in range(inscription.length()):
		vertical_characters.append(inscription.substr(character_index, 1))
	label.text = "\n".join(vertical_characters)
	label.font = load("res://assets/fonts/watchnight_chinese.tres") as Font
	label.font_size = 34
	label.pixel_size = scale_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.64, 0.45, 0.24, 0.90)
	label.outline_modulate = Color(0.02, 0.012, 0.008, 0.90)
	label.outline_size = 3
	label.position = Vector3(x, y, z)
	root_node.add_child(label)


func _add_hall_lantern(root_node: Node3D, position: Vector3, mats: Dictionary, energy: float) -> void:
	var lantern := Node3D.new()
	lantern.name = "OldSquareGalleryLantern"
	root_node.add_child(lantern)
	var glow := _material(Color(0.34, 0.205, 0.09), 0.91, Color(0.43, 0.19, 0.045))
	_add_box(lantern, "LanternAgedPaperCore", Vector3(0.40, 0.60, 0.40), position, glow)
	_add_box(lantern, "LanternHangingWood", Vector3(0.05, 0.62, 0.05), position + Vector3(0.0, 0.60, 0.0), mats.wood)
	for y in [-0.35, 0.35]:
		_add_box(lantern, "LanternHorizontalFrame", Vector3(0.53, 0.055, 0.53), position + Vector3(0.0, y, 0.0), mats.wood)
	for x in [-0.23, 0.23]:
		for z in [-0.23, 0.23]:
			_add_box(lantern, "LanternCornerPost", Vector3(0.045, 0.72, 0.045), position + Vector3(x, 0.0, z), mats.wood)
	for y in [-0.17, 0.17]:
		_add_box(lantern, "LanternFaceHorizontalMullion", Vector3(0.50, 0.035, 0.035), position + Vector3(0.0, y, -0.225), mats.dark_wood)
		_add_box(lantern, "LanternSideHorizontalMullion", Vector3(0.035, 0.035, 0.50), position + Vector3(-0.225, y, 0.0), mats.dark_wood)
	_add_box(lantern, "LanternFaceVerticalMullion", Vector3(0.035, 0.64, 0.035), position + Vector3(0.0, 0.0, -0.225), mats.dark_wood)
	_add_box(lantern, "LanternSideVerticalMullion", Vector3(0.035, 0.64, 0.035), position + Vector3(-0.225, 0.0, 0.0), mats.dark_wood)
	_add_cylinder(lantern, "LanternBottomWoodFinial", 0.055, 0.18, position + Vector3(0.0, -0.48, 0.0), mats.dark_wood)
	_add_box(lantern, "LanternOldTassel", Vector3(0.035, 0.40, 0.035), position + Vector3(0.0, -0.74, 0.0), mats.old_red)
	var light := OmniLight3D.new()
	light.name = "RestrainedGalleryLanternLight"
	light.position = position
	light.light_color = Color(0.88, 0.48, 0.22)
	light.light_energy = energy
	light.omni_range = 4.15
	light.omni_attenuation = 2.0
	light.shadow_enabled = false
	lantern.add_child(light)


func _build_hall_lighting(root_node: Node3D) -> void:
	var entrance_spill := SpotLight3D.new()
	entrance_spill.name = "ColdRainLightThroughOpenedGate"
	entrance_spill.position = Vector3(0.0, 3.55, 7.72)
	entrance_spill.light_color = Color(0.28, 0.39, 0.53)
	entrance_spill.light_energy = 4.10
	entrance_spill.spot_range = 10.5
	entrance_spill.spot_angle = 48.0
	entrance_spill.spot_attenuation = 1.55
	entrance_spill.shadow_enabled = true
	root_node.add_child(entrance_spill)
	entrance_spill.look_at(Vector3(0.0, 0.6, -1.8), Vector3.UP)
	var shrine_focus := SpotLight3D.new()
	shrine_focus.name = "LowWarmShrineFocus"
	shrine_focus.position = Vector3(0.0, 4.62, -9.60)
	shrine_focus.light_color = Color(0.72, 0.40, 0.20)
	shrine_focus.light_energy = 3.72
	shrine_focus.spot_range = 6.2
	shrine_focus.spot_angle = 39.0
	shrine_focus.spot_attenuation = 2.0
	shrine_focus.shadow_enabled = true
	root_node.add_child(shrine_focus)
	shrine_focus.look_at(Vector3(0.0, 2.05, -13.35), Vector3.UP)
	for side in [-1.0, 1.0]:
		var fill := OmniLight3D.new()
		fill.name = "WeakGalleryStructureFill"
		fill.position = Vector3(side * 4.35, 2.15, -2.80)
		fill.light_color = Color(0.19, 0.25, 0.32)
		fill.light_energy = 2.18
		fill.omni_range = 8.2
		fill.omni_attenuation = 1.65
		fill.shadow_enabled = false
		root_node.add_child(fill)
		var wall_bounce := OmniLight3D.new()
		wall_bounce.name = "RestrainedGalleryWallBounce"
		wall_bounce.position = Vector3(side * 6.05, 1.65, -2.80)
		wall_bounce.light_color = Color(0.50, 0.31, 0.19)
		wall_bounce.light_energy = 1.34
		wall_bounce.omni_range = 5.4
		wall_bounce.omni_attenuation = 1.9
		wall_bounce.shadow_enabled = false
		root_node.add_child(wall_bounce)
		var ceiling_wash := SpotLight3D.new()
		ceiling_wash.name = "ColdHighRoofStructureWash"
		ceiling_wash.position = Vector3(side * 6.15, 3.65, -2.6)
		ceiling_wash.light_color = Color(0.19, 0.24, 0.31)
		ceiling_wash.light_energy = 1.86
		ceiling_wash.spot_range = 7.6
		ceiling_wash.spot_angle = 42.0
		ceiling_wash.spot_attenuation = 2.2
		ceiling_wash.shadow_enabled = false
		root_node.add_child(ceiling_wash)
		ceiling_wash.look_at(Vector3(side * 1.8, 5.08, -2.8), Vector3.UP)
		var shrine_rim := OmniLight3D.new()
		shrine_rim.name = "ShrineSculptureWarmRim"
		shrine_rim.position = Vector3(side * 2.55, 3.02, -13.78)
		shrine_rim.light_color = Color(0.55, 0.27, 0.105)
		shrine_rim.light_energy = 0.78
		shrine_rim.omni_range = 3.5
		shrine_rim.omni_attenuation = 2.1
		shrine_rim.shadow_enabled = false
		root_node.add_child(shrine_rim)
		for zone_z in [4.15, -1.55, -7.10]:
			var gallery_zone_fill := OmniLight3D.new()
			gallery_zone_fill.name = "GalleryMacroReadabilityZone"
			gallery_zone_fill.position = Vector3(side * 5.82, 2.18, zone_z)
			gallery_zone_fill.light_color = Color(0.19, 0.235, 0.285)
			gallery_zone_fill.light_energy = 1.28 if zone_z > -6.0 else 1.05
			gallery_zone_fill.omni_range = 4.65
			gallery_zone_fill.omni_attenuation = 1.72
			gallery_zone_fill.shadow_enabled = false
			root_node.add_child(gallery_zone_fill)
	var nave_fill := OmniLight3D.new()
	nave_fill.name = "MainNaveColdFloorBounce"
	nave_fill.position = Vector3(0.0, 1.65, -1.8)
	nave_fill.light_color = Color(0.22, 0.30, 0.39)
	nave_fill.light_energy = 2.28
	nave_fill.omni_range = 10.8
	nave_fill.omni_attenuation = 1.6
	nave_fill.shadow_enabled = false
	root_node.add_child(nave_fill)
	for zone_z in [3.65, -2.45, -7.75]:
		var nave_zone_fill := OmniLight3D.new()
		nave_zone_fill.name = "NaveMacroReadabilityZone"
		nave_zone_fill.position = Vector3(0.0, 2.85, zone_z)
		nave_zone_fill.light_color = Color(0.18, 0.225, 0.285)
		nave_zone_fill.light_energy = 1.02
		nave_zone_fill.omni_range = 4.85
		nave_zone_fill.omni_attenuation = 1.78
		nave_zone_fill.shadow_enabled = false
		root_node.add_child(nave_zone_fill)
	var altar_bounce := OmniLight3D.new()
	altar_bounce.name = "ShrineLowWarmBounce"
	altar_bounce.position = Vector3(0.0, 2.10, -11.20)
	altar_bounce.light_color = Color(0.65, 0.35, 0.18)
	altar_bounce.light_energy = 2.72
	altar_bounce.omni_range = 7.0
	altar_bounce.omni_attenuation = 1.82
	altar_bounce.shadow_enabled = false
	root_node.add_child(altar_bounce)
	var roof_ambient := DirectionalLight3D.new()
	roof_ambient.name = "HighRoofColdAmbientSeparation"
	roof_ambient.light_color = Color(0.27, 0.34, 0.43)
	roof_ambient.light_energy = 0.46
	roof_ambient.rotation_degrees = Vector3(-62.0, -24.0, 0.0)
	roof_ambient.shadow_enabled = false
	root_node.add_child(roof_ambient)


func _build_hall_air(root_node: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "MainHallSlowDustAndIncenseAsh"
	dust.position = Vector3(0.0, 2.15, -3.4)
	dust.amount = 76
	dust.lifetime = 10.0
	dust.randomness = 0.82
	dust.visibility_aabb = AABB(Vector3(-8.0, -2.0, -12.0), Vector3(16.0, 4.2, 24.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(7.4, 2.0, 10.8)
	process.direction = Vector3(0.05, 0.16, -0.02)
	process.spread = 52.0
	process.initial_velocity_min = 0.008
	process.initial_velocity_max = 0.028
	process.gravity = Vector3(0.0, -0.003, 0.0)
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.018)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.50, 0.47, 0.40, 0.16)
	material.albedo_texture = _soft_particle_texture()
	quad.material = material
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_node.add_child(dust)
	dust.emitting = true


func _build_player() -> void:
	super._build_player()
	for child in player.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			var collision := child as CollisionShape3D
			var capsule := collision.shape as CapsuleShape3D
			capsule.radius = 0.36
			capsule.height = 1.62
			collision.position.y = 0.81
			break


func _physics_process(delta: float) -> void:
	if hammer_busy or (final_investigation != null and bool(final_investigation.get("movement_locked"))):
		_update_animation(false, 0.0)
		_update_flashlight()
		_update_camera(delta, 0.0)
		_update_hud()
		return
	var input_2d := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_2d.x, 0.0, input_2d.y)
	var target := direction.normalized() * WALK_SPEED if direction.length_squared() > 0.01 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, target.x, 7.5 * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, 7.5 * delta)
	player.velocity.y = -0.2
	var before := player.global_position
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -HALL_X_LIMIT, HALL_X_LIMIT)
	player.global_position.z = clampf(player.global_position.z, HALL_FAR_Z, HALL_NEAR_Z)
	var height := 0.02
	if absf(player.global_position.x) <= 4.45:
		if player.global_position.z <= -11.35:
			height = 0.54
		elif player.global_position.z <= -10.89:
			height = 0.36
		elif player.global_position.z <= -10.43:
			height = 0.18
	if height >= player.global_position.y:
		player.global_position.y = height
	else:
		player.global_position.y = move_toward(player.global_position.y, height, delta * 1.8)
	var speed := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length() / maxf(delta, 0.0001)
	_update_facing(direction)
	_update_animation(speed > 0.055, speed)
	_update_flashlight()
	_update_camera(delta, speed)
	_update_hud()


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "MainHallFollowCamera"
	camera.current = true
	camera.fov = 54.0
	camera.position = player.position + Vector3(0.0, 3.05, 6.10)
	add_child(camera)
	camera.look_at(player.position + Vector3(0.0, 1.08, -3.15), Vector3.UP)


func _update_flashlight() -> void:
	super._update_flashlight()
	if west_door_story == null or facing != "left":
		return
	var stage: int = west_door_story.stage()
	if stage in [GameState.HangingDoorStage.LATCH, GameState.HangingDoorStage.AFTERMATH]:
		var offset := player.position - BREAK_DOOR_POSITION
		if Vector2(offset.x, offset.z).length() < 1.42:
			flashlight_origin.rotation_degrees.x = 12.0


func _update_camera(delta: float, speed: float) -> void:
	var desired := player.global_position + Vector3(0.0, 3.05, 6.10)
	desired.x = clampf(player.global_position.x * 0.42, -2.15, 2.15)
	desired.z = minf(desired.z, 11.20)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.2))
	var bob := sin(Time.get_ticks_msec() * 0.012) * 0.007 * clampf(speed / WALK_SPEED, 0.0, 1.0)
	camera.look_at(player.global_position + Vector3(0.0, 1.08 + bob, -3.20), Vector3.UP)


func _build_hud() -> void:
	super._build_hud()
	if hud.has_method("set_objective"):
		hud.call("set_objective", "调查主大堂供奉区")
		if bool(_hall_state().get("final_chapter_objective_revealed")):
			hud.call("set_objective", GameState.APPROACH_HALL_OBJECTIVE)
		elif bool(_hall_state().get("bedroom_exit_event_done")):
			hud.call("set_objective", "寻找‘兰娘’的真实身份")
		elif bool(_hall_state().get("sealed_bedroom_unlocked")):
			hud.call("set_objective", "进入封镜旧卧房")
		elif _hall_state().has_item("study_old_copper_key"):
			hud.call("set_objective", "寻找旧铜钥匙能够打开的门")
		elif _hall_state().has_item("wang_warning_talisman"):
			if _study_door_broken():
				hud.call("set_objective", "进入王家旧书房")
			elif _hall_state().has_item("old_hammer"):
				hud.call("set_objective", "用铁锤砸开右回廊旧书房")
			else:
				hud.call("set_objective", "寻找工具进入右回廊旧书房")
		elif _door_broken():
			hud.call("set_objective", "调查已打开的左回廊偏室")
		elif _hall_state().has_item("old_hammer"):
			hud.call("set_objective", "用铁锤砸开左回廊偏室房门")
	if hud.has_method("set_door_prompt_visible"):
		hud.call("set_door_prompt_visible", false, true)


func _update_hud() -> void:
	if west_door_story != null and west_door_story.busy:
		hud_interaction_target = ""
		hud.call("set_door_prompt_visible", false)
		return
	near_exit = player.global_position.z > 6.78
	near_altar = player.global_position.z < -10.72 and absf(player.global_position.x) < 4.35
	var target := "exit" if near_exit else ""
	if final_investigation != null:
		var investigation_target: String = str(final_investigation.call("interaction_target", player.global_position))
		if not investigation_target.is_empty():
			target = investigation_target
	var tool_target := _hammer_target()
	if not tool_target.is_empty():
		target = tool_target
	if target != hud_interaction_target:
		hud_interaction_target = target
		if hud.has_method("set_door_prompt_visible"):
			hud.call("set_door_prompt_visible", not target.is_empty())
		if hud.has_method("set_interaction_text"):
			hud.call("set_interaction_text", "返回雨夜庭院" if target == "exit" else "")
			if final_investigation != null and bool(final_investigation.call("handles", target)):
				hud.call("set_interaction_text", str(final_investigation.call("prompt_for", target)))
			if target == "hammer":
				hud.call("set_interaction_text", "拾取旧木柄铁锤")
			elif target in ["break_door", "break_study_door"]:
				hud.call("set_interaction_text", "用铁锤砸开房门" if _hall_state().has_item("old_hammer") else "查看被封住的房门")
			elif target == "enter_room":
				var returning_to_west: bool = _hall_state().get("hanging_door_stage") == GameState.HangingDoorStage.COMPLETE
				hud.call("set_interaction_text", "推门返回西厢房" if returning_to_west else "进入左侧偏室")
			elif target == "inspect_west_latch":
				hud.call("set_interaction_text", "调查旧门闩")
			elif target == "enter_study_room":
				hud.call("set_interaction_text", "进入王家旧书房")
			elif target == "unlock_sealed_bedroom":
				hud.call("set_interaction_text", "用旧铜钥匙打开旧卧房" if _hall_state().has_item("study_old_copper_key") else "尝试打开上锁的旧卧房")
			elif target == "enter_sealed_bedroom":
				hud.call("set_interaction_text", "进入封镜旧卧房")
	if GameState.has_hanging_coda_completed():
		if final_investigation != null:
			final_investigation.call("consider_last_look", player.global_position)
		return
	var stage := 0
	var caption := "雨声被厚重木门压低，主堂里只有香火的气味"
	if player.global_position.z < -8.6:
		stage = 3
		caption = "神像低垂着眼，香炉里的灰却还是温的"
	elif absf(player.global_position.x) > 4.25:
		stage = 2
		caption = "回廊尽头的房门半掩着，里面没有一点声音"
	elif player.global_position.z < 0.5:
		stage = 1
		caption = "两侧房间似乎都通向更深处"
	if stage != story_stage:
		story_stage = stage
		if final_investigation != null:
			var encounter := final_investigation.get("pillar_encounter") as Node
			if encounter != null and bool(encounter.get("caption_active")):
				return
		if hud.has_method("set_story_caption"):
			hud.call("set_story_caption", caption, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if hammer_busy or (final_investigation != null and bool(final_investigation.get("movement_locked"))):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and west_door_story != null and west_door_story.busy:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not _hammer_target().is_empty():
		get_viewport().set_input_as_handled()
		_use_hammer_target(_hammer_target())
		return
	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and near_exit:
		get_viewport().set_input_as_handled()
		_return_to_courtyard()
	elif event.is_action_pressed("interact") and final_investigation != null and bool(final_investigation.call("handles", hud_interaction_target)):
		get_viewport().set_input_as_handled()
		final_investigation.call("interact", hud_interaction_target)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_courtyard()


func _return_to_courtyard() -> void:
	GameState.return_to_courtyard_from_hall = true
	_change_scene(COURTYARD_SCENE_PATH)
