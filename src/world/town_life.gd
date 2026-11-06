class_name TownLife
extends Node3D
## Little lives that make Suzunari breathe (no gameplay): sparrows pecking and hopping on the ground that
## burst into the air when you come close and settle somewhere else, and white / yellow butterflies
## wobbling over the flowers by day. Two MultiMeshes each, updated on the CPU (a few dozen instances).

const SPARROWS := 30
const BUTTERFLIES := 14

var player: Node3D
var _ground: Array[Vector3] = []
var _flowers: Array[Vector3] = []
var _birds: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _bird_body: MultiMesh
var _bird_head: MultiMesh
var _fly_mm: MultiMesh
var _t := 0.0


func setup(ground: Array[Vector3], flowers: Array[Vector3]) -> void:
	_ground = ground
	_flowers = flowers if not flowers.is_empty() else ground
	if _ground.is_empty():
		return
	_bird_body = _mm(_ellipsoid(0.085, 0.12), Color(0.55, 0.42, 0.3), SPARROWS, true)
	_bird_head = _mm(_ellipsoid(0.055, 0.1), Color(0.42, 0.3, 0.22), SPARROWS, true)
	var wing := QuadMesh.new()
	wing.size = Vector2(0.16, 0.11)
	_fly_mm = _mm(wing, Color.WHITE, BUTTERFLIES, false)
	for i in SPARROWS:
		var home: Vector3 = _ground[randi() % _ground.size()] + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		_birds.append({"p": home, "home": home, "state": "ground", "t": randf() * 3.0, "v": Vector3.ZERO, "yaw": randf() * TAU})
		_bird_body.set_instance_color(i, Color(0.55, 0.42, 0.3).lightened(randf_range(-0.1, 0.1)))
	for i in BUTTERFLIES:
		var f: Vector3 = _flowers[randi() % _flowers.size()]
		_flies.append({"c": f, "ph": randf() * TAU, "sp": randf_range(0.5, 1.0)})
		_fly_mm.set_instance_color(i, [Color(1, 1, 0.95), Color(1.0, 0.92, 0.45), Color(0.95, 0.95, 1.0)][i % 3])


func _ellipsoid(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = 6
	s.rings = 3
	return s


func _mm(mesh: Mesh, col: Color, n: int, lit: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	if not lit:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.emission_enabled = true
		m.emission = Color(0.4, 0.4, 0.35)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


func _process(delta: float) -> void:
	if _bird_body == null:
		return
	_t += delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	var pp := player.global_position if player else Vector3.INF
	var day := Clock.minute() < Clock.NIGHT
	for i in _birds.size():
		var b: Dictionary = _birds[i]
		b.t -= delta
		match b.state:
			"ground":
				if b.p.distance_to(pp) < 3.2 or not day:
					b.state = "fly"
					var away: Vector3 = (b.p - pp)
					away.y = 0.0
					b.v = (away.normalized() if away.length() > 0.01 else Vector3.BACK) * 5.0 + Vector3(0, 4.0, 0)
					b.t = randf_range(1.5, 2.5)
				elif b.t <= 0.0:
					# hop a little, peck, turn
					b.yaw += randf_range(-1.2, 1.2)
					var hop := Vector3(sin(b.yaw), 0, cos(b.yaw)) * randf_range(0.1, 0.3)
					if (b.p + hop).distance_to(b.home) < 1.5:
						b.p += hop
					b.t = randf_range(0.3, 1.4)
			"fly":
				b.p += b.v * delta
				b.v.y -= 0.6 * delta
				if b.t <= 0.0:
					b.state = "away"
					b.t = randf_range(6.0, 14.0)
			"away":
				b.p = Vector3(0, -50, 0)
				if b.t <= 0.0 and day:
					b.home = _ground[randi() % _ground.size()] + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
					if b.home.distance_to(pp) > 7.0:
						b.p = b.home
						b.state = "ground"
		var peck := 0.0 if b.state != "ground" else maxf(0.0, sin(_t * 9.0 + i)) * 0.04
		var hopy := 0.0 if b.state != "ground" else absf(sin(b.t * 12.0)) * 0.03
		var basis := Basis(Vector3.UP, b.yaw)
		var body_at: Vector3 = b.p + Vector3(0, 0.08 + hopy, 0)
		_bird_body.set_instance_transform(i, Transform3D(basis, body_at))
		_bird_head.set_instance_transform(i, Transform3D(basis, body_at + basis * Vector3(0, 0.06 - peck, 0.07 + peck)))
	for i in _flies.size():
		var f: Dictionary = _flies[i]
		var ph: float = f.ph + _t * f.sp
		var at: Vector3 = f.c + Vector3(sin(ph * 1.3) * 1.6, 0.6 + sin(ph * 2.1) * 0.35, cos(ph * 0.9) * 1.4)
		var flap := absf(sin(_t * 14.0 + f.ph)) * 0.85 + 0.15
		if not day:
			at.y = -50.0
		_fly_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(flap, 1, 1)), at))
