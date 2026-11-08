extends SceneTree
## Every verb x {success, fail}: the NPC must ANSWER BACK (a counter-move with choices) and something
## must CHANGE (reaction, label, attitude, memory). Then every counter choice and every approach
## ("they come to you") scene is played once. Exit code = failures.
##   godot --headless --path . --script res://tools/interact_back_test.gd

var _step := 0
var _wait := 0
var _fails := 0
var _last: Array = []  # [speaker, text, choices, callback]


var _approach_polls := 0

func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			var tags := {"class": "heir_lumen", "age": "young", "background": "influencer", "personality": "charming",
				"motivation": "get_famous", "secret": "compulsive_liar"}
			root.get_node("Game").new_game("Echo Tester", tags, 99)
			var g = root.get_node("Game")
			root.get_node("Router").params = {"planet_id": g.galaxy[1].id}
			change_scene_to_file("res://scenes/world/planet_surface.tscn")
			_step = 1
			_wait = 200
		1:
			root.get_node("EventBus").dialogue_requested.connect(func(s, t, c, cb): _last = [s, t, c, cb])
			_close()
			_verbs()
			_counters()
			_step = 2
		2:
			_approaches_start()
			_step = 3
			_wait = 200
		3:
			# Still walking over. Poll on the NPC's own clock (it talks from where it is when its 9 s run out), not a
			# frame count: headless frames run faster than physics ticks, so 600 frames was sometimes only ~1 s of NPC time.
			if _approachers[0].state == "approach" and _approachers[0]._approach_time > -1.0 and _approach_polls < 6000:
				_approach_polls += 1
				# Another modal (e.g. a FLAW & PERK offer after the theft verbs) pauses the tree and freezes the walk.
				var hud = get_first_node_in_group("hud")
				if hud != null and bool(hud.get("_dialogue_open")) and _last.is_empty():
					hud._on_choice("")
				return false
			_approaches_check()
			print("\nINTERACT-BACK TEST DONE - %d failures" % _fails)
			quit(_fails)
	return false


func _close() -> void:
	var hud = get_first_node_in_group("hud")
	for i in 16:
		if hud and hud._dialogue_open:
			hud._on_choice("")
	paused = false


func _fresh_npc():
	var list := get_nodes_in_group("npc").filter(func(n): return n.role == "civilian" and n.state != "dead" and n.story_id == "" \
		and n.persona_id == "" and not n.get("_leaving"))
	return list[randi() % list.size()] if not list.is_empty() else null


func _sig(n) -> String:
	if not is_instance_valid(n):
		return "gone"
	return "%d|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [n.attitude, n.relation_label(), n.owes_favour, n.grudge, n.robbed, n.fan, n.heckler,
		n._approach_kind, n._follow_kind, n.state]


func _verbs() -> void:
	print("\n== every verb, both outcomes")
	var inter = root.get_node("Interactions")
	var game = root.get_node("Game")
	var player = get_first_node_in_group("player")
	var no_counter := []
	var no_change := []
	var n_ok := 0
	for id in inter.verbs():
		for outcome in [true, false]:
			var d: Dictionary = inter.verbs()[id]
			if not outcome and not d.has("fail"):
				continue
			var npc = _fresh_npc()
			if npc == null:
				continue
			game.credits = 9999
			_reset(npc)
			player.global_position = npc.global_position + Vector3(1.5, 0, 0)
			var before := _sig(npc)
			inter.force_outcome = outcome
			_last = []
			inter.resolve(npc, id)
			inter.force_outcome = null
			var after := _sig(npc)
			var answered: bool = not _last.is_empty() and (_last[2] as Array).size() >= 2
			if not answered:
				no_counter.append("%s/%s" % [id, "ok" if outcome else "fail"])
			if before == after:
				no_change.append("%s/%s" % [id, "ok" if outcome else "fail"])
			n_ok += 1
			_close()
	print("  outcomes played: %d" % n_ok)
	_check(no_counter.is_empty(), "NPC answers back after every outcome %s" % str(no_counter))
	_check(no_change.is_empty(), "every outcome changes something %s" % str(no_change))


func _counters() -> void:
	print("\n== every counter choice")
	var inter = root.get_node("Interactions")
	var game = root.get_node("Game")
	var n := 0
	for table in ["counters", "approach"]:
		var t: Dictionary = root.get_node("DataDB").counters.get(table, {})
		for key in t:
			for tpl in t[key]:
				for i in (tpl.choices as Array).size():
					for outcome in [true, false]:
						var npc = _fresh_npc()
						if npc == null:
							continue
						game.credits = 9999
						inter.force_outcome = outcome
						_last = []
						inter._on_counter_choice("c%d" % i, npc, tpl)
						inter.force_outcome = null
						if _last.is_empty() or _unfilled.search(str(_last[1])):
							_check(false, "%s/%s choice %d produced: %s" % [table, key, i, str(_last)])
						n += 1
						_close()
	print("  counter choices played: %d" % n)


var _approachers: Array = []
var _unfilled := RegEx.create_from_string("\\{[a-z_]+\\}|#[a-z_]+#")


func _reset(n) -> void:
	for f in ["owes_favour", "grudge", "robbed", "robbed_noticed", "fan", "heckler", "partner", "pity", "loyal", "repossessed"]:
		n.set(f, false)
	for f in ["cold_until", "spooked_until", "scared_until", "_follow_time"]:
		n.set(f, 0.0)
	n._approach_kind = ""
	n._follow_kind = ""
	n.memories.clear()
	n.state = "idle"
	n.activity = ""
	n.attitude = 0


func _approaches_start() -> void:
	print("\n== they come to you")
	var player = get_first_node_in_group("player")
	var kinds: Array = root.get_node("DataDB").counters.get("approach", {}).keys()
	var npc = _fresh_npc()
	_reset(npc)
	player.global_position = npc.global_position + Vector3(4.0, 0, 0)
	for e in get_nodes_in_group("enemy"):
		e.hostile = false
	npc._schedule_approach(kinds[0], 0.01)
	npc.set("_last_approach", -999.0)
	_approachers = [npc, kinds]
	_last = []


## What froze the walk-over, if anything (diagnostics for the failure message).
func _blocker() -> String:
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	var t := ""
	if hud != null and bool(hud.get("_dialogue_open")):
		t = str(hud._dialogue_text.text).substr(0, 60)
	return " paused=%s dialogue=%s level=%s" % [str(paused), t, str(lvl.name) if lvl else "?"]


func _approaches_check() -> void:
	var npc = _approachers[0]
	var got: bool = not _last.is_empty() and (_last[2] as Array).size() >= 2
	_check(got, "an NPC walked up and started a conversation (%s)" % (_last[1].substr(0, 70) if got else "none: state=%s kind=%s wait=%.2f d=%.1f t=%.2f stuck=%.2f polls=%d" % [
		npc.state, npc._approach_kind, npc._approach_wait, npc.global_position.distance_to(get_first_node_in_group("player").global_position),
		npc._approach_time, npc._approach_stuck, _approach_polls]) + _blocker())
	_close()
	# Play each approach scene directly too.
	var inter = root.get_node("Interactions")
	for k in _approachers[1]:
		_last = []
		inter.present_counter(_fresh_npc(), k, "", "approach")
		_check(not _last.is_empty(), "approach '%s' opens a scene" % k)
		_close()


func _check(cond: bool, what: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
