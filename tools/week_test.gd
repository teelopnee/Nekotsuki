extends SceneTree
## School days and week 1 (Week autoload): a lesson is one event that jumps the clock, late after 8:30, absent
## when in town during class, every week-1 beat plays every choice (incl. the Sunday route question and the
## day-7 fallback text), the week closes with a summary + hook on day 7, Amane's topics don't repeat (once-only
## beats, "you asked yesterday"), reply order changes, talks cost time.
## godot --headless --path . --script res://tools/week_test.gd   (exit code = failures)

var _step := 0
var _wait := 0
var fails := 0


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
	var town = root.get_node("Town")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			game.new_game("Week Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(hud)
			clock.running = false
			_data_checks(week, town, amane)
			# Lessons: in school at 8:30 -> one event -> 12:30.
			game.location_id = "school"
			clock.st()["minute"] = 510
			week._on_minute(510)
			_check(hud._dialogue_open and _buttons(hud).size() == 4, "homeroom starts a lesson event with 4 choices")
			_buttons(hud)[0].pressed.emit()
			_check(clock.minute() == 750 and int(week.st()["study"]) == 1, "paying attention: studied, clock jumps to lunch (%d)" % clock.minute())
			_close_all(hud)
			# Late for the afternoon block.
			clock.st()["minute"] = 812
			week._on_minute(812)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).to_lower().contains("late"), "arriving 12 minutes into a block = late")
			_buttons(hud)[3].pressed.emit()
			_check(int(week.st()["late"]) == 1 and clock.minute() == 920, "late mark counted, afternoon over")
			_close_all(hud)
			# Absent: next day, in town during class.
			clock.next_day()
			game.location_id = "suzunari"
			var posts: int = (amane.st()["ura"] as Array).size()
			clock.st()["minute"] = 530
			week._on_minute(530)
			_check(int(week.st()["truant"]) == 1 and (amane.st()["ura"] as Array).size() == posts + 1, "in town 20 minutes into class = absent + Ura board post")
			_check(not hud._dialogue_open, "absence is a toast, not a modal")
			week._on_minute(531)
			_check(int(week.st()["truant"]) == 1, "one absence per block")
			_beats(week, clock, amane, game, lvl, hud)
			# Night of day 2 with 2 absences: Haruka hears about it.
			week.st()["truant"] = 2
			week.before_day_end(hud)
			_check(hud._dialogue_open, "two absences reach Aunt Haruka at night")
			_close_all(hud)
			# Week close on day 7.
			clock.st()["day"] = 7
			amane.st()["met"] = true
			week.before_day_end(hud)
			var t: String = str(hud._dialogue_text.text)
			_check(t.contains("WEEK 1") and t.contains("Amane:") and t.contains("Closest"), "day 7 closes week 1 with a summary")
			hud._on_choice("")
			_check(str(hud._dialogue_text.text).contains("WEEK 2"), "and a hook for week 2")
			_close_all(hud)
			_check((week.st()["closed"] as Array).has(1), "week 1 marked closed")
			week.before_day_end(hud)
			_check(not hud._dialogue_open, "it closes once")
			_topics(amane, clock, hud)
			# A talk costs time.
			clock.running = true
			clock.st()["minute"] = 930
			town.st()["today"] = []
			town.meet("tanuki")
			_close_all(hud)
			_check(clock.minute() >= 940, "a conversation costs 10 minutes (%d)" % clock.minute())
			clock.running = false
			print("week_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false


func _data_checks(week, town, amane) -> void:
	var missing := []
	var titles: Dictionary = town.data.get("lore_titles", {})
	for d in week.week1.days:
		for bt in week.week1.days[d].get("beats", []):
			for c in bt.get("choices", []):
				var fx: Dictionary = c.get("fx", {})
				if fx.has("lore") and not titles.has(str(fx.lore)):
					missing.append(str(fx.lore))
				if fx.has("egg") and not town.data.eggs.has(str(fx.egg)):
					missing.append("egg " + str(fx.egg))
				if fx.has("zukan") and not town.ZUKAN.has(str(fx.zukan)):
					missing.append("zukan " + str(fx.zukan))
	_check(missing.is_empty(), "week 1 lore / eggs / zukan exist %s" % str(missing))
	_check(week.week1.days.size() == 7, "seven days of week 1")
	for wd in ["Mon", "Tue", "Wed", "Thu", "Fri"]:
		_check((week.lessons.subjects.get(wd, []) as Array).size() == 2, "%s has two lesson blocks" % wd)


func _beats(week, clock, amane, game, lvl, hud) -> void:
	amane.st()["met"] = true
	var played := 0
	var bad := []
	for d in week.week1.days:
		for bt in week.week1.days[d].get("beats", []):
			for i in (bt.get("choices", []) as Array).size():
				clock.st()["day"] = int(d)
				var route_before: String = amane.route()
				week.st()["done"].erase(str(bt.id))
				town_picked_reset(bt)
				var where := str(bt.get("where", "any"))
				game.location_id = "school" if where == "school" else "suzunari"
				clock.st()["minute"] = int(bt.get("after", 450))
				if bt.has("near"):
					var n: Array = bt["near"]
					lvl.player.global_position = lvl.builder.center(int(n[0]), int(n[1])) + Vector3(0, 0.1, 0)
				week.today()["lesson_am"] = true
				week.today()["lesson_pm"] = true
				week._check_beats(clock.minute())
				if not hud._dialogue_open or i >= _buttons(hud).size():
					bad.append("%s/%d" % [bt.id, i])
					_close_all(hud)
					continue
				_buttons(hud)[i].pressed.emit()
				if str(hud._dialogue_text.text).strip_edges().length() < 20:
					bad.append("%s/%d text" % [bt.id, i])
				played += 1
				_close_all(hud)
				if str(bt.id) == "d5_question" and i == 1:
					_check(amane.route() == "romance", "Sunday's question sets the route (flirt -> romance, was %s)" % route_before)
	_check(bad.is_empty() and played >= 25, "every week-1 beat choice plays (%d) %s" % [played, str(bad)])
	# Fallback: Sunday's question finds you anywhere once Omagatoki has passed.
	week.st()["done"].erase("d5_question")
	clock.st()["day"] = 5
	clock.st()["minute"] = 1150
	lvl.player.global_position = lvl.builder.center(27, 47)
	week._check_beats(1150)
	_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("What am I to you"), "Sunday's question comes to you if you missed it")
	_close_all(hud)
	clock.st()["day"] = 2


