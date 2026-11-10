extends Node3D
## Scene-owned final performance. GameState stores the next unfinished beat.

const FIGURE = preload("res://scenes/encounters/YuelanBackFigure.tscn")
const PAPER = preload("res://assets/ui/reader_old_paper.png")
const FONT = preload("res://assets/fonts/watchnight_chinese.tres")
const CLOTH = preload("res://assets/audio/hanging_coda/cloth_shift.wav")
const ROPE_LAND = preload("res://assets/audio/hanging_coda/rope_lands.wav")
const Stage = GameState.HangingCodaStage
const RAIN_RESTORED := -22.0
const APPEAR := Vector3(0.02, 0.020, 7.34)
const RETREAT_DISTANCE := 0.64
const FLOOR_ROPE := Vector3(0.10, 0.061, -5.88)

const SCORE := [
	["step", 0.95],
	["place", 2.75],
	["speak", 1.15, "沈月兰。", preload("res://assets/audio/hanging_coda/name.wav")],
	["wait", 1.0],
	["speak", 2.55, "我知道那天夜里发生了什么。", preload("res://assets/audio/hanging_coda/know.wav")],
	["speak", 2.40, "绳子是他们提前备好的。", preload("res://assets/audio/hanging_coda/prepared.wav")],
	["speak", 2.95, "门，也是王承安亲手锁上的。", preload("res://assets/audio/hanging_coda/door.wav")],
	["wait", 1.0],
	["speak", 3.25, "他们说你疯了，说你自己寻了短见。", preload("res://assets/audio/hanging_coda/story.wav")],
	["speak", 4.17, "还从家谱里划去你的名字，不许你留下牌位。", preload("res://assets/audio/hanging_coda/erased.wav")],
	["wait", 2.0],
	["speak", 1.70, "可我找到了供词。", preload("res://assets/audio/hanging_coda/testimony.wav")],
	["speak", 1.45, "你没有被遗忘。", preload("res://assets/audio/hanging_coda/remembered.wav")],
	["speak", 2.12, "我会把真相带出去。", preload("res://assets/audio/hanging_coda/take_truth.wav")],
	["wait", 2.0],
	["loosen", 0.75],
	["drop", 0.70],
	["incense", 3.0],
	["reveal", 2.40],
	["thanks", 1.55, "谢谢你……"],
	["retreat", 2.45],
	["wait", 2.0],
	["reaction", 1.55, "结束了吗……", preload("res://assets/audio/hanging_coda/over.wav")],
	["wait", 1.0],
	["speak", 2.42, "至少……真相已经找到了。", preload("res://assets/audio/hanging_coda/found.wav")],
	["gather", 0.90],
	["return", 0.68],
]

@export var farewell_voice: AudioStream = preload("res://assets/audio/hanging_coda/thanks.wav")

var room: Node3D
var state: Node
var player: CharacterBody3D
var hud: Control
var rope: Node3D
var rain: AudioStreamPlayer
var cam: Camera3D
var timer: Timer
var thought: AudioStreamPlayer
var spatial: AudioStreamPlayer3D
var listener: AudioListener3D
var rain_fade: Tween
var floor_rope: Node3D
var offering: Node3D
var hairpin: Node3D
var figure: Node3D
var threshold_lighting: Node3D
var cool_fill: OmniLight3D
var cloth_key: SpotLight3D
var haze_material: ShaderMaterial
var figure_parts: Array[GeometryInstance3D] = []
var interaction_spot := Vector3.ZERO
var offering_spot := Vector3.ZERO
var actor_spot := Vector3.ZERO
var original_rope_position := Vector3.ZERO
var original_flashlight_range := 0.0
var busy := false
var paper_stir := 0.0
var timing_scale := 1.0
var beat_index := 0
var shot := "normal"
var walk_to_mark := false


