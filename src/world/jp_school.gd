class_name JPSchool
extends RefCounted
## Interiors for Suzunari (LevelBuilder indoor + palette theme "suzunari"): floors by character, plaster walls with
## wood wainscot and windows that look out on the spring sky, and the school furniture kit. Map legend
## (data/maps/school_*.txt, see tools in docs):
##   floors  . corridor linoleum  _ wood  , tiles  : tatami  ; terrazzo  = music-room planks   # wall
##   k blackboard (run)  n notice board  d desk+chair  t teacher's desk  a staff desk  l lockers  g shoe cubbies
##   s bookshelf  b infirmary bed  x anatomy model  v lab bench  p grand piano  e easel  m tall mirror  c counter
##   y drinks vending  f potted plant  o sofa  r trophy case  w toilet stall  u sinks  h cabinet  z table+chairs
##   j sorted bins  i bench  q AC unit  Y water tank   S stairs up  D stairs down  K roof door  X exit to town
## (R and E are taken by LevelBuilder.ACTOR_CHARS.) Links (S/D/K/X) and room features are handled by the School level (src/world/school.gd) via `links`.

const T := 2.0
const FLOORS := {".": "jp_lino", "_": "jp_woodfloor", ",": "jp_wctile", ":": "jp_tatami", ";": "jp_terrazzo", "=": "jp_gymfloor"}
const WALL_ITEMS := ["k", "n", "s", "l", "h", "g", "r", "m", "u", "w", "c"]

var b  ## LevelBuilder
var jp  ## JPKit
var rng: RandomNumberGenerator
var links: Array = []  ## [{char, tile: Vector2i, pos: Vector3}] for the level to wire up
var _desks: Array[Transform3D] = []
var _panels := {}


func _init(builder, kit) -> void:
	b = builder
	jp = kit
	rng = builder.rng


func materials() -> void:
	for k in ["lino", "terrazzo", "wctile", "tatami", "gymfloor"]:
		var m: StandardMaterial3D = b._textured("jp_" + k, Color.WHITE, 0.25, 0.5 if k != "tatami" else 0.9, 0.0, 0.8)
		m.vertex_color_use_as_albedo = true
		b._mats["jp_" + k] = m
	b._mats["wall"] = b._textured("jp_plaster", Color(0.98, 0.97, 0.93), 0.25, 0.9, 0.0, 0.5)


func floor_kind(x: int, z: int) -> String:
	var c: String = b.cell(x, z)
	if b.palette.get("roof", false):
		return "jp_sando"  # roof: concrete slabs with tar seams
	if FLOORS.has(c):
		return FLOORS[c]
	for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-2, 0), Vector2i(2, 0)]:
		var n: String = b.cell(x + o.x, z + o.y)
		if FLOORS.has(n):
			return FLOORS[n]
	return "jp_lino"


func floor_color(x: int, z: int) -> Color:
	var n: float = b._ground_noise.get_noise_2d(x * 2.0, z * 2.0)
	return Color.WHITE * (0.94 + n * 0.06)


# --- Walls -------------------------------------------------------------------------------------

