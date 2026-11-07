class_name JPKit
extends RefCounted
## Suzunari's look (LevelBuilder palette theme "suzunari"):
## - ground: pixelized CC0 photo textures (tools/jp_textures.py) chosen by town zone
## - buildings: machiya, modern shops, houses, the station, the old schoolhouse and the shrine keeper's house,
##   split into narrow units with kawara gable roofs and pixel facades (tools/jp_facades.py) that glow at night
## - nature: sakura (riverside rows, courtyard, shrine), fallen-petal carpets, grass tufts and spring flowers
## - street: utility poles with sagging wires, road paint, gutters, futons and laundry on balconies
## Night lighting: `night_mats` / `night_lights` are scaled by the level (`set_night`).

const T := 2.0
const ROOF_TINTS := [Color(0.78, 0.82, 0.92), Color(0.62, 0.68, 0.8), Color(0.9, 0.62, 0.5), Color(0.56, 0.66, 0.74),
	Color(0.85, 0.85, 0.88)]
const WALL_TINTS := [Color(0.98, 0.96, 0.9), Color(0.94, 0.9, 0.82), Color(0.9, 0.93, 0.96), Color(0.98, 0.9, 0.88),
	Color(0.92, 0.95, 0.88)]
const SAKURA := [Color(1.0, 0.8, 0.86), Color(0.98, 0.7, 0.8), Color(1.0, 0.9, 0.93)]

var b  ## LevelBuilder
var rng: RandomNumberGenerator
var night_mats: Array[StandardMaterial3D] = []
var night_lights: Array[OmniLight3D] = []
var _facades := {}
var _petal_spots: Array[Transform3D] = []
var _tufts: Array[Vector3] = []
var _flowers: Array[Vector3] = []
var _wire_xf: Array[Transform3D] = []
var _poles: Array[Vector3] = []
var shaft_mats: Array[StandardMaterial3D] = []  ## god rays (alpha scaled by set_sun)
var _grates: Array[Transform3D] = []


func _init(builder) -> void:
	b = builder
	rng = builder.rng


# --- Materials & ground -------------------------------------------------------------------------

## Ground textures: photo detail already, no grime layer on top (it read as polka dots on the gravel).
const FLOOR_TEX := ["jp_gravel", "jp_sando", "jp_stonepath", "jp_paving", "jp_asphalt", "jp_grass", "jp_schoolyard",
	"jp_beach", "jp_woodfloor", "jp_forest", "jp_moss"]
var _grime: Texture2D
var _props := {}
## Texture per LevelBuilder._jp_mat key: [texture, tint multiplier (null = use the key's colour x1.5), scale].
const PROP_TEX := {"vermilion": ["jp_lacquer", Color(1, 1, 1), 0.5], "torii_top": ["jp_darkwood", Color(0.55, 0.5, 0.5), 0.5],
	"wood": ["jp_darkwood", Color(1, 1, 1), 0.5], "wood_light": ["jp_hinoki", Color(1, 1, 1), 0.5],
	"ema": ["jp_hinoki", Color(1.05, 1.0, 0.95), 0.5], "stone": ["jp_granite", Color(1, 1, 1), 0.5],
	"step_edge": ["jp_granite", Color(0.85, 0.85, 0.85), 0.5], "lantern_stone": ["jp_granite", Color(1.05, 1.05, 1.0), 0.5],
	"jizo": ["jp_granite", Color(1.0, 1.0, 0.98), 0.5], "statue": ["jp_granite", Color(1, 1, 1), 0.5],
	"kawara_dark": ["jp_kawara", Color(0.7, 0.75, 0.85), 0.25], "bib": ["jp_indigo", Color(2.4, 0.5, 0.45), 0.5],
	"pole": ["jp_paint", Color(1.0, 1.0, 0.97), 0.5], "lamp_pole": ["jp_paint", Color(0.9, 0.92, 0.95), 0.5],
	"transformer": ["jp_sheet", Color(0.8, 0.82, 0.86), 0.5], "rope": ["jp_paint", Color(1.4, 1.2, 0.8), 0.5],
	"straw": ["jp_paint", Color(1.45, 1.25, 0.8), 0.5], "shide": ["jp_paint", Color(1.6, 1.6, 1.58), 0.5],
	"gilt": ["jp_paint", Color(1.5, 1.15, 0.5), 0.5], "bike": ["jp_paint", Color(1.3, 0.5, 0.45), 0.5],
	"tyre": ["jp_sheet", Color(0.25, 0.25, 0.27), 0.5]}


## Shared weathering on every Suzunari surface: one grime layer (dirt patches, rain streaks) multiplied on top,
## so roofs, walls, poles and statues read as one weathered place instead of clean primitives.
func weather(m: StandardMaterial3D) -> StandardMaterial3D:
	if _grime == null:
		_grime = b._tex("jp_f_grime")
	if _grime:
		m.detail_enabled = true
		m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.detail_albedo = _grime
		m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	return m


## A flat colour turned into a painted, weathered surface (chipped paint texture tinted by the colour).
func painted(c: Color, tex: String = "jp_paint", scale: float = 0.5) -> StandardMaterial3D:
	var m: StandardMaterial3D = b._textured(tex, Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, c.a), scale, 0.85, 0.0, 0.6)
	return m


## Cached material for a LevelBuilder._jp_mat key.
func prop_mat(key: String, c: Color) -> StandardMaterial3D:
	if _props.has(key):
		return _props[key]
	var base := key.trim_suffix("0").trim_suffix("1").trim_suffix("2")
	var m: StandardMaterial3D
	if PROP_TEX.has(base):
		var e: Array = PROP_TEX[base]
		m = b._textured(str(e[0]), e[1], float(e[2]), 0.85, 0.0, 0.8)
	else:
		m = painted(c)
	_props[key] = m
	return m

func materials() -> void:
	for k in [["gravel", 0.95, 0.8], ["sando", 0.9, 1.2], ["stonepath", 0.9, 1.4], ["paving", 0.85, 1.0],
			["asphalt", 0.75, 0.8], ["grass", 0.95, 0.6], ["schoolyard", 0.95, 0.6], ["beach", 0.95, 0.5],
			["woodfloor", 0.55, 0.6], ["forest", 0.95, 0.8], ["hinoki", 0.7, 0.8]]:
		var m: StandardMaterial3D = b._textured("jp_" + k[0], Color.WHITE, 0.25, k[1], 0.0, k[2])
		m.vertex_color_use_as_albedo = true
		b._mats["jp_" + k[0]] = m
	b._mats["floor"] = b._mats["jp_grass"]
	b._mats["floor_path"] = b._mats["jp_asphalt"]
	b._mats["wall"] = b._textured("jp_plaster", Color(0.97, 0.95, 0.9), 0.25, 0.9, 0.0, 0.5)
	b._mats["rock"] = b._textured("jp_ishigaki", Color(0.92, 0.92, 0.9), 0.25, 0.95, 0.0, 1.2)
	b._mats["concrete"] = b._textured("jp_concrete", Color(0.95, 0.95, 0.94), 0.25, 0.9, 0.0, 0.6)
	b._mats["metal"] = b._textured("jp_sheet", Color(0.95, 0.96, 0.98), 0.5, 0.6, 0.2, 0.8)
	b._mats["dark"] = b._textured("jp_darkwood", Color(0.8, 0.78, 0.76), 0.5, 0.8, 0.0, 0.8)
	b._mats["crate"] = b._textured("jp_cedar", Color(0.8, 0.72, 0.62), 0.5, 0.85, 0.0, 0.8)
	b._mats["pipe"] = b._textured("jp_paint", Color(1.1, 1.12, 1.15), 0.5, 0.6, 0.1, 0.6)


func zone(x: int, z: int) -> String:
	if z <= 9:
		return "shrine" if x >= 16 else "approach"
	if z <= 19:
		return "steps"
	if z <= 31:
		if x >= 40:
			return "dogshrine"
		if x <= 5 or z >= 28:
			return "schoolyard"
		return "school"
	if z <= 33 or z == 43:
		return "road"
	if z <= 42:
		return "rokujizo" if x >= 41 else "street"
	if z == 44:
		return "embankment"
	if z <= 46:
		return "river"
	if z <= 50:
		return "home"
	return "beach"


func floor_kind(x: int, z: int) -> String:
	var c: String = b.cell(x, z)
	if c == "~":
		return "water"
	if c == ",":
		return "jp_asphalt"
	if c == "l":
		return "jp_stonepath"
	match zone(x, z):
		"shrine":
			return "jp_sando" if absi(x - 27) <= 1 and z >= 2 else "jp_gravel"
		"dogshrine":
			return "jp_sando" if absi(x - 47) <= 0 and z >= 22 else "jp_gravel"
		"approach", "steps":
			return "jp_stonepath"
		"school":
			return "jp_woodfloor"
		"schoolyard":
			return "jp_schoolyard"
		"street":
			return "jp_sando" if z == 38 or z == 39 else "jp_paving"
		"rokujizo":
			return "jp_stonepath" if b.cell(x, z) in ["z", "o"] or (z >= 35 and z <= 37 and x <= 45) else "jp_grass"
		"embankment":
			return "jp_grass"
		"river":
			return "jp_hinoki"  # the bridge
		"home":
			return "jp_asphalt" if z == 47 else "jp_paving"
		"beach":
			return "jp_hinoki" if z >= 53 else "jp_beach"  # the pier runs out over the sea
	return "jp_paving"


## Per-tile tint: grass and gravel get organic patches, paved ground a little wear.
func floor_color(kind: String, x: int, z: int) -> Color:
	var n: float = b._ground_noise.get_noise_2d(x * 1.7, z * 1.7)
	match kind:
		"jp_paving":
			return Color(0.9, 0.88, 0.88) * (0.95 + n * 0.08)
		"jp_grass", "jp_forest":
			return Color(0.92 + n * 0.12, 1.0 + n * 0.08, 0.86 + n * 0.1)
		"jp_gravel":
			return Color(0.47, 0.48, 0.53) * (0.96 + n * 0.1)
	return Color.WHITE * (0.95 + n * 0.06 + rng.randf_range(-0.02, 0.02))


