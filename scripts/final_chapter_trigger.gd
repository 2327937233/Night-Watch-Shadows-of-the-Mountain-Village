extends Node3D

signal sequence_finished
signal mirror_warning_finished

const FINAL_OBJECTIVE := GameState.APPROACH_HALL_OBJECTIVE
const RECORDED_FOOTSTEPS_PATH := "res://assets/audio/public_effects/corridor_footsteps.wav"
const RECORDED_FOOTSTEPS_FALLBACK_DURATION := 13.29
const RECORDED_FOOTSTEPS_START_OFFSET := 1.40
const FOOTSTEP_POINTS := [
	Vector3(-0.72, 0.08, 14.60),
	Vector3(-0.55, 0.08, 13.20),
	Vector3(-0.36, 0.08, 11.95),
	Vector3(-0.18, 0.08, 10.75),
	Vector3(-0.06, 0.08, 9.55),
	Vector3(0.02, 0.08, 8.34),
]
const FOOTSTEP_DELAYS := [1.28, 1.08, 0.94, 0.88, 0.96, 0.0]

var room: Node3D
var state: Node
var hud: Control
var rain_audio: AudioStreamPlayer
var room_tone: AudioStreamPlayer
var extinguish_audio: AudioStreamPlayer3D
var objective_audio: AudioStreamPlayer
var footstep_players: Array[AudioStreamPlayer3D] = []
var recorded_footsteps: AudioStreamPlayer3D
var recorded_footstep_motion: Tween
var smoke_emitters: Array[GPUParticles3D] = []
var timing_scale := 1.0
var running := false
var played_footsteps := 0
var cancelled_for_night_failure := false
var story_delay: Tween


func setup(owner_room: Node3D) -> void:
	room = owner_room
	state = get_node("/root/GameState")
	GameState.night_time_expired.connect(_cancel_for_night_failure)
	hud = room.get("hud") as Control
	rain_audio = room.get("rain_audio") as AudioStreamPlayer
	_build_room_tone()
	_build_extinguish_audio()
	_build_objective_audio()
	_build_footsteps()
	_build_extinguish_smoke()
	if bool(state.get("final_chapter_started")) or bool(state.get("bedroom_mirror_warning_played")):
		_apply_resolved_room_state()


func play_mirror_warning() -> void:
	if cancelled_for_night_failure:
		return
	if running or bool(state.get("bedroom_mirror_warning_played")):
		room.call_deferred("_on_mirror_warning_finished")
		return
	running = true
	state.set("bedroom_mirror_warning_played", true)
	room.set("final_sequence_running", true)
	room.set("narration_active", true)
	room.set("room_busy", true)
	var room_player := room.get("player") as CharacterBody3D
	if room_player != null:
		room_player.velocity = Vector3.ZERO
	# Let the turned mirror settle before the room answers it.
	await _wait(0.38)
	await _fade_out_rain()
	_silence_room()
	await _wait(0.26)
	await _blackout_candles()
	room.set("room_busy", false)
	# The supplied heel recording starts as soon as the warm candlelight dies.
	await _wait(0.12)
	await _play_approaching_footsteps(false, true)
	await _wait(1.05)
	room.set("final_sequence_running", false)
	room.set("narration_active", false)
	running = false
	mirror_warning_finished.emit()
	room.call_deferred("_on_mirror_warning_finished")


