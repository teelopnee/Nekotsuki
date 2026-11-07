extends SceneTree
## Ura-Suzunari and the story flow fixes: entering the other side (red dusk, frozen clock, shadows, five echoes,
## Rin, wild kasha), talking to Rin and an echo, the second bell throwing you out a day later, the riverbed visit
## with Sayo and the Kasha Matriarch, walking back down, the free entry at the thousandth step, the story lantern
## marker + distance hint, the weekend menu, missed beats carrying over, endings remembered for the title.
## godot --headless --path . --script res://tools/ura_test.gd   (exit code = failures)

var _step := 0
var _wait := 0
var fails := 0
var _day0 := 0
var _tries := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func _buttons(hud) -> Array:
	var out := []
	for b in hud._dialogue_choices.get_children():
		if not b.is_queued_for_deletion():
			out.append(b)
	return out


func _close_all(hud) -> void:
	for _i in 14:
		if not hud._dialogue_open:
			return
		hud._on_choice("")


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var week = root.get_node("Week")
	var clock = root.get_node("Clock")
	var amane = root.get_node("Amane")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			game.new_game("Ura Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			amane.st()["met"] = true
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(hud)
			_check(lvl.find_child("ThousandthStep", true, false) != null, "the thousandth step is waiting at the top of the 999")
			_flow_checks(week, clock, game, lvl, hud)
			clock.st()["minute"] = 1085
			_day0 = clock.day()
			week.enter_ura("rin")
			_wait = 120
		2:
			_close_all(hud)
			_check(lvl.get("ura") == true and str(lvl.get("ura_goal")) == "rin", "in Ura-Suzunari (goal: the bell)")
			_check(not clock.running, "time stands still on the other side")
			_check(lvl.sun.light_color.r > lvl.sun.light_color.g * 1.8, "the light is red")
			var kasha := 0
			for e in get_nodes_in_group("enemy"):
				if str(e.get("display_name")).contains("Kasha"):
					kasha += 1
			_check(kasha >= 5, "wild kasha hunt here (%d)" % kasha)
			_check(get_nodes_in_group("echo").size() == 5, "five echoes of the past (%d)" % get_nodes_in_group("echo").size())
			var shadows := 0
			for n in get_nodes_in_group("npc"):
				var l = n.get("name_label")
				if l is Label3D and l.text == "a shadow":
					shadows += 1
			_check(shadows >= 5, "the townsfolk are shadows (%d)" % shadows)
			_check(lvl.find_child("Rin", true, false) != null, "Rin hangs in the air")
			var exit_ok := false
			for n in lvl.find_children("*", "Interactable", true, false):
				if str(n.get("prompt")).contains("thousandth step"):
					exit_ok = true
			_check(exit_ok, "the way out down the steps")
			_check(week.objective().contains("bell"), "objective points at the bell")
			lvl._rin_talk(week.ura.goals.rin)
			_check(hud._dialogue_open, "Rin talks")
			_buttons(hud)[0].pressed.emit()
			_close_all(hud)
			_check(bool(game.flags.get("met_rin", false)), "met Rin")
			var echo = get_nodes_in_group("echo")[0]
			echo._on_talk(null)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).length() > 60, "an echo replays the past")
			_buttons(hud)[0].pressed.emit()
			_close_all(hud)
			# Stay too long: the second bell throws you out, a day later.
			lvl._ura_t = lvl.bell_seconds() * 2.0 + 1.0
			lvl._ura_bells = 1
			lvl._ura_process(0.01)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("twice"), "the bell rings twice")
			_close_all(hud)
			_wait = 120
		3:
			_close_all(hud)
			_check(lvl.get("ura") == false and not game.flags.has("in_ura"), "thrown back out")
			_check(clock.day() == _day0 + 1, "a whole day passed outside (day %d -> %d)" % [_day0, clock.day()])
			clock.st()["minute"] = 1085
			game.flags["letter_101"] = true
			week.enter_ura("riverbed")
			_wait = 120
		4:
			_close_all(hud)
			var sayo = null
			for n in get_nodes_in_group("echo"):
				if str(n.get("echo").get("id", "")) == "goal_riverbed":
					sayo = n
			_check(sayo != null, "Sayo is on the dry riverbed")
			var boss := false
			for e in get_nodes_in_group("enemy"):
				if str(e.get("display_name")) == "Kasha Matriarch":
					boss = true
			_check(boss, "the Kasha Matriarch guards the riverbed")
			if sayo:
				sayo._on_talk(null)
				var bs := _buttons(hud)
				_check(bs.size() == 3, "three things to say to her (Letter 101 unlocked)")
				bs[0].pressed.emit()
				_close_all(hud)
			_check(bool(game.flags.get("sayo_found", false)), "found Sayo")
			week.leave_ura(false)
			_wait = 120
		5:
			_close_all(hud)
			_check(lvl.get("ura") == false and clock.minute() >= clock.NIGHT, "walked back down after Omagatoki")
			week.remember_ending("okaeri")
			_check(week.endings_seen().has("okaeri"), "endings are remembered for the title screen")
			# Races: stand on the lantern -> win; stand still while the cat runs -> lose.
			lvl.player.global_position = lvl.builder.center(38, 3) + Vector3(0.5, 0.1, 0.5)
			week.race({"kind": "lantern", "to": [38, 3], "seconds": 1, "ok": {"say": "Made it in time.", "fx": {"flag": "race_won"}},
				"fail": {"say": "Too late.", "fx": {"flag": "race_lost"}}})
			_wait = 10
		6:
			_close_all(hud)
			_check(bool(game.flags.get("race_won", false)), "reaching the lantern in time wins the race")
			lvl.player.global_position = lvl.builder.center(27, 47)
			week.race({"kind": "cat", "seconds": 0.5, "exact": true, "ok": {"say": "Caught it.", "fx": {"flag": "race_won2"}},
				"fail": {"say": "It got away.", "fx": {"flag": "race_lost"}}})
			_wait = 120
		7:
			_close_all(hud)
			_check(bool(game.flags.get("race_lost", false)) and not game.flags.has("race_won2"), "the cat gets away if you don't run")
			# Countdown feel: a race you stand still in ticks, goes urgent in the last seconds, and ends in a loss cue.
			var fx_script = load("res://src/core/fx.gd")
			fx_script.feel_log.clear()
			lvl.player.global_position = lvl.builder.center(27, 47)
			week.race({"kind": "lantern", "to": [38, 3], "seconds": 4.5, "exact": true, "ok": {"say": "-", "fx": {}},
				"fail": {"say": "-", "fx": {}}})
			_wait = 30
		8:
			var log: Array = load("res://src/core/fx.gd").feel_log
			if (log.is_empty() or not log.back() in ["win", "lose"]) and _tries < 2000:
				_tries += 1
				return false  # the countdown is still running
			_close_all(hud)
			_check(log.has("start") and log.has("tick") and log.has("urgent") and log.back() == "lose",
				"countdown: go, ticks, urgent ticks, loss cue %s" % str(log))
			var sfx_ok := true
			for n in ["race_tick", "race_tick_urgent", "race_go", "race_win", "race_lose"]:
				sfx_ok = sfx_ok and ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % n)
			_check(sfx_ok, "countdown sounds exist")
			game.settings["rumble"] = "off"
			_check(not load("res://src/core/fx.gd").rumble_on(), "vibration can be switched off")
			game.settings["rumble"] = true
			_check(load("res://src/core/fx.gd").rumble_on(), "old saves (rumble = true) still vibrate")
			print("ura_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false


func _flow_checks(week, clock, game, lvl, hud) -> void:
	# Marker: day 3 after school, Chiyo is waiting at the shrine.
	clock.st()["day"] = 3
	clock.st()["minute"] = 925
	week.st()["done"].erase("d3_chiyo")
	lvl.player.global_position = lvl.builder.center(27, 47)
	var mk: Array = week.marker()
	_check(not mk.is_empty() and mk[0] == Vector2i(28, 6), "the story marker points at the shrine (%s)" % str(mk))
	lvl._marker_t = 0.0
	lvl._marker_process(0.6)
	_check(lvl._marker != null and lvl._marker.visible, "a lantern floats over the place")
	_check(week.objective().contains(" m)"), "objective shows the way: %s" % week.objective().right(14))
	# Carry-over: the missed beat is still there on day 4.
	clock.st()["day"] = 4
	var ids := []
	for bt in week._candidates():
		ids.append(str(bt.id))
	_check(ids.has("d3_chiyo") and ids.has("d4_dogs"), "a missed beat carries over one day")
	# Weekend menu (Saturday morning at home).
	clock.st()["minute"] = 480
	week.st()["done"]["d3_chiyo"] = 3
	week.today().erase("weekend")
	game.location_id = "suzunari"
	week._check_beats(480)
	_check(hud._dialogue_open and _buttons(hud).size() >= 5, "Saturday: Aunt Haruka asks how you'll spend the day")
	var m0: int = clock.minute()
	for b in _buttons(hud):
		if str(b.text).contains("Sleep"):
			b.pressed.emit()
	_check(clock.minute() >= m0 + 200, "sleeping in costs the morning")
	_close_all(hud)
	clock.st()["day"] = 2

