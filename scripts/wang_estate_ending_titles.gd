extends CanvasLayer
## The closing cards sit above the existing courtyard HUD and camera.

signal return_requested

const FONT = preload("res://assets/fonts/watchnight_chinese.tres")
const MENU = preload("res://scripts/start_menu.gd")
const PHOTO_FRONT = preload("res://assets/art/bedroom_scratched_photo.png")
const PHOTO_BACK = preload("res://assets/ui/reader_old_paper.png")
const INK := Color(0.19, 0.125, 0.082)
const OLD_WHITE := Color(0.83, 0.79, 0.71)
const PALE_GOLD := Color(0.86, 0.76, 0.56)

var screen: ColorRect
var card_text: Label
var photo: Control
var front: TextureRect
var reverse: TextureRect
var end_menu: Control
var return_button: Button
var confirm: AudioStreamPlayer
var roll: Tween


func _ready() -> void:
	layer = 64
	screen = ColorRect.new()
	screen.name = "FinalFade"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	set_black(0.0)
	card_text = _label(screen, "", 36, OLD_WHITE, Vector2(1140.0, 120.0), 0.48)
	card_text.name = "ClosingWords"
	card_text.hide()
	_build_photo()
	_build_end_menu()


func set_black(amount: float) -> void:
	screen.color = Color(0.006, 0.006, 0.007, amount)


func play_cards(timing_scale: float = 1.0) -> void:
	if roll != null:
		return
	set_black(1.0)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	roll = create_tween().set_trans(Tween.TRANS_SINE)
	_show_line("有些名字被人抹去。", 2.0, timing_scale)
	_show_line("但发生过的事，不会因此消失。", 3.0, timing_scale)
	roll.tween_callback(func() -> void:
		card_text.hide()
		photo.modulate.a = 0.0
		photo.show()
	)
	roll.tween_property(photo, "modulate:a", 0.89, 0.8 * timing_scale)
	roll.tween_interval(0.95 * timing_scale)
	roll.tween_property(photo, "scale:x", 0.035, 0.34 * timing_scale)
	roll.tween_callback(func() -> void:
		front.hide()
		reverse.show()
	)
	roll.tween_property(photo, "scale:x", 1.0, 0.42 * timing_scale)
	roll.tween_interval(3.15 * timing_scale)
	roll.tween_property(photo, "modulate:a", 0.0, 1.55 * timing_scale)
	roll.tween_callback(photo.hide)
	roll.tween_interval(0.65 * timing_scale)
	roll.tween_callback(func() -> void:
		end_menu.modulate.a = 0.0
		end_menu.show()
	)
	roll.tween_property(end_menu, "modulate:a", 1.0, 1.45 * timing_scale)
	roll.tween_callback(func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return_button.disabled = false
		return_button.grab_focus()
	)


func _show_line(line: String, hold: float, timing: float) -> void:
	roll.tween_callback(func() -> void:
		card_text.text = line
		card_text.modulate.a = 0.0
		card_text.show()
	)
	roll.tween_property(card_text, "modulate:a", 1.0, 0.78 * timing)
	roll.tween_interval(hold * timing)
	roll.tween_property(card_text, "modulate:a", 0.0, 0.70 * timing)
	roll.tween_interval(0.28 * timing)


func _build_photo() -> void:
	photo = Control.new()
	photo.name = "FamilyPhotograph"
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(photo)
	_center(photo, Vector2(620, 463), 0.48)
	photo.pivot_offset = Vector2(310, 231.5)
	photo.rotation = deg_to_rad(-2.4)
	photo.hide()
	front = _texture(photo, PHOTO_FRONT)
	front.name = "ScratchedFront"
	reverse = _texture(photo, PHOTO_BACK)
	reverse.name = "InscribedReverse"
	reverse.self_modulate = Color(0.76, 0.71, 0.63)
	reverse.hide()
	var inset := Panel.new()
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.23, 0.15, 0.09, 0.055)
	border.border_color = Color(0.25, 0.16, 0.09, 0.19)
	border.set_border_width_all(1)
	inset.add_theme_stylebox_override("panel", border)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reverse.add_child(inset)
	_center(inset, Vector2(520, 365), 0.5)
	var inscription := _label(reverse, GameState.PHOTO_WEDDING_INSCRIPTION, 24, INK, Vector2(530, 75), 0.56)
	inscription.name = "MarriageInscription"
	inscription.rotation = deg_to_rad(-1.5)


func _build_end_menu() -> void:
	end_menu = Control.new()
	end_menu.name = "EndingMenu"
	end_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(end_menu)
	end_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_menu.hide()
	_label(end_menu, "《守夜：山村旧影》", 58, PALE_GOLD, Vector2(1120, 112), 0.39)
	_label(end_menu, "故事终", 27, OLD_WHITE, Vector2(320, 70), 0.51)
	return_button = Button.new()
	return_button.name = "ReturnToMainMenu"
	return_button.text = "◇ 返回主菜单 ◇"
	return_button.disabled = true
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_button.add_theme_font_override("font", FONT)
	return_button.add_theme_font_size_override("font_size", 26)
	return_button.add_theme_color_override("font_color", PALE_GOLD)
	return_button.add_theme_color_override("font_focus_color", PALE_GOLD)
	return_button.add_theme_color_override("font_hover_color", Color("#f2d6a2"))
	return_button.add_theme_stylebox_override("normal", MENU._make_button_style(false))
	return_button.add_theme_stylebox_override("hover", MENU._make_button_style(true))
	return_button.add_theme_stylebox_override("focus", MENU._make_button_style(true))
	return_button.add_theme_stylebox_override("pressed", MENU._make_button_style(true, true))
	end_menu.add_child(return_button)
	_center(return_button, Vector2(312, 62), 0.65)
	confirm = AudioStreamPlayer.new()
	confirm.stream = preload("res://assets/audio/menu_confirm.ogg")
	confirm.volume_db = -15.0
	add_child(confirm)
	return_button.pressed.connect(_return_to_menu)


func _return_to_menu() -> void:
	if return_button.disabled:
		return
	return_button.disabled = true
	confirm.play()
	var close := create_tween()
	close.tween_property(end_menu, "modulate:a", 0.0, 0.22)
	close.tween_callback(func() -> void: return_requested.emit())


func _center(item: Control, dimensions: Vector2, anchor_y: float) -> void:
	item.anchor_left = 0.5
	item.anchor_right = 0.5
	item.anchor_top = anchor_y
	item.anchor_bottom = anchor_y
	item.offset_left = -dimensions.x * 0.5
	item.offset_top = -dimensions.y * 0.5
	item.offset_right = dimensions.x * 0.5
	item.offset_bottom = dimensions.y * 0.5


func _label(parent: Control, words: String, font_size: int, color: Color, dimensions: Vector2, anchor_y: float) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	_center(label, dimensions, anchor_y)
	return label


func _texture(parent: Control, texture: Texture2D) -> TextureRect:
	var item := TextureRect.new()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return item