func setup(owner_room: Node3D, story_state: Node, spot: Vector3) -> void:
	room = owner_room
	state = story_state
	player = room.get("player")
	hud = room.get("hud")
	rope = room.get("rope_visual")
	rain = room.get("rain_audio")
	cam = room.get("camera")
	original_flashlight_range = (room.get("flashlight") as SpotLight3D).spot_range
	original_rope_position = rope.position
	interaction_spot = spot
	offering_spot = _choose_bare_tile(spot)
	actor_spot = Vector3(spot.x - 0.40, 0.02, spot.z + 0.40)
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_next)
	thought = AudioStreamPlayer.new()
	thought.name = "ChenMoFinalLines"
	thought.volume_db = -12.5
	add_child(thought)
	spatial = AudioStreamPlayer3D.new()
	spatial.name = "CodaSpatialFoley"
	spatial.unit_size = 3.2
	spatial.max_distance = 16.0
	spatial.attenuation_filter_cutoff_hz = 3500.0
	add_child(spatial)
	if state.hanging_coda_rope_down:
		_land_rope(false)
		_restore_incense(false)
	if state.has_hanging_coda_completed():
		state.preserve_final_evidence()
		hud.set_objective(GameState.RETURN_HOME_OBJECTIVE)
	elif state.hanging_coda_stage == Stage.PLAYING:
		_resume.call_deferred()


func start() -> void:
	if busy or not state.can_place_final_confession() or hud.objective_label.text != GameState.HANGING_CODA_OBJECTIVE:
		return
	if Vector2(player.position.x, player.position.z).distance_to(Vector2(interaction_spot.x, interaction_spot.z)) >= 0.53:
		return
	state.hanging_coda_stage = Stage.PLAYING
	state.hanging_coda_beat = 0
	_resume()


func _resume() -> void:
	if busy or state.hanging_coda_stage != Stage.PLAYING:
		return
	busy = true
	GameState.set_night_clock_hold(self, true)
	hud.set_process_input(false)
	hud.set_door_prompt_visible(false, true)
	room.hud_interaction_target = ""
	listener = AudioListener3D.new()
	listener.name = "CodaListeningPoint"
	add_child(listener)
	_update_listener()
	listener.make_current()
	var returning: Node = room.return_investigation
	if returning.ambience_tween != null:
		returning.ambience_tween.kill()
	beat_index = state.hanging_coda_beat
	var cue: String = SCORE[beat_index][0]
	# Once she was seen, returning cannot summon the figure again.
	if state.hanging_coda_yuelan_seen and cue in ["reveal", "thanks", "retreat"]:
		while SCORE[beat_index][0] != "reaction":
			beat_index += 1
		state.hanging_coda_beat = beat_index
	if beat_index > 0 or player.position.z > -3.0:
		player.position = actor_spot
	if beat_index > 1 and beat_index <= 16:
		shot = "beam"
	elif cue == "incense":
		shot = "door"
	if beat_index > 1 and beat_index < SCORE.size() - 1:
		_build_offering()
		offering.visible = SCORE[beat_index][0] != "gather"
	if not state.hanging_coda_rope_down:
		_fade_rain(-46.0, 4.0)
	_play_beat()


func _next() -> void:
	beat_index += 1
	state.hanging_coda_beat = beat_index
	if beat_index >= SCORE.size():
		_finish()
	else:
		_play_beat()


func _play_beat() -> void:
	thought.stop()
	var beat: Array = SCORE[beat_index]
	var cue: String = beat[0]
	var seconds: float = beat[1]
	var line: String = beat[2] if beat.size() > 2 else ""
	hud.set_story_caption(line, not line.is_empty(), true, 30, _seconds(seconds * 0.92))
	match cue:
		"step":
			walk_to_mark = true
		"place":
			walk_to_mark = false
			shot = "evidence"
			_build_offering()
			offering.show()
			offering.position.y = offering_spot.y + 0.18
			create_tween().tween_property(offering, "position:y", offering_spot.y, _seconds(0.62)).set_trans(Tween.TRANS_SINE)
			_play_at(CLOTH, offering_spot + Vector3.UP * 0.58, -24.0)
			_paper_sound(0.38)
		"loosen":
			shot = "beam"
			_loosen_rope()
		"drop":
			_drop_rope()
		"incense":
			_land_rope()
			_restore_incense(true)
			shot = "landed"
			var shift := create_tween()
			shift.tween_interval(_seconds(1.06))
			shift.tween_callback(func() -> void: shot = "incense")
			shift.tween_interval(_seconds(0.75))
			shift.tween_callback(_turn_to_door)
		"reveal":
			_reveal_figure()
		"thanks":
			if farewell_voice != null:
				_play_at(farewell_voice, APPEAR + Vector3.UP * 1.32, -16.0)
				seconds = maxf(seconds, farewell_voice.get_length() + 0.14)
		"retreat":
			_retreat_figure()
		"reaction":
			shot = "normal"
		"gather":
			shot = "evidence"
			if is_instance_valid(offering) and offering.visible:
				var gather := create_tween()
				gather.tween_property(offering, "position:y", offering_spot.y + 0.16, _seconds(0.48)).set_trans(Tween.TRANS_SINE)
				gather.tween_callback(offering.hide)
				_paper_sound(0.05)
		"return":
			shot = "normal"
	if cue == "speak" and shot == "evidence":
		shot = "beam"
	if line == "沈月兰。":
		_fade_last_echo()
	if beat.size() > 3:
		thought.stream = beat[3]
		thought.play()
	timer.start(_seconds(seconds))