## Plaster wall with a wood wainscot on the room side; tall back walls on the north edge get windows (sky, clouds,
## a sakura crown) unless something hangs there; low cut-away walls get a wooden cap. Roof: a wire fence instead.
func wall(x0: int, x1: int, z: int, low: bool, length: float, cx: float, cz: float) -> void:
	var roof: bool = b.palette.get("roof", false)
	if roof:
		_fence(length, cx, cz)
		return
	var h: float = 0.45 if low else LevelBuilder.WALL_H
	b.add_mesh(b.root, b.box(Vector3(length, h, T)), b._mats["wall"], Vector3(cx, h * 0.5, cz))
	var face := cz + T * 0.5
	var faces_room: bool = b.walkable(x0, z + 1) or b.walkable(x1, z + 1)
	if low:
		# Cut-away walls are seen from above: a light hinoki cap, never a dark band across the room.
		b.add_mesh(b.root, b.box(Vector3(length + 0.04, 0.06, T + 0.04)), jp.prop_mat("wood_light", Color.WHITE), Vector3(cx, h + 0.03, cz), 0.0, false)
		if faces_room:
			b.add_mesh(b.root, b.box(Vector3(length, 0.4, 0.05)), jp.prop_mat("wood_light", Color.WHITE), Vector3(cx, 0.2, face + 0.025), 0.0, false)
		return
	if faces_room:
		b.add_mesh(b.root, b.box(Vector3(length, 0.95, 0.05)), jp.prop_mat("wood_light", Color.WHITE), Vector3(cx, 0.475, face + 0.025), 0.0, false)
		b.add_mesh(b.root, b.box(Vector3(length, 0.06, 0.09)), b._mats["dark"], Vector3(cx, 0.97, face + 0.045), 0.0, false)
		b.add_mesh(b.root, b.box(Vector3(length, 0.14, 0.08)), b._mats["dark"], Vector3(cx, 0.07, face + 0.04), 0.0, false)
		if z == 0:
			for x in range(x0, x1 + 1):
				if b.walkable(x, 1) and not b.cell(x, 1) in WALL_ITEMS and not b.cell(x - 1, 1) in ["k"] and not b.cell(x + 1, 1) in ["k"]:
					_quad("window_out", Vector2(1.8, 1.8), Vector3(x * T + T * 0.5, 2.15, face + 0.03), 0.0, 0.9)
	b.add_mesh(b.root, b.box(Vector3(length + 0.05, 0.2, T + 0.1)), b._mats["dark"], Vector3(cx, h + 0.1, cz), 0.0, false)


func _fence(length: float, cx: float, cz: float) -> void:
	var metal: StandardMaterial3D = jp.painted(Color(0.55, 0.62, 0.6), "jp_paint", 0.5)
	b.add_mesh(b.root, b.box(Vector3(length, 0.3, T)), b._mats["concrete"], Vector3(cx, 0.15, cz))
	b.add_mesh(b.root, b.box(Vector3(length, 0.06, 0.06)), metal, Vector3(cx, 1.6, cz), 0.0, false)
	b.add_mesh(b.root, b.box(Vector3(length, 0.05, 0.05)), metal, Vector3(cx, 0.9, cz), 0.0, false)
	var n := int(length / 0.5)
	for i in n:
		b.add_mesh(b.root, b.box(Vector3(0.03, 1.3, 0.03)), metal, Vector3(cx - length * 0.5 + 0.25 + i * 0.5, 0.95, cz), 0.0, false)


