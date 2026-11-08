extends SceneTree
## A bot that PLAYS the game through the real day flow (not test shortcuts) and writes a transcript of everything said:
##   godot --headless --path . --script res://tools/playbot.gd -- <out_file> [days=7] [seed=1] [policy=random|kind|cold]
## Each day: wake at home, follow the story marker (Week.marker) or wander to people, go into school for lessons, talk
## to Amane now and then, end the day at 21:30 (cat nights end at dawn). Every dialogue is logged once with its
## choices and the pick. The summary at the end counts scenes, repeats, lessons, lates and failures.
## The bot teleports between places (it has no legs), so travel time is not part of the pacing it measures.

var out_path := "user://playbot.txt"
var days := 7
var policy := "random"
var rng := RandomNumberGenerator.new()
var lines: PackedStringArray = []
var _step := 0
var _wait := 0
var _last_text := ""
var _seen := {}
var _repeats := 0
var _dialogues := 0
var _per_day := {}
var _last_talk := -999
var _last_wander := -999
var _busy_frames := 0
var _start_ms := 0
var _ended := ""
var _stuck := 0
var _club := ""
var _club_day := -1


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_path = a[0]
	if a.size() > 1:
		days = int(a[1])
	rng.seed = int(a[2]) if a.size() > 2 else 1
	if a.size() > 3:
		policy = a[3]


func _log(s: String) -> void:
	lines.append(s)


func _clock() -> String:
	var c = root.get_node("Clock")
	var m := int(c.minute())
	return "D%d %s %02d:%02d" % [int(c.day()), str(c.weekday()), m / 60, m % 60]


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var clock = root.get_node("Clock")
	var week = root.get_node("Week")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			var toru = root.get_node("Toru")
			var tags := {}
			for c in toru.categories():
				var opts: Array = c.get("options", [])
				tags[str(c.id)] = str(opts[rng.randi() % opts.size()].id)
			var clubs: Array = toru.clubs.get("clubs", {}).keys()
			_club = str(clubs[rng.randi() % clubs.size()])
			_log("NEW GAME  tags: %s  policy: %s  club: %s" % [str(tags), policy, _club])
			root.get_node("Router").new_suzunari("Toru", tags)
			_start_ms = Time.get_ticks_msec()
			_step = 1
			_wait = 90
			return false
		1:
			if lvl == null or hud == null:
				_stuck += 1
				if _stuck > 600:
					_finish("no level (%s)" % [str(lvl.name) if lvl else "none"])
				return false
			_stuck = 0
			if game.flags.has("ending"):
				_ended = str(game.flags["ending"])
			if int(clock.day()) > days or _ended != "":
				_finish("done")
				return true
			clock.rate = 8.0  # 8 game minutes per real second: a school day is ~2 real minutes
			if hud._dialogue_open:
				_answer(hud)
				return false
			_busy_frames = 0
			_act(lvl, hud, game, clock, week)
	return false


func _answer(hud) -> void:
	_busy_frames += 1
	var text := str(hud._dialogue_text.text)
	var buttons := []
	for b in hud._dialogue_choices.get_children():
		if b is Button and not b.is_queued_for_deletion():
			buttons.append(b)
	if text != _last_text:
		_last_text = text
		_dialogues += 1
		var day := str(root.get_node("Clock").day())
		_per_day[day] = int(_per_day.get(day, 0)) + 1
		var key := text.substr(0, 120)
		if _seen.has(key):
			_repeats += 1
		_seen[key] = true
		var who := str(hud._dialogue_speaker.text) if hud.get("_dialogue_speaker") != null else ""
		_log("[%s] %s%s" % [_clock(), (who + ": ") if who != "" else "", text.replace("\n", " / ")])
		if buttons.size() > 1:
			var opts := []
			for b in buttons:
				opts.append(str(b.text).trim_prefix("> ") + (" (x)" if b.disabled else ""))
			_log("      choices: " + " | ".join(PackedStringArray(opts)))
		_wait = 2
		return
	var open := buttons.filter(func(b): return not b.disabled)
	if open.is_empty():
		hud._on_choice("")
		return
	var pick = open[rng.randi() % open.size()]
	if policy == "kind" or policy == "cold":
		for b in open:
			var t := str(b.text).to_lower()
			if policy == "kind" and (t.contains("kind") or t.contains("thank") or t.contains("together") or t.contains("i'll come")):
				pick = b
				break
			if policy == "cold" and (t.contains("leave me alone") or t.contains("annoying") or t.contains("go away")):
				pick = b
				break
	if buttons.size() > 1:
		_log("      -> " + str(pick.text).trim_prefix("> "))
	pick.pressed.emit()
	if _busy_frames > 400:
		hud._on_choice("")  # a modal that never closes: push through it
	_wait = 1


