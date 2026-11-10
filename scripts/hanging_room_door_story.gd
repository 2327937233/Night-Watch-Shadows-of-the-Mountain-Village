extends Node3D
## The inside and hallway are separate scenes. Only the investigation stage
## crosses that boundary; all playing sounds and timers belong to their scene.

const Stage = preload("res://scripts/game_state.gd").HangingDoorStage
const SOUNDS := {
	"hinge_close": preload("res://assets/audio/public_effects/hinge_close.wav"),
	"hinge_open": preload("res://assets/audio/public_effects/hinge_open.wav"),
	"door_seat": preload("res://assets/audio/public_effects/door_seat.wav"),
	"sob_close": preload("res://assets/audio/public_effects/sob_close.wav"),
	"sob_between": preload("res://assets/audio/public_effects/sob_between.wav"),
	"sob_last": preload("res://assets/audio/public_effects/sob_last.wav"),
	"knock_1": preload("res://assets/audio/door_cry/knock_1.wav"),
	"knock_2": preload("res://assets/audio/door_cry/knock_2.wav"),
	"knock_3": preload("res://assets/audio/door_cry/knock_3.wav"),
	"yuelan_open": preload("res://assets/audio/door_cry/yuelan_open.wav"),
	"yuelan_please": preload("res://assets/audio/door_cry/yuelan_please.wav"),
	"yuelan_not_mad": preload("res://assets/audio/door_cry/yuelan_not_mad.wav"),
	"chen_heard": preload("res://assets/audio/door_cry/chen_heard.wav"),
	"chen_trapped": preload("res://assets/audio/door_cry/chen_trapped.wav"),
	"chen_confession": preload("res://assets/audio/door_cry/chen_confession.wav"),
	"chen_marks": preload("res://assets/audio/door_cry/chen_marks.wav"),
	"chen_outside": preload("res://assets/audio/door_cry/chen_outside.wav"),
	"chen_no_escape": preload("res://assets/audio/door_cry/chen_no_escape.wav"),
	"chen_waiting": preload("res://assets/audio/door_cry/chen_waiting.wav"),
	"chen_no_rescue": preload("res://assets/audio/door_cry/chen_no_rescue.wav"),
}
const DOOR_Z := 7.55
const OPEN_ANGLE := 1.48
const ROOM_RAIN_DB := -24.0
const QUIET_RAIN_DB := -49.0
const HALL_DOOR := Vector3(-6.54, 1.14, -4.32)

signal beat_started(cue: String)
var timing_scale := 1.0
var room: Node3D
var state: Node
var hud: Control
var rain: AudioStreamPlayer
var hinge: Node3D
var leaf: MeshInstance3D
var barrier: CollisionShape3D
var trim: Node3D
var spill: OmniLight3D
var listener: AudioListener3D
var returning: Node
var source: AudioStreamPlayer3D
var thought: AudioStreamPlayer
var timer: Timer
var cues: Array[Dictionary] = []
var done: Callable
var busy := false
var can_build := false


