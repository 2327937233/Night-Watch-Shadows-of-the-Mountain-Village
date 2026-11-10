extends Node
class_name MainHallFinalInvestigation

## Owns the staged investigation at the existing ancestor altar.  The room
## supplies visuals and the shared HUD/audio; this node keeps the story state
## out of the player movement script.

const TARGET_TABLET_LEFT := "final_tablet_left"
const TARGET_TABLET_WANG := "final_tablet_wang_chengan"
const TARGET_TABLET_RIGHT := "final_tablet_right"
const TARGET_EMPTY_SPOT := "final_tablet_empty_spot"
const TARGET_ALTAR_SEAM := "final_altar_seam"
const TARGET_OPEN_COMPARTMENT := "final_open_altar_compartment"
const TARGET_CONFESSION := "final_wang_chengan_confession"
const TARGET_BURNED_LETTER := "final_burned_letter"
const TARGET_LOCK_PLATE := "final_west_wing_lock_plate"
const TARGET_HAIRPIN_FRAGMENT := "final_other_half_hairpin_fragment"
const TARGET_ROPE_SEGMENT := "final_old_hemp_rope_segment"
const TARGET_YUELAN_FOOTPRINTS := "final_yuelan_wet_footprints"

const ALTAR_APPROACH_Z := -11.38
const TABLET_LEFT_X := -1.24
const TABLET_WANG_X := 0.62
const TABLET_RIGHT_X := 1.86
const EMPTY_SPOT_X := 1.24
const ALTAR_SEAM_X := 0.92
const TRUTH_CRY_AUDIO_PATH := "res://assets/audio/public_effects/hall_sob.wav"
const TRUTH_CRY_POSITION := Vector3(-4.85, 1.15, 5.85)
const PILLAR_ENCOUNTER_SCENE = preload("res://scenes/encounters/MainHallPillarEncounter.tscn")
const TRUTH_FOOTSTEP_POINTS := [
	Vector3(-0.72, 0.08, 11.25),
	Vector3(-0.48, 0.08, 9.55),
	Vector3(-0.24, 0.08, 8.05),
	Vector3(-0.04, 0.08, 6.72),
]
const TRUTH_FOOTSTEP_DELAYS := [1.20, 0.90, 1.05, 0.0]
const TRUTH_ROAM_POINTS := [
	Vector3(-2.85, 0.08, -7.25),
	Vector3(-4.35, 0.08, -3.80),
	Vector3(-4.70, 0.08, 0.65),
	Vector3(-2.10, 0.08, 4.75),
	Vector3(2.15, 0.08, 4.55),
	Vector3(4.65, 0.08, 0.35),
	Vector3(4.25, 0.08, -4.10),
	Vector3(2.55, 0.08, -7.45),
	Vector3(0.10, 0.08, -8.75),
]
const TRUTH_ROAM_DELAYS := [1.22, 1.34, 1.18, 1.42, 1.26, 1.36, 1.16, 1.30, 1.52]

var room: Node
var hud: Control
var state: Node
var rain_audio: AudioStreamPlayer
var empty_trace: Node3D
var seam_visual: Node3D
var secret_panel: Node3D
var secret_compartment: Node3D
var confession_visual: Node3D
var burned_letter_visual: Node3D
var lock_plate_visual: Node3D
var hairpin_fragment_visual: Node3D
var rope_segment_visual: Node3D
var creak_audio: AudioStreamPlayer3D
var panel_friction_audio: AudioStreamPlayer3D
var truth_extinguish_audio: AudioStreamPlayer3D
var truth_room_tone: AudioStreamPlayer
var truth_cry_audio: AudioStreamPlayer3D
var truth_cry_bus_name := ""
var truth_cry_running := false
var truth_cry_envelope: Tween
var truth_cry_play_count := 0
var pillar_encounter: Node3D
var truth_candle_flames: Array[MeshInstance3D] = []
var truth_candle_lights: Array[Light3D] = []
var truth_smoke_emitters: Array[GPUParticles3D] = []
var truth_footstep_players: Array[AudioStreamPlayer3D] = []
var truth_footsteps_played := 0
var truth_roaming_active := false
var truth_roaming_step_index := 0
var truth_sequence_runs := 0
var busy := false
var movement_locked := false:
	set(value):
		movement_locked = value
		if is_inside_tree():
			GameState.set_night_clock_hold(self, value)
var cancelled_for_night_failure := false