func _seconds(duration: float) -> float:
	return maxf(0.01, duration * timing_scale)


func _fade_last_echo() -> void:
	var echo := AudioStreamPlayer3D.new()
	echo.name = "LastTraceOfCrying"
	echo.stream = room.return_investigation.beam_sob_stream
	echo.position = original_rope_position - Vector3.UP * 0.7
	echo.unit_size = 3.0
	echo.max_distance = 12.0
	echo.attenuation_filter_cutoff_hz = 2000.0
	add_child(echo)
	# Reuse the tail of the existing sob as a distant residual breath.
	echo.volume_db = -37.0
	echo.play(maxf(0.0, echo.stream.get_length() - 1.1))
	var tail := create_tween()
	tail.tween_property(echo, "volume_db", -60.0, _seconds(1.05))
	tail.tween_callback(func() -> void:
		echo.stop()
		echo.stream = null
		echo.queue_free()
	)

func _play_at(stream: AudioStream, at: Vector3, volume: float) -> void:
	spatial.stop()
	spatial.stream = stream
	spatial.position = at
	spatial.volume_db = volume
	spatial.play()


func _paper_sound(delay: float) -> void:
	var paper := room.get("paper_audio") as AudioStreamPlayer
	if paper != null:
		var tween := create_tween()
		tween.tween_interval(_seconds(delay))
		tween.tween_callback(func() -> void: _play_at(paper.stream, offering_spot, -19.5))


func update_player_and_camera(delta: float) -> void:
	var direction := actor_spot - player.position
	direction.y = 0.0
	var speed := 0.0
	player.velocity = Vector3.ZERO
	if walk_to_mark and direction.length_squared() > 0.0025:
		speed = minf(0.86, direction.length() / maxf(delta, 0.001))
		player.velocity = direction.normalized() * speed + Vector3.DOWN * 0.2
		player.move_and_slide()
		room._update_facing(direction)
	elif not walk_to_mark and shot != "door":
		room._update_facing(Vector3(0, 0, -1))
	room._update_animation(speed > 0.05, speed)
	room._update_flashlight()
	var lamp := room.get("flashlight_origin") as Node3D
	var beam := room.get("flashlight") as SpotLight3D
	# Let the actual torch reach the threshold at the edge of its falloff.
	# The player can still turn it off; no duplicate front light replaces it.
	beam.spot_range = original_flashlight_range + (2.55 if shot == "door" else 0.0)
	match shot:
		"evidence": lamp.look_at(offering_spot + Vector3(0.05, 0.10, 0.0))
		"beam": lamp.look_at(original_rope_position - Vector3.UP * 1.28)
		"landed": lamp.look_at(FLOOR_ROPE + Vector3(0.18, 0.04, 0.0))
		"door": lamp.look_at(APPEAR + Vector3.UP * 0.85)

	var p := player.global_position
	var eye := p + Vector3(-p.x * 0.66, 2.72, 5.30)
	var target := p + Vector3(0, 1.02, -2.15)
	var lens := 50.0
	match shot:
		"evidence":
			eye = offering_spot + Vector3(-0.13, 1.01, 1.32)
			target = offering_spot + Vector3(0.07, 0.15, -0.02)
			lens = 43.0
		"beam":
			eye = p + Vector3(-0.26, 1.85, 2.48)
			target = Vector3(-0.25, 1.55, -5.2)
			lens = 48.0
		"landed":
			eye = Vector3(-0.82, 1.52, -3.72)
			target = FLOOR_ROPE + Vector3(0.20, 0.06, 0.06)
			lens = 45.0
		"incense":
			eye = Vector3(-0.98, 1.40, -0.58)
			target = Vector3(0.0, 0.78, -2.62)
			lens = 45.0
		"door":
			eye = _door_eye()
			target = APPEAR + Vector3(0, 0.89, 0)
			lens = 43.0
	var weight := 1.0 - exp(-delta * (5.3 if shot == "normal" else 3.0))
	cam.global_position = cam.global_position.lerp(eye, weight)
	cam.global_basis = cam.global_basis.orthonormalized().slerp(Basis.looking_at(target - eye, Vector3.UP), weight)
	cam.fov = lerpf(cam.fov, lens, weight)
	_update_listener()