func build_inside(owner_room: Node3D, frame: Node3D, wood: Material, dark_wood: Material, plaster: Material) -> void:
	# The shell previously had jambs and lintel but no moving leaf. The hall
	# still uses its own existing mesh at the other side of the transition.
	hinge = Node3D.new()
	hinge.name = "WestWingOriginalFrameHinge"
	hinge.position = Vector3(1.11, 0.0, DOOR_Z)
	frame.add_child(hinge)
	leaf = owner_room._add_box(hinge, "WestWingDoorLeaf", Vector3(2.22, 2.93, 0.115), Vector3(-1.11, 1.49, 0), wood)
	var wear: StandardMaterial3D = owner_room._material(Color(0.24, 0.17, 0.11), 0.91)
	var cut: StandardMaterial3D = owner_room._material(Color(0.072, 0.048, 0.031), 0.95)
	for i in 7:
		var x := -2.0 + i * 0.28
		owner_room._add_box(hinge, "BoardJoint", Vector3(0.009, 2.83, 0.008), Vector3(x, 1.48, -0.059), cut)
		var crack: MeshInstance3D = owner_room._add_box(hinge, "DryWoodCrack", Vector3(0.006, 0.25 + (i % 3) * 0.13, 0.008), Vector3(x + 0.09, 0.52 + (i % 4) * 0.48, -0.06), cut)
		crack.rotation.z = 0.04 - i * 0.015
	for i in 5:
		var mark: MeshInstance3D = owner_room._add_box(hinge, "OldInsideScratch", Vector3(0.009, 0.19 + (i % 3) * 0.045, 0.009), Vector3(-1.40 + i * 0.079, 0.99 + i * 0.047, -0.064), wear)
		mark.rotation.z = -0.64 + i * 0.07
	for y in [0.49, 2.53]:
		owner_room._add_box(hinge, "DoorCrossRail", Vector3(2.06, 0.11, 0.075), Vector3(-1.11, y, -0.074), dark_wood)
	trim = Node3D.new()
	trim.name = "WestWingThresholdSurround"
	frame.add_child(trim)
	for x in [-2.13, 2.13]:
		owner_room._add_box(trim, "EntrancePlasterInfill", Vector3(1.52, 3.35, 0.24), Vector3(x, 1.67, DOOR_Z + 0.15), plaster)
	for i in 6:
		var edge: MeshInstance3D = owner_room._add_box(trim, "BatteredJambEdge", Vector3(0.015 + (i % 2) * 0.009, 0.05 + i * 0.015, 0.009), Vector3(-1.135 - i * 0.008, 0.33 + i * 0.29, DOOR_Z - 0.194), wear)
		edge.rotation.z = (i % 3 - 1) * 0.17
	for i in 5:
		var chip: MeshInstance3D = owner_room._add_box(trim, "SmallThresholdWoodChip", Vector3(0.035 + (i % 2) * 0.012, 0.007, 0.019), Vector3(-1.13 + i * 0.068, 0.04, 7.18 + (i % 3) * 0.095), wear)
		chip.rotation.y = i * 1.37
	# A fixed shut-position collider protects the threshold throughout the
	# swing, which is entirely outward and never sweeps into the player.
	var body := StaticBody3D.new()
	body.name = "WestWingClosedThreshold"
	body.position = Vector3(0, 1.48, DOOR_Z)
	frame.add_child(body)
	barrier = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.72, 2.95, 0.14)
	barrier.shape = box
	body.add_child(barrier)
	barrier.disabled = true
	hinge.rotation.y = OPEN_ANGLE
	hinge.hide()
	trim.hide()
	can_build = true


static func dress_hall_door(owner_room: Node3D, module: Node3D, door: MeshInstance3D, z: float, mats: Dictionary) -> void:
	var iron: StandardMaterial3D = owner_room._material(Color(0.13, 0.108, 0.083), 0.78)
	iron.metallic = 0.56
	var rubbed: StandardMaterial3D = owner_room._material(Color(0.22, 0.165, 0.12), 0.69)
	rubbed.metallic = 0.48
	# The bolt is parked short of the keeper today. There is no corresponding
	# mechanism on the inside, and this hardware never blocks the portal.
	owner_room._add_box(door, "OutsideWroughtBoltPlate", Vector3(0.038, 0.16, 0.33), Vector3(0.094, -0.28, -0.49), iron)
	owner_room._add_box(door, "RetractedOutsideBolt", Vector3(0.052, 0.036, 0.31), Vector3(0.135, -0.28, -0.53), rubbed)
	for s in [-1.0, 1.0]:
		owner_room._add_box(door, "WroughtBoltGuide", Vector3(0.072, 0.08, 0.037), Vector3(0.129, -0.28, -0.49 + s * 0.097), iron)
	owner_room._add_box(door, "OutsideBoltGrip", Vector3(0.082, 0.075, 0.033), Vector3(0.174, -0.28, -0.427), rubbed)
	owner_room._add_box(module, "WeatheredOuterKeeperBlock", Vector3(0.08, 0.18, 0.16), Vector3(-6.59, 1.27, z - 0.79), mats.dark_wood)
	for y in [1.235, 1.305]:
		owner_room._add_box(module, "OutsideKeeperLip", Vector3(0.061, 0.027, 0.09), Vector3(-6.53, y, z - 0.77), iron)
	owner_room._add_box(module, "OutsideKeeperBridge", Vector3(0.022, 0.094, 0.092), Vector3(-6.487, 1.27, z - 0.77), iron)


