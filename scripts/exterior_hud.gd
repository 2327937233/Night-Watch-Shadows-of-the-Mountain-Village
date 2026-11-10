extends Control

signal document_closed(item_id: String)

const INVENTORY_PAGE_SIZE := 12

@export var font_path = "res://assets/fonts/watchnight_chinese.tres"
@export var status_icon_path = "res://assets/ui/hud_status_icon.png"
@export var flashlight_icon_path = "res://assets/ui/hud_flashlight_icon.png"
@export var bag_icon_path = "res://assets/ui/hud_bag_icon.png"
@export var back_icon_path = "res://assets/ui/hud_back_icon.svg"

@onready var top_status: Control = $TopStatus
@onready var time_label: Label = $TopStatus/TimeLabel
@onready var dawn_hint: Label = $TopStatus/DawnHint
@onready var status_icon: TextureRect = $TopStatus/StatusIcon
@onready var health_back: ColorRect = $TopStatus/HealthBack
@onready var health_bar: ColorRect = $TopStatus/HealthBar
@onready var spirit_bar: ColorRect = $TopStatus/SpiritBar
@onready var pulse_line: Label = $TopStatus/PulseLine
@onready var objective_group: Control = $ObjectiveGroup
@onready var objective_glow: ColorRect = $ObjectiveGroup/ObjectiveGlow
@onready var objective_diamond: Label = $ObjectiveGroup/ObjectiveDiamond
@onready var objective_label: Label = $ObjectiveGroup/ObjectiveLabel
@onready var quick_slots: Control = $QuickSlots
@onready var flashlight_frame: Panel = $QuickSlots/FlashlightFrame
@onready var flashlight_icon: TextureRect = $QuickSlots/FlashlightIcon
@onready var flashlight_key: Label = $QuickSlots/FlashlightKey
@onready var bag_frame: Panel = $QuickSlots/BagFrame
@onready var bag_icon: TextureRect = $QuickSlots/BagIcon
@onready var bag_key: Label = $QuickSlots/BagKey
@onready var back_frame: Panel = $QuickSlots/BackFrame
@onready var back_icon: TextureRect = $QuickSlots/BackIcon
@onready var back_key: Label = $QuickSlots/BackKey
@onready var door_prompt: Control = $DoorPrompt
@onready var prompt_back: ColorRect = $DoorPrompt/PromptBack
@onready var key_box: Label = $DoorPrompt/KeyBox
@onready var prompt_text: Label = $DoorPrompt/PromptText

var ui_font: Font
var prompt_tween: Tween
var movement_caption: Control
var movement_label: Label
var movement_left_line: ColorRect
var movement_right_line: ColorRect
var movement_tween: Tween
var flashlight_is_enabled = true
var current_caption_text = ""
var current_caption_visible = false
var caption_priority := 0
var caption_minimum_remaining := 0.0
var queued_story_captions: Array[Dictionary] = []
var pending_environment_caption: Dictionary = {}
var inventory_overlay: Control
var inventory_panel: Panel
var inventory_slots: Array[Panel] = []
var inventory_slot_buttons: Array[Button] = []
var inventory_slot_icons: Array[TextureRect] = []
var inventory_slot_labels: Array[Label] = []
var inventory_previous_page_button: Button
var inventory_next_page_button: Button
var inventory_page_label: Label
var inventory_page_index := 0
var inventory_detail_icon: TextureRect
var inventory_detail_name: Label
var inventory_detail_category: Label
var inventory_detail_description: Label
var inventory_empty_hint: Label
var inventory_expand_button: Button
var inventory_document_overlay: Control
var inventory_document_dimmer: ColorRect
var inventory_document_shadow: Panel
var inventory_document_paper: TextureRect
var inventory_document_photo: TextureRect
var inventory_document_photo_rule: ColorRect
var inventory_document_photo_inscription: Label
var inventory_document_close_button: Button
var inventory_document_hint: Label
var inventory_document_body: Label
var inventory_document_pages: Array[String] = []
var inventory_document_page_index := 0
var inventory_document_last_page_seen := false
var inventory_document_has_photo := false
var inventory_document_tween: Tween
var inventory_document_photo_tween: Tween
var inventory_document_photo_click_count := 0
var inventory_item_ids: Array[String] = []
var selected_inventory_item_id := ""
var inventory_document_is_open := false
var inventory_document_item_id := ""
var inventory_document_returns_to_game := false
var inventory_is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_font = _safe_load_font(font_path)
	_ensure_movement_caption()
	_ensure_inventory_overlay()
	_apply_style()
	# This investigation has no combat health or stamina system.
	for unused_indicator in [health_back, health_bar, spirit_bar, pulse_line]:
		unused_indicator.hide()
	_load_icons()
	_layout(get_viewport_rect().size)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_door_prompt_visible(false, true)
	set_movement_caption("back", false, true)
	set_flashlight_enabled(true)
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_signal("inventory_changed"):
		game_state.inventory_changed.connect(_refresh_inventory)
	if game_state != null:
		game_state.night_time_changed.connect(_update_night_time)
		game_state.start_night_clock()
	_update_night_time()
	_refresh_inventory()


func _process(delta: float) -> void:
	# This HUD processes paused input, but caption reading time pauses with play.
	if get_tree().paused or caption_minimum_remaining <= 0.0:
		return
	caption_minimum_remaining = maxf(0.0, caption_minimum_remaining - delta)
	if caption_minimum_remaining == 0.0:
		_flush_pending_caption()


func _update_night_time(elapsed_minutes: int = -1) -> void:
	if elapsed_minutes < 0:
		elapsed_minutes = GameState.night_elapsed_minutes
	time_label.text = GameState.get_night_time_text()
	time_label.tooltip_text = ("次日 " if GameState.is_after_midnight() else "") + time_label.text
	dawn_hint.visible = elapsed_minutes >= 450 and elapsed_minutes < GameState.NIGHT_LENGTH_MINUTES
	time_label.add_theme_color_override("font_color", Color("#d4aa74") if dawn_hint.visible else _color("#C8C0B0", 0.86))
	if dawn_hint.visible and not GameState.dawn_warning_shown:
		GameState.dawn_warning_shown = true
		set_story_caption("快天亮了。六点前，得带着证据离开王宅。", true, true, 9, 3.5)


