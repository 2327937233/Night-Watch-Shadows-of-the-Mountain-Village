extends Node
## Footprint arrival and post-latch reconstruction in the existing room.
## The door sequence and the original first-visit clues are separate.

signal phase_changed(phase_name: String)

const Truth = preload("res://scripts/game_state.gd").HangingTruthStage
const Door = preload("res://scripts/game_state.gd").HangingDoorStage
const CONFESSION_ID := "wang_chengan_confession"
const ROPE := "final_beam_rope"
const STOOL := "final_old_stool"
const LEAVE_TRUTH := "final_confession_place"
const VOICES = {
	"arrival_door": preload("res://assets/audio/hanging_truth/arrival_door.wav"),
	"arrival_rope": preload("res://assets/audio/hanging_truth/arrival_rope.wav"),
	"rope_match": preload("res://assets/audio/hanging_truth/rope_match.wav"),
	"rope_prepared": preload("res://assets/audio/hanging_truth/rope_prepared.wav"),
	"stool_moved": preload("res://assets/audio/hanging_truth/stool_moved.wav"),
	"stool_scene": preload("res://assets/audio/hanging_truth/stool_scene.wav"),
	"summary_latch": preload("res://assets/audio/hanging_truth/summary_latch.wav"),
	"summary_rope": preload("res://assets/audio/hanging_truth/summary_rope.wav"),
	"summary_stool": preload("res://assets/audio/hanging_truth/summary_stool.wav"),
	"summary_knew": preload("res://assets/audio/hanging_truth/summary_knew.wav"),
	"summary_blame": preload("res://assets/audio/hanging_truth/summary_blame.wav"),
	"response_name": preload("res://assets/audio/hanging_truth/response_name.wav"),
	"response_truth": preload("res://assets/audio/hanging_truth/response_truth.wav"),
}
const STOOL_WEAR := preload("res://shaders/hanging_stool_wear.gdshader")

@export_range(1.0, 2.0, 0.1) var entry_silence := 1.6
@export_range(1.0, 4.0, 0.1) var line_duration := 2.7
@export_range(2.0, 3.0, 0.1) var sob_duration := 2.56
@export_range(0.5, 3.0, 0.1) var rope_settle_duration := 1.7
@export var beam_sob_stream: AudioStream = preload("res://assets/audio/public_effects/beam_sob.wav")
@export var stool_displacement := Vector3(0.10, 0.0, -0.06)

var room: Node3D
var state: Node
var hud: Control
var rope: Node3D
var stool: Node3D
var rain: AudioStreamPlayer
var beam_sob: AudioStreamPlayer3D
var voice: AudioStreamPlayer
var beat_timer: Timer
var active := false
var busy := false
var phase := "inactive"
var sway_strength := 1.0
var sway_clock := 0.0
var ambience_tween: Tween
var settle_tween: Tween
var beats: Array[Dictionary] = []
var next_beat := 0
var sequence_completed: Callable
var checkpoint_beats := false
var timing_scale := 1.0
var creak_delay := 28.0
var glance_up := false
var confession_spot := Vector3.ZERO


func setup(owner_room: Node3D, story_state: Node) -> void:
	room = owner_room
	state = story_state
	active = bool(state.get("main_hall_yuelan_footprints_available")) and bool(state.get("yuelan_trail_room_reached"))
	set_process(active)
	if not active:
		return
	hud = room.get("hud") as Control
	rope = room.get("rope_visual") as Node3D
	stool = room.find_child("KickedOldStool", true, false) as Node3D
	rain = room.get("rain_audio") as AudioStreamPlayer
	beat_timer = Timer.new()
	beat_timer.name = "InvestigationBeat"
	beat_timer.one_shot = true
	add_child(beat_timer)
	beat_timer.timeout.connect(_finish_beat)
	_apply_return_environment()
	hud.call("set_objective", "调查吊绳房的异常")
	# Captions from the original arrival must not compete with this visit.
	hud.call("set_story_caption", "", false, true)
	if not bool(state.get("hanging_return_entry_complete")) and int(state.get("hanging_door_stage")) < Door.PLAYING:
		_set_busy(true)
		call_deferred("_run_entry")
	else:
		_fade_ambience(-24.0, 0.0)
		_set_phase("investigating")


