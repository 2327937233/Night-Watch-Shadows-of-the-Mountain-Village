extends Control

const CONTROLS_PANEL_PATH = "res://scenes/ControlsPanel.tscn"
const EXTERIOR_HOUSE_SCENE_PATH = "res://scenes/ExteriorHouseScene.tscn"

@export var background_path = "res://assets/ui/start_menu_bg.png"
@export var vignette_path = "res://assets/ui/vignette.png"
@export var rain_overlay_path = "res://assets/ui/rain_overlay.png"
@export var fog_overlay_path = "res://assets/ui/fog_overlay.png"
@export var title_logo_path = "res://assets/ui/title_logo.png"
@export var font_path = "res://assets/fonts/watchnight_chinese.tres"
@export var bgm_audio_path = "res://assets/audio/thunderstorm_2min_loop.mp3"
@export var thunder_audio_path = "res://assets/audio/thunder_01.ogg"
@export var hover_audio_path = "res://assets/audio/menu_hover.ogg"
@export var confirm_audio_path = "res://assets/audio/menu_confirm.ogg"
@export var rain_shader_path = "res://shaders/rain_overlay.gdshader"
@export var vignette_shader_path = "res://shaders/screen_vignette.gdshader"

@onready var background: TextureRect = $Background
@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var rain_layer: TextureRect = $RainLayer
@onready var fog_layer: TextureRect = $FogLayer
@onready var vignette: TextureRect = $Vignette
@onready var title_group: Control = $TitleGroup
@onready var title_logo: TextureRect = $TitleGroup/TitleLogo
@onready var game_title: Label = $TitleGroup/GameTitle
@onready var subtitle: Label = $TitleGroup/Subtitle
@onready var seal_text: Label = $TitleGroup/SealText
@onready var menu_group: VBoxContainer = $MenuGroup
@onready var start_button: Button = $MenuGroup/StartButton
@onready var controls_button: Button = $MenuGroup/ControlsButton
@onready var restart_button: Button = $MenuGroup/RestartButton
@onready var exit_button: Button = $MenuGroup/ExitButton
@onready var bottom_hint: Label = $BottomHint
@onready var controls_panel_holder: Control = $ControlsPanelInstance
@onready var audio_bgm: AudioStreamPlayer = $AudioBgm
@onready var audio_hover: AudioStreamPlayer = $AudioHover
@onready var audio_confirm: AudioStreamPlayer = $AudioConfirm
@onready var audio_thunder: AudioStreamPlayer = $AudioThunder
@onready var thunder_timer: Timer = $ThunderTimer

var menu_buttons: Array[Button] = []
var menu_labels: Array[String] = ["开始游戏", "操作查看", "重新开始", "退出游戏"]
var selected_index = 0
var controls_panel: Control
var transitioning = false
var thunder_tween: Tween
var normal_overlay_color = Color(0.0, 0.0, 0.0, 0.10)
var ui_font: Font


