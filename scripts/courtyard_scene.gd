extends Node2D

const EXTERIOR_SCENE_PATH = "res://scenes/ExteriorHouseScene.tscn"
const INTERIOR_PLACEHOLDER_PATH = "res://scenes/InteriorPlaceholder.tscn"
const ANIMATION_ROOT = "res://assets/characters/animations"

@export var travel_speed = 0.055
@export var lateral_speed = 0.42
@export var bgm_audio_path = "res://assets/audio/thunderstorm_2min_loop.mp3"
@export var thunder_audio_path = "res://assets/audio/thunder_01.ogg"

@onready var entrance_layer: TextureRect = $VisualRoot/EntranceLayer
@onready var depth_layer: TextureRect = $VisualRoot/DepthLayer
@onready var hall_layer: TextureRect = $VisualRoot/HallLayer
@onready var depth_motion: Node2D = $DepthMotion
@onready var character_anchor: Node2D = $CharacterAnchor
@onready var character_sprite: AnimatedSprite2D = $CharacterAnchor/AnimatedSprite2D
@onready var flashlight_origin: Marker2D = $CharacterAnchor/FlashlightOrigin
@onready var flashlight_volume: Sprite2D = $CharacterAnchor/FlashlightOrigin/FlashlightVolume
@onready var flashlight_core: Sprite2D = $CharacterAnchor/FlashlightOrigin/FlashlightCore
@onready var flashlight_spill: Sprite2D = $CharacterAnchor/FlashlightOrigin/FlashlightSpill
@onready var rain_layer: TextureRect = $RainLayer
@onready var fog_layer: TextureRect = $FogLayer
@onready var vignette: TextureRect = $Vignette
@onready var thunder_flash: ColorRect = $ThunderFlash
@onready var objective_label: Label = $HUDLayer/HUD/Objective
@onready var depth_label: Label = $HUDLayer/HUD/DepthLabel
@onready var prompt: Label = $HUDLayer/HUD/Prompt
@onready var audio_bgm: AudioStreamPlayer = $AudioBgm
@onready var audio_thunder: AudioStreamPlayer = $AudioThunder
@onready var thunder_timer: Timer = $ThunderTimer

var travel_progress = 0.0
var visual_progress = 0.0
var lateral_offset = 0.0
var target_lateral_offset = 0.0
var flashlight_enabled = true
var facing = "back"
var thunder_tween: Tween


func _ready() -> void:
	randomize()
	_setup_visual_resources()
	_build_character_animations()
	_layout_scene()
	_setup_audio()
	get_viewport().size_changed.connect(_layout_scene)
	thunder_timer.timeout.connect(_on_thunder_timer_timeout)
	_schedule_next_thunder()
	_update_animation(false)
	_update_flashlight_pose()
	if audio_bgm.stream != null:
		audio_bgm.play()


func _process(delta: float) -> void:
	var forward_input = Input.get_axis("ui_down", "ui_up")
	var lateral_input = Input.get_axis("ui_left", "ui_right")
	var was_progress = travel_progress

	travel_progress = clampf(travel_progress + forward_input * travel_speed * delta, 0.0, 1.0)
	target_lateral_offset = clampf(target_lateral_offset + lateral_input * lateral_speed * delta, -0.34, 0.34)
	if is_zero_approx(lateral_input):
		target_lateral_offset = move_toward(target_lateral_offset, 0.0, delta * 0.08)
	lateral_offset = lerpf(lateral_offset, target_lateral_offset, 1.0 - exp(-delta * 5.5))
	visual_progress = lerpf(visual_progress, travel_progress, 1.0 - exp(-delta * 3.2))

	var moving = absf(travel_progress - was_progress) > 0.00001 or absf(lateral_input) > 0.05
	_update_facing(forward_input, lateral_input)
	_update_animation(moving)
	_update_depth_layers(delta, moving)
	_update_flashlight_pose()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("flashlight"):
		flashlight_enabled = not flashlight_enabled
		_update_flashlight_visibility()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and travel_progress >= 0.94:
		_change_scene(INTERIOR_PLACEHOLDER_PATH)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_change_scene(EXTERIOR_SCENE_PATH)
		get_viewport().set_input_as_handled()


func _setup_visual_resources() -> void:
	entrance_layer.texture = _safe_load_texture("res://assets/environments/courtyard/courtyard_entrance.png")
	# The entrance plate contains the outer gate and the complete inner depth.
	# Keeping it for the whole walk avoids visual discontinuity between images.
	depth_layer.texture = _safe_load_texture("res://assets/environments/courtyard/courtyard_entrance.png")
	hall_layer.texture = _safe_load_texture("res://assets/environments/courtyard/courtyard_hall.png")
	for layer in [entrance_layer, depth_layer, hall_layer]:
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The courtyard uses one continuous perspective plate. The other two images
	# remain available as art references but are not dissolved into gameplay.
	entrance_layer.visible = false
	hall_layer.visible = false
	depth_layer.visible = true
	depth_layer.modulate = Color.WHITE

	rain_layer.texture = _safe_load_texture("res://assets/ui/rain_overlay.png")
	var rain_shader = _safe_load_shader("res://shaders/rain_overlay.gdshader")
	if rain_layer.texture != null and rain_shader != null:
		var material = ShaderMaterial.new()
		material.shader = rain_shader
		material.set_shader_parameter("rain_alpha", 0.42)
		material.set_shader_parameter("scroll_speed", Vector2(-0.065, 0.82))
		rain_layer.material = material
	fog_layer.texture = _safe_load_texture("res://assets/ui/fog_overlay.png")
	fog_layer.modulate = Color(0.72, 0.78, 0.8, 0.19)
	vignette.texture = _safe_load_texture("res://assets/ui/vignette.png")
	flashlight_volume.texture = _safe_load_texture("res://assets/ui/flashlight_volume_soft.png")
	flashlight_core.texture = _safe_load_texture("res://assets/ui/flashlight_core_soft.png")
	flashlight_spill.texture = _safe_load_texture("res://assets/ui/flashlight_spill_soft.png")
	_update_flashlight_visibility()


func _build_character_animations() -> void:
	var frames = SpriteFrames.new()
	for animation_name in ["idle_front", "idle_back", "idle_left", "idle_right"]:
		_add_animation(frames, animation_name, 6, 3.2, true)
	for animation_name in ["walk_front", "walk_back", "walk_left", "walk_right"]:
		_add_animation(frames, animation_name, 8, 8.0, true)
	character_sprite.sprite_frames = frames


func _add_animation(frames: SpriteFrames, animation_name: String, frame_count: int, fps: float, looped: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, looped)
	var parts = animation_name.split("_")
	var direction = parts[1]
	var state = parts[0]
	for index in range(frame_count):
		var path = "%s/chen_mo_%s_%s_%02d.png" % [ANIMATION_ROOT, direction, state, index]
		var texture = _safe_load_texture(path)
		if texture != null:
			frames.add_frame(animation_name, texture)


func _update_facing(forward_input: float, lateral_input: float) -> void:
	if absf(forward_input) >= absf(lateral_input) and absf(forward_input) > 0.05:
		facing = "back" if forward_input > 0.0 else "front"
	elif absf(lateral_input) > 0.05:
		facing = "right" if lateral_input > 0.0 else "left"


func _update_animation(moving: bool) -> void:
	var requested = ("walk_" if moving else "idle_") + facing
	if character_sprite.sprite_frames == null or not character_sprite.sprite_frames.has_animation(requested):
		requested = "idle_back"
	if character_sprite.animation != requested:
		character_sprite.play(requested)


func _update_depth_layers(delta: float, moving: bool) -> void:
	var viewport_size = get_viewport_rect().size
	# Scale around the distant main-hall doorway. This keeps the vanishing point
	# stable while nearby side buildings move outward and pass the camera.
	var vanishing_point = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.355)
	depth_layer.pivot_offset = vanishing_point
	var push_curve = smoothstep(0.0, 1.0, visual_progress)
	# A restrained zoom keeps the supplied background close to its native pixel
	# density while still carrying the camera through the central gate.
	var forward_scale = lerpf(1.0, 1.62, push_curve)
	depth_layer.scale = Vector2.ONE * forward_scale

	# Horizontal camera drift is intentionally weaker at distance than the
	# foreground prop motion, producing a readable near/mid/far parallax split.
	var parallax_x = -lateral_offset * viewport_size.x * lerpf(0.08, 0.14, push_curve)
	depth_layer.position = Vector2(parallax_x, -push_curve * viewport_size.y * 0.018)
	var camera_catchup = smoothstep(0.0, 0.2, visual_progress)
	var character_target = Vector2(
		viewport_size.x * 0.5 + lateral_offset * 130.0,
		lerpf(viewport_size.y * 0.70, viewport_size.y * 0.85, camera_catchup)
	)
	character_anchor.position = character_anchor.position.lerp(character_target, 1.0 - exp(-delta * 7.0))
	var character_scale = lerpf(0.46, 0.55, camera_catchup)
	character_sprite.scale = Vector2.ONE * character_scale
	depth_motion.call("configure", visual_progress, lateral_offset, 1.0 if moving else 0.0, viewport_size)


func _update_flashlight_pose() -> void:
	match facing:
		"front":
			flashlight_origin.position = Vector2(48.0, -90.0)
			flashlight_origin.rotation = PI * 0.5
		"left":
			flashlight_origin.position = Vector2(-44.0, -145.0)
			flashlight_origin.rotation = PI
		"right":
			flashlight_origin.position = Vector2(50.0, -145.0)
			flashlight_origin.rotation = 0.0
		_:
			flashlight_origin.position = Vector2(48.0, -150.0)
			flashlight_origin.rotation = -PI * 0.5


func _update_flashlight_visibility() -> void:
	for node in [flashlight_volume, flashlight_core, flashlight_spill]:
		node.visible = flashlight_enabled


func _update_hud() -> void:
	objective_label.text = "◇  穿过庭院，前往主屋"
	depth_label.text = "庭院深处  %02d%%" % int(round(travel_progress * 100.0))
	prompt.visible = travel_progress >= 0.94


func _layout_scene() -> void:
	var viewport_size = get_viewport_rect().size
	for rect in [entrance_layer, depth_layer, hall_layer, rain_layer, fog_layer, vignette, thunder_flash]:
		rect.position = Vector2.ZERO
		rect.size = viewport_size
	# Chen Mo starts inside the central gate rather than already standing in the
	# foreground. The camera settles behind him during the first few steps.
	character_anchor.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.70)


func _setup_audio() -> void:
	_assign_audio(audio_bgm, bgm_audio_path, true)
	_assign_audio(audio_thunder, thunder_audio_path, false)


func _schedule_next_thunder() -> void:
	thunder_timer.wait_time = randf_range(9.0, 18.0)
	thunder_timer.start()


func _on_thunder_timer_timeout() -> void:
	if audio_thunder.stream != null:
		audio_thunder.play()
	if thunder_tween != null:
		thunder_tween.kill()
	thunder_tween = create_tween()
	thunder_tween.tween_property(thunder_flash, "color", Color(0.68, 0.78, 0.94, 0.14), 0.05)
	thunder_tween.tween_interval(0.1)
	thunder_tween.tween_property(thunder_flash, "color", Color(0.68, 0.78, 0.94, 0.0), 0.32)
	_schedule_next_thunder()


func _change_scene(scene_path: String) -> void:
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _assign_audio(player_node: AudioStreamPlayer, path: String, should_loop: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = should_loop
	elif stream is AudioStreamOggVorbis:
		stream.loop = should_loop
	player_node.stream = stream


func _safe_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image = Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null


func _safe_load_shader(path: String) -> Shader:
	if ResourceLoader.exists(path):
		return load(path) as Shader
	return null