func begin_truth_if_ready() -> void:
	# Called after the original door controller has restored its scene state.
	if not truth_is_active():
		return
	_dress_stool()
	if truth_stage() >= Truth.RESPONSE:
		_stop_rope()
		_fade_ambience(-32.0 if truth_stage() == Truth.READY else -45.0, 0.0)
	if truth_stage() == Truth.INVESTIGATING and _both_examined():
		_set_truth_stage(Truth.REVIEW)
	_resume_truth()


func truth_is_active() -> bool:
	return active and state.get("hanging_door_stage") == Door.COMPLETE


func truth_stage() -> int:
	return int(state.get("hanging_truth_stage"))


func _dress_stool() -> void:
	if stool == null:
		return
	var seat := stool.get_node_or_null("WornSeat") as MeshInstance3D
	if seat != null:
		var dust := ShaderMaterial.new()
		dust.shader = STOOL_WEAR
		seat.material_overlay = dust
	var wear := ShaderMaterial.new()
	wear.shader = STOOL_WEAR
	wear.set_shader_parameter("worn_leg", true)
	for child in stool.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and is_equal_approx(child.mesh.size.y, 0.62):
			child.material_overlay = wear
	# The point is off to the left of the existing stool, clear of its
	# collision and a full step to the side of the rope's floor projection.
	confession_spot = Vector3(stool.position.x - 1.10, 0.02, stool.position.z - 0.22)


func _apply_return_environment() -> void:
	# Disable the parent's energy cache as well as the lights. Its normal
	# flicker loop otherwise relights extinguished candles on the next frame.
	var energies: Array = room.get("candle_energy")
	for i in energies.size():
		energies[i] = 0.0
	for light in room.get("candle_lights"):
		(light as Light3D).light_energy = 0.0
	# Repeated procedural children can acquire @MeshInstance3D names, so
	# identify flames by their existing shader, not a name-prefix search.
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		var material := (mesh as MeshInstance3D).get_active_material(0) as ShaderMaterial
		if material != null and material.shader == preload("res://shaders/ritual_candle_flame.gdshader"):
			(mesh as Node3D).hide()
	for ember in room.get("incense_embers"):
		(ember as Node3D).hide()
	var smoke := room.get("incense_smoke") as GPUParticles3D
	if smoke != null:
		smoke.emitting = false
		smoke.hide()
	# Remove the old warm noose spotlight, retaining the existing cold fills
	# and the player's normal flashlight rather than flattening the room light.
	var warm_focus := room.find_child("RestrainedNooseFocus", true, false) as Light3D
	if warm_focus != null:
		warm_focus.light_energy = 0.0
	var trail := room.get("wet_footprint_route") as Node
	var floor_mat := trail.get("floor_material") as ShaderMaterial if trail != null else null
	if stool != null:
		# Move the original parent, including its existing seat collision. Never
		# accumulate another offset when re-entering the scene.
		var drag_lines := PackedVector4Array()
		for foot in [Vector3(-0.25, 0.0, -0.14), Vector3(0.25, 0.0, -0.14), Vector3(-0.25, 0.0, 0.14), Vector3(0.25, 0.0, 0.14)]:
			var start := stool.to_global(foot)
			var finish := start + stool_displacement
			drag_lines.append(Vector4(start.x, start.z, finish.x, finish.z))
		stool.position += stool_displacement
		if floor_mat != null:
			floor_mat.set_shader_parameter("hanging_stool_drag_lines", drag_lines)
			floor_mat.set_shader_parameter("hanging_stool_drag_active", true)
	room.set("room_reaction", 0.0)


func _build_beam_sob() -> void:
	beam_sob = AudioStreamPlayer3D.new()
	beam_sob.name = "LastSuppressedSobAtBeam"
	beam_sob.stream = beam_sob_stream
	beam_sob.volume_db = -21.0
	beam_sob.max_db = -11.0
	beam_sob.unit_size = 4.5
	beam_sob.max_distance = 20.0
	beam_sob.attenuation_filter_cutoff_hz = 2200.0
	add_child(beam_sob)
	beam_sob.global_position = rope.global_position + Vector3(0, -0.49, 0)


