extends CharacterBody2D

signal moving_changed(is_moving: bool)
signal movement_state_changed(facing: String, is_moving: bool)
signal flashlight_toggled(enabled: bool)

@export var move_speed = 125.0
@export var sprite_scale = Vector2(0.72, 0.72)
@export var playable_bounds = Rect2(Vector2(320.0, 620.0), Vector2(1280.0, 330.0))
@export var flashlight_enabled = true
@export var flashlight_range = 470.0
@export var flashlight_width = 150.0
@export var flashlight_cone_texture_path = "res://assets/ui/flashlight_cone_soft.png"
@export var flashlight_volume_texture_path = "res://assets/ui/flashlight_volume_soft.png"
@export var flashlight_core_texture_path = "res://assets/ui/flashlight_core_soft.png"
@export var flashlight_spill_texture_path = "res://assets/ui/flashlight_spill_soft.png"
@export var front_texture_path = "res://assets/characters/chen_mo_front.png"
@export var back_texture_path = "res://assets/characters/chen_mo_back.png"
@export var left_texture_path = "res://assets/characters/chen_mo_left.png"
@export var right_texture_path = "res://assets/characters/chen_mo_right.png"
@export var animation_frames_dir = "res://assets/characters/animations"

const TURN_PAIRS = [
	["front", "back"],
	["front", "left"],
	["front", "right"],
	["back", "front"],
	["back", "left"],
	["back", "right"],
	["left", "front"],
	["left", "back"],
	["left", "right"],
	["right", "front"],
	["right", "back"],
	["right", "left"],
]
const FOOTSTEP_PATHS = [
	"res://assets/audio/footstep_stone_01.wav",
	"res://assets/audio/footstep_stone_02.wav",
	"res://assets/audio/footstep_stone_03.wav",
	"res://assets/audio/footstep_stone_04.wav",
	"res://assets/audio/footstep_stone_05.wav",
	"res://assets/audio/footstep_stone_06.wav",
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flashlight_origin: Marker2D = get_node_or_null("FlashlightOrigin") as Marker2D
@onready var flashlight_beam: Polygon2D = get_node_or_null("FlashlightOrigin/FlashlightBeam") as Polygon2D
@onready var shadow: Polygon2D = $Shadow

var facing = "back"
var is_moving = false
var direction_textures: Dictionary = {}
var held_direction_order: Array[String] = []
var flashlight_intensity = 1.0
var flashlight_light: PointLight2D
var flashlight_volume_sprite: Sprite2D
var flashlight_core_sprite: Sprite2D
var flashlight_spill_sprite: Sprite2D
var flashlight_mouth_sprite: Sprite2D
var flashlight_core: Polygon2D
var flashlight_surface: Polygon2D
var last_reported_facing = ""
var last_reported_is_moving = false
var is_turning = false
var turn_from_facing = ""
var turn_target_facing = ""
var footstep_players: Array[AudioStreamPlayer] = []
var footstep_streams: Array[AudioStream] = []
var footstep_voice_index := 0
var last_footstep_index := -1
var last_footstep_time_msec := -1000


func _ready() -> void:
	animated_sprite.scale = sprite_scale
	animated_sprite.position = Vector2(0.0, -380.0 * sprite_scale.y)
	_setup_flashlight_layers()
	direction_textures = {
		"front": _safe_load_texture(front_texture_path),
		"back": _safe_load_texture(back_texture_path),
		"left": _safe_load_texture(left_texture_path),
		"right": _safe_load_texture(right_texture_path),
	}
	if direction_textures.get("front") == null:
		direction_textures["front"] = _make_fallback_texture("front")
	for direction in ["back", "left", "right"]:
		if direction_textures.get(direction) == null:
			direction_textures[direction] = direction_textures["front"]
	_setup_sprite_frames()
	_setup_footsteps()
	if not animated_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(false)
	_update_flashlight_beam()
	_emit_movement_state_if_changed(true)
	flashlight_toggled.emit(flashlight_enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("flashlight"):
		set_flashlight_enabled(not flashlight_enabled)
		get_viewport().set_input_as_handled()
		return

	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		var direction = _direction_for_action(action)
		if event.is_action_pressed(action):
			_mark_direction_pressed(direction)
		elif event.is_action_released(action):
			_mark_direction_released(direction)


func _physics_process(delta: float) -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_is_moving = input_vector.length_squared() > 0.001
	var was_moving = is_moving

	if is_turning:
		is_moving = false
		velocity = Vector2.ZERO
	elif input_is_moving:
		_prune_released_directions()
		var desired_facing = _get_facing_from_input(input_vector)
		if desired_facing != facing and _has_turn_animation(facing, desired_facing):
			_start_turn(desired_facing)
			is_moving = false
			velocity = Vector2.ZERO
		else:
			facing = desired_facing
			is_moving = true
			velocity = input_vector.normalized() * move_speed
	else:
		is_moving = false
		velocity = Vector2.ZERO

	if not is_turning:
		move_and_slide()
		global_position = _clamp_to_playable_area(global_position)

	if was_moving != is_moving:
		moving_changed.emit(is_moving)
		if is_moving:
			_play_footstep()

	if not is_turning:
		_play_animation(is_moving)
	animated_sprite.speed_scale = clampf(velocity.length() / move_speed, 0.92, 1.16) if is_moving else 1.0
	_update_walk_bob(delta)
	_update_flashlight_intensity(delta)
	_update_flashlight_beam()
	_emit_movement_state_if_changed()


func _set_facing_from_input(input_vector: Vector2) -> void:
	facing = _get_facing_from_input(input_vector)


func _get_facing_from_input(input_vector: Vector2) -> String:
	if not held_direction_order.is_empty():
		return held_direction_order[held_direction_order.size() - 1]

	if absf(input_vector.x) > absf(input_vector.y):
		return "right" if input_vector.x > 0.0 else "left"
	return "front" if input_vector.y > 0.0 else "back"


func _direction_for_action(action: String) -> String:
	match action:
		"ui_up":
			return "back"
		"ui_down":
			return "front"
		"ui_left":
			return "left"
		"ui_right":
			return "right"
	return facing


func _mark_direction_pressed(direction: String) -> void:
	held_direction_order.erase(direction)
	held_direction_order.append(direction)


func _mark_direction_released(direction: String) -> void:
	held_direction_order.erase(direction)


func _prune_released_directions() -> void:
	for direction in held_direction_order.duplicate():
		var action = _action_for_direction(direction)
		if action.is_empty() or not Input.is_action_pressed(action):
			held_direction_order.erase(direction)


func _action_for_direction(direction: String) -> String:
	match direction:
		"back":
			return "ui_up"
		"front":
			return "ui_down"
		"left":
			return "ui_left"
		"right":
			return "ui_right"
	return ""


func _clamp_to_playable_area(position: Vector2) -> Vector2:
	var clamped = position
	clamped.y = clampf(clamped.y, playable_bounds.position.y, playable_bounds.end.y)

	var left_limit = playable_bounds.position.x
	var right_limit = playable_bounds.end.x
	if clamped.y < 700.0:
		# The steps and doorway are intentionally narrower than the muddy yard.
		left_limit = 735.0
		right_limit = 1185.0
	elif clamped.y < 760.0:
		var t = (clamped.y - 700.0) / 60.0
		left_limit = lerpf(735.0, playable_bounds.position.x, t)
		right_limit = lerpf(1185.0, playable_bounds.end.x, t)

	clamped.x = clampf(clamped.x, left_limit, right_limit)
	return clamped


func _setup_sprite_frames() -> void:
	var frames = SpriteFrames.new()
	for animation_name in frames.get_animation_names():
		frames.remove_animation(animation_name)

	for direction in ["front", "back", "left", "right"]:
		var texture: Texture2D = direction_textures.get(direction)
		if texture == null:
			texture = _make_fallback_texture(direction)

		var idle_name = "idle_%s" % direction
		var walk_name = "walk_%s" % direction
		var idle_textures = _load_animation_textures(direction, "idle", texture)
		var walk_textures = _load_animation_textures(direction, "walk", texture)

		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.18)
		frames.set_animation_loop(idle_name, true)
		for idle_texture in idle_textures:
			frames.add_frame(idle_name, idle_texture)

		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 8.0)
		frames.set_animation_loop(walk_name, true)
		for walk_texture in walk_textures:
			frames.add_frame(walk_name, walk_texture)

	for pair in TURN_PAIRS:
		var from_direction: String = pair[0]
		var to_direction: String = pair[1]
		var turn_name = "turn_%s_to_%s" % [from_direction, to_direction]
		var turn_textures = _load_turn_frame_sequence(from_direction, to_direction)
		if turn_textures.is_empty():
			continue
		frames.add_animation(turn_name)
		frames.set_animation_speed(turn_name, 8.0)
		frames.set_animation_loop(turn_name, false)
		for turn_texture in turn_textures:
			frames.add_frame(turn_name, turn_texture)

	animated_sprite.sprite_frames = frames