func _exit_tree() -> void:
	if inventory_is_open and get_tree() != null:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if inventory_document_is_open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
			_close_inventory_document()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_turn_document_page(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_turn_document_page(1)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		set_inventory_visible(not inventory_is_open)
		get_viewport().set_input_as_handled()
	elif inventory_is_open and event.is_action_pressed("ui_cancel"):
		set_inventory_visible(false)
		get_viewport().set_input_as_handled()
	elif inventory_is_open and event.is_action_pressed("ui_left"):
		_turn_inventory_page(-1)
		get_viewport().set_input_as_handled()
	elif inventory_is_open and event.is_action_pressed("ui_right"):
		_turn_inventory_page(1)
		get_viewport().set_input_as_handled()


func set_inventory_visible(is_visible: bool) -> void:
	if not is_visible:
		_close_inventory_document()
	inventory_is_open = is_visible
	if inventory_overlay != null:
		inventory_overlay.visible = is_visible
	if is_visible:
		_refresh_inventory()
	if get_tree() != null:
		get_tree().paused = is_visible


func set_door_prompt_visible(is_visible: bool, immediate = false) -> void:
	if prompt_tween != null:
		prompt_tween.kill()

	if immediate:
		door_prompt.visible = is_visible
		door_prompt.modulate.a = 1.0 if is_visible else 0.0
		return

	if is_visible:
		door_prompt.visible = true
		door_prompt.modulate.a = 0.0
		prompt_tween = create_tween()
		prompt_tween.tween_property(door_prompt, "modulate:a", 1.0, 0.16)
	else:
		prompt_tween = create_tween()
		prompt_tween.tween_property(door_prompt, "modulate:a", 0.0, 0.14)
		prompt_tween.finished.connect(func() -> void: door_prompt.visible = false)


func set_flashlight_enabled(enabled: bool) -> void:
	flashlight_is_enabled = enabled
	var icon_alpha = 1.0 if enabled else 0.34
	var frame_alpha = 0.95 if enabled else 0.45
	flashlight_icon.modulate = Color(1.0, 0.94, 0.78, icon_alpha) if enabled else Color(0.48, 0.48, 0.48, icon_alpha)
	flashlight_key.modulate = Color(1.0, 0.92, 0.72, 1.0) if enabled else Color(0.55, 0.55, 0.55, 0.75)
	flashlight_frame.modulate = Color(1.0, 0.92, 0.72, frame_alpha) if enabled else Color(0.42, 0.42, 0.42, frame_alpha)


func set_objective(text: String) -> void:
	objective_label.text = text


func set_interaction_text(text: String) -> void:
	prompt_text.text = text


func set_story_caption(text: String, is_visible: bool, immediate = false, priority := 0, minimum_seconds := 0.0) -> void:
	if movement_caption == null or movement_label == null:
		return
	if text == current_caption_text and is_visible == current_caption_visible and caption_minimum_remaining > 0.0:
		return
	if caption_minimum_remaining > 0.0 and priority <= caption_priority:
		var request := {"text": text, "visible": is_visible, "immediate": immediate, "priority": priority, "minimum": minimum_seconds}
		if priority == 0:
			# Region changes can arrive every frame: only retain the latest region.
			pending_environment_caption = request
		else:
			for queued in queued_story_captions:
				if queued["text"] == text and queued["visible"] == is_visible:
					return
			queued_story_captions.append(request)
		return
	if text == current_caption_text and is_visible == current_caption_visible and not immediate and priority == caption_priority:
		return
	caption_priority = priority
	caption_minimum_remaining = maxf(0.0, minimum_seconds) if is_visible else 0.0
	if priority >= 20:
		# A scripted sequence owns its own timing; discard older investigation
		# lines rather than letting them surface after the sequence has moved on.
		queued_story_captions.clear()
		pending_environment_caption = {}
	current_caption_text = text
	current_caption_visible = is_visible
	movement_label.text = text
	movement_label.position = Vector2(42.0, 0.0)
	movement_label.size = Vector2(276.0, 42.0)
	movement_left_line.size.x = 38.0
	movement_right_line.position.x = 322.0
	movement_right_line.size.x = 38.0
	_set_caption_visible(is_visible, immediate)


func _flush_pending_caption() -> void:
	var request: Dictionary = {}
	if not queued_story_captions.is_empty():
		var next_index := 0
		for index in range(1, queued_story_captions.size()):
			if int(queued_story_captions[index]["priority"]) > int(queued_story_captions[next_index]["priority"]):
				next_index = index
		request = queued_story_captions.pop_at(next_index)
	elif not pending_environment_caption.is_empty():
		request = pending_environment_caption
		pending_environment_caption = {}
	if not request.is_empty():
		set_story_caption(str(request["text"]), bool(request["visible"]), bool(request["immediate"]), int(request["priority"]), float(request["minimum"]))


func set_movement_caption(facing: String, moving: bool, immediate = false) -> void:
	if movement_caption == null or movement_label == null:
		return

	var text := "行走"
	match facing:
		"left":
			text = "左侧行走"
		"right":
			text = "右侧行走"
		"front":
			text = "正面行走"
		"back":
			text = "背面行走"
	set_story_caption(text, moving, immediate)


func _set_caption_visible(is_visible: bool, immediate: bool) -> void:
	if movement_tween != null:
		movement_tween.kill()

	if immediate:
		movement_caption.visible = is_visible
		movement_caption.modulate.a = 1.0 if is_visible else 0.0
		return

	if is_visible:
		movement_caption.visible = true
		movement_tween = create_tween()
		movement_tween.tween_property(movement_caption, "modulate:a", 1.0, 0.16)
	else:
		movement_tween = create_tween()
		movement_tween.tween_property(movement_caption, "modulate:a", 0.0, 0.22)
		movement_tween.finished.connect(func() -> void: movement_caption.visible = false)


func _on_viewport_size_changed() -> void:
	_layout(get_viewport_rect().size)


func _layout(viewport_size: Vector2) -> void:
	top_status.position = Vector2(36.0, 24.0)
	objective_group.size = Vector2(330.0, 56.0)
	objective_group.position = Vector2(viewport_size.x - objective_group.size.x - 142.0, 76.0)
	quick_slots.position = Vector2(42.0, viewport_size.y - 166.0)
	door_prompt.position = Vector2(viewport_size.x * 0.50 - 108.0, 480.0)
	if movement_caption != null:
		movement_caption.size = Vector2(480.0, 42.0)
		movement_caption.position = Vector2(viewport_size.x * 0.5 - 240.0, viewport_size.y - 104.0)
	if inventory_document_paper != null:
		_layout_document_reader(viewport_size)


func _apply_style() -> void:
	_update_night_time()
	objective_diamond.text = "◇"
	objective_label.text = "进入荒宅"
	flashlight_key.text = "F"
	bag_key.text = "Tab"
	key_box.text = "E"
	prompt_text.text = "推门进入"
	pulse_line.text = "╲╱╲─"

	var labels = [time_label, dawn_hint, pulse_line, objective_diamond, objective_label, flashlight_key, bag_key, back_key, key_box, prompt_text]
	for label in labels:
		if ui_font != null:
			label.add_theme_font_override("font", ui_font)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
		label.add_theme_constant_override("shadow_outline_size", 2)

	time_label.add_theme_font_size_override("font_size", 25)
	dawn_hint.add_theme_font_size_override("font_size", 19)
	dawn_hint.add_theme_color_override("font_color", Color("#d4aa74"))
	pulse_line.add_theme_font_size_override("font_size", 19)
	pulse_line.add_theme_color_override("font_color", _color("#00B267", 0.86))

	objective_diamond.add_theme_font_size_override("font_size", 25)
	objective_diamond.add_theme_color_override("font_color", _color("#C58B35", 0.95))
	objective_label.add_theme_font_size_override("font_size", 26)
	objective_label.add_theme_color_override("font_color", _color("#D7C6AA", 0.9))
	# Objectives must sit inside the scene instead of on a fixed-colour card.
	# Readability comes from the restrained text shadow, so the rain-night,
	# plaster and timber behind the objective remain visible and consistent.
	objective_glow.color = Color(0.0, 0.0, 0.0, 0.0)
	objective_glow.visible = false

	for label in [flashlight_key, bag_key, back_key, key_box]:
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", _color("#D7C6AA", 0.9))
		label.add_theme_stylebox_override("normal", _make_key_style())

	prompt_text.add_theme_font_size_override("font_size", 25)
	prompt_text.add_theme_color_override("font_color", _color("#D7C6AA", 0.9))
	# Keep the compact E key cap, but remove the wide black prompt rectangle.
	# This prevents interaction text from looking pasted over brighter walls.
	prompt_back.color = Color(0.0, 0.0, 0.0, 0.0)
	prompt_back.visible = false

	flashlight_frame.add_theme_stylebox_override("panel", _make_slot_style())
	bag_frame.add_theme_stylebox_override("panel", _make_slot_style())
	back_frame.add_theme_stylebox_override("panel", _make_slot_style())
	back_icon.modulate = Color(0.86, 0.77, 0.62, 0.92)
	if movement_label != null:
		movement_label.add_theme_font_size_override("font_size", 24)
		movement_label.add_theme_color_override("font_color", _color("#D7C6AA", 0.88))
		movement_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		movement_label.add_theme_constant_override("shadow_outline_size", 3)
		if ui_font != null:
			movement_label.add_theme_font_override("font", ui_font)
	if movement_left_line != null:
		movement_left_line.color = _color("#8B6B42", 0.46)
	if movement_right_line != null:
		movement_right_line.color = _color("#8B6B42", 0.46)

	health_back.color = _color("#180807", 0.78)
	health_bar.color = _color("#9B1519", 0.95)
	spirit_bar.color = _color("#008B4A", 0.88)


func _load_icons() -> void:
	status_icon.texture = _safe_load_texture(status_icon_path)
	flashlight_icon.texture = _safe_load_texture(flashlight_icon_path)
	bag_icon.texture = _safe_load_texture(bag_icon_path)
	back_icon.texture = _safe_load_texture(back_icon_path)


func _ensure_movement_caption() -> void:
	movement_caption = get_node_or_null("MovementCaption") as Control
	if movement_caption == null:
		movement_caption = Control.new()
		movement_caption.name = "MovementCaption"
		movement_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(movement_caption)

	movement_left_line = movement_caption.get_node_or_null("LeftLine") as ColorRect
	if movement_left_line == null:
		movement_left_line = ColorRect.new()
		movement_left_line.name = "LeftLine"
		movement_left_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		movement_left_line.position = Vector2(0.0, 20.0)
		movement_left_line.size = Vector2(110.0, 2.0)
		movement_caption.add_child(movement_left_line)

	movement_right_line = movement_caption.get_node_or_null("RightLine") as ColorRect
	if movement_right_line == null:
		movement_right_line = ColorRect.new()
		movement_right_line.name = "RightLine"
		movement_right_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		movement_right_line.position = Vector2(250.0, 20.0)
		movement_right_line.size = Vector2(110.0, 2.0)
		movement_caption.add_child(movement_right_line)

	movement_label = movement_caption.get_node_or_null("CaptionLabel") as Label
	if movement_label == null:
		movement_label = Label.new()
		movement_label.name = "CaptionLabel"
		movement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		movement_label.position = Vector2(112.0, 0.0)
		movement_label.size = Vector2(136.0, 42.0)
		movement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		movement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		movement_caption.add_child(movement_label)


func _ensure_inventory_overlay() -> void:
	inventory_overlay = Control.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_overlay.z_index = 80
	inventory_overlay.visible = false
	add_child(inventory_overlay)

	var dimmer = ColorRect.new()
	dimmer.name = "RainNightDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.005, 0.007, 0.008, 0.88)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.add_child(dimmer)

	inventory_panel = Panel.new()
	inventory_panel.name = "OldLedgerInventoryPanel"
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.offset_left = -505.0
	inventory_panel.offset_top = -315.0
	inventory_panel.offset_right = 505.0
	inventory_panel.offset_bottom = 315.0
	inventory_panel.add_theme_stylebox_override("panel", _make_inventory_panel_style())
	inventory_overlay.add_child(inventory_panel)

	_make_inventory_label(inventory_panel, "Title", "行 囊", Vector2(42, 24), Vector2(300, 56), 38, Color(0.82, 0.71, 0.54, 0.96))
	_make_inventory_label(inventory_panel, "Subtitle", "随身携带之物", Vector2(45, 70), Vector2(300, 32), 19, Color(0.56, 0.51, 0.43, 0.82))
	var header_line = ColorRect.new()
	header_line.position = Vector2(42, 108)
	header_line.size = Vector2(926, 2)
	header_line.color = Color(0.42, 0.29, 0.16, 0.62)
	inventory_panel.add_child(header_line)

	var grid_back = Panel.new()
	grid_back.name = "InventoryGrid"
	grid_back.position = Vector2(42, 132)
	grid_back.size = Vector2(548, 410)
	grid_back.add_theme_stylebox_override("panel", _make_inventory_inner_style())
	inventory_panel.add_child(grid_back)
	for index in range(INVENTORY_PAGE_SIZE):
		var column = index % 4
		var row = index / 4
		var slot = Panel.new()
		slot.name = "ItemSlot_%02d" % index
		slot.position = Vector2(20 + column * 130, 18 + row * 126)
		slot.size = Vector2(112, 108)
		slot.add_theme_stylebox_override("panel", _make_inventory_slot_style(false))
		grid_back.add_child(slot)
		inventory_slots.append(slot)
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(19, 8)
		icon.size = Vector2(74, 70)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		inventory_slot_icons.append(icon)
		var item_label = _make_inventory_label(slot, "Name", "", Vector2(5, 78), Vector2(102, 25), 15, Color(0.74, 0.66, 0.54, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
		item_label.clip_text = true
		item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		inventory_slot_labels.append(item_label)
		var hitbox := Button.new()
		hitbox.name = "SelectItemButton"
		hitbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hitbox.flat = true
		hitbox.focus_mode = Control.FOCUS_NONE
		hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hitbox.disabled = true
		hitbox.tooltip_text = ""
		hitbox.pressed.connect(_on_inventory_slot_pressed.bind(index))
		slot.add_child(hitbox)
		inventory_slot_buttons.append(hitbox)

	var detail_back = Panel.new()
	detail_back.name = "ItemDetails"
	detail_back.position = Vector2(612, 132)
	detail_back.size = Vector2(356, 410)
	detail_back.add_theme_stylebox_override("panel", _make_inventory_inner_style())
	inventory_panel.add_child(detail_back)
	inventory_detail_icon = TextureRect.new()
	inventory_detail_icon.name = "SelectedItemIcon"
	inventory_detail_icon.position = Vector2(94, 20)
	inventory_detail_icon.size = Vector2(168, 150)
	inventory_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inventory_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_back.add_child(inventory_detail_icon)
	inventory_detail_name = _make_inventory_label(detail_back, "SelectedItemName", "", Vector2(28, 182), Vector2(300, 40), 25, Color(0.82, 0.68, 0.45, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	inventory_detail_category = _make_inventory_label(detail_back, "SelectedItemCategory", "", Vector2(28, 217), Vector2(300, 24), 15, Color(0.55, 0.46, 0.34, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	var detail_line = ColorRect.new()
	detail_line.position = Vector2(48, 245)
	detail_line.size = Vector2(260, 1)
	detail_line.color = Color(0.42, 0.29, 0.16, 0.62)
	detail_back.add_child(detail_line)
	inventory_detail_description = _make_inventory_label(detail_back, "SelectedItemDescription", "", Vector2(35, 258), Vector2(286, 92), 18, Color(0.67, 0.63, 0.56, 0.90))
	inventory_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_expand_button = Button.new()
	inventory_expand_button.name = "ExpandSelectedItem"
	inventory_expand_button.text = "展开阅读"
	inventory_expand_button.position = Vector2(91,354)
	inventory_expand_button.size = Vector2(174,40)
	inventory_expand_button.focus_mode = Control.FOCUS_NONE
	inventory_expand_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	inventory_expand_button.add_theme_font_size_override("font_size",18)
	inventory_expand_button.add_theme_color_override("font_color",Color(0.80,0.69,0.50,0.96))
	inventory_expand_button.add_theme_color_override("font_hover_color",Color(0.96,0.82,0.56,1.0))
	if ui_font != null:
		inventory_expand_button.add_theme_font_override("font",ui_font)
	inventory_expand_button.add_theme_stylebox_override("normal",_make_inventory_action_style(false))
	inventory_expand_button.add_theme_stylebox_override("hover",_make_inventory_action_style(true))
	inventory_expand_button.add_theme_stylebox_override("pressed",_make_inventory_action_style(true))
	inventory_expand_button.pressed.connect(_open_selected_inventory_document)
	inventory_expand_button.visible = false
	detail_back.add_child(inventory_expand_button)
	inventory_empty_hint = _make_inventory_label(detail_back, "EmptyHint", "背包里空空的，\n只残留着潮湿的布味。", Vector2(35, 184), Vector2(286, 100), 20, Color(0.48, 0.46, 0.42, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	inventory_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inventory_previous_page_button = _make_inventory_page_button("PreviousInventoryPage", "A  上一页", Vector2(42, 554))
	inventory_previous_page_button.pressed.connect(_turn_inventory_page.bind(-1))
	inventory_page_label = _make_inventory_label(inventory_panel, "InventoryPageNumber", "第 1 / 1 页", Vector2(200, 558), Vector2(232, 32), 18, Color(0.66, 0.58, 0.45, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	inventory_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_next_page_button = _make_inventory_page_button("NextInventoryPage", "下一页  D", Vector2(440, 554))
	inventory_next_page_button.pressed.connect(_turn_inventory_page.bind(1))
	_make_inventory_label(inventory_panel, "CloseHint", "Tab 关闭    ·    ESC 返回游戏", Vector2(610, 562), Vector2(358, 32), 17, Color(0.55, 0.50, 0.42, 0.84), HORIZONTAL_ALIGNMENT_RIGHT)
	_build_inventory_document_overlay()


func _make_inventory_page_button(node_name: String, text: String, position: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = position
	button.size = Vector2(150, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.80, 0.69, 0.50, 0.96))
	button.add_theme_color_override("font_hover_color", Color(0.96, 0.82, 0.56, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.38, 0.31, 0.65))
	if ui_font != null:
		button.add_theme_font_override("font", ui_font)
	button.add_theme_stylebox_override("normal", _make_inventory_action_style(false))
	button.add_theme_stylebox_override("hover", _make_inventory_action_style(true))
	button.add_theme_stylebox_override("pressed", _make_inventory_action_style(true))
	button.add_theme_stylebox_override("disabled", _make_inventory_inner_style())
	inventory_panel.add_child(button)
	return button


func _make_inventory_label(parent: Control, node_name: String, text: String, position: Vector2, size: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("shadow_outline_size", 3)
	if ui_font != null:
		label.add_theme_font_override("font", ui_font)
	parent.add_child(label)
	return label


func _build_inventory_document_overlay() -> void:
	inventory_document_overlay = Control.new()
	inventory_document_overlay.name = "InventoryDocumentOverlay"
	inventory_document_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_document_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_document_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_document_overlay.z_index = 120
	inventory_document_overlay.visible = false
	inventory_overlay.add_child(inventory_document_overlay)
	inventory_document_dimmer = ColorRect.new()
	inventory_document_dimmer.name = "BackgroundDim"
	inventory_document_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_document_dimmer.color = Color.WHITE
	inventory_document_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	var blur_material := ShaderMaterial.new()
	blur_material.shader = load("res://shaders/document_reader_dim.gdshader") as Shader
	inventory_document_dimmer.material = blur_material
	inventory_document_overlay.add_child(inventory_document_dimmer)
	inventory_document_shadow = Panel.new()
	inventory_document_shadow.name = "PaperSoftShadow"
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.06, 0.04, 0.025, 0.08)
	shadow_style.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	shadow_style.shadow_size = 31
	inventory_document_shadow.add_theme_stylebox_override("panel", shadow_style)
	inventory_document_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_document_overlay.add_child(inventory_document_shadow)
	inventory_document_paper = TextureRect.new()
	inventory_document_paper.name = "ExpandedOldPaper"
	inventory_document_paper.texture = _safe_load_texture("res://assets/ui/reader_old_paper.png")
	inventory_document_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inventory_document_paper.stretch_mode = TextureRect.STRETCH_SCALE
	inventory_document_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_document_overlay.add_child(inventory_document_paper)
	inventory_document_photo = TextureRect.new()
	inventory_document_photo.name = "ActualScratchedPhoto"
	inventory_document_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inventory_document_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inventory_document_photo.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_document_photo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	inventory_document_photo.gui_input.connect(_on_inventory_document_photo_input)
	inventory_document_photo.visible = false
	inventory_document_paper.add_child(inventory_document_photo)
	inventory_document_photo_rule = ColorRect.new()
	inventory_document_photo_rule.name = "PhotoInscriptionRule"
	inventory_document_photo_rule.color = Color(0.24, 0.16, 0.10, 0.34)
	inventory_document_photo_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_document_photo_rule.visible = false
	inventory_document_paper.add_child(inventory_document_photo_rule)
	inventory_document_photo_inscription = _make_inventory_label(inventory_document_paper, "PhotoHiddenInscription", GameState.PHOTO_WEDDING_INSCRIPTION, Vector2.ZERO, Vector2.ONE, 21, Color(0.18, 0.115, 0.072, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	inventory_document_photo_inscription.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inventory_document_photo_inscription.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	inventory_document_photo_inscription.add_theme_constant_override("shadow_outline_size", 0)
	inventory_document_photo_inscription.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_document_photo_inscription.visible = false
	inventory_document_body = _make_inventory_label(inventory_document_paper, "DocumentBody", "", Vector2.ZERO, Vector2.ONE, 27, Color(0.13, 0.095, 0.067, 0.97), HORIZONTAL_ALIGNMENT_LEFT)
	inventory_document_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inventory_document_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_document_body.clip_text = true
	inventory_document_body.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	inventory_document_body.add_theme_constant_override("shadow_outline_size", 0)
	inventory_document_body.add_theme_constant_override("line_spacing", 8)
	inventory_document_close_button = Button.new()
	inventory_document_close_button.name = "CloseExpandedDocument"
	inventory_document_close_button.text = "×"
	inventory_document_close_button.focus_mode = Control.FOCUS_NONE
	inventory_document_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	inventory_document_close_button.add_theme_font_size_override("font_size", 29)
	inventory_document_close_button.add_theme_color_override("font_color", Color(0.73, 0.69, 0.62, 0.88))
	inventory_document_close_button.add_theme_color_override("font_hover_color", Color(0.93, 0.83, 0.68, 1.0))
	inventory_document_close_button.add_theme_stylebox_override("normal", _make_reader_close_style(false))
	inventory_document_close_button.add_theme_stylebox_override("hover", _make_reader_close_style(true))
	inventory_document_close_button.add_theme_stylebox_override("pressed", _make_reader_close_style(true))
	inventory_document_close_button.pressed.connect(_close_inventory_document)
	inventory_document_overlay.add_child(inventory_document_close_button)
	inventory_document_hint = _make_inventory_label(inventory_document_overlay, "NavigationHints", "ESC 关闭", Vector2.ZERO, Vector2.ONE, 17, Color(0.73, 0.68, 0.58, 0.87), HORIZONTAL_ALIGNMENT_CENTER)
	inventory_document_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.50))
	_layout_document_reader(get_viewport_rect().size)


func _make_reader_close_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.83) if hovered else Color(0.055, 0.048, 0.043, 0.70)
	style.border_color = Color(0.48, 0.40, 0.30, 0.78) if hovered else Color(0.28, 0.24, 0.20, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _layout_document_reader(viewport_size: Vector2) -> void:
	var paper_size := Vector2(minf(viewport_size.x * 0.46, 1220.0), minf(viewport_size.y * 0.82, 1200.0))
	paper_size.x = minf(paper_size.x, viewport_size.x - 150.0)
	paper_size.y = minf(paper_size.y, viewport_size.y - 95.0)
	var paper_pos := (viewport_size - paper_size) * 0.5 - Vector2(0.0, 11.0)
	inventory_document_paper.position = paper_pos
	inventory_document_paper.size = paper_size
	inventory_document_paper.pivot_offset = paper_size * 0.5
	inventory_document_shadow.position = paper_pos + Vector2(30, 29)
	inventory_document_shadow.size = paper_size - Vector2(60, 60)
	inventory_document_close_button.position = Vector2(minf(viewport_size.x - 70.0, paper_pos.x + paper_size.x + 18.0), paper_pos.y + 14.0)
	inventory_document_close_button.size = Vector2(49, 49)
	inventory_document_hint.position = Vector2(paper_pos.x, minf(viewport_size.y - 34.0, paper_pos.y + paper_size.y + 10.0))
	inventory_document_hint.size = Vector2(paper_size.x, 30.0)
	var body_font_size := clampi(roundi(paper_size.y * 0.036), 23, 37)
	if inventory_document_has_photo:
		inventory_document_photo.position = Vector2(paper_size.x * 0.145, paper_size.y * 0.10)
		inventory_document_photo.size = Vector2(paper_size.x * 0.71, paper_size.y * 0.38)
		inventory_document_photo.pivot_offset = inventory_document_photo.size * 0.5
		inventory_document_photo_rule.position = Vector2(paper_size.x * 0.29, paper_size.y * 0.493)
		inventory_document_photo_rule.size = Vector2(paper_size.x * 0.42, 1.0)
		inventory_document_photo_inscription.position = Vector2(paper_size.x * 0.15, paper_size.y * 0.498)
		inventory_document_photo_inscription.size = Vector2(paper_size.x * 0.70, paper_size.y * 0.055)
		inventory_document_photo_inscription.add_theme_font_size_override("font_size", clampi(roundi(paper_size.y * 0.025), 18, 27))
		inventory_document_body.position = Vector2(paper_size.x * 0.15, paper_size.y * 0.575)
		inventory_document_body.size = Vector2(paper_size.x * 0.70, paper_size.y * 0.315)
		body_font_size = clampi(roundi(paper_size.y * 0.028), 21, 31)
	else:
		inventory_document_photo_rule.visible = false
		inventory_document_photo_inscription.visible = false
		inventory_document_body.position = Vector2(paper_size.x * 0.15, paper_size.y * 0.12)
		inventory_document_body.size = Vector2(paper_size.x * 0.70, paper_size.y * 0.75)
	inventory_document_body.add_theme_font_size_override("font_size", body_font_size)
	if inventory_document_is_open:
		_set_document_pages(inventory_document_item_id)


func _paginate_document_text(source: String) -> Array[String]:
	var pages: Array[String] = []
	var font: Font = ui_font if ui_font != null else ThemeDB.fallback_font
	var font_size := inventory_document_body.get_theme_font_size("font_size")
	var line_height := maxf(font.get_height(font_size) + 8.0, float(font_size) * 1.45)
	var max_lines := maxi(3, int(floor((inventory_document_body.size.y - 10.0) / line_height)))
	var max_width := inventory_document_body.size.x - 32.0
	var visual_lines: Array[String] = []
	for original_line in source.split("\n", true):
		if original_line.is_empty():
			visual_lines.append("")
			continue
		var current_line := ""
		for character in original_line:
			var candidate := current_line + character
			if not current_line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
				var comma_break := current_line.rfind("，")
				if comma_break >= current_line.length() / 2:
					visual_lines.append(current_line.substr(0, comma_break + 1))
					current_line = current_line.substr(comma_break + 1) + character
				elif "，。！？；：、）》」』".contains(character) and current_line.length() > 1:
					var carried := current_line.substr(current_line.length() - 1, 1)
					visual_lines.append(current_line.substr(0, current_line.length() - 1))
					current_line = carried + character
				else:
					visual_lines.append(current_line)
					current_line = character
			else:
				current_line = candidate
		visual_lines.append(current_line)
	var page_lines: Array[String] = []
	for line in visual_lines:
		if page_lines.size() >= max_lines:
			pages.append("\n".join(page_lines).strip_edges())
			page_lines.clear()
		page_lines.append(line)
	if not page_lines.is_empty() or pages.is_empty():
		pages.append("\n".join(page_lines).strip_edges())
	return pages


func _set_document_pages(item_id: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or item_id.is_empty():
		return
	var definition := state.call("get_item_definition", item_id) as Dictionary
	inventory_document_pages = _paginate_document_text(str(definition.get("document_text", definition.get("description", ""))))
	inventory_document_page_index = clampi(inventory_document_page_index, 0, inventory_document_pages.size() - 1)
	_show_document_page()


func _show_document_page() -> void:
	if inventory_document_pages.is_empty():
		inventory_document_body.text = ""
		inventory_document_hint.text = "ESC 关闭"
		return
	inventory_document_body.text = inventory_document_pages[inventory_document_page_index]
	if inventory_document_page_index == inventory_document_pages.size() - 1:
		inventory_document_last_page_seen = true
	if inventory_document_pages.size() == 1:
		inventory_document_hint.text = "ESC 关闭"
	else:
		inventory_document_hint.text = "A 上一页     ·     %d / %d     ·     D 下一页     ·     ESC 关闭" % [inventory_document_page_index + 1, inventory_document_pages.size()]
	if inventory_document_item_id == "scratched_family_photo" and not GameState.bedroom_photo_inscription_revealed:
		var photo_hint := "点击照片查看背面" if inventory_document_photo_click_count == 0 else "再查看照片背面"
		inventory_document_hint.text = photo_hint + "     ·     " + inventory_document_hint.text


func _turn_document_page(direction: int) -> void:
	if inventory_document_pages.size() < 2:
		return
	inventory_document_page_index = clampi(inventory_document_page_index + direction, 0, inventory_document_pages.size() - 1)
	_show_document_page()


func _on_inventory_document_photo_input(event: InputEvent) -> void:
	if not inventory_document_is_open or inventory_document_item_id != "scratched_family_photo":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		inventory_document_photo.accept_event()
		_inspect_scratched_family_photo()


func _inspect_scratched_family_photo() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or inventory_document_item_id != "scratched_family_photo":
		return
	if bool(state.get("bedroom_photo_inscription_revealed")):
		_show_photo_inscription(false)
		return
	state.bedroom_photo_inspections = mini(state.bedroom_photo_inspections + 1, 3)
	inventory_document_photo_click_count = state.bedroom_photo_inspections
	if inventory_document_photo_tween != null:
		inventory_document_photo_tween.kill()
	inventory_document_photo.rotation = deg_to_rad(-0.28 if inventory_document_photo_click_count % 2 == 1 else 0.28)
	inventory_document_photo.scale = Vector2(0.992, 0.992)
	inventory_document_photo_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	inventory_document_photo_tween.set_parallel(true)
	inventory_document_photo_tween.tween_property(inventory_document_photo, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	inventory_document_photo_tween.tween_property(inventory_document_photo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if inventory_document_photo_click_count >= 3:
		state.set("bedroom_photo_inscription_revealed", true)
		_show_photo_inscription(true)
	_show_document_page()


func _show_photo_inscription(animated: bool) -> void:
	inventory_document_photo_rule.visible = true
	inventory_document_photo_inscription.visible = true
	if not animated:
		inventory_document_photo_rule.modulate.a = 1.0
		inventory_document_photo_inscription.modulate.a = 1.0
		return
	inventory_document_photo_rule.modulate.a = 0.0
	inventory_document_photo_inscription.modulate.a = 0.0
	var target_y := inventory_document_photo_inscription.position.y
	inventory_document_photo_inscription.position.y = target_y + 5.0
	var reveal_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(inventory_document_photo_rule, "modulate:a", 1.0, 0.50)
	reveal_tween.tween_property(inventory_document_photo_inscription, "modulate:a", 1.0, 0.62)
	reveal_tween.tween_property(inventory_document_photo_inscription, "position:y", target_y, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_inventory_slot_pressed(index: int) -> void:
	if inventory_document_is_open or index < 0 or index >= inventory_slots.size():
		return
	var item_index := inventory_page_index * INVENTORY_PAGE_SIZE + index
	if item_index >= inventory_item_ids.size():
		return
	selected_inventory_item_id = inventory_item_ids[item_index]
	_update_inventory_selection()


func _update_inventory_selection() -> void:
	var state := get_node_or_null("/root/GameState")
	var has_selection := state != null and not selected_inventory_item_id.is_empty() and inventory_item_ids.has(selected_inventory_item_id)
	inventory_empty_hint.visible = not has_selection
	inventory_detail_icon.visible = has_selection
	inventory_detail_name.visible = has_selection
	inventory_detail_category.visible = has_selection
	inventory_detail_description.visible = has_selection
	inventory_expand_button.visible = false
	for index in range(inventory_slots.size()):
		var item_index := inventory_page_index * INVENTORY_PAGE_SIZE + index
		var selected := item_index < inventory_item_ids.size() and inventory_item_ids[item_index] == selected_inventory_item_id
		inventory_slots[index].add_theme_stylebox_override("panel",_make_inventory_slot_style(selected))
	if not has_selection:
		inventory_detail_icon.texture = null
		inventory_detail_name.text = ""
		inventory_detail_category.text = ""
		inventory_detail_description.text = ""
		return
	var definition := state.call("get_item_definition",selected_inventory_item_id) as Dictionary
	inventory_detail_icon.texture = _safe_load_texture(str(definition.get("icon","")))
	inventory_detail_name.text = str(definition.get("name","未知物件"))
	inventory_detail_category.text = "〔%s〕" % str(definition.get("category", "物品"))
	inventory_detail_description.text = str(definition.get("description","这件物品没有留下说明。"))
	inventory_expand_button.visible = bool(definition.get("can_expand",false))


func _open_selected_inventory_document() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or selected_inventory_item_id.is_empty():
		return
	var definition := state.call("get_item_definition",selected_inventory_item_id) as Dictionary
	if not bool(definition.get("can_expand",false)):
		return
	if inventory_document_tween != null:
		inventory_document_tween.kill()
	inventory_document_item_id = selected_inventory_item_id
	inventory_document_is_open = true
	inventory_document_page_index = 0
	inventory_document_last_page_seen = false
	var image_path := str(definition.get("document_image", ""))
	inventory_document_photo.texture = _safe_load_texture(image_path) if not image_path.is_empty() else null
	inventory_document_has_photo = inventory_document_photo.texture != null
	inventory_document_photo.visible = inventory_document_has_photo
	inventory_document_photo.rotation = 0.0
	inventory_document_photo.scale = Vector2.ONE
	inventory_document_photo_click_count = state.bedroom_photo_inspections if selected_inventory_item_id == "scratched_family_photo" else 0
	inventory_document_photo_rule.visible = false
	inventory_document_photo_inscription.visible = false
	_layout_document_reader(get_viewport_rect().size)
	if inventory_document_item_id == "scratched_family_photo" and bool(state.get("bedroom_photo_inscription_revealed")):
		_show_photo_inscription(false)
	_set_document_pages(selected_inventory_item_id)
	(inventory_overlay.get_node("RainNightDimmer") as ColorRect).color = Color(0.005, 0.007, 0.008, 0.18)
	inventory_panel.modulate.a = 0.25
	inventory_document_overlay.visible = true
	inventory_document_overlay.modulate.a = 0.0
	inventory_document_paper.scale = Vector2(0.97, 0.97)
	inventory_document_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	inventory_document_tween.set_parallel(true)
	inventory_document_tween.tween_property(inventory_document_overlay, "modulate:a", 1.0, 0.25)
	inventory_document_tween.tween_property(inventory_document_paper, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_inventory_document() -> void:
	if not inventory_document_is_open:
		return
	var closed_item_id := inventory_document_item_id
	var should_return_to_game := inventory_document_returns_to_game
	if inventory_document_last_page_seen:
		GameState.mark_document_completed(closed_item_id)
	inventory_document_is_open = false
	inventory_document_item_id = ""
	inventory_document_returns_to_game = false
	if inventory_document_tween != null:
		inventory_document_tween.kill()
	inventory_document_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	inventory_document_tween.set_parallel(true)
	inventory_document_tween.tween_property(inventory_document_overlay, "modulate:a", 0.0, 0.18)
	inventory_document_tween.tween_property(inventory_document_paper, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	inventory_document_tween.finished.connect(func() -> void:
		if inventory_document_is_open:
			return
		inventory_document_overlay.visible = false
		inventory_document_paper.scale = Vector2.ONE
		(inventory_overlay.get_node("RainNightDimmer") as ColorRect).color = Color(0.005, 0.007, 0.008, 0.88)
		inventory_panel.modulate.a = 1.0
		if should_return_to_game:
			inventory_overlay.visible = false
	)
	if should_return_to_game:
		inventory_is_open = false
		if get_tree() != null:
			get_tree().paused = false
	document_closed.emit(closed_item_id)


func open_document_item(item_id: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.call("has_item", item_id):
		return
	selected_inventory_item_id = item_id
	set_inventory_visible(true)
	_update_inventory_selection()
	inventory_document_returns_to_game = true
	_open_selected_inventory_document()


func _refresh_inventory() -> void:
	if not is_inside_tree() or inventory_slots.is_empty():
		return
	inventory_item_ids.clear()
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_inventory_items"):
		inventory_item_ids = game_state.call("get_inventory_items") as Array[String]
	inventory_page_index = clampi(inventory_page_index, 0, _inventory_page_count() - 1)
	if inventory_item_ids.has(selected_inventory_item_id):
		# Directly opening a newly acquired document also reveals its bag page.
		inventory_page_index = inventory_item_ids.find(selected_inventory_item_id) / INVENTORY_PAGE_SIZE
	else:
		var first_item := inventory_page_index * INVENTORY_PAGE_SIZE
		selected_inventory_item_id = inventory_item_ids[first_item] if not inventory_item_ids.is_empty() else ""
	_render_inventory_page()


func _inventory_page_count() -> int:
	return maxi(1, ceili(float(inventory_item_ids.size()) / INVENTORY_PAGE_SIZE))


func _turn_inventory_page(direction: int) -> void:
	if not inventory_is_open or inventory_document_is_open:
		return
	var next_page := clampi(inventory_page_index + direction, 0, _inventory_page_count() - 1)
	if next_page == inventory_page_index:
		return
	inventory_page_index = next_page
	selected_inventory_item_id = inventory_item_ids[inventory_page_index * INVENTORY_PAGE_SIZE]
	_render_inventory_page()


func _render_inventory_page() -> void:
	var game_state := get_node_or_null("/root/GameState")
	var page_start := inventory_page_index * INVENTORY_PAGE_SIZE
	for index in range(inventory_slots.size()):
		inventory_slot_icons[index].texture = null
		inventory_slot_icons[index].visible = false
		inventory_slot_labels[index].text = ""
		inventory_slots[index].add_theme_stylebox_override("panel", _make_inventory_slot_style(false))
		inventory_slot_buttons[index].disabled = true
		inventory_slot_buttons[index].tooltip_text = ""
		var item_index := page_start + index
		if item_index >= inventory_item_ids.size():
			continue
		var definition = game_state.call("get_item_definition", inventory_item_ids[item_index]) as Dictionary
		inventory_slot_icons[index].texture = _safe_load_texture(str(definition.get("icon", "")))
		inventory_slot_icons[index].visible = true
		inventory_slot_labels[index].text = str(definition.get("name", "未知物件"))
		inventory_slot_buttons[index].disabled = false
		inventory_slot_buttons[index].tooltip_text = "查看：" + str(definition.get("name","未知物件"))
	var page_count := _inventory_page_count()
	inventory_page_label.text = "第 %d / %d 页" % [inventory_page_index + 1, page_count]
	inventory_previous_page_button.disabled = inventory_page_index == 0
	inventory_next_page_button.disabled = inventory_page_index == page_count - 1
	_update_inventory_selection()


func _make_inventory_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.019, 0.98)
	style.border_color = Color(0.39, 0.25, 0.13, 0.90)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0, 0, 0, 0.88)
	style.shadow_size = 24
	return style


func _make_inventory_inner_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.017, 0.015, 0.94)
	style.border_color = Color(0.24, 0.17, 0.11, 0.72)
	style.set_border_width_all(1)
	return style


func _make_inventory_slot_style(selected: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.050, 0.031, 0.90) if selected else Color(0.027, 0.024, 0.020, 0.90)
	style.border_color = Color(0.66, 0.45, 0.21, 0.96) if selected else Color(0.27, 0.20, 0.14, 0.70)
	style.set_border_width_all(2 if selected else 1)
	style.shadow_color = Color(0, 0, 0, 0.50)
	style.shadow_size = 6
	return style


func _make_inventory_action_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13,0.085,0.042,0.96) if hovered else Color(0.075,0.052,0.032,0.92)
	style.border_color = Color(0.72,0.48,0.22,0.94) if hovered else Color(0.40,0.28,0.15,0.84)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _make_close_button_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.26,0.095,0.055,0.24) if hovered else Color(0.08,0.050,0.027,0.14)
	style.border_color = Color(0.40,0.16,0.09,0.72) if hovered else Color(0.22,0.13,0.065,0.44)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _make_slot_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = _color("#120C08", 0.66)
	style.border_color = _color("#6F4A31", 0.58)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0, 0, 0, 0.52)
	style.shadow_size = 8
	return style


func _make_key_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = _color("#0B0908", 0.72)
	style.border_color = _color("#8C7A62", 0.62)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_content_margin(SIDE_LEFT, 5.0)
	style.set_content_margin(SIDE_RIGHT, 5.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _safe_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource

	var image = Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
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
