extends SceneTree
## M4 words & world: Amane's topic talks (every topic x every exact reply), the Town's landmarks, lore signs,
## spirits/yokai scenes (every choice), the Notes codex and data integrity (lore titles, eggs, zukan).
## godot --headless --path . --script res://tools/talk_test.gd   (exit code = failures)

const LEAKS := ["credit", "paragon", "planet", "consortium", "station", "corp", "neon", "drone", "{", "#"]

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


func _press(hud, i: int) -> bool:
	var bs := _buttons(hud)
	if i >= bs.size() or not hud._dialogue_open:
		return false
	bs[i].pressed.emit()
	return true


func _close_all(hud) -> void:
	for _i in 12:
		if not hud._dialogue_open:
			return
		hud._on_choice("")


func _leaky(t: String) -> String:
	var low := t.to_lower()
	for w in LEAKS:
		if w == "station" and low.contains("station"):
			continue  # Suzunari has a train station
		if low.contains(w):
			return w
	return ""


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var amane = root.get_node("Amane")
	var town = root.get_node("Town")
	var clock = root.get_node("Clock")
	match _step:
		0:
			game.new_game("Talk Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			var hud = current_scene.get("hud")
			_close_all(hud)
			amane.st()["met"] = true
			_data_checks(amane, town)
			_world_checks(town)
			_amane_answers(amane)
		2:
			var hud = current_scene.get("hud")
			_close_all(hud)
			# A real conversation through the HUD: topic -> exact words -> answer -> bye.
			var a = get_first_node_in_group("amane")
			amane.st()["topics_today"] = []
			amane.converse(a, hud)
			var opened: bool = hud._dialogue_open
			var n_topics := _buttons(hud).size()
			_check(opened and n_topics >= 2 and n_topics <= 5, "talk opens with topics + bye (%d)" % n_topics)
			_press(hud, 0)
			var n_replies := _buttons(hud).size()
			_check(n_replies >= 3, "a topic offers exact words to pick (%d)" % n_replies)
			_press(hud, 1)
			_check(str(hud._dialogue_text.text).contains("> Tears"), "his answer shows what changed")
			_check((amane.st()["topics_today"] as Array).size() == 1, "topic remembered for today")
			_press(hud, _buttons(hud).size() - 1)  # bye
			_close_all(hud)
		3:
			var hud = current_scene.get("hud")
			_spirit_scenes(town, clock, hud)
		4:
			var hud = current_scene.get("hud")
			_landmarks(town, hud, game)
		5:
			var c: Dictionary = town.codex()
			_check(c.lore.size() >= 20, "Notes remember lore (%d)" % c.lore.size())
			_check(c.places.size() >= 15, "Notes list places (%d)" % c.places.size())
			_check(c.people.size() == town.data.spirits.size(), "Notes list everyone met (%d)" % c.people.size())
			_check(c.zukan.filter(func(z): return z != "???").size() >= 7, "Hyakki Zukan pages filled")
			_check(int(c.eggs) >= 10, "Easter eggs found (%d / %d)" % [c.eggs, c.eggs_total])
			var ov = current_scene.get("overlay")
			ov._tab = 2
			ov.open_phone()
			_check(str(ov._log.text).contains("HYAKKI ZUKAN"), "phone Notes tab shows the codex")
			ov.close_phone()
			print("talk_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false


func _data_checks(amane, town) -> void:
	var titles: Dictionary = town.data.get("lore_titles", {})
	var missing := []
	for id in amane.talk.get("topics", {}):
		var t: Dictionary = amane.talk.topics[id]
		for r in t.get("replies", []):
			if r.has("lore") and not titles.has(str(r.lore)):
				missing.append(str(r.lore))
			for k in ["lore", "no_lore"]:
				if r.get("when", {}).has(k) and not titles.has(str(r.when[k])):
					missing.append(str(r.when[k]))
		for k in ["lore", "no_lore"]:
			if t.get("when", {}).has(k) and not titles.has(str(t.when[k])):
				missing.append(str(t.when[k]))
	var eggs: Dictionary = town.data.get("eggs", {})
	var scenes := []
	for sp in town.data.spirits:
		scenes.append_array(sp.choices)
	for k in town.data.landmarks:
		var e = town.data.landmarks[k]
		if e is Dictionary:
			scenes.append_array(e.get("choices", []))
	for c in scenes:
		var fx: Dictionary = c.get("fx", {})
		if fx.has("lore") and not titles.has(str(fx.lore)):
			missing.append(str(fx.lore))
		if fx.has("egg") and not eggs.has(str(fx.egg)):
			missing.append("egg " + str(fx.egg))
		if fx.has("zukan") and not town.ZUKAN.has(str(fx.zukan)):
			missing.append("zukan " + str(fx.zukan))
	for lp in town.data.lore_points:
		if lp.has("lore") and not titles.has(str(lp.lore)):
			missing.append(str(lp.lore))
		if lp.has("egg") and not eggs.has(str(lp.egg)):
			missing.append("egg " + str(lp.egg))
	_check(missing.is_empty(), "every lore / egg / zukan id is defined %s" % str(missing))
	var n_topics: int = amane.talk.topics.size()
	var n_replies := 0
	for id in amane.talk.topics:
		n_replies += (amane.talk.topics[id].get("replies", []) as Array).size()
	_check(n_topics >= 15 and n_replies >= 75, "Amane: %d topics, %d exact replies" % [n_topics, n_replies])
	for kind in ["torii", "torii_steps", "torii_dog", "hall", "hall_dog", "offering", "offering_dog", "komaneko",
			"komainu", "ema", "chozuya"]:
		if town.landmark(kind).is_empty():
			missing.append(kind)
	_check(missing.is_empty() and town.data.landmarks.jizo.size() == 6, "every landmark kind has lore")


func _world_checks(town) -> void:
	var signs := 0
	var prompts := {}
	for n in current_scene.find_children("*", "Interactable", true, false):
		var p := str(n.get("prompt"))
		if p.begins_with("Read: "):
			signs += 1
		prompts[p] = int(prompts.get(p, 0)) + 1
	_check(signs == town.data.lore_points.size(), "lore signs in town (%d)" % signs)
	_check(int(prompts.get("Pray to the Jizo (save)", 0)) == 6, "six Jizo at the crossroads")
	for p in ["Look at the torii", "Look at the hall", "Ring the bell", "Look at the guardian", "Read the wooden wishes", "Purify your hands"]:
		_check(prompts.has(p), "landmark: " + p)
	var outdoor: int = town.data.spirits.filter(func(sp): return not sp.has("indoor")).size()
	_check(get_nodes_in_group("spirit").size() == outdoor, "spirits & yokai placed outdoors (%d / %d)" % [get_nodes_in_group("spirit").size(), outdoor])


func _amane_answers(amane) -> void:
	var leaks := []
	var empty := 0
	var s: Dictionary = amane.st()
	var keep: Dictionary = s.duplicate(true)
	for id in amane.talk.topics:
		var replies: Array = amane.talk.topics[id].get("replies", [])
		for i in replies.size():
			var r: Dictionary = amane.answer(id, i)
			var t := str(r.text)
			if t.split("\n")[0].strip_edges() in ["", "..."]:
				empty += 1
			var w := _leaky(t.split("\n> ")[0])
			if w != "":
				leaks.append("%s/%d:%s" % [id, i, w])
			if amane.tears_level() >= 4:
				amane.set_tears(1.0)
	_check(empty == 0, "every reply gets an answer")
	_check(leaks.is_empty(), "no sci-fi leaks in Amane's answers %s" % str(leaks))
	# Cold words shrink as he cries; kind ones grow.
	amane.set_tears(4.2)
	var cold_scale := 1.0
	for c in amane.reply_choices("food"):
		if c.has("scale") and float(c.scale) < cold_scale:
			cold_scale = float(c.scale)
	_check(cold_scale < 0.7, "cold words shrink when he cries (%.2f)" % cold_scale)
	for k in keep:
		s[k] = keep[k]


func _spirit_scenes(town, clock, hud) -> void:
	var total := 0
	var bad := []
	for sp in town.data.spirits:
		var hours: Array = sp.hours[0]
		_check(town.present(sp, int(hours[0])) and not town.present(sp, int(hours[0]) - 1 if int(hours[0]) > 0 else 1400),
			"%s keeps hours" % sp.name)
		for i in (sp.choices as Array).size():
			town.st()["today"] = []
			_close_all(hud)
			town.meet(str(sp.id))
			if not _press(hud, i):
				bad.append("%s/%d no menu" % [sp.id, i])
				continue
			var t := str(hud._dialogue_text.text)
			if t.strip_edges() == "" or _leaky(t.split("\n> ")[0]) != "":
				bad.append("%s/%d" % [sp.id, i])
			total += 1
			_close_all(hud)
		town.meet(str(sp.id))  # second time today: short "again" line, no menu (except People's: schedules, walk home)
		if _buttons(hud).size() > 1 + root.get_node("People").menu_items(str(sp.id)).size():
			bad.append("%s again" % sp.id)
		_close_all(hud)
	_check(bad.is_empty() and total >= 40, "every spirit choice plays (%d) %s" % [total, str(bad)])


func _landmarks(town, hud, game) -> void:
	var kinds := ["torii", "torii_steps", "torii_dog", "hall", "hall_dog", "offering", "offering_dog", "komaneko",
		"komainu", "ema", "chozuya"]
	for kind in kinds:
		var e: Dictionary = town.landmark(kind)
		var n: int = maxi(1, (e.get("choices", []) as Array).size())
		for i in n:
			_close_all(hud)
			town.examine(kind)
			if e.has("choices"):
				_press(hud, i)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).length() > 30, "examine %s%s" % [kind, " #%d" % i if n > 1 else ""])
	_close_all(hud)
	for i in 6:
		town.examine("jizo", i)
		_close_all(hud)
	_check(town.st()["eggs"].has("six_jizo"), "praying to all six Jizo finds an egg")
	_check(FileAccess.file_exists("user://save_0.json") or DirAccess.get_files_at("user://").size() > 0, "Jizo saved the game")
	for lp in town.data.lore_points:
		town.read_point(str(lp.id))
		_close_all(hud)
	var ema: String = town.landmark_text("ema")
	_check(ema.count("\"") >= 6 and not ema.contains("#"), "ema boards show three wishes")
