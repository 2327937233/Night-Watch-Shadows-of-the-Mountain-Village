extends Control

@export var font_path = "res://assets/fonts/watchnight_chinese.tres"

@onready var background_dim: ColorRect = $BackgroundDim
@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/VBoxContainer/Title
@onready var control_text: RichTextLabel = $Panel/VBoxContainer/ControlText
@onready var return_hint: Label = $Panel/VBoxContainer/ReturnHint

var fade_tween: Tween
var ui_font: Font
var ambience_slider: HSlider
var thunder_slider: HSlider
var flashes_check: CheckBox


func _ready() -> void:
	ui_font = _safe_load_font(font_path)
	_apply_style()
	_build_presentation_settings()
	close_immediate()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	if fade_tween != null:
		fade_tween.kill()

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0

	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_panel() -> void:
	if not visible:
		return

	if fade_tween != null:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(close_immediate)


func close_immediate() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_style() -> void:
	title.text = "操作查看"
	control_text.text = "W / A / S / D ：移动角色\n鼠标 ：选择菜单 / 调查物品\nE ：调查 / 互动\nF ：打开或关闭手电筒\nTab ：查看背包（暂停计时）\nEsc ：返回 / 关闭界面\n\n06:00 前须带着证据离开王宅。"
	return_hint.text = "按 Esc 返回"

	background_dim.color = Color(0.0, 0.0, 0.0, 0.62)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = _color("#120D0B", 0.88)
	panel_style.border_color = _color("#5A1E1E", 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	panel_style.shadow_size = 18
	panel_style.set_content_margin(SIDE_LEFT, 52.0)
	panel_style.set_content_margin(SIDE_RIGHT, 52.0)
	panel_style.set_content_margin(SIDE_TOP, 42.0)
	panel_style.set_content_margin(SIDE_BOTTOM, 42.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	if ui_font != null:
		title.add_theme_font_override("font", ui_font)
		control_text.add_theme_font_override("normal_font", ui_font)
		return_hint.add_theme_font_override("font", ui_font)

	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", _color("#F2D6A2"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("shadow_outline_size", 3)

	control_text.custom_minimum_size = Vector2(650.0, 254.0)
	control_text.scroll_active = false
	control_text.selection_enabled = false
	control_text.add_theme_font_size_override("normal_font_size", 25)
	control_text.add_theme_color_override("default_color", _color("#C8C0B0", 0.94))

	return_hint.add_theme_font_size_override("font_size", 24)
	return_hint.add_theme_color_override("font_color", _color("#C8C0B0", 0.68))
	return_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	return_hint.add_theme_constant_override("shadow_outline_size", 2)


func _build_presentation_settings() -> void:
	var stack := return_hint.get_parent() as VBoxContainer
	stack.add_theme_constant_override("separation", 13)
	ambience_slider = _insert_volume_slider(stack, "雨声与环境音", GameState.ambience_volume)
	thunder_slider = _insert_volume_slider(stack, "雷声音量", GameState.thunder_volume)
	flashes_check = CheckBox.new()
	flashes_check.text = "减少雷电闪光"
	flashes_check.button_pressed = GameState.reduced_flashes
	if ui_font != null:
		flashes_check.add_theme_font_override("font", ui_font)
	flashes_check.add_theme_font_size_override("font_size", 24)
	stack.add_child(flashes_check)
	stack.move_child(return_hint, -1)
	ambience_slider.value_changed.connect(_settings_changed)
	thunder_slider.value_changed.connect(_settings_changed)
	flashes_check.toggled.connect(_settings_changed)


func _insert_volume_slider(stack: VBoxContainer, title_text: String, value: float) -> HSlider:
	var row := HBoxContainer.new()
	stack.add_child(row)
	var label := Label.new()
	label.text = title_text
	label.custom_minimum_size.x = 205.0
	if ui_font != null:
		label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", 24)
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	return slider


func _settings_changed(_value: Variant) -> void:
	GameState.apply_presentation_settings(ambience_slider.value, thunder_slider.value, flashes_check.button_pressed)


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