# --- Facades ------------------------------------------------------------------------------------

func facade(name: String) -> StandardMaterial3D:
	if _facades.has(name):
		return _facades[name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = b._tex("jp_f_" + name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.8
	var e: Texture2D = b._tex("jp_f_%s_e" % name)
	if e:
		m.emission_enabled = true
		m.emission_texture = e
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.0
		night_mats.append(m)
	_facades[name] = m
	return m


func _panel(body: Node3D, name: String, size: Vector2, at: Vector3, deco: Array[Node], repeat_x: float = 1.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mat := facade(name)
	if repeat_x != 1.0:
		mat = mat.duplicate()
		mat.uv1_scale = Vector3(repeat_x, 1, 1)
		if mat.emission_enabled:
			night_mats.append(mat)
	var mi: MeshInstance3D = b.add_mesh(body, q, mat, at, 0.0, false)
	deco.append(mi)
	return mi


func _wall_mat(tex: String, tint: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = b._textured(tex, tint, 0.25, 0.9, 0.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	return m


## Gable roof, ridge along x, overhanging eaves; the south slope faces the camera.
## `deco`: every piece that is not drawn with `roof`/`wall` (ridge, fascia, gutter, downpipe) is added here so it hides
## with the house when the camera cuts the house away.
func gable(body: Node3D, w: float, d: float, h: float, roof: StandardMaterial3D, wall: StandardMaterial3D, pitch: float = 0.5, gutter: bool = true, deco: Array[Node] = []) -> float:
	var hd := d * 0.5
	var over := 0.55
	var rise := hd * tan(pitch)
	var run := hd + over
	var slab_len := run / cos(pitch)
	for s in [1.0, -1.0]:
		var slab: MeshInstance3D = b.add_mesh(body, b.box(Vector3(w + 1.0, 0.16, slab_len)), roof,
			Vector3(0, h + rise - run * tan(pitch) * 0.5, s * run * 0.5))
		slab.rotation.x = s * pitch
	var prism := PrismMesh.new()
	prism.size = Vector3(d, rise, w)
	var gm: MeshInstance3D = b.add_mesh(body, prism, wall, Vector3(0, h + rise * 0.5, 0))
	gm.rotation.y = PI * 0.5
	var ridge := roof.duplicate() as StandardMaterial3D
	ridge.albedo_color = roof.albedo_color.darkened(0.25)
	deco.append(b.add_mesh(body, b.box(Vector3(w + 1.1, 0.26, 0.36)), ridge, Vector3(0, h + rise + 0.08, 0)))
	for sx in [-1.0, 1.0]:
		deco.append(b.add_mesh(body, b.box(Vector3(0.3, 0.5, 0.42)), ridge, Vector3(sx * (w * 0.5 + 0.55), h + rise + 0.2, 0), 0.0, false))
	# Fascia board under the eave, a rain gutter and a downpipe: the little lines that make a roof sit on a house.
	var eave_y := h - over * tan(pitch)
	deco.append(b.add_mesh(body, b.box(Vector3(w + 1.0, 0.18, 0.06)), b._mats["dark"], Vector3(0, eave_y - 0.12, run + 0.02), 0.0, false))
	if gutter:
		var gutter_mat: StandardMaterial3D = painted(Color(0.55, 0.5, 0.45))
		var g: MeshInstance3D = b.add_mesh(body, b.cylinder(0.07, w + 0.9, 6), gutter_mat, Vector3(0, eave_y - 0.2, run + 0.1), 0.0, false)
		g.rotation.z = PI * 0.5
		deco.append(g)
		var px := (w * 0.5 + 0.25) * (1.0 if rng.randf() < 0.5 else -1.0)
		deco.append(b.add_mesh(body, b.cylinder(0.05, eave_y, 6), gutter_mat, Vector3(px, eave_y * 0.5 - 0.2, d * 0.5 + 0.12), 0.0, false))
	return h + rise


## A small tiled eave (hisashi) over the ground floor.
func hisashi(body: Node3D, w: float, front: float, y: float, roof: StandardMaterial3D, deco: Array[Node]) -> void:
	var e: MeshInstance3D = b.add_mesh(body, b.box(Vector3(w + 0.2, 0.1, 1.0)), roof, Vector3(0, y, front + 0.45))
	e.rotation.x = 0.32
	deco.append(e)


func building(x0: int, z0: int, x1: int, z1: int) -> void:
	var w := (x1 - x0 + 1) * T
	var d := (z1 - z0 + 1) * T - 0.3
	var c := Vector3((x0 + x1 + 1) * T * 0.5, 0.0, (z0 + z1 + 1) * T * 0.5)
	var zn := zone(x0, z0)
	if z0 <= 9:
		zn = "keeper"
	elif z0 >= 20 and z1 <= 31 and x0 >= 6:
		zn = "school_main"
	elif z0 >= 20 and z1 <= 31:
		zn = "oldschool"
	elif x0 <= 7 and z0 >= 34 and z1 <= 38:
		zn = "station"
	if zn in ["dogshrine", "rokujizo"]:
		zn = "keeper"  # the Inukai priest's house, the Kuroe house by the old temple stones
	if x0 == 49 and z0 == 48:
		zn = "mansion"  # the Shirasagi residence
	# Narrow units side by side: Japanese streets are a row of different little houses.
	var widths: Array[float] = []
	if zn in ["street", "home"]:
		var left := w
		while left > 0.1:
			var uw := minf(left, [4.0, 4.0, 6.0, 6.0, 8.0][rng.randi() % 5])
			if left - uw < 3.9 and left - uw > 0.1:
				uw = left
			widths.append(uw)
			left -= uw
	else:
		widths.append(w)
	var x := -w * 0.5
	var venue_unit := rng.randi() % widths.size()
	var asagiri := zn == "home" and x0 >= 24 and x1 <= 31
	for i in widths.size():
		var uw: float = widths[i]
		var style := zn
		if zn == "street":
			style = ["machiya", "machiya", "modern", "modern2"][rng.randi() % 4]
		elif zn == "home":
			style = "machiya" if asagiri else ("house" if rng.randf() < 0.85 else "modern2")
		_unit(c + Vector3(x + uw * 0.5, 0, 0), uw - 0.12, d, style, (i == venue_unit and zn == "street") or (asagiri and i == 0), asagiri)
		x += uw


func _unit(pos: Vector3, w: float, d: float, style: String, venue: bool, asagiri: bool) -> void:
	var body: StaticBody3D = b.static_body(pos, LevelBuilder.LAYER_WORLD | LevelBuilder.LAYER_OCCLUDER)
	body.name = "House"
	var front := d * 0.5
	var deco: Array[Node] = []
	var fade: Array = []
	var roof: StandardMaterial3D = b._textured("jp_kawara" if rng.randf() < 0.75 else "jp_kawara_old", ROOF_TINTS[rng.randi() % ROOF_TINTS.size()], 0.25, 0.7, 0.1, 1.2)
	roof.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var h := 5.6
	var wall: StandardMaterial3D
	match style:
		"machiya":
			wall = _wall_mat("jp_plaster", WALL_TINTS[rng.randi() % WALL_TINTS.size()])
			var cedar := rng.randf() < 0.5
			var lower := _wall_mat("jp_cedar" if cedar else "jp_yakisugi", Color(0.66, 0.56, 0.5) if cedar else Color(0.9, 0.86, 0.82))
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			b.add_mesh(body, b.box(Vector3(w + 0.04, 3.0, d + 0.04)), lower, Vector3(0, 1.5, 0))
			fade.append(lower)
			var face := "shop" if venue else ("koshi" if rng.randf() < 0.7 else "shutter")
			_panel(body, face, Vector2(w - 0.3, 2.9), Vector3(0, 1.45, front + 0.04), deco, maxf(1.0, roundf(w / 4.0)))
			hisashi(body, w, front, 3.1, roof, deco)
			_upper_windows(body, w, front, 4.35, ["win", "shoji", "shoji"], deco)
			_timber(body, w, h, front, [3.0, h - 0.12], deco)
			gable(body, w, d, h, roof, wall, 0.5, true, deco)
		"modern", "modern2":
			h = 8.6 if style == "modern" else 5.8
			wall = _wall_mat("jp_concrete" if rng.randf() < 0.6 else "jp_plaster", WALL_TINTS[rng.randi() % WALL_TINTS.size()].darkened(0.04))
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			_panel(body, "shop" if venue or rng.randf() < 0.55 else "shutter", Vector2(w - 0.3, 2.9), Vector3(0, 1.45, front + 0.04), deco, maxf(1.0, roundf(w / 4.0)))
			var awn: MeshInstance3D = b.add_mesh(body, b.box(Vector3(w - 0.2, 0.06, 1.1)), b._flat([Color(0.85, 0.25, 0.22), Color(0.2, 0.45, 0.75), Color(0.25, 0.55, 0.35), Color(0.95, 0.75, 0.3)][rng.randi() % 4]), Vector3(0, 3.0, front + 0.5))
			awn.rotation.x = 0.28
			deco.append(awn)
			var fy := 4.4
			while fy < h - 1.0:
				_upper_windows(body, w, front, fy, ["alu", "alu", "win"], deco)
				if rng.randf() < 0.6:
					_balcony(body, w, front, fy - 0.85, deco)
				fy += 2.8
			_storeys(body, w, h, front, deco)
			b.add_mesh(body, b.box(Vector3(w + 0.1, 0.3, d + 0.1)), roof if style == "modern2" else wall, Vector3(0, h + 0.15, 0))
			if rng.randf() < 0.5:
				b.add_mesh(body, b.cylinder(0.5, 1.0, 8), b._mats["metal"], Vector3(w * 0.25, h + 0.8, -d * 0.2), 0.0, false)
		"house":
			wall = _wall_mat("jp_plaster", WALL_TINTS[rng.randi() % WALL_TINTS.size()])
			h = 5.4
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			var dx := rng.randf_range(-w * 0.25, w * 0.25)
			_panel(body, "door", Vector2(1.6, 2.4), Vector3(dx, 1.2, front + 0.04), deco)
			if w > 3.5:
				_panel(body, "alu" if rng.randf() < 0.5 else "win", Vector2(1.6, 1.2), Vector3(-dx * 0.2 + (1.4 if dx < 0 else -1.4), 1.5, front + 0.04), deco)
			_upper_windows(body, w, front, 4.0, ["win", "alu", "shoji"], deco)
			if rng.randf() < 0.7:
				_balcony(body, w, front, 3.2, deco)
			_pots(body, w, front, dx, deco)
			_storeys(body, w, h, front, deco)
			gable(body, w, d, h, roof, wall, 0.45, true, deco)
		"keeper":
			wall = _wall_mat("jp_hinoki", Color(0.92, 0.86, 0.78))
			h = 3.4
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			_panel(body, "shoji", Vector2(w - 0.6, 2.2), Vector3(0, 1.6, front + 0.04), deco, maxf(1.0, roundf(w / 2.0)))
			var deck: MeshInstance3D = b.add_mesh(body, b.box(Vector3(w, 0.12, 0.9)), b._mats["jp_hinoki"], Vector3(0, 0.45, front + 0.45))
			deco.append(deck)
			roof.albedo_texture = b._tex("jp_kawara_old")
			_timber(body, w, h, front, [h - 0.12], deco)
			gable(body, w, d, h, roof, wall, 0.55, true, deco)
		"mansion":
			# The Shirasagi residence: two white storeys over charred cedar, a deep roof, a roofed gate with a
			# heron crest and a child-sized maneki-neko whose paint is cracking (the family's luck since 2010).
			wall = _wall_mat("jp_plaster", Color(0.98, 0.97, 0.94))
			h = 7.4
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			var char_wall := _wall_mat("jp_yakisugi", Color(0.9, 0.86, 0.82))
			b.add_mesh(body, b.box(Vector3(w + 0.04, 2.8, d + 0.04)), char_wall, Vector3(0, 1.4, 0))
			fade.append(char_wall)
			for sx in [-1.0, 1.0]:
				_panel(body, "koshi", Vector2(w * 0.5 - 2.2, 2.4), Vector3(sx * (w * 0.25 + 0.9), 1.3, front + 0.04), deco, 2.0)
			_panel(body, "door", Vector2(1.7, 2.4), Vector3(0, 1.2, front + 0.04), deco)
			hisashi(body, w, front, 3.0, roof, deco)
			_upper_windows(body, w, front, 4.9, ["shoji", "shoji", "win"], deco)
			_timber(body, w, h, front, [2.8, h - 0.12], deco)
			gable(body, w, d, h, roof, wall, 0.5, true, deco)
			var post_mat := prop_mat("wood", Color(0.5, 0.42, 0.38))
			for sx in [-1.35, 1.35]:
				deco.append(b.add_mesh(body, b.box(Vector3(0.26, 3.0, 0.26)), post_mat, Vector3(sx, 1.5, front + 1.25)))
			deco.append(b.add_mesh(body, b.box(Vector3(3.3, 0.24, 0.3)), post_mat, Vector3(0, 2.85, front + 1.25)))
			var gate_roof: MeshInstance3D = b.add_mesh(body, b.box(Vector3(3.9, 0.14, 1.5)), roof, Vector3(0, 3.18, front + 1.25))
			deco.append(gate_roof)
			var crest: MeshInstance3D = b.add_mesh(body, b.cylinder(0.24, 0.05, 16), painted(Color(0.96, 0.96, 0.93)), Vector3(0, 2.85, front + 1.42), 0.0, false)
			crest.rotation.x = PI * 0.5
			deco.append(crest)
			var neko := Node3D.new()
			neko.position = Vector3(-w * 0.5 + 1.0, 0, front + 0.9)
			body.add_child(neko)
			deco.append(neko)
			var white := painted(Color(0.95, 0.94, 0.9))
			var base := MeshInstance3D.new()
			base.mesh = b.box(Vector3(0.9, 0.4, 0.9))
			base.material_override = prop_mat("stone", Color(0.8, 0.8, 0.8))
			base.position.y = 0.2
			neko.add_child(base)
			for part in [[0.36, 0.85], [0.3, 1.45]]:
				var sp := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = float(part[0])
				sm.height = float(part[0]) * 2.0
				sp.mesh = sm
				sp.material_override = white
				sp.position.y = float(part[1])
				neko.add_child(sp)
			var paw := MeshInstance3D.new()
			paw.mesh = b.box(Vector3(0.14, 0.42, 0.14))
			paw.material_override = white
			paw.position = Vector3(-0.3, 1.45, 0.05)
			neko.add_child(paw)
			var koban := MeshInstance3D.new()
			koban.mesh = b.box(Vector3(0.26, 0.16, 0.05))
			koban.material_override = painted(Color(0.95, 0.75, 0.3))
			koban.position = Vector3(0.0, 0.9, 0.36)
			neko.add_child(koban)
		"oldschool":
			wall = _wall_mat("jp_yakisugi", Color(0.95, 0.92, 0.9))
			h = 6.2
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			_panel(body, "school", Vector2(w - 0.4, 2.8), Vector3(0, 1.7, front + 0.04), deco, maxf(1.0, roundf(w / 4.0)))
			_panel(body, "school", Vector2(w - 0.4, 2.8), Vector3(0, 4.6, front + 0.04), deco, maxf(1.0, roundf(w / 4.0)))
			_timber(body, w, h, front, [3.1, h - 0.12], deco)
			roof.albedo_texture = b._tex("jp_kawara_old")
			gable(body, w, d, h, roof, wall, 0.5, true, deco)
		"school_main":
			# Suzunari Gakuen: three white storeys, ribbon windows, a clock, two glass entrances (see school.json doors).
			wall = _wall_mat("jp_concrete", Color(1.0, 1.0, 0.98))
			h = 11.2
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			for fy in [1.95, 5.6, 9.2]:
				_panel(body, "alu", Vector2(w - 1.2, 1.7), Vector3(0, fy, front + 0.04), deco, roundf(w / 2.2))
			for sy in [3.55, 7.2]:
				deco.append(b.add_mesh(body, b.box(Vector3(w + 0.1, 0.22, 0.3)), b._mats["concrete"], Vector3(0, sy, front + 0.12)))
			deco.append(b.add_mesh(body, b.box(Vector3(w + 0.2, 0.5, d + 0.2)), b._mats["concrete"], Vector3(0, h + 0.25, 0)))
			for wx in [24.0, 64.0]:  # entrances (between door tiles 11/12 and 31/32)
				var lx: float = float(wx) - pos.x
				_panel(body, "shop", Vector2(3.6, 2.6), Vector3(lx, 1.3, front + 0.05), deco)
				var can: MeshInstance3D = b.add_mesh(body, b.box(Vector3(4.6, 0.2, 2.2)), b._mats["concrete"], Vector3(lx, 3.0, front + 1.1))
				deco.append(can)
				for sx in [-2.1, 2.1]:
					deco.append(b.add_mesh(body, b.box(Vector3(0.18, 3.0, 0.18)), b._mats["concrete"], Vector3(lx + sx, 1.5, front + 2.05)))
			var clock: MeshInstance3D = b.add_mesh(body, b.cylinder(0.9, 0.1, 20), painted(Color(0.97, 0.96, 0.92)), Vector3(0, h - 1.4, front + 0.08), 0.0, false)
			clock.rotation.x = PI * 0.5
			deco.append(clock)
			for hand in [[0.06, 0.65, 0.0], [0.05, 0.85, 1.9]]:
				var hm: MeshInstance3D = b.add_mesh(body, b.box(Vector3(float(hand[0]), float(hand[1]), 0.02)), painted(Color(0.1, 0.1, 0.12)), Vector3(0, h - 1.4, front + 0.15), 0.0, false)
				hm.rotation.z = float(hand[2])
				deco.append(hm)
			var sign := Label3D.new()
			sign.text = "SUZUNARI  GAKUEN"
			sign.font_size = 96
			sign.pixel_size = 0.012
			sign.modulate = Color(0.2, 0.25, 0.3)
			sign.outline_size = 0
			sign.position = Vector3(0, 3.95, front + 0.3)
			body.add_child(sign)
			deco.append(sign)
		"station":
			wall = _wall_mat("jp_plaster", Color(0.96, 0.96, 0.94))
			h = 3.8
			b.add_mesh(body, b.box(Vector3(w, h, d)), wall, Vector3(0, h * 0.5, 0))
			_panel(body, "shop", Vector2(w * 0.5, 2.6), Vector3(-w * 0.2, 1.3, front + 0.04), deco, 2.0)
			_panel(body, "alu", Vector2(2.4, 1.4), Vector3(w * 0.3, 1.8, front + 0.04), deco)
			var sb: MeshInstance3D = b.add_mesh(body, b.box(Vector3(w * 0.7, 0.7, 0.12)), b._flat(Color(0.12, 0.3, 0.55)), Vector3(0, 3.35, front + 0.1), 0.0, false)
			deco.append(sb)
			var sl := Label3D.new()
			sl.text = "SUZUNARI  STATION"
			sl.font_size = 64
			sl.pixel_size = 0.008
			sl.outline_size = 0
			sl.position = Vector3(0, 3.35, front + 0.18)
			body.add_child(sl)
			deco.append(sl)
			gable(body, w, d, h, roof, wall, 0.3, true, deco)
	fade.append_array([wall, roof])
	b.add_box_collider(body, Vector3(w, h, d), Vector3(0, h * 0.5, 0))
	if venue:
		_shop_sign(body, w, front, deco, asagiri)
	body.set_meta("fade_mats", fade)
	body.set_meta("fade_hide", deco)
	b._roofs.append([pos + Vector3(0, h, 0), Vector2(w, d) * 0.5])
	if style in ["machiya", "modern", "modern2", "house", "station"]:
		_clutter(pos, w, front, style, venue)
	# Weeds and flowers creep along the foot of every wall.
	for k in int(w / 1.2):
		if rng.randf() < 0.5:
			_tufts.append(pos + Vector3(-w * 0.5 + 0.4 + k * 1.2 + rng.randf_range(-0.3, 0.3), 0, front + 0.25))


func _upper_windows(body: Node3D, w: float, front: float, y: float, kinds: Array, deco: Array[Node]) -> void:
	var n := maxi(1, int(w / 2.3))
	var step := w / n
	for i in n:
		if rng.randf() < 0.15:
			continue
		var wx := -w * 0.5 + step * (i + 0.5)
		_panel(body, str(kinds[rng.randi() % kinds.size()]), Vector2(1.7, 1.28), Vector3(wx, y, front + 0.04), deco)
		_window_frame(body, wx, y, front, deco)


## Real depth around every window: a stone sill that catches light, a lintel and two jambs that throw small shadows.
func _window_frame(body: Node3D, x: float, y: float, front: float, deco: Array[Node]) -> void:
	var trim: StandardMaterial3D = b._mats["dark"]
	deco.append(b.add_mesh(body, b.box(Vector3(1.95, 0.09, 0.2)), b._mats["concrete"], Vector3(x, y - 0.69, front + 0.1)))
	deco.append(b.add_mesh(body, b.box(Vector3(1.9, 0.12, 0.12)), trim, Vector3(x, y + 0.7, front + 0.07)))
	for sx in [-1.0, 1.0]:
		deco.append(b.add_mesh(body, b.box(Vector3(0.09, 1.4, 0.1)), trim, Vector3(x + sx * 0.9, y, front + 0.06), 0.0, false))


## Exposed timber frame: corner posts and floor beams across the front (machiya, old school, keeper's house).
func _timber(body: Node3D, w: float, h: float, front: float, beams: Array, deco: Array[Node]) -> void:
	var timber: StandardMaterial3D = b._mats["dark"]
	for sx in [-1.0, 1.0]:
		deco.append(b.add_mesh(body, b.box(Vector3(0.22, h, 0.2)), timber, Vector3(sx * (w * 0.5 - 0.1), h * 0.5, front + 0.07)))
	for by in beams:
		deco.append(b.add_mesh(body, b.box(Vector3(w, 0.22, 0.18)), timber, Vector3(0, float(by), front + 0.07)))


## A slab edge per floor on concrete buildings (and a plinth), so they read as storeys, not a box.
func _storeys(body: Node3D, w: float, h: float, front: float, deco: Array[Node]) -> void:
	var y := 3.05
	while y < h - 0.5:
		deco.append(b.add_mesh(body, b.box(Vector3(w + 0.1, 0.16, 0.22)), b._mats["concrete"], Vector3(0, y, front + 0.08)))
		y += 2.8
	deco.append(b.add_mesh(body, b.box(Vector3(w + 0.06, 0.3, 0.12)), b._mats["rock"], Vector3(0, 0.15, front + 0.05)))


func _balcony(body: Node3D, w: float, front: float, y: float, deco: Array[Node]) -> void:
	var bw := minf(w - 0.6, 3.6)
	var bx := rng.randf_range(-(w - bw) * 0.5, (w - bw) * 0.5)
	deco.append(b.add_mesh(body, b.box(Vector3(bw, 0.1, 0.8)), b._mats["concrete"], Vector3(bx, y, front + 0.4)))
	deco.append(b.add_mesh(body, b.box(Vector3(bw, 0.9, 0.05)), b._flat(Color(0.75, 0.76, 0.78)), Vector3(bx, y + 0.5, front + 0.8), 0.0, false))
	if rng.randf() < 0.55:  # futon airing over the rail
		var fc: Color = [Color(0.95, 0.85, 0.85), Color(0.75, 0.85, 0.98), Color(0.98, 0.95, 0.8), Color(0.9, 0.7, 0.6)][rng.randi() % 4]
		deco.append(b.add_mesh(body, b.box(Vector3(minf(bw * 0.6, 1.8), 1.0, 0.12)), b._flat(fc), Vector3(bx + rng.randf_range(-0.3, 0.3), y + 0.55, front + 0.86), 0.0, false))
	else:  # laundry on a pole
		var pole: MeshInstance3D = b.add_mesh(body, b.cylinder(0.025, bw, 4), b._flat(Color(0.7, 0.7, 0.72)), Vector3(bx, y + 1.5, front + 0.55), 0.0, false)
		pole.rotation.z = PI * 0.5
		deco.append(pole)
		for k in rng.randi_range(2, 5):
			var lc := Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.8, 1.0))
			deco.append(b.add_mesh(body, b.box(Vector3(0.4, rng.randf_range(0.4, 0.7), 0.03)), b._flat(lc), Vector3(bx - bw * 0.4 + k * 0.5, y + 1.2, front + 0.55), 0.0, false))


func _pots(body: Node3D, w: float, front: float, dx: float, deco: Array[Node]) -> void:
	for k in rng.randi_range(1, 4):
		var px := dx + (1.1 + k * 0.45) * (1 if rng.randf() < 0.5 else -1)
		if absf(px) > w * 0.5 - 0.3:
			continue
		deco.append(b.add_mesh(body, b.cylinder(0.17, 0.3, 6, 0.2), b._flat(Color(0.65, 0.38, 0.25)), Vector3(px, 0.15, front + 0.35), 0.0, false))
		var leaf := SphereMesh.new()
		leaf.radius = rng.randf_range(0.2, 0.32)
		leaf.height = leaf.radius * 1.6
		leaf.radial_segments = 6
		leaf.rings = 3
		deco.append(b.add_mesh(body, leaf, b._flat(Color(0.3, 0.55, 0.3).lightened(rng.randf_range(-0.1, 0.1))), Vector3(px, 0.45, front + 0.35), 0.0, false))
		if rng.randf() < 0.5:
			_flowers.append(body.position + Vector3(px, 0.35, front + 0.4))


func _shop_sign(body: Node3D, w: float, front: float, deco: Array[Node], asagiri: bool) -> void:
	var types := ["food", "food", "food", "bar", "arcade", "karaoke", "pawn", "fortune", "clinic", "tapes"]
	var venue_id: String = "food" if asagiri else str(types[rng.randi() % types.size()])
	var label := Label3D.new()
	label.text = "ASAGIRI-DO" if asagiri else Copy.make(venue_id + "_name", rng).to_upper()
	label.font_size = 72 if label.text.length() <= 12 else 52
	label.pixel_size = 0.008
	label.modulate = Color(0.22, 0.12, 0.08)
	label.outline_size = 0
	label.position = Vector3(0, 2.7, front + 0.09)
	body.add_child(label)
	deco.append(label)
	# Noren curtain over the doorway + a red paper lantern.
	var noren_col: Color = [Color(0.16, 0.22, 0.42), Color(0.62, 0.14, 0.14), Color(0.2, 0.36, 0.26)][rng.randi() % 3]
	for k in 3:
		deco.append(b.add_mesh(body, b.box(Vector3(0.42, 0.75, 0.02)), painted(noren_col * 0.9, "jp_indigo", 1.0), Vector3(-0.45 + k * 0.45, 2.15, front + 0.35), 0.0, false))
	var lan := SphereMesh.new()
	lan.radius = 0.24
	lan.height = 0.6
	lan.radial_segments = 8
	lan.rings = 4
	var lm: StandardMaterial3D = b.emissive(Color(1.0, 0.35, 0.2), 1.5)
	night_mats.append(lm)
	deco.append(b.add_mesh(body, lan, lm, Vector3(w * 0.5 - 0.5, 2.3, front + 0.5), 0.0, false))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 0.0
	light.visible = false
	light.omni_range = 6.0
	light.position = Vector3(0, 1.6, front + 1.4)
	body.add_child(light)
	night_lights.append(light)
	# Nobori: tall coloured shop banners on poles, the shopping street's bunting.
	for k in rng.randi_range(1, 2):
		var nx := (w * 0.5 - 0.35) * (1 if k == 0 else -1)
		var flag_col: Color = [Color(0.85, 0.15, 0.15), Color(0.95, 0.75, 0.15), Color(0.15, 0.45, 0.8), Color(0.2, 0.6, 0.3), Color(0.95, 0.45, 0.6)][rng.randi() % 5]
		deco.append(b.add_mesh(body, b.cylinder(0.025, 2.6, 4), b._flat(Color(0.8, 0.8, 0.8)), Vector3(nx, 1.3, front + 1.1), 0.0, false))
		var flag: MeshInstance3D = b.add_mesh(body, b.box(Vector3(0.42, 1.7, 0.02)), b._flat(flag_col), Vector3(nx + 0.23, 1.55, front + 1.1), 0.0, true)
		deco.append(flag)
		deco.append(b.add_mesh(body, b.box(Vector3(0.12, 1.4, 0.025)), b._flat(Color(1, 1, 0.96)), Vector3(nx + 0.23, 1.55, front + 1.1), 0.0, false))
	b._add_venue(body, label.text, "", Vector3(0, 0.8, front + 0.95), venue_id)
	b._glow_spots.append([body.position + Vector3(0, 0, front + 0.6), Color(1.0, 0.75, 0.5), 0.8])


# --- Trees & nature -------------------------------------------------------------------------------

## A cherry tree in full April bloom (or an old pine at the shrines). Fades when it hides the player.
func tree(p: Vector3, x: int, z: int) -> void:
	var zn := zone(x, z)
	if zn in ["shrine", "dogshrine"] and rng.randf() < 0.4:
		_pine(p)
		return
	var body: StaticBody3D = b.static_body(p, LevelBuilder.LAYER_WORLD | LevelBuilder.LAYER_OCCLUDER)
	body.name = "Sakura"
	var bark: StandardMaterial3D = b._textured("jp_bark", Color(0.62, 0.5, 0.48), 0.5, 0.95, 0.0, 1.0)
	bark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var mats: Array = [bark]
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.2, 0.1))
	var trunk: MeshInstance3D = b.add_mesh(body, b.cylinder(0.2, 2.6, 7, 0.14), bark, Vector3(0, 1.3, 0))
	trunk.rotation = Vector3(lean.z, 0, -lean.x)
	for k in 3:
		var br: MeshInstance3D = b.add_mesh(body, b.cylinder(0.09, 1.8, 5, 0.04), bark, Vector3(0, 2.5, 0) + lean * 2.0, 0.0, false)
		br.rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(0.5, 1.0))
	var pinks: Array[StandardMaterial3D] = []
	for col in SAKURA:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.albedo_texture = b._tex("jp_f_blossom")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_scale = Vector3(4, 2, 1)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.emission_enabled = true
		m.emission = col.darkened(0.2)
		m.emission_energy_multiplier = 0.07  # blossoms glow softly in shade
		pinks.append(m)
		mats.append(m)
	# Inner crown (solid, darker) + many fluffy textured clumps around it.
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color(0.86, 0.58, 0.66)
	inner.roughness = 1.0
	inner.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	mats.append(inner)
	var core := SphereMesh.new()
	core.radius = 1.3
	core.height = 1.7
	core.radial_segments = 8
	core.rings = 4
	b.add_mesh(body, core, inner, Vector3(0, 3.4, 0) + lean * 2.0, 0.0, true)
	for k in rng.randi_range(13, 18):
		var blob := SphereMesh.new()
		blob.radius = rng.randf_range(0.5, 0.95)
		blob.height = blob.radius * rng.randf_range(1.2, 1.6)
		blob.radial_segments = 8
		blob.rings = 4
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.6, 2.1)
		b.add_mesh(body, blob, pinks[rng.randi() % pinks.size()],
			Vector3(cos(a) * r, rng.randf_range(2.7, 4.3) - r * 0.15, sin(a) * r) + lean * 2.0, 0.0, false)
	b.add_box_collider(body, Vector3(0.5, 2.0, 0.5), Vector3(0, 1.0, 0))
	body.set_meta("fade_mats", mats)
	body.set_meta("fade_hide", [])
	for k in 40:  # petal carpet under the crown
		var a2 := rng.randf() * TAU
		var r2 := sqrt(rng.randf()) * 2.6
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.4))
		_petal_spots.append(Transform3D(basis, p + Vector3(cos(a2) * r2, 0.015, sin(a2) * r2)))


