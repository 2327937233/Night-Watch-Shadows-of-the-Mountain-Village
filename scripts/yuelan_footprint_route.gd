extends Node3D
## Scene-local sections of one story route. Coordinates follow the existing
## left gallery portal; the courtyard's key room is NOT the hanging room.
## Marks are absorbed into the real floor shader: no planes, floor offsets,
## individual collision bodies or per-frame regeneration.

@export_enum("hall", "hanging") var section := "hall"
@export_range(0.35, 0.50, 0.01) var step_distance := 0.42
@export_range(0.20, 0.26, 0.005) var shoe_length := 0.236
@export_range(0.08, 0.12, 0.005) var shoe_width := 0.102
@export_range(0.06, 0.12, 0.005) var lateral_offset := 0.075
@export_range(0.4, 0.85, 0.01) var water_contrast := 0.72
@export var route_points := PackedVector3Array()
@export var doorway_sob: AudioStream = preload("res://assets/audio/public_effects/hall_sob.wav")
@export_range(0.5, 3.0, 0.1) var sob_duration := 2.3

const MAX_MARKS := 96
const HALL_PATH := [
	Vector3(-4.43, 0.02, -6.17), Vector3(-4.69, 0.02, -5.70),
	Vector3(-4.87, 0.02, -5.16), Vector3(-5.05, 0.02, -4.62),
	Vector3(-5.48, 0.02, -4.32), Vector3(-6.08, 0.02, -4.32),
]
const HANGING_PATH := [
	Vector3(0.0, 0.02, 7.25), Vector3(-0.12, 0.02, 6.50),
	Vector3(-0.42, 0.02, 5.30), Vector3(-0.62, 0.02, 2.8),
	Vector3(-0.77, 0.02, 0.0), Vector3(-0.94, 0.02, -2.65),
	Vector3(-0.85, 0.02, -4.25), Vector3(-0.22, 0.02, -5.25),
]
const DOOR_APPROACH := Vector2(-6.08, -4.32)

var room: Node3D
var state: Node
var floor_material: ShaderMaterial
var marks := PackedVector4Array()
var walking_curve: Curve3D
var active := false
var sob: AudioStreamPlayer3D
var sob_tween: Tween
var last_fade_seconds := -2.0


func setup(owner_room: Node3D, story_state: Node, route_section: String) -> void:
	room = owner_room
	state = story_state
	section = route_section
	var tiles := room.find_child("UnevenWetStoneTiles_MultiMesh" if section == "hall" else "UnevenOldWetFloorTiles", true, false) as MultiMeshInstance3D
	if tiles != null:
		floor_material = tiles.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	if route_points.is_empty():
		var anchors := get_node_or_null("HallPath" if section == "hall" else "HangingPath")
		if anchors != null:
			for point in anchors.get_children():
				if point is Marker3D:
					route_points.append((point as Marker3D).position)
		if route_points.is_empty():
			route_points = PackedVector3Array(HALL_PATH if section == "hall" else HANGING_PATH)
	_generate_marks()
	_bind_floor()
	# A previously hidden section is restored from the shared story flag.
	set_active(bool(state.get("main_hall_yuelan_footprints_available")))
	if section == "hall":
		_build_sob()
	elif active:
		# Loading an already-made room is the existing entrance transition.
		# Reaching it completes tracking without triggering any ending.
		state.set("yuelan_trail_room_reached", true)
		state.set("yuelan_trail_door_heard", true)
	if floor_material != null:
		floor_material.set_shader_parameter("yuelan_return_hanging", section == "hanging")
	_sync_return_fade()
	_sync_objective()


func _generate_marks() -> void:
	walking_curve = Curve3D.new()
	walking_curve.bake_interval = 0.035
	for i in route_points.size():
		var tangent := Vector3.ZERO
		if i > 0 and i + 1 < route_points.size():
			tangent = (route_points[i + 1] - route_points[i - 1]).normalized()
			var reach := minf(route_points[i].distance_to(route_points[i - 1]), route_points[i].distance_to(route_points[i + 1])) * 0.20
			tangent *= reach
		walking_curve.add_point(route_points[i], -tangent, tangent)
	marks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 171627 if section == "hall" else 171628
	var distance := 0.13
	var length := walking_curve.get_baked_length()
	while distance <= length and marks.size() < MAX_MARKS:
		var p := walking_curve.sample_baked(distance, true)
		var ahead := walking_curve.sample_baked(minf(distance + 0.10, length), true)
		var behind := walking_curve.sample_baked(maxf(distance - 0.10, 0.0), true)
		var direction := (ahead - behind).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x)
		p += side * lateral_offset * (-1.0 if marks.size() % 2 == 0 else 1.0)
		var yaw := atan2(-direction.x, -direction.z) + rng.randf_range(-0.055, 0.055)
		var clarity := rng.randf_range(0.78, 0.94)
		if section == "hanging" and distance < 1.4:
			clarity = 0.98
		marks.append(Vector4(p.x, p.z, yaw, clarity))
		distance += step_distance + rng.randf_range(-0.022, 0.022)


