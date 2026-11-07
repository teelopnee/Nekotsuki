extends Level
## Suzunari Gakuen, inside. One floor at a time (data/maps/school_<floor>.txt, built by JPSchool): stairs S/D/K move
## between floors, X leads back out to town. Room name plates and light pools come from data/school.json `rooms`;
## every room's features are interactables that open a Town.scene; cast and staff stand where they work
## (Town spirits with `indoor` + `itile`); students fill the classrooms ('N'). Same clock, phone, Amane and day
## end as the town.

const MAP := "res://data/maps/school_%s.txt"
const FLOORS := ["1f", "2f", "3f", "roof"]
const SURNAMES := ["Sato", "Suzuki", "Takahashi", "Tanaka", "Ito", "Watanabe", "Yamamoto", "Nakamura", "Kobayashi", "Kato"]
const GIVEN := ["Haruto", "Sota", "Yuto", "Ren", "Yui", "Hina", "Mei", "Rin", "Sakura", "Aoi", "Koharu", "Taiga"]

var floor_id := "1f"
var data := {}
var amane: AmaneNPC
var overlay: Node
var _key: DirectionalLight3D
var _room_lights: Array[OmniLight3D] = []
var _students: Array = []  ## [{npc, room}] - who is where, so the bell can move them


var _ending := false

func _setup() -> void:
	if FileAccess.file_exists("res://data/school.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/school.json"))
		if parsed is Dictionary:
			data = parsed
	floor_id = str(Router.params.get("floor", Game.flags.get("school_floor", "1f")))
	if not floor_id in FLOORS:
		floor_id = "1f"
	Game.flags["school_floor"] = floor_id
	var roof := floor_id == "roof"
	palette = {
		"theme": "suzunari", "roof": roof, "bg": "#b8c8e0" if roof else "#3a3440", "ground": "#8c8796", "ground_alt": "#9a94a4",
		"wall": "#efe8da", "fog": "#d8d4e0", "fog_density": 0.002, "sun": "#ffe8c8", "sun_energy": 1.2, "ambient": "#c8ccd8",
		"ambient_energy": 1.0, "neon": ["#ffd6a0"], "props": [], "ground_tex": "concrete", "path_tex": "asphalt",
		"horizon": [], "foliage": 0.0, "plant": "#6aa84f", "exposure": 1.0}
	level_seed = 3100 + FLOORS.find(floor_id)
	camera_pitch = 27.0  # lower than outside: the back walls (windows, posters, the board) are part of the room
	camera_distance = 13.5
	camera_fov = 32.0
	music = Week.music_now()
	spawn_key = "default"
	CharacterLook.theme = "suzunari"
	Copy.theme = "suzunari"
	DataDB.apply_theme("suzunari")
	Game.location_id = "school"
	Game.location_name = "Suzunari Gakuen - " + str(data.get("floors", {}).get(floor_id, floor_id))


func _is_outdoor() -> bool:
	return false


func _get_layout() -> Array:
	var rows: Array = []
	var path := MAP % floor_id
	if FileAccess.file_exists(path):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges() != "":
				rows.append(line)
	return rows


func spawn_npc(role: String, pos: Vector3, recruit_id: String = "") -> NPC:
	var n: NPC = NPC_SCENE.instantiate()
	n.role = role
	n.recruit_id = recruit_id
	n.look = CharacterLook.random_look(rng, "student")
	n.npc_name = "%s %s" % [SURNAMES[rng.randi() % SURNAMES.size()], GIVEN[rng.randi() % GIVEN.size()]]
	n.traits.assign([["poor", "worker", "artsy", "rebel", "weird"][rng.randi() % 5]])
	actors.add_child(n)
	n.global_position = pos + Vector3(0, 0.1, 0)
	return n


