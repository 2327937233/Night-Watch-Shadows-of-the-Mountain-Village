extends Node3D
## Four patches of absorbed water in the existing floor material. No planes,
## new lights, collision bodies or floating decals are added to the hall.

const TARGET := "final_yuelan_wet_footprints"
const PRINTS := [
	Vector4(-4.10, -6.31, 2.85, 0.93),
	Vector4(-3.90, -6.35, 2.78, 0.85),
	Vector4(-4.30, -6.59, 2.93, 0.72),
	Vector4(-4.11, -6.76, 2.88, 0.60),
]
const CENTER := Vector3(-3.99, 0.04, -6.42)
var hall: Node3D
var state: Node
var floor_material: ShaderMaterial
var available := false


func setup(owner_hall: Node3D, story_state: Node) -> void:
	hall = owner_hall
	state = story_state
	var tiles := hall.find_child("UnevenWetStoneTiles_MultiMesh", true, false) as MultiMeshInstance3D
	if tiles != null:
		floor_material = tiles.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	if floor_material != null:
		floor_material.set_shader_parameter("yuelan_footprints", PackedVector4Array(PRINTS))
		floor_material.set_shader_parameter("yuelan_footprints_active", false)
	available = bool(state.get("main_hall_yuelan_footprints_available"))
	if available and floor_material != null:
		floor_material.set_shader_parameter("yuelan_footprints_active", true)


func activate() -> void:
	available = true
	state.set("main_hall_yuelan_footprints_available", true)
	if floor_material != null:
		floor_material.set_shader_parameter("yuelan_footprints_active", true)
	var route := hall.get("wet_footprint_route") as Node
	if route != null:
		route.call("set_active", true)
	var hud := hall.get("hud") as Control
	if hud != null and not bool(state.get("main_hall_yuelan_footprints_examined")):
		hud.call("set_objective", "调查木柱旁的潮湿脚印")


func interaction_target(player_position: Vector3) -> String:
	if not available or state.has_hanging_coda_completed() or bool(state.get("main_hall_yuelan_footprints_examined")):
		return ""
	if Vector2(player_position.x - CENTER.x, player_position.z - CENTER.z).length() > 1.60:
		return ""
	var flashlight := hall.get("flashlight") as SpotLight3D
	var camera := hall.get("camera") as Camera3D
	if flashlight == null or camera == null or not flashlight.is_visible_in_tree() or flashlight.light_energy <= 0.0:
		return ""
	for mark in PRINTS:
		if bool(get_parent().call("_point_lit_and_visible", Vector3(mark.x, CENTER.y, mark.y), flashlight, camera)):
			return TARGET
	return ""


func inspect() -> void:
	state.set("main_hall_yuelan_footprints_examined", true)
	var hud := hall.get("hud") as Control
	get_parent().set("caption_active", true)
	if hud != null:
		hud.call("set_story_caption", "几枚布鞋印……还湿着。\n\n她刚才就站在这里。", true, true)
		hud.call("set_objective", "调查吊绳房的异常" if bool(state.get("yuelan_trail_room_reached")) else "沿着脚印寻找女人")
	get_tree().create_timer(4.0, false).timeout.connect(func() -> void: get_parent().set("caption_active", false))