func _process(delta: float) -> void:
	if not active or rope == null or state.hanging_coda_stage != GameState.HangingCodaStage.WAITING:
		return
	sway_clock += delta
	# The original rope pivot is still fixed at the roof beam.
	rope.rotation_degrees.z = (sin(sway_clock * 0.86) * 0.82 + sin(sway_clock * 0.37) * 0.18) * sway_strength
	rope.rotation_degrees.x = sin(sway_clock * 0.51) * 0.12 * sway_strength
	if truth_is_active() and truth_stage() == Truth.INVESTIGATING and not busy:
		creak_delay -= delta
		if creak_delay <= 0.0:
			creak_delay = randf_range(36.0, 52.0)
			var creak := room.get("beam_creak_audio") as AudioStreamPlayer3D
			if creak != null:
				creak.volume_db = -27.0
				creak.max_db = -15.0
				creak.play()


func interaction_target(player_position: Vector3) -> String:
	if not truth_is_active() or busy:
		return ""
	var p := Vector2(player_position.x, player_position.z)
	if truth_stage() == Truth.READY:
		return LEAVE_TRUTH if state.can_place_final_confession() and p.distance_to(Vector2(confession_spot.x, confession_spot.z)) < 0.53 else ""
	if truth_stage() != Truth.INVESTIGATING:
		return ""
	var rope_distance := p.distance_to(Vector2(rope.position.x, rope.position.z)) if rope != null else INF
	var stool_distance := p.distance_to(Vector2(stool.position.x, stool.position.z)) if stool != null else INF
	var can_rope := not bool(state.get("hanging_return_rope_examined")) and rope_distance < 1.50
	var can_stool := not bool(state.get("hanging_return_stool_examined")) and stool_distance < 1.15
	if can_stool and (not can_rope or stool_distance < rope_distance):
		return STOOL
	return ROPE if can_rope else ""


func prompt_for(target: String) -> String:
	match target:
		ROPE: return "检查房梁麻绳"
		STOOL: return "调查旧木凳"
		LEAVE_TRUTH: return "放下王承安的供词"
		_: return ""


func interact(target: String) -> void:
	var player := room.get("player") as Node3D
	if player == null or target.is_empty() or target != interaction_target(player.position):
		return
	if target == LEAVE_TRUTH:
		room.coda.start()
		return
	_set_busy(true)
	_set_phase("examining_" + target)
	call_deferred("_run_investigation", target)


func _run_entry() -> void:
	# Hall cries/footsteps belong to the old scene and stop on scene exit.
	# This room creates no continuing woman footsteps or doorway cry.
	_fade_ambience(-48.0, 0.15)
	_play_beats([
		{"phase": "entry_silence", "duration": entry_silence},
		{"phase": "entry_caption", "caption": "脚印到这里就没了……", "duration": line_duration},
		_line("她为什么一定要让我回来？"),
	], _entry_finished)


func _entry_finished() -> void:
	state.set("hanging_return_entry_complete", true)
	hud.call("set_objective", "调查吊绳房的异常")
	_fade_ambience(-24.0, 1.2)
	_set_phase("investigating")
	_set_busy(false)
	GameState.save_checkpoint("west_wing")


func _run_investigation(target: String) -> void:
	var lines: Array[Dictionary] = []
	if target == ROPE:
		lines.append(_line("麻绳已经发黑，纤维粗糙。"))
		lines.append(_line("绳结与固定位置上，留有陈旧的磨损痕迹。"))
		if bool(state.call("has_item", "old_hemp_rope_segment")):
			lines.append(_line("这条麻绳的粗细与编织方式，和正堂暗格中的残段一致。", 3.8))
			lines.append(_spoken("正堂里竟然还藏着同样的麻绳……", "rope_match", 2.9))
			lines.append({"duration": 1.0})
		if _confession_was_read():
			lines.append(_spoken("王承安的供词里说，绳子是他们提前准备的。", "rope_prepared", 3.6))
	elif target == STOOL:
		lines.append(_line("木凳腿部布满磨损。"))
		lines.append(_line("地上留下了一道陈旧的拖动痕迹。"))
		lines.append(_line("它曾经被人移动过。", 2.0))
		lines.append(_spoken("凳子也被人动过……", "stool_moved", 2.0))
		lines.append(_spoken("这里的现场，可能早就被他们布置过。", "stool_scene", 3.0))
	_play_beats(lines, _investigation_finished.bind(target))