func _post_build() -> void:
	Game.set_deferred("air_billing_active", false)
	Clock.running = true
	Week.level_ready.call_deferred()
	_place_player()
	_wire_links()
	_rooms()
	_features()
	_people()
	_crowd()
	_build_motes()
	Clock.period_changed.connect(_bell)
	# only lamps and window light bloom, not light hair under the tubes (or in the sun on the roof)
	environment.glow_hdr_threshold = 1.35 if floor_id != "roof" else 1.8
	environment.glow_intensity = 0.6
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.06
	environment.tonemap_exposure = 1.3
	if camera_rig and camera_rig.post_mat:
		camera_rig.post_mat.set_shader_parameter("vignette", 0.3)
	var a = NPC_SCENE.instantiate()
	a.set_script(load("res://src/actors/amane_npc.gd"))
	amane = a
	actors.add_child(amane)
	amane.global_position = player.global_position + Vector3(1.2, 0.1, 2.0)
	if not Amane.st()["met"] or Amane.route() == "ignore" and randf() < 0.5:
		amane.global_position = player.global_position + Vector3(0, 0.1, 9.0)
	overlay = load("res://src/ui/neko_overlay.gd").new()
	overlay.level = self
	add_child(overlay)
	Clock.minute_passed.connect(_on_minute)
	_apply_light()
	if hud:
		EventBus.toast.emit(Game.location_name, Color(1.0, 0.92, 0.8))


func _exit_tree() -> void:
	super._exit_tree()
	Clock.running = false


func _place_player() -> void:
	var at = Router.params.get("at")
	if at is Array and at.size() == 2:
		player.global_position = builder.center(int(at[0]), int(at[1])) + Vector3(0, 0.1, 0)
		return
	for l in _links():
		if l.char == "X":
			player.global_position = l.pos + Vector3(0, 0.1, -2.5)
			return
		if l.char == "D":
			player.global_position = l.pos + Vector3(0, 0.1, 2.0)


func _links() -> Array:
	var s = build.get("school")
	return s.links if s else []


# --- Getting around ---------------------------------------------------------------------------

func _wire_links() -> void:
	for l in _links():
		var c: String = l.char
		if c == "X" and builder.cell(l.tile.x - 1, l.tile.y) == "X":
			continue  # one door for the pair
		var it := Interactable.new()
		it.prompt = {"S": "Go upstairs", "K": "Go up to the roof", "D": "Go downstairs", "X": "Leave school"}.get(c, "Use")
		it.radius = 1.7
		add_child(it)
		it.global_position = l.pos + Vector3(0.0 if c != "X" else LevelBuilder.TILE * 0.5, 0.8, 0.0 if c != "X" else -1.2)
		it.interacted.connect(use_link.bind(c, l.tile))


func use_link(_p: Node, c: String, tile: Vector2i) -> void:
	var i := FLOORS.find(floor_id)
	match c:
		"S", "K":
			go_floor(FLOORS[mini(i + 1, FLOORS.size() - 1)], Vector2i(tile.x, tile.y + 1))
		"D":
			go_floor(FLOORS[maxi(i - 1, 0)], Vector2i(tile.x, tile.y + 1))
		"X":
			leave()


func go_floor(id: String, at: Vector2i) -> void:
	Game.flags["school_floor"] = id
	Router.goto(Router.SCHOOL, {"floor": id, "at": [at.x, at.y]}, 0.25)


## Back out to town, at the door we came in by.
func leave() -> void:
	Game.location_id = "suzunari"
	var door = Game.flags.get("school_door", [11, 28])
	Router.goto(Router.SUZUNARI, {"spawn_tile": door})


# --- Rooms: name plates and ceiling-light pools -------------------------------------------------

