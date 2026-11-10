extends Node3D

const EXTERIOR_SCENE_PATH = "res://scenes/ExteriorHouseScene.tscn"
const INTERIOR_SCENE_PATH = "res://scenes/InteriorPlaceholder.tscn"
const LEFT_WING_INTERIOR_SCENE_PATH = "res://scenes/LeftWingInterior3D.tscn"
const MAIN_HOUSE_KEY_ID = "main_house_key"
const ANIMATION_ROOT = "res://assets/characters/animations_dehalo"
const COURTYARD_STONE_MATERIAL = "res://materials/ground/courtyard_stone_wet.tres"
const LEFT_WING_ART_TEST = preload("res://scripts/left_wing_art_test.gd")
const EXTERIOR_HUD_SCENE = preload("res://scenes/UI/ExteriorHUD.tscn")
const WANG_ESTATE_DEPARTURE = preload("res://scripts/wang_estate_departure.gd")
const GROUND_VISUAL_CENTER_Z = -11.0
const GROUND_VISUAL_SIZE = Vector2(14.8, 43.0)

const WALK_SPEED = 2.25
const WALK_ACCELERATION = 8.5
const WALK_DECELERATION = 12.5
const INPUT_DEADZONE = 0.12
const DIRECTION_SWITCH_BIAS = 1.18
const WALK_ANIMATION_FPS = 9.2
const MIN_WALK_ANIMATION_SCALE = 0.68
const CAMERA_HEIGHT = 2.78
const CAMERA_DISTANCE = 5.75
const CAMERA_SIDE_OFFSET = 0.28
const CAMERA_SAFE_MIN_X = -3.05
const CAMERA_SAFE_MAX_X = 3.75
const CAMERA_ENTRANCE_MAX_Z = 13.2
# Keep Chen Mo's capsule a small, visible distance away from the left facade.
# The old limit put the capsule exactly between the wall and its collision skin,
# which could wedge it against a door post after diagonal movement.
const MIN_X = -5.58
const MAX_X = 5.7
const NEAR_Z = 8.2
const FAR_Z = -32.18
const LEFT_ENTRY_PORCH_Z_MIN = 2.12
const LEFT_ENTRY_PORCH_Z_MAX = 6.42
const LEFT_ENTRY_STEP_X = -4.38
const LEFT_ENTRY_PORCH_X = -4.88
const LEFT_ENTRY_STEP_HEIGHT = 0.13
const LEFT_ENTRY_PORCH_HEIGHT = 0.31
const LEFT_WING_DOOR_CENTER = Vector2(-5.22, 5.65)
const LEFT_WING_DOOR_HALF_EXTENTS = Vector2(0.62, 0.72)
const MAIN_GATE_INTERACTION_Z = FAR_Z + 1.8
const MAIN_GATE_INTERACTION_HALF_WIDTH = 3.45
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
var contact_shadow: MeshInstance3D
var contact_shadow_material: ShaderMaterial
var footstep_players: Array[AudioStreamPlayer] = []
var footstep_streams: Array[AudioStream] = []
var footstep_voice_index := 0
var last_footstep_index := -1
var flashlight_origin: Node3D
var flashlight: SpotLight3D
var camera: Camera3D
var rain: Node3D
var courtyard_hud: Control
var thunder_flash: ColorRect
var audio_bgm: AudioStreamPlayer
var audio_thunder: AudioStreamPlayer
var thunder_timer: Timer

var facing = "back"
var animation_facing = "back"
var locomotion_state = "idle"
var wants_to_move = false
var flashlight_enabled = true
var camera_position = Vector3.ZERO
var camera_target = Vector3.ZERO
var camera_bob_offset = 0.0
var thunder_tween: Tween
var hud_near_gate = false
var hud_near_left_wing = false
var hud_story_stage = -1
var hud_was_moving = false
var gate_locked_feedback_until_msec := 0
var reflection_probe: ReflectionProbe
var estate_departure: Node3D
var entrance_posts: Node3D
var hud_near_estate_exit := false


func _ready() -> void:
	randomize()
	_build_world_environment()
	_build_courtyard_geometry()
	_build_player()
	_build_camera()
	_build_rain()
	_build_hud()
	_build_audio()
	estate_departure = WANG_ESTATE_DEPARTURE.new()
	estate_departure.name = "WangEstateDeparture"
	add_child(estate_departure)
	estate_departure.setup(self, entrance_posts)
	_update_character_animation(false, 0.0)
	_update_flashlight_pose()
	_update_hud_state(false)
	_schedule_thunder()


func _physics_process(delta: float) -> void:
	if estate_departure != null and estate_departure.busy:
		estate_departure.advance(delta)
		return
	var input_2d = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_strength = input_2d.length()
	if input_strength <= INPUT_DEADZONE:
		input_2d = Vector2.ZERO
	else:
		input_strength = inverse_lerp(INPUT_DEADZONE, 1.0, minf(input_strength, 1.0))
		input_2d = input_2d.normalized() * input_strength
	var move_direction = Vector3(input_2d.x, 0.0, input_2d.y)
	var target_velocity = move_direction * WALK_SPEED
	var acceleration = WALK_ACCELERATION if move_direction.length_squared() > 0.001 else WALK_DECELERATION
	player.velocity.x = move_toward(player.velocity.x, target_velocity.x, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, target_velocity.z, acceleration * delta)
	player.velocity.y = -0.2
	var previous_position = player.global_position
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, MIN_X, MAX_X)
	player.global_position.z = clampf(player.global_position.z, FAR_Z, NEAR_Z)
	_update_player_surface_height(delta)

	var planar_distance = Vector2(player.global_position.x - previous_position.x, player.global_position.z - previous_position.z).length()
	var planar_speed = planar_distance / maxf(delta, 0.0001)
	var has_move_intent = move_direction.length_squared() > 0.01
	var moving = planar_speed > 0.06
	var can_advance = has_move_intent and moving
	_update_facing(move_direction)
	_update_character_animation(can_advance, planar_speed)
	_update_character_grounding(delta, planar_speed)
	_update_flashlight_pose()
	_update_camera(delta, moving)
	rain.global_position = Vector3(player.global_position.x, 7.0, player.global_position.z - 3.0)
	_update_hud_state(moving)


func _unhandled_input(event: InputEvent) -> void:
	if estate_departure != null and estate_departure.busy:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("flashlight"):
		flashlight_enabled = not flashlight_enabled
		GameState.flashlight_enabled = flashlight_enabled
		flashlight.visible = flashlight_enabled
		if courtyard_hud != null and courtyard_hud.has_method("set_flashlight_enabled"):
			courtyard_hud.call("set_flashlight_enabled", flashlight_enabled)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and estate_departure.can_start():
		get_viewport().set_input_as_handled()
		estate_departure.start()
	elif event.is_action_pressed("interact") and hud_near_left_wing:
		get_viewport().set_input_as_handled()
		_change_scene(LEFT_WING_INTERIOR_SCENE_PATH)
	elif event.is_action_pressed("interact") and hud_near_gate:
		get_viewport().set_input_as_handled()
		_try_enter_main_house()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_change_scene(EXTERIOR_SCENE_PATH)


func _build_world_environment() -> void:
	var world_environment = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.009, 0.014)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.085, 0.105, 0.13)
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.08, 0.1, 0.12)
	environment.fog_light_energy = 0.3
	environment.fog_density = 0.009
	environment.fog_height = 1.15
	environment.fog_height_density = 0.32
	world_environment.environment = environment
	add_child(world_environment)

	reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "WetCourtyardReflections"
	reflection_probe.position = Vector3(0.0, 2.4, -11.0)
	reflection_probe.size = Vector3(15.0, 6.0, 43.0)
	reflection_probe.max_distance = 48.0
	reflection_probe.box_projection = true
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	add_child(reflection_probe)

	var moon = DirectionalLight3D.new()
	moon.light_color = Color(0.36, 0.45, 0.56)
	moon.light_energy = 0.38
	moon.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	moon.shadow_enabled = true
	add_child(moon)