func _investigation_finished(target: String) -> void:
	state.set("hanging_return_rope_examined" if target == ROPE else "hanging_return_stool_examined", true)
	if _both_examined():
		_set_truth_stage(Truth.REVIEW)
		_resume_truth()
	else:
		_set_phase("investigating")
		_set_busy(false)


func _resume_truth() -> void:
	match truth_stage():
		Truth.ARRIVAL:
			_set_busy(true)
			_set_phase("truth_arrival")
			_play_beats([
				_spoken("门是从外面锁上的……", "arrival_door", 2.4),
				_spoken("那这条绳子，又是谁准备的？", "arrival_rope", 2.7),
			], _truth_arrived, true)
		Truth.REVIEW: _review_evidence()
		Truth.SOB: _queue_beam_sob()
		Truth.RESPONSE: _respond_to_sob(false)
		Truth.READY: _set_phase("complete")


func _truth_arrived() -> void:
	_set_truth_stage(Truth.INVESTIGATING)
	_set_phase("investigating")
	_set_busy(false)


func _confession_was_read() -> bool:
	return state.has_completed_document(CONFESSION_ID) or bool(state.get("main_hall_confession_read"))


func _review_evidence() -> void:
	_set_busy(true)
	_set_phase("evidence_review")
	var lines: Array[Dictionary] = []
	if _confession_was_read():
		var definition: Dictionary = state.get_item_definition(CONFESSION_ID)
		var document: String = definition.get("document_text", "")
		for sentence in document.split("\n", false):
			if sentence.begins_with("那夜，") or sentence.begins_with("西厢的门") or sentence.begins_with("第二日，"):
				lines.append(_line("“" + sentence + "”", 3.2 if sentence.length() > 17 else 2.6))
		lines.append({"duration": 0.55})
	lines.append_array([
		_spoken("外面的门闩……", "summary_latch", 1.55),
		_spoken("提前备好的绳子……", "summary_rope", 1.8),
		_spoken("还有这张被挪动过的凳子。", "summary_stool", 2.4),
		{"duration": 1.0},
		_spoken("他们早就知道这里会发生什么。", "summary_knew", 2.7),
		_spoken("却把一切都推给了沈月兰。", "summary_blame", 2.5),
	])
	_play_beats(lines, _review_finished, true)


func _review_finished() -> void:
	_set_truth_stage(Truth.SOB)
	_queue_beam_sob()


func _queue_beam_sob() -> void:
	_set_busy(true)
	var creak := room.get("beam_creak_audio") as AudioStreamPlayer3D
	if creak != null:
		creak.stop()
	_fade_ambience(-45.0, _seconds(1.1))
	_play_beats([{"phase": "final_quiet", "duration": 1.15}], _play_last_sob)


func _play_last_sob() -> void:
	_build_beam_sob()
	# Persist before playback: leaving during the cry resumes with Chen Mo's
	# response, without emitting the one-time sound a second time.
	_set_truth_stage(Truth.RESPONSE)
	beam_sob.play()
	_play_beats([{"phase": "beam_sob", "duration": sob_duration}], _respond_to_sob.bind(true))


func _respond_to_sob(settle: bool) -> void:
	_set_busy(true)
	var lines: Array[Dictionary] = [
		{"phase": "rope_settling", "duration": rope_settle_duration, "action": "_settle_rope"},
		{"phase": "last_caption", "duration": 1.7, "caption": "沈月兰……", "clip": "response_name", "action": "_look_up"},
		{"duration": 1.0},
		_spoken("你让我回来，是想让我替你说出真相吗？", "response_truth", 3.5),
		{"phase": "last_silence", "duration": 2.0, "action": "_end_look"},
	]
	if not settle:
		_stop_rope()
	_play_beats(lines, _final_finished, true)