## A textured panel (facade-style material) facing +Z; `glow` = emission (window daylight).
func _quad(name: String, size: Vector2, at: Vector3, rot_y: float = 0.0, glow: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var key := "%s_%s" % [name, glow]
	if not _panels.has(key):
		var m: StandardMaterial3D = jp.facade(name).duplicate()
		if glow > 0.0:
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission_energy_multiplier = glow
		_panels[key] = m
	return b.add_mesh(parent if parent else b.root, q, _panels[key], at, rot_y, false)


# --- Furniture ---------------------------------------------------------------------------------

func cell(c: String, p: Vector3, x: int, z: int) -> bool:
	if FLOORS.has(c):
		return true  # floor characters are floors here ('=' would be a crate in the base legend)
	var wall_z := p.z - T * 0.5 + 0.06  # the north wall face of this cell
	match c:
		"d":
			_desks.append(Transform3D(Basis(), p))
		"t":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(1.5, 0.78, 0.7)), b._mats["dark"], Vector3(0, 0.39, 0))
			b.add_mesh(body, b.box(Vector3(0.7, 1.05, 0.5)), jp.prop_mat("wood_light", Color.WHITE), Vector3(0.9, 0.52, 0.25))
			b.add_mesh(body, b.box(Vector3(0.3, 0.06, 0.22)), jp.painted(Color(0.85, 0.3, 0.25)), Vector3(-0.3, 0.81, 0), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.24, 0.05, 0.2)), jp.painted(Color(0.3, 0.45, 0.75)), Vector3(-0.3, 0.86, 0.02), 0.0, false)
			b.add_box_collider(body, Vector3(1.6, 0.8, 0.7), Vector3(0, 0.4, 0))
		"k":
			if b.cell(x - 1, z) != "k":
				var n := 1
				while b.cell(x + n, z) == "k":
					n += 1
				_quad("blackboard", Vector2(n * T - 0.4, 1.6), Vector3(p.x + (n - 1) * T * 0.5, 1.55, wall_z + 0.02))
				b.add_mesh(b.root, b.box(Vector3(n * T - 0.3, 0.06, 0.14)), b._mats["dark"], Vector3(p.x + (n - 1) * T * 0.5, 0.74, wall_z + 0.08), 0.0, false)
		"n":
			_quad("cork", Vector2(1.7, 1.25), Vector3(p.x, 1.6, wall_z + 0.02))
		"s":
			_cabinet(p, Vector3(1.9, 2.2, 0.42), "books", b._mats["dark"])
		"l":
			_cabinet(p, Vector3(1.9, 1.9, 0.45), "lockers", jp.painted(Color(0.6, 0.62, 0.65), "jp_sheet", 0.5))
		"g":
			_cabinet(p, Vector3(1.9, 1.6, 0.45), "getabako", b._mats["crate"], 0.0)
		"h":
			var body: StaticBody3D = b.static_body(p + Vector3(0, 0, -0.6))
			b.add_mesh(body, b.box(Vector3(1.85, 1.15, 0.45)), jp.painted(Color(0.72, 0.74, 0.72), "jp_sheet", 0.5), Vector3(0, 0.575, 0))
			b.add_mesh(body, b.box(Vector3(0.02, 1.0, 0.02)), b._mats["dark"], Vector3(0, 0.55, 0.23), 0.0, false)
			for k in rng.randi_range(2, 5):
				var col := Color.from_hsv(rng.randf(), 0.4, 0.85)
				b.add_mesh(body, b.box(Vector3(rng.randf_range(0.15, 0.3), rng.randf_range(0.1, 0.35), 0.25)), jp.painted(col), Vector3(-0.7 + k * 0.35, 1.25, 0), 0.0, false)
			b.add_box_collider(body, Vector3(1.85, 1.15, 0.45), Vector3(0, 0.575, 0))
		"a":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(1.3, 0.74, 0.75)), jp.painted(Color(0.62, 0.64, 0.66), "jp_sheet", 0.5), Vector3(0, 0.37, 0))
			b.add_mesh(body, b.box(Vector3(0.5, 0.36, 0.05)), jp.painted(Color(0.15, 0.15, 0.17)), Vector3(0.25, 0.98, -0.2), 0.0, false)
			for k in rng.randi_range(1, 3):
				b.add_mesh(body, b.box(Vector3(0.3, 0.05 + k * 0.04, 0.22)), jp.painted(Color(0.97, 0.96, 0.92)), Vector3(-0.35, 0.76 + k * 0.025, 0.05), 0.0, false)
			b.add_mesh(body, b.cylinder(0.04, 0.09, 8), jp.painted(Color.from_hsv(rng.randf(), 0.5, 0.9)), Vector3(0.0, 0.79, 0.15), 0.0, false)
			_chair(body, Vector3(0, 0, 0.6))
			b.add_box_collider(body, Vector3(1.3, 0.75, 0.75), Vector3(0, 0.37, 0))
		"b":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(1.0, 0.45, 1.9)), jp.painted(Color(0.9, 0.92, 0.93), "jp_sheet", 0.5), Vector3(0, 0.25, 0.1))
			b.add_mesh(body, b.box(Vector3(0.95, 0.12, 1.85)), jp.painted(Color(0.98, 0.98, 1.0)), Vector3(0, 0.53, 0.1), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.6, 0.12, 0.35)), jp.painted(Color(1.0, 1.0, 1.0)), Vector3(0, 0.64, -0.6), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.95, 0.1, 1.1)), jp.painted(Color(0.7, 0.85, 0.95)), Vector3(0, 0.62, 0.45), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.04, 0.04, 2.2)), b._mats["pipe"], Vector3(0.62, 2.2, 0.1), 0.0, false)
			var curtain: StandardMaterial3D = jp.painted(Color(0.72, 0.86, 0.8), "jp_indigo", 1.0)
			b.add_mesh(body, b.box(Vector3(0.03, 1.9, 1.2)), curtain, Vector3(0.62, 1.2, -0.3), 0.0, true)
			b.add_box_collider(body, Vector3(1.0, 0.6, 1.9), Vector3(0, 0.3, 0.1))
		"x":
			_anatomy(p)
		"v":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(1.9, 0.85, 0.95)), jp.painted(Color(0.85, 0.85, 0.82), "jp_sheet", 0.5), Vector3(0, 0.42, 0))
			b.add_mesh(body, b.box(Vector3(1.95, 0.06, 1.0)), jp.painted(Color(0.12, 0.12, 0.13)), Vector3(0, 0.87, 0), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.4, 0.04, 0.35)), jp.painted(Color(0.4, 0.42, 0.45)), Vector3(0.6, 0.9, 0), 0.0, false)
			b.add_mesh(body, b.cylinder(0.02, 0.3, 5), b._mats["pipe"], Vector3(0.6, 1.05, -0.25), 0.0, false)
			for k in 3:
				var flask: MeshInstance3D = b.add_mesh(body, b.cylinder(0.05, 0.18, 7, 0.02), jp.painted(Color.from_hsv(0.3 + k * 0.25, 0.4, 0.9)), Vector3(-0.6 + k * 0.2, 0.99, 0.1), 0.0, false)
				flask.rotation.y = 0.0
			for sx in [-0.6, 0.6]:
				b.add_mesh(body, b.cylinder(0.16, 0.6, 7), b._mats["metal"], Vector3(sx, 0.3, 0.7), 0.0, false)
			b.add_box_collider(body, Vector3(1.9, 0.9, 0.95), Vector3(0, 0.45, 0))
		"p":
			var body: StaticBody3D = b.static_body(p)
			var lacquer: StandardMaterial3D = jp.painted(Color(0.06, 0.06, 0.07), "jp_darkwood", 0.5)
			lacquer.roughness = 0.2
			lacquer.metallic = 0.3
			b.add_mesh(body, b.box(Vector3(1.5, 0.32, 1.9)), lacquer, Vector3(0, 0.85, -0.2))
			var lid: MeshInstance3D = b.add_mesh(body, b.box(Vector3(1.4, 0.04, 1.8)), lacquer, Vector3(-0.3, 1.45, -0.25))
			lid.rotation.z = 0.6
			b.add_mesh(body, b.box(Vector3(1.4, 0.06, 0.25)), jp.painted(Color(0.98, 0.97, 0.94)), Vector3(0, 0.98, 0.83), 0.0, false)
			for sx in [-0.6, 0.6]:
				b.add_mesh(body, b.box(Vector3(0.1, 0.7, 0.1)), lacquer, Vector3(sx, 0.35, 0.4), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.9, 0.5, 0.4)), lacquer, Vector3(0, 0.25, 1.35))
			b.add_box_collider(body, Vector3(1.5, 1.0, 2.2), Vector3(0, 0.5, 0))
		"e":
			var body: StaticBody3D = b.static_body(p)
			var wood: StandardMaterial3D = jp.prop_mat("wood_light", Color.WHITE)
			for sx in [-0.28, 0.28]:
				var leg: MeshInstance3D = b.add_mesh(body, b.box(Vector3(0.05, 1.7, 0.05)), wood, Vector3(sx, 0.85, 0), 0.0, false)
				leg.rotation.z = -signf(sx) * 0.12
			var back: MeshInstance3D = b.add_mesh(body, b.box(Vector3(0.05, 1.7, 0.05)), wood, Vector3(0, 0.82, -0.3), 0.0, false)
			back.rotation.x = 0.3
			b.add_mesh(body, b.box(Vector3(0.8, 0.6, 0.04)), jp.painted(Color(0.97, 0.96, 0.92)), Vector3(0, 1.25, 0.05), 0.0, true)
			for k in 3:
				b.add_mesh(body, b.box(Vector3(rng.randf_range(0.15, 0.5), rng.randf_range(0.1, 0.3), 0.01)), jp.painted(Color.from_hsv(rng.randf(), 0.6, 0.9)), Vector3(rng.randf_range(-0.2, 0.2), 1.25 + rng.randf_range(-0.15, 0.15), 0.075), 0.0, false)
		"m":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(1.0, 2.0, 0.1)), b._mats["dark"], Vector3(0, 1.05, -0.85))
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.75, 0.82, 0.9)
			glass.metallic = 1.0
			glass.roughness = 0.04
			b.add_mesh(body, b.box(Vector3(0.85, 1.8, 0.02)), glass, Vector3(0, 1.05, -0.79), 0.0, false)
		"c":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(2.0, 0.95, 0.6)), jp.prop_mat("wood_light", Color.WHITE), Vector3(0, 0.47, 0))
			b.add_mesh(body, b.box(Vector3(2.05, 0.05, 0.7)), b._mats["dark"], Vector3(0, 0.97, 0), 0.0, false)
			for k in 4:
				b.add_mesh(body, b.box(Vector3(0.28, 0.12, 0.2)), jp.painted([Color(0.95, 0.75, 0.4), Color(0.85, 0.55, 0.3), Color(0.98, 0.95, 0.85)][k % 3]), Vector3(-0.7 + k * 0.45, 1.05, 0.05), 0.0, false)
			b.add_box_collider(body, Vector3(2.0, 1.0, 0.6), Vector3(0, 0.5, 0))
		"y":
			b._vending(p + Vector3(0, 0, -0.4))
		"f":
			jp._pot(p + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)))
		"o":
			var body: StaticBody3D = b.static_body(p)
			var leather: StandardMaterial3D = jp.painted(Color(0.45, 0.28, 0.2), "jp_darkwood", 0.5)
			b.add_mesh(body, b.box(Vector3(1.9, 0.42, 0.8)), leather, Vector3(0, 0.21, 0))
			b.add_mesh(body, b.box(Vector3(1.9, 0.5, 0.2)), leather, Vector3(0, 0.6, -0.32))
			b.add_box_collider(body, Vector3(1.9, 0.6, 0.8), Vector3(0, 0.3, 0))
		"r":
			var body: StaticBody3D = b.static_body(p + Vector3(0, 0, -0.55))
			b.add_mesh(body, b.box(Vector3(1.8, 1.9, 0.5)), b._mats["dark"], Vector3(0, 0.95, 0))
			var gold: StandardMaterial3D = jp.painted(Color(1.0, 0.8, 0.35))
			gold.metallic = 0.7
			gold.roughness = 0.3
			for row in 2:
				for k in 3:
					b.add_mesh(body, b.cylinder(0.08, 0.3, 8, 0.04), gold, Vector3(-0.5 + k * 0.5, 0.9 + row * 0.6, 0.26), 0.0, false)
			b.add_mesh(body, b.box(Vector3(0.4, 0.3, 0.02)), jp.painted(Color(0.85, 0.8, 0.7)), Vector3(0.55, 1.6, 0.26), 0.0, false)
			b.add_box_collider(body, Vector3(1.8, 1.9, 0.5), Vector3(0, 0.95, 0))
		"w":
			var body: StaticBody3D = b.static_body(p)
			var panel: StandardMaterial3D = jp.painted([Color(0.95, 0.75, 0.8), Color(0.75, 0.85, 0.95)][x % 2], "jp_sheet", 0.5)
			b.add_mesh(body, b.box(Vector3(0.06, 1.9, 1.6)), panel, Vector3(-0.97, 0.95, 0.1))
			b.add_mesh(body, b.box(Vector3(1.0, 1.9, 0.06)), panel, Vector3(0.3, 0.95, -0.7))
			b.add_mesh(body, b.box(Vector3(0.45, 0.4, 0.6)), jp.painted(Color(0.98, 0.98, 1.0)), Vector3(-0.2, 0.2, 0.4), 0.0, false)
			b.add_box_collider(body, Vector3(0.06, 1.9, 1.6), Vector3(-0.97, 0.95, 0.1))
		"u":
			var body: StaticBody3D = b.static_body(p + Vector3(0, 0, -0.55))
			b.add_mesh(body, b.box(Vector3(1.9, 0.85, 0.55)), jp.painted(Color(0.85, 0.87, 0.88), "jp_sheet", 0.5), Vector3(0, 0.42, 0))
			b.add_mesh(body, b.box(Vector3(0.5, 0.08, 0.35)), jp.painted(Color(0.98, 0.98, 1.0)), Vector3(0, 0.86, 0.05), 0.0, false)
			b.add_mesh(body, b.cylinder(0.02, 0.25, 5), b._mats["pipe"], Vector3(0, 1.0, -0.15), 0.0, false)
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.75, 0.82, 0.9)
			glass.metallic = 1.0
			glass.roughness = 0.05
			b.add_mesh(body, b.box(Vector3(1.6, 0.8, 0.02)), glass, Vector3(0, 1.6, -0.26), 0.0, false)
			b.add_box_collider(body, Vector3(1.9, 0.85, 0.55), Vector3(0, 0.42, 0))
		"z":
			var body: StaticBody3D = b.static_body(p)
			b.add_mesh(body, b.box(Vector3(1.7, 0.06, 0.95)), jp.prop_mat("wood_light", Color.WHITE), Vector3(0, 0.72, 0))
			for sx in [-0.75, 0.75]:
				for sz in [-0.38, 0.38]:
					b.add_mesh(body, b.box(Vector3(0.06, 0.7, 0.06)), b._mats["dark"], Vector3(sx, 0.35, sz), 0.0, false)
			_chair(body, Vector3(-0.4, 0, 0.75))
			_chair(body, Vector3(0.4, 0, 0.75))
			b.add_box_collider(body, Vector3(1.7, 0.75, 0.95), Vector3(0, 0.37, 0))
		"j":
			var body: StaticBody3D = b.static_body(p + Vector3(0, 0, -0.6))
			for k in 3:
				b.add_mesh(body, b.box(Vector3(0.38, 0.7, 0.38)), jp.painted([Color(0.25, 0.5, 0.85), Color(0.95, 0.75, 0.2), Color(0.85, 0.25, 0.2)][k], "jp_sheet", 1.0), Vector3(-0.45 + k * 0.45, 0.35, 0))
		"i":
			b._bench(p)
		"q":
			jp._ac_unit(p)
		"Y":
			if b.cell(x - 1, z) != "Y":
				var body: StaticBody3D = b.static_body(p + Vector3(T, 0, 0))
				var tank: MeshInstance3D = b.add_mesh(body, b.cylinder(1.3, 4.0, 14), jp.painted(Color(0.85, 0.87, 0.85), "jp_sheet", 0.5), Vector3(0, 2.4, 0))
				tank.rotation.z = PI * 0.5
				for sx in [-1.4, 1.4]:
					b.add_mesh(body, b.box(Vector3(0.15, 1.1, 2.2)), b._mats["concrete"], Vector3(sx, 0.55, 0))
				b.add_box_collider(body, Vector3(4.2, 3.6, 2.6), Vector3(0, 1.8, 0))
		"S", "K":
			_stairs_up(p, c == "K")
			links.append({"char": c, "tile": Vector2i(x, z), "pos": p})
		"D":
			_stairs_down(p)
			links.append({"char": c, "tile": Vector2i(x, z), "pos": p})
		"X":
			if b.cell(x - 1, z) != "X":
				_entrance_doors(p + Vector3(T * 0.5, 0, 0))
			links.append({"char": c, "tile": Vector2i(x, z), "pos": p})
		_:
			return false
	return true


