extends Node2D

const COURTYARD_SCENE_PATH = "res://scenes/Courtyard3D.tscn"

@export var background_path = "res://assets/environments/exterior_house_bg.png"
@export var rain_overlay_path = "res://assets/ui/rain_overlay.png"
@export var fog_overlay_path = "res://assets/ui/fog_overlay.png"
@export var vignette_path = "res://assets/ui/vignette.png"
@export var rain_shader_path = "res://shaders/rain_overlay.gdshader"
@export var bgm_audio_path = "res://assets/audio/thunderstorm_2min_loop.mp3"
@export var thunder_audio_path = "res://assets/audio/thunder_01.ogg"
@export var door_push_audio_path = "res://assets/audio/public_effects/door_push.wav"

@onready var background: TextureRect = $Background
@onready var rain_layer: TextureRect = $RainLayer
@onready var fog_layer: TextureRect = $FogLayer
@onready var vignette: TextureRect = $Vignette
@onready var thunder_flash: ColorRect = $ThunderFlash
@onready var door_area: Area2D = $World/DoorArea
@onready var player: CharacterBody2D = $World/Player
@onready var hud: Control = $HUDLayer/ExteriorHUD
@onready var audio_bgm: AudioStreamPlayer = $AudioBgm
@onready var audio_thunder: AudioStreamPlayer = $AudioThunder
@onready var audio_door_push: AudioStreamPlayer = $AudioDoorPush
@onready var thunder_timer: Timer = $ThunderTimer

var player_near_door = false
var entering_interior = false
var thunder_tween: Tween