func _load_animation_textures(direction: String, state: String, fallback_texture: Texture2D) -> Array[Texture2D]:
	var textures = _load_frame_sequence(direction, state)
	if textures.is_empty() and not (direction == "front" and state == "idle"):
		textures = _load_frame_sequence("front", "idle")
	if textures.is_empty():
		textures.append(fallback_texture)
	return textures


func _load_frame_sequence(direction: String, state: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for index in range(16):
		var frame_path = "%s/chen_mo_%s_%s_%02d.png" % [animation_frames_dir, direction, state, index]
		var frame_texture = _safe_load_texture(frame_path)
		if frame_texture == null:
			break
		textures.append(frame_texture)
	return textures


func _load_turn_frame_sequence(from_direction: String, to_direction: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for index in range(8):
		var frame_path = "%s/chen_mo_turn_%s_to_%s_%02d.png" % [animation_frames_dir, from_direction, to_direction, index]
		var frame_texture = _safe_load_texture(frame_path)
		if frame_texture == null:
			break
		textures.append(frame_texture)
	return textures


func _play_animation(moving: bool) -> void:
	if is_turning:
		return
	var animation_name = "%s_%s" % ["walk" if moving else "idle", facing]
	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation(animation_name):
		animation_name = "idle_front"
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _has_turn_animation(from_direction: String, to_direction: String) -> bool:
	if animated_sprite.sprite_frames == null:
		return false
	return animated_sprite.sprite_frames.has_animation("turn_%s_to_%s" % [from_direction, to_direction])


func _start_turn(to_direction: String) -> void:
	var turn_name = "turn_%s_to_%s" % [facing, to_direction]
	if not _has_turn_animation(facing, to_direction):
		facing = to_direction
		return
	turn_from_facing = facing
	turn_target_facing = to_direction
	is_turning = true
	is_moving = false
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(turn_name)


func _on_animation_finished() -> void:
	if not is_turning:
		return

	facing = turn_target_facing if not turn_target_facing.is_empty() else facing
	is_turning = false
	turn_from_facing = ""
	turn_target_facing = ""

	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wants_to_move = input_vector.length_squared() > 0.001
	if wants_to_move:
		_prune_released_directions()
		facing = _get_facing_from_input(input_vector)
	is_moving = wants_to_move
	_play_animation(is_moving)
	if is_moving:
		_play_footstep()
	_emit_movement_state_if_changed(true)


func _update_walk_bob(delta: float) -> void:
	var base_position = Vector2(0.0, -380.0 * sprite_scale.y)
	var target_position = base_position + _get_body_frame_offset()
	var target_rotation = _get_body_frame_rotation()
	var settle_speed = 18.0 if is_moving else 9.0

	animated_sprite.position = animated_sprite.position.lerp(target_position, delta * settle_speed)
	animated_sprite.rotation_degrees = lerpf(animated_sprite.rotation_degrees, target_rotation, delta * settle_speed)

	var shadow_target_x = 1.0
	var shadow_target_y = 1.0
	if is_moving:
		var frame = animated_sprite.frame % 8
		var pressure: float = [0.0, -0.03, 0.14, 0.07, 0.0, -0.03, 0.14, 0.07][frame]
		shadow_target_x = 1.0 + pressure
		shadow_target_y = 1.0 - pressure * 0.55
	else:
		var idle_pressure: float = [0.0, 0.01, 0.025, 0.015, 0.0, 0.005][animated_sprite.frame % 6]
		shadow_target_x = 1.0 + idle_pressure
		shadow_target_y = 1.0 - idle_pressure * 0.35

	shadow.scale.x = lerpf(shadow.scale.x, shadow_target_x, delta * settle_speed)
	shadow.scale.y = lerpf(shadow.scale.y, shadow_target_y, delta * settle_speed)


func _get_body_frame_offset() -> Vector2:
	var frame = animated_sprite.frame
	if animated_sprite.animation.begins_with("walk"):
		var walk_y = [0.0, 3.0, 0.9, -1.7, 0.0, 2.8, 0.8, -1.6]
		match facing:
			"left":
				return Vector2(0.0, walk_y[frame % 8])
			"right":
				return Vector2(0.0, walk_y[frame % 8])
			"front":
				return Vector2([-2.0, -3.2, -1.4, 1.2, 2.0, 3.2, 1.4, -1.2][frame % 8], walk_y[frame % 8])
			"back":
				return Vector2([-1.8, -3.0, -1.4, 1.0, 1.8, 3.0, 1.4, -1.0][frame % 8], [0.0, 3.0, 0.9, -1.8, 0.0, 2.8, 0.8, -1.7][frame % 8])

	var idle_y = [0.0, 0.35, 0.9, 0.65, 0.2, 0.0]
	match facing:
		"left":
			return Vector2([0.0, -0.25, -0.4, -0.2, 0.1, 0.0][frame % 6], idle_y[frame % 6])
		"right":
			return Vector2([0.0, 0.25, 0.4, 0.2, -0.1, 0.0][frame % 6], idle_y[frame % 6])
		"back":
			return Vector2([0.0, -0.3, -0.55, 0.25, 0.55, 0.0][frame % 6], idle_y[frame % 6] * 0.75)
		_:
			return Vector2([0.0, -0.2, -0.35, 0.15, 0.35, 0.0][frame % 6], idle_y[frame % 6])


func _get_body_frame_rotation() -> float:
	var frame = animated_sprite.frame
	if animated_sprite.animation.begins_with("walk"):
		match facing:
			"left":
				return 0.0
			"right":
				return 0.0
			"front":
				return [-0.18, -0.38, -0.12, 0.24, 0.18, 0.38, 0.12, -0.24][frame % 8]
			"back":
				return [-0.16, -0.34, -0.12, 0.20, 0.16, 0.34, 0.12, -0.20][frame % 8]

	if facing == "left":
		return [0.0, -0.08, -0.16, -0.08, 0.04, 0.0][frame % 6]
	if facing == "right":
		return [0.0, 0.08, 0.16, 0.08, -0.04, 0.0][frame % 6]
	if facing == "back":
		return [0.0, -0.08, -0.16, 0.07, 0.16, 0.0][frame % 6]
	return [0.0, -0.06, -0.1, 0.04, 0.1, 0.0][frame % 6]


func _setup_flashlight_layers() -> void:
	var additive_material = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	if flashlight_origin == null:
		flashlight_origin = Marker2D.new()
		flashlight_origin.name = "FlashlightOrigin"
		add_child(flashlight_origin)

	if flashlight_beam == null:
		flashlight_beam = Polygon2D.new()
		flashlight_beam.name = "FlashlightBeam"
		flashlight_beam.z_index = -1
		flashlight_origin.add_child(flashlight_beam)
	flashlight_beam.material = additive_material

	flashlight_core = flashlight_origin.get_node_or_null("FlashlightCore") as Polygon2D
	if flashlight_core == null:
		flashlight_core = Polygon2D.new()
		flashlight_core.name = "FlashlightCore"
		flashlight_core.z_index = flashlight_beam.z_index + 1
		flashlight_origin.add_child(flashlight_core)
	flashlight_core.material = additive_material

	flashlight_surface = flashlight_origin.get_node_or_null("FlashlightSurface") as Polygon2D
	if flashlight_surface == null:
		flashlight_surface = Polygon2D.new()
		flashlight_surface.name = "FlashlightSurface"
		flashlight_surface.z_index = flashlight_beam.z_index - 1
		flashlight_origin.add_child(flashlight_surface)
	flashlight_surface.material = additive_material

	flashlight_volume_sprite = _ensure_flashlight_sprite("FlashlightVolume", additive_material)
	flashlight_core_sprite = _ensure_flashlight_sprite("FlashlightCoreSprite", additive_material)
	flashlight_spill_sprite = _ensure_flashlight_sprite("FlashlightSpill", additive_material)
	flashlight_mouth_sprite = _ensure_flashlight_sprite("FlashlightMouthGlow", additive_material)

	flashlight_volume_sprite.texture = _safe_load_texture(flashlight_volume_texture_path)
	flashlight_core_sprite.texture = _safe_load_texture(flashlight_core_texture_path)
	flashlight_spill_sprite.texture = _safe_load_texture(flashlight_spill_texture_path)
	flashlight_mouth_sprite.texture = _safe_load_texture(flashlight_spill_texture_path)
	flashlight_volume_sprite.z_index = -2
	flashlight_core_sprite.z_index = -1
	flashlight_spill_sprite.z_index = -3
	flashlight_mouth_sprite.z_index = 2
	flashlight_spill_sprite.position = Vector2(290.0, 0.0)
	flashlight_spill_sprite.scale = Vector2(0.98, 0.42)
	flashlight_mouth_sprite.scale = Vector2(0.09, 0.06)
	flashlight_mouth_sprite.position = Vector2.ZERO

	flashlight_light = flashlight_origin.get_node_or_null("FlashlightLight") as PointLight2D
	if flashlight_light == null:
		flashlight_light = PointLight2D.new()
		flashlight_light.name = "FlashlightLight"
		flashlight_light.z_index = -3
		flashlight_origin.add_child(flashlight_light)

	var cone_texture = _safe_load_texture(flashlight_cone_texture_path)
	if cone_texture != null:
		flashlight_light.texture = cone_texture
	flashlight_light.color = Color.html("#F4E6C2")
	flashlight_light.energy = 1.08
	flashlight_light.texture_scale = 0.92
	flashlight_light.enabled = flashlight_enabled


func _ensure_flashlight_sprite(node_name: String, material: CanvasItemMaterial) -> Sprite2D:
	var sprite = flashlight_origin.get_node_or_null(node_name) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = node_name
		sprite.centered = true
		flashlight_origin.add_child(sprite)
	sprite.material = material
	return sprite


func _on_sprite_frame_changed() -> void:
	_update_flashlight_beam()
	if is_moving and animated_sprite.animation.begins_with("walk_") and animated_sprite.frame in [0, 4]:
		_play_footstep()


func _setup_footsteps() -> void:
	for path in FOOTSTEP_PATHS:
		var stream = load(path) as AudioStream
		if stream != null:
			footstep_streams.append(stream)
	for index in range(2):
		var step_player = AudioStreamPlayer.new()
		step_player.name = "ExteriorFootstep%d" % (index + 1)
		step_player.bus = "Master"
		step_player.volume_db = -12.0
		add_child(step_player)
		footstep_players.append(step_player)


func _play_footstep() -> void:
	if footstep_players.is_empty() or footstep_streams.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_footstep_time_msec < 140:
		return
	last_footstep_time_msec = now_msec
	var step_index = randi_range(0, footstep_streams.size() - 1)
	if footstep_streams.size() > 1 and step_index == last_footstep_index:
		step_index = (step_index + randi_range(1, footstep_streams.size() - 1)) % footstep_streams.size()
	last_footstep_index = step_index
	var step_player = footstep_players[footstep_voice_index]
	footstep_voice_index = (footstep_voice_index + 1) % footstep_players.size()
	step_player.stream = footstep_streams[step_index]
	step_player.pitch_scale = randf_range(0.96, 1.04)
	step_player.volume_db = randf_range(-13.0, -11.5)
	step_player.play()


func set_flashlight_enabled(enabled: bool) -> void:
	if flashlight_enabled == enabled:
		return
	flashlight_enabled = enabled
	flashlight_toggled.emit(flashlight_enabled)


func is_flashlight_enabled() -> bool:
	return flashlight_enabled


func _update_flashlight_intensity(delta: float) -> void:
	var target = 1.0 if flashlight_enabled else 0.0
	flashlight_intensity = lerpf(flashlight_intensity, target, delta * 12.0)


func _update_flashlight_beam() -> void:
	if flashlight_origin == null or flashlight_beam == null or flashlight_core == null or flashlight_surface == null:
		return

	var frame_sway = _get_frame_sway()
	var alpha = flashlight_intensity
	# The textured Light2D/Sprite layers carry the visible flashlight; polygons stay hidden
	# so the beam never reads as a hard transparent trapezoid on the ground.
	flashlight_beam.visible = false
	flashlight_core.visible = false
	flashlight_surface.visible = false
	if flashlight_volume_sprite != null:
		flashlight_volume_sprite.visible = alpha > 0.025
	if flashlight_core_sprite != null:
		flashlight_core_sprite.visible = alpha > 0.035
	if flashlight_spill_sprite != null:
		flashlight_spill_sprite.visible = alpha > 0.04
	if flashlight_mouth_sprite != null:
		flashlight_mouth_sprite.visible = alpha > 0.04
	if flashlight_light != null:
		flashlight_light.enabled = alpha > 0.025
		flashlight_light.energy = 1.18 * alpha
	if alpha <= 0.025:
		return

	var pose = _get_flashlight_pose(frame_sway)
	flashlight_origin.position = pose["position"]
	flashlight_origin.rotation = pose["rotation"]
	if flashlight_light != null:
		flashlight_light.texture_scale = pose["light_scale"]
	if flashlight_volume_sprite != null:
		flashlight_volume_sprite.scale = pose["volume_scale"]
		flashlight_volume_sprite.modulate = Color(1.0, 0.93, 0.74, pose["volume_alpha"] * alpha)
	if flashlight_core_sprite != null:
		flashlight_core_sprite.scale = pose["core_scale"]
		flashlight_core_sprite.modulate = Color(1.0, 0.92, 0.70, pose["core_alpha"] * alpha)
	if flashlight_spill_sprite != null:
		flashlight_spill_sprite.position = pose["spill_position"]
		flashlight_spill_sprite.scale = pose["spill_scale"]
		flashlight_spill_sprite.modulate = Color(1.0, 0.86, 0.55, pose["spill_alpha"] * alpha)
	if flashlight_mouth_sprite != null:
		flashlight_mouth_sprite.position = Vector2.ZERO
		flashlight_mouth_sprite.modulate = Color(1.0, 0.94, 0.80, 0.92 * alpha)

	var range = flashlight_range
	var width = flashlight_width
	var pulse = _get_flashlight_pulse()
	var wide = width * (0.92 + pulse * 0.035)
	var far = range * (0.98 + pulse * 0.025)

	flashlight_beam.polygon = PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(far * 0.22, -wide * 0.18),
		Vector2(far * 0.92, -wide * 0.50),
		Vector2(far, 0.0),
		Vector2(far * 0.92, wide * 0.50),
		Vector2(far * 0.22, wide * 0.18),
		Vector2(0.0, 9.0),
	])
	flashlight_core.polygon = PackedVector2Array([
		Vector2(0.0, -3.4),
		Vector2(far * 0.24, -wide * 0.065),
		Vector2(far * 0.72, -wide * 0.18),
		Vector2(far * 0.88, 0.0),
		Vector2(far * 0.72, wide * 0.18),
		Vector2(far * 0.24, wide * 0.065),
		Vector2(0.0, 3.4),
	])
	flashlight_surface.polygon = PackedVector2Array([
		Vector2(far * 0.34, -wide * 0.18),
		Vector2(far * 0.58, -wide * 0.32),
		Vector2(far * 0.86, -wide * 0.22),
		Vector2(far * 0.96, 0.0),
		Vector2(far * 0.82, wide * 0.22),
		Vector2(far * 0.52, wide * 0.28),
		Vector2(far * 0.30, wide * 0.12),
	])

	flashlight_beam.color = Color(0.92, 0.86, 0.68, 0.075 * alpha)
	flashlight_core.color = Color(1.0, 0.93, 0.72, 0.125 * alpha)
	flashlight_surface.color = Color(0.95, 0.84, 0.55, 0.105 * alpha)


