class_name HomeVisits
extends Node
## The five houses of Suzunari (People autoload, data/people/*.json): a door with a nameplate and a bell for each,
## the morning pick-up (ring the bell -> a parent or your friend answers; or wait until they come out at their own
## time), the walk to school / to their door / to yours with a companion who chats on the way, and Amane's
## reaction when it's somebody else (romance: he cuts in, friend: he trails and sulks, ignore: sad texts,
## boundaries: a brave text). Created by the Suzunari level (`home`).

const HOME_TILE := Vector2i(27, 47)  ## Asagiri-do (where Toru wakes up)
const SHOP_TILE := Vector2i(27, 50)  ## Asagiri-do's shop front
const PLATES := {"hayate": "INUKAI", "hina": "HAYASE", "mio": "KUROE", "reiji": "SHIRASAGI", "amane": "NEKOMORI"}

var level: Node
var doors: Dictionary = {}
var companion: Node3D
var _busy := false
var _chat_t := 6.0
var _amane_t := 18.0
var _amane_done := false
var _follow_t := -1.0
var _follow_left := 0
var _first_chat := true


func setup(lvl: Node) -> void:
	level = lvl
	for id in People.IDS:
		_make_door(id)
	Clock.minute_passed.connect(_on_minute)
	_update_prompts()


func _hud() -> Node:
	return level.get("hud")


func _player() -> Node3D:
	return level.get("player") as Node3D


func _tile_pos(t: Vector2i) -> Vector3:
	return level.builder.center(t.x, t.y)


# --- Doors ---------------------------------------------------------------------------------------

func _make_door(id: String) -> void:
	var d := People.door(id)
	var p := _tile_pos(d)
	var wall_z := p.z - LevelBuilder.TILE * 0.5 - 0.15
	var it := Interactable.new()
	it.radius = 2.0
	level.add_child(it)
	it.global_position = Vector3(p.x, 0.9, wall_z + 0.6)
	it.interacted.connect(func(_pl): visit(id))
	doors[id] = it
	# 表札: a wooden nameplate and a doorbell beside the door, the way every Japanese house has one.
	var root := Node3D.new()
	root.name = "Nameplate_" + id
	level.add_child(root)
	root.global_position = Vector3(p.x + 1.05, 0.0, wall_z)
	var wood := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.2, 0.05)
	wood.mesh = bm
	var jp = level.build.get("jp") if level.get("build") is Dictionary else null
	wood.material_override = jp.prop_mat("wood_light", Color(0.92, 0.86, 0.76)) if jp and jp.has_method("prop_mat") else StandardMaterial3D.new()
	wood.position = Vector3(0, 1.62, 0.04)
	root.add_child(wood)
	var plate := Label3D.new()
	plate.text = str(PLATES.get(id, id.to_upper()))
	plate.font_size = 30
	plate.pixel_size = 0.0045
	plate.modulate = Color(0.12, 0.1, 0.1)
	plate.outline_size = 0
	plate.position = Vector3(0, 1.62, 0.075)
	root.add_child(plate)
	var bell := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.1, 0.14, 0.05)
	bell.mesh = bb
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.86, 0.84, 0.8)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.75, 0.4)
	bmat.emission_energy_multiplier = 0.35
	bell.material_override = bmat
	bell.position = Vector3(0, 1.3, 0.04)
	root.add_child(bell)


func _update_prompts() -> void:
	for id in doors:
		var it: Interactable = doors[id]
		var t := "Visit the %s house" % str(PLATES.get(id, id)).capitalize()
		if People.knows(id) and People.status(id) == "morning":
			t += " (%s leaves %s)" % [People.short(id), Clock.time_text(People.leave_min(id))]
		it.prompt = t


func visit(id: String) -> void:
	var hud := _hud()
	if _busy or hud == null or hud._dialogue_open:
		return
	_busy = true
	await _visit(id)
	_busy = false


func _visit(id: String) -> void:
	var hud := _hud()
	if People.escorting(id):
		return
	if People.escorting():
		await hud.say("", People.line(id, "wait_outside") + "\n(You already have company. Another morning.)")
		return
	if id == "amane" and not Amane.st()["met"]:
		await hud.say("Nekomori Chiyo", "The old shrine keeper looks at you a long time. \"He left at dawn. He said someone would come to Suzunari Gakuen today, and he had to be at the gate.\" A tap of her cane. \"Go on, then.\"")
		return
	match People.status(id):
		"morning":
			await _morning_door(id)
		"away":
			var pl := People.parent_line(id, "parent_left")
			await hud.say(pl.who, pl.t)
		_:
			var key := "parent_about_you" if Clock.is_weekend() or randf() < 0.35 else "parent_evening"
			var pe := People.parent_line(id, key)
			await hud.say(pe.who, pe.t)


func _morning_door(id: String) -> void:
	var hud := _hud()
	var text := People.line(id, "wait_outside")
	while People.status(id) == "morning":
		var wait_t := "Wait for %s (leaves %s)." % [People.short(id), Clock.time_text(People.leave_min(id))] if People.knows(id) \
			else "Wait outside a little."
		var picked: String = await hud.say("", text, [{"id": "ring", "text": "Ring the bell."},
			{"id": "wait", "text": wait_t}, {"id": "leave", "text": "Leave."}])
		match picked:
			"ring":
				await _ring(id)
				return
			"wait":
				var lv := People.leave_min(id)
				Clock.advance(lv - Clock.minute() if People.knows(id) else mini(5, lv - Clock.minute()))
				if Clock.minute() >= lv:
					await _come_out(id, "wait")
					return
				text = People.line(id, "wait_outside") + "\n> 5 minutes pass. (%s)" % Clock.clock_text()
			_:
				return


## Lazy? Ring. A parent, or your friend in person, answers - and each takes it their own way.
func _ring(id: String) -> void:
	var hud := _hud()
	var ans: Dictionary = People.profile(id).get("answer", {})
	var parent_p := float(ans.get("parent", 0.5))
	match People.tier(id):
		"mid":
			parent_p *= 0.7
		"high":
			parent_p = 1.0 - float(ans.get("self_high", 0.7))
	if Toru.quirk("promise_breaker"):
		parent_p = minf(1.0, parent_p + 0.2)  # kotodama: they send a parent to the door instead
	if randf() < parent_p:
		var pl := People.parent_line(id, "ring_parent")
		await hud.say(pl.who, pl.t)
		if randf() < 0.3:
			var pa := People.parent_line(id, "parent_about_you")
			await hud.say(pa.who, pa.t)
		await _come_out(id, "rushed")
	else:
		await _come_out(id, "self")


## They step out of the door: their own reaction to being picked up, then walk together or not.
func _come_out(id: String, how: String) -> void:
	var hud := _hud()
	People.today(id)["out"] = true
	var key: String = {"wait": "come_out", "rushed": "come_out_rushed", "self": "ring_self", "natural": "come_out"}.get(how, "come_out")
	var text := People.line(id, key)
	if how in ["wait", "natural"] and float(Amane.st()["rain"]) > 0.4 and randf() < 0.6:
		text = People.line(id, "come_out_rain")
	var delta := People.fx(id, "wait") if how == "wait" else (People.fx(id, "rush") if how in ["rushed", "self"] else 0)
	var before := People.close(id)
	People.add_close(id, delta)
	if delta != 0:
		text += "\n> %s %s you %s. (%d -> %d)" % [People.short(id), "liked that" if delta > 0 else "didn't like that",
			"waited" if how == "wait" else "rang the bell", before, People.close(id)]
	_spawn_companion(id, _tile_pos(People.door(id)) + Vector3(0.4, 0.1, -0.2))
	var picked: String = await hud.say(People.short(id), text, [{"id": "go", "text": "\"Let's walk to school together.\""},
		{"id": "no", "text": "\"I was just passing by.\""}])
	if picked == "go":
		People.start_escort(id, "school")
		People.today(id)["picked"] = true
		await hud.say(People.short(id), People.line(id, "pickup_accept"))
		_begin_walk()
	else:
		People.add_close(id, -1)
		if id == "amane":
			Amane.add("tears", 1.0)
		await hud.say(People.short(id), People.line(id, "pickup_decline"))
		dismiss(true)


# --- The walk ------------------------------------------------------------------------------------

func _spawn_companion(id: String, at: Vector3) -> Node3D:
	if companion and is_instance_valid(companion) and not companion.get("leaving"):
		return companion
	if id == "amane":
		companion = level.get("amane") as Node3D
		if companion:
			companion.visible = true
			companion.global_position = at
		return companion
	# Take over from their usual body if it's standing somewhere in the scene.
	for n in get_tree().get_nodes_in_group("npc"):
		if n.get("npc_name") == People.full_name(id) and n.visible and not n.is_in_group("companion"):
			at = n.global_position
	var c = load("res://scenes/actors/npc.tscn").instantiate()
	c.set_script(load("res://src/actors/companion_npc.gd"))
	c.person = id
	level.actors.add_child(c)
	c.global_position = at
	companion = c
	return c


func _begin_walk() -> void:
	_chat_t = 5.0
	_amane_t = randf_range(12.0, 22.0)
	_amane_done = false
	_follow_t = -1.0
	_follow_left = 0
	_first_chat = true


## Called by the level after its own morning note: someone you said yes to is at your door, or an escort
## carried over from another scene (walking out of the school with someone).
func resume() -> void:
	var s := People.st()
	var pm: Dictionary = s["pickup_me"]
	var hud := _hud()
	if not pm.is_empty() and int(pm.get("day", 0)) == Clock.day() and not People.escorting() and hud:
		s["pickup_me"] = {}
		var id := str(pm.get("who", ""))
		if Clock.is_weekend() or not People.data.has(id):
			return
		People.today(id)["out"] = true
		_spawn_companion(id, _player().global_position + Vector3(1.6, 0.1, 1.2))
		_busy = true
		var picked: String = await hud.say(People.short(id), People.line(id, "at_your_door"),
			[{"id": "go", "text": "\"Morning! Let's go.\""}, {"id": "no", "text": "\"Sorry - go ahead without me.\""}])
		if picked == "go":
			People.start_escort(id, "school")
			People.today(id)["picked"] = true
			_begin_walk()
		else:
			People.add_close(id, -3)
			await hud.say(People.short(id), People.line(id, "pickup_decline"))
			dismiss(true)
		_busy = false
		return
	if People.escorting():
		var e := People.escort()
		if int(e.get("day", 0)) != Clock.day():
			People.end_escort()
			return
		_spawn_companion(str(e.who), _player().global_position + Vector3(1.6, 0.1, 0.8))
		_begin_walk()


func _process(delta: float) -> void:
	if not People.escorting() or level == null:
		return
	var e := People.escort()
	var id := str(e.get("who", ""))
	var mode := str(e.get("mode", "school"))
	var p := _player()
	if p == null:
		return
	if companion == null or not is_instance_valid(companion):
		_spawn_companion(id, p.global_position + Vector3(1.6, 0.1, 0.8))
		return
	var hud := _hud()
	if _busy or (hud and hud._dialogue_open):
		return
	var tile := Vector2i(int(p.global_position.x / LevelBuilder.TILE), int(p.global_position.z / LevelBuilder.TILE))
	match mode:
		"school":
			if tile.y >= 20 and tile.y <= 30 and tile.x <= 39:
				finish()
				return
		"their_home":
			if p.global_position.distance_to(_tile_pos(People.door(id))) < 4.5:
				finish()
				return
		"my_home":
			if p.global_position.distance_to(_tile_pos(HOME_TILE)) < 5.0 or p.global_position.distance_to(_tile_pos(SHOP_TILE)) < 5.0:
				finish()
				return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(14.0, 22.0)
		if companion.has_method("say"):
			companion.say(_walk_line(id, mode), 5.0)
	if id != "amane" and not _amane_done:
		_amane_t -= delta
		if _amane_t <= 0.0:
			_amane_done = true
			_amane_react(id)
	if _follow_t > 0.0:
		_follow_t -= delta
		if _follow_t <= 0.0 and _follow_left > 0:
			_follow_left -= 1
			_follow_t = randf_range(9.0, 14.0) if _follow_left > 0 else -1.0
			var a := level.get("amane") as Node3D
			if a and a.visible and a.has_method("say"):
				a.say(People.jealous("follow", id), 2.4)
				Emotion.express(a, "peek" if randf() < 0.5 else "pout", 2.0)


func _walk_line(id: String, mode: String) -> String:
	if _first_chat:
		_first_chat = false
		if mode == "school":
			var d := People.line(id, "morning_day")
			if d != "":
				return d
	if float(Amane.st()["rain"]) > 0.4 and randf() < 0.4:
		return People.line(id, "walk_rain")
	if People.tier(id) == "high" and randf() < 0.35:
		return People.line(id, "walk_close")
	return People.line(id, "home_walk" if mode != "school" and randf() < 0.75 else "walk")


## The end of the road: at the school gate, their door, or yours.
func finish() -> void:
	if not People.escorting():
		return
	var hud := _hud()
	_busy = true
	var e := People.escort().duplicate()
	var id := str(e.who)
	var mode := str(e.mode)
	var s := People.st()
	var before := People.close(id)
	var lines: Array[String] = []
	if mode == "school":
		People.add_close(id, People.fx(id, "pickup"))
		s["pickups"][id] = int(s["pickups"].get(id, 0)) + 1
		People.today(id)["arrived"] = true
		if int(s["promise"].get(id, -1)) == Clock.day():
			s["promise"].erase(id)
			People.add_close(id, 2)
			lines.append("> You kept your promise.")
	else:
		People.add_close(id, People.fx(id, "walk"))
		s["walks"][id] = int(s["walks"].get(id, 0)) + 1
		People.today(id)["home"] = true
	lines.push_front("> %s %d -> %d%s" % [People.short(id), before, People.close(id), "  (" + People.tier(id).to_upper() + ")"])
	People.end_escort()
	if hud:
		var text := People.line(id, "arrive" if mode == "school" else "goodbye") + "\n" + "\n".join(lines)
		var choices := [{"id": "bye", "text": "\"See you later.\""}]
		if mode == "school" and People.tier(id) != "low" and not s["promise"].has(id):
			choices.push_front({"id": "promise", "text": "\"Same time tomorrow?\""})
		var picked: String = await hud.say(People.short(id), text, choices)
		if picked == "promise":
			s["promise"][id] = Clock.day() + 1
			await hud.say(People.short(id), People.line(id, "promise_yes") + "\n> A promise. %s will be waiting tomorrow." % People.short(id))
		if mode != "school":
			await _offer_pickup(id)
		if mode == "school" and id != "amane" and Amane.st()["met"] and Amane.route() in ["friend", "none"] \
				and int(Amane.st()["jealousy"].get(People.full_name(id), 0)) > 0:
			var a := level.get("amane") as Node3D
			if a and a.visible:
				await hud.say("Amane", People.jealous("sulk", ""))
				Emotion.express(a, "sulk", 3.0)
	_end_amane_join()
	dismiss(mode != "school" or id != "amane")
	_busy = false


## Close friends offer to come and get you tomorrow (their words); a yes means they'll be at your door.
func _offer_pickup(id: String) -> void:
	var need := 40 if id in ["hayate", "amane"] else People.NEED_PICKUP_OFFER
	if People.close(id) < need or not People.st()["pickup_me"].is_empty() or randf() > 0.7:
		return
	var hud := _hud()
	var picked: String = await hud.say(People.short(id), People.line(id, "offer_pickup"),
		[{"id": "yes", "text": "\"Yes - come and get me.\""}, {"id": "no", "text": "\"I'll be fine, thanks.\""}])
	if picked == "yes":
		People.st()["pickup_me"] = {"who": id, "day": Clock.day() + 1}
		await hud.say(People.short(id), "\"Then it's a promise!\"\n> Tomorrow morning %s comes to Asagiri-do." % People.short(id))


## The companion walks off (towards the school door or into their house) and is freed; Amane just goes
## back to trailing you.
func dismiss(walk_off: bool = true) -> void:
	if companion == null or not is_instance_valid(companion):
		companion = null
		return
	if companion.is_in_group("amane"):
		companion = null
		return
	if walk_off and companion.has_method("leave"):
		var p := _player()
		companion.leave(companion.global_position - p.global_position if p else Vector3.FORWARD)
	else:
		companion.queue_free()
	companion = null


# --- Amane, while you walk with someone else -------------------------------------------------------

func _amane_react(id: String) -> void:
	var s := Amane.st()
	var a := level.get("amane") as Node3D
	if not s["met"] or s["blocked"]:
		return
	var who := People.full_name(id)
	match Amane.route():
		"romance":
			await _cut_in(id, a)
		"ignore":
			Amane.notice_rival(who)
			Amane.send_text(People.jealous("text", id))
			Amane.add("tears", 0.5)
		"boundary":
			Amane.send_text(People.jealous("text_boundary", ""))
			Amane.add("self", 2.0)
		_:
			Amane.notice_rival(who, a if a and a.visible else null)
			_follow_left = 2
			_follow_t = randf_range(6.0, 10.0)


func _cut_in(id: String, a: Node3D) -> void:
	var hud := _hud()
	var p := _player()
	if hud == null or p == null:
		return
	if hud._dialogue_open:
		_amane_done = false
		_amane_t = 4.0
		return
	_busy = true
	var who := People.full_name(id)
	if a:
		a.visible = true
		var spot: Vector3 = p.global_position + Vector3(-1.4, 0.05, 0.9)
		if level.has_method("nearest_walkable"):
			spot = level.nearest_walkable(spot)
		a.global_position = spot
		a.set_meta("close_follow", true)
	Amane.notice_rival(who)
	var j: Dictionary = Amane.st()["jealousy"]
	if a:
		Emotion.express(a, "yandere" if int(j.get(who, 0)) >= 30 else "pout", 3.0)
	var before := {"bond": float(Amane.st()["bond_now"]), "tears": Amane.tears_level(), "route": Amane.route()}
	var text := People.jealous("cut_in", id) + "\n\n%s: %s" % [People.short(id), People.line(id, "amane_cut_in")]
	var choices := [{"id": "kind", "text": "\"Amane, walk with us.\""}, {"id": "honest", "text": "\"We're just friends. Really.\""},
		{"id": "boundary", "text": "\"Amane. Not now.\""}]
	if float(Amane.st()["bond_now"]) >= 40.0:
		choices.push_front({"id": "hand", "text": "Take his hand."})
	var picked: String = await hud.say("Amane", text, choices)
	match picked:
		"hand":
			Amane.add("bond_now", 6.0)
			Amane.add("tears", -1.0)
			j[who] = maxi(0, int(j.get(who, 0)) - 20)
			People.add_close(id, -2)
			if a:
				Emotion.express(a, "happy", 3.0)
		"kind":
			Amane.add("bond_now", 3.0)
			Amane.add("tears", -0.6)
			Amane.add("trust", 1.0)
			j[who] = maxi(0, int(j.get(who, 0)) - 10)
		"honest":
			Amane.add("trust", 2.0)
			Amane.add("tears", -0.3)
			j[who] = maxi(0, int(j.get(who, 0)) - 5)
		_:
			picked = "boundary"
			Amane.add("self", 3.0)
			Amane.add("tears", 1.0)
			if a:
				a.remove_meta("close_follow")
				Emotion.express(a, "sad", 3.0)
	var out := People.jealous("cut_in_reply", picked)
	if picked == "kind":
		out += "\n" + People.jealous("join", "")
	await hud.say("Amane", out + "\n" + Amane.impact(before))
	if picked in ["honest", "boundary"]:
		_end_amane_join()
	_busy = false


func _end_amane_join() -> void:
	var a := level.get("amane") as Node3D
	if a and a.has_meta("close_follow"):
		a.remove_meta("close_follow")


# --- Clock: people leave home at their own minute --------------------------------------------------

func _on_minute(m: int) -> void:
	_update_prompts()
	if Clock.is_weekend():
		return
	var s := People.st()
	var p := _player()
	var hud := _hud()
	for id in People.IDS:
		var t := People.today(id)
		if bool(t.get("out", false)) or m < People.leave_min(id):
			continue
		t["out"] = true
		if id == "amane" and not Amane.st()["met"]:
			continue
		var near := p != null and p.global_position.distance_to(_tile_pos(People.door(id))) < 9.0
		if near and not _busy and hud and not hud._dialogue_open and not People.escorting():
			_busy = true
			_come_out.call_deferred(id, "natural")
			_release_later.call_deferred()
	# Promises: they wait three minutes past their time, then go - and remember.
	for id in s["promise"].keys():
		if int(s["promise"][id]) != Clock.day() or bool(People.today(id).get("picked", false)):
			continue
		if m >= People.leave_min(id) + 3:
			s["promise"].erase(id)
			s["broken"][id] = true
			var before := People.close(id)
			People.add_close(id, People.fx(id, "broken"))
			if id == "amane":
				Amane.add("tears", 1.5)
			if hud and hud.has_method("toast"):
				hud.toast("%s waited at the door. You promised. (%d -> %d)" % [People.short(id), before, People.close(id)], Color(1.0, 0.7, 0.6))


func _release_later() -> void:
	# _come_out runs as a deferred coroutine; wait until its dialogue closes before taking new visits.
	var hud := _hud()
	await get_tree().process_frame
	while hud and hud._dialogue_open:
		await get_tree().process_frame
	_busy = false
