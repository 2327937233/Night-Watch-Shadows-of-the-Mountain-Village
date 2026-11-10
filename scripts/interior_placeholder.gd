extends Control

const EXTERIOR_HOUSE_SCENE_PATH = "res://scenes/Courtyard3D.tscn"

@export var font_path = "res://assets/fonts/watchnight_chinese.tres"
@export var bgm_audio_path = "res://assets/audio/thunderstorm_2min_loop.mp3"

@onready var main_text: Label = $TextGroup/MainText
@onready var sub_text: Label = $TextGroup/SubText
@onready var audio_bgm: AudioStreamPlayer = $AudioBgm

var returning = false
var ui_font: Font


func _ready() -> void:
	ui_font = _safe_load_font(font_path)
	_apply_style()
	_assign_audio(audio_bgm, bgm_audio_path, true)
	if audio_bgm.stream != null:
		audio_bgm.play()

	main_text.modulate.a = 0.0
	sub_text.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(main_text, "modulate:a", 1.0, 1.0)
	tween.tween_interval(0.9)
	tween.tween_property(sub_text, "modulate:a", 1.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_return_to_exterior()
		get_viewport().set_input_as_handled()


func _return_to_exterior() -> void:
	if returning:
		return

	returning = true
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", EXTERIOR_HOUSE_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(EXTERIOR_HOUSE_SCENE_PATH)


func _apply_style() -> void:
	main_text.text = "门被缓缓推开，屋内一片死寂……"
	sub_text.text = "室内场景将在下一阶段制作。"
	for label in [main_text, sub_text]:
		if ui_font != null:
			label.add_theme_font_override("font", ui_font)
		label.add_theme_color_override("font_color", _color("#C8C0B0", 0.94))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_outline_size", 4)

	main_text.add_theme_font_size_override("font_size", 38)
	sub_text.add_theme_font_size_override("font_size", 27)
	sub_text.add_theme_color_override("font_color", _color("#C8C0B0", 0.72))


func _assign_audio(player_node: AudioStreamPlayer, path: String, should_loop: bool) -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is AudioStream:
			stream = resource

	if stream == null:
		stream = _load_audio_file_directly(path, should_loop)

	if stream == null:
		return

	if stream is AudioStreamMP3:
		stream.loop = should_loop
	elif stream is AudioStreamOggVorbis:
		stream.loop = should_loop
	player_node.stream = stream


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
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Font:
			return resource
	return null


func _color(hex: String, alpha = 1.0) -> Color:
	var parsed = Color.html(hex)
	parsed.a = alpha
	return parsed
