extends Node3D
## Sound-guided, one-shot encounter at an existing left middle-hall column.
## No NPC physics or navigation. A replacement scene uses feet origin / +Z back.

@export var figure_scene: PackedScene
@export_range(5.0, 60.0, 0.5) var appearance_duration := 30.0
@export_range(1.0, 6.0, 0.1) var fade_duration := 2.5
const FIGURE_SCRIPT = preload("res://scripts/yuelan_back_figure.gd")
const FOOTPRINTS_SCRIPT = preload("res://scripts/yuelan_wet_footprints.gd")
const STANDING_POSITION := Vector3(-4.15, 0.02, -6.35)
# Move behind the stone foot of the column, rather than across its silhouette.
const HIDDEN_POSITION := Vector3(-3.45, 0.02, -6.63)
const SOUND_POSITION := STANDING_POSITION + Vector3(0.0, 1.08, 0.0)

var hall: Node3D
var controller: Node
var state: Node
var figure: Node3D
var footprints: Node3D
var rustle: AudioStreamPlayer3D
var figure_cry: AudioStreamPlayer3D
var figure_cry_envelope: Tween
var figure_cry_repeat_after := 0.0
var figure_cry_play_count := 0
var retreating := false
var armed := false
var located := false
var showing := false
var completed := false
var caption_active := false
var shown_seconds := 0.0
var guidance_finished := false
var hint_used := false
var cancelled_for_night_failure := false


func setup(owner_hall: Node3D, story_controller: Node) -> void:
	hall = owner_hall
	controller = story_controller
	state = get_node("/root/GameState")
	figure = figure_scene.instantiate() as Node3D if figure_scene != null else FIGURE_SCRIPT.new()
	figure.name = "YuelanReplaceableBackFigure"
	add_child(figure)
	figure.position = STANDING_POSITION
	if figure.has_method("apply_column_shading"):
		figure.call("apply_column_shading")
	figure.hide()
	# Reuse the recorded cry and hall effects bus, with a separate voice so
	# interrupting the approach cry cannot stop the flashlight response.
	var source := controller.get("truth_cry_audio") as AudioStreamPlayer3D
	if source != null:
		figure_cry = AudioStreamPlayer3D.new()
		figure_cry.name = "YuelanFlashlightResponseCry"
		figure_cry.stream = source.stream
		figure_cry.bus = source.bus
		figure_cry.pitch_scale = source.pitch_scale
		figure_cry.unit_size = 8.0
		figure_cry.max_distance = 24.0
		figure_cry.attenuation_filter_cutoff_hz = 3200.0
		figure_cry.position = Vector3(0.0, 1.10, 0.0)
		figure.add_child(figure_cry)
		figure_cry.finished.connect(func() -> void: figure_cry_repeat_after = 0.65)
	rustle = AudioStreamPlayer3D.new()
	rustle.name = "QuietOldClothRustleAtColumn"
	rustle.position = SOUND_POSITION
	rustle.stream = _cloth_stream()
	rustle.volume_db = -18.0
	rustle.unit_size = 5.0
	rustle.max_distance = 22.0
	add_child(rustle)
	completed = bool(state.get("main_hall_pillar_figure_seen"))
	guidance_finished = bool(state.get("main_hall_pillar_cry_finished"))
	footprints = FOOTPRINTS_SCRIPT.new()
	footprints.name = "YuelanWetFootprintInvestigation"
	add_child(footprints)
	footprints.call("setup", hall, state)
	# On a return to the hall the figure is already gone, including a scene
	# exit during the final fade. Restore the aftermath without replaying her.
	if completed:
		footprints.call("activate")


func arm() -> void:
	if cancelled_for_night_failure or completed or armed:
		return
	armed = true
	controller.set("truth_roaming_active", false)
	var cry := controller.get("truth_cry_audio") as AudioStreamPlayer3D
	if cry != null:
		cry.position = SOUND_POSITION
	var hud := hall.get("hud") as Control
	if hud != null:
		hud.call("set_objective", "寻找正堂中哭声的来源")
	if not guidance_finished:
		call_deferred("_play_guidance_once")