func town_picked_reset(bt: Dictionary) -> void:
	root.get_node("Town").st()["picked"].erase("wk_" + str(bt.id))


func _topics(amane, clock, hud) -> void:
	var s: Dictionary = amane.st()
	s["topics_today"] = []
	s["topics_seen"] = {"mother": 1, "food": clock.day() - 1}
	var ids := []
	for c in amane.topic_choices():
		ids.append(str(c.id))
	_check(not ids.has("mother"), "once-only topics don't come back")
	_check(not ids.has("food"), "everyday topics rest for a few days")
	s["topics_seen"]["food"] = clock.day() - 1
	clock.st()["day"] = clock.day() + 3
	var again: String = amane.asked_before("food")
	_check(again != "" and not again.contains("{"), "asked again: \"%s\"" % again.left(60))
	var orders := {}
	for d in 6:
		clock.st()["day"] = 10 + d
		var o := []
		for c in amane.reply_choices("food"):
			o.append(str(c.id))
		orders[str(o)] = true
	_check(orders.size() >= 3, "reply order changes from day to day (%d orders in 6 days)" % orders.size())
	amane.set_tears(0.0)
	var scaled := false
	for c in amane.reply_choices("food"):
		if c.has("scale"):
			scaled = true
	_check(not scaled, "calm: every reply is the same size")