func _chair(parent: Node3D, at: Vector3) -> void:
	var wood: StandardMaterial3D = jp.prop_mat("wood_light", Color.WHITE)
	b.add_mesh(parent, b.box(Vector3(0.42, 0.05, 0.4)), wood, at + Vector3(0, 0.44, 0), 0.0, false)
	b.add_mesh(parent, b.box(Vector3(0.42, 0.35, 0.04)), wood, at + Vector3(0, 0.72, 0.2), 0.0, false)
	b.add_mesh(parent, b.box(Vector3(0.36, 0.42, 0.34)), b._mats["metal"], at + Vector3(0, 0.21, 0), 0.0, false)


## A box against the north wall with a pixel front (books, lockers, shoe cubbies).
func _cabinet(p: Vector3, size: Vector3, panel: String, mat: Material, back: float = -0.75) -> void:
	var body: StaticBody3D = b.static_body(p + Vector3(0, 0, back))
	b.add_mesh(body, b.box(size), mat, Vector3(0, size.y * 0.5, 0))
	_quad(panel, Vector2(size.x - 0.06, size.y - 0.06), Vector3(0, size.y * 0.5, size.z * 0.5 + 0.01), 0.0, 0.0, body)
	b.add_box_collider(body, size, Vector3(0, size.y * 0.5, 0))