func _build_courtyard_geometry() -> void:
	var root = Node3D.new()
	root.name = "CourtyardGeometry"
	add_child(root)

	_build_ground_collision(root)
	var ground_visual = Node3D.new()
	ground_visual.name = "GroundVisual"
	root.add_child(ground_visual)

	var wet_material = ShaderMaterial.new()
	wet_material.shader = load("res://shaders/wet_courtyard.gdshader") as Shader
	_add_box(ground_visual, "LegacyWetStoneRoadFallback", Vector3(14.8, 0.12, 43.0), Vector3(0.0, -0.08, -11.0), wet_material)
	_build_stone_full_courtyard(ground_visual)

	var wall_material = _make_material(Color(0.075, 0.07, 0.064), 0.78)
	var wood_material = _make_material(Color(0.09, 0.065, 0.045), 0.7)
	var roof_material = _make_material(Color(0.035, 0.045, 0.052), 0.54, 0.08)
	var stone_material = _make_material(Color(0.105, 0.105, 0.095), 0.68)
	var dark_material = _make_material(Color(0.018, 0.02, 0.022), 0.88)
	var haunted_plaster_base = load("res://materials/architecture/peeling_plaster.tres") as ShaderMaterial
	var right_wall_material = haunted_plaster_base.duplicate(true) as ShaderMaterial
	right_wall_material.set_shader_parameter("uv_repeat", Vector2(8.6, 1.25))
	right_wall_material.set_shader_parameter("weathering_repeat", Vector2(0.54, 0.92))
	right_wall_material.set_shader_parameter("material_tint", Color(0.72, 0.71, 0.67, 1.0))
	right_wall_material.set_shader_parameter("albedo_gain", 1.20)
	right_wall_material.set_shader_parameter("weathering_strength", 0.60)
	right_wall_material.set_shader_parameter("wall_root_dampness", 0.70)
	right_wall_material.set_shader_parameter("rain_streak_strength", 0.52)
	right_wall_material.set_shader_parameter("crack_strength", 0.36)
	var hall_wall_material = haunted_plaster_base.duplicate(true) as ShaderMaterial
	hall_wall_material.set_shader_parameter("uv_repeat", Vector2(3.4, 1.55))
	hall_wall_material.set_shader_parameter("weathering_repeat", Vector2(0.88, 0.9))
	hall_wall_material.set_shader_parameter("weathering_strength", 0.64)

	# The long right wing keeps its simple silhouette, but now uses the same
	# physically weathered plaster language as the restored entrance bay.
	_add_box(root, "RightSideWall_Weathered", Vector3(1.5, 3.55, 39.0), Vector3(6.45, 1.72, -10.5), right_wall_material)
	_add_box(root, "RightSideRoof_Legacy", Vector3(2.45, 0.28, 40.0), Vector3(6.0, 3.72, -10.5), roof_material, Vector3(0.0, 0.0, -7.0))
	var gallery_wood := (load("res://materials/architecture/wet_old_wood.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	gallery_wood.set_shader_parameter("uv_repeat", Vector2(1.05, 2.25))
	gallery_wood.set_shader_parameter("material_tint", Color(0.42, 0.31, 0.24))
	gallery_wood.set_shader_parameter("wetness_amount", 0.47)
	for z in [6.5, 0.0, -6.5, -13.0, -19.5, -26.0]:
		_add_box(root, "RightWoodColumn_Legacy", Vector3(0.42, 3.65, 0.42), Vector3(5.18, 1.82, z), gallery_wood)
		_add_box(root, "RightColumnStonePlinth", Vector3(0.49, 0.18, 0.48), Vector3(5.18, 0.11, z), stone_material)
		_add_box(root, "RightColumnWornCapital", Vector3(0.46, 0.13, 0.46), Vector3(5.18, 3.28, z), gallery_wood)
		_add_box(root, "RightWindowFrame_Legacy", Vector3(0.16, 1.18, 1.75), Vector3(5.66, 2.0, z - 2.6), dark_material)
		_add_box(root, "RightPorchStep_Legacy", Vector3(1.2, 0.22, 2.6), Vector3(5.0, 0.05, z - 2.0), stone_material)
	_build_right_wing_finish(root, gallery_wood, stone_material)

	# Keep the unfinished wing out of the sample bay's sightline. Its old exposed
	# end cap read as a giant black wall behind the new 2.4 m facade.
	var restored_left_wall_material = (load("res://materials/architecture/peeling_plaster.tres") as ShaderMaterial).duplicate(true) as ShaderMaterial
	restored_left_wall_material.set_shader_parameter("uv_repeat", Vector2(7.2, 1.25))
	restored_left_wall_material.set_shader_parameter("weathering_repeat", Vector2(0.58, 0.94))
	restored_left_wall_material.set_shader_parameter("material_tint", Color(0.70, 0.71, 0.68, 1.0))
	restored_left_wall_material.set_shader_parameter("albedo_gain", 1.18)
	restored_left_wall_material.set_shader_parameter("weathering_strength", 0.64)
	restored_left_wall_material.set_shader_parameter("wall_root_dampness", 0.76)
	restored_left_wall_material.set_shader_parameter("rain_streak_strength", 0.56)
	restored_left_wall_material.set_shader_parameter("crack_strength", 0.38)
	var restored_left_roof_material = load("res://materials/architecture/wet_gray_roof_tile.tres") as Material
	var restored_left_wood_material = load("res://materials/architecture/wet_old_wood.tres") as Material
	# Extend the low-detail distant shell only far enough to meet the restored
	# transition. The detailed entrance sample remains a single 2.4 m bay.
	_add_box(root, "LeftSideWall_DistantLegacy", Vector3(1.5, 3.55, 32.85), Vector3(-6.45, 1.72, -14.075), restored_left_wall_material)
	# Stop the legacy roof before the restored transition. Leaving it under the
	# sample eave created a broad, almost black slab at gameplay camera angles.
	_add_box(root, "LeftSideRoof_DistantLegacy", Vector3(2.12, 0.22, 32.45), Vector3(-6.03, 3.69, -14.275), restored_left_roof_material, Vector3(0.0, 0.0, 7.0))
	for z in [0.0, -6.5, -13.0, -19.5, -26.0]:
		_add_box(root, "LeftWoodColumn_DistantLegacy", Vector3(0.32, 3.25, 0.32), Vector3(-5.18, 1.65, z), restored_left_wood_material)
		_add_box(root, "LeftWindowFrame_DistantLegacy", Vector3(0.16, 1.18, 1.75), Vector3(-5.66, 2.0, z - 2.6), dark_material)
		_add_box(root, "LeftPorchStep_DistantLegacy", Vector3(1.2, 0.22, 2.6), Vector3(-5.0, 0.05, z - 2.0), stone_material)
	_build_left_rear_abandonment(root, restored_left_wood_material, dark_material, stone_material)

	var left_wing_test = LEFT_WING_ART_TEST.new() as Node3D
	root.add_child(left_wing_test)
	left_wing_test.call("build")
	_build_left_second_wing(root, restored_left_wall_material, restored_left_roof_material, restored_left_wood_material, stone_material, dark_material)

	# Complete the eave language on the long legacy shells. The restored front
	# bays already carry hand-authored rafters and drip tiles, so these ranges
	# deliberately stop before them instead of doubling the geometry.
	_build_side_eave_module(root, "LeftRearWing", -1.0, -15.35, 27.45, restored_left_roof_material, restored_left_wood_material)
	_build_side_eave_module(root, "RightWing", 1.0, -10.50, 39.0, roof_material, wood_material)

	# Keep the entrance gate behind the initial third-person camera. Placing it
	# between the camera and Chen Mo caused the posts to fill most of the screen.
	entrance_posts = Node3D.new()
	entrance_posts.name = "OriginalCourtyardEntrance"
	root.add_child(entrance_posts)
	for x in [-2.35, 2.35]:
		_add_box(entrance_posts, "EntranceGatePost", Vector3(0.38, 4.3, 0.38), Vector3(x, 2.12, 14.0), wood_material)
	_add_box(entrance_posts, "EntranceLintel", Vector3(5.3, 0.48, 0.62), Vector3(0.0, 4.05, 14.0), wood_material)

	_build_main_gate(root, hall_wall_material, roof_material, wood_material, stone_material, dark_material)
	_build_gate_eave_readability(root, roof_material, wood_material, dark_material)

	_build_props(root, stone_material, wood_material)
	_build_puddles(root)
	_build_lanterns(root)
	_build_restrained_wall_horror_details(root)
	_build_courtyard_collisions(root)


func _build_courtyard_collisions(root: Node3D) -> void:
	var collision_root = Node3D.new()
	collision_root.name = "SolidCourtyardGeometry"
	root.add_child(collision_root)
	_add_model_colliders_recursive(root, collision_root)


func _add_model_colliders_recursive(node: Node, collision_root: Node3D) -> void:
	for child in node.get_children():
		if child == collision_root:
			continue
		if child is MeshInstance3D and _is_ground_reachable_solid(child as MeshInstance3D):
			_add_mesh_collider(child as MeshInstance3D, collision_root)
		_add_model_colliders_recursive(child, collision_root)


func _is_ground_reachable_solid(source: MeshInstance3D) -> bool:
	var lower_name = source.name.to_lower()
	# These are thin surface treatments, overhead pieces or walkable surfaces;
	# they must not become invisible waist-height barriers.
	for excluded in ["ground", "surface", "puddle", "step", "plinth", "foundation", "threshold", "roof", "tile", "beam", "lintel", "capital", "rafter", "mullion", "rail", "stain", "crack", "paper", "moss", "mud", "glaze", "shadow", "light", "grass", "weed", "patch", "tassel", "lantern", "bracket"]:
		if excluded in lower_name:
			return false
	if source.mesh is BoxMesh:
		var size = (source.mesh as BoxMesh).size
		var bottom = source.global_position.y - size.y * 0.5
		return size.y >= 0.24 and size.x >= 0.05 and size.z >= 0.05 and bottom <= 1.42
	if source.mesh is CylinderMesh:
		var cylinder = source.mesh as CylinderMesh
		var radius = maxf(cylinder.top_radius, cylinder.bottom_radius)
		var bottom = source.global_position.y - cylinder.height * 0.5
		return cylinder.height >= 0.20 and radius >= 0.05 and bottom <= 1.42
	return false


func _add_mesh_collider(source: MeshInstance3D, collision_root: Node3D) -> void:
	var shape: Shape3D
	if source.mesh is BoxMesh:
		var box_shape = BoxShape3D.new()
		var visual_size = (source.mesh as BoxMesh).size
		# A very small skin is enough because the player already has a capsule.
		# The previous 12 cm expansion made neighbouring door-frame and column
		# colliders overlap the route that still looked open on screen.
		box_shape.size = Vector3(visual_size.x + 0.04, visual_size.y, visual_size.z + 0.04)
		shape = box_shape
	elif source.mesh is CylinderMesh:
		var cylinder_mesh = source.mesh as CylinderMesh
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.radius = maxf(cylinder_mesh.top_radius, cylinder_mesh.bottom_radius) + 0.025
		cylinder_shape.height = cylinder_mesh.height
		shape = cylinder_shape
	else:
		return
	var body = StaticBody3D.new()
	body.name = "%sCollision" % source.name
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape
	body.add_child(collision_shape)
	collision_root.add_child(body)
	body.global_transform = source.global_transform


func _build_side_eave_module(root: Node3D, module_name: String, side: float, center_z: float, length: float, roof_material: Material, wood_material: Material) -> void:
	var eave = Node3D.new()
	eave.name = "%s_UnifiedDeepEave" % module_name
	root.add_child(eave)
	var edge_x = side * 4.54
	var inner_x = side * 6.18
	var center_x = (edge_x + inner_x) * 0.5
	var slope = -side * 7.0

	# Three continuous lines read from gameplay distance: outer fascia, inner
	# purlin and a thin shadow gap. Their warm-brown timber separates from the
	# wet black tile instead of collapsing into a single silhouette.
	_add_box(eave, "%sCourtyardFascia" % module_name, Vector3(0.16, 0.25, length), Vector3(edge_x, 3.31, center_z), wood_material)
	_add_box(eave, "%sInnerPurlin" % module_name, Vector3(0.20, 0.19, length), Vector3(side * 5.74, 3.42, center_z), wood_material)
	_add_box(eave, "%sEaveShadowGap" % module_name, Vector3(0.07, 0.055, length - 0.18), Vector3(side * 4.66, 3.43, center_z), _make_material(Color(0.018, 0.019, 0.020), 0.94))

	# Repeating rafters and the courtyard-facing drip row are MultiMeshes. This
	# gives every bay a real underside while keeping node count and material
	# changes far below one MeshInstance3D per piece.
	var rafter_mesh = BoxMesh.new()
	rafter_mesh.size = Vector3(1.82, 0.095, 0.105)
	rafter_mesh.material = wood_material
	var rafter_count = maxi(2, int(floor(length / 0.48)) + 1)
	var rafter_multimesh = MultiMesh.new()
	rafter_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rafter_multimesh.mesh = rafter_mesh
	rafter_multimesh.instance_count = rafter_count
	for index in range(rafter_count):
		var ratio = float(index) / float(maxi(1, rafter_count - 1))
		var z = center_z - length * 0.5 + 0.12 + ratio * (length - 0.24)
		rafter_multimesh.set_instance_transform(index, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(slope))), Vector3(center_x, 3.42, z)))
	var rafters = MultiMeshInstance3D.new()
	rafters.name = "%sExposedRafters_MultiMesh" % module_name
	rafters.multimesh = rafter_multimesh
	rafters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	eave.add_child(rafters)

	var drip_mesh = CylinderMesh.new()
	drip_mesh.top_radius = 0.082
	drip_mesh.bottom_radius = 0.070
	drip_mesh.height = 0.29
	drip_mesh.radial_segments = 8
	drip_mesh.rings = 1
	drip_mesh.material = roof_material
	var drip_count = maxi(3, int(floor(length / 0.25)) + 1)
	var drip_multimesh = MultiMesh.new()
	drip_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	drip_multimesh.mesh = drip_mesh
	drip_multimesh.instance_count = drip_count
	for index in range(drip_count):
		var ratio = float(index) / float(maxi(1, drip_count - 1))
		var z = center_z - length * 0.5 + 0.10 + ratio * (length - 0.20)
		var y_offset = -0.018 if index % 7 == 0 else 0.0
		drip_multimesh.set_instance_transform(index, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3(edge_x - side * 0.025, 3.48 + y_offset, z)))
	var drip_tiles = MultiMeshInstance3D.new()
	drip_tiles.name = "%sWetDripTiles_MultiMesh" % module_name
	drip_tiles.multimesh = drip_multimesh
	drip_tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	eave.add_child(drip_tiles)


func _build_gate_eave_readability(root: Node3D, roof_material: Material, wood_material: Material, dark_material: Material) -> void:
	var eave = Node3D.new()
	eave.name = "MainGate_CourtyardFacingEaveEmphasis"
	root.add_child(eave)
	# The main roof already owns its tile field. These additions only strengthen
	# the readable courtyard-facing edge and its bracket rhythm.
	_add_box(eave, "GateCourtyardEaveFascia", Vector3(8.45, 0.24, 0.16), Vector3(0.0, 5.55, -31.91), wood_material)
	_add_box(eave, "GateEaveUnderShadow", Vector3(8.10, 0.07, 0.20), Vector3(0.0, 5.43, -32.01), dark_material)
	var rafters: Array[Vector3] = []
	var drip_tiles: Array[Vector3] = []
	for index in range(13):
		var x = -3.72 + float(index) * 0.62
		rafters.append(Vector3(x, 5.53, -32.18))
	for index in range(27):
		var x = -3.9 + float(index) * 0.30
		drip_tiles.append(Vector3(x, 5.70 - (0.018 if index % 9 == 0 else 0.0), -31.93))
	var timber := BoxMesh.new()
	timber.size = Vector3(0.11, 0.10, 0.86)
	timber.material = wood_material
	_batch_roof_mesh(eave, "GateCourtyardRafters", timber, rafters, Vector3(deg_to_rad(-4.0), 0, 0))
	_batch_roof_tiles(eave, "GateCourtyardDripTiles", roof_material, drip_tiles, Vector3(PI * 0.5, 0, 0), 0.085, 0.072, 0.30)