func _pine(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p, LevelBuilder.LAYER_WORLD | LevelBuilder.LAYER_OCCLUDER)
	body.name = "Pine"
	var bark: StandardMaterial3D = b._textured("jp_bark", Color(0.55, 0.45, 0.4), 0.5, 0.95, 0.0, 1.0)
	var needles: StandardMaterial3D = b._leafy("", Color(0.45, 0.62, 0.5))
	bark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var trunk: MeshInstance3D = b.add_mesh(body, b.cylinder(0.22, 3.8, 7, 0.14), bark, Vector3(0.2, 1.9, 0))
	trunk.rotation.z = -0.15
	for k in 4:  # flat cloud-pruned layers, like a shrine pine
		var pad := SphereMesh.new()
		pad.radius = rng.randf_range(0.9, 1.4)
		pad.height = 0.6
		pad.radial_segments = 8
		pad.rings = 3
		b.add_mesh(body, pad, needles, Vector3(rng.randf_range(-1.0, 1.2), 2.6 + k * 0.6, rng.randf_range(-0.6, 0.6)), 0.0, k < 2)
	b.add_box_collider(body, Vector3(0.5, 2.0, 0.5), Vector3(0, 1.0, 0))
	body.set_meta("fade_mats", [bark, needles])
	body.set_meta("fade_hide", [])