func _ready() -> void:
	GameState.stop_night_clock()
	menu_labels[0] = "继续游戏" if GameState.has_checkpoint() else "开始游戏"
	randomize()
	menu_buttons = [start_button, controls_button, restart_button, exit_button]

	_load_visual_assets()
	_load_audio_assets()
	_setup_labels()
	_setup_buttons()
	_create_controls_panel()
	_layout_interface()

	resized.connect(_layout_interface)
	thunder_timer.timeout.connect(_on_thunder_timer_timeout)

	_set_selected_index(0, false)
	_play_bgm()
	_schedule_next_thunder()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if _is_controls_panel_open():
		if event.is_action_pressed("ui_cancel"):
			controls_panel.call("close_panel")
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_down"):
		_set_selected_index(selected_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_set_selected_index(selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# Current phase keeps Esc on the start screen instead of quitting.
		get_viewport().set_input_as_handled()


func _load_visual_assets() -> void:
	background.texture = _safe_load_texture(background_path)
	if background.texture == null:
		background.texture = _make_fallback_background()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	vignette.texture = _safe_load_texture(vignette_path)
	if vignette.texture == null:
		var vignette_shader = _safe_load_shader(vignette_shader_path)
		if vignette_shader != null:
			var material = ShaderMaterial.new()
			material.shader = vignette_shader
			vignette.material = material

	rain_layer.texture = _safe_load_texture(rain_overlay_path)
	var rain_shader = _safe_load_shader(rain_shader_path)
	if rain_layer.texture != null and rain_shader != null:
		var rain_material = ShaderMaterial.new()
		rain_material.shader = rain_shader
		rain_material.set_shader_parameter("rain_alpha", 0.44)
		rain_layer.material = rain_material

	fog_layer.texture = _safe_load_texture(fog_overlay_path)
	fog_layer.modulate = Color(1.0, 1.0, 1.0, 0.26)
	dark_overlay.color = normal_overlay_color

	title_logo.texture = _safe_load_texture(title_logo_path)
	title_logo.visible = title_logo.texture != null

	ui_font = _safe_load_font(font_path)


func _load_audio_assets() -> void:
	_assign_audio(audio_bgm, bgm_audio_path, true)
	_assign_audio(audio_thunder, thunder_audio_path, false)
	audio_bgm.bus = &"Ambience"
	audio_thunder.bus = &"Thunder"
	_assign_audio(audio_hover, hover_audio_path, false)
	_assign_audio(audio_confirm, confirm_audio_path, false)


func _setup_labels() -> void:
	game_title.text = "守夜"
	subtitle.text = "山村旧影"
	seal_text.text = "陈\n默"
	bottom_hint.text = "↑↓ 选择    Enter 确认    Esc 返回"

	var use_title_logo = title_logo.texture != null
	title_logo.visible = use_title_logo
	game_title.visible = not use_title_logo
	subtitle.visible = not use_title_logo
	seal_text.visible = not use_title_logo

	var labels = [game_title, subtitle, seal_text, bottom_hint]
	for label in labels:
		if ui_font != null:
			label.add_theme_font_override("font", ui_font)

	game_title.add_theme_font_size_override("font_size", 156)
	game_title.add_theme_color_override("font_color", _color("#D8D2C8"))
	game_title.add_theme_color_override("font_shadow_color", _color("#3B1111", 0.95))
	game_title.add_theme_constant_override("shadow_offset_x", 5)
	game_title.add_theme_constant_override("shadow_offset_y", 5)
	game_title.add_theme_constant_override("shadow_outline_size", 7)

	subtitle.add_theme_font_size_override("font_size", 44)
	subtitle.add_theme_color_override("font_color", _color("#8B2C2C"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	subtitle.add_theme_constant_override("shadow_offset_x", 3)
	subtitle.add_theme_constant_override("shadow_offset_y", 3)
	subtitle.add_theme_constant_override("shadow_outline_size", 3)

	seal_text.add_theme_font_size_override("font_size", 31)
	seal_text.add_theme_color_override("font_color", _color("#170707"))
	seal_text.add_theme_color_override("font_shadow_color", _color("#8B2C2C", 0.9))
	seal_text.add_theme_constant_override("shadow_outline_size", 5)

	bottom_hint.add_theme_font_size_override("font_size", 22)
	bottom_hint.add_theme_color_override("font_color", _color("#C8C0B0", 0.76))
	bottom_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	bottom_hint.add_theme_constant_override("shadow_outline_size", 2)


func _setup_buttons() -> void:
	for index in range(menu_buttons.size()):
		var button = menu_buttons[index]
		button.text = menu_labels[index]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(580.0, 72.0)
		button.add_theme_font_size_override("font_size", 39)
		if ui_font != null:
			button.add_theme_font_override("font", ui_font)
		button.mouse_entered.connect(_on_button_mouse_entered.bind(index))
		button.pressed.connect(_on_button_pressed.bind(index))


func _create_controls_panel() -> void:
	if not ResourceLoader.exists(CONTROLS_PANEL_PATH):
		push_warning("ControlsPanel scene is missing: %s" % CONTROLS_PANEL_PATH)
		return

	var packed_scene = load(CONTROLS_PANEL_PATH)
	if packed_scene is PackedScene:
		controls_panel = packed_scene.instantiate()
		controls_panel_holder.add_child(controls_panel)
		if controls_panel.has_method("close_immediate"):
			controls_panel.call("close_immediate")
		else:
			controls_panel.visible = false


func _layout_interface() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	title_group.position = Vector2(max(96.0, viewport_size.x * 0.063), max(54.0, viewport_size.y * 0.065))
	title_group.size = Vector2(620.0, 395.0)

	menu_group.size = Vector2(580.0, 350.0)
	var menu_x: float = viewport_size.x * 0.37
	var menu_max_x: float = maxf(24.0, viewport_size.x - menu_group.size.x - 64.0)
	menu_group.position = Vector2(clamp(menu_x, 420.0, menu_max_x), viewport_size.y * 0.405)

	bottom_hint.size = Vector2(640.0, 48.0)
	bottom_hint.position = Vector2(viewport_size.x - bottom_hint.size.x - 90.0, viewport_size.y - 128.0)


func _set_selected_index(new_index: int, play_sound = true) -> void:
	if menu_buttons.is_empty():
		return

	var wrapped_index = new_index % menu_buttons.size()
	if wrapped_index < 0:
		wrapped_index += menu_buttons.size()

	if selected_index == wrapped_index and play_sound:
		return

	selected_index = wrapped_index
	_update_button_states()
	if play_sound:
		_play_sound(audio_hover)


func _update_button_states() -> void:
	for index in range(menu_buttons.size()):
		var button = menu_buttons[index]
		var selected = index == selected_index
		button.text = "◇ %s ◇" % menu_labels[index] if selected else menu_labels[index]
		button.add_theme_color_override("font_color", _color("#F2D6A2") if selected else _color("#C8C0B0"))
		button.add_theme_color_override("font_hover_color", _color("#F2D6A2"))
		button.add_theme_color_override("font_pressed_color", _color("#F2D6A2"))
		button.add_theme_color_override("font_focus_color", _color("#F2D6A2"))
		button.add_theme_stylebox_override("normal", _make_button_style(selected))
		button.add_theme_stylebox_override("hover", _make_button_style(true))
		button.add_theme_stylebox_override("pressed", _make_button_style(true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _make_button_style(selected: bool, pressed = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = _color("#3A1210", 0.62 if selected else 0.00)
	style.border_color = _color("#8B2C2C", 0.74 if selected else 0.00)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 1 if selected else 0
	style.border_width_bottom = 1 if selected else 0
	style.shadow_color = _color("#5A1E1E", 0.50 if selected else 0.0)
	style.shadow_size = 18 if selected else 0
	style.set_content_margin(SIDE_LEFT, 36.0)
	style.set_content_margin(SIDE_RIGHT, 36.0)
	style.set_content_margin(SIDE_TOP, 10.0)
	style.set_content_margin(SIDE_BOTTOM, 10.0)

	if pressed:
		style.bg_color = _color("#301010", 0.82)
	return style


func _on_button_mouse_entered(index: int) -> void:
	_set_selected_index(index)


func _on_button_pressed(index: int) -> void:
	_set_selected_index(index, false)
	_confirm_selection()


func _confirm_selection() -> void:
	if transitioning:
		return

	_play_sound(audio_confirm)

	match selected_index:
		0:
			var path := GameState.restore_checkpoint()
			if path.is_empty():
				_reset_game_progress()
				path = EXTERIOR_HOUSE_SCENE_PATH
			transitioning = true
			await get_tree().create_timer(0.12).timeout
			_change_scene(path)
		1:
			if controls_panel != null and controls_panel.has_method("open_panel"):
				controls_panel.call("open_panel")
		2:
			GameState.clear_checkpoint()
			_reset_game_progress()
			transitioning = true
			await get_tree().create_timer(0.12).timeout
			_change_scene(EXTERIOR_HOUSE_SCENE_PATH)
		3:
			get_tree().quit()


func _reset_game_progress() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("reset_run"):
		game_state.call("reset_run")


func _is_controls_panel_open() -> bool:
	return controls_panel != null and controls_panel.visible


func _change_scene(scene_path: String) -> void:
	var main_scene = get_tree().current_scene
	if main_scene != null and main_scene.has_method("change_scene"):
		main_scene.call("change_scene", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _play_bgm() -> void:
	if audio_bgm.stream != null:
		audio_bgm.play()


func _play_sound(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.stop()
		player.play()


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


func _schedule_next_thunder() -> void:
	thunder_timer.wait_time = 5.0
	thunder_timer.start()


func _on_thunder_timer_timeout() -> void:
	_play_sound(audio_thunder)
	if GameState.reduced_flashes:
		_schedule_next_thunder()
		return

	var flash_duration = randf_range(0.10, 0.25)
	if thunder_tween != null:
		thunder_tween.kill()

	thunder_tween = create_tween()
	thunder_tween.tween_property(dark_overlay, "color", _color("#000000", 0.07), 0.035)
	thunder_tween.parallel().tween_property(background, "modulate", Color(1.28, 1.25, 1.18, 1.0), 0.035)
	thunder_tween.tween_interval(flash_duration)
	thunder_tween.tween_property(dark_overlay, "color", normal_overlay_color, 0.22)
	thunder_tween.parallel().tween_property(background, "modulate", Color.WHITE, 0.22)
	_schedule_next_thunder()


func _safe_load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		var image = Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
		return null

	var resource = load(path)
	if resource is Texture2D:
		return resource

	var fallback_image = Image.new()
	if fallback_image.load(path) == OK:
		return ImageTexture.create_from_image(fallback_image)

	push_warning("Resource is not a texture: %s" % path)
	return null


func _safe_load_shader(path: String) -> Shader:
	if not ResourceLoader.exists(path):
		return null

	var resource = load(path)
	if resource is Shader:
		return resource

	push_warning("Resource is not a shader: %s" % path)
	return null


func _safe_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null

	var resource = load(path)
	if resource is Font:
		return resource

	push_warning("Resource is not a font: %s" % path)
	return null


func _make_fallback_background() -> Texture2D:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([_color("#0A1018"), _color("#11110F"), _color("#020303")])

	var texture = GradientTexture2D.new()
	texture.width = 1920
	texture.height = 1080
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.gradient = gradient
	return texture


static func _color(hex: String, alpha = 1.0) -> Color:
	var parsed = Color.html(hex)
	parsed.a = alpha
	return parsed