func begin() -> void:
	if cancelled_for_night_failure or running or bool(state.get("final_chapter_started")):
		return
	running = true
	state.set("bedroom_identity_confirmed", true)
	state.set("final_chapter_started", true)
	# The former doorway stinger must not interrupt the final chapter sequence.
	state.set("bedroom_exit_event_done", true)
	room.set("final_sequence_running", true)
	room.set("narration_active", true)
	room.set("room_busy", true)
	await _wait(0.75)
	# Scripted chapter beats supersede protected investigation captions.
	hud.call("set_story_caption", "沈月兰……", true, true, 20)
	await _wait(0.75)
	room.set("room_busy", false)
	await _wait(1.10)
	hud.call("set_story_caption", "", false, true, 20)
	await _wait(0.55)
	if not bool(state.get("bedroom_mirror_warning_played")):
		await _fade_out_rain()
		_silence_room()
		await _wait(0.34)
		await _blackout_candles()
		await _wait(0.12)
		await _play_approaching_footsteps(true, true)
		await _wait(1.10)
	else:
		# The mirror turn already extinguished the candles.  The supplied heel
		# recording still belongs after the complete name is spoken, so play it
		# here without replaying the blackout animation.
		_silence_room()
		await _wait(0.12)
		await _play_approaching_footsteps(true, false)
		await _wait(0.65)
	state.set("final_chapter_objective_revealed", true)
	room.call("_update_objective")
	objective_audio.play()
	await _wait(0.72)
	hud.call("set_story_caption", "她在信里提到过祠堂……", true, true, 20)
	await _wait(1.55)
	hud.call("set_story_caption", "答案应该在那里。", true, true, 20)
	await _wait(1.55)
	hud.call("set_story_caption", "", false, true, 20)
	state.set("final_chapter_sequence_complete", true)
	GameState.save_checkpoint("hall")
	room.set("final_sequence_running", false)
	room.set("narration_active", false)
	running = false
	sequence_finished.emit()


func _wait(seconds: float) -> void:
	story_delay = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	story_delay.tween_interval(maxf(0.01, seconds * timing_scale))
	await story_delay.finished


func _cancel_for_night_failure() -> void:
	cancelled_for_night_failure = true
	if story_delay != null and story_delay.is_valid():
		story_delay.kill()
	if recorded_footstep_motion != null and recorded_footstep_motion.is_valid():
		recorded_footstep_motion.kill()
	for audio in get_children():
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.stop()
	if is_instance_valid(rain_audio):
		rain_audio.stop()
	_silence_room()
	process_mode = Node.PROCESS_MODE_DISABLED