## The science room's anatomy model (one of the seven mysteries: it runs at night). Plastic, not gory.
func _anatomy(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var plastic: StandardMaterial3D = jp.painted(Color(0.95, 0.82, 0.72))
	var inner: StandardMaterial3D = jp.painted(Color(0.85, 0.45, 0.4))
	b.add_mesh(body, b.cylinder(0.25, 0.08, 10), b._mats["metal"], Vector3(0, 0.04, 0), 0.0, false)
	b.add_mesh(body, b.cylinder(0.03, 0.9, 5), b._mats["metal"], Vector3(0, 0.5, -0.1), 0.0, false)
	b.add_mesh(body, b.box(Vector3(0.18, 0.75, 0.16)), plastic, Vector3(-0.1, 0.45, 0))
	b.add_mesh(body, b.box(Vector3(0.18, 0.75, 0.16)), inner, Vector3(0.1, 0.45, 0))
	b.add_mesh(body, b.box(Vector3(0.42, 0.6, 0.22)), plastic, Vector3(-0.05, 1.12, 0))
	b.add_mesh(body, b.box(Vector3(0.18, 0.5, 0.2)), inner, Vector3(0.12, 1.12, 0.02))
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.32
	b.add_mesh(body, head, plastic, Vector3(0, 1.6, 0))
	for sx in [-0.28, 0.28]:
		b.add_mesh(body, b.box(Vector3(0.09, 0.6, 0.09)), plastic if sx < 0 else inner, Vector3(sx, 1.05, 0.02), 0.0, false)
	b.add_box_collider(body, Vector3(0.6, 1.8, 0.4), Vector3(0, 0.9, 0))


func _stairs_up(p: Vector3, roof: bool) -> void:
	var body: StaticBody3D = b.static_body(p)
	var stone: StandardMaterial3D = b._mats["concrete"]
	for k in 6:
		b.add_mesh(body, b.box(Vector3(1.8, 0.2 + k * 0.2, 0.32)), stone, Vector3(0, (0.2 + k * 0.2) * 0.5, 0.75 - k * 0.32))
		b.add_mesh(body, b.box(Vector3(1.8, 0.03, 0.06)), jp.painted(Color(0.9, 0.75, 0.2)), Vector3(0, 0.2 + k * 0.2 + 0.01, 0.9 - k * 0.32), 0.0, false)
	for sx in [-0.95, 0.95]:
		var rail: MeshInstance3D = b.add_mesh(body, b.box(Vector3(0.05, 0.05, 2.1)), b._mats["pipe"], Vector3(sx, 1.3, 0.0), 0.0, false)
		rail.rotation.x = 0.5
	_quad("exit", Vector2(0.6, 0.3), Vector3(0, 2.5, -0.95), 0.0, 1.2, body)
	if roof:
		b.add_mesh(body, b.box(Vector3(1.4, 2.3, 0.1)), jp.painted(Color(0.55, 0.6, 0.62), "jp_sheet", 0.5), Vector3(0, 1.15, -0.95))
	b.add_box_collider(body, Vector3(1.8, 1.2, 1.9), Vector3(0, 0.6, 0))


func _stairs_down(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var dark: StandardMaterial3D = jp.painted(Color(0.18, 0.18, 0.2))
	b.add_mesh(body, b.box(Vector3(1.8, 0.02, 1.8)), dark, Vector3(0, 0.01, 0), 0.0, false)
	for k in 4:
		b.add_mesh(body, b.box(Vector3(1.7, 0.02, 0.3)), b._mats["concrete"], Vector3(0, 0.02, -0.6 + k * 0.38), 0.0, false)
	for sx in [-0.95, 0.95]:
		b.add_mesh(body, b.box(Vector3(0.05, 0.9, 1.8)), b._mats["pipe"], Vector3(sx, 0.45, 0), 0.0, false)
	b.add_mesh(body, b.box(Vector3(1.9, 0.05, 0.05)), b._mats["pipe"], Vector3(0, 0.9, -0.9), 0.0, false)


func _entrance_doors(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var frame: StandardMaterial3D = jp.painted(Color(0.7, 0.72, 0.75), "jp_sheet", 0.5)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.8, 0.9, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.7, 0.85, 0.95)
	glass.emission_energy_multiplier = 0.4
	for k in 4:
		b.add_mesh(body, b.box(Vector3(0.9, 2.2, 0.04)), glass, Vector3(-1.35 + k * 0.9, 1.1, 0.1), 0.0, false)
		b.add_mesh(body, b.box(Vector3(0.06, 2.3, 0.08)), frame, Vector3(-1.8 + k * 0.9, 1.15, 0.1), 0.0, false)
	b.add_mesh(body, b.box(Vector3(3.8, 0.12, 0.1)), frame, Vector3(0, 2.25, 0.1), 0.0, false)


## Every desk in the floor as four MultiMeshes (top, frame, seat, back): 60 desks = 4 draw calls.
func finish() -> void:
	if _desks.is_empty():
		return
	var tops: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var seats: Array[Transform3D] = []
	var backs: Array[Transform3D] = []
	for t in _desks:
		var o := t.origin + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.06, 0.06))
		tops.append(Transform3D(Basis(), o + Vector3(0, 0.72, -0.2)))
		frames.append(Transform3D(Basis(), o + Vector3(0, 0.35, -0.2)))
		seats.append(Transform3D(Basis(), o + Vector3(0, 0.44, 0.38)))
		backs.append(Transform3D(Basis(), o + Vector3(0, 0.66, 0.58)))
	jp._mm(tops, b.box(Vector3(0.66, 0.05, 0.48)), jp.prop_mat("wood_light", Color.WHITE), "DeskTops")
	jp._mm(frames, b.box(Vector3(0.58, 0.68, 0.4)), b._mats["metal"], "DeskFrames")
	jp._mm(seats, b.box(Vector3(0.42, 0.06, 0.4)), jp.prop_mat("wood_light", Color.WHITE), "ChairSeats")
	jp._mm(backs, b.box(Vector3(0.42, 0.36, 0.05)), jp.prop_mat("wood_light", Color.WHITE), "ChairBacks")
	for t in _desks:
		var body: StaticBody3D = b.static_body(t.origin + Vector3(0, 0, -0.2))
		b.add_box_collider(body, Vector3(0.66, 0.75, 0.48), Vector3(0, 0.37, 0))