func setup(
	room_node: Node,
	hud_node: Control,
	state_node: Node,
	rain_player: AudioStreamPlayer,
	empty_trace_node: Node3D,
	seam_visual_node: Node3D,
	secret_panel_node: Node3D,
	secret_compartment_node: Node3D,
	confession_visual_node: Node3D,
	burned_letter_visual_node: Node3D,
	lock_plate_visual_node: Node3D,
	hairpin_fragment_visual_node: Node3D,
	rope_segment_visual_node: Node3D
) -> void:
	room = room_node
	hud = hud_node
	state = state_node
	rain_audio = rain_player
	empty_trace = empty_trace_node
	seam_visual = seam_visual_node
	secret_panel = secret_panel_node
	secret_compartment = secret_compartment_node
	confession_visual = confession_visual_node
	burned_letter_visual = burned_letter_visual_node
	lock_plate_visual = lock_plate_visual_node
	hairpin_fragment_visual = hairpin_fragment_visual_node
	rope_segment_visual = rope_segment_visual_node
	_build_quiet_creak()
	_build_panel_friction()
	_collect_truth_candles()
	_build_truth_smoke()
	_build_truth_audio()
	_build_truth_footsteps()
	_build_truth_cry()
	pillar_encounter = PILLAR_ENCOUNTER_SCENE.instantiate()
	pillar_encounter.name = "SoundGuidedLeftColumnEncounter"
	room.add_child(pillar_encounter)
	pillar_encounter.call("setup", room, self)
	if hud != null and hud.has_signal("document_closed") and not hud.is_connected("document_closed", _on_document_closed):
		hud.connect("document_closed", _on_document_closed)
	state.connect("night_time_expired", _cancel_for_night_failure)
	_sync_from_state()


func is_active() -> bool:
	# The main hall is the payoff for learning the erased woman's complete
	# identity.  Merely owning or reading the photograph must not expose the
	# tablets, the empty place, or the altar compartment.
	return state != null and bool(state.get("bedroom_identity_confirmed"))


func _sync_from_state() -> void:
	var active := is_active()
	if empty_trace != null:
		empty_trace.visible = active
	if seam_visual != null:
		seam_visual.visible = active \
			and bool(state.get("main_hall_empty_tablet_spot_examined")) \
			and not bool(state.get("main_hall_secret_compartment_opened"))
	var opened := active and bool(state.get("main_hall_secret_compartment_opened"))
	if secret_panel != null:
		secret_panel.position = Vector3(1.80, 1.37, -11.74) if opened else Vector3(0.96, 1.37, -11.905)
		secret_panel.rotation_degrees.y = 3.0 if opened else 0.0
	if secret_compartment != null:
		secret_compartment.visible = active
	if confession_visual != null:
		confession_visual.visible = not bool(state.call("has_item", "wang_chengan_confession"))
	if burned_letter_visual != null:
		burned_letter_visual.visible = not bool(state.call("has_item", "burned_yuelan_letter_scraps"))
	if lock_plate_visual != null:
		lock_plate_visual.visible = not bool(state.call("has_item", "west_wing_old_lock_plate"))
	if hairpin_fragment_visual != null:
		hairpin_fragment_visual.visible = not bool(state.call("has_item", "altar_silver_hairpin_fragment")) \
			and not bool(state.call("has_item", "complete_silver_hairpin"))
	if rope_segment_visual != null:
		rope_segment_visual.visible = bool(state.call("has_item", "wang_chengan_confession")) \
			and not bool(state.call("has_item", "old_hemp_rope_segment"))
	if not active:
		return
	if bool(state.get("main_hall_truth_revealed")):
		_apply_resolved_truth_state()
	state.set("main_hall_final_investigation_started", true)
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", state.estate_investigation_objective())


func interaction_target(player_position: Vector3) -> String:
	if cancelled_for_night_failure or not is_active() or busy or state.has_hanging_coda_completed():
		return ""
	if pillar_encounter != null:
		var aftermath := pillar_encounter.get("footprints") as Node
		if aftermath != null:
			var mark_target := str(aftermath.call("interaction_target", player_position))
			if not mark_target.is_empty():
				return mark_target
	if player_position.z > -10.76:
		return ""
	# Each step takes priority over the earlier optional tablets.  The anchors
	# sit along the altar front so the player never needs to clip into the dais.
	if bool(state.get("main_hall_empty_tablet_spot_examined")) and not bool(state.get("main_hall_altar_seam_examined")):
		return TARGET_ALTAR_SEAM if absf(player_position.x - ALTAR_SEAM_X) <= 0.62 else ""
	if bool(state.get("main_hall_altar_seam_examined")) and not bool(state.get("main_hall_secret_compartment_opened")):
		return TARGET_OPEN_COMPARTMENT if absf(player_position.x - ALTAR_SEAM_X) <= 0.64 else ""
	if bool(state.get("main_hall_secret_compartment_opened")):
		if player_position.x < 0.82 and player_position.x >= 0.30 and not bool(state.call("has_item", "burned_yuelan_letter_scraps")):
			return TARGET_BURNED_LETTER
		# The silver fragment sits in the small upper-right side niche.  It takes
		# priority over the lock plate below it, then the same standing position
		# naturally exposes the older evidence after the fragment is removed.
		if player_position.x > 1.10 and player_position.x <= 1.62 \
			and not bool(state.call("has_item", "altar_silver_hairpin_fragment")) \
			and not bool(state.call("has_item", "complete_silver_hairpin")):
			return TARGET_HAIRPIN_FRAGMENT
		if player_position.x > 1.10 and player_position.x <= 1.62 and not bool(state.call("has_item", "west_wing_old_lock_plate")):
			return TARGET_LOCK_PLATE
		if absf(player_position.x - ALTAR_SEAM_X) <= 0.36 and not bool(state.call("has_item", "wang_chengan_confession")):
			return TARGET_CONFESSION
		if absf(player_position.x - ALTAR_SEAM_X) <= 0.36 \
			and bool(state.call("has_item", "wang_chengan_confession")) \
			and not bool(state.call("has_item", "old_hemp_rope_segment")):
			return TARGET_ROPE_SEGMENT
		return ""
	if bool(state.get("main_hall_wang_chengan_examined")) and not bool(state.get("main_hall_empty_tablet_spot_examined")):
		return TARGET_EMPTY_SPOT if absf(player_position.x - EMPTY_SPOT_X) <= 0.58 else ""
	if absf(player_position.x - TABLET_WANG_X) <= 0.48:
		return TARGET_TABLET_WANG
	if absf(player_position.x - TABLET_LEFT_X) <= 0.50:
		return TARGET_TABLET_LEFT
	if absf(player_position.x - TABLET_RIGHT_X) <= 0.50:
		return TARGET_TABLET_RIGHT
	return ""