func _rooms() -> void:
	for r in data.get("rooms", []):
		if str(r.get("floor", "")) != floor_id:
			continue
		var d: Array = r.get("door", [])
		if d.size() == 2:
			_plate(str(r.name), builder.center(int(d[0]), int(d[1])))
		var rect: Array = r.get("rect", [])
		if rect.size() == 4 and floor_id != "roof":
			var c0: Vector3 = builder.center(int(rect[0]), int(rect[1]))
			var c1: Vector3 = builder.center(int(rect[2]), int(rect[3]))
			var l := OmniLight3D.new()
			l.light_color = Color(0.96, 0.98, 1.0)  # fluorescent tubes
			l.light_energy = 0.8
			l.omni_range = maxf(8.0, c0.distance_to(c1) * 0.75)
			l.omni_attenuation = 0.7  # broad and even, like a ceiling of tubes - no hot spots on faces
			add_child(l)
			l.global_position = (c0 + c1) * 0.5 + Vector3(0, 4.2, 0)
			_room_lights.append(l)


## A Japanese room plate (shitsumei-fuda) sticking out over the doorway, on a slim bracket.
func _plate(text: String, p: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.06, 2.4, 0.06)
	post.mesh = pm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.25, 0.2, 0.18)
	post.material_override = dark
	post.position = Vector3(-0.9, 1.2, 0.6)
	root.add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.36, 0.06)
	board.mesh = bm
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.95, 0.9)
	board.material_override = white
	board.position = Vector3(-0.2, 2.35, 0.6)
	root.add_child(board)
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 40
	lab.pixel_size = 0.006
	lab.modulate = Color(0.12, 0.12, 0.16)
	lab.outline_size = 0
	lab.position = Vector3(-0.2, 2.35, 0.64)
	root.add_child(lab)


# --- Room features (data/school.json) -----------------------------------------------------------

func _features() -> void:
	for f in data.get("features", []):
		if str(f.get("floor", "")) != floor_id:
			continue
		var t: Array = f.get("tile", [0, 0])
		var it := Interactable.new()
		it.prompt = str(f.get("prompt", "Look"))
		it.radius = 1.6
		add_child(it)
		it.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(0, 0.9, 0.8)
		it.interacted.connect(func(_p): use_feature(f))


## Pick the first variant whose `when` matches (Amane.ok grammar + after/before minutes + chance) and play it.
func feature_scene(f: Dictionary) -> Dictionary:
	if not f.has("variants"):
		return f
	for v in f["variants"]:
		var w: Dictionary = (v.get("when", {}) as Dictionary).duplicate()
		var m := Clock.minute()
		if w.has("after") and m < int(w["after"]):
			continue
		if w.has("before") and m >= int(w["before"]):
			continue
		if w.has("chance") and randf() > float(w["chance"]):
			continue
		for k in ["after", "before", "chance"]:
			w.erase(k)
		if Amane.ok(w):
			return v
	return f["variants"][-1]


func use_feature(f: Dictionary) -> void:
	if hud == null:
		return
	var v := feature_scene(f)
	await Town.scene(str(f.get("name", "")), Amane.fill(str(v.get("open", "..."))), v.get("choices", []), "sc_" + str(f.get("id", "")))


# --- People -----------------------------------------------------------------------------------

func _people() -> void:
	for sp in Town.data.get("spirits", []):
		if str(sp.get("indoor", "")) != floor_id:
			continue
		var n = NPC_SCENE.instantiate()
		n.set_script(load("res://src/actors/spirit_npc.gd"))
		n.set("spirit_id", str(sp.id))
		actors.add_child(n)
		var t: Array = sp.get("itile", [1, 1])
		n.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(0, 0.1, 0)
		n.call("set_home", n.global_position)


