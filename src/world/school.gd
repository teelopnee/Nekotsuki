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
	camera_pitch = 34.0
	camera_distance = 15.0
	camera_fov = 32.0
	music = "crystal_lull"
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
	_place_player()
	_wire_links()
	_rooms()
	_features()
	_people()
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
			l.light_energy = 1.1
			l.omni_range = maxf(6.0, c0.distance_to(c1) * 0.6)
			l.omni_attenuation = 1.4
			add_child(l)
			l.global_position = (c0 + c1) * 0.5 + Vector3(0, 3.0, 0)
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


# --- Light & time -----------------------------------------------------------------------------

func _on_minute(m: int) -> void:
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
		r.light_energy = 1.1 + 0.9 * night
	if camera_rig:
		camera_rig.set_grade((l.ambient as Color).darkened(0.6).lerp(Color(0.12, 0.16, 0.3), 0.4), (l.sun as Color).lightened(0.35), 0.18)
	var jp = build.get("jp")
	if jp:
		jp.set_night(night)


func nearest_walkable(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		return NavigationServer3D.map_get_closest_point(map, p)
	return p


## Night inside the school: you fall asleep at your desk and wake up at home.
func end_day() -> void:
	Clock.running = false
	Clock.next_day()
	Game.location_id = "suzunari"
	Game.save_game()
	Ledger.write()
	Router.goto(Router.SUZUNARI)


func night_watch() -> void:
	if hud:
		await hud.say("", "You can't watch the rooftops from inside the school. Go outside first.")