func prompt_for(target: String) -> String:
	match target:
		TARGET_YUELAN_FOOTPRINTS:
			return "调查潮湿脚印"
		TARGET_TABLET_LEFT, TARGET_TABLET_WANG, TARGET_TABLET_RIGHT:
			return "查看牌位"
		TARGET_EMPTY_SPOT:
			return "调查牌位空位"
		TARGET_ALTAR_SEAM:
			return "调查异常木缝"
		TARGET_OPEN_COMPARTMENT:
			return "拉开旧木板"
		TARGET_CONFESSION:
			return "查看供词"
		TARGET_BURNED_LETTER:
			return "查看烧残的旧信"
		TARGET_LOCK_PLATE:
			return "调查西厢旧锁扣"
		TARGET_HAIRPIN_FRAGMENT:
			return "拾取断簪残片"
		TARGET_ROPE_SEGMENT:
			return "调查旧麻绳"
		_:
			return ""


func handles(target: String) -> bool:
	return target in [
		TARGET_YUELAN_FOOTPRINTS,
		TARGET_TABLET_LEFT,
		TARGET_TABLET_WANG,
		TARGET_TABLET_RIGHT,
		TARGET_EMPTY_SPOT,
		TARGET_ALTAR_SEAM,
		TARGET_OPEN_COMPARTMENT,
		TARGET_CONFESSION,
		TARGET_BURNED_LETTER,
		TARGET_LOCK_PLATE,
		TARGET_HAIRPIN_FRAGMENT,
		TARGET_ROPE_SEGMENT,
	]


func interact(target: String) -> void:
	var room_player := room.get("player") as CharacterBody3D
	if room_player == null or busy or not handles(target) or target != interaction_target(room_player.global_position):
		return
	busy = true
	if hud != null and hud.has_method("set_door_prompt_visible"):
		hud.call("set_door_prompt_visible", false)
	match target:
		TARGET_YUELAN_FOOTPRINTS:
			var aftermath := pillar_encounter.get("footprints") as Node
			if aftermath != null:
				aftermath.call("inspect")
		TARGET_TABLET_LEFT:
			state.set("main_hall_ordinary_tablet_examined", true)
			_show_caption("王氏绍文一脉先祖之位。木牌上的金字已经黯淡。")
		TARGET_TABLET_RIGHT:
			state.set("main_hall_ordinary_tablet_examined", true)
			_show_caption("王氏德全一脉先祖之位。牌座上积着多年的香灰。")
		TARGET_TABLET_WANG:
			_inspect_wang_chengan()
		TARGET_EMPTY_SPOT:
			_inspect_empty_spot()
		TARGET_ALTAR_SEAM:
			_inspect_altar_seam()
		TARGET_OPEN_COMPARTMENT:
			_open_secret_compartment()
			return
		TARGET_CONFESSION:
			_take_confession()
		TARGET_BURNED_LETTER:
			_take_burned_letter()
		TARGET_LOCK_PLATE:
			_take_lock_plate()
		TARGET_HAIRPIN_FRAGMENT:
			_take_hairpin_fragment()
		TARGET_ROPE_SEGMENT:
			_inspect_rope_segment()
	busy = false


func _inspect_wang_chengan() -> void:
	state.set("main_hall_wang_chengan_examined", true)
	_show_caption("王承安在这里……\n\n可沈月兰呢？")
	_soften_hall_ambience()


func _inspect_empty_spot() -> void:
	state.set("main_hall_empty_tablet_spot_examined", true)
	_show_caption("灰尘留下了一个清晰的轮廓。\n\n这里原本放过东西。")
	if seam_visual != null:
		seam_visual.visible = true
	if creak_audio != null:
		creak_audio.play()