## How many students each room wants in a period (classrooms full in lessons, the store and entrance at lunch and in
## the morning, club rooms after school, the roof at lunch; "_corridor" = people between rooms).
func targets(period: String) -> Dictionary:
	var t := {}
	for r in data.get("rooms", []):
		if str(r.get("floor", "")) != floor_id:
			continue
		var name := str(r.get("name", ""))
		var n := 0
		if name.length() == 3 and name[1] == "-":
			n = 9 if period in ["Homeroom", "Class"] else (4 if period == "Lunch" else 2)
		elif name in ["LIBRARY", "ART ROOM", "MUSIC ROOM", "SCIENCE LAB", "NEWSPAPER CLUB"]:
			n = 4 if period in ["Clubs", "Lunch"] else 1
		elif name in ["SCHOOL STORE", "ENTRANCE"]:
			n = 5 if period in ["Lunch", "Morning", "Homeroom", "Evening"] else 1
		elif name == "STAFF ROOM":
			n = 3
		if n > 0:
			t[name] = n
	t["_corridor"] = 6 if period in ["Morning", "Homeroom", "Lunch", "Clubs", "Evening"] else 2
	if floor_id == "roof":
		t = {"_roof": 18 if period == "Lunch" else 3}
	return t


var _room_hint := Vector3.INF  ## disambiguates rooms with the same name (two STAIRS, two WC)