func setup(owner_room: Node3D, story_state: Node, entry: Node = null) -> void:
	room = owner_room
	state = story_state
	returning = entry
	hud = room.get("hud")
	rain = room.get("rain_audio")
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_next)
	source = AudioStreamPlayer3D.new()
	source.name = "WestWingDoorSpatialSound"
	source.position = Vector3(0, 1.16, DOOR_Z - 0.18) if can_build else HALL_DOOR + Vector3(-0.41, 0, 0)
	source.unit_size = 7.0 if can_build else 2.0
	source.max_distance = 22.0
	source.max_db = -6.0
	source.attenuation_filter_cutoff_hz = 3600.0
	add_child(source)
	thought = AudioStreamPlayer.new()
	thought.name = "ChenMoQuietVoice"
	add_child(thought)
	# Leaving mid-scene resumes at the investigation, never at the knock.
	if stage() == Stage.PLAYING:
		state.set("hanging_door_stage", Stage.INSPECT)
	elif stage() == Stage.AFTERMATH:
		state.set("hanging_door_stage", Stage.COMPLETE)
	if can_build and stage() >= Stage.INSPECT:
		trim.show()
		hinge.show()
		_set_shut(stage() < Stage.LATCH)
		spill.light_energy = 0.42 if stage() < Stage.LATCH else 1.08
		rain.volume_db = QUIET_RAIN_DB if stage() < Stage.COMPLETE else ROOM_RAIN_DB
	elif stage() == Stage.COMPLETE:
		rain.volume_db = ROOM_RAIN_DB
	_update_objective()
	set_process(false)
	set_physics_process(can_build and stage() == Stage.WAITING)


func _process(_delta: float) -> void:
	if is_instance_valid(listener):
		listener.global_basis = room.get("camera").global_basis


func stage() -> int:
	return int(state.get("hanging_door_stage")) if state != null else Stage.WAITING


func _physics_process(_delta: float) -> void:
	if returning == null or not returning.active or returning.busy or not state.get("hanging_return_entry_complete"):
		return
	var p: Vector3 = room.get("player").position
	var stool: Node3D = returning.stool
	if stool != null and Vector2(p.x, p.z).distance_to(Vector2(stool.position.x, stool.position.z)) < 1.35:
		_begin()


func inside_target(p: Vector3) -> String:
	if busy:
		return ""
	var at_door := p.z >= 6.12 and absf(p.x) <= 1.10
	match stage():
		Stage.INSPECT: return "inspect_west_door" if at_door else ""
		Stage.OPEN: return "open_west_door" if at_door else ""
		_: return "exit" if p.z > 6.70 and (stage() == Stage.WAITING or at_door) else ""


func interact_inside(target: String) -> void:
	if target != inside_target(room.get("player").position):
		return
	match target:
		"inspect_west_door":
			_play([
				_line("门板内侧残留着几道陈旧的划痕。", "", 2.8),
				_line("门框边缘有反复碰撞留下的磨损。", "", 2.8),
				_line("这些痕迹……像是有人曾经拼命想把门打开。", "chen_marks", 4.0),
			], _set_stage.bind(Stage.OPEN))
		"open_west_door":
			_play([_cue("open", 1.13, "", "hinge_open", -22.0), _cue("release", 0.01)], _set_stage.bind(Stage.LATCH))


func inspect_outside() -> void:
	if busy or stage() != Stage.LATCH:
		return
	var lines: Array[Dictionary] = [
		_line("门闩安装在房门外侧。", "", 2.5),
		_line("从房间里面，根本无法操作这道门闩。", "", 3.3),
	]
	if state.get("main_hall_confession_read"):
		lines.append(_line("果然……这扇门是从外面锁上的。", "chen_outside", 3.2))
		lines.append(_line("她当时根本出不去。", "chen_no_escape", 2.5))
	lines.append_array([
		_cue("outside_quiet", 1.2),
		_cue("last_sob", 1.35, "", "sob_last", -23.0),
		_cue("rain_returns", 0.24),
		_line("原来她一直在等人开门……", "chen_waiting", 2.8),
		_cue("pause", 0.75),
		_line("可没有人愿意救她。", "chen_no_rescue", 2.6),
	])
	_set_stage(Stage.AFTERMATH)
	_play(lines, _set_stage.bind(Stage.COMPLETE))