## Called once the whole grid is built: riverside sakura rows, grass, petals, wires, road paint.
func finish() -> void:
	# The famous riverside sakura row (every third tile of the embankment).
	for x in range(3, b.width - 2, 3):
		if b.cell(x, 44) == "." and b.cell(x - 1, 44) != "g" and b.cell(x + 1, 44) != "g":
			tree(b.center(x, 44) + Vector3(0, 0, -0.3), x, 44)
	for z in b.height:
		for x in b.width:
			var kind := floor_kind(x, z)
			var c: String = b.cell(x, z)
			if c != "." and c != "_":
				continue
			if kind in ["jp_grass", "jp_schoolyard", "jp_gravel"] and rng.randf() < (0.55 if kind == "jp_grass" else 0.08):
				for k in rng.randi_range(1, 3):
					_tufts.append(b.center(x, z) + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9)))
				if kind == "jp_grass" and rng.randf() < 0.35:
					_flowers.append(b.center(x, z) + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9)))
			# Moss and weeds where paving meets a wall.
			if (b.cell(x, z - 1) in ["#", "b", "^"]) and rng.randf() < 0.4:
				_tufts.append(b.center(x, z) + Vector3(rng.randf_range(-0.8, 0.8), 0, -0.75))
	_plants(_tufts, [Color(0.42, 0.62, 0.3), Color(0.5, 0.7, 0.34), Color(0.36, 0.55, 0.3)], [0, 4], "Tufts")
	_plants(_flowers, [Color(1.0, 0.82, 0.3), Color(1.0, 0.95, 0.95), Color(0.95, 0.6, 0.8), Color(0.7, 0.62, 1.0)], [0, 4], "Flowers", 0.7)
	_petals_ground()
	_wires()
	_road_paint()
	_classrooms()
	_garlands()
	_boats()
	_planters()
	_shafts()
	_shrine_dressing()
	_ground_details()