func _play_guidance_once() -> void:
	if cancelled_for_night_failure:
		return
	_hint_lantern_once()
	await controller.call("_play_truth_cry")
	if cancelled_for_night_failure:
		return
	guidance_finished = true
	state.set("main_hall_pillar_cry_finished", true)


func cancel_for_night_failure() -> void:
	cancelled_for_night_failure = true
	armed = false
	if figure_cry_envelope != null and figure_cry_envelope.is_valid():
		figure_cry_envelope.kill()
	if is_instance_valid(figure_cry):
		figure_cry.stop()
	if is_instance_valid(rustle):
		rustle.stop()
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if not armed or hall == null:
		return
	var player := hall.get("player") as CharacterBody3D
	if player == null or bool(controller.get("movement_locked")):
		return
	if not located:
		var distance := _flat_distance(player.global_position, STANDING_POSITION)
		if distance < 2.9:
			_locate_source()
		return
	# Finish the first sob naturally. Approaching or already pointing the
	# flashlight here cannot overlap it with the figure's second crying cue.
	if not guidance_finished or retreating:
		return
	if not showing:
		# Light/contact-of-view is the reveal gate. The previous 1.65 m lower
		# bound stranded players who approached in darkness before switching on.
		if _lit_and_visible():
			_reveal(player.global_position)
		return
	shown_seconds += delta
	_update_figure_cry(delta)
	if shown_seconds >= appearance_duration:
		_retreat()


func _locate_source() -> void:
	located = true
	state.set("main_hall_cry_source_located", true)
	for voice in controller.get("truth_footstep_players") as Array:
		(voice as AudioStreamPlayer3D).stop()
	rustle.play()
	caption_active = true
	var hud := hall.get("hud") as Control
	if hud != null:
		hud.call("set_story_caption", "声音……就在这里。", true, true, 20, 3.2)
	get_tree().create_timer(3.0, false).timeout.connect(func() -> void: caption_active = false)