func room(name: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for r in data.get("rooms", []):
		if str(r.get("floor", "")) == floor_id and str(r.get("name", "")) == name:
			if _room_hint == Vector3.INF:
				return r
			var rect: Array = r.get("rect", [0, 0, 0, 0])
			var c: Vector3 = (builder.center(int(rect[0]), int(rect[1])) + builder.center(int(rect[2]), int(rect[3]))) * 0.5
			if c.distance_to(_room_hint) < best_d:
				best = r
				best_d = c.distance_to(_room_hint)
	return best


## Students where a school day puts them. They pick desk / table seats (life spots) inside their room by themselves.
func _crowd() -> void:
	var t := targets(Clock.period())
	# Roof seats fill from where you are outward, so the lunch crowd is around you, not 30 m away.
	var seats := get_tree().get_nodes_in_group("life_spot")
	var here: Vector3 = player.global_position if player else Vector3.ZERO
	seats.sort_custom(func(a, b2): return (a as Node3D).global_position.distance_to(here) > (b2 as Node3D).global_position.distance_to(here))
	for name in t:
		for i in int(t[name]):
			# On the roof people come to sit and eat: start them right by a picnic sheet or a bench.
			if str(name) == "_roof" and not seats.is_empty():
				var seat: Node3D = seats.pop_back()
				var n := _add_student(seat.global_position + Vector3(randf_range(-0.3, 0.3), 0, 0.35), "_roof")
				n.set("_act_check", randf_range(0.2, 1.5))
				continue
			var tile := _room_tile(str(name))
			if tile != Vector2i(-1, -1):
				_add_student(builder.center(tile.x, tile.y), str(name))


func _add_student(at: Vector3, room_name: String) -> NPC:
	var n := spawn_npc("civilian", at, "")
	_set_room(n, room_name)
	_students.append({"npc": n, "room": room_name})
	return n


func _set_room(n: NPC, room_name: String) -> void:
	var rect := _room_rect(room_name)
	if rect.size() == 4:
		var a: Vector3 = builder.center(int(rect[0]), int(rect[1]))
		var c: Vector3 = builder.center(int(rect[2]), int(rect[3]))
		n.set_meta("area", Rect2(Vector2(a.x - 1.0, a.z - 1.0), Vector2(c.x - a.x + 2.0, c.z - a.z + 2.0)))


func _room_rect(room_name: String) -> Array:
	if room_name == "_corridor":
		return [1, 9, builder.width - 2, 10]
	if room_name == "_roof":
		return [5, 5, 34, 15]
	return room(room_name).get("rect", [])


func _room_tile(room_name: String) -> Vector2i:
	var rect := _room_rect(room_name)
	return _free_tile(rect) if rect.size() == 4 else Vector2i(-1, -1)


## Ding-dong: the bell between periods. Surplus students walk out by their door, along the corridor and into a room
## that wants people (or down the stairs and away); rooms still short get students coming up the stairs.
func _bell(period: String) -> void:
	Audio.play_sfx("chime", 0.0, -4.0)
	if hud:
		EventBus.toast.emit("~ ding dong ding dong ~  %s" % period, Color(1.0, 0.95, 0.8))
	_students = _students.filter(func(e): return is_instance_valid(e.npc))
	var want := targets(period)
	var have := {}
	for e in _students:
		have[e.room] = int(have.get(e.room, 0)) + 1
	var movers: Array = []
	for e in _students:
		var r: String = e.room
		if int(have.get(r, 0)) > int(want.get(r, 0)):
			have[r] = int(have[r]) - 1
			movers.append(e)
	var short: Array = []
	for r in want:
		for i in maxi(0, int(want[r]) - int(have.get(r, 0))):
			short.append(r)
	short.shuffle()
	for e in movers:
		if short.is_empty():
			var exit := _exit_point()
			if exit != Vector3.INF:
				_room_hint = exit
				var out_pts: Array[Vector3] = route(e.room, _room_at(exit))
				_room_hint = Vector3.INF
				out_pts.append(exit)
				e.npc.walk_path(out_pts, "free")
			_students.erase(e)
			continue
		var to: String = short.pop_back()
		var target := _room_tile(to)
		if target == Vector2i(-1, -1):
			continue
		var pts: Array[Vector3] = route(e.room, to)
		pts.append(builder.center(target.x, target.y))
		e.npc.walk_path(pts)
		e.room = to
		_set_room(e.npc, to)
	# whoever is still missing arrives by the stairs
	for r in short:
		var start := _exit_point()
		var target := _room_tile(r)
		if start == Vector3.INF or target == Vector2i(-1, -1):
			continue
		var n := _add_student(start, r)
		_room_hint = start
		var pts: Array[Vector3] = route(_room_at(start), r)
		_room_hint = Vector3.INF
		pts.append(builder.center(target.x, target.y))
		n.walk_path(pts)


## Waypoints from one room to another through their doors and the corridor (rooms are walled; NPCs steer straight).
func route(from: String, to: String) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for pair in [[from, true], [to, false]]:
		var r := room(str(pair[0]))
		var d: Array = r.get("door", [])
		if d.size() != 2:
			continue
		var door: Vector3 = builder.center(int(d[0]), int(d[1]))
		var corridor_z := 9 if int(d[1]) <= 8 else 10
		var outside: Vector3 = builder.center(int(d[0]), corridor_z)
		var inside: Vector3 = door + Vector3(0, 0, -LevelBuilder.TILE if int(d[1]) <= 8 else LevelBuilder.TILE)
		if pair[1]:
			pts.append_array([inside, door, outside])
		else:
			pts.append_array([outside, door, inside])
	return pts


## The stairs (or the roof door, or the entrance): where students come from and leave to.
func _exit_point() -> Vector3:
	var ls := _links().filter(func(l): return l.char in ["S", "D", "X", "K"])
	if ls.is_empty():
		return Vector3.INF
	var l = ls[randi() % ls.size()]
	return l.pos + Vector3(0, 0, -LevelBuilder.TILE if l.char == "X" else LevelBuilder.TILE)


## Name of the room whose rect holds a world position ("" = corridor / nowhere).
func _room_at(p: Vector3) -> String:
	var tx := int(p.x / LevelBuilder.TILE)
	var tz := int(p.z / LevelBuilder.TILE)
	for r in data.get("rooms", []):
		var rect: Array = r.get("rect", [])
		if str(r.get("floor", "")) == floor_id and rect.size() == 4 and tx >= int(rect[0]) and tx <= int(rect[2]) and tz >= int(rect[1]) and tz <= int(rect[3]):
			return str(r.name)
	return ""


func _free_tile(rect: Array) -> Vector2i:
	for k in 20:
		var x := rng.randi_range(int(rect[0]), int(rect[2]))
		var z := rng.randi_range(int(rect[1]), int(rect[3]))
		if builder.cell(x, z) in [".", "_", ",", ":", ";", "="]:
			return Vector2i(x, z)
	return Vector2i(-1, -1)


## Dust motes turning in the window light.
func _build_motes() -> void:
	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(builder.width, 1.4, 6.0)
	pm.gravity = Vector3(0, 0.01, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.1
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.05
	motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.94, 0.75)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.6)
	m.emission_energy_multiplier = 2.0
	q.material = m
	motes.draw_pass_1 = q
	motes.amount = maxi(30, int(160 * quality_mult()))
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.visibility_aabb = AABB(Vector3(-builder.width * 2.0, -4, -10), Vector3(builder.width * 4.0, 10, 20))
	add_child(motes)
	motes.global_position = Vector3(builder.width, 1.8, 3.0 * LevelBuilder.TILE)


