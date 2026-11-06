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
var overlay: Node
var _rain: Array[CPUParticles3D] = []
var _storm_t := 0.0
var _petals: GPUParticles3D
var _motes: GPUParticles3D


func _setup() -> void:
	palette = {
		"theme": "suzunari", "bg": "#8a9cc4", "ground": "#8c8796", "ground_alt": "#9a94a4", "wall": "#e6dccb",
		"fog": "#d8cfe2", "fog_density": 0.004, "sun": "#ffe2b8", "sun_energy": 1.2, "ambient": "#b8c0dc",
		"ambient_energy": 1.3, "neon": ["#ffb35a", "#ff6a7a", "#7ad0ff"], "props": ["crate"], "ground_tex": "concrete",
		"path_tex": "asphalt", "horizon": ["skyline_mountains", "skyline_city", "skyline_mountains"], "foliage": 0.0,
		"foliage_cells": [0, 4], "plant": "#6aa84f", "plant_glow": 0.0, "puddles": "water", "weather": "",
		"water": "#1d4c5e", "water_glow": "#a8e6ee", "water_glow_strength": 0.05, "water_glow_b": "#ffb35a",
		"water_reflect": 0.0, "building_h": [4.0, 7.0], "exposure": 1.12}
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
	_build_petals()
	_build_motes()
	var jp = build.get("jp")
	if jp:
		var life := TownLife.new()
		life.name = "TownLife"
		add_child(life)
		life.setup(jp.ground_spots(), jp.flower_spots())
	# Kei cars and vans on the roads (left-hand traffic: eastbound on the north lane).
	var w := builder.width
	var lanes := [[builder.center(-3, 32), builder.center(w + 2, 32)], [builder.center(w + 2, 33), builder.center(-3, 33)],
		[builder.center(-3, 43), builder.center(w + 2, 43)], [builder.center(w + 2, 43), builder.center(-3, 43)]]
	for i in 6:
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
	environment.fog_density = 0.0035
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
		h.global_position = builder.center(16, 29) + Vector3(0, 0.1, 0)
		h.spot = h.global_position
	Town.spawn_in(self)
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
	if _petals and player:
		_petals.global_position = player.global_position + Vector3(0, 6.0, -5.0)
		if _motes:
			_motes.global_position = player.global_position + Vector3(0, 1.6, -3.0)
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
	if m >= Clock.END_MIN and is_inside_tree():
		end_day()


func _apply_light() -> void:
	if not sun or not environment:
		return
	var l := Clock.light()
	var gloom := 1.0 - 0.45 * float(Amane.st()["rain"])
	# HD-2D contrast: a strong key light with real shadows, a low cool fill (flat ambient killed the depth).
	sun.light_color = l.sun
	sun.light_energy = float(l.sun_energy) * gloom * 1.25
	environment.ambient_light_color = l.ambient
	environment.ambient_light_energy = float(l.ambient_energy) * (0.75 + 0.25 * gloom) * 0.62
	# The sun crosses the sky behind the camera: low and golden from the south-east in the morning,
	# high at noon, long red shadows from the south-west at Omagatoki.
	var t := clampf((float(Clock.minute()) - 450.0) / (Clock.NIGHT - 450.0), 0.0, 1.0)
	var elev := lerpf(24.0, 58.0, sin(t * PI)) if t < 0.92 else lerpf(18.0, 10.0, (t - 0.92) / 0.08)
	sun.rotation_degrees = Vector3(-elev, lerpf(48.0, -55.0, t), 0.0)
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
	environment.fog_height_density = 0.12 * morning + 0.02


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
