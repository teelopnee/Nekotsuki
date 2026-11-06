extends Level
## NEKOTSUKI episode 0 hub: Suzunari - school, shopping street, river, the Asagiri sweet shop.
## Authored map (data/maps/suzunari.txt). Clock drives the light (gold morning -> red Omagatoki ->
## night), Amane's tears drive the rain, and the day ends at night (save + next morning).

const MAP := "res://data/maps/suzunari.txt"
const GATE := Vector2i(21, 14)
const SURNAMES := ["Sato", "Suzuki", "Takahashi", "Tanaka", "Ito", "Watanabe", "Yamamoto", "Nakamura", "Kobayashi",
	"Kato", "Yoshida", "Yamada", "Sasaki", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Mori", "Ikeda"]
const GIVEN := ["Haruto", "Sota", "Yuto", "Ren", "Riku", "Kaito", "Yui", "Hina", "Mei", "Rin", "Sakura", "Aoi",
	"Koharu", "Mio", "Yuna", "Taiga", "Shun", "Nanami", "Akari", "Kenta"]

var amane: AmaneNPC
var overlay: Node
var _rain: Array[CPUParticles3D] = []
var _storm_t := 0.0


func _setup() -> void:
	palette = {
		"theme": "suzunari", "bg": "#8a9cc4", "ground": "#8c8796", "ground_alt": "#9a94a4", "wall": "#e6dccb",
		"fog": "#d8cfe2", "fog_density": 0.004, "sun": "#ffe2b8", "sun_energy": 1.2, "ambient": "#b8c0dc",
		"ambient_energy": 1.3, "neon": ["#ffb35a", "#ff6a7a", "#7ad0ff"], "props": ["crate"], "ground_tex": "concrete",
		"path_tex": "asphalt", "horizon": ["skyline_mountains", "skyline_city", "skyline_mountains"], "foliage": 0.05,
		"foliage_cells": [0, 4], "plant": "#f2a6c2", "plant_glow": 0.0, "puddles": "water", "weather": "",
		"water": "#20304a", "water_glow": "#7ad0ff", "water_glow_strength": 0.08, "water_glow_b": "#ffb35a",
		"water_reflect": 0.5, "building_h": [4.0, 7.0], "exposure": 1.45}
	level_seed = 2026
	camera_pitch = 30.0
	camera_distance = 16.0
	camera_fov = 32.0
	music = "crystal_lull"
	spawn_key = "default"
	CharacterLook.theme = "suzunari"
	Copy.theme = "suzunari"
	DataDB.apply_theme("suzunari")
	Game.location_id = "suzunari"
	Game.location_name = "Suzunari"


func _is_outdoor() -> bool:
	return true


func _get_layout() -> Array:
	var rows: Array = []
	if FileAccess.file_exists(MAP):
		for line in FileAccess.get_file_as_string(MAP).split("\n"):
			if line.strip_edges() != "":
				rows.append(line)
	return rows


## Townsfolk and students instead of the sci-fi crowd.
func spawn_npc(role: String, pos: Vector3, recruit_id: String = "") -> NPC:
	var n: NPC = NPC_SCENE.instantiate()
	n.role = role
	n.recruit_id = recruit_id
	var in_school := pos.z < GATE.y * LevelBuilder.TILE
	n.look = CharacterLook.random_look(rng, "student" if in_school or rng.randf() < 0.4 else "civilian")
	n.npc_name = "%s %s" % [SURNAMES[rng.randi() % SURNAMES.size()], GIVEN[rng.randi() % GIVEN.size()]]
	var pool := ["poor", "worker", "artsy", "rebel", "weird"]
	n.traits.assign([pool[rng.randi() % pool.size()]])
	actors.add_child(n)
	n.global_position = pos + Vector3(0, 0.1, 0)
	return n


func _post_build() -> void:
	Game.set_deferred("air_billing_active", false)
	Clock.running = true
	_build_rain()
	var a = NPC_SCENE.instantiate()
	a.set_script(load("res://src/actors/amane_npc.gd"))
	amane = a
	actors.add_child(amane)
	if Amane.st()["met"]:
		amane.global_position = player.global_position + Vector3(0, 0.1, 4.0)
	else:
		amane.global_position = builder.center(GATE.x, GATE.y) + Vector3(0, 0.1, -1.0)
	overlay = load("res://src/ui/neko_overlay.gd").new()
	overlay.level = self
	add_child(overlay)
	Clock.minute_passed.connect(_on_minute)
	_apply_light()
	Cats.spawn_in(self, 8)
	if not Amane.fate(Amane.FRIEND) in ["injured", "hidden"]:
		var h = NPC_SCENE.instantiate()
		h.set_script(load("res://src/actors/hayate_npc.gd"))
		actors.add_child(h)
		h.global_position = builder.center(17, 11) + Vector3(0, 0.1, 0)
		h.spot = h.global_position
	_morning.call_deferred()


func _exit_tree() -> void:
	super._exit_tree()
	Clock.running = false


func _morning() -> void:
	var note := Amane.morning_event()
	if note != "" and hud:
		amane.global_position = player.global_position + Vector3(0.6, 0.1, -1.6)
		await hud.say("", note)
		Emotion.express(amane, "cry", 3.0)
	elif Clock.day() == 1 and Clock.minute() <= Clock.START_MIN + 1 and hud:
		await hud.say("", "Suzunari. Day one of the spring term. It has rained every single day since you arrived.\nThe school is up the hill, across the river and through the shopping street.")


## Rain the town's mood: two particle systems from Level's weather builder, scaled by Amane's tears.
func _build_rain() -> void:
	var before := camera_rig.get_children()
	var timers_before := get_children()
	_build_weather("rain")
	for c in camera_rig.get_children():
		if c is CPUParticles3D and not before.has(c):
			_rain.append(c)
	for c in get_children():
		if c is Timer and not timers_before.has(c):
			c.queue_free()  # lightning only during a storm (see _process)
	_set_rain(float(Amane.st()["rain"]))


func _set_rain(r: float) -> void:
	for p in _rain:
		if not is_instance_valid(p):
			continue
		p.emitting = r > 0.03
		if "amount_ratio" in p:
			p.amount_ratio = clampf(r, 0.05, 1.0)


func _process(delta: float) -> void:
	var r := float(Amane.st()["rain"])
	_set_rain(r)
	if Amane.tears_level() >= 5 and sun:
		_storm_t -= delta
		if _storm_t <= 0.0:
			_storm_t = randf_range(5.0, 11.0)
			var e := sun.light_energy
			sun.light_energy = e * 4.0
			get_tree().create_timer(0.08).timeout.connect(func(): if is_instance_valid(sun): sun.light_energy = e)
			Audio.play_sfx("thunder", 0.0, -6.0)


func _on_minute(m: int) -> void:
	_apply_light()
	if m >= Clock.END_MIN and is_inside_tree():
		end_day()


func _apply_light() -> void:
	if not sun or not environment:
		return
	var l := Clock.light()
	var gloom := 1.0 - 0.45 * float(Amane.st()["rain"])
	sun.light_color = l.sun
	sun.light_energy = float(l.sun_energy) * gloom
	environment.ambient_light_color = l.ambient
	environment.ambient_light_energy = float(l.ambient_energy) * (0.75 + 0.25 * gloom)


func nearest_walkable(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		return NavigationServer3D.map_get_closest_point(map, p)
	return p


## Night: save, wake up at home the next morning.
func end_day() -> void:
	Clock.running = false
	Clock.next_day()
	Game.save_game()
	Ledger.write()
	Router.goto(Router.SUZUNARI)


## Phone "watch the rooftops" (after 21:00 while Amane has a rival): meet his living spirit on the roofs.
func night_watch() -> void:
	if hud == null or Amane.rival() == "":
		return
	var w: Dictionary = Amane.data.get("night_watch", {})
	var c: Dictionary = w.get("choices", {})
	var picked: String = await hud.say("", Amane.fill(str(w.get("intro", ""))).replace("{rival}", Amane.rival()),
		[{"id": "chase", "text": str(c.get("chase", "Chase it."))}, {"id": "name", "text": str(c.get("name", "Name it."))},
		{"id": "let_go", "text": str(c.get("let_go", "Let it go."))}])
	await hud.say("", Amane.night_choice(picked))