func _update_listener() -> void:
	listener.global_transform = Transform3D(cam.global_basis,
		cam.global_position if shot == "door" else player.global_position + Vector3.UP * 1.38)


func _door_eye() -> Vector3:
	return Vector3(0.40, 1.24, 4.38)


func _turn_to_door() -> void:
	# Brief soft transition through shadow, leaving the original HUD readable.
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.017, 0.020, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var transition := create_tween().set_trans(Tween.TRANS_SINE)
	transition.tween_property(shade, "color:a", 1.0, _seconds(0.24))
	transition.tween_callback(func() -> void:
		shot = "door"
		cam.global_position = _door_eye()
		cam.look_at(APPEAR + Vector3(0, 0.89, 0), Vector3.UP)
		cam.fov = 43.0
	)
	transition.tween_property(shade, "color:a", 0.0, _seconds(0.30))
	transition.tween_callback(layer.queue_free)


func _choose_bare_tile(spot: Vector3) -> Vector3:
	# The scatter is generated from fixed seeds. Check the actual sheets so
	# the confession never needs to sit on top of raised ink or ghost money.
	var patches: Array[Vector3] = []
	for prefix in ["TalismanCluster*", "GhostMoneyCluster*"]:
		for node in room.find_children(prefix, "MultiMeshInstance3D", true, false):
			var scatter := node as MultiMeshInstance3D
			for i in scatter.multimesh.instance_count:
				patches.append(scatter.to_global(scatter.multimesh.get_instance_transform(i).origin))
	var best := spot + Vector3(-0.28, 0, -0.10)
	var best_score := -INF
	for x in [-0.19, -0.30, -0.41, -0.52, -0.63, -0.74]:
		for z in [-0.25, -0.15, -0.05, 0.05, 0.15, 0.25]:
			var candidate := spot + Vector3(x, 0, z)
			var clearance := 1.0
			for patch in patches:
				clearance = minf(clearance, Vector2(candidate.x - 0.06 - patch.x, candidate.z - patch.z).length())
			var score := clearance - 0.12 * Vector2(x, z).length()
			if score > best_score:
				best_score = score
				best = candidate
	best.y = 0.037
	return best


func _build_offering() -> void:
	if is_instance_valid(offering):
		return
	offering = Node3D.new()
	offering.name = "TemporaryConfessionOffering"
	offering.position = offering_spot
	offering.rotation.y = -0.22
	add_child(offering)
	var material := StandardMaterial3D.new()
	material.albedo_texture = PAPER
	material.albedo_color = Color(0.86, 0.80, 0.68)
	material.roughness = 0.94
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.42
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.27, 0.37)
	plane.material = material
	var page := _mesh(offering, "AgedFoldedConfession", plane, Vector3.ZERO)
	page.rotation.z = 0.015
	var crease := StandardMaterial3D.new()
	crease.albedo_color = Color(0.35, 0.255, 0.15)
	crease.roughness = 1.0
	var fold := BoxMesh.new()
	fold.size = Vector3(0.225, 0.0018, 0.003)
	fold.material = crease
	_mesh(offering, "PaperFold", fold, Vector3(0, 0.002, 0.029))
	var writing := Label3D.new()
	writing.font = FONT
	writing.text = "那夜，他们让我备好绳子。\n西厢的门也是我锁的。\n\n第二日，我们只说她疯病发作，\n自缢而亡。"
	writing.font_size = 25
	writing.pixel_size = 0.00061
	writing.outline_size = 0
	writing.modulate = Color(0.24, 0.17, 0.11, 0.9)
	writing.shaded = true
	writing.position = Vector3(0, 0.004, -0.014)
	writing.rotation.x = -PI / 2.0
	offering.add_child(writing)
	if state.has_item("complete_silver_hairpin"):
		_build_hairpin()


