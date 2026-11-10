extends Node3D
## Shared three-dimensional figure. Local +Z is her back; no facial geometry.

const FABRIC = preload("res://shaders/yuelan_aged_cloth.gdshader")
const HAIR = preload("res://shaders/yuelan_damp_hair.gdshader")
var feet: Array[Node3D] = []
var rest_feet: Array[Vector3] = []
var body: Node3D


func _ready() -> void:
	body = Node3D.new()
	body.name = "BowedPosture"
	body.rotation.z = .013
	add_child(body)
	var blouse := _fabric(Color(0.405, 0.397, 0.371), 0.96, 1.0)
	var skirt := _fabric(Color(0.335, 0.331, 0.313), 0.98, 2.0)
	var binding := _fabric(Color(0.28, 0.278, 0.26), 0.98, 0.0)
	var hair := ShaderMaterial.new()
	hair.shader = HAIR
	var skin := _matte(Color(0.34, 0.325, 0.307), 0.96)
	var shaded_skin := _matte(Color(0.22, 0.213, 0.202), 0.97)
	var shoe := _matte(Color(0.070, 0.063, 0.057), 0.99)
	var sole := _matte(Color(0.044, 0.040, 0.037), 0.98)
	# Republic-era stand-collar blouse over a separate, ankle-length plain skirt.
	_garment("HangingSkirt", [
		Vector3(.230,.115,.146), Vector3(.236,.182,.151), Vector3(.228,.34,.151),
		Vector3(.207,.51,.139), Vector3(.169,.70,.116), Vector3(.143,.80,.099),
		Vector3(.122,.88,.086), Vector3(.114,.98,.079)
	], skirt, 80, 52, 2)
	_garment("FittedClothBlouse", [
		Vector3(.159,.815,.110), Vector3(.163,.842,.116), Vector3(.147,.899,.107),
		Vector3(.128,.985,.090), Vector3(.137,1.08,.100), Vector3(.153,1.180,.110),
		Vector3(.164,1.251,.092), Vector3(.139,1.304,.077), Vector3(.089,1.353,.059), Vector3(.059,1.371,.055)
	], blouse, 64, 48, 1)
	_garment("StandCollar", [Vector3(.057,1.358,.052), Vector3(.058,1.376,.053), Vector3(.054,1.405,.051)], binding, 32, 10, 0)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0.0 else "Right"
		_garment("SlopingSleeve" + suffix, [
			Vector3(.044,.830,.044), Vector3(.047,.853,.047), Vector3(.045,.910,.048),
			Vector3(.047,1.004,.050), Vector3(.052,1.092,.057), Vector3(.055,1.187,.061),
			Vector3(.056,1.238,.057), Vector3(.040,1.289,.045), Vector3(.002,1.318,.003)
		], blouse, 40, 35, 3, side)
		var hand_center := _sleeve_center(.831, side) + Vector3(-side * .007, -.042, -.008)
		var palm := _ellipsoid(body, "SoftHand" + suffix, hand_center, Vector3(.025,.045,.017), skin, 16, 10)
		palm.rotation.z = side * -.14
		for digit in 4:
			var across := digit - 1.5
			var finger := _ellipsoid(body, "BentFinger", hand_center + Vector3(across * .0105, -.040 + absf(across) * .006, -.003 - digit * .0014), Vector3(.0054,.020 - absf(across) * .0025,.007), skin, 8, 5)
			finger.rotation.x = -.15 - .05 * digit
		var foot := Node3D.new()
		foot.name = "ClothShoe" + suffix
		foot.position = Vector3(side * .074, .007, -.025 + side * .038)
		foot.rotation.y = -side * .10
		add_child(foot)
		feet.append(foot)
		rest_feet.append(foot.position)
		_ellipsoid(foot, "CompressedClothSole", Vector3(0,.010,-.033), Vector3(.043,.010,.092), sole)
		_ellipsoid(foot, "SoftFabricUpper", Vector3(0,.028,-.034), Vector3(.041,.027,.089), shoe)
		_ellipsoid(foot, "AnkleInShade", Vector3(0,.111,.004), Vector3(.028,.081,.033), shaded_skin)
	# The head is bowed and covered, including at the shallow side-back angle.
	var cap := _ellipsoid(body, "BowedHairCap", Vector3(-.011,1.486,-.082), Vector3(.089,.116,.087), hair, 40, 24)
	cap.rotation.x = -.24
	cap.rotation.z = -.085
	_build_locks(hair)