func _inspect_altar_seam() -> void:
	state.set("main_hall_altar_seam_examined", true)
	_show_caption("供台下方的木板没有完全合拢。\n\n边缘有反复移动留下的磨痕。\n\n这块木板……被打开过。")
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "调查供台下方")


func _open_secret_compartment() -> void:
	movement_locked = true
	var room_player := room.get("player") as CharacterBody3D
	if room_player != null:
		room_player.velocity = Vector3.ZERO
	if panel_friction_audio != null:
		panel_friction_audio.play()
	var tween := create_tween()
	# Pull the loose board outward and cant it at the same time, then slide it
	# aside.  Starting the parallel group before both properties keeps the
	# duration deterministic (0.28 + 0.64 seconds).
	tween.set_parallel(true)
	tween.tween_property(secret_panel, "position:z", -11.74, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(secret_panel, "rotation_degrees:y", 3.0, 0.28)
	tween.set_parallel(false)
	tween.tween_property(secret_panel, "position:x", 1.80, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish_open_secret_compartment, CONNECT_ONE_SHOT)


func _finish_open_secret_compartment() -> void:
	state.set("main_hall_secret_compartment_opened", true)
	if seam_visual != null:
		seam_visual.visible = false
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "查看暗格中的供词")
	_show_caption("木板后只有一掌多深。供词与几件旧物被人整齐地藏在里面。")
	movement_locked = false
	busy = false


func _take_confession() -> void:
	if bool(state.call("add_item", "wang_chengan_confession")):
		confession_visual.hide()
		if rope_segment_visual != null and not bool(state.call("has_item", "old_hemp_rope_segment")):
			rope_segment_visual.show()
		if hud != null and hud.has_method("open_document_item"):
			hud.call("open_document_item", "wang_chengan_confession")


func _take_burned_letter() -> void:
	if bool(state.call("add_item", "burned_yuelan_letter_scraps")):
		state.set("main_hall_burned_letter_examined", true)
		burned_letter_visual.hide()
		if hud != null and hud.has_method("set_story_caption"):
			_show_caption("焦黑纸片被人重新叠好。残存笔迹与月兰的信完全相同。")


func _take_lock_plate() -> void:
	if bool(state.call("add_item", "west_wing_old_lock_plate")):
		state.set("main_hall_lock_plate_examined", true)
		lock_plate_visual.hide()
		if hud != null and hud.has_method("set_story_caption"):
			_show_caption("锁扣内侧的磨痕朝外。西厢门确实曾从外面锁上。")


func _take_hairpin_fragment() -> void:
	var had_bedroom_fragment := bool(state.call("has_item", "broken_silver_hairpin"))
	if not bool(state.call("add_item", "altar_silver_hairpin_fragment")):
		return
	if hairpin_fragment_visual != null:
		hairpin_fragment_visual.hide()
	if hud == null or not hud.has_method("set_story_caption"):
		return
	if had_bedroom_fragment and bool(state.call("has_item", "complete_silver_hairpin")):
		_show_caption("两截银簪的断口完全吻合。")
	else:
		_show_caption("一截发黑的银簪残片。断口像是在等待另一半。")


func _inspect_rope_segment() -> void:
	if hud != null and hud.has_method("set_story_caption"):
		_show_caption("这截麻绳已经发黑受潮。\n\n材质、粗细和编织方式……\n与西厢房梁上的那条麻绳一致。")
	if bool(state.call("add_item", "old_hemp_rope_segment")):
		state.set("main_hall_rope_segment_examined", true)
		if rope_segment_visual != null:
			rope_segment_visual.hide()


func _on_document_closed(item_id: String) -> void:
	if cancelled_for_night_failure or item_id != "wang_chengan_confession" or bool(state.get("main_hall_confession_read")):
		return
	if not bool(state.call("has_completed_document", item_id)):
		return
	state.set("main_hall_confession_read", true)
	# Lock the interaction dispatcher immediately.  The half-second pause after
	# the paper closes remains visually free, but another item cannot start a
	# competing story coroutine during it.
	busy = true
	movement_locked = true
	var room_player := room.get("player") as CharacterBody3D
	if room_player != null:
		room_player.velocity = Vector3.ZERO
	call_deferred("_play_truth_revelation")