func _batch_roof_tiles(parent: Node3D, batch_name: String, material: Material, positions: Array[Vector3], angles: Vector3, bottom: float, top: float, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = material
	_batch_roof_mesh(parent, batch_name, mesh, positions, angles)


func _batch_roof_mesh(parent: Node3D, batch_name: String, mesh: PrimitiveMesh, positions: Array[Vector3], angles: Vector3) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = positions.size()
	var orientation := Basis.from_euler(angles)
	for index in range(positions.size()):
		batch.set_instance_transform(index, Transform3D(orientation, positions[index]))
	var visual := MultiMeshInstance3D.new()
	visual.name = batch_name
	visual.multimesh = batch
	parent.add_child(visual)


func _update_player_surface_height(delta: float) -> void:
	var target_height = 0.02
	# The restored left-wing entrance has a real 13 cm approach tread and a
	# roughly 31 cm veranda. Match the character root to those visible tops so
	# the boots neither sink into the stone nor hover above it. The full bay and
	# its short restored transition form one continuous walkable strip.
	var in_left_entry_depth = player.global_position.z >= LEFT_ENTRY_PORCH_Z_MIN and player.global_position.z <= LEFT_ENTRY_PORCH_Z_MAX
	if in_left_entry_depth and player.global_position.x <= LEFT_ENTRY_STEP_X:
		if player.global_position.x <= LEFT_ENTRY_PORCH_X:
			target_height = LEFT_ENTRY_PORCH_HEIGHT
		else:
			target_height = LEFT_ENTRY_STEP_HEIGHT
	if absf(player.global_position.x) <= 3.30:
		var z = player.global_position.z
		if z <= -31.80:
			target_height = 0.90
		elif z <= -31.67:
			target_height = 0.72
		elif z <= -31.12:
			target_height = 0.54
		elif z <= -30.57:
			target_height = 0.36
		elif z <= -30.02:
			target_height = 0.18
	# Snap upward onto the tread so the boots never pass through its front edge.
	# Descending is slightly softened to avoid a visible downward pop.
	if target_height >= player.global_position.y:
		player.global_position.y = target_height
	else:
		player.global_position.y = move_toward(player.global_position.y, target_height, 1.8 * delta)


func _build_left_second_wing(root: Node3D, wall_material: Material, roof_material: Material, wood_material: Material, stone_material: Material, dark_material: Material) -> void:
	# Second bay: same structural family as the front bay, but deliberately more
	# closed-in and neglected. It occupies the next depth module after the first
	# entrance (roughly z=-1.45..1.95), before the long greybox shell resumes.
	var group = Node3D.new()
	group.name = "LeftWingSecondBay_ClosedNeglected"
	root.add_child(group)
	var center_z = 0.20
	var bay_length = 3.50
	var wall_x = -6.36
	var front_face_x = -5.54
	var porch_x = -5.16
	var dark_wood = _make_material(Color(0.052, 0.039, 0.030), 0.92)
	var wet_mud = _make_material(Color(0.025, 0.032, 0.028), 0.96)
	var old_paper = _make_material(Color(0.17, 0.12, 0.065), 0.98)
	var soaked_paper = _make_material(Color(0.072, 0.050, 0.030), 0.99)
	var exposed_brick = _make_material(Color(0.082, 0.078, 0.067), 0.92)

	# Continuous sealed wall and low plinth keep the room physically closed.
	_add_box(group, "SecondBayPlasterWall", Vector3(0.38, 2.62, bay_length), Vector3(wall_x, 1.59, center_z), wall_material)
	_add_box(group, "SecondBayStonePlinth", Vector3(1.72, 0.30, bay_length + 0.16), Vector3(-5.68, 0.15, center_z), stone_material)
	_add_box(group, "SecondBayWallRootMud", Vector3(0.06, 0.34, bay_length - 0.10), Vector3(front_face_x + 0.02, 0.43, center_z), wet_mud)

	# A closed, slightly offset door avoids the welcoming front-bay language.
	var door_z = 0.93
	_add_box(group, "SecondBayDoorRecess", Vector3(0.08, 2.22, 1.04), Vector3(front_face_x, 1.48, door_z), dark_material)
	_add_box(group, "SecondBayDoorHeader", Vector3(0.18, 0.16, 1.22), Vector3(front_face_x + 0.06, 2.62, door_z), dark_wood)
	for side in [-1.0, 1.0]:
		var leaf_z = door_z + float(side) * 0.235
		_add_box(group, "SecondBayDoorLeaf", Vector3(0.14, 2.06, 0.44), Vector3(front_face_x + 0.055, 1.47, leaf_z), wood_material)
		for y in [0.83, 1.47, 2.12]:
			_add_box(group, "SecondBayDoorWaterloggedRail", Vector3(0.08, 0.055, 0.37), Vector3(front_face_x + 0.14, y, leaf_z), dark_wood)
	_add_box(group, "SecondBayDoorDarkFoot", Vector3(0.10, 0.30, 0.94), Vector3(front_face_x + 0.13, 0.59, door_z), wet_mud)
	# One diagonal brace makes the closure feel improvised and long undisturbed.
	var door_brace = _add_box(group, "SecondBayDoorDiagonalBrace", Vector3(0.10, 0.10, 1.03), Vector3(front_face_x + 0.17, 1.45, door_z), dark_wood)
	door_brace.rotation_degrees.x = -17.0

	# The rear window is papered over and pinned from the courtyard side; no strong
	# interior source leaks through it.
	var window_z = -0.82
	_add_box(group, "SecondBayWindowUnlitRecess", Vector3(0.08, 1.38, 1.14), Vector3(front_face_x, 1.78, window_z), dark_material)
	_add_box(group, "SecondBayWindowOldPaper", Vector3(0.035, 1.10, 0.84), Vector3(front_face_x + 0.06, 1.78, window_z), soaked_paper)
	for side in [-1.0, 1.0]:
		_add_box(group, "SecondBayWindowPost", Vector3(0.15, 1.54, 0.13), Vector3(front_face_x + 0.13, 1.78, window_z + side * 0.53), wood_material)
	for y in [1.15, 1.79, 2.41]:
		_add_box(group, "SecondBayWindowWarpedRail", Vector3(0.15, 0.11, 1.13), Vector3(front_face_x + 0.14, y, window_z), wood_material)
	var nailed_board = _add_box(group, "SecondBayWindowNailedBoard", Vector3(0.18, 0.14, 1.34), Vector3(front_face_x + 0.18, 1.80, window_z), dark_wood)
	nailed_board.rotation_degrees.x = 14.0
	var torn_paper = _add_box(group, "SecondBayWindowTornPaperEdge", Vector3(0.028, 0.34, 0.22), Vector3(front_face_x + 0.20, 2.18, window_z + 0.36), old_paper)
	torn_paper.rotation_degrees.x = -9.0
	torn_paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Porch structure is complete but tighter and more occluding than bay one.
	for data in [[-1.58, 0.14], [1.92, 0.11]]:
		var z = float(data[0])
		_add_cylinder(group, "SecondBayWetWoodColumn", 0.14, 2.72, Vector3(porch_x, 1.72, z), wood_material)
		_add_cylinder(group, "SecondBayStoneColumnBase", 0.23, 0.20, Vector3(porch_x, 0.38, z), stone_material)
		_add_box(group, "SecondBayColumnCapital", Vector3(0.42, 0.14, 0.42), Vector3(porch_x, 3.03, z), wood_material)
	_add_box(group, "SecondBayFrontBeam", Vector3(0.28, 0.25, bay_length + 0.28), Vector3(porch_x, 3.18, center_z), wood_material)
	_add_box(group, "SecondBayRearBeam", Vector3(0.24, 0.22, bay_length + 0.20), Vector3(-6.18, 3.12, center_z), wood_material)
	_add_box(group, "SecondBayPorchStep", Vector3(1.28, 0.15, bay_length + 0.12), Vector3(-5.02, 0.075, center_z), stone_material)

	# Low, uneven eave with wet black tiles. It is intact, but the stagger and
	# slight lean keep it visibly older than a newly built roof.
	_add_box(group, "SecondBayRoofUnderlay", Vector3(2.18, 0.20, bay_length + 0.34), Vector3(-6.02, 3.57, center_z), dark_wood, Vector3(0.0, 0.0, 6.0))
	for x_index in range(12):
		var tile_x = -4.56 - float(x_index) * 0.16
		var tile_y = 3.39 + float(x_index) * 0.028
		for z_index in range(8):
			var tile_z = -1.63 + float(z_index) * 0.47 + float(x_index % 2) * 0.026
			var tile = _add_cylinder(group, "SecondBayWetRoofTile", 0.073, 0.55, Vector3(tile_x, tile_y, tile_z), roof_material, 0.058)
			tile.rotation_degrees.x = 90.0
	for z_index in range(17):
		var drip = _add_cylinder(group, "SecondBayDripEdgeTile", 0.085, 0.22, Vector3(-4.53, 3.34, -1.66 + float(z_index) * 0.215), roof_material, 0.068)
		drip.rotation_degrees.z = 90.0

	# Uneven plaster loss, vertical rain trails and a few unreadable paper traces.
	for data in [[-0.60, 1.00, 0.42, 0.60], [1.38, 2.35, 0.34, 0.44], [-1.14, 1.62, 0.28, 0.72]]:
		_add_box(group, "SecondBayExposedBrickPatch", Vector3(0.035, float(data[2]), float(data[3])), Vector3(front_face_x + 0.03, float(data[1]), float(data[0])), exposed_brick)
	for data in [[-1.18, 2.12, 0.06, 1.10], [0.02, 2.36, 0.05, 0.86], [1.43, 1.80, 0.07, 0.62]]:
		_add_box(group, "SecondBayVerticalRainStreak", Vector3(0.026, float(data[3]), float(data[2])), Vector3(front_face_x + 0.052, float(data[1]), float(data[0])), wet_mud)
	var wall_paper = _add_box(group, "SecondBayFadedPaperRemnant", Vector3(0.024, 0.37, 0.19), Vector3(front_face_x + 0.07, 2.18, -1.38), old_paper)
	wall_paper.rotation_degrees.x = -7.0
	wall_paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Sparse story props: a tipped basket, one low stool and boards tight to the wall.
	_add_pot(group, Vector3(-4.56, 0.24, -1.34), 0.34, stone_material)
	var stool = _add_box(group, "SecondBayAbandonedLowStool", Vector3(0.58, 0.42, 0.48), Vector3(-4.78, 0.23, 0.32), wood_material, Vector3(0.0, -13.0, 0.0))
	stool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for data in [[-4.76, -1.12, -7.0], [-4.84, -0.96, 11.0]]:
		var board = _add_box(group, "SecondBayLeaningRottenBoard", Vector3(0.10, 1.34, 0.42), Vector3(float(data[0]), 0.78, float(data[1])), wood_material)
		board.rotation_degrees.z = float(data[2])

	# One weak, shielded warm lamp at the door edge, much dimmer than the first bay.
	_add_unified_old_lantern(group, "SecondBayOldPaperLantern", Vector3(-5.27, 2.54, 1.55), 0.62, 3.25)
	var storm_fill = OmniLight3D.new()
	storm_fill.name = "SecondBaySubtleStormFill"
	storm_fill.position = Vector3(-4.48, 2.05, 0.15)
	storm_fill.light_color = Color(0.25, 0.32, 0.39)
	storm_fill.light_energy = 0.46
	storm_fill.omni_range = 4.2
	storm_fill.omni_attenuation = 1.8
	storm_fill.shadow_enabled = false
	group.add_child(storm_fill)


func _build_main_gate(root: Node3D, hall_wall_material: Material, roof_material: Material, wood_material: Material, stone_material: Material, dark_material: Material) -> void:
	var gate = Node3D.new()
	gate.name = "MainGate_ThreeDimensionalWeatheredEntrance"
	root.add_child(gate)
	var facade_wall = hall_wall_material.duplicate(true) as ShaderMaterial
	facade_wall.set_shader_parameter("uv_repeat", Vector2(3.8, 1.55))
	facade_wall.set_shader_parameter("weathering_repeat", Vector2(0.82, 0.9))
	facade_wall.set_shader_parameter("material_tint", Color(0.52, 0.53, 0.50, 1.0))
	facade_wall.set_shader_parameter("weathering_strength", 0.86)
	facade_wall.set_shader_parameter("wall_root_dampness", 0.90)
	facade_wall.set_shader_parameter("rain_streak_strength", 0.66)
	var gate_stone = _make_material(Color(0.18, 0.19, 0.19), 0.74)
	var gate_stone_edge = _make_material(Color(0.075, 0.082, 0.082), 0.90)
	var gate_dark_wood = _make_material(Color(0.078, 0.042, 0.028), 0.86)
	var gate_damp_wood = _make_material(Color(0.22, 0.105, 0.052), 0.80)
	var gate_damp_wood_shadow = _make_material(Color(0.155, 0.068, 0.034), 0.86)
	var gate_old_iron = _make_material(Color(0.065, 0.058, 0.050), 0.82, 0.22)
	var gate_leaf_left = (load("res://materials/architecture/wet_old_wood.tres") as Material).duplicate(true) as ShaderMaterial
	gate_leaf_left.set_shader_parameter("uv_repeat", Vector2(1.15, 3.25))
	gate_leaf_left.set_shader_parameter("material_tint", Color(0.40, 0.225, 0.135, 1.0))
	gate_leaf_left.set_shader_parameter("albedo_gain", 0.96)
	gate_leaf_left.set_shader_parameter("wetness_amount", 0.76)
	gate_leaf_left.set_shader_parameter("wet_roughness", 0.40)
	gate_leaf_left.set_shader_parameter("roughness_floor", 0.62)
	gate_leaf_left.set_shader_parameter("moss_amount", 0.12)
	gate_leaf_left.set_shader_parameter("weathering_strength", 0.30)
	gate_leaf_left.set_shader_parameter("wall_root_dampness", 0.62)
	var gate_leaf_right = gate_leaf_left.duplicate(true) as ShaderMaterial
	gate_leaf_right.set_shader_parameter("material_tint", Color(0.345, 0.18, 0.11, 1.0))
	gate_leaf_right.set_shader_parameter("wetness_amount", 0.68)
	gate_leaf_right.set_shader_parameter("wall_root_dampness", 0.74)
	var gate_frame_wood = gate_leaf_left.duplicate(true) as ShaderMaterial
	gate_frame_wood.set_shader_parameter("uv_repeat", Vector2(1.0, 2.25))
	gate_frame_wood.set_shader_parameter("material_tint", Color(0.31, 0.185, 0.125, 1.0))
	gate_frame_wood.set_shader_parameter("albedo_gain", 0.88)
	gate_frame_wood.set_shader_parameter("wetness_amount", 0.72)
	gate_frame_wood.set_shader_parameter("moss_amount", 0.08)
	var gate_mud = _make_material(Color(0.028, 0.034, 0.031), 0.96)
	var gate_moss = _make_material(Color(0.038, 0.066, 0.043), 0.96)
	var gate_roof = _make_material(Color(0.060, 0.073, 0.080), 0.52, 0.04)
	var gate_wet_glaze = _make_material(Color(0.075, 0.095, 0.105, 0.34), 0.20, 0.06, true)

	# Thick front wall and darker side returns establish a real enclosed threshold.
	_add_box(gate, "GatePlasterFacade", Vector3(13.2, 5.45, 1.30), Vector3(0.0, 2.70, -34.05), facade_wall)
	_add_box(gate, "GateLeftReturn", Vector3(0.92, 5.45, 3.15), Vector3(-6.14, 2.70, -33.38), facade_wall)
	_add_box(gate, "GateRightReturn", Vector3(0.92, 5.45, 3.15), Vector3(6.14, 2.70, -33.38), facade_wall)
	_add_box(gate, "GateStoneFoundation", Vector3(13.55, 0.58, 1.58), Vector3(0.0, 0.29, -33.90), gate_stone)
	_add_box(gate, "GateFoundationShadowBand", Vector3(13.25, 0.24, 0.10), Vector3(0.0, 0.78, -33.24), gate_stone_edge)

	# Recess behind the door leaves: the blackness is a physical cavity, not a flat decal.
	_add_box(gate, "GateDeepDoorRecess", Vector3(4.70, 4.16, 0.38), Vector3(0.0, 2.20, -33.28), dark_material)
	_add_box(gate, "GateRecessCeilingShadow", Vector3(5.15, 0.24, 0.72), Vector3(0.0, 4.35, -33.17), gate_dark_wood)
	_add_box(gate, "GateRecessLeftReveal", Vector3(0.20, 4.10, 0.68), Vector3(-2.38, 2.22, -33.14), gate_frame_wood)
	_add_box(gate, "GateRecessRightReveal", Vector3(0.20, 4.10, 0.68), Vector3(2.38, 2.22, -33.14), gate_frame_wood)

	# Thick jambs, threshold and lintel are layered in front of the cavity.
	_add_box(gate, "GateLeftTimberJamb", Vector3(0.42, 4.48, 0.56), Vector3(-2.48, 2.35, -32.91), gate_frame_wood)
	_add_box(gate, "GateRightTimberJamb", Vector3(0.42, 4.48, 0.56), Vector3(2.48, 2.35, -32.91), gate_frame_wood)
	_add_box(gate, "GateHeavyTimberLintel", Vector3(5.35, 0.46, 0.60), Vector3(0.0, 4.54, -32.91), gate_frame_wood)
	_add_box(gate, "GateThresholdStone", Vector3(4.78, 0.22, 0.72), Vector3(0.0, 0.86, -32.63), gate_stone_edge)
	_add_box(gate, "GateThresholdWoodLip", Vector3(4.12, 0.16, 0.18), Vector3(0.0, 1.00, -32.46), gate_frame_wood)

	# Heavy double door with board seams, old cross rails and a near-invisible center gap.
	var door_center_z = -32.60
	for side in [-1.0, 1.0]:
		var door_x = float(side) * 1.04
		var leaf_material = gate_leaf_left if side < 0.0 else gate_leaf_right
		var leaf_z = door_center_z - (0.018 if side < 0.0 else -0.012)
		_add_box(gate, "GateDoorLeaf", Vector3(1.96, 3.54, 0.20), Vector3(door_x, 2.56, leaf_z), leaf_material)
		# A separate front frame and plank seams establish the door thickness at
		# distance; the two leaves deliberately do not close on exactly one plane.
		for stile_x in [-0.84, 0.84]:
			_add_box(gate, "GateDoorPerimeterStile", Vector3(0.105, 3.30, 0.105), Vector3(door_x + stile_x, 2.56, leaf_z + 0.145), gate_dark_wood)
		for y in [1.02, 4.10]:
			_add_box(gate, "GateDoorPerimeterRail", Vector3(1.78, 0.105, 0.105), Vector3(door_x, y, leaf_z + 0.145), gate_dark_wood)
		for y in [1.38, 2.52, 3.62]:
			_add_box(gate, "GateDoorHorizontalBoard", Vector3(1.66, 0.072, 0.095), Vector3(door_x, y, leaf_z + 0.142), gate_dark_wood)
		for z_offset in [-0.58, -0.29, 0.0, 0.29, 0.58]:
			_add_box(gate, "GateDoorVerticalPlankSeam", Vector3(0.045, 3.26, 0.025), Vector3(door_x + z_offset, 2.56, door_center_z + 0.115), gate_dark_wood)
		var door_brace = _add_box(gate, "GateDoorDiagonalBrace", Vector3(0.105, 0.105, 1.30), Vector3(door_x, 2.55, leaf_z + 0.18), gate_dark_wood)
		door_brace.rotation_degrees.x = -14.0 if side < 0.0 else 14.0
		_add_box(gate, "GateDoorFootWaterDamage", Vector3(1.72, 0.30 + (0.08 if side > 0.0 else 0.0), 0.035), Vector3(door_x, 0.96, leaf_z + 0.16), gate_mud)
		for stud_x in [-0.68, 0.68]:
			for stud_y in [1.42, 2.48, 3.53]:
				var stud = _add_cylinder(gate, "GateOxidizedDoorStud", 0.042, 0.028, Vector3(door_x + stud_x, stud_y, leaf_z + 0.205), gate_old_iron)
				stud.rotation_degrees.x = 90.0
	_add_box(gate, "GateDoorCenterShadowGap", Vector3(0.055, 3.43, 0.035), Vector3(0.0, 2.56, door_center_z + 0.225), dark_material)
	# Real torus knockers replace the previous solid circular discs.
	for side in [-1.0, 1.0]:
		_add_cylinder(gate, "GateOldIronKnockerBoss", 0.075, 0.042, Vector3(float(side) * 0.48, 2.68, door_center_z + 0.215), gate_old_iron).rotation_degrees.x = 90.0
		var ring = _add_torus(gate, "GateOldIronDoorRing", 0.075, 0.125, Vector3(float(side) * 0.48, 2.50, door_center_z + 0.235), gate_old_iron)
		ring.rotation_degrees.x = 90.0
		_add_box(gate, "GateRustHingeStrap", Vector3(0.09, 1.08, 0.045), Vector3(float(side) * 1.70, 2.72, door_center_z + 0.19), gate_old_iron)

	# Four broad, wet stone steps and a landing physically connect the gate to the courtyard.
	for index in range(4):
		var step_y = 0.09 + float(index) * 0.18
		var step_z = -30.36 - float(index) * 0.55
		var step_width = 7.35 - float(index) * 0.22
		_add_box(gate, "GateWetStoneStep_%02d" % index, Vector3(step_width, 0.18, 0.68), Vector3(0.0, step_y, step_z), gate_stone)
		_add_box(gate, "GateStepFrontEdge_%02d" % index, Vector3(step_width * 0.98, 0.065, 0.055), Vector3(0.0, step_y + 0.09, step_z + 0.325), gate_stone_edge)
		var wet_top = _add_box(gate, "GateStepWetGlaze_%02d" % index, Vector3(step_width * 0.92, 0.012, 0.54), Vector3(0.0, step_y + 0.096, step_z - 0.015), gate_wet_glaze)
		wet_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(gate, "GateTopLanding", Vector3(6.62, 0.18, 1.16), Vector3(0.0, 0.81, -32.38), gate_stone_edge)
	var landing_wet = _add_box(gate, "GateLandingWetGlaze", Vector3(5.85, 0.012, 0.82), Vector3(0.12, 0.906, -32.33), gate_wet_glaze)
	landing_wet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(gate, "GateStepRootMoss", Vector3(5.85, 0.035, 0.12), Vector3(0.0, 0.92, -31.84), gate_moss)

	# Main timber posts and stone bases visibly carry the roof load.
	for side in [-1.0, 1.0]:
		var x = float(side) * 3.05
		_add_cylinder(gate, "GateMainWetWoodPost", 0.24, 4.55, Vector3(x, 2.95, -32.68), gate_frame_wood)
		_add_box(gate, "GatePostStoneBase", Vector3(0.72, 0.26, 0.72), Vector3(x, 0.98, -32.66), gate_stone_edge)
		_add_box(gate, "GatePostCapital", Vector3(0.74, 0.22, 0.72), Vector3(x, 5.18, -32.68), gate_dark_wood)
		var bracket = _add_box(gate, "GateCarvedBracketSilhouette", Vector3(0.76, 0.14, 0.22), Vector3(float(side) * 2.65, 4.82, -32.62), gate_dark_wood)
		bracket.rotation_degrees.z = -18.0 * side
	_add_box(gate, "GateUpperCrossBeam", Vector3(6.75, 0.34, 0.42), Vector3(0.0, 5.02, -32.66), gate_frame_wood)
	_add_box(gate, "GateSecondaryLintel", Vector3(7.60, 0.18, 0.32), Vector3(0.0, 4.73, -32.48), gate_damp_wood_shadow)
	_add_box(gate, "GateUpperTimberPanel", Vector3(5.86, 0.72, 0.20), Vector3(0.0, 5.55, -32.70), gate_damp_wood)
	for x in [-2.42, -1.20, 0.0, 1.20, 2.42]:
		_add_box(gate, "GateUpperPanelRafter", Vector3(0.12, 0.56, 0.24), Vector3(x, 5.55, -32.55), gate_dark_wood)
	for x in [-5.40, -4.50, -3.60, -2.70, -1.80, -0.90, 0.0, 0.90, 1.80, 2.70, 3.60, 4.50, 5.40]:
		var eave_rafter = _add_box(gate, "GateExposedEaveRafter", Vector3(0.13, 0.12, 1.18), Vector3(x, 5.63, -32.52), gate_dark_wood)
		eave_rafter.rotation_degrees.x = -4.0

	# Layered eave and black wet tiles press down over the threshold.
	_add_box(gate, "GateRoofUnderlay", Vector3(14.25, 0.30, 3.25), Vector3(0.0, 5.92, -33.70), gate_dark_wood, Vector3(0.0, 0.0, -2.8))
	var roof_tiles: Array[Vector3] = []
	var front_tiles: Array[Vector3] = []
	var ridge_tiles: Array[Vector3] = []
	for row in range(5):
		var roof_z = -35.00 + float(row) * 0.47
		var row_width = 13.6 - float(row) * 0.32
		for col in range(19):
			var roof_x = -row_width * 0.5 + 0.36 + float(col) * (row_width - 0.72) / 18.0
			roof_tiles.append(Vector3(roof_x, 5.82 + float(row) * 0.065, roof_z))
	for col in range(23):
		var ridge_x = -5.55 + float(col) * 0.505
		front_tiles.append(Vector3(ridge_x, 5.73, -31.98))
	for col in range(21):
		var ridge_x = -5.25 + float(col) * 0.525
		ridge_tiles.append(Vector3(ridge_x, 6.20, -33.55))
	_batch_roof_tiles(gate, "GateWetRoofTiles", gate_roof, roof_tiles, Vector3(0, 0, PI * 0.5), 0.095, 0.072, 0.50)
	_batch_roof_tiles(gate, "GateFrontDripTiles", gate_roof, front_tiles, Vector3(0, 0, PI * 0.5), 0.105, 0.082, 0.27)
	_batch_roof_tiles(gate, "GateRidgeCapTiles", gate_roof, ridge_tiles, Vector3(0, 0, PI * 0.5), 0.115, 0.087, 0.30)

	# Weathering is physical surface layering, kept sparse around the focal doorway.
	for data in [[-5.0, 1.56, 0.58, 0.66], [-3.95, 3.42, 0.36, 0.74], [3.92, 1.74, 0.55, 0.48], [5.10, 3.08, 0.40, 0.62]]:
		_add_box(gate, "GateExposedDampMasonry", Vector3(0.04, float(data[2]), float(data[3])), Vector3(float(data[0]), float(data[1]), -33.37), gate_stone_edge)
	for data in [[-5.40, 2.98, 0.06, 1.18], [-4.10, 2.36, 0.045, 0.82], [4.45, 3.10, 0.055, 1.00], [5.25, 1.64, 0.045, 0.62]]:
		_add_box(gate, "GateVerticalRainStreak", Vector3(0.035, float(data[3]), float(data[2])), Vector3(float(data[0]), float(data[1]), -33.345), gate_mud)
	for data in [[-5.55, 3.35, 0.035, 0.92, -9.0], [-4.72, 2.62, 0.028, 0.66, 14.0], [4.76, 3.64, 0.032, 0.82, 8.0], [5.42, 2.28, 0.026, 0.58, -12.0]]:
		_add_box(gate, "GateFineWallCrack", Vector3(float(data[2]), float(data[3]), 0.022), Vector3(float(data[0]), float(data[1]), -33.32), gate_mud, Vector3(0.0, 0.0, float(data[4])))
	_add_box(gate, "GateWallRootMossLeft", Vector3(2.20, 0.17, 0.045), Vector3(-4.55, 0.94, -33.34), gate_moss)
	_add_box(gate, "GateWallRootMossRight", Vector3(1.55, 0.13, 0.045), Vector3(4.72, 1.00, -33.34), gate_moss)

	# A pair of matching old lanterns anchors the entrance and gives the wet steps a reflection cue.
	_add_unified_old_lantern(gate, "MainGateLeftOldLantern", Vector3(-3.46, 3.48, -32.34), 0.92, 4.15, true)
	_add_unified_old_lantern(gate, "MainGateRightOldLantern", Vector3(3.46, 3.48, -32.34), 0.92, 4.15, true)
	var gate_fill = OmniLight3D.new()
	gate_fill.name = "MainGateSubtleColdRainFill"
	gate_fill.position = Vector3(0.0, 2.75, -30.92)
	gate_fill.light_color = Color(0.24, 0.31, 0.38)
	gate_fill.light_energy = 1.04
	gate_fill.omni_range = 6.8
	gate_fill.omni_attenuation = 1.62
	gate_fill.shadow_enabled = false
	gate.add_child(gate_fill)
	var threshold_fill = OmniLight3D.new()
	threshold_fill.name = "MainGateLowWarmThresholdBounce"
	threshold_fill.position = Vector3(0.0, 1.18, -31.32)
	threshold_fill.light_color = Color(0.62, 0.36, 0.18)
	threshold_fill.light_energy = 0.72
	threshold_fill.omni_range = 4.2
	threshold_fill.omni_attenuation = 2.0
	threshold_fill.shadow_enabled = false
	gate.add_child(threshold_fill)


func _add_cylinder(root: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, top_radius := -1.0) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius if top_radius < 0.0 else top_radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 18
	cylinder.material = material
	instance.mesh = cylinder
	instance.position = position
	root.add_child(instance)
	return instance


func _add_torus(root: Node3D, node_name: String, inner_radius: float, outer_radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var torus = TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 18
	torus.ring_segments = 12
	torus.material = material
	instance.mesh = torus
	instance.position = position
	root.add_child(instance)
	return instance


func _build_right_wing_finish(root: Node3D, wood_material: Material, stone_material: Material) -> void:
	# The right wing shares the courtyard's construction language, but its openings
	# are more regular and less actively maintained than the two left bays.
	var surface_x = 5.54
	var damp = _make_material(Color(0.026, 0.034, 0.031), 0.96)
	var exposed = _make_material(Color(0.088, 0.080, 0.068), 0.92)
	var paper = _make_material(Color(0.12, 0.086, 0.046), 0.99)
	var window_paper := ShaderMaterial.new()
	window_paper.shader = preload("res://shaders/aged_room_paper.gdshader")
	window_paper.set_shader_parameter("paper_tint", Color(0.32, 0.30, 0.25))
	var mullions := PackedVector3Array()
	var rails := PackedVector3Array()
	var panes := PackedVector3Array()
	for z in [-2.60, -9.10, -15.60, -22.10]:
		_add_box(root, "RightWingBoardedWindowHead", Vector3(0.13, 0.13, 1.92), Vector3(surface_x, 2.62, z), wood_material)
		_add_box(root, "RightWingBoardedWindowSill", Vector3(0.15, 0.14, 1.94), Vector3(surface_x, 0.96, z), stone_material)
		for side in [-1.0, 1.0]:
			_add_box(root, "RightWingBoardedWindowPost", Vector3(0.13, 1.72, 0.12), Vector3(surface_x, 1.78, z + side * 0.90), wood_material)
		for offset in [-0.57, -0.29, 0.03, 0.37, 0.65]:
			mullions.append(Vector3(surface_x - 0.008, 1.79, z + offset))
		for y in [1.40, 2.19, 2.39]:
			rails.append(Vector3(surface_x - 0.014, y, z))
		for offset in [-0.44, 0.18, 0.51]:
			panes.append(Vector3(surface_x + 0.021, 1.84, z + offset))
		var board = _add_box(root, "RightWingWarpedWindowBoard", Vector3(0.12, 0.13, 1.62), Vector3(surface_x + 0.07, 1.62, z), wood_material)
		board.rotation_degrees.x = 9.0 if int(absf(z)) % 2 == 0 else -13.0
		_add_box(root, "RightWingWindowRootDamp", Vector3(0.035, 0.34, 1.82), Vector3(surface_x + 0.04, 0.58, z), damp)
	_add_right_lattice_batch(root, "RightWingWeatheredMullions", Vector3(0.045, 1.47, 0.042), mullions, wood_material)
	_add_right_lattice_batch(root, "RightWingWindowLatticeRails", Vector3(0.048, 0.042, 1.72), rails, wood_material)
	_add_right_lattice_batch(root, "RightWingDampWindowPaper", Vector3(0.014, 1.28, 0.24), panes, window_paper)

	for data in [[-4.8, 1.18, 0.42, 0.72], [-11.7, 2.20, 0.35, 0.56], [-18.8, 1.45, 0.55, 0.42], [-25.1, 2.05, 0.30, 0.60]]:
		_add_box(root, "RightWingExposedMasonry", Vector3(0.028, float(data[2]), float(data[3])), Vector3(surface_x + 0.03, float(data[1]), float(data[0])), exposed)
	for data in [[-5.4, 2.16, 0.055, 0.92], [-12.7, 1.94, 0.045, 0.72], [-20.0, 2.30, 0.06, 0.54]]:
		_add_box(root, "RightWingRainStreak", Vector3(0.024, float(data[3]), float(data[2])), Vector3(surface_x + 0.05, float(data[1]), float(data[0])), damp)
	var paper_fragment = _add_box(root, "RightWingFadedPaperRemnant", Vector3(0.022, 0.31, 0.18), Vector3(surface_x + 0.07, 2.08, -13.22), paper)
	paper_fragment.rotation_degrees.x = 6.0
	paper_fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_right_lattice_batch(root: Node3D, label: String, size: Vector3, positions: PackedVector3Array, material: Material) -> void:
	var slat := BoxMesh.new()
	slat.size = size
	slat.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = slat
	batch.instance_count = positions.size()
	for index in positions.size():
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var lattice := MultiMeshInstance3D.new()
	lattice.name = label
	lattice.multimesh = batch
	lattice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lattice)


func _add_unified_old_lantern(parent: Node3D, lantern_name: String, position: Vector3, energy: float, omni_range: float, face_toward_courtyard_z := false, face_toward_negative_x := false, casts_shadows := true) -> void:
	var group = Node3D.new()
	group.name = lantern_name
	parent.add_child(group)
	var frame = _make_material(Color(0.075, 0.046, 0.028), 0.82)
	var paper = _make_material(Color(0.58, 0.34, 0.15), 0.82, 0.0, false, Color(0.72, 0.38, 0.12))
	var core_material = _make_material(Color(0.66, 0.36, 0.12), 0.68, 0.0, false, Color(0.95, 0.52, 0.18))
	_add_box(group, "LanternHangingRod", Vector3(0.04, 0.42, 0.04), position + Vector3(0.0, 0.44, 0.0), frame)
	var shade = _add_box(group, "LanternAgedPaperShade", Vector3(0.34, 0.54, 0.34), position, paper)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core = _add_cylinder(group, "LanternInternalWarmCore", 0.062, 0.32, position, core_material)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [-0.32, 0.32]:
		_add_box(group, "LanternTopBottomFrame", Vector3(0.42, 0.045, 0.42), position + Vector3(0.0, y, 0.0), frame)
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			_add_box(group, "LanternCornerFrame", Vector3(0.035, 0.66, 0.035), position + Vector3(x, 0.0, z), frame)
	if face_toward_courtyard_z:
		_add_box(group, "LanternFrontMullion", Vector3(0.026, 0.54, 0.025), position + Vector3(0.0, 0.0, 0.192), frame)
		for y in [-0.17, 0.0, 0.17]:
			_add_box(group, "LanternFrontMullionHorizontal", Vector3(0.33, 0.025, 0.026), position + Vector3(0.0, y, 0.192), frame)
		_add_box(group, "LanternPaperWaterStain", Vector3(0.11, 0.18, 0.012), position + Vector3(0.08, -0.16, 0.177), frame)
	else:
		var face_x = -0.192 if face_toward_negative_x else 0.192
		var stain_x = -0.177 if face_toward_negative_x else 0.177
		_add_box(group, "LanternFrontMullion", Vector3(0.025, 0.54, 0.026), position + Vector3(face_x, 0.0, 0.0), frame)
		for y in [-0.17, 0.0, 0.17]:
			_add_box(group, "LanternFrontMullionHorizontal", Vector3(0.026, 0.025, 0.33), position + Vector3(face_x, y, 0.0), frame)
		_add_box(group, "LanternPaperWaterStain", Vector3(0.012, 0.18, 0.11), position + Vector3(stain_x, -0.16, 0.08), frame)
	_add_box(group, "LanternBottomTassel", Vector3(0.025, 0.28, 0.025), position + Vector3(0.0, -0.48, 0.0), frame)
	var light = OmniLight3D.new()
	light.name = "LocalizedWarmLanternLight"
	if face_toward_courtyard_z:
		light.position = position + Vector3(0.0, -0.05, 0.16)
	else:
		light.position = position + Vector3(-0.16 if face_toward_negative_x else 0.16, -0.05, 0.0)
	light.light_color = Color(1.0, 0.64, 0.32)
	light.light_energy = energy
	light.omni_range = omni_range
	light.omni_attenuation = 1.92
	light.shadow_enabled = casts_shadows
	group.add_child(light)


func _build_left_rear_abandonment(root: Node3D, wood_material: Material, dark_material: Material, stone_material: Material) -> void:
	var exposed_masonry = _make_material(Color(0.075, 0.078, 0.074), 0.91)
	var wall_root_mud = _make_material(Color(0.028, 0.038, 0.032), 0.94)
	var soaked_paper = _make_material(Color(0.095, 0.068, 0.038), 0.98)
	var adhesive_ghost = _make_material(Color(0.052, 0.044, 0.035), 0.97)

	# The distant legacy windows used to be solid black boxes. Shallow frames and
	# warped boards retain their darkness while giving the eye believable depth.
	for data in [[-2.60, 0.0], [-9.10, 1.0], [-15.60, 0.0], [-22.10, 1.0]]:
		var z = float(data[0])
		var reversed = float(data[1])
		_add_box(root, "LeftRearBlindWindowRecess", Vector3(0.035, 1.58, 2.02), Vector3(-5.555, 1.78, z), dark_material)
		_add_box(root, "LeftRearWindowHead", Vector3(0.13, 0.14, 2.18), Vector3(-5.52, 2.60, z), wood_material)
		_add_box(root, "LeftRearWindowSill", Vector3(0.15, 0.16, 2.18), Vector3(-5.51, 0.96, z), stone_material)
		for side in [-1.0, 1.0]:
			_add_box(root, "LeftRearWindowPost", Vector3(0.13, 1.76, 0.13), Vector3(-5.52, 1.78, z + side * 1.02), wood_material)
		var board_a = _add_box(root, "LeftRearWarpedBoardA", Vector3(0.12, 0.13, 1.82), Vector3(-5.47, 1.62, z), wood_material)
		board_a.rotation_degrees.x = -11.0 if reversed < 0.5 else 13.0
		var board_b = _add_box(root, "LeftRearWarpedBoardB", Vector3(0.12, 0.12, 1.48), Vector3(-5.455, 2.12, z + 0.10), wood_material)
		board_b.rotation_degrees.x = 7.0 if reversed < 0.5 else -9.0
		_add_box(root, "LeftRearWindowRootDamp", Vector3(0.035, 0.42, 1.82), Vector3(-5.445, 0.61, z), wall_root_mud)

	# Broken plaster is kept sparse and irregular; the wall should imply neglect,
	# not turn into a decorative collage of decals.
	for data in [
		[-0.65, 1.18, 0.56, 0.88], [-5.15, 2.32, 0.42, 0.64],
		[-11.85, 1.42, 0.68, 0.52], [-18.20, 2.08, 0.38, 0.72]
	]:
		_add_box(root, "LeftRearExposedOldMasonry", Vector3(0.026, float(data[2]), float(data[3])), Vector3(-5.548, float(data[1]), float(data[0])), exposed_masonry)

	for data in [[-4.75, 1.86, -6.0], [-12.0, 1.52, 8.0], [-20.15, 2.12, -4.0]]:
		var ghost = _add_box(root, "LeftRearFadedPaperGhost", Vector3(0.018, 0.47, 0.29), Vector3(-5.515, float(data[1]), float(data[0])), adhesive_ghost)
		ghost.rotation_degrees.x = float(data[2])
		var fragment = _add_box(root, "LeftRearSoakedPaperFragment", Vector3(0.014, 0.25, 0.16), Vector3(-5.492, float(data[1]) - 0.08, float(data[0]) + 0.035), soaked_paper)
		fragment.rotation_degrees.x = float(data[2]) - 5.0

	# Weak blue-grey rain bounce reveals relief without advertising a light source.
	for data in [
		[-2.15, 2.28, 0.35, -5.60, 1.46, -3.1],
		[-2.10, 2.35, -12.25, -5.60, 1.48, -13.1]
	]:
		var fill = SpotLight3D.new()
		fill.name = "ColdRainBounceBehindLeftWing"
		fill.position = Vector3(float(data[0]), float(data[1]), float(data[2]))
		fill.light_color = Color(0.245, 0.325, 0.405)
		fill.light_energy = 0.86
		fill.spot_range = 10.0
		fill.spot_angle = 46.0
		fill.spot_attenuation = 1.9
		fill.shadow_enabled = false
		root.add_child(fill)
		fill.look_at(Vector3(float(data[3]), float(data[4]), float(data[5])), Vector3.UP)

	# Soft local sky spill keeps the boarded recesses legible from the normal
	# follow camera. It is deliberately weaker than every lantern in the yard.
	for data in [[-4.20, 1.72, -3.15, 1.15, 7.4], [-4.10, 1.82, -13.15, 0.88, 7.8]]:
		var spill = OmniLight3D.new()
		spill.name = "DiffuseColdSkySpillBehindLeftWing"
		spill.position = Vector3(float(data[0]), float(data[1]), float(data[2]))
		spill.light_color = Color(0.21, 0.285, 0.36)
		spill.light_energy = float(data[3])
		spill.omni_range = float(data[4])
		spill.omni_attenuation = 1.48
		spill.shadow_enabled = false
		root.add_child(spill)


func _build_restrained_wall_horror_details(root: Node3D) -> void:
	var wall_root_moss = _make_material(Color(0.032, 0.048, 0.036), 0.9)
	var old_paper = _make_material(Color(0.20, 0.145, 0.075), 0.96)
	var soaked_paper = _make_material(Color(0.105, 0.075, 0.045), 0.98)
	var old_adhesive = _make_material(Color(0.065, 0.052, 0.038), 0.94)

	# Broken, varied wall-root masses read as years of rising damp rather than a
	# decorative horizontal stripe.
	for data in [
		[5.695, 0.31, 4.8, 0.23, 2.7], [5.695, 0.24, -1.7, 0.15, 3.8],
		[5.695, 0.34, -9.4, 0.28, 2.2], [5.695, 0.26, -17.2, 0.18, 4.1],
		[5.695, 0.32, -25.4, 0.24, 2.9], [-5.695, 0.27, -5.8, 0.19, 3.4],
		[-5.695, 0.33, -15.6, 0.26, 2.5], [-5.695, 0.25, -24.1, 0.16, 3.7],
	]:
		var patch = _add_box(
			root, "IrregularWallRootDamp",
			Vector3(0.018, float(data[3]), float(data[4])),
			Vector3(float(data[0]), float(data[1]), float(data[2])), wall_root_moss
		)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Sparse, illegible paper remnants and their darker adhesive ghosts. No
	# readable talisman symbols are used; the implication comes from placement,
	# water damage, and missing fragments.
	for data in [
		[5.68, 1.48, 2.35, 0.19, 0.42, -7.0],
		[5.68, 1.82, -7.15, 0.14, 0.31, 5.0],
		[-5.68, 1.36, -2.75, 0.17, 0.36, -4.0],
		[-5.68, 2.02, -18.4, 0.12, 0.27, 8.0],
	]:
		_add_box(root, "FadedPaperAdhesiveGhost", Vector3(0.016, float(data[4]) * 1.18, float(data[3]) * 1.22), Vector3(float(data[0]), float(data[1]), float(data[2])), old_adhesive, Vector3(float(data[5]), 0.0, 0.0))
		var fragment = _add_box(root, "RottenSoakedPaperFragment", Vector3(0.021, float(data[4]), float(data[3])), Vector3(float(data[0]) - signf(float(data[0])) * 0.012, float(data[1]) + 0.02, float(data[2]) + 0.025), old_paper if int(absf(float(data[2]))) % 2 == 0 else soaked_paper, Vector3(float(data[5]), 0.0, 0.0))
		fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The main hall gets only two distant traces, avoiding a theatrical or busy
	# horror-film wall while still suggesting long-abandoned ritual use.
	for data in [[-3.9, 1.72, 0.22, 0.48, -6.0], [4.15, 2.08, 0.15, 0.34, 4.0]]:
		_add_box(root, "HallPaperAdhesiveGhost", Vector3(float(data[2]) * 1.2, float(data[3]) * 1.16, 0.018), Vector3(float(data[0]), float(data[1]), -32.875), old_adhesive, Vector3(0.0, 0.0, float(data[4])))
		var hall_fragment = _add_box(root, "HallRottenPaperFragment", Vector3(float(data[2]), float(data[3]), 0.022), Vector3(float(data[0]) + 0.018, float(data[1]) + 0.02, -32.858), soaked_paper, Vector3(0.0, 0.0, float(data[4])))
		hall_fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Very weak cool bounce light reveals material response on the otherwise
	# black right wing. It is intentionally too dim to read as a visible lamp.
	for data in [
		[2.30, 2.18, 7.1, 5.72, 1.38, 5.6],
		[2.25, 2.15, -3.8, 5.72, 1.35, -5.2],
		[2.10, 2.25, -14.5, 5.72, 1.40, -15.5],
		[2.20, 2.20, -25.6, 5.72, 1.36, -25.0],
	]:
		var damp_wall_fill = SpotLight3D.new()
		damp_wall_fill.name = "ColdRainBounceOnRightWall"
		damp_wall_fill.position = Vector3(float(data[0]), float(data[1]), float(data[2]))
		damp_wall_fill.light_color = Color(0.29, 0.37, 0.46)
		damp_wall_fill.light_energy = 0.72
		damp_wall_fill.spot_range = 8.6
		damp_wall_fill.spot_angle = 48.0
		damp_wall_fill.spot_attenuation = 1.8
		damp_wall_fill.shadow_enabled = false
		root.add_child(damp_wall_fill)
		damp_wall_fill.look_at(Vector3(float(data[3]), float(data[4]), float(data[5])), Vector3.UP)


func _build_ground_collision(root: Node3D) -> void:
	var ground_collision = StaticBody3D.new()
	ground_collision.name = "GroundCollision"
	var collision_shape = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(14.8, 0.12, 43.0)
	collision_shape.shape = ground_shape
	collision_shape.position = Vector3(0.0, -0.08, -11.0)
	ground_collision.add_child(collision_shape)
	root.add_child(ground_collision)


func _build_stone_full_courtyard(ground_visual: Node3D) -> void:
	if not ResourceLoader.exists(COURTYARD_STONE_MATERIAL):
		return
	var stone_ground = Node3D.new()
	stone_ground.name = "CourtyardStoneGround_FullCourtyard"
	stone_ground.position.z = GROUND_VISUAL_CENTER_Z
	ground_visual.add_child(stone_ground)

	var stone_mesh = PlaneMesh.new()
	stone_mesh.size = GROUND_VISUAL_SIZE
	stone_mesh.subdivide_width = 72
	stone_mesh.subdivide_depth = 224
	stone_mesh.material = load(COURTYARD_STONE_MATERIAL) as Material
	var stone_surface = MeshInstance3D.new()
	stone_surface.name = "DisplacedBluestoneSurface"
	stone_surface.mesh = stone_mesh
	stone_surface.position = Vector3(0.0, 0.012, 0.0)
	stone_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stone_ground.add_child(stone_surface)

	# Sparse edge inserts break the perfect-plane silhouette without touching collision.
	var insert_material = _make_material(Color(0.105, 0.12, 0.13), 0.72)
	var insert_data = [
		[-4.45, 6.25, 0.74, 1.1, -1.2],
		[4.25, 4.3, 0.92, 0.66, 1.4],
		[-4.2, 1.4, 1.15, 0.58, 0.9],
		[4.5, -1.65, 0.7, 1.05, -1.0],
		[-4.35, -8.2, 0.86, 0.72, 1.1],
		[4.42, -14.1, 1.05, 0.62, -0.8],
		[-4.5, -21.4, 0.72, 1.12, 1.3],
		[4.3, -27.2, 0.94, 0.68, -1.1],
	]
	for data in insert_data:
		var insert = _add_box(
			stone_ground,
			"SlightlyRaisedStone",
			Vector3(float(data[2]), 0.025, float(data[3])),
			Vector3(float(data[0]), 0.003, float(data[1]) - GROUND_VISUAL_CENTER_Z),
			insert_material,
			Vector3(0.0, float(data[4]), 0.0)
		)
		insert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_props(root: Node3D, stone_material: Material, wood_material: Material) -> void:
	for data in [[-5.0, -3.0, 0.5], [-4.4, -15.4, 0.38], [4.65, 2.1, 0.46], [4.95, -8.5, 0.56], [4.45, -21.5, 0.4]]:
		_add_pot(root, Vector3(data[0], data[2] * 0.5, data[1]), data[2], stone_material)
	for data in [[4.7, -2.2], [4.45, -13.8], [-4.65, -22.5]]:
		_add_box(root, "AbandonedCrate", Vector3(0.9, 0.72, 0.82), Vector3(data[0], 0.36, data[1]), wood_material, Vector3(0.0, 13.0, 0.0))
	for side in [-1.0, 1.0]:
		for z in [4.0, -1.5, -8.0, -15.0, -23.0]:
			if side < 0.0 and z > 1.0:
				continue
			for offset in range(4):
				var blade = _add_box(root, "WetGrass", Vector3(0.035, 0.72 + offset * 0.08, 0.035), Vector3(side * (4.25 + offset * 0.18), 0.36, z + offset * 0.24), stone_material)
				blade.rotation_degrees.z = side * (8.0 + offset * 3.0)


func _build_puddles(root: Node3D) -> void:
	# Localized puddles are now authored by the full-courtyard PBR puddle mask.
	pass


func _build_lanterns(root: Node3D) -> void:
	for data in [[5.0, -7.0], [-5.0, -18.5]]:
		var position: Vector3 = Vector3(float(data[0]), 2.8, float(data[1]))
		var is_right_wing = float(data[0]) > 0.0
		_add_unified_old_lantern(root, "CourtyardOldLantern_%s" % str(data[1]), position, 1.18, 3.7, false, is_right_wing, false)
	for data in [[1.6, 2.30], [-10.1, 1.95], [-21.3, 1.82]]:
		var z := float(data[0])
		var fill := SpotLight3D.new()
		fill.name = "RightGalleryRainBounce"
		fill.position = Vector3(3.05, 2.84, z + 1.35)
		fill.light_color = Color(0.43, 0.50, 0.60)
		fill.light_energy = float(data[1])
		fill.spot_range = 9.5
		fill.spot_angle = 54.0
		fill.spot_attenuation = 1.24
		fill.shadow_enabled = false
		root.add_child(fill)
		fill.look_at(Vector3(5.65, 1.60, z - 0.50), Vector3.UP)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "ChenMo"
	player.position = Vector3(0.0, 0.02, 7.4)
	if GameState.return_to_courtyard_from_hall:
		GameState.return_to_courtyard_from_hall = false
		player.position.z = MAIN_GATE_INTERACTION_Z + 1.65
		facing = "front"
	elif GameState.return_to_courtyard_from_left_wing:
		GameState.return_to_courtyard_from_left_wing = false
		player.position = Vector3(LEFT_WING_DOOR_CENTER.x + 1.65, 0.02, LEFT_WING_DOOR_CENTER.y)
		facing = "right"
	add_child(player)
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	# A 72 cm diameter capsule matches the sprite's shoulder/hip footprint and
	# clears the authored 1.1 m doorway without weakening solid-object blocking.
	capsule.radius = 0.36
	capsule.height = 1.62
	collision.shape = capsule
	collision.position.y = 0.81
	player.add_child(collision)

	character_sprite = AnimatedSprite3D.new()
	character_sprite.position = Vector3(0.0, 0.92, 0.0)
	character_sprite.pixel_size = 0.00242
	character_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	character_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	character_sprite.alpha_scissor_threshold = 0.16
	character_sprite.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	character_sprite.alpha_antialiasing_edge = 0.34
	# The character frames intentionally have no mipmaps. Sampling them with a
	# mipmapped filter pulled bright RGB from transparent texels and produced the
	# pale outline visible around the boots and trousers.
	character_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# Keep the authored character contrast readable in the very dark courtyard,
	# while a restrained cool tint ties the unlit billboard into the moonlight.
	character_sprite.shaded = false
	character_sprite.modulate = Color(0.88, 0.92, 1.0, 1.0)
	character_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	character_sprite.sprite_frames = _build_character_frames()
	character_sprite.animation_finished.connect(_on_character_animation_finished)
	character_sprite.frame_changed.connect(_on_character_frame_changed)
	player.add_child(character_sprite)
	var edge_blend := Node.new()
	edge_blend.name = "CharacterEdgeBlend"
	edge_blend.set_script(preload("res://scripts/character_edge_blend.gd"))
	character_sprite.add_child(edge_blend)
	_build_ground_contact_shadow()
	_build_footsteps()

	flashlight_origin = Node3D.new()
	player.add_child(flashlight_origin)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.9, 0.69)
	flashlight.light_energy = 5.2
	flashlight.spot_range = 9.5
	flashlight.spot_angle = 24.0
	flashlight.spot_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight_enabled = GameState.flashlight_enabled
	flashlight.visible = flashlight_enabled
	flashlight_origin.add_child(flashlight)