func _bind_floor() -> void:
	if floor_material == null:
		push_error("Yuelan trail could not find the existing floor in " + section)
		return
	var data := PackedVector4Array()
	data.resize(MAX_MARKS)
	var bounds := Vector4(INF, INF, -INF, -INF)
	for i in marks.size():
		var mark := marks[i]
		data[i] = mark
		bounds.x = minf(bounds.x, mark.x - 0.20)
		bounds.y = minf(bounds.y, mark.y - 0.20)
		bounds.z = maxf(bounds.z, mark.x + 0.20)
		bounds.w = maxf(bounds.w, mark.y + 0.20)
	floor_material.set_shader_parameter("yuelan_trail", data)
	floor_material.set_shader_parameter("yuelan_trail_count", marks.size())
	floor_material.set_shader_parameter("yuelan_trail_bounds", bounds)
	floor_material.set_shader_parameter("yuelan_shoe_size", Vector2(shoe_width, shoe_length))
	floor_material.set_shader_parameter("yuelan_water_contrast", water_contrast)


func set_active(value: bool) -> void:
	active = value
	if floor_material != null:
		floor_material.set_shader_parameter("yuelan_footprints_active", value)
	_sync_objective()


func _sync_objective() -> void:
	if not active:
		return
	var hud := room.get("hud") as Control
	if hud == null:
		return
	var door_objective: String = state.hanging_door_objective()
	if not door_objective.is_empty():
		hud.call("set_objective", door_objective)
	elif bool(state.get("yuelan_trail_room_reached")):
		hud.call("set_objective", "调查吊绳房的异常")
	elif bool(state.get("main_hall_yuelan_footprints_examined")):
		hud.call("set_objective", "沿着脚印寻找女人")
	else:
		hud.call("set_objective", "调查木柱旁的潮湿脚印")


func _build_sob() -> void:
	sob = AudioStreamPlayer3D.new()
	sob.name = "QuietSobAtExistingHangingDoor"
	sob.stream = doorway_sob
	sob.position = Vector3(-6.55, 1.15, -4.32)
	sob.volume_db = -20.0
	sob.unit_size = 3.0
	sob.max_distance = 12.0
	sob.attenuation_filter_cutoff_hz = 2400.0
	add_child(sob)


func _physics_process(_delta: float) -> void:
	_sync_return_fade()
	if state.has_hanging_coda_completed():
		return
	if not active or section != "hall" or bool(state.get("yuelan_trail_door_heard")):
		return
	var player := room.get("player") as Node3D
	if player == null:
		return
	var p := Vector2(player.position.x, player.position.z)
	if p.distance_to(DOOR_APPROACH) < 0.80:
		play_door_sob()


func play_door_sob() -> void:
	if not active or sob == null or state.has_hanging_coda_completed() or bool(state.get("yuelan_trail_door_heard")):
		return
	state.set("yuelan_trail_door_heard", true)
	sob.volume_db = -30.0
	sob.play(2.0)
	sob_tween = create_tween()
	sob_tween.tween_property(sob, "volume_db", -17.0, 0.35)
	sob_tween.tween_interval(maxf(0.0, sob_duration - 0.75))
	sob_tween.tween_property(sob, "volume_db", -60.0, 0.40)
	sob_tween.tween_callback(sob.stop)


func _sync_return_fade() -> void:
	if state == null or floor_material == null or not state.has_hanging_coda_completed():
		return
	var elapsed: float = state.yuelan_trail_fade_seconds
	if elapsed == last_fade_seconds:
		return
	last_fade_seconds = elapsed
	floor_material.set_shader_parameter("yuelan_return_fade_seconds", elapsed)
	if sob_tween != null and sob_tween.is_valid():
		sob_tween.kill()
	if sob != null and sob.playing:
		sob.stop()
	if elapsed >= 14.0:
		floor_material.set_shader_parameter("yuelan_footprints_active", false)


func _exit_tree() -> void:
	if sob != null:
		sob.stop()