func _play_truth_revelation() -> void:
	if cancelled_for_night_failure:
		return
	if bool(state.get("main_hall_truth_revealed")):
		movement_locked = false
		busy = false
		return
	busy = true
	movement_locked = true
	truth_sequence_runs += 1
	# Let the physical paper disappear and the player's eye return to the altar
	# before the room answers what was just read.
	# When reread from the bag, wait for gameplay to resume before this pause
	# elapses, so the blackout cannot happen behind an open inventory.
	await get_tree().create_timer(0.50, false).timeout
	if cancelled_for_night_failure:
		return
	_fade_truth_ambience()
	await _blackout_truth_candles()
	# The blackout lands at roughly 0.4 s.  Hold the hall near-silent until the
	# first step appears at about the two-second mark.
	await get_tree().create_timer(1.58, false).timeout
	if cancelled_for_night_failure:
		return
	await _play_truth_footsteps()
	if cancelled_for_night_failure:
		return
	await get_tree().create_timer(1.0, false).timeout
	if cancelled_for_night_failure:
		return
	state.set("main_hall_truth_revealed", true)
	if hud != null:
		if hud.has_method("set_objective"):
			hud.call("set_objective", "王氏旧事的真相已经揭开")
		if hud.has_method("set_story_caption"):
			hud.call("set_story_caption", "沈月兰并非自缢。王家制造了她的死亡，也抹去了她存在过的痕迹。", true, true, 20, 4.5)
	movement_locked = false
	busy = false
	# Let the player look for the source while the room is cold and quiet.
	# The encounter owns one opening cry, then waits for flashlight discovery.
	pillar_encounter.call("arm")


