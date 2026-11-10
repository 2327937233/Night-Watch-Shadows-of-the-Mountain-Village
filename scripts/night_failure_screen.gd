extends CanvasLayer

signal action_chosen(retry: bool)

const FONT = preload("res://assets/fonts/watchnight_chinese.tres")
const VEIL = preload("res://shaders/night_timeout_overlay.gdshader")
const THUNDER = preload("res://assets/audio/thunder_01.ogg")
const CRY_PATH := "res://assets/audio/public_effects/hall_sob.wav"
const CONFIRM = preload("res://assets/audio/menu_confirm.ogg")
const IVORY := Color(0.87, 0.79, 0.65)
const OLD_GOLD := Color(0.67, 0.53, 0.36)

var cover: Control
var wash: ShaderMaterial
var heading: Control
var choices: VBoxContainer
var retry_button: Button
var menu_button: Button
var thunder: AudioStreamPlayer
var sob: AudioStreamPlayer
var confirm: AudioStreamPlayer
var sequence: Tween
var leaving := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_screen()
	thunder = _sound(THUNDER, -2.5)
	thunder.bus = &"Thunder"
	sob = _sound(load(CRY_PATH) as AudioStream, -11.0)
	confirm = _sound(CONFIRM, -13.0)
	thunder.play()
	sequence = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	sequence.tween_method(_reveal, 0.18, 1.0, 0.66)
	if not bool(get_node("/root/GameState").get("reduced_flashes")):
		sequence.tween_method(_lightning, 0.63, 0.0, 0.46)
	sequence.tween_property(heading, "modulate:a", 1.0, 0.92).set_delay(0.19)
	sequence.tween_property(choices, "modulate:a", 1.0, 0.75).set_delay(0.54)
	sequence.tween_callback(sob.play.bind(0.05)).set_delay(0.64)
	sequence.tween_property(sob, "volume_db", -8.0, 0.46).set_delay(0.64)
	sequence.tween_callback(_enable_choices).set_delay(1.30)
	sequence.tween_property(sob, "volume_db", -44.0, 2.5).set_delay(5.15)
	sequence.tween_callback(sob.stop).set_delay(7.7)


func _build_screen() -> void:
	cover = Control.new()
	cover.name = "TimeoutInterface"
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash = ShaderMaterial.new()
	wash.shader = VEIL
	veil.material = wash
	cover.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.resized.connect(_fit_seal)
	_fit_seal()

	heading = Control.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading.modulate.a = 0.0
	var title := _label("游戏失败", 112, IVORY)
	title.name = "FailureTitle"
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.046, 0.033, 0.84))
	heading.add_child(title)
	_center(title, Vector2(980, 152), 0.263)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(line)
	_center(line, Vector2(720, 56), 0.382)
	line.add_child(_ornament(false))
	line.add_child(_label("真相仍埋在王宅深处", 34, OLD_GOLD))
	line.add_child(_ornament(true))
	var dawn := _label("天色将明 · 未能离开王宅", 19, Color(0.64, 0.57, 0.46, 0.86))
	heading.add_child(dawn)
	_center(dawn, Vector2(500, 35), 0.432)

	choices = VBoxContainer.new()
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choices.name = "TimeoutChoices"
	choices.add_theme_constant_override("separation", 21)
	choices.modulate.a = 0.0
	cover.add_child(choices)
	_center(choices, Vector2(355, 165), 0.785)
	retry_button = _button("从检查点重试" if bool(get_node("/root/GameState").call("has_checkpoint")) else "重新尝试", true)
	menu_button = _button("返回主菜单", false)
	retry_button.name = "RetryNight"
	menu_button.name = "ReturnToMainMenu"
	retry_button.focus_neighbor_top = retry_button.get_path_to(menu_button)
	retry_button.focus_neighbor_bottom = retry_button.get_path_to(menu_button)
	menu_button.focus_neighbor_top = menu_button.get_path_to(retry_button)
	menu_button.focus_neighbor_bottom = menu_button.get_path_to(retry_button)


func _center(item: Control, dimensions: Vector2, vertical: float) -> void:
	item.anchor_left = 0.5
	item.anchor_right = 0.5
	item.anchor_top = vertical
	item.anchor_bottom = vertical
	item.offset_left = -dimensions.x * 0.5
	item.offset_right = dimensions.x * 0.5
	item.offset_top = -dimensions.y * 0.5
	item.offset_bottom = dimensions.y * 0.5