func _matte(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = .10
	return mat


func _fabric(tint: Color, roughness: float, kind: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FABRIC
	mat.set_shader_parameter("cloth_color", tint)
	mat.set_shader_parameter("base_roughness", roughness)
	mat.set_shader_parameter("cut", kind)
	return mat


func _sample(profile: Array, t: float) -> Vector3:
	var at := t * (profile.size() - 1)
	var i := mini(int(at), profile.size() - 2)
	var value: Vector3 = profile[i]
	return value.cubic_interpolate(profile[i + 1], profile[maxi(0,i - 1)], profile[mini(i + 2,profile.size() - 1)], at - i)


func _sleeve_center(y: float, side: float) -> Vector3:
	var t := clampf((y - .830) / .488, 0.0, 1.0)
	# The elbow turns outward a little; the wrist falls inward and forward.
	var x := .183 + .015 * sin(t * PI) - .052 * smoothstep(.64,1.0,t)
	var z := -.066 + .050 * sin(t * PI * .91) - .022 * smoothstep(.74,1.0,t)
	return Vector3(side * x, y - .013 * side, z + .014 * side)


func _garment(label: String, profile: Array, material: Material, sides: int, rows: int, cut: int, side := 0.0) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows + 1):
		var t := float(row) / rows
		var ring := _sample(profile, t)
		for j in range(sides + 1):
			var u := float(j) / sides
			var a := u * TAU
			var f := 0.0
			var hem := 0.0
			var center := Vector3(-.013 * smoothstep(1.2,1.4,ring.y), ring.y, -.071 * smoothstep(1.11,1.42,ring.y))
			if cut == 2:
				center = Vector3(.018 * (1.0 - t), ring.y, .013 * sin(t * PI) * (1.0 - smoothstep(.65,1.0,t)))
				var fold := a + .12 * sin(3.0 * a + 3.4 * t) + .12 * t
				f = (sin(fold * 12.0 + .39) * .58 + sin(fold * 17.0 - 1.2) * .32 + sin(a * 6.0 + 3.4 * t) * .35) * (.006 + .010 * sin(PI * t * .88)) * (1.0 - .56 * pow(t, 5.0))
				hem = (sin(a * 3.0 + .9) * .008 + sin(a * 13.0) * .003) * pow(1.0 - t, 6.0)
			elif cut == 3:
				center = _sleeve_center(ring.y, side)
				var bend := exp(-pow((ring.y - 1.025) / .105, 2.0))
				f = sin(a * 5.0 + 3.2 * t + side * .4) * .003 * (1.0 - t) + sin(55.0 * ring.y + 3.4 * cos(a - .4 * side)) * .0024 * bend
				hem = (.004 * sin(a + side) + .0015 * sin(a * 7.0)) * pow(1.0 - t, 6.0)
			elif cut == 1:
				var waist := exp(-pow((ring.y - .92) / .12, 2.0))
				f = sin(a * 8.0 + ring.y * 5.6) * (.002 + .004 * waist) + sin(ring.y * 62.0 + cos(a * 3.0) * 2.4) * .0022 * waist
				hem = sin(a * 4.0 + .6) * .004 * pow(1.0 - t, 7.0)
			var pos := center + Vector3(cos(a) * maxf(.001, ring.x + f), hem, sin(a) * maxf(.001, ring.z + f))
			# Shoulder slopes towards the arm, and the rear shoulder blades round
			# into the collar rather than meeting a horizontal cylinder.
			if cut == 1:
				pos.y -= .031 * absf(cos(a)) * exp(-pow((ring.y - 1.285) / .052, 2.0))
			var breath := smoothstep(.91, 1.26, ring.y) if cut != 2 else 0.0
			mesh.set_color(Color(pow(1.0 - t, 2.8), breath, float(cut) / 3.0))
			mesh.set_uv(Vector2(u, ring.y))
			mesh.add_vertex(pos)
	_indices(mesh, rows, sides)
	_finish(body, label, mesh, material)


func _build_locks(material: Material) -> void:
	# Curved, overlapping three-dimensional locks grow from a rounded cap.
	# Variable starts, widths and tapered ends avoid a second block of hair.
	for i in 30:
		var under := i < 16
		var index := i if under else i - 16
		var count := 16.0 if under else 14.0
		var spread := ((index + .5) / count) * 2.0 - 1.0
		var phase := i * 2.39996
		var tip := .955 + .070 * absf(spread) + .078 * sin(phase) + (.036 if under else 0.0)
		var start_y := 1.585 - .063 * pow(absf(spread), 1.45) + .005 * cos(phase)
		var start_x := -.012 + spread * (.075 if under else .066)
		var start_z := -.065 + sqrt(maxf(.01, 1.0 - spread * spread)) * .047
		var width := (.0133 if under else .0112) * (1.0 + .28 * sin(phase * 1.9))
		var strand := SurfaceTool.new()
		strand.begin(Mesh.PRIMITIVE_TRIANGLES)
		const ROWS := 29
		const SIDES := 8
		for row in range(ROWS + 1):
			var t := float(row) / ROWS
			var y := lerpf(start_y, tip, t)
			var spread_gain := smoothstep(.04,.51,t)
			var x := lerpf(start_x, spread * .117 + .011, spread_gain)
			x += (sin(t * 8.2 + phase) * .008 + sin(t * 16.0 + phase * 2.0) * .0035) * pow(t, .75)
			var z := lerpf(start_z, .107 + (.014 if not under else 0.0), smoothstep(.02,.47,t))
			z += (1.0 - absf(spread)) * .028 * sin(t * PI) + .015 * t * t + .006 * sin(t * 12.0 + phase)
			var taper := lerpf(.27, 1.0, smoothstep(0.0,.15,t)) * lerpf(1.0,.015,smoothstep(.65,1.0,t))
			for k in range(SIDES + 1):
				var u := float(k) / SIDES
				var a := TAU * u
				var p := Vector3(x + cos(a) * width * taper, y, z + sin(a) * (width * .32 + .0014) * taper)
				strand.set_color(Color(pow(t, 2.5), .48 + .36 * sin(phase), 0.0))
				strand.set_uv(Vector2(u + i * .113, y))
				strand.add_vertex(p)
		_indices(strand, ROWS, SIDES, true)
		_finish(body, "HangingLock%02d" % i, strand, material)


func pose_retreat(progress: float, travel: float) -> void:
	pose_drift(progress, Vector3(0.0, 0.0, -travel))


func pose_drift(progress: float, local_travel: Vector3, stride_pairs: int = 1) -> void:
	# Keep the planted shoes on the floor even when the root travels diagonally.
	var elapsed_pairs := progress * stride_pairs
	var step_progress := elapsed_pairs - minf(floorf(elapsed_pairs), stride_pairs - 1.0)
	var stride := local_travel / stride_pairs
	for i in 2:
		var phase := clampf((step_progress - (.05 if i == 0 else .45)) / (.50 if i == 0 else .53), 0.0, 1.0)
		var planted := smoothstep(0.0, 1.0, phase)
		feet[i].position = rest_feet[i] + stride * (planted - step_progress) + Vector3.UP * (sin(phase * PI) * .021)
		feet[i].rotation.x = sin(phase * TAU) * .075
	body.position.x = sin(progress * TAU) * .008
	body.position.y = -sin(progress * PI) * .004 + absf(sin(progress * TAU)) * .003
	body.rotation.z = .013 + sin(progress * TAU) * .010


func apply_column_shading() -> void:
	# The materials are built per figure. The bedroom and final doorway retain
	# their own exposure and lighting.
	var adjusted: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var material := mesh_node.material_override
		if material == null or adjusted.has(material):
			continue
		adjusted[material] = true
		if material is ShaderMaterial and material.shader == FABRIC:
			var cloth: Color = material.get_shader_parameter("cloth_color")
			material.set_shader_parameter("cloth_color", Color(cloth.r * .80, cloth.g * .83, cloth.b * .88))
		elif material is StandardMaterial3D:
			material.albedo_color = material.albedo_color.darkened(.11)


func begin_retreat() -> void:
	# Keep the existing first hall encounter compatible with the shared asset.
	var step := create_tween()
	step.tween_method(func(t: float) -> void: pose_retreat(t, .19), 0.0, 1.0, 1.7)


func _ellipsoid(parent: Node3D, label: String, pos: Vector3, size: Vector3, material: Material, segments := 20, rings := 12) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = segments
	shape.rings = rings
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = shape
	item.material_override = material
	item.position = pos
	item.scale = size * 2.0
	parent.add_child(item)
	return item


func _indices(builder: SurfaceTool, rows: int, columns: int, descending := false) -> void:
	for row in rows:
		for col in columns:
			var a := row * (columns + 1) + col
			var indices := [a, a + 1, a + columns + 1, a + 1, a + columns + 2, a + columns + 1]
			if descending:
				indices.reverse()
			for index in indices:
				builder.add_index(index)


func _finish(parent: Node3D, label: String, builder: SurfaceTool, material: Material) -> void:
	builder.generate_normals()
	builder.generate_tangents()
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = builder.commit()
	item.material_override = material
	parent.add_child(item)