func _fade_truth_ambience() -> void:
	if rain_audio != null:
		var rain_fade := create_tween()
		# Keep a barely audible bed rather than producing digital silence.  The
		# subdued rain persists after the event so the hall genuinely feels colder.
		rain_fade.tween_property(rain_audio, "volume_db", -48.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if truth_room_tone != null and not truth_room_tone.playing:
		truth_room_tone.play()


func _blackout_truth_candles() -> void:
	# One small, shared shiver reads as an abnormal draught without becoming a
	# flash or a jump scare.
	var shiver := create_tween().set_parallel(true)
	for flame in truth_candle_flames:
		if is_instance_valid(flame) and flame.visible:
			shiver.tween_property(flame, "scale", Vector3(1.16, 0.72, 1.0), 0.09)
	await shiver.finished
	if truth_extinguish_audio != null:
		truth_extinguish_audio.play()
	var collapse := create_tween().set_parallel(true)
	for flame in truth_candle_flames:
		if is_instance_valid(flame) and flame.visible:
			collapse.tween_property(flame, "scale", Vector3(0.06, 0.02, 0.06), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for light in truth_candle_lights:
		if is_instance_valid(light):
			collapse.tween_property(light, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await collapse.finished
	# The inherited room process continuously animates the candle-light energy.
	# Stop that visual-only process once the story permanently extinguishes them;
	# physics, flashlight and camera controls continue normally.
	room.set_process(false)
	var base_energies: Array = room.get("candle_energy") as Array
	for index in range(base_energies.size()):
		base_energies[index] = 0.0
	for flame in truth_candle_flames:
		if is_instance_valid(flame):
			flame.visible = false
	for light in truth_candle_lights:
		if is_instance_valid(light):
			light.light_energy = 0.0
	for smoke in truth_smoke_emitters:
		if is_instance_valid(smoke):
			smoke.restart()
			smoke.emitting = true


func _play_truth_footsteps() -> void:
	for index in range(truth_footstep_players.size()):
		if cancelled_for_night_failure:
			return
		var step := truth_footstep_players[index]
		if not is_instance_valid(step):
			continue
		step.pitch_scale = 0.91 + float(index) * 0.018
		step.play()
		truth_footsteps_played += 1
		if index < TRUTH_FOOTSTEP_DELAYS.size() and TRUTH_FOOTSTEP_DELAYS[index] > 0.0:
			await get_tree().create_timer(TRUTH_FOOTSTEP_DELAYS[index], false).timeout


func _start_truth_roaming() -> void:
	if cancelled_for_night_failure or state.has_hanging_coda_completed():
		return
	if truth_roaming_active or truth_cry_running or truth_footstep_players.is_empty():
		return
	if bool(state.get("yuelan_trail_room_reached")):
		return
	if pillar_encounter != null and bool(pillar_encounter.get("armed")):
		return
	truth_roaming_active = true
	call_deferred("_run_truth_roaming")


func _run_truth_roaming() -> void:
	# After the four-step approach, the unseen walker keeps circling through the
	# nave and both side aisles.  The path never crosses into the altar itself,
	# so it sounds like someone pacing the hall rather than standing on the player.
	while truth_roaming_active and is_inside_tree():
		var route_index := truth_roaming_step_index % TRUTH_ROAM_POINTS.size()
		var voice_index := truth_roaming_step_index % truth_footstep_players.size()
		var step := truth_footstep_players[voice_index]
		if is_instance_valid(step):
			step.position = TRUTH_ROAM_POINTS[route_index]
			step.volume_db = -2.5 + sin(float(route_index) * 1.37) * 0.9
			step.pitch_scale = 0.88 + float(route_index % 4) * 0.018
			step.play()
			truth_footsteps_played += 1
		truth_roaming_step_index += 1
		var delay: float = float(TRUTH_ROAM_DELAYS[route_index])
		await get_tree().create_timer(delay, false).timeout


func _collect_truth_candles() -> void:
	truth_candle_flames.clear()
	truth_candle_lights.clear()
	for node in room.find_children("SmallCandleFlame", "MeshInstance3D", true, false):
		var flame := node as MeshInstance3D
		if flame != null:
			truth_candle_flames.append(flame)
	for node in room.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light == null:
			continue
		var light_name := String(light.name)
		if light_name.begins_with("UnstableCandleLight_") \
			or light_name == "ShrineLowWarmBounce" \
			or light_name == "WeakRoomCandleLeak":
			truth_candle_lights.append(light)


func _build_truth_smoke() -> void:
	for flame in truth_candle_flames:
		var smoke := GPUParticles3D.new()
		smoke.name = "MainHallExtinguishedWickSmoke"
		room.add_child(smoke)
		smoke.global_position = flame.global_position + Vector3(0.0, 0.015, 0.0)
		smoke.amount = 6
		smoke.lifetime = 2.65
		smoke.one_shot = true
		smoke.explosiveness = 0.72
		smoke.randomness = 0.30
		smoke.visibility_aabb = AABB(Vector3(-0.30, -0.1, -0.30), Vector3(0.60, 1.8, 0.60))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.07, 1.0, 0.03)
		process.spread = 7.0
		process.initial_velocity_min = 0.075
		process.initial_velocity_max = 0.125
		process.gravity = Vector3(0.009, 0.018, 0.0)
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.16, 0.62, 1.0])
		fade.colors = PackedColorArray([Color(0.65, 0.68, 0.72, 0.0), Color(0.65, 0.68, 0.72, 0.18), Color(0.44, 0.48, 0.53, 0.10), Color(0.35, 0.38, 0.42, 0.0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		process.color_ramp = ramp
		smoke.process_material = process
		var quad := QuadMesh.new()
		quad.size = Vector2(0.055, 0.18)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(0.56, 0.59, 0.63, 0.12)
		quad.material = material
		smoke.draw_pass_1 = quad
		smoke.emitting = false
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		truth_smoke_emitters.append(smoke)


func _build_truth_audio() -> void:
	truth_extinguish_audio = AudioStreamPlayer3D.new()
	truth_extinguish_audio.name = "MainHallRestrainedCandleExtinguish"
	truth_extinguish_audio.position = Vector3(0.0, 2.05, -11.85)
	truth_extinguish_audio.stream = _make_truth_extinguish_stream()
	truth_extinguish_audio.volume_db = -17.0
	truth_extinguish_audio.unit_size = 3.0
	truth_extinguish_audio.max_distance = 22.0
	room.add_child(truth_extinguish_audio)
	truth_room_tone = AudioStreamPlayer.new()
	truth_room_tone.name = "MainHallBarelyAudibleTruthRoomTone"
	truth_room_tone.stream = _make_truth_room_tone_stream()
	truth_room_tone.volume_db = -48.0
	room.add_child(truth_room_tone)


func _build_truth_footsteps() -> void:
	for index in range(TRUTH_FOOTSTEP_POINTS.size()):
		var step := AudioStreamPlayer3D.new()
		step.name = "MainHallWomanSoftSoleStep%02d" % (index + 1)
		step.position = TRUTH_FOOTSTEP_POINTS[index]
		# Use single, existing stone-contact samples rather than the imported heel
		# recording.  A low cutoff and slightly lowered pitch remove the modern hard
		# click and leave a damp cloth-shoe impact with a short masonry reflection.
		var sample_index: int = int([2, 5, 3, 6][index])
		var soft_step := load("res://assets/audio/footstep_stone_%02d.wav" % sample_index) as AudioStream
		step.stream = soft_step if soft_step != null else _make_truth_soft_step_stream(9137 + index * 277)
		# The player is commonly still beside the altar, more than twenty metres
		# from the first courtyard anchor.  These values keep the distant first hit
		# quiet but audible and make the final hit unmistakably close.
		step.volume_db = lerpf(-10.0, -2.0, float(index) / float(TRUTH_FOOTSTEP_POINTS.size() - 1))
		step.unit_size = 9.0
		step.max_distance = 60.0
		step.attenuation_filter_cutoff_hz = 2200.0
		room.add_child(step)
		truth_footstep_players.append(step)


func _build_truth_cry() -> void:
	var stream := load(TRUTH_CRY_AUDIO_PATH) as AudioStream
	if stream == null:
		push_warning("Main hall crying audio is unavailable: " + TRUTH_CRY_AUDIO_PATH)
		return
	# A dedicated effect bus colours this one recording only.  It leaves player
	# steps, rain and the shared Master bus untouched and is removed on room exit.
	truth_cry_bus_name = "MainHallDistantCry_%d" % get_instance_id()
	var bus_index := AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, truth_cry_bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = 3200.0
	AudioServer.add_bus_effect(bus_index, low_pass)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.55
	reverb.damping = 0.72
	reverb.predelay_msec = 32.0
	reverb.dry = 0.88
	reverb.wet = 0.16
	AudioServer.add_bus_effect(bus_index, reverb)
	truth_cry_audio = AudioStreamPlayer3D.new()
	truth_cry_audio.name = "WomanQuietCryBeyondHallSideGallery"
	truth_cry_audio.position = TRUTH_CRY_POSITION
	truth_cry_audio.stream = stream
	truth_cry_audio.bus = truth_cry_bus_name
	truth_cry_audio.volume_db = -60.0
	truth_cry_audio.pitch_scale = 0.97
	truth_cry_audio.unit_size = 12.0
	truth_cry_audio.max_distance = 55.0
	truth_cry_audio.attenuation_filter_cutoff_hz = 3200.0
	room.add_child(truth_cry_audio)


func _play_truth_cry(repeat_for_search := false) -> void:
	if cancelled_for_night_failure or truth_cry_running or (truth_cry_play_count > 0 and not repeat_for_search) or not is_instance_valid(truth_cry_audio):
		return
	truth_cry_running = true
	truth_cry_play_count += 1
	truth_cry_audio.volume_db = -60.0
	truth_cry_audio.play()
	var duration := truth_cry_audio.stream.get_length() / truth_cry_audio.pitch_scale
	truth_cry_envelope = create_tween()
	truth_cry_envelope.tween_property(truth_cry_audio, "volume_db", -6.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	truth_cry_envelope.tween_interval(maxf(0.0, duration - 2.05))
	truth_cry_envelope.tween_property(truth_cry_audio, "volume_db", -60.0, 1.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Proximity may interrupt the cry. Poll playback rather than awaiting a
	# killed tween, which would strand the parent story coroutine permanently.
	while truth_cry_running and truth_cry_audio.playing:
		await get_tree().create_timer(0.08, false).timeout
	if cancelled_for_night_failure:
		return
	if truth_cry_envelope != null and truth_cry_envelope.is_valid():
		truth_cry_envelope.kill()
	truth_cry_audio.stop()
	await get_tree().create_timer(0.65, false).timeout
	truth_cry_running = false


func stop_truth_cry_at_source() -> void:
	if truth_cry_envelope != null and truth_cry_envelope.is_valid():
		truth_cry_envelope.kill()
	if is_instance_valid(truth_cry_audio):
		truth_cry_audio.stop()
	truth_cry_running = false


func _cancel_for_night_failure() -> void:
	cancelled_for_night_failure = true
	truth_roaming_active = false
	stop_truth_cry_at_source()
	for step in truth_footstep_players:
		if is_instance_valid(step):
			step.stop()
	for player in [creak_audio, panel_friction_audio, truth_extinguish_audio, truth_room_tone]:
		if is_instance_valid(player):
			player.stop()
	if is_instance_valid(pillar_encounter):
		pillar_encounter.call("cancel_for_night_failure")
	var cry_bus := AudioServer.get_bus_index(truth_cry_bus_name)
	if cry_bus > 0:
		AudioServer.set_bus_mute(cry_bus, true)
	# Bound tweens must stay frozen even when the failure menu releases the tree.
	process_mode = Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	truth_roaming_active = false
	if is_instance_valid(truth_cry_audio):
		truth_cry_audio.stop()
	if not truth_cry_bus_name.is_empty():
		var bus_index := AudioServer.get_bus_index(truth_cry_bus_name)
		if bus_index > 0:
			AudioServer.remove_bus(bus_index)


func _apply_resolved_truth_state() -> void:
	room.set_process(false)
	var base_energies: Array = room.get("candle_energy") as Array
	for index in range(base_energies.size()):
		base_energies[index] = 0.0
	for flame in truth_candle_flames:
		if is_instance_valid(flame):
			flame.visible = false
	for light in truth_candle_lights:
		if is_instance_valid(light):
			light.light_energy = 0.0
	if rain_audio != null:
		rain_audio.volume_db = -24.0 if state.hanging_door_stage == GameState.HangingDoorStage.COMPLETE else -48.0
	if state.has_hanging_coda_completed():
		truth_roaming_active = false
		stop_truth_cry_at_source()
		for voice in truth_footstep_players:
			voice.stop()
		if truth_room_tone != null:
			truth_room_tone.stop()
		if rain_audio != null:
			rain_audio.volume_db = -22.0
		return
	if truth_room_tone != null and not truth_room_tone.playing:
		truth_room_tone.play()
	if pillar_encounter != null and not bool(state.get("main_hall_pillar_figure_seen")):
		pillar_encounter.call("arm")
	_start_truth_roaming()


func consider_last_look(player_position: Vector3) -> void:
	if (
		state.wang_estate_last_look_seen or not state.has_hanging_coda_completed()
		or not bool(state.get("main_hall_empty_tablet_spot_examined"))
		or player_position.z > -8.85 or absf(player_position.x) > 3.45
	):
		return
	state.wang_estate_last_look_seen = true
	hud.call("set_story_caption", "他们连一个名字都不肯留给你……", true, true, 24, 2.35)
	var lines := create_tween()
	lines.tween_interval(2.4)
	lines.tween_callback(func() -> void: hud.call("set_story_caption", "", false, true, 24))
	lines.tween_interval(1.0)
	lines.tween_callback(func() -> void: hud.call("set_story_caption", "可我会记得。", true, true, 24, 2.0))
	lines.tween_interval(2.2)
	lines.tween_callback(func() -> void: hud.call("set_story_caption", "", false, true, 24))


func _show_caption(text: String) -> void:
	if hud != null and hud.has_method("set_story_caption"):
		var minimum_seconds := clampf(float(text.length()) * 0.11, 4.0, 7.0)
		hud.call("set_story_caption", text, true, true, 10, minimum_seconds)


func _soften_hall_ambience() -> void:
	if rain_audio == null:
		return
	var target_db := rain_audio.volume_db - 1.35
	var tween := create_tween()
	tween.tween_property(rain_audio, "volume_db", target_db, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_quiet_creak() -> void:
	creak_audio = AudioStreamPlayer3D.new()
	creak_audio.name = "AltarSecretPanelQuietCreak"
	creak_audio.position = Vector3(ALTAR_SEAM_X, 1.05, -11.96)
	creak_audio.volume_db = -21.0
	creak_audio.unit_size = 2.0
	creak_audio.max_distance = 10.0
	creak_audio.stream = _make_quiet_wood_creak()
	room.add_child(creak_audio)


func _build_panel_friction() -> void:
	panel_friction_audio = AudioStreamPlayer3D.new()
	panel_friction_audio.name = "AltarPanelLowWoodFriction"
	panel_friction_audio.position = Vector3(ALTAR_SEAM_X, 1.34, -11.95)
	panel_friction_audio.volume_db = -17.5
	panel_friction_audio.unit_size = 2.0
	panel_friction_audio.max_distance = 9.0
	panel_friction_audio.stream = _make_panel_friction_stream()
	room.add_child(panel_friction_audio)


func _make_quiet_wood_creak() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := int(22050.0 * 0.62)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 16027
	for index in range(sample_count):
		var t := float(index) / 22050.0
		var envelope := sin(PI * clampf(t / 0.62, 0.0, 1.0)) * exp(-t * 1.8)
		var bend := 86.0 - t * 31.0 + sin(t * 19.0) * 4.0
		var tone := sin(TAU * bend * t) * 0.16
		tone += sin(TAU * (bend * 2.03) * t) * 0.045
		tone += noise.randf_range(-1.0, 1.0) * 0.025
		data.encode_s16(index * 2, int(clampf(tone * envelope, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream


func _make_panel_friction_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := int(22050.0 * 1.08)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 43117
	var smoothed_noise := 0.0
	for index in range(sample_count):
		var t := float(index) / 22050.0
		var attack := minf(t / 0.10, 1.0)
		var release := clampf((1.08 - t) / 0.22, 0.0, 1.0)
		var envelope := attack * release * (0.72 + sin(t * 17.0) * 0.12)
		smoothed_noise = lerpf(smoothed_noise, noise.randf_range(-1.0, 1.0), 0.035)
		var low_rub := sin(TAU * (52.0 + sin(t * 6.0) * 5.0) * t) * 0.13
		var grain := smoothed_noise * 0.22 + noise.randf_range(-1.0, 1.0) * 0.018
		var value := (low_rub + grain) * envelope
		data.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream


func _make_truth_extinguish_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := int(22050.0 * 0.42)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 68123
	var smooth := 0.0
	for index in range(sample_count):
		var t := float(index) / 22050.0
		var envelope := exp(-t * 12.0) * minf(t / 0.018, 1.0)
		smooth = lerpf(smooth, noise.randf_range(-1.0, 1.0), 0.12)
		var breath := smooth * 0.24 + sin(TAU * 91.0 * t) * 0.035
		data.encode_s16(index * 2, int(clampf(breath * envelope, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream


func _make_truth_room_tone_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var sample_count := 22050 * 2
	stream.loop_end = sample_count
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 44071
	var smooth := 0.0
	for index in range(sample_count):
		var t := float(index) / 22050.0
		smooth = lerpf(smooth, noise.randf_range(-1.0, 1.0), 0.006)
		var value := smooth * 0.035 + sin(TAU * 41.0 * t) * 0.006
		data.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream


func _make_truth_soft_step_stream(seed_value: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := int(22050.0 * 0.34)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = seed_value
	var smooth := 0.0
	for index in range(sample_count):
		var t := float(index) / 22050.0
		var attack := minf(t / 0.014, 1.0)
		var envelope := attack * exp(-t * 13.5)
		smooth = lerpf(smooth, noise.randf_range(-1.0, 1.0), 0.055)
		var sole := sin(TAU * (73.0 - t * 18.0) * t) * 0.17
		var damp_grain := smooth * 0.22 + noise.randf_range(-1.0, 1.0) * 0.015
		data.encode_s16(index * 2, int(clampf((sole + damp_grain) * envelope, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream
