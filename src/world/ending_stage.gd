class_name EndingStage
extends Node
## Staged endings (data/endings.json endings.<id>.stage, docs/dev/story.md): Toru, Amane and whoever else belongs in
## the ending stand on the 999 steps or at the shrine and act each line before it is spoken.
## A beat = {"do": [actions], "who": "Speaker", "say": "line"}; a beat without "say" only acts (use it to sequence).
## Actions (tiles are map tiles, floats allowed; Y comes from the ground under them):
##   {"at": who, "tile": [x, z]}            place (spawns a cast member the first time)
##   {"walk": who, "tile": [x, z], "t": s}  walk there (t defaults to distance / 2.2 m/s)
##   {"face": who, "to": who2 or [x, z]}    turn towards someone or a tile
##   {"feel": who, "is": feeling, "s": s}   Emotion.express (data/emotions.json feelings)
##   {"hide": who} / {"show": who}          vanish / come back
##   {"camera": who}                         the camera follows someone else (Toru by default)
##   {"fx": "rain" | "rain_stop" | "bell" | "red" | "dawn" | "day" | "night" | "fade_out" | "fade_in" | "flash" | "cats"}
##   {"wait": s}
## who = "toru" (the player), "amane" (the AmaneNPC in the level) or a cast look id (data/cast_looks.json); spawned
## people are named from NAMES. Each beat waits for its longest action, then shows the line.
## Headless (tests): nothing tweens or waits - everyone snaps into place, so a test can click straight through.

const NAMES := {"sayo": "Sayo", "makoto": "Asagiri Makoto", "kyoko": "Shirasagi Kyoko", "takeshi": "Inukai Takeshi",
	"hayate": "Inukai Hayate", "hina": "Hayase Hina", "mio": "Kuroe Mio", "reiji": "Shirasagi Reiji",
	"makabe": "Makabe-sensei", "chiyo": "Nekomori Chiyo", "haruka": "Asagiri Haruka",
	"first_year_a": "A first-year", "first_year_b": "A first-year"}
## Rivals who are spirited away (Amane fate "hidden") are not in town: they stay invisible in any ending scene.
const RIVALS := {"hayate": "Inukai Hayate", "hina": "Hayase Hina", "mio": "Kuroe Mio", "reiji": "Shirasagi Reiji"}
const SPEED := 2.2  # metres per second, an unhurried walk
const NPC_SCENE := preload("res://scenes/actors/npc.tscn")
const TILE := 2.0

var level: Node
var actors := {}
var instant := false
var _fade: ColorRect
var _lamp: OmniLight3D  # a soft warm key light over the people on stage: night endings were too dark to read faces
var _hidden := {}
var _red := false  # Ura light: re-applied every frame, the level's own light would undo it


func _init(lvl: Node = null) -> void:
	level = lvl
	name = "EndingStage"


func play(beats: Array, hud: Node) -> void:
	instant = DisplayServer.get_name() == "headless"
	Clock.running = false
	_build_fade()
	_lamp = OmniLight3D.new()
	_lamp.name = "StageLamp"
	_lamp.light_color = Color(1.0, 0.85, 0.66)
	_lamp.omni_range = 7.5
	_lamp.shadow_enabled = false
	level.add_child(_lamp)
	actors["toru"] = level.player
	_freeze(level.player)
	var am = level.get("amane")
	if am != null and is_instance_valid(am):
		actors["amane"] = am
		_freeze(am)
	for bt in beats:
		var longest := 0.0
		for a in bt.get("do", []):
			longest = maxf(longest, _act(a))
		_aim_lamp()  # where people are going to stand
		if longest > 0.0 and not instant:
			await get_tree().create_timer(longest + 0.25).timeout
		_keep_visible()
		var say := str(bt.get("say", ""))
		if say != "" and hud != null:
			await hud.say(Week.fill(str(bt.get("who", ""))), Week.fill(Amane.fill(say)))


func _freeze(n: Node) -> void:
	n.set_physics_process(false)
	n.set_process_unhandled_input(false)
	if n != level.player:
		n.set_process(false)  # AmaneNPC peeks and follows from _process
	if n is CharacterBody3D:
		(n as CharacterBody3D).velocity = Vector3.ZERO


func _actor(who: String) -> Node3D:
	if actors.has(who) and is_instance_valid(actors[who]):
		return actors[who]
	var n = NPC_SCENE.instantiate()
	n.set_script(load("res://src/actors/stage_npc.gd"))
	n.cast_id = who
	n.label = str(NAMES.get(who, who.capitalize()))
	level.actors.add_child(n)
	actors[who] = n
	return n


## The ground under a (fractional) map tile: the steps climb, so Y is a ray down onto the world.
func _pos(t: Array) -> Vector3:
	var x := float(t[0]) * TILE + TILE * 0.5
	var z := float(t[1]) * TILE + TILE * 0.5
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -20.0, z), 1)
	var hit := space.intersect_ray(q)
	return Vector3(x, (float(hit.position.y) if not hit.is_empty() else 0.0) + 0.1, z)


func _sprite(n: Node) -> BillboardSprite:
	var s = n.get("sprite") if n else null
	return s as BillboardSprite


func _face(n: Node3D, at: Vector3) -> void:
	var d := at - n.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var s := _sprite(n)
	if s:
		s.set_facing(d.normalized())
	if n == level.player:
		level.player.facing = d.normalized()


## Runs one action; returns how long it takes (the beat waits for its longest action).
func _act(a: Dictionary) -> float:
	if a.has("at"):
		var n := _actor(str(a.at))
		n.global_position = _pos(a.get("tile", [4, 10]))
		n.visible = not _absent(str(a.at))
		_hidden.erase(str(a.at))
		n.set_meta("stage_to", n.global_position)
		return 0.0
	if a.has("walk"):
		var n := _actor(str(a.walk))
		var to := _pos(a.get("tile", [4, 10]))
		var t := float(a.get("t", n.global_position.distance_to(to) / SPEED))
		_face(n, to)
		n.set_meta("stage_to", to)
		if instant or t <= 0.01:
			n.global_position = to
			return 0.0
		var s := _sprite(n)
		if s:
			s.play("walk")
		var tw := create_tween()
		tw.tween_property(n, "global_position", to, t)
		if s:
			tw.tween_callback(func(): s.play("idle"))
		return t
	if a.has("face"):
		var n := _actor(str(a.face))
		var to = a.get("to", "toru")
		_face(n, _pos(to) if to is Array else _actor(str(to)).global_position)
		return 0.0
	if a.has("feel"):
		Emotion.express(_actor(str(a.feel)), str(a.get("is", "content")), float(a.get("s", 4.0)))
		return 0.0
	if a.has("hide"):
		_actor(str(a.hide)).visible = false
		_hidden[str(a.hide)] = true
		return 0.0
	if a.has("show"):
		_actor(str(a.show)).visible = not _absent(str(a.show))
		_hidden.erase(str(a.show))
		return 0.0
	if a.has("camera"):
		level.camera_rig.target = _actor(str(a.camera))
		return 0.0
	if a.has("wait"):
		return 0.0 if instant else float(a.wait)
	if a.has("fx"):
		return _fx(str(a.fx), a)
	return 0.0


## Schedules (AmaneNPC is "at home" before 7:52, People.hides) must not hide someone the ending put on stage.
func _keep_visible() -> void:
	for who in actors:
		var n = actors[who]
		if is_instance_valid(n) and n.has_meta("stage_to") and not _hidden.has(who) and not _absent(str(who)):
			n.visible = true


## The lamp hangs above and in front of everyone on stage (the camera looks north), softer by day.
func _aim_lamp() -> void:
	var sum := Vector3.ZERO
	var n_vis := 0
	for who in actors:
		var n = actors[who]
		if is_instance_valid(n) and n.has_meta("stage_to") and not _hidden.has(who):
			sum += n.get_meta("stage_to")
			n_vis += 1
	if n_vis == 0:
		return
	_lamp.global_position = sum / float(n_vis) + Vector3(0, 2.8, 2.2)
	var m := int(Clock.minute())
	_lamp.visible = m < 390 or m >= 1050  # by day the sun is enough (and light hair would bloom under it)
	_lamp.light_energy = 1.7


func _process(_d: float) -> void:
	if _red and level != null:
		level._ura_light()


func _absent(who: String) -> bool:
	return RIVALS.has(who) and Amane.fate(str(RIVALS[who])) == "hidden"


func _fx(kind: String, a: Dictionary = {}) -> float:
	match kind:
		"rain":
			Amane.set_tears(4.6)
			level._set_rain(0.9)
		"rain_stop":
			Amane.set_tears(0.0)
			level._set_rain(0.0)
		"bell":
			Audio.play_sfx("chime")
			FX.rumble(0.3, 0.5, 0.4, true)
		"red":
			# Ura's endless red dusk: the sun low at Omagatoki first (at 21:00 it is below the horizon), then the red.
			Clock.st()["minute"] = 1085
			level._apply_light()
			_red = true
			level._ura_light()
		"dawn", "day", "night":
			_red = false
			Clock.st()["minute"] = {"dawn": 330, "day": 600, "night": 1260}[kind]
			level._apply_light()
		"fade_out", "fade_in", "flash":
			return _fade_to(kind)
		"cats":
			_cats_watch(a.get("around", [3.5, 13]))
	return 0.0


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5  # under the HUD (10): the dialogue box still shows on black
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _fade_to(kind: String) -> float:
	var c := Color(1, 1, 1, 1) if kind == "flash" else Color(0, 0, 0, 1)
	var end := 1.0 if kind == "fade_out" else 0.0
	if kind == "fade_in":
		c = Color(0, 0, 0, _fade.color.a)
	_fade.color = c
	if instant:
		_fade.color.a = end
		return 0.0
	var t := 0.8 if kind == "flash" else 1.4
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", end, t)
	return t


## Every cat in town comes and sits in a ring around the scene, watching (the red thread, the two of us).
func _cats_watch(around: Array) -> void:
	var cats := get_tree().get_nodes_in_group("cat")
	var mid := _pos(around)
	for i in cats.size():
		var c = cats[i]
		_freeze(c)
		var ang := TAU * float(i) / float(maxi(1, cats.size())) + 0.4
		var r := 2.6 + 0.8 * float(i % 2)
		c.global_position = _pos([float(around[0]) + cos(ang) * r, float(around[1]) + sin(ang) * r])
		c.visible = true
		var s := _sprite(c)
		if s:
			s.set_facing((mid - c.global_position).normalized())
			s.play("idle")
