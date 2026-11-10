extends Node3D
## Final walk through the original courtyard entrance, independent of player controls.

const TITLES = preload("res://scripts/wang_estate_ending_titles.gd")
const MENU_PATH := "res://scenes/StartMenu.tscn"
const STAGE = GameState.WangEstateExitStage
const THRESHOLD_Z := 14.0
const START_Z := 7.15
const LAST_SHOT := 22.4

@export var door_sound: AudioStream = preload("res://assets/audio/public_effects/door_push.wav")
@export var reflection_voice: AudioStream
@export var last_words_voice: AudioStream

var courtyard: Node3D
var actor: CharacterBody3D
var sprite: AnimatedSprite3D
var camera: Camera3D
var hud: Control
var entrance: Node3D
var titles: CanvasLayer
var leaves: Array[Node3D] = []
var voice: AudioStreamPlayer
var hinge: AudioStreamPlayer3D
var start_position := Vector3.ZERO
var rain_db := -7.0
var elapsed := 0.0
var timing_scale := 1.0
var busy := false
var cards_started := false


func setup(owner_court: Node3D, original_entrance: Node3D) -> void:
	courtyard = owner_court
	actor = courtyard.player
	sprite = courtyard.character_sprite
	camera = courtyard.camera
	hud = courtyard.courtyard_hud
	entrance = original_entrance
	# There is no disk save system. A scene reload during the walk safely
	# returns the player to the existing playable courtyard.
	if GameState.wang_estate_exit_stage == STAGE.DEPARTING:
		GameState.wang_estate_exit_stage = STAGE.WAITING
		GameState.start_night_clock()
	if GameState.has_hanging_coda_completed():
		GameState.begin_yuelan_trail_fade()
		GameState.preserve_final_evidence()
		_prepare_threshold()


func can_start() -> bool:
	return (
		not busy and GameState.can_leave_wang_estate() and is_instance_valid(actor)
		and actor.global_position.z >= START_Z and absf(actor.global_position.x) <= 1.45
	)


func start() -> void:
	if not can_start() or not GameState.try_begin_wang_estate_departure():
		return
	busy = true
	GameState.preserve_final_evidence()
	elapsed = 0.0
	start_position = actor.global_position
	actor.velocity = Vector3.ZERO
	hud.set_process_input(false)
	hud.set_door_prompt_visible(false, true)
	hud.set_story_caption("", false, true, 40)
	hud.top_status.hide()
	hud.quick_slots.hide()
	hud.objective_group.hide()
	courtyard.thunder_timer.stop()
	if courtyard.thunder_tween != null:
		courtyard.thunder_tween.kill()
	courtyard.audio_thunder.stop()
	courtyard.thunder_flash.color.a = 0.0
	rain_db = courtyard.audio_bgm.volume_db
	if leaves.is_empty():
		_prepare_threshold()
	titles = TITLES.new()
	add_child(titles)
	titles.return_requested.connect(_return_to_menu)
	hinge = AudioStreamPlayer3D.new()
	hinge.position = Vector3(0.0, 1.35, THRESHOLD_Z)
	hinge.unit_size = 5.0
	hinge.max_distance = 18.0
	hinge.volume_db = -16.0
	hinge.stream = door_sound
	add_child(hinge)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -12.5
	add_child(voice)


func advance(delta: float) -> void:
	if cards_started:
		return
	var previous := elapsed
	elapsed = minf(LAST_SHOT, elapsed + delta / timing_scale)
	var t := elapsed
	if t >= 0.50:
		_update_walk(t, delta)
		_update_shot(t)
	if _crossed(previous, 4.95) and hinge.stream != null:
		hinge.play()
	_set_gate_open(smoothstep(4.95, 7.25, t))
	if _crossed(previous, 13.0):
		_caption("王家的故事……", 1.85, reflection_voice)
	if _crossed(previous, 14.9):
		hud.set_story_caption("", false, true, 40)
	if _crossed(previous, 15.9):
		_caption("该有人知道了。", 2.15, last_words_voice)
	if _crossed(previous, 18.1):
		hud.set_story_caption("", false, true, 40)
	var opening_dissolve := smoothstep(0.0, 0.50, t) * (1.0 - smoothstep(0.50, 1.33, t))
	var reverse_dissolve := smoothstep(9.12, 9.54, t) * (1.0 - smoothstep(9.54, 10.18, t))
	var final_fade := smoothstep(20.1, LAST_SHOT, t)
	titles.set_black(maxf(opening_dissolve, maxf(reverse_dissolve, final_fade)))
	courtyard.audio_bgm.volume_db = lerpf(rain_db, -54.0, final_fade)
	if t >= LAST_SHOT:
		_finish_walk()