func _build_hairpin() -> void:
	hairpin = Node3D.new()
	hairpin.name = "TemporaryCompleteSilverHairpin"
	hairpin.position = Vector3(-0.18, 0.003, 0.025)
	hairpin.rotation.y = -0.25
	offering.add_child(hairpin)
	var oxidized := StandardMaterial3D.new()
	oxidized.albedo_color = Color(0.34, 0.345, 0.32)
	oxidized.metallic = 0.54
	oxidized.roughness = 0.69
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.0027
	shaft.bottom_radius = 0.0054
	shaft.height = 0.155
	shaft.radial_segments = 8
	shaft.material = oxidized
	_mesh(hairpin, "TaperedShaft", shaft, Vector3.ZERO).rotation.x = -PI / 2.0
	var petal := SphereMesh.new()
	petal.radius = 0.006
	petal.height = 0.024
	petal.radial_segments = 8
	petal.rings = 4
	petal.material = oxidized
	for i in 5:
		var angle := i * TAU / 5.0
		var ornament := _mesh(hairpin, "OxidizedPetal", petal, Vector3(sin(angle) * 0.008, 0.002, 0.079 + cos(angle) * 0.008))
		ornament.rotation = Vector3(PI / 2.0, angle, 0)


func _mesh(parent: Node3D, label: String, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


func _loosen_rope() -> void:
	var beam := room.get("beam_creak_audio") as AudioStreamPlayer3D
	if beam != null:
		_play_at(beam.stream, original_rope_position, -25.0)
	var twitch := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	twitch.tween_property(rope, "rotation", Vector3(0.09, 0.0, -0.03), _seconds(0.74))
	twitch.tween_property(rope, "position:y", original_rope_position.y - 0.10, _seconds(0.74))


func _drop_rope() -> void:
	if state.hanging_coda_rope_down:
		return
	rope.position.y = original_rope_position.y - 0.10
	var fall := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(rope, "position:y", 2.065, _seconds(0.68))
	fall.tween_property(rope, "rotation", Vector3(0.35, 0.08, -0.13), _seconds(0.68))
	fall.chain().tween_callback(func() -> void: _land_rope(true))


func _land_rope(sound := false) -> void:
	if not is_instance_valid(floor_rope):
		floor_rope = Node3D.new()
		floor_rope.name = "SettledOldHempRope"
		floor_rope.position = FLOOR_ROPE
		add_child(floor_rope)
		var rope_mesh := rope.get_child(0) as MeshInstance3D
		var material := rope_mesh.get_active_material(0)
		var loop: Array[Vector3] = []
		for i in range(65):
			var a := i * TAU / 64.0
			loop.append(Vector3(sin(a) * (0.31 + 0.027 * sin(a * 3.0)), 0.003 * cos(a * 3.0), cos(a) * 0.43))
		_rope_tube("FlattenedNooseLoop", loop, 0.035, material, true)
		var slack: Array[Vector3] = [Vector3(0,0,0.43), Vector3(0.12,0.022,0.55), Vector3(0.29,0,0.56), Vector3(0.43,0,0.46), Vector3(0.53,0,0.30), Vector3(0.63,0,0.17), Vector3(0.76,0,0.14), Vector3(0.85,0,0.26), Vector3(0.80,0,0.39)]
		_rope_tube("SlackFreeEnd", _smooth_rope(slack), 0.032, material)
		var knot: Array[Vector3] = [Vector3(-0.07,0.009,0.39), Vector3(-0.045,0.034,0.465), Vector3(0.018,0.043,0.49), Vector3(0.068,0.015,0.45)]
		_rope_tube("SettledKnot", _smooth_rope(knot), 0.039, material)
	rope.hide()
	state.hanging_coda_rope_down = true
	if sound:
		_play_at(ROPE_LAND, FLOOR_ROPE, -18.0)


func _smooth_rope(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in range(points.size() - 1):
		for step in 7:
			result.append(points[i].cubic_interpolate(points[i + 1], points[maxi(0, i - 1)], points[mini(i + 2, points.size() - 1)], step / 7.0))
	result.append(points.back())
	return result


func _rope_tube(label: String, points: Array[Vector3], radius: float, material: Material, looped := false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	const SIDES := 10
	var travelled := 0.0
	for i in points.size():
		var last := points.size() - 1
		var before := points[i - 1] if i > 0 else points[last - 1] if looped else points[0]
		var after := points[i + 1] if i < last else points[1] if looped else points[last]
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		var tangent := (after - before).normalized()
		var side := Vector3.UP.cross(tangent).normalized()
		var up := tangent.cross(side).normalized()
		for j in SIDES:
			var angle := j * TAU / SIDES
			var normal := up * cos(angle) + side * sin(angle)
			var twist := sin(3.0 * angle + travelled * 87.0)
			var tone := 0.72 + 0.16 * twist + 0.055 * sin(travelled * 32.0)
			surface.set_uv(Vector2(float(j) / SIDES, travelled))
			surface.set_color(Color(tone, tone, tone))
			surface.set_normal(normal)
			surface.add_vertex(points[i] + normal * radius * (1.0 + twist * 0.045))
	for i in range(points.size() - 1):
		for j in SIDES:
			var a := i * SIDES + j
			var b := i * SIDES + (j + 1) % SIDES
			for idx in [a, b, a + SIDES, b, b + SIDES, a + SIDES]:
				surface.add_index(idx)
	_mesh(floor_rope, label, surface.commit(), Vector3.ZERO)


func _restore_incense(animate: bool) -> void:
	var smoke := room.get("incense_smoke") as GPUParticles3D
	if smoke != null and not smoke.emitting:
		smoke.preprocess = 0.0
		smoke.show()
		smoke.emitting = true
		smoke.restart()
	for ember in room.incense_embers:
		var material := (ember as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 0.19
		ember.show()
	if animate:
		var paper_motion := create_tween().set_trans(Tween.TRANS_SINE)
		paper_motion.tween_property(self, "paper_stir", 1.0, _seconds(0.42))
		paper_motion.tween_property(self, "paper_stir", 0.0, _seconds(2.3))
		_fade_rain(RAIN_RESTORED, 3.7)
	else:
		_fade_rain(RAIN_RESTORED, 0.0)


func _fade_rain(target: float, seconds: float) -> void:
	if rain_fade != null:
		rain_fade.kill()
	if seconds <= 0.0:
		rain.volume_db = target
	else:
		rain_fade = create_tween()
		rain_fade.tween_property(rain, "volume_db", target, _seconds(seconds)).set_trans(Tween.TRANS_SINE)


func _reveal_figure() -> void:
	state.hanging_coda_yuelan_seen = true
	figure = FIGURE.instantiate()
	figure.name = "ShenYuelanAtWestThreshold"
	figure.position = APPEAR
	figure.rotation.y = PI - 0.21
	add_child(figure)
	for child in figure.find_children("*", "GeometryInstance3D", true, false):
		figure_parts.append(child as GeometryInstance3D)
	_set_figure_fade(1.0)
	_build_threshold_lighting()
	var dissolve := create_tween().set_trans(Tween.TRANS_SINE)
	dissolve.tween_method(_set_figure_fade, 1.0, 0.0, _seconds(0.52))


func _build_threshold_lighting() -> void:
	threshold_lighting = Node3D.new()
	threshold_lighting.name = "SoftColdThreshold"
	add_child(threshold_lighting)
	cool_fill = OmniLight3D.new()
	cool_fill.position = Vector3(0.45, 2.12, 7.71)
	cool_fill.light_color = Color(0.47, 0.58, 0.67)
	cool_fill.omni_range = 2.2
	cool_fill.omni_attenuation = 1.7
	threshold_lighting.add_child(cool_fill)
	cloth_key = SpotLight3D.new()
	cloth_key.position = Vector3(-0.82, 1.84, 6.87)
	cloth_key.light_color = Color(0.64, 0.73, 0.80)
	cloth_key.spot_range = 3.25
	cloth_key.spot_angle = 43.0
	cloth_key.spot_attenuation = 1.74
	threshold_lighting.add_child(cloth_key)
	cloth_key.look_at(APPEAR + Vector3(0, 0.86, 0), Vector3.UP)
	var veil := QuadMesh.new()
	veil.size = Vector2(2.45, 3.0)
	haze_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform float veil = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.64, 0.33)) * vec2(1.16, 0.93);
	float rolloff = 1.0 - smoothstep(0.0, 0.59, length(d));
	float ends = smoothstep(0.0, 0.20, UV.x) * smoothstep(0.0, 0.23, 1.0 - UV.x)
		* smoothstep(0.0, 0.13, UV.y) * smoothstep(0.0, 0.29, 1.0 - UV.y);
	ALBEDO = mix(vec3(0.013, 0.019, 0.027), vec3(0.053, 0.081, 0.110), rolloff);
	ALPHA = rolloff * ends * veil * 0.30;
}"""
	haze_material.shader = shader
	veil.material = haze_material
	var card := _mesh(threshold_lighting, "DimCorridorAir", veil, Vector3(0, 1.47, 8.67))
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_figure_fade(1.0)


func _set_figure_fade(value: float) -> void:
	_grade_threshold(1.0 - value)
	for part in figure_parts:
		part.transparency = value


func _grade_threshold(visibility: float) -> void:
	if is_instance_valid(cool_fill):
		cool_fill.light_energy = 0.59 * visibility
	if is_instance_valid(cloth_key):
		cloth_key.light_energy = 1.32 * visibility
	if haze_material != null:
		haze_material.set_shader_parameter("veil", visibility)


func _retreat_figure() -> void:
	if not is_instance_valid(figure):
		return
	var forward := -figure.basis.z
	var retreat := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	retreat.tween_method(func(p: float) -> void:
		figure.position = APPEAR + forward * (p * RETREAT_DISTANCE)
		figure.pose_retreat(p, RETREAT_DISTANCE)
		_grade_threshold(1.0 - 0.87 * smoothstep(0.12, 0.77, p))
		var fade := smoothstep(0.43, 0.98, p)
		for part in figure_parts:
			part.transparency = fade
	, 0.0, 1.0, _seconds(2.38))
	retreat.tween_callback(_clear_figure)


func _clear_figure() -> void:
	if is_instance_valid(figure):
		figure.hide()
		figure.queue_free()
	if is_instance_valid(threshold_lighting):
		threshold_lighting.hide()
		threshold_lighting.queue_free()
	figure_parts.clear()


func _finish() -> void:
	thought.stop()
	spatial.stop()
	if is_instance_valid(listener):
		listener.clear_current()
		listener.queue_free()
	var prior := room.door_story.listener as AudioListener3D
	if is_instance_valid(prior):
		prior.make_current()
	_clear_figure()
	if is_instance_valid(offering):
		offering.hide()
	_land_rope()
	_restore_incense(false)
	hud.set_story_caption("", false, true, 31)
	(room.get("flashlight") as SpotLight3D).spot_range = original_flashlight_range
	cam.fov = 50.0
	player.velocity = Vector3.ZERO
	state.hanging_coda_stage = Stage.COMPLETE
	state.preserve_final_evidence()
	state.save_checkpoint(GameState.DEPARTURE_CHECKPOINT)
	hud.set_objective(GameState.RETURN_HOME_OBJECTIVE)
	hud.set_process_input(true)
	busy = false
	GameState.set_night_clock_hold(self, false)


func _exit_tree() -> void:
	GameState.set_night_clock_hold(self, false)
	if is_instance_valid(thought):
		thought.stop()
		thought.stream = null
	if is_instance_valid(spatial):
		spatial.stop()
		spatial.stream = null