func _act(lvl, hud, game, clock, week) -> void:
	var m: int = clock.minute()
	var t_abs: int = int(clock.day()) * 1440 + m  # cooldowns across days
	var loc := str(game.location_id)
	# Cat night: the bot is the cat; let it end at dawn.
	if lvl.get("cat_night") == true:
		if lvl.has_method("finish_cat_night"):
			_log("[%s] (cat night: the bot sits on a roof until dawn)" % _clock())
			lvl.finish_cat_night("dawn")
			_wait = 120
		return
	if lvl.get("ura") == true:
		if lvl.has_method("_thrown_out"):
			_log("[%s] (Ura-Suzunari: the bot waits for the second bell)" % _clock())
			lvl._thrown_out()
			_wait = 120
		return
	if m >= 1290:
		_log("[%s] (end of day)" % _clock())
		lvl.end_day()
		_wait = 150
		return
	var player = lvl.get("player")
	if player == null:
		return
	if loc == "suzunari":
		var lesson_soon: bool = week.block(m) != "" or (m >= 495 and m < 510) or (m >= 780 and m < 800)
		var b: String = week.block(m + 15)
		if lesson_soon and b != "" and not week.today().has("lesson_" + b) and not week.free_day():
			_log("[%s] (goes into school)" % _clock())
			lvl.enter_school([11, 28])
			_wait = 120
			return
		var mk: Array = week.marker()
		if not mk.is_empty():
			var t: Vector2i = mk[0]
			var to: Vector3 = lvl.builder.center(t.x, t.y) + Vector3(0.6, 0.1, 0.6)
			if player.global_position.distance_to(to) > 3.0:
				_log("[%s] (walks to the marker: %s at %s)" % [_clock(), str(mk[1]), str(t)])
				player.global_position = to
				return
		elif _club_time(clock):
			return
		elif t_abs - _last_wander > 60:
			_last_wander = t_abs
			var people := get_nodes_in_group("npc").filter(func(n): return n.visible and n != lvl.get("amane") and n.has_method("_on_talk"))
			if not people.is_empty():
				var n = people[rng.randi() % people.size()]
				player.global_position = n.global_position + Vector3(1.2, 0, 0.8)
				_log("[%s] (talks to %s)" % [_clock(), str(n.get("npc_name"))])
				n._on_talk(player)
				return
	elif loc == "school":
		if _club_time(clock):
			return
		var b: String = week.block(m)
		var due_here := false
		for bt in week._candidates():
			if str(bt.get("where", "")) == "school" and m >= int(bt.get("after", 0)) - 30 and (not bt.has("before") or m < int(bt["before"])):
				due_here = true
		if due_here and m < 1080:
			return  # a scene is due in the school: stay (a player would read the objective line)
		if b == "" and week.block(m + 20) == "" and (m >= 920 or m < 500):
			_log("[%s] (leaves school)" % _clock())
			lvl.leave()
			_wait = 120
			return
	# Talk to Amane now and then (every ~2 game hours), the way a player would.
	var am = lvl.get("amane")
	if am != null and is_instance_valid(am) and am.visible and t_abs - _last_talk > 120:
		_last_talk = t_abs
		player.global_position = am.global_position + Vector3(1.0, 0, 0.6)
		_log("[%s] (talks to Amane)" % _clock())
		root.get_node("Amane").converse(am, hud)


## After school on a day the club meets: go to it (join on the first visit, then practise).
func _club_time(clock) -> bool:
	var toru = root.get_node("Toru")
	if _club == "" or _club_day == int(clock.day()) or not toru.club_open(_club):
		return false
	_club_day = int(clock.day())
	_log("[%s] (goes to the %s)" % [_clock(), str(toru.club_data(_club).get("name", _club))])
	toru.use_club(_club, current_scene.get("hud"))
	return true


func _finish(why: String) -> void:
	var real := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var w = root.get_node("Week")
	var s: Dictionary = w.st()
	_log("")
	_log("== SUMMARY (%s)" % why)
	_log("days played: %d   dialogues: %d   repeated texts: %d   ending: %s" % [int(root.get_node("Clock").day()) - 1, _dialogues, _repeats, _ended if _ended != "" else "-"])
	_log("per day: %s" % str(_per_day))
	_log("lessons studied %d  late %d  absent %d" % [int(s.get("study", 0)), int(s.get("late", 0)), int(s.get("truant", 0))])
	_log("beats done: %d   Amane route %s, bond %d, tears %d" % [(s.get("done", {}) as Dictionary).size(), root.get_node("Amane").route(),
		int(float(root.get_node("Amane").st()["bond_now"])), root.get_node("Amane").tears_level()])
	_log("real time %.0f s" % real)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	print("playbot: %s -> %s (%d dialogues)" % [why, out_path, _dialogues])
	quit(0)