func _build_ground_contact_shadow() -> void:
	contact_shadow = MeshInstance3D.new()
	contact_shadow.name = "GroundContactShadow"
	var shadow_mesh = PlaneMesh.new()
	shadow_mesh.size = Vector2(0.66, 0.34)
	contact_shadow_material = ShaderMaterial.new()
	contact_shadow_material.shader = load("res://shaders/ground_contact_shadow.gdshader") as Shader
	contact_shadow_material.render_priority = 1
	shadow_mesh.material = contact_shadow_material
	contact_shadow.mesh = shadow_mesh
	contact_shadow.position = Vector3(0.0, 0.006, 0.03)
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(contact_shadow)


func _build_footsteps() -> void:
	for path in FOOTSTEP_PATHS:
		var stream = load(path) as AudioStream
		if stream != null:
			footstep_streams.append(stream)
	# Footsteps are player feedback, so keep them on a non-positional channel.
	# The previous 3D channel attenuated them heavily because the camera trails
	# several metres behind the character and the rain bed then masked them.
	# Two voices preserve the short wet-stone tail when the next foot lands.
	for index in range(2):
		var step_player = AudioStreamPlayer.new()
		step_player.name = "StoneFootstep%d" % (index + 1)
		step_player.volume_db = -13.0
		step_player.bus = "Master"
		player.add_child(step_player)
		footstep_players.append(step_player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 49.0
	camera.near = 0.12
	camera.far = 85.0
	camera.current = true
	add_child(camera)
	camera_position = player.global_position + Vector3(CAMERA_SIDE_OFFSET, CAMERA_HEIGHT, CAMERA_DISTANCE)
	camera_position.z = minf(camera_position.z, CAMERA_ENTRANCE_MAX_Z)
	camera_target = player.global_position + Vector3(0.0, 1.05, -2.1)
	camera.global_position = camera_position
	camera.look_at(camera_target, Vector3.UP)


func _update_camera(delta: float, moving: bool) -> void:
	var desired_position = player.global_position + Vector3(CAMERA_SIDE_OFFSET, CAMERA_HEIGHT, CAMERA_DISTANCE)
	desired_position.x = clampf(desired_position.x, CAMERA_SAFE_MIN_X, CAMERA_SAFE_MAX_X)
	desired_position.z = minf(desired_position.z, CAMERA_ENTRANCE_MAX_Z)
	var desired_target = player.global_position + Vector3(0.0, 1.02, -2.15)
	camera_position = camera_position.lerp(desired_position, 1.0 - exp(-delta * 5.8))
	camera_target = camera_target.lerp(desired_target, 1.0 - exp(-delta * 7.2))
	var target_bob = 0.0
	if moving and character_sprite.animation.begins_with("walk_"):
		var gait_phase = TAU * (float(character_sprite.frame) + character_sprite.frame_progress) / 8.0
		target_bob = sin(gait_phase * 2.0) * 0.008
	camera_bob_offset = lerpf(camera_bob_offset, target_bob, 1.0 - exp(-delta * 13.0))
	camera.global_position = camera_position + Vector3(0.0, camera_bob_offset, 0.0)
	camera.look_at(camera_target, Vector3.UP)


func _build_rain() -> void:
	rain = Node3D.new()
	rain.name = "RainLayers"
	add_child(rain)
	# Keep the rain over the exposed court so covered verandas remain readable.
	_add_rain_layer(rain, "FarRain", 620, Vector2(0.0025, 0.105), 0.045, 13.0, 17.0, Vector3(5.45, 0.4, 13.0))
	_add_rain_layer(rain, "MidRain", 220, Vector2(0.0045, 0.18), 0.065, 14.0, 19.0, Vector3(5.1, 0.4, 11.0))
	_add_rain_layer(rain, "NearRain", 38, Vector2(0.008, 0.25), 0.08, 16.0, 21.0, Vector3(4.65, 0.4, 8.5))


func _add_rain_layer(parent: Node3D, layer_name: String, amount: int, streak_size: Vector2, alpha: float, speed_min: float, speed_max: float, extents: Vector3) -> void:
	var layer = GPUParticles3D.new()
	layer.name = layer_name
	layer.amount = amount
	layer.lifetime = 1.35
	layer.visibility_aabb = AABB(Vector3(-12.0, -8.0, -14.0), Vector3(24.0, 18.0, 28.0))
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3(-0.13, -1.0, 0.04)
	process.spread = 3.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = Vector3(0.0, -8.0, 0.0)
	layer.process_material = process
	var rain_mesh = QuadMesh.new()
	rain_mesh.size = streak_size
	var rain_material = StandardMaterial3D.new()
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.albedo_color = Color(0.42, 0.49, 0.55, alpha)
	rain_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	rain_mesh.material = rain_material
	layer.draw_pass_1 = rain_mesh
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(layer)
	layer.emitting = true


func _build_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "HUDLayer"
	add_child(canvas)
	courtyard_hud = EXTERIOR_HUD_SCENE.instantiate() as Control
	courtyard_hud.name = "CourtyardHUD"
	canvas.add_child(courtyard_hud)
	if courtyard_hud.has_method("set_objective"):
		courtyard_hud.call("set_objective", _courtyard_objective())
	if courtyard_hud.has_method("set_interaction_text"):
		courtyard_hud.call("set_interaction_text", "")
	if courtyard_hud.has_method("set_door_prompt_visible"):
		courtyard_hud.call("set_door_prompt_visible", false, true)
	if courtyard_hud.has_method("set_flashlight_enabled"):
		courtyard_hud.call("set_flashlight_enabled", flashlight_enabled)
	thunder_flash = ColorRect.new()
	thunder_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thunder_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thunder_flash.color = Color(0.68, 0.78, 0.94, 0.0)
	canvas.add_child(thunder_flash)


func _update_hud_state(moving: bool) -> void:
	if courtyard_hud == null:
		return
	var player_planar = Vector2(player.global_position.x, player.global_position.z)
	var left_delta = player_planar - LEFT_WING_DOOR_CENTER
	var near_left_wing = absf(left_delta.x) <= LEFT_WING_DOOR_HALF_EXTENTS.x and absf(left_delta.y) <= LEFT_WING_DOOR_HALF_EXTENTS.y
	var near_gate = player.global_position.z <= MAIN_GATE_INTERACTION_Z and absf(player.global_position.x) <= MAIN_GATE_INTERACTION_HALF_WIDTH
	var near_estate_exit: bool = estate_departure != null and estate_departure.can_start()
	var gate_feedback_active := near_gate and Time.get_ticks_msec() < gate_locked_feedback_until_msec
	if near_gate != hud_near_gate or near_left_wing != hud_near_left_wing or near_estate_exit != hud_near_estate_exit:
		hud_near_gate = near_gate
		hud_near_left_wing = near_left_wing
		hud_near_estate_exit = near_estate_exit
		if courtyard_hud.has_method("set_door_prompt_visible"):
			courtyard_hud.call("set_door_prompt_visible", near_gate or near_left_wing or near_estate_exit)
		if courtyard_hud.has_method("set_interaction_text"):
			if near_estate_exit:
				courtyard_hud.call("set_interaction_text", "离开王宅")
			elif near_left_wing:
				courtyard_hud.call("set_interaction_text", "进入左侧厢房")
			else:
				courtyard_hud.call("set_interaction_text", "")
		if courtyard_hud.has_method("set_objective"):
			courtyard_hud.call("set_objective", _courtyard_objective())

	var story_stage = 0
	var story_text = "沿着石板路，前往亮着灯的主屋"
	if player.global_position.z < -18.0:
		story_stage = 2
		story_text = "那扇门后……刚才像是有动静"
	elif player.global_position.z < -7.0:
		story_stage = 1
		story_text = "院子太安静了，只剩下雨声"

	if near_left_wing:
		story_text = "门缝里有一股潮湿的香灰味"
	elif gate_feedback_active:
		story_text = "门锁纹丝不动。你必须要有钥匙。"
	if near_gate and courtyard_hud.has_method("set_interaction_text"):
		if gate_feedback_active:
			courtyard_hud.call("set_interaction_text", "你必须要有钥匙")
		elif _is_main_house_unlocked():
			courtyard_hud.call("set_interaction_text", "进入王氏正堂")
		elif _has_main_house_key():
			courtyard_hud.call("set_interaction_text", "使用钥匙打开主屋大门")
		else:
			courtyard_hud.call("set_interaction_text", "检查上锁的主屋大门")
	if GameState.has_hanging_coda_completed():
		return
	if story_stage != hud_story_stage or moving != hud_was_moving or near_gate or near_left_wing:
		hud_story_stage = story_stage
		hud_was_moving = moving
		if courtyard_hud.has_method("set_story_caption"):
			courtyard_hud.call("set_story_caption", story_text, gate_feedback_active or (moving and not near_gate and not near_left_wing), gate_feedback_active)


func _courtyard_objective() -> String:
	var final_objective := GameState.estate_investigation_objective()
	if not final_objective.is_empty():
		return final_objective
	if GameState.has_item("study_old_copper_key"):
		return "寻找旧铜钥匙能够打开的门"
	if GameState.has_item("wang_warning_talisman"):
		return "调查王氏旧事的来源"
	if _is_main_house_unlocked():
		return "调查主大堂供奉区"
	if _has_main_house_key():
		return "进入荒宅主屋"
	return "调查左侧厢房"


func _try_enter_main_house() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("unlock_main_house"):
		_show_locked_gate_feedback()
		return
	if not bool(game_state.call("unlock_main_house")):
		_show_locked_gate_feedback()
		return
	_change_scene(INTERIOR_SCENE_PATH)


func _show_locked_gate_feedback() -> void:
	gate_locked_feedback_until_msec = Time.get_ticks_msec() + 2400
	if courtyard_hud == null:
		return
	if courtyard_hud.has_method("set_interaction_text"):
		courtyard_hud.call("set_interaction_text", "你必须要有钥匙")
	if courtyard_hud.has_method("set_story_caption"):
		courtyard_hud.call("set_story_caption", "门锁纹丝不动。你必须要有钥匙。", true, true)


func _has_main_house_key() -> bool:
	var game_state = get_node_or_null("/root/GameState")
	return game_state != null and game_state.has_method("has_item") and bool(game_state.call("has_item", MAIN_HOUSE_KEY_ID))


func _is_main_house_unlocked() -> bool:
	var game_state = get_node_or_null("/root/GameState")
	return game_state != null and game_state.has_method("is_main_house_door_unlocked") and bool(game_state.call("is_main_house_door_unlocked"))


func _build_audio() -> void:
	audio_bgm = AudioStreamPlayer.new()
	audio_bgm.bus = &"Ambience"
	audio_bgm.volume_db = -7.0
	add_child(audio_bgm)
	_assign_audio(audio_bgm, "res://assets/audio/thunderstorm_2min_loop.mp3", true)
	if audio_bgm.stream != null:
		audio_bgm.play()
	audio_thunder = AudioStreamPlayer.new()
	audio_thunder.bus = &"Thunder"
	audio_thunder.volume_db = -7.0
	add_child(audio_thunder)
	_assign_audio(audio_thunder, "res://assets/audio/thunder_01.ogg", false)
	thunder_timer = Timer.new()
	thunder_timer.one_shot = true
	add_child(thunder_timer)
	thunder_timer.timeout.connect(_on_thunder)


func _update_facing(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return
	var horizontal = absf(direction.x)
	var vertical = absf(direction.z)
	var was_horizontal = facing == "left" or facing == "right"
	# Bias the current axis slightly so tiny diagonal-stick changes do not make
	# the billboard flicker between front and side poses every physics frame.
	if was_horizontal:
		if vertical > horizontal * DIRECTION_SWITCH_BIAS:
			facing = "back" if direction.z < 0.0 else "front"
		else:
			facing = "right" if direction.x > 0.0 else "left"
	elif horizontal > vertical * DIRECTION_SWITCH_BIAS:
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "back" if direction.z < 0.0 else "front"


func _update_character_animation(moving: bool, planar_speed: float) -> void:
	wants_to_move = moving
	if moving:
		if locomotion_state == "idle" or locomotion_state == "stopping":
			_begin_locomotion_animation("starting", "start_walk_" + facing, facing)
			_play_footstep(maxf(planar_speed, WALK_SPEED * 0.45))
		elif animation_facing != facing:
			_begin_walk_direction_change(facing)
		elif locomotion_state == "walking":
			_play_if_needed("walk_" + facing)
	else:
		if locomotion_state == "walking" or locomotion_state == "starting" or locomotion_state == "turning":
			_begin_locomotion_animation("stopping", "stop_walk_" + animation_facing, animation_facing)
		elif locomotion_state == "idle":
			animation_facing = facing
			_play_if_needed("idle_" + facing)

	if locomotion_state == "walking":
		character_sprite.speed_scale = clampf(planar_speed / WALK_SPEED, MIN_WALK_ANIMATION_SCALE, 1.08)
	else:
		character_sprite.speed_scale = 1.0


func _begin_locomotion_animation(state: String, animation_name: String, direction: String) -> void:
	if state == "stopping" and character_sprite.sprite_frames.has_animation(animation_name):
		# Start deceleration from the pose actually on screen, not always frame 5.
		var current_texture = character_sprite.sprite_frames.get_frame_texture(character_sprite.animation, character_sprite.frame)
		character_sprite.sprite_frames.set_frame(animation_name, 0, current_texture)
	locomotion_state = state
	animation_facing = direction
	if character_sprite.sprite_frames.has_animation(animation_name):
		character_sprite.play(animation_name)
	elif state == "starting":
		locomotion_state = "walking"
		character_sprite.play("walk_" + direction)
	else:
		locomotion_state = "idle"
		character_sprite.play("idle_" + direction)


func _begin_walk_direction_change(new_facing: String) -> void:
	var old_frame = character_sprite.frame
	var transition_name = "walk_%s_to_%s" % [animation_facing, new_facing]
	animation_facing = new_facing
	if character_sprite.sprite_frames.has_animation(transition_name):
		locomotion_state = "turning"
		character_sprite.play(transition_name)
	else:
		locomotion_state = "walking"
		character_sprite.play("walk_" + new_facing)
		character_sprite.frame = mini(old_frame, character_sprite.sprite_frames.get_frame_count(character_sprite.animation) - 1)


func _play_if_needed(animation_name: String) -> void:
	if character_sprite.animation != animation_name:
		character_sprite.play(animation_name)


func _on_character_animation_finished() -> void:
	match locomotion_state:
		"starting", "turning":
			if wants_to_move:
				# Start ends on walk 2; a moving turn ends on destination walk 1.
				var continuation_frame = 3 if locomotion_state == "starting" else 2
				locomotion_state = "walking"
				animation_facing = facing
				character_sprite.play("walk_" + animation_facing)
				character_sprite.set_frame_and_progress(continuation_frame, 0.0)
			else:
				_begin_locomotion_animation("stopping", "stop_walk_" + animation_facing, animation_facing)
		"stopping":
			if wants_to_move:
				_begin_locomotion_animation("starting", "start_walk_" + facing, facing)
			else:
				locomotion_state = "idle"
				animation_facing = facing
				character_sprite.play("idle_" + animation_facing)


func _on_character_frame_changed() -> void:
	if footstep_players.is_empty() or footstep_streams.is_empty() or not character_sprite.animation.begins_with("walk_"):
		return
	if "_to_" in character_sprite.animation:
		return
	if character_sprite.frame != 0 and character_sprite.frame != 4:
		return
	var planar_speed = Vector2(player.velocity.x, player.velocity.z).length()
	if planar_speed < 0.55:
		return
	_play_footstep(planar_speed)


func _play_footstep(planar_speed: float) -> void:
	if footstep_players.is_empty() or footstep_streams.is_empty():
		return
	var step_index = randi_range(0, footstep_streams.size() - 1)
	if footstep_streams.size() > 1 and step_index == last_footstep_index:
		step_index = (step_index + randi_range(1, footstep_streams.size() - 1)) % footstep_streams.size()
	last_footstep_index = step_index
	var step_player = footstep_players[footstep_voice_index]
	footstep_voice_index = (footstep_voice_index + 1) % footstep_players.size()
	step_player.stream = footstep_streams[step_index]
	step_player.pitch_scale = randf_range(0.96, 1.04)
	step_player.volume_db = lerpf(-15.0, -11.5, clampf(planar_speed / WALK_SPEED, 0.0, 1.0))
	step_player.play()


func _update_character_grounding(delta: float, planar_speed: float) -> void:
	if contact_shadow == null:
		return
	var motion = clampf(planar_speed / WALK_SPEED, 0.0, 1.0)
	var pressure = 0.0
	if character_sprite.animation.begins_with("walk_"):
		pressure = [0.10, -0.03, 0.03, 0.12, 0.10, -0.03, 0.03, 0.12][character_sprite.frame % 8]
	var target_scale = Vector3(1.0 + pressure * motion, 1.0, 1.0 - pressure * 0.42 * motion)
	contact_shadow.scale = contact_shadow.scale.lerp(target_scale, 1.0 - exp(-delta * 15.0))
	if planar_speed > 0.05:
		contact_shadow.rotation.y = lerp_angle(contact_shadow.rotation.y, atan2(player.velocity.x, player.velocity.z), 1.0 - exp(-delta * 9.0))
	if contact_shadow_material != null:
		contact_shadow_material.set_shader_parameter("motion", motion)
		contact_shadow_material.set_shader_parameter("stride_phase", float(character_sprite.frame % 8) / 8.0)


func _update_flashlight_pose() -> void:
	match facing:
		"front":
			flashlight_origin.position = Vector3(-0.27, 0.9, 0.05)
			flashlight_origin.rotation_degrees = Vector3(-13.0, 180.0, 0.0)
		"left":
			flashlight_origin.position = Vector3(-0.28, 0.92, -0.02)
			flashlight_origin.rotation_degrees = Vector3(-13.0, 90.0, 0.0)
		"right":
			flashlight_origin.position = Vector3(0.3, 0.92, -0.02)
			flashlight_origin.rotation_degrees = Vector3(-13.0, -90.0, 0.0)
		_:
			flashlight_origin.position = Vector3(0.28, 0.94, -0.08)
			flashlight_origin.rotation_degrees = Vector3(-13.0, 0.0, 0.0)


func _build_character_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for direction in ["front", "back", "left", "right"]:
		_add_character_sequence(frames, "idle_" + direction, "chen_mo_%s_idle" % direction, 6, 3.2, true)
		_add_character_sequence(frames, "walk_" + direction, "chen_mo_%s_walk" % direction, 8, WALK_ANIMATION_FPS, true)
		_add_character_sequence(frames, "start_walk_" + direction, "chen_mo_start_walk_%s" % direction, 3, 10.0, false)
		_add_character_sequence(frames, "stop_walk_" + direction, "chen_mo_stop_walk_%s" % direction, 3, 10.0, false)
	for from_direction in ["front", "back", "left", "right"]:
		for to_direction in ["front", "back", "left", "right"]:
			if from_direction == to_direction:
				continue
			var animation_name = "walk_%s_to_%s" % [from_direction, to_direction]
			var file_prefix = "chen_mo_walk_%s_to_%s" % [from_direction, to_direction]
			_add_character_sequence(frames, animation_name, file_prefix, 4, 10.0, false)
	return frames


func _add_character_sequence(frames: SpriteFrames, animation: String, file_prefix: String, count: int, fps: float, loop: bool) -> void:
	var first_path = "%s/%s_00.png" % [ANIMATION_ROOT, file_prefix]
	if not ResourceLoader.exists(first_path):
		return
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	for index in range(count):
		var path = "%s/%s_%02d.png" % [ANIMATION_ROOT, file_prefix, index]
		if ResourceLoader.exists(path):
			frames.add_frame(animation, load(path) as Texture2D)


func _add_box(root: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, rotation_degrees = Vector3.ZERO) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var box = BoxMesh.new()
	box.size = size
	box.material = material
	instance.mesh = box
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	root.add_child(instance)
	return instance


func _add_pot(root: Node3D, position: Vector3, radius: float, material: Material) -> void:
	var instance = MeshInstance3D.new()
	instance.name = "AbandonedPot"
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = radius * 1.55
	mesh.radial_segments = 18
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	root.add_child(instance)


func _make_material(color: Color, roughness: float, metallic = 0.0, transparent = false, emission = Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.4
	return material


func _schedule_thunder() -> void:
	thunder_timer.wait_time = randf_range(9.0, 17.0)
	thunder_timer.start()


func _on_thunder() -> void:
	if audio_thunder.stream != null:
		audio_thunder.play()
	if GameState.reduced_flashes:
		_schedule_thunder()
		return
	if thunder_tween != null:
		thunder_tween.kill()
	thunder_tween = create_tween()
	thunder_tween.tween_property(thunder_flash, "color", Color(0.68, 0.78, 0.94, 0.15), 0.045)
	thunder_tween.tween_interval(0.1)
	thunder_tween.tween_property(thunder_flash, "color", Color(0.68, 0.78, 0.94, 0.0), 0.3)
	_schedule_thunder()


func _assign_audio(player_node: AudioStreamPlayer, path: String, looped: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path) as AudioStream
	if stream is AudioStreamMP3:
		stream.loop = looped
	elif stream is AudioStreamOggVorbis:
		stream.loop = looped
	player_node.stream = stream


func _change_scene(scene_path: String) -> void:
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