func _begin() -> void:
	set_physics_process(false)
	_set_stage(Stage.PLAYING)
	trim.show()
	hinge.show()
	# Spatial sound is heard from Chen Mo's position, even though his camera
	# can sit several metres behind him in the entrance direction.
	listener = AudioListener3D.new()
	listener.position = Vector3(0, 1.42, 0)
	room.get("player").add_child(listener)
	listener.make_current()
	set_process(true)
	barrier.set_deferred("disabled", false)
	var opening: Array[Dictionary] = [
		_cue("close", 2.66, "", "hinge_close", -13.0),
		_cue("seat", 0.56, "", "door_seat", -16.0),
		_cue("quiet", 1.35),
		_cue("first_sob", 1.12, "", "sob_close", -22.0),
		_cue("yuelan_open", 1.1, "开门……", "yuelan_open", -9.0),
		_cue("pause", 1.0),
		_cue("yuelan_please", 2.3, "求求你们……开门……", "yuelan_please", -9.0),
		_cue("between_sob", 1.38, "", "sob_between", -20.0),
		_cue("yuelan_not_mad", 1.9, "我没有疯……", "yuelan_not_mad", -10.0),
		_cue("pause", 0.8),
		_cue("knock_1", 1.03, "", "knock_1", -13.0),
		_cue("knock_2", 0.73, "", "knock_2", -10.0),
		_cue("knock_3", 1.15, "", "knock_3", -18.0),
		_cue("fading_sob", 1.34, "", "sob_last", -25.0),
		_cue("pause", 1.0),
		_line("这声音……", "chen_heard", 1.3),
		_line("难道是她当年被关在这里的时候？", "chen_trapped", 3.1),
	]
	if state.get("main_hall_confession_read"):
		opening.append(_cue("pause", 1.0))
		opening.append(_line("王承安说过……门是他锁的。", "chen_confession", 3.0))
	_play(opening, _set_stage.bind(Stage.INSPECT))


func _line(text: String, clip: String, duration: float) -> Dictionary:
	return _cue("thought", duration, text, clip, -13.5)


func _cue(key: String, seconds: float, text := "", clip := "", db := -18.0) -> Dictionary:
	return {"key": key, "seconds": seconds, "text": text, "clip": clip, "db": db}


func _play(sequence: Array[Dictionary], completion: Callable) -> void:
	busy = true
	room.set("hud_interaction_target", "")
	hud.set_door_prompt_visible(false, true)
	hud.set_process_input(false)
	cues = sequence
	done = completion
	_next()


func _next() -> void:
	source.stop()
	thought.stop()
	if cues.is_empty():
		var completion := done
		done = Callable()
		busy = false
		hud.set_process_input(true)
		hud.set_story_caption("", false, true, 20)
		if is_instance_valid(listener):
			listener.clear_current()
			listener.queue_free()
			set_process(false)
		completion.call()
		return
	var cue: Dictionary = cues.pop_front()
	var key: String = cue.key
	var text: String = cue.text
	hud.set_story_caption(text, not text.is_empty(), true, 20)
	var duration := float(cue.seconds)
	if not str(cue.clip).is_empty():
		var clip := SOUNDS.get(cue.clip) as AudioStream
		if clip != null:
			if key == "thought":
				thought.stream = clip
				thought.volume_db = cue.db
				thought.play()
			else:
				source.stream = clip
				source.volume_db = cue.db
				source.play()
			if key != "open":
				duration = maxf(duration, clip.get_length() + 0.06)
	match key:
		"close":
			var motion := create_tween()
			motion.tween_property(hinge, "rotation:y", OPEN_ANGLE - 0.033, _seconds(0.23)).set_trans(Tween.TRANS_SINE)
			motion.tween_property(hinge, "rotation:y", 0.0, _seconds(2.35)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			motion.parallel().tween_property(spill, "light_energy", 0.42, _seconds(2.35))
		"seat":
			_set_shut(true)
			_fade_rain(QUIET_RAIN_DB, 0.75)
		"open":
			var swing := create_tween().set_parallel()
			swing.tween_property(hinge, "rotation:y", OPEN_ANGLE, _seconds(1.06)).set_trans(Tween.TRANS_SINE)
			swing.tween_property(spill, "light_energy", 1.08, _seconds(1.06))
		"release": _set_shut(false)
		"outside_quiet": _fade_rain(QUIET_RAIN_DB, 0.48)
		"rain_returns": _fade_rain(ROOM_RAIN_DB, 2.2)
	if key.begins_with("knock_"):
		var vibration := create_tween()
		vibration.tween_property(leaf, "position:z", 0.003, _seconds(0.045))
		vibration.tween_property(leaf, "position:z", 0.0, _seconds(0.13)).set_trans(Tween.TRANS_SINE)
	beat_started.emit(key)
	timer.start(_seconds(duration))


func _seconds(value: float) -> float:
	return maxf(0.01, value * timing_scale)


func _fade_rain(db: float, time: float) -> void:
	create_tween().tween_property(rain, "volume_db", db, _seconds(time))


func _set_shut(shut: bool) -> void:
	hinge.rotation.y = 0.0 if shut else OPEN_ANGLE
	barrier.set_deferred("disabled", not shut)


func _set_stage(value: int) -> void:
	state.set("hanging_door_stage", value)
	_update_objective()


func _update_objective() -> void:
	var objective: String = state.hanging_door_objective()
	if not objective.is_empty():
		hud.set_objective(objective)