func _ready() -> void:
	randomize()
	_load_visuals()
	_load_audio()
	_layout_layers()

	get_viewport().size_changed.connect(_layout_layers)
	door_area.body_entered.connect(_on_door_area_body_entered)
	door_area.body_exited.connect(_on_door_area_body_exited)
	thunder_timer.timeout.connect(_on_thunder_timer_timeout)
	if player.has_signal("flashlight_toggled"):
		player.flashlight_toggled.connect(_on_player_flashlight_toggled)
	if player.has_signal("movement_state_changed"):
		player.movement_state_changed.connect(_on_player_movement_state_changed)

	_play_bgm()
	_schedule_next_thunder()
	player.set_flashlight_enabled(GameState.flashlight_enabled)
	if player.has_method("is_flashlight_enabled") and hud.has_method("set_flashlight_enabled"):
		hud.call("set_flashlight_enabled", player.call("is_flashlight_enabled"))
	if GameState.night_elapsed_minutes == 0:
		hud.call("set_story_caption", "每过一秒，夜里走一分钟。须在六点前带着证据离开王宅。", true, true, 8, 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if player_near_door and event.is_action_pressed("interact"):
		_enter_interior()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_change_scene("res://scenes/StartMenu.tscn")
		get_viewport().set_input_as_handled()


func _load_visuals() -> void:
	background.texture = _safe_load_texture(background_path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	rain_layer.texture = _safe_load_texture(rain_overlay_path)
	var rain_shader = _safe_load_shader(rain_shader_path)
	if rain_layer.texture != null and rain_shader != null:
		var material = ShaderMaterial.new()
		material.shader = rain_shader
		material.set_shader_parameter("rain_alpha", 0.36)
		material.set_shader_parameter("scroll_speed", Vector2(-0.06, 0.72))
		rain_layer.material = material

	fog_layer.texture = _safe_load_texture(fog_overlay_path)
	fog_layer.modulate = Color(1.0, 1.0, 1.0, 0.26)
	vignette.texture = _safe_load_texture(vignette_path)
	thunder_flash.color = Color(0.68, 0.78, 0.96, 0.0)


func _load_audio() -> void:
	_assign_audio(audio_bgm, bgm_audio_path, true)
	_assign_audio(audio_thunder, thunder_audio_path, false)
	audio_bgm.bus = &"Ambience"
	audio_thunder.bus = &"Thunder"
	_assign_audio(audio_door_push, door_push_audio_path, false)


func _layout_layers() -> void:
	var viewport_size = get_viewport_rect().size
	for rect in [background, rain_layer, fog_layer, vignette, thunder_flash]:
		rect.position = Vector2.ZERO
		rect.size = viewport_size


func _on_door_area_body_entered(body: Node2D) -> void:
	if body == player:
		player_near_door = true
		if hud.has_method("set_door_prompt_visible"):
			hud.call("set_door_prompt_visible", true)


func _on_door_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_near_door = false
		if hud.has_method("set_door_prompt_visible"):
			hud.call("set_door_prompt_visible", false)


func _enter_interior() -> void:
	if entering_interior:
		return

	entering_interior = true
	_play_persistent_door_sound()
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	await get_tree().create_timer(0.72).timeout
	_change_scene(COURTYARD_SCENE_PATH)


func _play_persistent_door_sound() -> void:
	if audio_door_push == null or audio_door_push.stream == null:
		return
	var scene_host := get_tree().current_scene
	if scene_host == null or scene_host == self:
		_play_sound(audio_door_push)
		return
	var transition_audio := AudioStreamPlayer.new()
	transition_audio.name = "AuthorizedOldWoodDoorTransition"
	transition_audio.stream = audio_door_push.stream
	transition_audio.volume_db = -1.5
	transition_audio.finished.connect(transition_audio.queue_free)
	scene_host.add_child(transition_audio)
	transition_audio.play()


func _change_scene(scene_path: String) -> void:
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _on_player_flashlight_toggled(enabled: bool) -> void:
	GameState.flashlight_enabled = enabled
	if hud.has_method("set_flashlight_enabled"):
		hud.call("set_flashlight_enabled", enabled)


func _on_player_movement_state_changed(facing: String, moving: bool) -> void:
	if hud.has_method("set_movement_caption"):
		hud.call("set_movement_caption", facing, moving)


func _play_bgm() -> void:
	if audio_bgm.stream != null:
		audio_bgm.play()


func _play_sound(player_node: AudioStreamPlayer) -> void:
	if player_node.stream != null:
		player_node.stop()
		player_node.play()


func _schedule_next_thunder() -> void:
	thunder_timer.wait_time = randf_range(10.0, 22.0)
	thunder_timer.start()


func _on_thunder_timer_timeout() -> void:
	_play_sound(audio_thunder)
	if GameState.reduced_flashes:
		_schedule_next_thunder()
		return
	if thunder_tween != null:
		thunder_tween.kill()
	thunder_tween = create_tween()
	thunder_tween.tween_property(thunder_flash, "color", Color(0.76, 0.86, 1.0, 0.16), 0.04)
	thunder_tween.tween_interval(randf_range(0.08, 0.22))
	thunder_tween.tween_property(thunder_flash, "color", Color(0.68, 0.78, 0.96, 0.0), 0.32)
	_schedule_next_thunder()


func _assign_audio(player_node: AudioStreamPlayer, path: String, should_loop: bool) -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is AudioStream:
			stream = resource

	if stream == null:
		stream = _load_audio_file_directly(path, should_loop)

	if stream == null:
		push_warning("Audio file could not be loaded: %s" % path)
		return

	if stream is AudioStreamOggVorbis:
		stream.loop = should_loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		stream.loop = should_loop

	player_node.stream = stream


func _load_audio_file_directly(path: String, should_loop: bool) -> AudioStream:
	var absolute_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null

	match path.get_extension().to_lower():
		"mp3":
			var mp3_stream = AudioStreamMP3.new()
			mp3_stream.data = FileAccess.get_file_as_bytes(absolute_path)
			mp3_stream.loop = should_loop
			return mp3_stream
		"ogg":
			var ogg_stream = AudioStreamOggVorbis.load_from_file(absolute_path)
			if ogg_stream != null:
				ogg_stream.loop = should_loop
			return ogg_stream
		"wav":
			var wav_stream = AudioStreamWAV.load_from_file(absolute_path)
			if wav_stream != null:
				wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
			return wav_stream

	return null


func _safe_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource

	var image = Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)

	return null


func _safe_load_shader(path: String) -> Shader:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Shader:
			return resource
	return null