func _crossed(previous: float, cue: float) -> bool:
	return previous < cue and elapsed >= cue


func _update_walk(t: float, delta: float) -> void:
	var previous := actor.position
	var approach := clampf((t - 1.35) / 3.75, 0.0, 1.0)
	var cross := clampf((t - 7.0) / 2.4, 0.0, 1.0)
	var outside := clampf((t - 9.75) / 2.14, 0.0, 1.0)
	var z := lerpf(start_position.z, 12.58, approach) + cross * 2.73 + outside * 1.12
	actor.position = Vector3(lerpf(start_position.x, 0.03, smoothstep(0.0, 0.63, approach)), 0.02, z)
	var speed := absf(z - previous.z) / maxf(delta / timing_scale, 0.001)
	actor.velocity = Vector3(0.0, 0.0, speed)
	var pose := "back"
	if t >= 9.54:
		pose = "front" if t < 12.10 else ("left" if t < 12.58 else "back")
	var animation := ("walk_" if speed > 0.12 else "idle_") + pose
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
	sprite.speed_scale = clampf(speed / 1.25, 0.72, 1.15) if speed > 0.12 else 1.0
	courtyard.facing = "front" if t < 12.58 else "back"
	courtyard.call("_update_flashlight_pose")
	# Keep the flashlight naturally aimed low; do not light the exit like a reveal.
	courtyard.flashlight.light_energy = lerpf(5.2, 2.65, smoothstep(7.0, 12.1, t))
	courtyard.call("_update_character_grounding", delta, speed)
	courtyard.rain.global_position = Vector3(0.0, 7.0, z)


func _update_shot(t: float) -> void:
	if t < 9.54:
		var advance_t := smoothstep(1.25, 8.92, t)
		camera.global_position = Vector3(1.28, 2.35, 4.15).lerp(Vector3(1.03, 2.52, 9.87), advance_t)
		camera.look_at(Vector3(0.0, 1.37, lerpf(11.65, 14.75, advance_t)))
	else:
		var pullback := smoothstep(10.0, 20.8, t)
		camera.global_position = Vector3(1.45, 2.12, 18.92).lerp(Vector3(2.16, 3.27, 22.18), pullback)
		camera.look_at(Vector3(0.0, lerpf(1.33, 1.82, pullback), 13.63))


func _caption(line: String, duration: float, clip: AudioStream) -> void:
	hud.set_story_caption(line, true, true, 40, duration * timing_scale * 0.9)
	if clip != null:
		voice.stream = clip
		voice.play()


func _finish_walk() -> void:
	cards_started = true
	actor.velocity = Vector3.ZERO
	hinge.stop()
	voice.stop()
	for player in courtyard.footstep_players:
		player.stop()
	courtyard.audio_bgm.stop()
	for layer in courtyard.rain.get_children():
		if layer is GPUParticles3D:
			layer.emitting = false
	courtyard.rain.hide()
	# Nothing behind the black cards needs another realtime reflection render.
	if is_instance_valid(courtyard.reflection_probe):
		courtyard.reflection_probe.queue_free()
	GameState.stop_night_clock()
	GameState.wang_estate_exit_stage = STAGE.COMPLETE
	GameState.clear_checkpoint()
	titles.play_cards(timing_scale)


func _return_to_menu() -> void:
	courtyard.call_deferred("_change_scene", MENU_PATH)


func _set_gate_open(amount: float) -> void:
	for i in leaves.size():
		leaves[i].rotation_degrees.y = (-1.0 if i == 0 else 1.0) * (80.0 if i == 0 else 73.0) * amount