func _lit_and_visible() -> bool:
	var flashlight := hall.get("flashlight") as SpotLight3D
	var camera := hall.get("camera") as Camera3D
	if flashlight == null or not flashlight.is_visible_in_tree() or flashlight.light_energy <= 0.0 or camera == null:
		return false
	# A shoulder can be illuminated while the column still masks the torso.
	# Require both the player's light and actual camera to reach that same point.
	for offset in [Vector3(-0.17, 1.22, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(-0.15, 0.42, 0.0)]:
		if _point_lit_and_visible(figure.global_position + offset, flashlight, camera):
			return true
	return false


func _point_lit_and_visible(target: Vector3, flashlight: SpotLight3D, camera: Camera3D) -> bool:
	var offset := target - flashlight.global_position
	if offset.length() > flashlight.spot_range or offset.normalized().dot(-flashlight.global_basis.z) < cos(deg_to_rad(flashlight.spot_angle * 0.86)):
		return false
	if camera.is_position_behind(target):
		return false
	var screen := camera.unproject_position(target)
	if not camera.get_viewport().get_visible_rect().has_point(screen):
		return false
	return _line_clear(flashlight.global_position, target) and _line_clear(camera.global_position, target)


func _line_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var player := hall.get("player") as CharacterBody3D
	query.exclude = [player.get_rid()]
	return hall.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _reveal(player_position: Vector3) -> void:
	showing = true
	var back := player_position - figure.global_position
	# Commit to the initial side-back pose; never turn her to track the player.
	figure.rotation.y = atan2(back.x, back.z) - 0.24
	var arrival := create_tween().set_parallel(true)
	for node in figure.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.transparency = 1.0
		arrival.tween_property(geometry, "transparency", 0.0, 0.48).set_trans(Tween.TRANS_SINE)
	figure.show()
	_play_figure_cry()


func _update_figure_cry(delta: float) -> void:
	if figure_cry == null:
		return
	# Discovery starts a single 30-second scene. Looking away does not reset
	# its timer or cut off the sob; each short recording has a soft breath gap.
	figure_cry_repeat_after -= delta
	if not figure_cry.playing and figure_cry_repeat_after <= 0.0:
		_play_figure_cry()


func _play_figure_cry() -> void:
	if figure_cry_envelope != null and figure_cry_envelope.is_valid():
		figure_cry_envelope.kill()
	figure_cry.volume_db = -60.0
	figure_cry.play()
	figure_cry_play_count += 1
	var duration := figure_cry.stream.get_length() / figure_cry.pitch_scale
	figure_cry_envelope = create_tween()
	figure_cry_envelope.tween_property(figure_cry, "volume_db", -8.0, 0.40)
	figure_cry_envelope.tween_interval(maxf(0.0, duration - 1.40))
	figure_cry_envelope.tween_property(figure_cry, "volume_db", -60.0, 1.0)


func _fade_figure_cry(duration: float) -> void:
	if figure_cry == null:
		return
	if figure_cry_envelope != null and figure_cry_envelope.is_valid():
		figure_cry_envelope.kill()
	figure_cry_envelope = create_tween()
	figure_cry_envelope.tween_property(figure_cry, "volume_db", -60.0, duration)
	figure_cry_envelope.tween_callback(figure_cry.stop)


func _retreat() -> void:
	# Hold her in the original position for 30 seconds, then let silhouette and
	# sound recede together. Close approach cannot shorten this scene.
	completed = true
	retreating = true
	state.set("main_hall_pillar_figure_seen", true)
	rustle.play()
	var can_pose := figure.has_method("pose_drift")
	if not can_pose and figure.has_method("begin_retreat"):
		figure.call("begin_retreat")
	_fade_figure_cry(fade_duration)
	var geometry := figure.find_children("*", "GeometryInstance3D", true, false)
	var local_travel := figure.basis.inverse() * (HIDDEN_POSITION - STANDING_POSITION)
	var retreat := create_tween()
	retreat.tween_method(func(t: float) -> void:
		figure.position = STANDING_POSITION.lerp(HIDDEN_POSITION, t)
		if can_pose:
			figure.call("pose_drift", t, local_travel, 2)
		var fade := smoothstep(0.23, 0.98, t)
		for node in geometry:
			(node as GeometryInstance3D).transparency = fade
	, 0.0, 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	retreat.tween_callback(_finish_retreat)


func _finish_retreat() -> void:
	figure.hide()
	armed = false
	showing = false
	retreating = false
	if figure_cry != null:
		figure_cry.stop()
	footprints.call("activate")
	controller.call("_start_truth_roaming")


func _hint_lantern_once() -> void:
	hint_used = true
	var nearest: OmniLight3D
	var best := INF
	for node in hall.find_children("RestrainedGalleryLanternLight", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		var distance := light.global_position.distance_to(SOUND_POSITION)
		if light.light_energy > 0.0 and distance < best:
			best = distance
			nearest = light
	if nearest == null:
		return
	var energy := nearest.light_energy
	var hint := create_tween()
	hint.tween_property(nearest, "light_energy", energy * 0.72, 0.13)
	hint.tween_property(nearest, "light_energy", energy, 0.23)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _cloth_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(12128 * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 21741
	var smooth := 0.0
	for i in range(12128):
		var t := float(i) / 22050.0
		smooth = lerpf(smooth, random.randf_range(-1.0, 1.0), 0.13)
		var envelope := sin(PI * t / 0.55) * (0.7 + sin(t * 37.0) * 0.2)
		data.encode_s16(i * 2, int(smooth * envelope * 0.35 * 32767.0))
	stream.data = data
	return stream
