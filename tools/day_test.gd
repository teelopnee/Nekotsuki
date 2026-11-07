extends SceneTree
## NEKOTSUKI episode 0, day loop: Suzunari loads, Amane spawns and follows, tears -> rain, routes,
## shrinking "no", phone replies, the doorstep morning, end of day. Exit code = failures.
## godot --headless --path . --script res://tools/day_test.gd

var _step := 0
var _wait := 0
var fails := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var amane = root.get_node("Amane")
	var clock = root.get_node("Clock")
	match _step:
		0:
			game.new_game("Day Tester", {}, 7, {}, "", 17)
			game.location_id = "suzunari"
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			# Close the day-one narration (dialogue pauses the world), then let time run.
			var hud = current_scene.get("hud")
			if hud and hud.get("_dialogue_open"):
				hud._on_choice("")
			clock.rate = 60.0  # one game hour per real second for the test
			_wait = 90
		2:
			var lvl = current_scene
			_check(lvl != null and lvl.name == "Suzunari", "Suzunari scene loaded")
			var a = get_first_node_in_group("amane")
			_check(a != null, "Amane spawned")
			_check(clock.running and clock.minute() > clock.START_MIN, "clock runs (%s running=%s paused=%s dlg=%s)" % [clock.clock_text(), clock.running, paused, lvl.hud.get("_dialogue_open")])
			clock.rate = 1.0
			_check(not game.air_billing_active, "no air billing in Suzunari")
			_check(lvl.get("_rain").size() >= 1, "rain particles exist")
			var s: Dictionary = amane.st()
			s["met"] = true
			for i in 4:
				amane.choose("reject")
			_check(amane.tears_level() >= 4, "rejecting makes him wail (tears %d)" % amane.tears_level())
			_check(amane.route() == "ignore", "route = ignore")
			var ch: Array = amane.choices()
			_check(float(ch[3].scale) < float(ch[0].get("scale", 1.0)) and ch[2].get("disabled", false), "'no' shrinks, boundary locked while crying")
			_check(amane.rain_target() >= 0.7, "storm clouds over Suzunari")
			var r: Dictionary = amane.choose("flirt")
			_check(amane.route() == "romance" and str(r.text).contains("> Tears"), "flirting -> romance + impact block")
			amane.set_tears(0.0)
			var self_before := float(amane.st()["self"])
			amane.choose("boundary")
			_check(float(amane.st()["self"]) > self_before and amane.route() == "romance", "boundaries grow his self, romance stays")
			amane.st()["route"] = "friend"
			amane.choose("boundary")
			_check(amane.route() == "boundary", "friend -> boundary route")
			# Amane follows: put the player far away, he slips back behind.
			var p = get_first_node_in_group("player")
			p.global_position = lvl.builder.center(21, 20) + Vector3(0, 0.2, 0)
			_wait = 120
		3:
			var a = get_first_node_in_group("amane")
			var p = get_first_node_in_group("player")
			_check(a.global_position.distance_to(p.global_position) < 22.0, "Amane keeps up (%.1f m)" % a.global_position.distance_to(p.global_position))
			# Suzunari theme: town verbs only, Japanese shops, no sci-fi words in what people say.
			var db = root.get_node("DataDB")
			_check(db.theme == "suzunari" and str(db.venues.venues.food.name) == "Shopping Street Eatery", "themed venues")
			var bad := RegEx.new()
			bad.compile("(?i)paragon|consortium|credit|planet|implant|android|oxygenix|halcyon|gristle|lumen|protein paste|\\bcr\\b")
			var npc: Node = null
			for n in get_nodes_in_group("npc"):
				if not n.is_in_group("amane") and n.get("role") == "civilian":
					npc = n
					break
			if npc:
				var ids: Array = root.get_node("Interactions").choices_for(npc, "civilian").map(func(c): return str(c.id).trim_prefix("act:"))
				var ok := true
				for id in ids:
					if id.begins_with("act") or id == "" or id == "leave":
						continue
					if not root.get_node("Interactions").SUZUNARI_VERBS.has(id) and not id.contains(":"):
						ok = false
						print("    off-theme verb: ", id)
				_check(ok, "only town verbs (%d choices)" % ids.size())
				var leaks := 0
				for i in 40:
					var line: String = npc._opening_line()
					if bad.search(line):
						leaks += 1
						print("    sci-fi leak: ", line)
				_check(leaks <= 2, "townsfolk talk like townsfolk (%d/40 leaks)" % leaks)
			amane.notice_rival("Sato Yui", a)
			_check(str(amane.st()["rival"]) == "Sato Yui", "jealousy remembers the rival")
			amane.send("jealous")
			_check(int(amane.st()["unread"]) >= 1, "phone message arrives")
			_check(amane.phone_reply("block").contains("Blocked"), "block")
			var light: Dictionary = clock.light()
			_check(light.has("sun") and float(light.sun_energy) > 0.0, "daylight keys")
			clock.advance(clock.DUSK - clock.minute())
			_check(clock.period() == "Omagatoki" or clock.is_weekend(), "dusk is Omagatoki")
			current_scene.end_day()
			_wait = 120
		4:
			_check(clock.day() == 2, "next day")
			_check(current_scene != null and current_scene.name == "Suzunari", "woke up in Suzunari")
			_check(str(amane.st()["pending"]) == "", "doorstep morning played")
			print("day_test: %d failures" % fails)
			quit(fails)
			return true
	_step += 1
	return false