func _prepare_threshold() -> void:
	# The original entrance is a pair of posts and lintel. Its leaves and
	# dressed threshold exist only for this return, outside the normal bounds.
	var wood := preload("res://materials/architecture/wet_old_wood.tres") as ShaderMaterial
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.14, 0.086, 0.054)
	trim.roughness = 0.89
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.081, 0.068, 0.052)
	iron.roughness = 0.81
	iron.metallic = 0.24
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "DepartureLeafLeft" if side < 0.0 else "DepartureLeafRight"
		pivot.position = Vector3(float(side) * 2.13, 0.0, THRESHOLD_Z)
		entrance.add_child(pivot)
		leaves.append(pivot)
		for i in 6:
			var board_x := -float(side) * (0.18 + float(i) * 0.351)
			_box(pivot, Vector3(0.347, 3.70, 0.15), Vector3(board_x, 1.91, 0.0), wood)
		for height in [0.48, 1.84, 3.40]:
			_box(pivot, Vector3(2.09, 0.14, 0.085), Vector3(-float(side) * 1.05, float(height), -0.09), trim)
			_box(pivot, Vector3(0.28, 0.090, 0.04), Vector3(-float(side) * 0.23, float(height), -0.15), iron)
		_box(pivot, Vector3(0.13, 3.70, 0.08), Vector3(-float(side) * 2.025, 1.91, -0.083), trim)
		_box(pivot, Vector3(0.09, 0.18, 0.065), Vector3(-float(side) * 1.84, 1.62, -0.107), iron)
	# Render-only apron continues the courtyard stone through the existing frame.
	# Its edge is beyond the final camera; no terrain collision or clamp changes.
	var stone := preload("res://materials/ground/courtyard_stone_wet.tres").duplicate() as ShaderMaterial
	stone.set_shader_parameter("tile_repeat", Vector2(3.6, 3.33))
	var paving := PlaneMesh.new()
	paving.size = Vector2(14.8, 13.0)
	paving.subdivide_width = 30
	paving.subdivide_depth = 28
	paving.material = stone
	var apron := MeshInstance3D.new()
	apron.name = "ExistingEntranceThresholdDressing"
	apron.mesh = paving
	apron.position = Vector3(0.0, 0.012, 17.0)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entrance.add_child(apron)
	_dress_entrance_eaves(wood, trim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 2.65, 15.72)
	fill.light_color = Color(0.54, 0.65, 0.78)
	fill.light_energy = 0.64
	fill.omni_range = 8.0
	entrance.add_child(fill)


func _dress_entrance_eaves(wood: Material, trim: Material) -> void:
	var plaster := preload("res://materials/architecture/peeling_plaster.tres").duplicate() as ShaderMaterial
	plaster.set_shader_parameter("uv_repeat", Vector2(1.2, 1.0))
	plaster.set_shader_parameter("material_tint", Color(0.53, 0.49, 0.43))
	var tile := preload("res://materials/architecture/wet_gray_roof_tile.tres") as Material
	for side in [-1.0, 1.0]:
		_box(entrance, Vector3(3.54, 3.45, 0.38), Vector3(float(side) * 4.27, 1.73, THRESHOLD_Z), plaster)
		_box(entrance, Vector3(3.68, 0.18, 0.53), Vector3(float(side) * 4.29, 3.47, THRESHOLD_Z), wood)
		_box(entrance, Vector3(0.34, 0.29, 0.44), Vector3(float(side) * 2.18, 3.80, THRESHOLD_Z), trim)
		_box(entrance, Vector3(5.72, 0.18, 1.40), Vector3(0.0, 4.35, THRESHOLD_Z + float(side) * 0.60), wood)
		for i in 19:
			var x := -2.69 + float(i) * 0.30
			var rib: MeshInstance3D = courtyard.call("_add_cylinder", entrance, "DepartureEaveTile", 0.091, 1.55, Vector3(x, 4.51, THRESHOLD_Z + float(side) * 0.63), tile)
			rib.rotation.x = float(side) * deg_to_rad(105.0)
		courtyard.call("_add_unified_old_lantern", entrance, "LowEntranceLantern", Vector3(float(side) * 2.63, 3.03, THRESHOLD_Z + 0.46), 0.48, 3.4, true)
	_box(entrance, Vector3(5.97, 0.16, 0.29), Vector3(0.0, 4.79, THRESHOLD_Z), tile)


func _box(parent: Node3D, dimensions: Vector3, center: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	piece.mesh = box
	piece.material_override = material
	piece.position = center
	parent.add_child(piece)