func _label(words: String, size: int, tint: Color) -> Label:
	var item := Label.new()
	item.text = words
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", tint)
	item.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	item.add_theme_constant_override("shadow_offset_x", 1)
	item.add_theme_constant_override("shadow_offset_y", 2)
	return item


func _ornament(reverse: bool) -> Control:
	var ornament := Control.new()
	ornament.custom_minimum_size = Vector2(132.0, 24.0)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(func() -> void:
		var y := ornament.size.y * 0.52
		var x := 5.0 if reverse else ornament.size.x - 5.0
		var end := ornament.size.x if reverse else 0.0
		var sign_x := 1.0 if reverse else -1.0
		var gold := Color(0.59, 0.44, 0.27, 0.66)
		ornament.draw_line(Vector2(x + sign_x * 8.0, y), Vector2(end, y), gold, 1.0, true)
		ornament.draw_polyline(PackedVector2Array([
			Vector2(x - 5.0, y), Vector2(x, y - 5.0), Vector2(x + 5.0, y),
			Vector2(x, y + 5.0), Vector2(x - 5.0, y)
		]), gold, 1.0, true)
	)
	return ornament


func _button(words: String, retry: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.disabled = true
	button.custom_minimum_size.y = 69
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 33)
	for role in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(role, IVORY)
	var dark := _frame(false)
	var gold := _frame(true)
	button.add_theme_stylebox_override("normal", dark)
	button.add_theme_stylebox_override("disabled", dark)
	button.add_theme_stylebox_override("hover", gold)
	button.add_theme_stylebox_override("pressed", gold)
	button.add_theme_stylebox_override("focus", gold)
	choices.add_child(button)
	button.pressed.connect(_choose.bind(retry))
	return button


func _frame(highlight: bool) -> StyleBoxTexture:
	var stroke := "#bc8c49" if highlight else "#604d38"
	var fill := "#2b2216" if highlight else "#100f0e"
	var accent := "#c29452" if highlight else "#4e3d2b"
	var source := """<svg xmlns="http://www.w3.org/2000/svg" width="355" height="69" viewBox="0 0 355 69">
		<path d="M21 3 H334 L339 10 L346 14 V25 L353 34.5 L346 44 V55 L339 59 L334 66 H21 L16 59 L9 55 V44 L2 34.5 L9 25 V14 L16 10Z" fill="%s" fill-opacity=".86" stroke="%s" stroke-width="1.35"/>
		<path d="M25 7 H330 M25 62 H330" stroke="%s" stroke-opacity=".46" fill="none"/>
		<path d="M10 30 L15 34.5 L10 39 L5 34.5Z M345 30 L350 34.5 L345 39 L340 34.5Z" stroke="%s" fill="none" stroke-width="1"/>
	</svg>""" % [fill, stroke, accent, accent]
	var image := Image.new()
	image.load_svg_from_string(source, 2.0)
	var frame := StyleBoxTexture.new()
	frame.texture = ImageTexture.create_from_image(image)
	frame.region_rect = Rect2(Vector2.ZERO, Vector2(710, 138))
	frame.set_texture_margin(SIDE_LEFT, 48.0)
	frame.set_texture_margin(SIDE_RIGHT, 48.0)
	frame.set_texture_margin(SIDE_TOP, 20.0)
	frame.set_texture_margin(SIDE_BOTTOM, 20.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		frame.set_content_margin(side, 5.0)
	return frame


func _sound(stream: AudioStream, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = gain
	add_child(player)
	return player


func _fit_seal() -> void:
	wash.set_shader_parameter("aspect", cover.size.x / maxf(cover.size.y, 1.0))


func _reveal(value: float) -> void:
	wash.set_shader_parameter("reveal", value)


func _lightning(value: float) -> void:
	wash.set_shader_parameter("lightning", value)


func _enable_choices() -> void:
	retry_button.disabled = false
	menu_button.disabled = false
	retry_button.grab_focus()


func _choose(retry: bool) -> void:
	if leaving:
		return
	leaving = true
	retry_button.disabled = true
	menu_button.disabled = true
	sequence.kill()
	thunder.stop()
	sob.stop()
	confirm.play()
	var close := create_tween()
	close.tween_property(cover, "modulate:a", 0.0, 0.20)
	close.tween_callback(func() -> void: action_chosen.emit(retry))
