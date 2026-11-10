extends Control

const START_MENU_PATH = "res://scenes/StartMenu.tscn"

@export var font_path = "res://assets/fonts/watchnight_chinese.tres"
@export var bgm_audio_path = "res://assets/audio/thunderstorm_2min_loop.mp3"

@onready var main_text: Label = $TextGroup/MainText
@onready var sub_text: Label = $TextGroup/SubText
@onready var audio_bgm: AudioStreamPlayer = $AudioBgm
@onready var timer: Timer = $Timer

var returning_to_menu = false
var ui_font: Font


func _ready() -> void:
	ui_font = _safe_load_font(font_path)
	_apply_style()
	_assign_audio(audio_bgm, bgm_audio_path, true)
	if audio_bgm.stream != null:
		audio_bgm.play()

	main_text.modulate.a = 0.0
	sub_text.visible = false
	sub_text.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(main_text, "modulate:a", 1.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	timer.timeout.connect(_show_sub_text)
	timer.start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_return_to_start_menu()
		get_viewport().set_input_as_handled()


func _show_sub_text() -> void:
	sub_text.visible = true
	var tween = create_tween()
	tween.tween_property(sub_text, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _return_to_start_menu() -> void:
	if returning_to_menu:
		return

	returning_to_menu = true
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", START_MENU_PATH)
	else:
		get_tree().change_scene_to_file(START_MENU_PATH)


func _apply_style() -> void:
	main_text.text = "夜已深，雨很大，当你路过的时候发现荒宅的门开了……"
	sub_text.text = "正式关卡将在下一阶段制作。"

	for label in [main_text, sub_text]:
		if ui_font != null:
			label.add_theme_font_override("font", ui_font)
		label.add_theme_color_override("font_color", _color("#C8C0B0"))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
		label.add_theme_constant_override("shadow_outline_size", 4)

	main_text.add_theme_font_size_override("font_size", 38)
	sub_text.add_theme_font_size_override("font_size", 28)
	sub_text.add_theme_color_override("font_color", _color("#C8C0B0", 0.76))


func _assign_audio(player: AudioStreamPlayer, path: String, should_loop: bool) -> void:
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

	player.stream = stream


func _load_audio_file_directly(path: String, should_loop: bool) -> AudioStream:
	var absolute_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null

	if path.get_extension().to_lower() == "mp3":
		var mp3_stream = AudioStreamMP3.new()
		mp3_stream.data = FileAccess.get_file_as_bytes(absolute_path)
		mp3_stream.loop = should_loop
		return mp3_stream

	return null


func _safe_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null

	var resource = load(path)
	if resource is Font:
		return resource

	push_warning("Resource is not a font: %s" % path)
	return null


func _color(hex: String, alpha = 1.0) -> Color:
	var parsed = Color.html(hex)
	parsed.a = alpha
	return parsed