func _plants(spots: Array[Vector3], colors: Array, cells: Array, nm: String, scale: float = 1.0) -> void:
	if spots.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = spots.size()
	for i in spots.size():
		var sc := rng.randf_range(0.45, 0.85) * scale
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc * (1 if rng.randf() < 0.5 else -1), sc, sc)), spots[i]))
		mm.set_instance_color(i, (colors[rng.randi() % colors.size()] as Color).lightened(rng.randf_range(-0.1, 0.1)))
		mm.set_instance_custom_data(i, Color(float(cells[rng.randi() % cells.size()]), 0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/foliage.gdshader")
	mat.set_shader_parameter("atlas", b._tex("foliage"))
	mat.set_shader_parameter("emission_strength", 0.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(mmi)


func _petals_ground() -> void:
	if _petal_spots.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.08)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.88)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.75, 0.82)
	m.emission_energy_multiplier = 0.15
	m.roughness = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = _petal_spots.size()
	for i in _petal_spots.size():
		mm.set_instance_transform(i, _petal_spots[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FallenPetals"
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(mmi)


## Utility poles ('n') strung together with sagging wires, plus drop lines to nearby roofs.
func _wires() -> void:
	for z in b.height:
		for x in b.width:
			if b.cell(x, z) == "n":
				_poles.append(b.center(x, z))
	for i in _poles.size():
		var best := -1
		var best_d := 1e9
		for j in _poles.size():
			if j == i:
				continue
			var dx: float = _poles[j].x - _poles[i].x
			var dd: float = _poles[i].distance_to(_poles[j])
			if dx > 0.5 and dd < 34.0 and dd < best_d:
				best = j
				best_d = dd
		if best >= 0:
			for hgt in [7.0, 7.25, 7.8]:
				_wire(_poles[i] + Vector3(0, hgt, 0), _poles[best] + Vector3(0, hgt, 0), 0.5 + best_d * 0.02)
		for r in b._roofs:
			var rp: Vector3 = r[0]
			if Vector2(rp.x - _poles[i].x, rp.z - _poles[i].z).length() < 9.0 and rng.randf() < 0.5:
				_wire(_poles[i] + Vector3(0, 6.6, 0), Vector3(rp.x, minf(rp.y, 5.4), rp.z + float(r[1].y)), 0.35)
	if _wire_xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = b.box(Vector3(1, 0.022, 0.022))
	mm.instance_count = _wire_xf.size()
	for i in _wire_xf.size():
		mm.set_instance_transform(i, _wire_xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Wires"
	mmi.multimesh = mm
	mmi.material_override = b._flat(Color(0.12, 0.12, 0.14))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	b.root.add_child(mmi)


func _wire(a: Vector3, c: Vector3, sag: float) -> void:
	var n := 10
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(c, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var seg := p - prev
		var basis := Basis.looking_at(seg.normalized(), Vector3.UP) * Basis(Vector3.UP, PI * 0.5)
		_wire_xf.append(Transform3D(basis * Basis.from_scale(Vector3(seg.length() + 0.02, 1, 1)), (p + prev) * 0.5))
		prev = p


## White edge lines and a dashed centre line on the asphalt roads, a zebra crossing at the school gate,
## and gutter grates along the kerb.
func _road_paint() -> void:
	var lines: Array[Transform3D] = []
	var grates: Array[Transform3D] = []
	for z in b.height:
		for x in b.width:
			if b.cell(x, z) != ",":
				continue
			var c: Vector3 = b.center(x, z)
			var top: bool = b.cell(x, z - 1) != ","
			var bottom: bool = b.cell(x, z + 1) != ","
			if top:
				lines.append(Transform3D(Basis().scaled(Vector3(2.0, 1, 0.12)), c + Vector3(0, 0.012, -0.75)))
				grates.append(Transform3D(Basis().scaled(Vector3(1.9, 1, 0.3)), c + Vector3(0, 0.01, -0.92)))
			if bottom:
				lines.append(Transform3D(Basis().scaled(Vector3(2.0, 1, 0.12)), c + Vector3(0, 0.012, 0.75)))
			if bottom and not top and x % 2 == 0:
				lines.append(Transform3D(Basis().scaled(Vector3(1.0, 1, 0.12)), c + Vector3(0, 0.012, -1.0)))
			if x >= 21 and x <= 24 and z >= 32 and z <= 33:
				for k in 5:
					lines.append(Transform3D(Basis().scaled(Vector3(0.4, 1, 1.7)), c + Vector3(-0.8 + k * 0.4, 0.013, 0)))
	var q := PlaneMesh.new()
	q.size = Vector2(1, 1)
	_mm(lines, q, b._flat(Color(0.92, 0.92, 0.88)), "RoadPaint")
	_mm(grates, q, b._flat(Color(0.3, 0.31, 0.33)), "Gutters")


func _mm(xf: Array[Transform3D], mesh: Mesh, mat: Material, nm: String) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(mmi)


## The world past the map edge: forest on the hills, the sea to the south.
func margin() -> void:
	var land: Array[Transform3D] = []
	var sea: Array[Transform3D] = []
	for z in range(-4, b.height + 14):
		for x in range(-8, b.width + 8):
			if x >= 0 and x < b.width and z >= 0 and z < b.height:
				continue
			var p: Vector3 = b.center(x, z)
			if z >= b.height - 3:
				sea.append(Transform3D(Basis(), p + Vector3(0, -0.3, 0)))
			else:
				land.append(Transform3D(Basis(), p + Vector3(0, -0.2, 0)))
	var tile: BoxMesh = b.box(Vector3(T, 0.2, T))
	_mm(land, tile, b._mats["jp_forest"], "MarginForest")
	_mm(sea, tile, b._mats["water"], "MarginSea")


## 0 = day, 1 = full night: windows, lanterns and shop lights come on at dusk.
func set_night(t: float) -> void:
	for m in night_mats:
		m.emission_energy_multiplier = 0.05 + 1.05 * t
	for l in night_lights:
		if is_instance_valid(l):
			l.light_energy = 1.1 * t
			l.visible = t > 0.02


## Open ground where sparrows like to peck (TownLife), and the flower spots for butterflies.
func ground_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for z in b.height:
		for x in b.width:
			if b.cell(x, z) in [".", "_"] and floor_kind(x, z) in ["jp_grass", "jp_paving", "jp_gravel", "jp_schoolyard", "jp_sando"] and rng.randf() < 0.2:
				out.append(b.center(x, z))
	return out


func flower_spots() -> Array[Vector3]:
	return _flowers


## Desks, chairs and a blackboard in every classroom (the camera looks into the school from above).
func _classrooms() -> void:
	var tops: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var chairs: Array[Transform3D] = []
	var rooms := {}
	for z in range(21, 25):
		for x in range(7, 39):
			if b.cell(x, z) != "_" or zone(x, z) != "school":
				continue
			var room := 0 if x < 17 else (1 if x < 28 else 2)
			rooms[room] = true
			if z == 21 or b.cell(x - 1, z) == "#" or b.cell(x + 1, z) == "#":
				continue
			for k in 2:
				var c: Vector3 = b.center(x, z) + Vector3(-0.5 + k * 1.0, 0, 0.2)
				tops.append(Transform3D(Basis(), c + Vector3(0, 0.72, 0)))
				frames.append(Transform3D(Basis(), c + Vector3(0, 0.35, 0)))
				chairs.append(Transform3D(Basis(), c + Vector3(0, 0.0, 0.55)))
	_mm(tops, b.box(Vector3(0.62, 0.05, 0.45)), b._textured("jp_hinoki", Color(0.95, 0.85, 0.7), 0.5, 0.8, 0.0, 0.5), "Desks")
	_mm(frames, b.box(Vector3(0.5, 0.68, 0.36)), b._flat(Color(0.5, 0.52, 0.55)), "DeskFrames")
	var chair := BoxMesh.new()
	chair.size = Vector3(0.42, 0.85, 0.08)
	var seat_xf: Array[Transform3D] = []
	var back_xf: Array[Transform3D] = []
	for t in chairs:
		seat_xf.append(Transform3D(Basis(), t.origin + Vector3(0, 0.42, -0.12)))
		back_xf.append(Transform3D(Basis(), t.origin + Vector3(0, 0.45, 0.1)))
	_mm(back_xf, chair, b._flat(Color(0.62, 0.45, 0.3)), "ChairBacks")
	_mm(seat_xf, b.box(Vector3(0.42, 0.06, 0.4)), b._flat(Color(0.68, 0.5, 0.34)), "ChairSeats")
	for room in rooms:
		var cx: float = [12.0, 23.0, 34.0][room] * T
		var board := QuadMesh.new()
		board.size = Vector2(6.0, 1.4)
		var bm: StandardMaterial3D = b._flat(Color(0.2, 0.36, 0.28))
		b.add_mesh(b.root, board, bm, Vector3(cx, 1.7, 21 * T + 0.06), 0.0, false)
		b.add_mesh(b.root, b.box(Vector3(6.2, 0.08, 0.12)), b._textured("jp_hinoki", Color.WHITE, 0.5, 0.8, 0.0, 0.5), Vector3(cx, 0.98, 21 * T + 0.1), 0.0, false)
		b.add_mesh(b.root, b.box(Vector3(1.4, 1.0, 0.6)), b._textured("jp_hinoki", Color(0.8, 0.65, 0.5), 0.5, 0.8, 0.0, 0.5), Vector3(cx, 0.5, 21 * T + 1.2))
		var day := Label3D.new()
		day.text = ["4/8 (Wed)   duty: Sato", "TEST ON FRIDAY!!", "Keep your word.  - the founder"][room]
		day.font_size = 40
		day.pixel_size = 0.006
		day.modulate = Color(0.94, 0.96, 0.9)
		day.outline_size = 0
		day.position = Vector3(cx - 1.0, 1.9, 21 * T + 0.08)
		b.root.add_child(day)


## Red and white paper lanterns strung across the shopping street (they light up at dusk).
func _garlands() -> void:
	var strings: Array[Transform3D] = []
	var red: Array[Transform3D] = []
	var white: Array[Transform3D] = []
	for zz in [38.6, 41.4]:
		var z: float = zz * T
		var x0 := 2.0 * T
		var x1 := 40.0 * T
		var n := int((x1 - x0) / 7.0)
		for i in n:
			var a := Vector3(x0 + i * 7.0, 6.0, z)
			var c := Vector3(x0 + (i + 1) * 7.0, 6.0, z)
			var before := _wire_xf.size()
			_wire(a, c, 0.45)
			for k in range(before, _wire_xf.size()):
				strings.append(_wire_xf[k])
			_wire_xf.resize(before)
			for k in 4:
				var t := (k + 0.5) / 4.0
				var p := a.lerp(c, t) - Vector3(0, 0.45 * 4.0 * t * (1.0 - t) + 0.28, 0)
				(red if (i + k) % 2 == 0 else white).append(Transform3D(Basis(), p))
	_mm(strings, b.box(Vector3(1, 0.02, 0.02)), b._flat(Color(0.15, 0.12, 0.12)), "GarlandString")
	var lan := SphereMesh.new()
	lan.radius = 0.14
	lan.height = 0.36
	lan.radial_segments = 8
	lan.rings = 4
	var rm: StandardMaterial3D = b.emissive(Color(0.95, 0.3, 0.22), 0.0)
	var wm: StandardMaterial3D = b.emissive(Color(1.0, 0.95, 0.85), 0.0)
	rm.albedo_color = Color(0.9, 0.25, 0.2)
	wm.albedo_color = Color(0.98, 0.96, 0.9)
	night_mats.append_array([rm, wm])
	_mm(red, lan, rm, "LanternsRed")
	_mm(white, lan, wm, "LanternsWhite")


## A couple of small fishing boats moored off the beach, bobbing gently (a shader-free tween).
func _boats() -> void:
	for i in 3:
		var x: int = [10, 24, 47][i]
		var p: Vector3 = b.center(x, 54) + Vector3(rng.randf_range(-0.5, 0.5), -0.05, rng.randf_range(-0.3, 0.6))
		var boat := Node3D.new()
		boat.position = p
		boat.rotation.y = rng.randf_range(-0.3, 0.3)
		b.root.add_child(boat)
		var hull_col: Color = [Color(0.95, 0.95, 0.92), Color(0.3, 0.5, 0.75), Color(0.85, 0.4, 0.3)][i]
		var hull := PrismMesh.new()
		hull.size = Vector3(3.4, 0.6, 1.3)
		var hm: MeshInstance3D = b.add_mesh(boat, hull, b._flat(hull_col), Vector3(0, 0.2, 0), 0.0, true)
		hm.rotation.z = PI
		b.add_mesh(boat, b.box(Vector3(2.8, 0.08, 1.1)), b._textured("jp_hinoki", Color(0.85, 0.75, 0.6), 0.5, 0.8, 0.0, 0.5), Vector3(0, 0.48, 0), 0.0, false)
		b.add_mesh(boat, b.box(Vector3(0.8, 0.7, 0.8)), b._flat(Color(0.95, 0.95, 0.95)), Vector3(-0.6, 0.85, 0), 0.0, true)
		b.add_mesh(boat, b.cylinder(0.03, 1.8, 4), b._flat(Color(0.3, 0.3, 0.3)), Vector3(0.6, 1.4, 0), 0.0, false)
		var tw := boat.create_tween().set_loops()
		tw.tween_property(boat, "position:y", p.y + 0.08, 1.6 + i * 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(boat, "position:y", p.y - 0.04, 1.6 + i * 0.3).set_trans(Tween.TRANS_SINE)


## Wooden planters full of spring flowers down the middle of the shopping street.
func _planters() -> void:
	var wood: StandardMaterial3D = b._textured("jp_cedar", Color(0.7, 0.58, 0.5), 0.5, 0.85, 0.0, 0.6)
	var soil: StandardMaterial3D = b._flat(Color(0.3, 0.22, 0.16))
	var spots: Array[Vector3] = []
	var blooms: Array[Vector3] = []
	for x in range(4, 40, 6):
		var z := 38 if (x / 6) % 2 == 0 else 39
		if b.cell(x, z) != "." or b.cell(x + 1, z) != ".":
			continue
		var p: Vector3 = b.center(x, z) + Vector3(T * 0.5, 0, 0)
		var body: StaticBody3D = b.static_body(p)
		b.add_mesh(body, b.box(Vector3(2.2, 0.55, 0.7)), wood, Vector3(0, 0.27, 0))
		b.add_mesh(body, b.box(Vector3(2.0, 0.05, 0.55)), soil, Vector3(0, 0.53, 0), 0.0, false)
		b.add_box_collider(body, Vector3(2.2, 0.6, 0.7), Vector3(0, 0.3, 0))
		for k in 7:
			var at := p + Vector3(-0.9 + k * 0.3, 0.5, rng.randf_range(-0.15, 0.15))
			spots.append(at)
			if k % 2 == 0:
				blooms.append(at + Vector3(0.1, 0.05, 0.05))
	_plants(spots, [Color(0.4, 0.62, 0.32), Color(0.48, 0.7, 0.36)], [0, 4], "PlanterLeaves", 0.8)
	_plants(blooms, [Color(1.0, 0.45, 0.55), Color(1.0, 0.85, 0.3), Color(0.98, 0.98, 1.0), Color(0.75, 0.55, 1.0)], [0, 4], "PlanterBlooms", 0.6)
	_flowers.append_array(blooms)


## God rays: tall additive beams slanting down through alley gaps, shrine trees, the steps, the courtyard and
## between the riverside sakura. Strongest in the morning and at Omagatoki (set_sun).
func _shafts() -> void:
	var spots: Array[Vector3] = []
	for z in range(34, 43):
		for x in range(1, b.width - 1):
			if b.cell(x, z) == "." and b.cell(x - 1, z) == "b" and b.cell(x + 1, z) == "b" and rng.randf() < 0.6:
				spots.append(b.center(x, z) + Vector3(0, 0, 1.0))
	for k in 7:
		spots.append(b.center(rng.randi_range(18, 37), rng.randi_range(2, 8)))
	for z in range(11, 19, 3):
		spots.append(b.center(4, z))
	for x in range(6, 38, 7):
		spots.append(b.center(x, 29))
	for x in range(5, b.width - 3, 9):
		spots.append(b.center(x, 44) + Vector3(T * 0.5, 0, 0))
	var tex: Texture2D = b._tex("light_shaft")
	for p in spots:
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(1.6, 3.2), rng.randf_range(6.0, 8.0))
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_texture = tex
		var base := rng.randf_range(0.22, 0.38)
		m.albedo_color = Color(1.0, 0.86, 0.62, base)
		m.set_meta("base", base)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p + Vector3(0, q.size.y * 0.42, -0.4)
		mi.rotation = Vector3(0, 0, -0.42 + rng.randf_range(-0.08, 0.08))
		b.root.add_child(mi)
		shaft_mats.append(m)


## Sun shafts: 0 = none (noon, night, rain), 1 = full golden beams. `warm` 0..1 shifts gold -> rose at dusk.
func set_sun(strength: float, warm: float) -> void:
	var col := Color(1.0, 0.88, 0.62).lerp(Color(1.0, 0.6, 0.45), warm)
	for m in shaft_mats:
		col.a = float(m.get_meta("base", 0.2)) * strength
		m.albedo_color = col


# --- Street-level clutter: what makes a Japanese street (and an HD-2D diorama) feel lived in ----------------

## Things people leave in front of their house or shop. Positions are world space; most props have no collider
## (they sit against the facade), the big ones (vending machines, stands) do.
func _clutter(pos: Vector3, w: float, front: float, style: String, venue: bool) -> void:
	var z := pos.z + front + 0.55
	_grates.append(Transform3D(Basis().scaled(Vector3(w - 0.2, 1, 0.32)), Vector3(pos.x, 0.012, pos.z + front + 0.2)))
	var slots: Array[float] = []
	var x := -w * 0.5 + 0.6
	while x < w * 0.5 - 0.5:
		if not (venue and absf(x) < 1.0):
			slots.append(x)
		x += 0.9
	slots.shuffle()
	var picks := ["bikes", "crates", "pots", "umbrellas", "sign", "ac", "vending"] if style != "house" \
		else ["bikes", "pots", "pots", "ac", "mailbox", "styro"]
	if venue:
		_display_stand(Vector3(pos.x + (w * 0.5 - 1.0) * (1 if rng.randf() < 0.5 else -1), 0, z + 0.1))
		_a_sign(Vector3(pos.x + rng.randf_range(-0.6, 0.6), 0, z + 0.9))
	for k in mini(slots.size(), rng.randi_range(2, 4)):
		var p := Vector3(pos.x + slots[k], 0, z)
		match str(picks[rng.randi() % picks.size()]):
			"bikes":
				for i in rng.randi_range(1, 2):
					b._jp_cell("q", p + Vector3(i * 0.55, 0, 0.25), 0, 0)
			"crates":
				_crates(p)
			"pots":
				for i in rng.randi_range(2, 4):
					_pot(p + Vector3(i * 0.32 - 0.4, 0, rng.randf_range(-0.1, 0.1)))
			"umbrellas":
				_umbrellas(p)
			"sign":
				_a_sign(p + Vector3(0, 0, 0.3))
			"ac":
				_ac_unit(p + Vector3(0, 0, -0.15))
			"vending":
				if rng.randf() < 0.5:
					b._vending(p + Vector3(0, 0, 0.1))
			"mailbox":
				var mb: StaticBody3D = b.static_body(p)
				b.add_mesh(mb, b.cylinder(0.04, 1.0, 5), b._mats["pipe"], Vector3(0, 0.5, 0), 0.0, false)
				b.add_mesh(mb, b.box(Vector3(0.36, 0.3, 0.22)), painted(Color(0.85, 0.2, 0.18)), Vector3(0, 1.1, 0))
			"styro":
				var sb: StaticBody3D = b.static_body(p)
				b.add_mesh(sb, b.box(Vector3(0.7, 0.3, 0.4)), painted(Color(0.95, 0.95, 0.93)), Vector3(0, 0.15, 0))
				for i in 4:
					_tufts.append(p + Vector3(-0.25 + i * 0.17, 0.3, 0))


func _pot(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var h := rng.randf_range(0.22, 0.4)
	b.add_mesh(body, b.cylinder(0.14, h, 7, 0.17), painted([Color(0.65, 0.38, 0.25), Color(0.5, 0.52, 0.55), Color(0.85, 0.82, 0.75)][rng.randi() % 3]), Vector3(0, h * 0.5, 0), 0.0, false)
	var leaf := SphereMesh.new()
	leaf.radius = rng.randf_range(0.16, 0.28)
	leaf.height = leaf.radius * 1.7
	leaf.radial_segments = 7
	leaf.rings = 4
	b.add_mesh(body, leaf, b._leafy("pot_leaf", Color(0.8, 1.0, 0.8)), Vector3(0, h + leaf.radius * 0.6, 0), 0.0, true)
	if rng.randf() < 0.4:
		_flowers.append(p + Vector3(0, h + 0.1, 0.05))


## Plastic beer / produce crates, stacked.
func _crates(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var col: Color = [Color(0.95, 0.75, 0.15), Color(0.2, 0.45, 0.8), Color(0.85, 0.25, 0.2), Color(0.25, 0.6, 0.35)][rng.randi() % 4]
	var m := painted(col, "jp_sheet", 1.0)
	for i in rng.randi_range(1, 3):
		var c: MeshInstance3D = b.add_mesh(body, b.box(Vector3(0.5, 0.3, 0.38)), m, Vector3(rng.randf_range(-0.04, 0.04), 0.15 + i * 0.31 - 0.31, 0))
		c.rotation.y = rng.randf_range(-0.15, 0.15)


func _umbrellas(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	b.add_mesh(body, b.cylinder(0.16, 0.5, 8), b._mats["metal"], Vector3(0, 0.25, 0), 0.0, true)
	for i in rng.randi_range(2, 4):
		var u: MeshInstance3D = b.add_mesh(body, b.cylinder(0.04, 0.9, 5, 0.01), painted(Color.from_hsv(rng.randf(), 0.5, 0.8)), Vector3(rng.randf_range(-0.08, 0.08), 0.6, rng.randf_range(-0.08, 0.08)), 0.0, false)
		u.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))


## Standing A-frame sign board (menu / sale), leaning boards on a stand.
func _a_sign(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var board := painted([Color(0.15, 0.25, 0.2), Color(0.9, 0.88, 0.8), Color(0.15, 0.15, 0.18)][rng.randi() % 3])
	for sd in [-1.0, 1.0]:
		var bd: MeshInstance3D = b.add_mesh(body, b.box(Vector3(0.5, 0.85, 0.03)), board, Vector3(0, 0.42, sd * 0.12))
		bd.rotation.x = -sd * 0.22
	b.add_mesh(body, b.box(Vector3(0.4, 0.08, 0.04)), painted([Color(0.9, 0.2, 0.15), Color(0.95, 0.75, 0.2)][rng.randi() % 2]), Vector3(0, 0.62, 0.21), 0.0, false)
	for k in 3:
		b.add_mesh(body, b.box(Vector3(0.3, 0.025, 0.02)), painted(Color(0.95, 0.95, 0.9)), Vector3(0, 0.48 - k * 0.1, 0.22 - k * 0.02), 0.0, false)


## Outdoor air-conditioner unit with its fan grille and pipe.
func _ac_unit(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	b.add_mesh(body, b.box(Vector3(0.75, 0.55, 0.3)), painted(Color(0.92, 0.92, 0.9), "jp_sheet", 1.0), Vector3(0, 0.3, 0))
	var fan: MeshInstance3D = b.add_mesh(body, b.cylinder(0.2, 0.02, 12), painted(Color(0.3, 0.3, 0.32)), Vector3(-0.1, 0.32, 0.16), 0.0, false)
	fan.rotation.x = PI * 0.5
	b.add_mesh(body, b.cylinder(0.025, 0.6, 5), painted(Color(0.85, 0.83, 0.78)), Vector3(0.3, 0.6, -0.1), 0.0, false)


## Tiered wooden stand of goods in front of a shop (fruit, sweets, souvenirs).
func _display_stand(p: Vector3) -> void:
	var body: StaticBody3D = b.static_body(p)
	var wood: StandardMaterial3D = b._mats["crate"]
	for t in 3:
		b.add_mesh(body, b.box(Vector3(1.2, 0.08, 0.32)), wood, Vector3(0, 0.35 + t * 0.28, 0.25 - t * 0.2))
		for k in 5:
			var col := Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.8), rng.randf_range(0.7, 1.0))
			b.add_mesh(body, b.box(Vector3(0.18, rng.randf_range(0.1, 0.2), 0.2)), painted(col), Vector3(-0.48 + k * 0.24, 0.47 + t * 0.28, 0.25 - t * 0.2), 0.0, false)
	for sx in [-0.58, 0.58]:
		b.add_mesh(body, b.box(Vector3(0.05, 0.95, 0.05)), wood, Vector3(sx, 0.47, 0.0), 0.0, false)
	b.add_box_collider(body, Vector3(1.2, 1.0, 0.7), Vector3(0, 0.5, 0.05))


## The shrine is more than a hall: stone lanterns line the approach, an omikuji rack full of tied fortunes,
## a stack of sake barrels given by the town, a low sacred fence, a bamboo broom against the hall.
func _shrine_dressing() -> void:
	for z in [3, 5, 7]:
		for x in [25, 29]:
			if b.cell(x, z) == "_":
				b._jp_cell("h", b.center(x, z) + Vector3(0.6 if x == 25 else -0.6, 0, 0), x, z)
	# omikuji rack
	var rp: Vector3 = b.center(33, 5)
	var rack: StaticBody3D = b.static_body(rp)
	var wood: StandardMaterial3D = b._mats["dark"]
	for sx in [-1.0, 1.0]:
		b.add_mesh(rack, b.box(Vector3(0.1, 1.5, 0.1)), wood, Vector3(sx * 1.1, 0.75, 0))
	var knots: Array[Transform3D] = []
	for row in 3:
		b.add_mesh(rack, b.cylinder(0.015, 2.2, 4), painted(Color(0.3, 0.3, 0.3)), Vector3(0, 0.75 + row * 0.3, 0), 0.0, false).rotation.z = PI * 0.5
		for k in 14:
			var at := rp + Vector3(-1.0 + k * 0.15 + rng.randf_range(-0.03, 0.03), 0.72 + row * 0.3, rng.randf_range(-0.02, 0.02))
			knots.append(Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.4, 0.4)), at))
	_mm(knots, b.box(Vector3(0.05, 0.11, 0.03)), painted(Color(1.0, 1.0, 0.98)), "OmikujiKnots")
	b.add_box_collider(rack, Vector3(2.3, 1.5, 0.3), Vector3(0, 0.75, 0))
	# sake barrels (kazaridaru), stacked in a pyramid beside the hall
	var bp: Vector3 = b.center(22, 3)
	var barrels: StaticBody3D = b.static_body(bp)
	var labels := [Color(0.85, 0.2, 0.15), Color(0.15, 0.3, 0.6), Color(0.95, 0.95, 0.9), Color(0.2, 0.5, 0.3)]
	for row in 3:
		for k in 3 - row:
			var at := Vector3(-0.55 * (2 - row) * 0.5 + k * 0.55, 0.27 + row * 0.5, 0)
			b.add_mesh(barrels, b.cylinder(0.26, 0.5, 10), painted(labels[(row + k) % labels.size()]), at, 0.0, true)
			b.add_mesh(barrels, b.cylinder(0.27, 0.06, 10), painted(Color(0.8, 0.7, 0.45)), at + Vector3(0, 0.18, 0), 0.0, false)
	b.add_box_collider(barrels, Vector3(1.7, 1.5, 0.6), Vector3(0, 0.75, 0))
	# tamagaki: low vermilion fence either side of the hall
	var red: StandardMaterial3D = prop_mat("vermilion", Color.RED)
	for side in [-1.0, 1.0]:
		var f0: Vector3 = b.center(27, 4) + Vector3(side * 4.6, 0, -1.6)
		for k in 6:
			b.add_mesh(b.root, b.box(Vector3(0.1, 0.9, 0.1)), red, f0 + Vector3(side * k * 0.45, 0.45, 0), 0.0, true)
		b.add_mesh(b.root, b.box(Vector3(2.5, 0.08, 0.08)), red, f0 + Vector3(side * 1.12, 0.8, 0), 0.0, false)
		b.add_mesh(b.root, b.box(Vector3(2.5, 0.08, 0.08)), red, f0 + Vector3(side * 1.12, 0.4, 0), 0.0, false)
	# shrine nobori: tall red banners with a white stripe lining the approach
	for z in [2, 4, 6, 8]:
		for x in [24, 30]:
			if not b.walkable(x, z):
				continue
			var at: Vector3 = b.center(x, z) + Vector3(0.7 if x == 24 else -0.7, 0, 0.5)
			b.add_mesh(b.root, b.cylinder(0.03, 3.0, 5), b._mats["dark"], at + Vector3(0, 1.5, 0), 0.0, true)
			b.add_mesh(b.root, b.box(Vector3(0.45, 2.2, 0.02)), painted(Color(0.95, 0.22, 0.16)), at + Vector3(0.24, 1.7, 0), 0.0, true)
			b.add_mesh(b.root, b.box(Vector3(0.1, 1.8, 0.025)), painted(Color(0.95, 0.93, 0.88)), at + Vector3(0.24, 1.7, 0.0), 0.0, false)
	# bamboo broom against the hall
	var broom: MeshInstance3D = b.add_mesh(b.root, b.cylinder(0.03, 1.6, 5), prop_mat("wood_light", Color.WHITE), b.center(30, 3) + Vector3(0, 0.8, 0.6), 0.0, true)
	broom.rotation.z = 0.25


## Ground-level detail everywhere: tactile paving to the station and along the road, drain grates under the shop
## fronts, kerbs between road and pavement, patched asphalt, manhole covers.
func _ground_details() -> void:
	var tactile: Array[Transform3D] = []
	var kerbs: Array[Transform3D] = []
	var patches: Array[Transform3D] = []
	var holes: Array[Transform3D] = []
	for x in range(1, b.width - 1):
		if b.walkable(x, 34) and b.cell(x, 34) != ",":
			tactile.append(Transform3D(Basis().scaled(Vector3(2.0, 1, 0.3)), b.center(x, 34) + Vector3(0, 0.014, -0.55)))
		for z in [31, 34, 42, 44]:
			if b.cell(x, z) != "," and (b.cell(x, z - 1) == "," or b.cell(x, z + 1) == ","):
				var side := -1.0 if b.cell(x, z - 1) == "," else 1.0
				kerbs.append(Transform3D(Basis(), b.center(x, z) + Vector3(0, 0.06, side * 0.92)))
	for z in range(36, 42):
		if b.walkable(8, z):
			tactile.append(Transform3D(Basis().scaled(Vector3(0.3, 1, 2.0)), b.center(8, z) + Vector3(0.6, 0.014, 0)))
	for z in b.height:
		for x in b.width:
			if b.cell(x, z) == "," and rng.randf() < 0.08:
				patches.append(Transform3D(Basis(Vector3.UP, rng.randf() * 0.4).scaled(Vector3(rng.randf_range(0.8, 2.2), 1, rng.randf_range(0.5, 1.4))), b.center(x, z) + Vector3(rng.randf_range(-0.5, 0.5), 0.011, rng.randf_range(-0.4, 0.4))))
			elif b.cell(x, z) == "," and rng.randf() < 0.03:
				holes.append(Transform3D(Basis(), b.center(x, z) + Vector3(rng.randf_range(-0.5, 0.5), 0.013, rng.randf_range(-0.4, 0.4))))
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	_mm(tactile, plane, painted(Color(0.95, 0.78, 0.15), "jp_sando", 1.0), "TactilePaving")
	_mm(_grates, plane, painted(Color(0.35, 0.36, 0.38), "jp_sheet", 2.0), "DrainGrates")
	_mm(kerbs, b.box(Vector3(2.0, 0.14, 0.18)), b._mats["rock"], "Kerbs")
	_mm(patches, plane, b._textured("jp_asphalt", Color(0.72, 0.72, 0.75), 0.25, 0.8, 0.0, 0.5), "AsphaltPatches")
	var disc := CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.38
	disc.height = 0.02
	disc.radial_segments = 14
	_mm(holes, disc, painted(Color(0.45, 0.42, 0.4), "jp_sheet", 3.0), "Manholes")