func _settle_rope() -> void:
	if beam_sob != null:
		beam_sob.stop()
	if sway_strength > 0.0:
		settle_tween = create_tween()
		settle_tween.tween_property(self, "sway_strength", 0.0, _seconds(rope_settle_duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stop_rope() -> void:
	sway_strength = 0.0
	rope.rotation = Vector3.ZERO


func _look_up() -> void:
	_stop_rope()
	glance_up = true


func _end_look() -> void:
	glance_up = false


func _final_finished() -> void:
	state.set("hanging_return_final_sob_complete", true)
	_set_truth_stage(Truth.READY)
	hud.set_objective(state.hanging_door_objective())
	_fade_ambience(-32.0, _seconds(1.3))
	_set_phase("complete")
	_set_busy(false)


func _both_examined() -> bool:
	return bool(state.get("hanging_return_rope_examined")) and bool(state.get("hanging_return_stool_examined"))


func _set_truth_stage(value: int) -> void:
	state.set("hanging_truth_stage", value)
	state.set("hanging_truth_resume_beat", 0)


func _play_beats(sequence: Array[Dictionary], completed: Callable, resume := false) -> void:
	beats = sequence
	checkpoint_beats = resume
	next_beat = clampi(int(state.get("hanging_truth_resume_beat")), 0, sequence.size()) if resume else 0
	sequence_completed = completed
	_advance_beat()


func _finish_beat() -> void:
	if checkpoint_beats:
		state.set("hanging_truth_resume_beat", next_beat)
	_advance_beat()


func _advance_beat() -> void:
	# One scene-owned timer, without suspended coroutine states. Exiting or
	# cancelling cannot leave a queued caption/audio callback in the next room.
	if voice != null:
		voice.stop()
	if next_beat >= beats.size():
		hud.set_story_caption("", false, true, 20)
		var completed := sequence_completed
		sequence_completed = Callable()
		beats.clear()
		if completed.is_valid():
			completed.call()
		return
	var beat := beats[next_beat]
	next_beat += 1
	var text: String = beat.get("caption", "")
	hud.set_story_caption(text, not text.is_empty(), true, 20)
	if beat.has("action"):
		call(str(beat["action"]))
	var duration: float = beat["duration"]
	var clip := VOICES.get(beat.get("clip", "")) as AudioStream
	if clip != null:
		if voice == null:
			voice = AudioStreamPlayer.new()
			voice.name = "ChenMoReconstructionVoice"
			voice.volume_db = -14.5
			add_child(voice)
		voice.stream = clip
		voice.play()
		duration = maxf(duration, clip.get_length() + 0.08)
	if beat.has("phase"):
		_set_phase(str(beat["phase"]))
	beat_timer.start(_seconds(duration))


func _line(text: String, duration := -1.0) -> Dictionary:
	return {"caption": text, "duration": line_duration if duration < 0.0 else duration}


func _spoken(text: String, clip: String, duration: float) -> Dictionary:
	return {"caption": text, "clip": clip, "duration": duration}


func _seconds(duration: float) -> float:
	return maxf(0.01, duration * timing_scale)


func _set_busy(value: bool) -> void:
	busy = value
	# During reconstruction the usual inventory pauses the room and its timer.
	# E remains routed through the room, and ESC/flashlight/movement still work.
	hud.set_process_input(not value or truth_is_active())
	if value:
		hud.call("set_door_prompt_visible", false, true)
		room.set("hud_interaction_target", "")


func _set_phase(value: String) -> void:
	phase = value
	phase_changed.emit(value)


func _fade_ambience(volume: float, duration: float) -> void:
	if rain == null:
		return
	if ambience_tween != null:
		ambience_tween.kill()
	if duration <= 0.0:
		rain.volume_db = volume
	else:
		ambience_tween = create_tween()
		ambience_tween.tween_property(rain, "volume_db", volume, duration)


func _exit_tree() -> void:
	if is_instance_valid(beam_sob):
		beam_sob.stop()
	if is_instance_valid(voice):
		voice.stop()
	if is_instance_valid(beat_timer):
		beat_timer.stop()
	beats.clear()
	sequence_completed = Callable()