func _get_flashlight_pose(frame_sway: Vector2) -> Dictionary:
	if is_turning and not turn_from_facing.is_empty() and not turn_target_facing.is_empty():
		var from_pose = _get_flashlight_pose_for_direction(turn_from_facing, frame_sway)
		var to_pose = _get_flashlight_pose_for_direction(turn_target_facing, frame_sway)
		return _blend_flashlight_poses(from_pose, to_pose, _get_turn_progress())
	return _get_flashlight_pose_for_direction(facing, frame_sway)


func _get_flashlight_pose_for_direction(direction: String, frame_sway: Vector2) -> Dictionary:
	var body_offset = _get_body_frame_offset()
	var hand_jitter = Vector2(frame_sway.x * 0.075, frame_sway.y * 0.10)
	var angle_jitter = deg_to_rad(clampf(frame_sway.y * 0.035 + frame_sway.x * 0.010, -1.8, 1.8))

	match direction:
		"front":
			return {
				"position": Vector2(-68.0, -181.0) + body_offset + hand_jitter,
				"rotation": deg_to_rad(102.0) + angle_jitter,
				"light_scale": 0.62,
				"volume_scale": Vector2(0.72, 0.66),
				"core_scale": Vector2(0.62, 0.50),
				"spill_position": Vector2(220.0, 6.0),
				"spill_scale": Vector2(0.62, 0.28),
				"volume_alpha": 0.64,
				"core_alpha": 0.58,
				"spill_alpha": 0.72,
			}
		"back":
			return {
				"position": Vector2(80.0, -180.0) + body_offset + hand_jitter,
				"rotation": deg_to_rad(-28.0) + angle_jitter,
				"light_scale": 0.72,
				"volume_scale": Vector2(0.80, 0.58),
				"core_scale": Vector2(0.68, 0.42),
				"spill_position": Vector2(250.0, 10.0),
				"spill_scale": Vector2(0.78, 0.34),
				"volume_alpha": 0.48,
				"core_alpha": 0.42,
				"spill_alpha": 0.86,
			}
		"left":
			return {
				"position": Vector2(-104.0, -178.0) + body_offset + hand_jitter,
				"rotation": deg_to_rad(172.0) + angle_jitter,
				"light_scale": 0.74,
				"volume_scale": Vector2(0.82, 0.54),
				"core_scale": Vector2(0.72, 0.38),
				"spill_position": Vector2(276.0, 18.0),
				"spill_scale": Vector2(0.92, 0.30),
				"volume_alpha": 0.60,
				"core_alpha": 0.54,
				"spill_alpha": 0.82,
			}
		"right":
			return {
				"position": Vector2(104.0, -178.0) + body_offset + hand_jitter,
				"rotation": deg_to_rad(8.0) + angle_jitter,
				"light_scale": 0.74,
				"volume_scale": Vector2(0.82, 0.54),
				"core_scale": Vector2(0.72, 0.38),
				"spill_position": Vector2(276.0, 18.0),
				"spill_scale": Vector2(0.92, 0.30),
				"volume_alpha": 0.60,
				"core_alpha": 0.54,
				"spill_alpha": 0.82,
			}

	return {
		"position": Vector2(80.0, -180.0) + body_offset + hand_jitter,
		"rotation": deg_to_rad(-28.0) + angle_jitter,
		"light_scale": 0.72,
		"volume_scale": Vector2(0.80, 0.58),
		"core_scale": Vector2(0.68, 0.42),
		"spill_position": Vector2(250.0, 10.0),
		"spill_scale": Vector2(0.78, 0.34),
		"volume_alpha": 0.48,
		"core_alpha": 0.42,
		"spill_alpha": 0.86,
	}


func _blend_flashlight_poses(from_pose: Dictionary, to_pose: Dictionary, weight: float) -> Dictionary:
	var t = clampf(weight, 0.0, 1.0)
	return {
		"position": (from_pose["position"] as Vector2).lerp(to_pose["position"] as Vector2, t),
		"rotation": lerp_angle(from_pose["rotation"], to_pose["rotation"], t),
		"light_scale": lerpf(from_pose["light_scale"], to_pose["light_scale"], t),
		"volume_scale": (from_pose["volume_scale"] as Vector2).lerp(to_pose["volume_scale"] as Vector2, t),
		"core_scale": (from_pose["core_scale"] as Vector2).lerp(to_pose["core_scale"] as Vector2, t),
		"spill_position": (from_pose["spill_position"] as Vector2).lerp(to_pose["spill_position"] as Vector2, t),
		"spill_scale": (from_pose["spill_scale"] as Vector2).lerp(to_pose["spill_scale"] as Vector2, t),
		"volume_alpha": lerpf(from_pose["volume_alpha"], to_pose["volume_alpha"], t),
		"core_alpha": lerpf(from_pose["core_alpha"], to_pose["core_alpha"], t),
		"spill_alpha": lerpf(from_pose["spill_alpha"], to_pose["spill_alpha"], t),
	}


func _get_turn_progress() -> float:
	if animated_sprite.sprite_frames == null or not animated_sprite.animation.begins_with("turn_"):
		return 1.0
	var frame_count = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
	if frame_count <= 1:
		return 1.0
	return clampf(float(animated_sprite.frame) / float(frame_count - 1), 0.0, 1.0)


func _get_flashlight_pulse() -> float:
	var frame = animated_sprite.frame
	if animated_sprite.animation.begins_with("walk"):
		return [0.0, 0.12, 0.32, 0.18, 0.0, -0.10, -0.22, -0.08][frame % 8]
	return [0.0, 0.06, 0.10, 0.05, -0.02, 0.0][frame % 6]


func _get_frame_sway() -> Vector2:
	var animation_name = animated_sprite.animation
	var frame = animated_sprite.frame
	if animation_name.begins_with("walk"):
		match facing:
			"left":
				return [
					Vector2(0, 0), Vector2(-12, 3), Vector2(-28, 10), Vector2(-16, 6),
					Vector2(0, 1), Vector2(7, -3), Vector2(18, -7), Vector2(8, -3)
				][frame % 8]
			"right":
				return [
					Vector2(0, 0), Vector2(12, 3), Vector2(28, 10), Vector2(16, 6),
					Vector2(0, 1), Vector2(-7, -3), Vector2(-18, -7), Vector2(-8, -3)
				][frame % 8]
			"front":
				return [
					Vector2(0, 0), Vector2(-12, 4), Vector2(-26, 12), Vector2(-14, 7),
					Vector2(0, 1), Vector2(12, 4), Vector2(26, 12), Vector2(14, 7)
				][frame % 8]
			"back":
				return [
					Vector2(0, 0), Vector2(-10, -5), Vector2(-24, -13), Vector2(-14, -7),
					Vector2(0, 0), Vector2(10, 5), Vector2(24, 13), Vector2(14, 7)
				][frame % 8]

	var idle_sway = [
		Vector2(0, 0),
		Vector2(-1, 1),
		Vector2(-3, 2),
		Vector2(1, 2),
		Vector2(3, 1),
		Vector2(0, 1),
	]
	return idle_sway[frame % idle_sway.size()]


func _emit_movement_state_if_changed(force = false) -> void:
	if force or facing != last_reported_facing or is_moving != last_reported_is_moving:
		last_reported_facing = facing
		last_reported_is_moving = is_moving
		movement_state_changed.emit(facing, is_moving)


func _safe_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource

	var image = Image.new()
	var absolute_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path) and image.load(path) == OK:
		return ImageTexture.create_from_image(image)

	return null


func _make_fallback_texture(direction: String) -> Texture2D:
	var image = Image.create(220, 420, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var body_color = Color(0.07, 0.08, 0.085, 1.0)
	for y in range(60, 390):
		for x in range(78, 142):
			image.set_pixel(x, y, body_color)
	return ImageTexture.create_from_image(image)