func _fade_out_rain() -> void:
	if rain_audio == null:
		return
	var tween := create_tween()
	tween.tween_property(rain_audio, "volume_db", -80.0, maxf(0.01, 0.56 * timing_scale)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	rain_audio.stop()
	room_tone.play()


func _silence_room() -> void:
	for property_name in ["floor_audio", "rustle_audio", "drawer_audio"]:
		var player := room.get(property_name) as AudioStreamPlayer3D
		if player != null:
			player.stop()
	room.set("next_wood_creak_at", INF)


func _blackout_candles() -> void:
	var flames: Array = room.get("candle_flames") as Array
	var nervous := create_tween().set_parallel(true)
	for flame_variant in flames:
		var flame := flame_variant as MeshInstance3D
		if flame != null:
			nervous.tween_property(flame, "scale", Vector3(1.18, 0.72, 1.0), maxf(0.01, 0.08 * timing_scale))
	await nervous.finished
	extinguish_audio.play()
	var collapse := create_tween().set_parallel(true)
	collapse.tween_property(room, "final_candle_factor", 0.0, maxf(0.01, 0.20 * timing_scale)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for flame_variant in flames:
		var flame := flame_variant as MeshInstance3D
		if flame != null:
			collapse.tween_property(flame, "scale", Vector3(0.08, 0.02, 0.08), maxf(0.01, 0.16 * timing_scale)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await collapse.finished
	for flame_variant in flames:
		var flame := flame_variant as MeshInstance3D
		if flame != null:
			flame.visible = false
	for smoke in smoke_emitters:
		smoke.restart()
		smoke.emitting = true


func _play_approaching_footsteps(use_recorded_clip := true, count_as_first_sequence := true) -> void:
	if use_recorded_clip and recorded_footsteps != null and recorded_footsteps.stream != null:
		recorded_footsteps.position = FOOTSTEP_POINTS[0]
		recorded_footsteps.pitch_scale = 1.0
		# The source has roughly 1.46 seconds of opening silence.  Seek just
		# before the first heel so it becomes audible immediately after blackout.
		recorded_footsteps.play(RECORDED_FOOTSTEPS_START_OFFSET)
		if count_as_first_sequence:
			played_footsteps += FOOTSTEP_POINTS.size()
		var clip_duration := recorded_footsteps.stream.get_length() - RECORDED_FOOTSTEPS_START_OFFSET
		if clip_duration <= 0.0:
			clip_duration = RECORDED_FOOTSTEPS_FALLBACK_DURATION
		if recorded_footstep_motion != null and recorded_footstep_motion.is_valid():
			recorded_footstep_motion.kill()
		recorded_footstep_motion = create_tween()
		var travel_duration := maxf(0.01, clip_duration * timing_scale)
		var segment_duration := travel_duration / float(FOOTSTEP_POINTS.size() - 1)
		for index in range(1, FOOTSTEP_POINTS.size()):
			recorded_footstep_motion.tween_property(recorded_footsteps, "position", FOOTSTEP_POINTS[index], segment_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Let one corridor lamp react around the middle of the approach while the
		# recording continues uninterrupted.
		await _wait(clip_duration * 0.42)
		_flicker_corridor_light()
		await _wait(clip_duration * 0.58)
		# Automated scene checks accelerate the event clock; do not leave the
		# full-length sample playing after those shortened checks finish.
		if timing_scale < 0.50 and recorded_footsteps.playing:
			recorded_footsteps.stop()
		return

	# Safe fallback for projects where the imported recording is temporarily
	# unavailable.  These six spatial anchors preserve the original event.
	for index in range(footstep_players.size()):
		var step := footstep_players[index]
		step.pitch_scale = 1.02 + float(index % 3) * 0.025
		step.play()
		if count_as_first_sequence:
			played_footsteps += 1
		if index == 2:
			_flicker_corridor_light()
		if index < FOOTSTEP_DELAYS.size() and FOOTSTEP_DELAYS[index] > 0.0:
			await _wait(FOOTSTEP_DELAYS[index])


func _flicker_corridor_light() -> void:
	var corridor_light := room.get("final_corridor_light") as OmniLight3D
	if corridor_light == null:
		return
	var original := corridor_light.light_energy
	var tween := create_tween()
	tween.tween_property(corridor_light, "light_energy", original * 0.22, maxf(0.01, 0.09 * timing_scale))
	tween.tween_property(corridor_light, "light_energy", original * 0.68, maxf(0.01, 0.11 * timing_scale))
	tween.tween_property(corridor_light, "light_energy", 0.0, maxf(0.01, 0.18 * timing_scale))


func _apply_resolved_room_state() -> void:
	room.set("final_candle_factor", 0.0)
	for light_variant in room.get("candle_lights") as Array:
		var light := light_variant as OmniLight3D
		if light != null:
			light.light_energy = 0.0
	for flame_variant in room.get("candle_flames") as Array:
		var flame := flame_variant as MeshInstance3D
		if flame != null:
			flame.visible = false
	if rain_audio != null:
		rain_audio.volume_db = -80.0
		rain_audio.stop()
	room_tone.play()


func _build_room_tone() -> void:
	room_tone = AudioStreamPlayer.new()
	room_tone.name = "FinalChapterBarelyAudibleRoomTone"
	room_tone.stream = _make_room_tone_stream()
	room_tone.volume_db = -47.0
	add_child(room_tone)


func _build_extinguish_audio() -> void:
	extinguish_audio = AudioStreamPlayer3D.new()
	extinguish_audio.name = "RestrainedCandleExtinguish"
	extinguish_audio.position = Vector3(2.7, 1.25, -4.85)
	extinguish_audio.stream = _make_extinguish_stream()
	extinguish_audio.volume_db = -17.5
	extinguish_audio.unit_size = 2.5
	extinguish_audio.max_distance = 15.0
	add_child(extinguish_audio)


func _build_objective_audio() -> void:
	objective_audio = AudioStreamPlayer.new()
	objective_audio.name = "QuietFinalObjectiveCue"
	objective_audio.stream = load("res://assets/audio/menu_confirm.ogg") as AudioStream
	objective_audio.volume_db = -25.0
	add_child(objective_audio)


func _build_footsteps() -> void:
	var wet_step := load("res://assets/audio/footstep_wet.ogg") as AudioStream
	for index in range(FOOTSTEP_POINTS.size()):
		var player := AudioStreamPlayer3D.new()
		player.name = "WomanSoftSoleFootstepPoint%02d" % (index + 1)
		player.position = FOOTSTEP_POINTS[index]
		player.stream = wet_step if wet_step != null else _make_soft_footstep_stream(7817 + index * 193, 74.0 + index * 2.1)
		# Still restrained, but high enough to remain audible above the user's
		# system noise floor and Godot's 3D distance attenuation.
		player.volume_db = lerpf(-18.5, -9.5, float(index) / float(FOOTSTEP_POINTS.size() - 1))
		player.unit_size = 3.2
		player.max_distance = 30.0
		player.attenuation_filter_cutoff_hz = 2650.0
		add_child(player)
		footstep_players.append(player)

	var recorded_stream := load(RECORDED_FOOTSTEPS_PATH) as AudioStream
	if recorded_stream == null:
		return
	recorded_footsteps = AudioStreamPlayer3D.new()
	recorded_footsteps.name = "RecordedWomanHeelsApproachingFromCorridor"
	recorded_footsteps.position = FOOTSTEP_POINTS[0]
	recorded_footsteps.stream = recorded_stream
	recorded_footsteps.volume_db = -7.5
	recorded_footsteps.unit_size = 4.2
	recorded_footsteps.max_distance = 36.0
	recorded_footsteps.attenuation_filter_cutoff_hz = 3600.0
	add_child(recorded_footsteps)


func _build_extinguish_smoke() -> void:
	for flame_variant in room.get("candle_flames") as Array:
		var flame := flame_variant as MeshInstance3D
		if flame == null:
			continue
		var smoke := GPUParticles3D.new()
		smoke.name = "ThinExtinguishedWickSmoke"
		smoke.position = flame.global_position + Vector3(0.0, 0.015, 0.0)
		smoke.amount = 8
		smoke.lifetime = 3.0
		smoke.one_shot = true
		smoke.explosiveness = 0.74
		smoke.randomness = 0.34
		smoke.visibility_aabb = AABB(Vector3(-0.35, -0.1, -0.35), Vector3(0.70, 2.2, 0.70))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.10, 1.0, 0.04)
		process.spread = 8.0
		process.initial_velocity_min = 0.09
		process.initial_velocity_max = 0.15
		process.gravity = Vector3(0.015, 0.02, 0.0)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.14, 0.58, 1.0])
		gradient.colors = PackedColorArray([Color(0.68, 0.70, 0.73, 0.0), Color(0.68, 0.70, 0.73, 0.22), Color(0.48, 0.51, 0.55, 0.12), Color(0.35, 0.38, 0.42, 0.0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		process.color_ramp = ramp
		smoke.process_material = process
		var quad := QuadMesh.new()
		quad.size = Vector2(0.065, 0.20)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(0.58, 0.61, 0.65, 0.13)
		quad.material = material
		smoke.draw_pass_1 = quad
		smoke.emitting = false
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(smoke)
		smoke_emitters.append(smoke)


func _make_soft_footstep_stream(seed_value: int, base_pitch: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := 7000
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var softened_noise := 0.0
	for i in range(sample_count):
		var t := float(i) / 22050.0
		softened_noise = lerpf(softened_noise, random.randf_range(-1.0, 1.0), 0.085)
		var sole := sin(TAU * base_pitch * t) * exp(-t * 25.0) * 0.18
		var damp := softened_noise * exp(-t * 18.0) * 0.15
		var board := sin(TAU * (142.0 + base_pitch * 0.20) * t) * exp(-absf(t - 0.075) * 38.0) * 0.035
		var sample := clampf(sole + damp + board, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = bytes
	return stream


func _make_extinguish_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := 9000
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 92317
	var filtered := 0.0
	for i in range(sample_count):
		var t := float(i) / 22050.0
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.16)
		var puff := filtered * exp(-t * 12.0) * 0.12
		var wick := sin(TAU * 178.0 * t) * exp(-t * 28.0) * 0.035
		bytes.encode_s16(i * 2, int(clampf(puff + wick, -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream


func _make_room_tone_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var sample_count := 44100
	stream.loop_begin = 0
	stream.loop_end = sample_count
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 51309
	var filtered := 0.0
	for i in range(sample_count):
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.003)
		var t := float(i) / 22050.0
		var sample := filtered * 0.010 + sin(TAU * 38.0 * t) * 0.003
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream
