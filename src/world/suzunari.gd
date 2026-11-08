extends Level
## NEKOTSUKI episode 0 hub: Suzunari - school, shopping street, river, the Asagiri sweet shop.
## Authored map (data/maps/suzunari.txt). Clock drives the light (gold morning -> red Omagatoki ->
## night), Amane's tears drive the rain, and the day ends at night (save + next morning).

const MAP := "res://data/maps/suzunari.txt"
const GATE := Vector2i(22, 31)  ## school gate (the wall at z = 31)
const SURNAMES := ["Sato", "Suzuki", "Takahashi", "Tanaka", "Ito", "Watanabe", "Yamamoto", "Nakamura", "Kobayashi",
	"Kato", "Yoshida", "Yamada", "Sasaki", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Mori", "Ikeda"]
const GIVEN := ["Haruto", "Sota", "Yuto", "Ren", "Riku", "Kaito", "Yui", "Hina", "Mei", "Rin", "Sakura", "Aoi",
	"Koharu", "Mio", "Yuna", "Taiga", "Shun", "Nanami", "Akari", "Kenta"]

var amane: AmaneNPC
var _ending := false
## Ura-Suzunari (data/ura.json, Week.enter_ura): the same map at an endless red dusk.
var ura := false
var ura_goal := ""
var cat_night := false  ## playing Amane's two-tailed cat tonight (data/cat_night.json)
var cat := {}
var _cat_t := 0.0
var _cat_done := false
var _cat_warned := false
var _cat_rival_pos := Vector3.ZERO
var _ura_t := 0.0
var _ura_bells := 0
var _marker: Node3D
var _marker_t := 0.0
var home: HomeVisits  ## the five houses: doors, morning pick-ups, walking people home
var overlay: Node
var _rain: Array[CPUParticles3D] = []
var _storm_t := 0.0
var _petals: GPUParticles3D
var _motes: GPUParticles3D
var _key: DirectionalLight3D  ## shadowless front key light (see _apply_light)
var _clouds: MeshInstance3D  ## invisible cloud layer: only its shadows drift over the town


func _setup() -> void:
	palette = {
		"theme": "suzunari", "bg": "#8a9cc4", "ground": "#8c8796", "ground_alt": "#9a94a4", "wall": "#e6dccb",
		"fog": "#d8cfe2", "fog_density": 0.004, "sun": "#ffe2b8", "sun_energy": 1.2, "ambient": "#b8c0dc",
		"ambient_energy": 1.3, "neon": ["#ffb35a", "#ff6a7a", "#7ad0ff"], "props": ["crate"], "ground_tex": "concrete",
		"path_tex": "asphalt", "horizon": ["skyline_mountains", "skyline_city", "skyline_mountains"], "foliage": 0.0,
		"foliage_cells": [0, 4], "plant": "#6aa84f", "plant_glow": 0.0, "puddles": "water", "weather": "",
		"water": "#1d4c5e", "water_glow": "#a8e6ee", "water_glow_strength": 0.05, "water_glow_b": "#ffb35a",
		"water_reflect": 0.0, "building_h": [4.0, 7.0], "exposure": 0.98}
	level_seed = 2026
	camera_pitch = 30.0
	camera_distance = 16.0
	camera_fov = 32.0
	music = Week.music_now()
	spawn_key = "default"
	CharacterLook.theme = "suzunari"
	Copy.theme = "suzunari"
	DataDB.apply_theme("suzunari")
	Game.location_id = "suzunari"
	Game.location_name = "Suzunari"
	ura = bool(Router.params.get("ura", false)) and bool(Game.flags.get("in_ura", false))
	cat_night = not ura and Game.flags.has("cat_night")
	if cat_night:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/cat_night.json"))
		cat = parsed if parsed is Dictionary else {}
		Game.location_name = "Suzunari, 23:40"
		music = "suzunari_rain_night"
		palette["bg"] = "#070a18"
		palette["fog"] = "#151b36"
		palette["fog_density"] = 0.007
		palette["sun"] = "#8ea6ff"
		palette["ambient"] = "#3a4678"
	if not ura:
		Game.flags.erase("in_ura")
	else:
		ura_goal = str(Router.params.get("goal", "free"))
		Game.location_name = "Ura-Suzunari"
		music = "ura_festival"
		palette["bg"] = "#4a0e1c"
		palette["fog"] = "#8a2236"
		palette["fog_density"] = 0.011
		palette["sun"] = "#ff5a3a"
		palette["ambient"] = "#b0405a"


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
	Clock.running = not cat_night
	if cat_night:
		Clock.st()["minute"] = Clock.END_MIN - 2  # 23:40 in the story; the clock stands still all night
	_build_rain()
	_build_petals()
	_build_motes()
	_build_clouds()
	var jp = build.get("jp")
	if jp and not ura and not cat_night:
		var life := TownLife.new()
		life.name = "TownLife"
		add_child(life)
		life.setup(jp.ground_spots(), jp.flower_spots())
	# Kei cars and vans on the roads (left-hand traffic: eastbound on the north lane).
	var w := builder.width
	var lanes := [[builder.center(-3, 32), builder.center(w + 2, 32)], [builder.center(w + 2, 33), builder.center(-3, 33)],
		[builder.center(-3, 43), builder.center(w + 2, 43)], [builder.center(w + 2, 43), builder.center(-3, 43)]]
	for i in (0 if ura or cat_night else 6):
		var car := Critter.new()
		car.kind = "streetcar"
		car.style = "kei"
		var lane: Array = lanes[i % lanes.size()]
		car.lane_from = lane[0]
		car.lane_to = lane[1]
		car.seed_value = 7700 + i
		actors.add_child(car)
	environment.adjustment_saturation = 1.16
	environment.adjustment_contrast = 1.14
	environment.fog_density = 0.0025
	var a = NPC_SCENE.instantiate()
	a.set_script(load("res://src/actors/amane_npc.gd"))
	amane = a
	actors.add_child(amane)
	var back = Router.params.get("spawn_tile")  # coming out of a building: stand at its door
	if back is Array and back.size() == 2:
		player.global_position = builder.center(int(back[0]), int(back[1])) + Vector3(1.0, 0.1, 0.9)
	if Amane.st()["met"]:
		amane.global_position = player.global_position + Vector3(0, 0.1, 4.0)
	else:
		amane.global_position = builder.center(GATE.x, GATE.y) + Vector3(0, 0.1, -1.0)
	overlay = load("res://src/ui/neko_overlay.gd").new()
	overlay.level = self
	add_child(overlay)
	Clock.minute_passed.connect(_on_minute)
	_apply_light()
	update_ambience.call_deferred()
	if not ura:
		Cats.spawn_in(self, 8)
	if not ura and not cat_night and not Amane.fate(Amane.FRIEND) in ["injured", "hidden"]:
		var h = NPC_SCENE.instantiate()
		h.set_script(load("res://src/actors/hayate_npc.gd"))
		actors.add_child(h)
		h.global_position = builder.center(16, 29) + Vector3(0, 0.1, 0)
		h.spot = h.global_position
	if ura:
		_build_ura.call_deferred()
		_morning.call_deferred()
		return
	if cat_night:
		_build_cat_night.call_deferred()
		return
	Town.spawn_in(self)
	_school_doors()
	_thousandth_step()
	_work_spots()
	if str(Amane.st()["pending"]) == "doorstep":
		People.today("amane")["out"] = true  # he's on Senpai's doorstep, not at home
	home = HomeVisits.new()
	home.name = "HomeVisits"
	add_child(home)
	home.setup(self)
	Party.spawn_in.call_deferred(self)  # friends hanging out with you
	_morning.call_deferred()


## The two entrances of Suzunari Gakuen (data/school.json `doors`, one interactable per pair of tiles).
func _school_doors() -> void:
	var sd := {}
	if FileAccess.file_exists("res://data/school.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/school.json"))
		if parsed is Dictionary:
			sd = parsed
	var doors: Array = sd.get("doors", [])
	for i in range(0, doors.size(), 2):
		var t: Array = doors[i]
		var it := Interactable.new()
		it.prompt = "Enter Suzunari Gakuen"
		it.radius = 1.8
		add_child(it)
		it.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(LevelBuilder.TILE * 0.5, 0.9, -0.4)
		it.interacted.connect(func(_p): enter_school(t))


## Club places and part-time jobs out in town (data/clubs.json `where.level` = suzunari, Toru autoload),
## and your desk at home (cram for exams).
func _work_spots() -> void:
	var desk := Interactable.new()
	desk.name = "HomeDesk"
	desk.prompt = "Your desk at home: study"
	desk.radius = 1.5
	add_child(desk)
	desk.global_position = builder.center(24, 47) + Vector3(0, 0.9, 0)
	desk.interacted.connect(func(_p): Week.cram(hud, "home"))
	for kind in ["clubs", "jobs"]:
		var all: Dictionary = Toru.clubs.get(kind, {})
		for id in all:
			var w: Dictionary = all[id].get("where", {})
			if str(w.get("level", "")) != "suzunari":
				continue
			var t: Array = w.get("tile", [0, 0])
			var it := Interactable.new()
			it.name = "Work_" + str(id)
			it.prompt = str(all[id].get("prompt", all[id].get("name", id)))
			it.radius = 1.7
			add_child(it)
			it.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(0, 0.9, 0)
			var tag := Label3D.new()
			tag.text = str(all[id].get("name", id)) + ("\n(part-time)" if kind == "jobs" else "")
			tag.font_size = 30
			tag.pixel_size = 0.006
			tag.outline_size = 8
			tag.modulate = Color(1.0, 0.88, 0.7)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.visibility_range_end = 13.0
			tag.position = Vector3(0, 1.5, 0)
			it.add_child(tag)
			if kind == "clubs":
				it.interacted.connect(func(_p): Toru.use_club(id, hud))
			else:
				it.interacted.connect(func(_p): Toru.use_job(id, hud))


func enter_school(door: Array) -> void:
	if home and People.escorting() and str(People.escort().get("mode", "")) == "school":
		await home.finish()  # walked someone to school: they say goodbye at the door
	Game.flags["school_door"] = door
	Game.flags["school_floor"] = "1f"
	Game.location_id = "school"
	Router.goto(Router.SCHOOL, {"floor": "1f"})


func _exit_tree() -> void:
	super._exit_tree()
	Clock.running = false


func _morning() -> void:
	if ura:
		if hud:
			await hud.say("", str(Week.ura.get("enter_text", "")))
		return
	var note := Amane.morning_event()
	if note != "" and hud:
		amane.global_position = player.global_position + Vector3(0.6, 0.1, -1.6)
		await hud.say("", note)
		Emotion.express(amane, "cry", 3.0)
	elif Clock.day() == 1 and Clock.minute() <= Clock.START_MIN + 1 and hud:
		await hud.say("", "Suzunari. Day one of the spring term. It has rained every single day since you arrived.\nThe school is up the hill, across the river and through the shopping street.")
	var wn := Week.morning_note()
	if wn != "" and hud:
		await hud.say("", wn)
	var tn := Toru.morning_note()  # a captain's complaint, a line from Toru's past
	if tn != "" and hud:
		await hud.say("", tn)
	if home:
		await home.resume()
	Week.level_ready()


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
	if ura:
		_ura_process(delta)
	elif cat_night:
		_cat_process(delta)
	else:
		_marker_process(delta)
	var r := float(Amane.st()["rain"]) if not ura else 0.8
	_set_rain(r)
	if _petals and player:
		_petals.global_position = player.global_position + Vector3(0, 6.0, -5.0)
		if _motes:
			_motes.global_position = player.global_position + Vector3(0, 1.6, -3.0)
	if _clouds:
		_clouds.position.x = fmod(_clouds.position.x + delta * 0.9, 160.0 / 3.0) if r < 0.5 else _clouds.position.x
		_clouds.visible = r < 0.5  # under rain the whole sky is one cloud
		_petals.amount_ratio = clampf(1.0 - r * 0.8, 0.15, 1.0)
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
	if not ura:
		Audio.play_music(Week.music_now(), 2.5)
	update_ambience()
	if m >= Clock.END_MIN and is_inside_tree():
		end_day()


## The town's sound bed (tools/gen_ambience_suzunari.py): sparrows by day, crows and frogs at Omagatoki, frogs and
## bell crickets at night, the rain when Amane cries. Ura-Suzunari has none: only its festival music.
func update_ambience() -> void:
	if ura:
		Audio.play_ambience("")
		return
	var m := Clock.minute()
	var amb := "amb_suzunari_day"
	if float(Amane.st()["rain"]) > 0.45:
		amb = "amb_rain"
	elif cat_night or m >= Clock.NIGHT:
		amb = "amb_suzunari_night"
	elif m >= Clock.DUSK - 30:
		amb = "amb_suzunari_dusk"
	Audio.play_ambience(amb, -10.0 if amb != "amb_rain" else -8.0)


func _apply_light() -> void:
	if not sun or not environment:
		return
	var l := Clock.light()
	var gloom := 1.0 - 0.45 * float(Amane.st()["rain"])
	# HD-2D contrast: a strong key light with real shadows, a low cool fill (flat ambient killed the depth).
	sun.light_color = l.sun
	sun.light_energy = float(l.sun_energy) * gloom * 1.35
	environment.ambient_light_color = l.ambient
	environment.ambient_light_energy = float(l.ambient_energy) * (0.75 + 0.25 * gloom) * 0.55
	# The sun crosses the sky behind the camera: low and golden from the south-east in the morning,
	# high at noon, long red shadows from the south-west at Omagatoki.
	var t := clampf((float(Clock.minute()) - 450.0) / (Clock.NIGHT - 450.0), 0.0, 1.0)
	# Two suns, the HD-2D trick: the shadow sun swings round BEHIND the town (east -> north -> west), so every
	# shadow stretches toward the camera where you can see it (the sprites' shadow cards turn to face it); a
	# shadowless key light from the camera side keeps facades and faces lit.
	var elev := lerpf(24.0, 52.0, sin(t * PI)) if t < 0.92 else lerpf(18.0, 10.0, (t - 0.92) / 0.08)
	sun.rotation_degrees = Vector3(-elev, lerpf(115.0, 245.0, t), 0.0)
	sun.shadow_opacity = 1.0
	sun.shadow_blur = 0.9
	sun.directional_shadow_max_distance = 40.0
	if _key == null:
		_key = DirectionalLight3D.new()
		_key.name = "KeyLight"
		_key.shadow_enabled = false
		add_child(_key)
	_key.rotation_degrees = Vector3(-38.0, lerpf(45.0, -45.0, t), 0.0)
	_key.light_color = (l.sun as Color).lerp(Color.WHITE, 0.25)
	_key.light_energy = sun.light_energy * 0.5
	sun.light_energy *= 0.85
	var haze: Color = (l.ambient as Color).lerp(l.sun, 0.35)
	environment.fog_light_color = haze.lerp(Color(0.55, 0.58, 0.66), 0.5 * float(Amane.st()["rain"]))
	environment.background_color = environment.fog_light_color
	var night := clampf((1.05 - float(l.sun_energy)) / 0.7, 0.0, 1.0)
	# Colour grade follows the sky: cool blue shadows, highlights the colour of the sun.
	if camera_rig:
		camera_rig.set_grade((l.ambient as Color).darkened(0.6).lerp(Color(0.12, 0.16, 0.3), 0.4), (l.sun as Color).lightened(0.35), 0.2)
		if camera_rig.post_mat:
			camera_rig.post_mat.set_shader_parameter("aberration", 0.5)
			camera_rig.post_mat.set_shader_parameter("grain", 0.02)
			camera_rig.post_mat.set_shader_parameter("vignette", 0.42)
	var jp = build.get("jp")
	var rain := float(Amane.st()["rain"])
	var m := float(Clock.minute())
	var morning := clampf(1.0 - (m - 470.0) / 160.0, 0.0, 1.0)
	var dusk := clampf((m - 990.0) / 90.0, 0.0, 1.0) * clampf((1125.0 - m) / 30.0, 0.0, 1.0)
	var sun_rays := maxf(morning, dusk) * (1.0 - rain)
	if jp:
		jp.set_night(maxf(night, 0.35 * rain))
		jp.set_sun(maxf(sun_rays, 0.18 * (1.0 - night) * (1.0 - rain)), dusk)
	if _motes:
		_motes.amount_ratio = clampf(sun_rays, 0.05, 1.0)
		_motes.visible = night < 0.6 and rain < 0.5
	# Morning mist hugging the ground, a thin haze by day, none in the dark.
	environment.fog_height = 0.8
	environment.fog_height_density = 0.05 * morning


## The thousandth step, at the top of the 999: after you've met Rin, at Omagatoki, you can go over on your own.
	if ura:
		_ura_light()


func _thousandth_step() -> void:
	var it := Interactable.new()
	it.name = "ThousandthStep"
	it.prompt = "Count the steps... and take one more (Ura-Suzunari)"
	it.radius = 2.0
	add_child(it)
	it.global_position = builder.center(4, 10) + Vector3(0, 0.9, 0)
	it.interacted.connect(func(_p):
		if Clock.is_dusk() and bool(Game.flags.get("met_rin", false)) and not People.escorting():
			Week.enter_ura("free")
		elif hud:
			hud.say("", "Nine hundred and ninety-nine. You count them twice. There is no thousandth step - not now. (Omagatoki, 18:00-18:30, once you've met the bell.)"))


func nearest_walkable(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var r := NavigationServer3D.map_get_closest_point(map, p)
		if r.y > 1.5 and p.y < 1.5:
			# The baked navmesh also covers flat house tops: a street query must never land on a roof.
			for dist in [2.0, 3.5, 5.0, 7.0]:
				for k in 8:
					var q: Vector3 = p + Vector3.FORWARD.rotated(Vector3.UP, k * PI / 4.0) * float(dist)
					var r2 := NavigationServer3D.map_get_closest_point(map, Vector3(q.x, 0.0, q.z))
					if r2.y < 1.0:
						return r2
		return r
	return p


## Night: save, wake up at home the next morning.
func end_day() -> void:
	if _ending:
		return
	_ending = true
	Clock.running = false
	await Week.before_day_end(hud)  # Haruka hears about lates/absences; day 7 closes week 1
	if not Game.flags.has("ending") and Amane.cat_night_due():
		Game.flags["cat_night"] = {"day": Clock.day(), "rival": Amane.rival()}
		Game.save_game()
		Router.goto(Router.SUZUNARI)  # tonight you are the cat (cat mode)
		return
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


## Cherry petals drifting through the frame all spring (fewer in heavy rain).
func _build_petals() -> void:
	_petals = GPUParticles3D.new()
	_petals.name = "Petals"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18.0, 2.0, 14.0)
	pm.direction = Vector3(1.0, -0.4, 0.5)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, -0.5, 0)
	pm.angular_velocity_min = -220.0
	pm.angular_velocity_max = 220.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 5.0
	pm.turbulence_influence_min = 0.04
	pm.turbulence_influence_max = 0.14
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(0.98, 0.66, 0.78))
	grad.set_color(1, Color(0.93, 0.5, 0.66))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	_petals.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.065)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.72)
	m.emission_energy_multiplier = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_petals.draw_pass_1 = q
	_petals.amount = maxi(40, int(200 * quality_mult()))
	_petals.lifetime = 10.0
	_petals.preprocess = 10.0
	_petals.local_coords = false
	_petals.visibility_aabb = AABB(Vector3(-26, -12, -22), Vector3(52, 24, 44))
	add_child(_petals)


## Dust and pollen motes glittering in the sunbeams (morning and Omagatoki), like an HD-2D diorama.
func _build_motes() -> void:
	_motes = GPUParticles3D.new()
	_motes.name = "Motes"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12.0, 1.6, 9.0)
	pm.direction = Vector3(0.3, 1.0, 0.0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3(0, 0.01, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(0.7, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = fade
	pm.scale_curve = ct
	_motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.92, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.55)
	m.emission_energy_multiplier = 2.5
	q.material = m
	_motes.draw_pass_1 = q
	_motes.amount = maxi(20, int(120 * quality_mult()))
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.local_coords = false
	_motes.visibility_aabb = AABB(Vector3(-16, -4, -12), Vector3(32, 10, 24))
	add_child(_motes)


## Cloud shadows: a high quad that casts shadows only (never drawn), drifting with the wind.
func _build_clouds() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(160.0, 160.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/jp_f_clouds.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(3, 3, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_clouds = MeshInstance3D.new()
	_clouds.name = "CloudShadows"
	_clouds.mesh = q
	_clouds.material_override = m
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_clouds.rotation.x = -PI * 0.5
	_clouds.position = Vector3(0.0, 24.0, builder.height * LevelBuilder.TILE * 0.5)
	_clouds.extra_cull_margin = 200.0
	add_child(_clouds)
	_clouds.position.x = builder.width * LevelBuilder.TILE * 0.5


# --- Ura-Suzunari ------------------------------------------------------------------------------------------

func _build_ura() -> void:
	var u: Dictionary = Week.ura
	Clock.running = false
	if hud and hud.has_method("set_ticker_shown"):
		hud.set_ticker_shown(false)  # no school notices or radio on the other side
	if bool(Game.flags.get("kasa_friend", false)) and hud and hud.has_method("toast"):
		hud.toast(str(u.get("kasa_text", "")), Color(0.8, 0.85, 1.0))
	var arrive: Array = u.get("arrive", [4, 20])
	player.global_position = builder.center(int(arrive[0]), int(arrive[1])) + Vector3(0, 0.1, 0)
	if amane and Amane.st()["met"]:
		amane.global_position = player.global_position + Vector3(1.2, 0.1, 1.4)
	# Everyone who lives here now is a shadow of someone who didn't want to leave.
	for n in get_tree().get_nodes_in_group("npc"):
		if n == amane or n.is_in_group("echo"):
			continue
		var spr = n.get("sprite")
		if spr:
			spr.modulate = Color(0.16, 0.05, 0.1, 0.7)
		var lbl = n.get("name_label")
		if lbl is Label3D:
			lbl.text = "a shadow"
		var t = n.get("talk")
		if t:
			t.enabled = false
	for e in u.get("echoes", []):
		_spawn_echo(e, false)
	_spawn_hidden(u)
	var goal: Dictionary = u.get("goals", {}).get(ura_goal, {})
	if goal.has("tile"):
		if ura_goal == "rin":
			_spawn_rin(goal)
		else:
			var g := goal.duplicate()
			g["id"] = "goal_" + ura_goal
			_spawn_echo(g, true)
	# Wild kasha hunt the living - away from where you arrive.
	var k: Dictionary = u.get("kasha", {})
	var spots: Array = []
	for z in range(1, builder.height - 1):
		for x in range(1, builder.width - 1):
			if builder.cell(x, z) in [".", ",", "_"] and builder.center(x, z).distance_to(player.global_position) > 26.0:
				spots.append(Vector2i(x, z))
	spots.shuffle()
	for i in mini(int(k.get("count", 6)), spots.size()):
		spawn_enemy("kasha", builder.center(spots[i].x, spots[i].y), {"look": k.get("look", {}), "name": "Wild Kasha", "hostile": true})
	if bool(goal.get("elite", false)) and goal.has("tile"):
		var gt: Array = goal["tile"]
		spawn_enemy("kasha", builder.center(int(gt[0]) + 3, int(gt[1]) - 1), {"look": k.get("look", {}), "name": "Kasha Matriarch",
			"hostile": true, "elite": true})
	if Arsenal.owned("melee").is_empty():
		Game.flags["weapons"] = {"melee": ["pipe"], "ranged": ["sidearm"]}
	_ura_dressing()
	# The way out: back down the thousandth step.
	var ex: Array = u.get("exit", [4, 19])
	var it := Interactable.new()
	it.prompt = "Walk back down the thousandth step"
	it.radius = 2.2
	add_child(it)
	it.global_position = builder.center(int(ex[0]), int(ex[1])) + Vector3(0, 0.9, 0)
	it.interacted.connect(func(_p): Week.leave_ura(false))
	# Upward rain.
	for p in _rain:
		if is_instance_valid(p):
			p.gravity = Vector3(0, absf(p.gravity.y) * 0.5 + 2.0, 0)
			p.position.y -= 10.0
	_apply_light()
	if hud and hud.has_method("toast"):
		hud.toast("Ura-Suzunari. Wild kasha hunt here: MELEE / FIRE to fight, ROLL to dodge.", Color(1.0, 0.6, 0.6))


## What makes the other side look like the other side (LORE 1.6, 7.4): the river runs dry and children's stone
## towers stand on its bed, festival stalls line the shopping street, red lanterns hang in the air over the roads,
## torii stand where there were none, and the station's sign says Kisaragi.
func _ura_dressing() -> void:
	var jp = build.get("jp")
	var root := Node3D.new()
	root.name = "UraDressing"
	add_child(root)
	var T := LevelBuilder.TILE
	var stone: Material = jp.prop_mat("stone", Color(0.46, 0.43, 0.42)) if jp else StandardMaterial3D.new()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1868
	var bed_cells: Array[Vector2i] = []
	for z in range(builder.height):
		if z >= 50:
			break  # the sea stays the sea
		var x0 := -1
		for x in range(builder.width + 1):
			var water: bool = x < builder.width and builder.cell(x, z) == "~"
			if water:
				bed_cells.append(Vector2i(x, z))
				if x0 < 0:
					x0 = x
			elif x0 >= 0:
				var length := (x - x0) * T
				builder.add_mesh(root, builder.box(Vector3(length, 0.24, T)), stone, Vector3(x0 * T + length * 0.5, 0.12, z * T + T * 0.5), 0.0, false)
				x0 = -1
	# Children's stone towers on the dry bed (sai no kawara).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = builder.box(Vector3(0.34, 0.16, 0.28))
	var xforms: Array[Transform3D] = []
	for i in mini(150, bed_cells.size() * 3):
		var c: Vector2i = bed_cells[rng2.randi() % bed_cells.size()]
		var base := builder.center(c.x, c.y) + Vector3(rng2.randf_range(-0.8, 0.8), 0.32, rng2.randf_range(-0.8, 0.8))
		var h := rng2.randi_range(2, 5)
		for k in h:
			var sc := 1.0 - 0.14 * k
			xforms.append(Transform3D(Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3(sc, 1.0, sc)), base + Vector3(0, 0.15 * k, 0)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var towers := MultiMeshInstance3D.new()
	towers.multimesh = mm
	towers.material_override = stone
	root.add_child(towers)
	# Festival stalls along the shopping street, lanterns in the air over the roads.
	var wood: Material = jp.prop_mat("wood", Color(0.55, 0.36, 0.24)) if jp else StandardMaterial3D.new()
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.85, 0.18, 0.2)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.55, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.2)
	glow.emission_energy_multiplier = 2.4
	for x in [4, 9, 17, 27, 33]:
		var p := builder.center(x, 38) + Vector3(0, 0, -0.9)
		builder.add_mesh(root, builder.box(Vector3(1.8, 0.9, 0.8)), wood, p + Vector3(0, 0.45, 0))
		var roof := builder.add_mesh(root, builder.box(Vector3(2.1, 0.06, 1.3)), cloth, p + Vector3(0, 2.0, 0.2))
		roof.rotation.x = 0.3
		for sx in [-0.9, 0.9]:
			builder.add_mesh(root, builder.box(Vector3(0.08, 2.0, 0.08)), wood, p + Vector3(sx, 1.0, 0.55), 0.0, false)
			builder.add_mesh(root, builder.cylinder(0.16, 0.3, 8), glow, p + Vector3(sx * 0.7, 1.6, 0.75), 0.0, false)
		if x == int(Week.ura.get("food", {}).get("stall_x", 17)):
			_ura_food_stall(p)
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	lm.mesh = builder.cylinder(0.2, 0.36, 8)
	var lx: Array[Transform3D] = []
	for z in [32, 33, 43]:
		var x := 0
		while x < builder.width:
			if builder.cell(x, z) == ",":
				lx.append(Transform3D(Basis(), builder.center(x, z) + Vector3(0, 3.2 + 0.25 * sin(x), 0)))
			x += 2
	lm.instance_count = lx.size()
	for i in lx.size():
		lm.set_instance_transform(i, lx[i])
	var lanterns := MultiMeshInstance3D.new()
	lanterns.multimesh = lm
	lanterns.material_override = glow
	lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lanterns)
	# Torii across the road where the real town has none.
	var red: Material = jp.prop_mat("vermilion", Color(0.85, 0.24, 0.15)) if jp else StandardMaterial3D.new()
	for x in [8, 26, 46]:
		var p := builder.center(x, 32) + Vector3(0, 0, T * 0.5)
		for sz in [-1.9, 1.9]:
			builder.add_mesh(root, builder.cylinder(0.15, 3.6, 8), red, p + Vector3(0, 1.8, sz))
		var top := builder.add_mesh(root, builder.box(Vector3(0.42, 0.24, 4.6)), red, p + Vector3(0, 3.62, 0))
		top.position.y = 3.62
		builder.add_mesh(root, builder.box(Vector3(0.3, 0.18, 4.0)), red, p + Vector3(0, 3.0, 0), 0.0, false)
	# The station that isn't there (Kisaragi, LORE 1.6).
	for l in find_children("*", "Label3D", true, false):
		if str(l.text).contains("SUZUNARI  STATION"):
			l.text = "KISARAGI  STATION"


func _spawn_echo(e: Dictionary, solid: bool) -> void:
	var n = NPC_SCENE.instantiate()
	n.set_script(load("res://src/actors/echo_npc.gd"))
	n.echo = e
	n.solid = solid
	actors.add_child(n)
	var t: Array = e.get("tile", [4, 20])
	n.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(0, 0.1, 0)


## Everyone the cat spirited away waits here (data/ura.json `hidden`): take their hand, walk them down the steps.
func _spawn_hidden(u: Dictionary) -> void:
	var spots: Array = u.get("hidden", {}).get("spots", [[20, 8]])
	var i := 0
	for who in Amane.st()["fates"]:
		if Amane.fate(str(who)) != "hidden":
			continue
		var n = NPC_SCENE.instantiate()
		n.set_script(load("res://src/actors/lost_npc.gd"))
		n.who = str(who)
		actors.add_child(n)
		var t: Array = spots[i % spots.size()]
		n.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(0, 0.1, 0)
		i += 1


## Rin: a gold bell hanging in the air by itself.
func _spawn_rin(goal: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Rin"
	add_child(root)
	var t: Array = goal.get("tile", [6, 21])
	root.global_position = builder.center(int(t[0]), int(t[1])) + Vector3(0, 1.6, 0)
	var bell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.36
	bell.mesh = sm
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.3)
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.25)
	gold.emission_energy_multiplier = 0.8
	bell.material_override = gold
	root.add_child(bell)
	var cord := MeshInstance3D.new()
	cord.mesh = builder.cylinder(0.02, 0.6, 5)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.1, 0.15)
	cord.material_override = red
	cord.position.y = 0.42
	root.add_child(cord)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.omni_range = 4.0
	light.light_energy = 1.4
	root.add_child(light)
	var it := Interactable.new()
	it.prompt = "Talk to the bell"
	it.radius = 2.0
	root.add_child(it)
	it.position.y = -0.8
	it.interacted.connect(func(_p): _rin_talk(goal))
	var tw := root.create_tween().set_loops()
	tw.tween_property(root, "position:y", root.position.y + 0.25, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "position:y", root.position.y, 1.2).set_trans(Tween.TRANS_SINE)


func _rin_talk(goal: Dictionary) -> void:
	if hud == null or hud._dialogue_open:
		return
	if not Game.flags.has("met_rin"):
		Ledger.capture("Rin, the bell that waited 314 years")
	await Town.scene("Rin", str(goal.get("text", "")), goal.get("choices", []), "ura_goal_rin")
	ura_scene_done("goal_rin")


## A goal scene finished: point the way home.
func ura_scene_done(id: String) -> void:
	if id.begins_with("goal_"):
		Week.st()["ura_goal_done"] = true
		if hud and hud.has_method("toast"):
			hud.toast("Get back to the steps before the second bell.", Color(1.0, 0.8, 0.6))


## Seconds before the first bell on the other side (the second rings at twice this). Courage buys time, the old
## umbrella you took home (kasa_friend) keeps the upward rain off you, and food eaten over there calls you sooner.
func bell_seconds() -> float:
	var s := float(Week.ura.get("bell_seconds", 150)) + Toru.bell_bonus()
	if bool(Game.flags.get("kasa_friend", false)):
		s += float(Week.ura.get("kasa_bonus", 20))
	if bool(Game.flags.get("ate_in_ura", false)):
		s *= float(Week.ura.get("food", {}).get("bell_mult", 0.7))
	return s


## Yomotsuhegui (food of the other side): one dango stall offers you a skewer, once per visit (data/ura.json food).
func _ura_food_stall(p: Vector3) -> void:
	var f: Dictionary = Week.ura.get("food", {})
	if f.is_empty():
		return
	var it := Interactable.new()
	it.name = "UraFood"
	it.prompt = str(f.get("prompt", "The dango stall"))
	it.radius = 1.8
	add_child(it)
	it.global_position = p + Vector3(0, 0.6, 1.1)
	it.interacted.connect(func(_p): _ura_food(it))


func _ura_food(it: Interactable) -> void:
	var f: Dictionary = Week.ura.get("food", {})
	var choices: Array = f.get("choices", [])
	var pick: String = await Town.scene(str(f.get("speaker", "")), Week.fill(str(f.get("text", ""))), choices, "ura_food")
	if not pick.is_valid_int() or int(pick) >= choices.size():
		return
	it.enabled = false  # she doesn't offer twice in one visit
	if str(choices[int(pick)].get("kind", "")) == "eat":
		Game.flags["ate_in_ura"] = true
		var pr: Array = Amane.st()["promises"]
		if pr.has("dont_eat_ura"):  # Grandpa's warning in the week 6 dream
			pr.erase("dont_eat_ura")
			Game.flags["broke_genzo_promise"] = true
			Ledger.deed("ura_food_broken", "dango")
		else:
			Ledger.deed("ura_food", "dango")
	else:
		Game.flags["refused_ura_food"] = true
		Ledger.deed("ura_food_refused", "dango")


func _ura_process(delta: float) -> void:
	_set_rain(0.8)
	if hud and hud._dialogue_open:
		return
	_ura_t += delta
	var bell_s := bell_seconds()
	if _ura_bells == 0 and _ura_t >= bell_s:
		_ura_bells = 1
		Audio.play_sfx("chime")
		FX.rumble(0.3, 0.5, 0.4, true)
		if hud and hud.has_method("toast"):
			hud.toast(str(Week.ura.get("first_bell", "")), Color(1.0, 0.7, 0.5))
	elif _ura_bells == 1 and _ura_t >= bell_s * 2.0:
		_ura_bells = 2
		Audio.play_sfx("chime", 0.0, 3.0)
		FX.rumble(0.4, 1.0, 0.8, true)
		_thrown_out()


func _thrown_out() -> void:
	if hud:
		await hud.say("", str(Week.ura.get("second_bell", "")))
	Week.leave_ura(true)


func _ura_light() -> void:
	var sun_node := sun as DirectionalLight3D
	if sun_node:
		sun_node.light_color = Color(1.0, 0.36, 0.26)
		sun_node.light_energy = 0.9
	environment.ambient_light_color = Color(0.36, 0.28, 0.56)
	environment.ambient_light_energy = 0.85
	environment.fog_light_color = Color(0.5, 0.12, 0.24)
	environment.adjustment_saturation = 1.08
	if jp_night_ok():
		build.get("jp").window_scale = 0.45  # shop windows were the brightest thing on the other side
		build.get("jp").set_night(0.8)


## Week.ending: play an ending on the steps with the people in it (EndingStage, data/endings.json stage).
func stage_ending(beats: Array, hud_node: Node) -> void:
	var st := EndingStage.new(self)
	add_child(st)
	await st.play(beats, hud_node)


func jp_night_ok() -> bool:
	return build.get("jp") != null and build.get("jp").has_method("set_night")


# --- Story marker ------------------------------------------------------------------------------------------

## A paper lantern over the next story place (Week.marker) and "(NE 120 m)" on the objective line.
func _marker_process(delta: float) -> void:
	_marker_t -= delta
	if _marker_t > 0.0:
		if _marker and _marker.visible:
			_marker.position.y = _marker.get_meta("y0", 0.0) + sin(Time.get_ticks_msec() / 400.0) * 0.18
		return
	_marker_t = 0.5
	var mk: Array = Week.marker()
	if mk.is_empty() or player == null:
		Week.marker_hint = ""
		if _marker:
			_marker.visible = false
		return
	if _marker == null:
		_marker = _make_marker()
	var tile: Vector2i = mk[0]
	var pos := builder.center(tile.x, tile.y)
	_marker.visible = true
	_marker.global_position = pos + Vector3(0, 3.0, 0)
	_marker.set_meta("y0", _marker.position.y)
	var to := pos - player.global_position
	to.y = 0.0
	var d := to.length()
	if d < 6.0:
		Week.marker_hint = "  (here)"
		return
	var ang := atan2(to.x, -to.z)  # 0 = north (up the screen)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var i := int(round(ang / (PI / 4.0))) % 8
	if i < 0:
		i += 8
	Week.marker_hint = "  (%s %d m)" % [dirs[i], int(d)]


func _make_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "StoryMarker"
	add_child(root)
	var lantern := MeshInstance3D.new()
	lantern.mesh = builder.cylinder(0.32, 0.6, 12)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.25)
	m.emission_energy_multiplier = 2.2
	lantern.material_override = m
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lantern)
	for y in [0.33, -0.33]:
		var cap := MeshInstance3D.new()
		cap.mesh = builder.cylinder(0.2, 0.08, 10)
		var dk := StandardMaterial3D.new()
		dk.albedo_color = Color(0.15, 0.08, 0.06)
		cap.material_override = dk
		cap.position.y = y
		root.add_child(cap)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.omni_range = 5.0
	l.light_energy = 1.2
	root.add_child(l)
	return root


# --- Races (Week.race) -------------------------------------------------------------------------------------

## Spawn the race target and wait: true if the player reaches it in time. "cat" = the two-tailed cat running
## away along the street; "lantern" = a lantern on the hill at `to`. The objective line counts down.
func start_race(spec: Dictionary) -> bool:
	if player == null:
		return false
	var kind := str(spec.get("kind", "lantern"))
	var target := Node3D.new()
	target.name = "RaceTarget"
	add_child(target)
	var spr := BillboardSprite.new()
	var from := player.global_position
	var dir := Vector3.ZERO
	if kind == "cat":
		spr.set_look(Week.ura.get("kasha", {}).get("look", {}))
		target.add_child(spr)
		# Start ~9 m away in whichever direction has open street, so it's always a chase.
		var best := from
		for k in 8:
			var d8 := Vector3.FORWARD.rotated(Vector3.UP, k * PI / 4.0)
			var w8 := nearest_walkable(from + d8 * 9.0)
			if w8.distance_to(from) > best.distance_to(from):
				best = w8
				dir = d8
		target.global_position = best + Vector3(0, 0.05, 0)
		spr.play("run")
	else:
		var to: Array = spec.get("to", [36, 3])
		target.global_position = builder.center(int(to[0]), int(to[1])) + Vector3(0, 0.1, 0)
		var lantern := _make_marker()
		lantern.reparent(target, false)
		lantern.position = Vector3(0, 1.4, 0)
	var dist := from.distance_to(target.global_position)
	var seconds := float(spec.get("seconds", 20)) if bool(spec.get("exact", false)) else maxf(float(spec.get("seconds", 20)), dist / 4.5 + 6.0)
	var speed := float(spec.get("speed", 3.4))
	var t := 0.0
	var won := false
	if hud and hud.has_method("toast"):
		hud.toast(str(spec.get("toast", "RUN!")), Color(1.0, 0.55, 0.4))
	FX.countdown("start")
	Ledger.capture("Running for it" if kind != "cat" else "Chasing a cat with two tails")
	player.set_meta("speed_mult", Toru.race_speed())  # agility
	var last_sec := int(ceil(seconds))
	while t < seconds:
		await get_tree().process_frame
		if not is_inside_tree() or player == null:
			break
		var d := get_process_delta_time()
		if hud and hud._dialogue_open:
			continue
		t += d
		if kind == "cat":
			var p2 := target.global_position + dir * speed * d
			var w := nearest_walkable(p2)
			if w.distance_to(p2) > 0.6:  # hit a wall: turn along it
				dir = dir.rotated(Vector3.UP, PI * 0.5)
			else:
				target.global_position = Vector3(p2.x, target.global_position.y, p2.z)
			spr.set_facing(dir)
		var left := int(ceil(seconds - t))
		Week.marker_hint = "  (RUN! %d s)" % left
		if left < last_sec and left > 0:
			last_sec = left
			FX.countdown("urgent" if left <= 3 else "tick")
		if player.global_position.distance_to(target.global_position) < 2.4:
			won = true
			break
	Week.marker_hint = ""
	if is_instance_valid(player):
		player.remove_meta("speed_mult")
	FX.countdown("win" if won else "lose")
	if is_instance_valid(target):
		target.queue_free()
	return won


# --- Cat spirit night (docs/GDD.md 4.11, data/cat_night.json) ------------------------------------------
## The town sleeps; you are Amane's living spirit, a black cat with two tails. The rival's window decides the
## night (plan / resist), Senpai's window ends it gently, friends' windows hold secrets, some things fall over.

func _build_cat_night() -> void:
	Clock.running = false
	Playtest.mark("Cat night")
	for n in get_tree().get_nodes_in_group("npc"):
		if n == amane or n.is_in_group("cat"):
			continue
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
	for it in find_children("*", "Interactable", true, false):
		it.enabled = false  # shops and doors are shut
	if amane:
		amane.visible = false
		amane.process_mode = Node.PROCESS_MODE_DISABLED
		amane.global_position = Vector3(0, -40, 0)
	var home: Array = cat.get("home_tile", [34, 5])
	player.global_position = builder.center(int(home[0]), int(home[1])) + Vector3(0.5, 0.1, 0.8)
	player.sprite.pixel_size = float(cat.get("pixel_size", 0.06))
	player.sprite.set_look(cat.get("look", {}))
	player.set_meta("speed_mult", float(cat.get("speed", 1.45)))
	player.set_meta("cat_mode", true)
	player.collision_mask |= LevelBuilder.LAYER_ROOF  # the roofs are a road tonight
	# A black cat on black roofs: moonlit fur (brighter tint) and a sleeping town (most windows dark, no notice board).
	player.sprite.base_modulate = Color(1.35, 1.3, 1.55)
	if build.get("jp") != null:
		build.get("jp").window_scale = 0.15
	# Closer and steeper than the street camera: the cat is small and the roofs are the road tonight.
	camera_rig.configure(40.0, 12.0, camera_fov)
	if hud and hud.has_method("set_ticker_shown"):
		hud.set_ticker_shown(false)
	# A soft violet halo of its own (the player's glow light is driven every frame by the player), so a black cat
	# still reads against black roofs at night.
	var halo := OmniLight3D.new()
	halo.name = "CatHalo"
	halo.light_color = Color(0.7, 0.55, 1.0)
	halo.light_energy = 2.6
	halo.omni_range = 5.0
	halo.position = Vector3(0, 1.6, 1.2)
	player.add_child(halo)
	_cat_spots()
	_apply_light()
	_cat_intro.call_deferred()


func _cat_fill(t: String) -> String:
	var who := Amane.rival()
	return Week.fill(Amane.fill(t)).replace("{rival_short}", who.split(" ")[-1] if who != "" else "him").replace("{rival}", who)


func _cat_spot(tile: Array, prompt: String, cb: Callable, r: float = 1.8) -> Interactable:
	var it := Interactable.new()
	it.prompt = _cat_fill(prompt)
	it.radius = r
	it.add_to_group("cat_spot")
	add_child(it)
	it.global_position = builder.center(int(tile[0]), int(tile[1])) + Vector3(0, 0.6, 0)
	it.interacted.connect(func(_p): cb.call(it))
	return it


func _cat_spots() -> void:
	var tw: Dictionary = cat.get("toru_window", {})
	_cat_spot(tw.get("tile", [26, 47]), str(tw.get("prompt", "Senpai's window")), func(_it): _cat_toru_window())
	var rival := Amane.rival()
	var pid := People.id_of(rival)
	var door: Array = People.profile(pid).get("door", []) if pid != "" else []
	if door.size() != 2:
		var homes: Array = cat.get("rival_homes", [[41, 47]])
		door = homes[absi(hash(rival)) % homes.size()]
	_cat_rival_pos = builder.center(int(door[0]), int(door[1]))
	var rw := _cat_spot(door, str(cat.get("rival_window", {}).get("prompt", "{rival_short}'s window")), func(_it): _cat_rival_window())
	rw.name = "RivalWindow"
	for sc in cat.get("secrets", []):
		if str(sc.get("who", "")) == rival:
			continue  # his window is the rival's window tonight
		_cat_spot(sc.tile, str(sc.prompt), func(it): _cat_secret(sc, it))
	for k in cat.get("knocks", []):
		_cat_spot(k.tile, "Knock it over: " + str(k.prompt).to_lower(), func(it): _cat_knock(k, it), 1.5)
	for w in cat.get("watchers", []):
		var nw = load("res://src/actors/night_watcher.gd").new()
		nw.setup(w, self)
		actors.add_child(nw)
		nw.spotted.connect(_cat_spotted)


func _cat_intro() -> void:
	if hud == null:
		return
	var menu := []
	for c in cat.get("intro_choices", []):
		menu.append({"id": str(c.id), "text": str(c.t)})
	var pick: String = await hud.say("", _cat_fill(str(cat.get("intro", ""))), menu)
	if pick == "skip":
		await hud.say("", _cat_fill(str(cat.get("skip", ""))))
		finish_cat_night("skip")
		return
	if hud.has_method("toast"):
		hud.toast("The town's cats lower their heads as you pass. Find %s's window - or Senpai's." % Amane.rival().split(" ")[-1], Color(0.8, 0.85, 1.0))
		hud.toast(str(cat.get("how_to", "")), Color(0.85, 0.8, 1.0))


func cat_objective() -> String:
	var to := _cat_rival_pos - (player.global_position if player else Vector3.ZERO)
	to.y = 0.0
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var i := int(round(atan2(to.x, -to.z) / (PI / 4.0))) % 8
	if i < 0:
		i += 8
	var where := "here" if to.length() < 5.0 else "%s %d m" % [dirs[i], int(to.length())]
	var mins := maxi(0, int(ceil((float(cat.get("dawn_seconds", 240)) - _cat_t) / 60.0)))
	return _cat_fill(str(cat.get("objective", ""))).replace("{where}", where).replace("{mins}", str(mins))


func _cat_process(delta: float) -> void:
	if _cat_done or (hud and hud._dialogue_open):
		return
	_cat_t += delta
	_cat_under(delta)
	if hud and hud.has_method("_refresh_objective") and int(_cat_t * 2.0) != int((_cat_t - delta) * 2.0):
		hud._refresh_objective()  # the clock is stopped, so nothing else refreshes the distance / dawn line
	var dawn := float(cat.get("dawn_seconds", 240))
	if not _cat_warned and _cat_t >= dawn - 60.0:
		_cat_warned = true
		if hud and hud.has_method("toast"):
			hud.toast("The sky over the sea is turning grey. One minute to dawn.", Color(0.85, 0.85, 1.0))
	if _cat_t >= dawn:
		_cat_dawn()


func _cat_dawn() -> void:
	_cat_done = true  # nothing else can start now
	if hud:
		await hud.say("", _cat_fill(str(cat.get("dawn", ""))))
	_cat_done = false
	finish_cat_night("dawn")


func _cat_menu(choices: Array) -> Array:
	var menu := []
	for c in choices:
		menu.append({"id": str(c.id), "text": _cat_fill(str(c.t))})
	return menu


func _cat_toru_window() -> void:
	if _cat_done or hud == null:
		return
	var w: Dictionary = cat.get("toru_window", {})
	Ledger.capture("A black cat at Senpai's window")
	var pick: String = await hud.say("", _cat_fill(str(w.get("text", ""))), _cat_menu(w.get("choices", [])))
	for c in w.get("choices", []):
		if str(c.id) != pick:
			continue
		var lines := Town.apply_fx(c.get("fx", {}))
		await hud.say("", _cat_fill(str(c.get("say", ""))) + ("\n" + lines if lines != "" else ""))
		if c.has("outcome"):
			finish_cat_night(str(c.outcome))


func _cat_rival_window() -> void:
	if _cat_done or hud == null:
		return
	var w: Dictionary = cat.get("rival_window", {})
	var stage := mini(6, int(Amane.st()["plan"]["stage"]) + 1)
	var text := _cat_fill(str(w.get("text", ""))).replace("{stage}", str(cat.get("stage_preview", {}).get(str(stage), "...")))
	var choices: Array = w.get("choices", [])
	Ledger.capture(_cat_fill("A black cat at {rival_short}'s window"))
	for _round in 3:
		var pick: String = await hud.say("", text, _cat_menu(choices))
		var c: Dictionary = {}
		for x in choices:
			if str(x.id) == pick:
				c = x
		if c.is_empty():
			return
		await hud.say("", _cat_fill(str(c.get("say", ""))))
		if c.has("outcome"):
			finish_cat_night(str(c.outcome))
			return
		var rest := []
		for x in choices:
			if x.has("outcome"):
				rest.append(x)
		choices = rest  # after watching him sleep, only the decision is left


func _cat_secret(sc: Dictionary, it: Interactable) -> void:
	if hud == null:
		return
	it.enabled = false
	Ledger.deed("eavesdrop", str(sc.id))
	var lines := Town.apply_fx(sc.get("fx", {}))
	await hud.say("", _cat_fill(str(sc.get("text", ""))) + ("\n" + lines if lines != "" else ""))


func _cat_knock(k: Dictionary, it: Interactable) -> void:
	if hud == null:
		return
	it.enabled = false
	FX.dust(self, it.global_position, 0.8)
	Audio.play_sfx("break", 0.0, -4.0)
	Ledger.deed("knock", str(k.id))
	var lines := Town.apply_fx(k.get("fx", {}))
	if str(k.get("post", "")) != "":
		var u: Array = Amane.st()["ura"]
		u.append({"day": Clock.date_text(), "time": "23:52", "text": str(k.post)})
	await hud.say("", _cat_fill(str(k.get("text", ""))) + ("\n" + lines if lines != "" else ""))


## LEAP (Roll): up onto the roof or wall ahead, across a gap to the next roof, or down to the street.
## Looks 1.5-7 m ahead along the cat's facing, casting down onto houses (WORLD) and roof slabs (ROOF).
func cat_leap() -> bool:
	if player == null or player.has_meta("hopping") or _cat_done:
		return false
	var f: Vector3 = player.facing
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3.FORWARD
	f = f.normalized()
	var from := player.global_position
	var space := get_world_3d().direct_space_state
	var on_roof := from.y > 2.0
	var gap := false
	var target := Vector3.INF
	var ground := Vector3.INF
	for i in range(3, 15):
		var pt := from + f * (i * 0.5)
		var q := PhysicsRayQueryParameters3D.create(pt + Vector3(0, 30, 0), pt + Vector3(0, -2, 0), LevelBuilder.LAYER_WORLD | LevelBuilder.LAYER_ROOF)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var y: float = hit.position.y
		if not on_roof:
			if y > from.y + 1.2 and y < from.y + 12.0:
				target = hit.position
				break
		else:
			if y < 1.0:
				gap = true
				if ground == Vector3.INF:
					ground = hit.position
			elif gap and y > 1.5:
				target = hit.position
				break
	if target == Vector3.INF and on_roof:
		target = ground if ground != Vector3.INF else Vector3(from.x + f.x * 2.5, 0.1, from.z + f.z * 2.5)  # (the navmesh has rooftops too)
	if target == Vector3.INF:
		if hud and hud.has_method("toast"):
			hud.toast("Nothing to leap onto that way.", Color(0.8, 0.8, 0.9))
		return false
	_cat_hop_to(target + Vector3(0, 0.12, 0))
	return true


## One arc from here to `b` (physics off while flying; the camera follows).
func _cat_hop_to(b: Vector3) -> void:
	if player == null or player.has_meta("hopping"):
		return
	player.set_meta("hopping", true)
	var a := player.global_position
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.sprite.play("run", true)
	player.sprite.set_facing((b - a).normalized())
	Audio.play_sfx("roll", 0.0, -6.0)
	var arc := maxf(1.6, b.y - a.y + 1.6)
	var tw := create_tween()
	tw.tween_method(func(k: float): player.global_position = a.lerp(b, k) + Vector3(0, sin(k * PI) * arc, 0), 0.0, 1.0, 0.75)
	await tw.finished
	if is_instance_valid(player):
		player.set_physics_process(true)
		player.remove_meta("hopping")
		FX.dust(self, player.global_position, 0.5)
		Audio.play_sfx("land", 0.0, -6.0)


## Which house is the cat standing on (so the camera never fades it away under its paws)?
var _under_t := 0.0


func _cat_under(delta: float) -> void:
	_under_t -= delta
	if _under_t > 0.0 or player == null:
		return
	_under_t = 0.2
	if player.global_position.y < 1.5:
		player.remove_meta("standing_on")
		return
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.5, 0), player.global_position + Vector3(0, -3, 0),
		LevelBuilder.LAYER_WORLD | LevelBuilder.LAYER_ROOF)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		player.remove_meta("standing_on")
	else:
		player.set_meta("standing_on", hit.collider)


## The night watch saw the cat: chased off, the dawn comes closer, the town talks; three times = the night is over.
var cat_spotted := 0


func _cat_spotted(w: Node) -> void:
	if _cat_done or player == null:
		return
	cat_spotted += 1
	_cat_t += 25.0
	Audio.play_sfx("alert", 0.0, -2.0)
	Ledger.deed("seen", str(w.spec.get("kind", "patrol")))
	var lines: Array = w.spec.get("spotted", ["Shoo!"])
	var place := "the shopping street" if player.global_position.z > 34.0 * LevelBuilder.TILE else ("the road" if player.global_position.z > 30.0 * LevelBuilder.TILE else "the shrine")
	var u: Array = Amane.st()["ura"]
	u.append({"day": Clock.date_text(), "time": "23:5%d" % mini(9, cat_spotted), "text": str(cat.get("spotted_post", "")).replace("{place}", place)})
	if hud and hud.has_method("toast"):
		hud.toast("%s: %s" % [str(w.spec.get("name", "")), str(lines[mini(w.spotted_count - 1, lines.size() - 1)])], Color(1.0, 0.75, 0.6))
	var away: Vector3 = player.global_position - w.global_position
	away.y = 0.0
	_cat_hop_to(nearest_walkable(player.global_position + away.normalized() * 4.5) + Vector3(0, 0.1, 0))
	if cat_spotted >= 3:
		_cat_done = true
		if hud:
			await hud.say("", _cat_fill(str(cat.get("spotted_out", ""))))
		_cat_done = false
		finish_cat_night("dawn")


## The night is decided: tell Amane's mind, then wake up at home the next morning as Toru.
func finish_cat_night(kind: String) -> void:
	if _cat_done:
		return
	_cat_done = true
	Amane.cat_outcome(kind, _cat_fill(str(cat.get("morning", {}).get("plan" if kind == "dawn" else kind, ""))))
	Ledger.deed("cat_night", kind)
	Game.flags.erase("cat_night")
	Clock.next_day()
	Game.location_id = "suzunari"
	Game.save_game()
	Ledger.write()
	Router.goto(Router.SUZUNARI)