# --- Light & time -----------------------------------------------------------------------------

func _on_minute(m: int) -> void:
	Audio.play_music(Week.music_now(), 2.5)
	_apply_light()
	if m >= Clock.END_MIN and is_inside_tree():
		end_day()


## Daylight through the windows (a shadow sun behind the north windows + a soft key from the corridor side),
## fluorescent pools in every room; after dark the windows go blue and the room lights carry the scene.
func _apply_light() -> void:
	if not sun or not environment:
		return
	var l := Clock.light()
	var night := clampf((1.05 - float(l.sun_energy)) / 0.7, 0.0, 1.0)
	var roof := floor_id == "roof"
	sun.light_color = l.sun
	sun.light_energy = float(l.sun_energy) * (1.2 if roof else 0.95)
	sun.rotation_degrees = Vector3(-48.0, lerpf(150.0, 210.0, clampf((float(Clock.minute()) - 450.0) / 660.0, 0.0, 1.0)), 0.0)
	sun.shadow_opacity = 1.0
	sun.directional_shadow_max_distance = 40.0
	if _key == null:
		_key = DirectionalLight3D.new()
		_key.shadow_enabled = false
		add_child(_key)
	_key.rotation_degrees = Vector3(-40.0, 20.0, 0.0)
	_key.light_color = (l.sun as Color).lerp(Color.WHITE, 0.4)
	_key.light_energy = float(l.sun_energy) * 0.45
	environment.ambient_light_color = (l.ambient as Color).lerp(Color(0.95, 0.95, 1.0), 0.4)
	environment.ambient_light_energy = float(l.ambient_energy) * (0.75 if roof else 0.85) + 0.2 * night
	environment.background_color = (l.ambient as Color).darkened(0.5) if not roof else (l.ambient as Color).lerp(l.sun, 0.3)
	for r in _room_lights:
		r.light_energy = 0.8 + 0.7 * night
	if camera_rig:
		camera_rig.set_grade((l.ambient as Color).darkened(0.6).lerp(Color(0.12, 0.16, 0.3), 0.4), (l.sun as Color).lightened(0.35), 0.18)
	var jp = build.get("jp")
	if jp:
		jp.set_night(night)
		var golden := clampf(1.0 - absf(float(Clock.minute()) - 1020.0) / 240.0, 0.0, 1.0)  # strongest late afternoon
		jp.set_sun((0.55 + 0.45 * golden) * (1.0 - night) * (1.0 - 0.7 * float(Amane.st()["rain"])), golden)


func nearest_walkable(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		return NavigationServer3D.map_get_closest_point(map, p)
	return p


## Night inside the school: you fall asleep at your desk and wake up at home.
func end_day() -> void:
	if _ending:
		return
	_ending = true
	Clock.running = false
	await Week.before_day_end(hud)
	Clock.next_day()
	Game.location_id = "suzunari"
	Game.save_game()
	Ledger.write()
	Router.goto(Router.SUZUNARI)


func night_watch() -> void:
	if hud:
		await hud.say("", "You can't watch the rooftops from inside the school. Go outside first.")
