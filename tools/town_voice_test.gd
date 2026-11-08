extends SceneTree
## Runtime voice check for Suzunari (docs/REVIEW.md third review #1): leak_check.py reads the data files, but most of
## what townsfolk say is COMPOSED while you play (Copy grammar, rumours, the saga, the generated galaxy, NPC memory).
## This loads the town, makes every townsperson talk through the real generators many times, and scans the result:
##   godot --headless --path . --script res://tools/town_voice_test.gd -- [samples_file]
## Exit code = lines with a leak (sci-fi words, galaxy / faction / saga names, non-Japanese names, placeholders,
## broken grammar). "tone" lines (billing / repossession satire) are reported too, and fail when there are too many.

var _step := 0
var _wait := 0
var _lines: Array = []  # [source, text]
var _rng := RandomNumberGenerator.new()
var _fails := 0
var _got := []


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			root.get_node("Router").new_suzunari("Toru", {})
			_wait = 120
		1:
			_harvest()
			_scan()
			quit(_fails)
			return true
	_step += 1
	return false


func _add(src: String, t) -> void:
	var s := str(t)
	if s.strip_edges() != "":
		_lines.append([src, s])


func _harvest() -> void:
	_rng.seed = 7
	var bus = root.get_node("EventBus")
	bus.dialogue_requested.connect(func(s, t, c, cb): _got.append([str(s), str(t), c]))
	bus.speech_bubble.connect(func(_n, t): _got.append(["bubble", str(t), []]))
	var inter = root.get_node("Interactions")
	var voice = load("res://src/core/npc_voice.gd")
	var copy = load("res://src/core/copy.gd")
	var lvl = current_scene
	var hud = lvl.get("hud")
	var people := get_nodes_in_group("npc").filter(func(n): return n.has_method("_opening_line") and n != lvl.get("amane") \
		and not n.is_in_group("cat") and str(n.get("role")) in ["civilian", "merchant", "keeper", ""])
	print("town_voice_test: %d townspeople" % people.size())
	# Things the town can know about you: a theft, a kindness, a fight.
	var causality = root.get_node("Causality")
	causality.record("theft", {"target": "a shop", "target_faction": "", "position": Vector3.ZERO})
	for kind in ["theft", "charity", "threat", "show"]:
		voice.add_street_memory(kind)
	for n in people.slice(0, 24):
		for i in 6:
			_add("opening", n._opening_line())
		for i in 3:
			_add("remark", voice.remark(n, _rng))
			_add("remark_bubble", voice.remark(n, _rng, true))
			_add("greeting", inter.greeting(n))
			_add("gossip", voice.gossip(n, _rng))
		for i in 6:
			_add("rumour", inter.rumor(n))
		var b: Dictionary = n.barks()
		for k in ["civilian", "merchant", "pair", "infamous"]:
			for l in b.get(k, []):
				_add("bark_" + k, l)
	# Talk menus and verbs, every outcome (the dialogue boxes they open are collected, then closed).
	for n in people.slice(0, 10):
		_got.clear()
		n._talk_civilian()
		_close(hud)
		for g in _got:
			_add("talk_open", g[1])
		var choices: Array = inter.choices_for(n, "civilian")
		for c in choices:
			var id := str(c.get("id", ""))
			if not id.begins_with("act:"):
				continue
			for ok in [true, false]:
				_got.clear()
				inter.force_outcome = ok
				inter.resolve(n, id.substr(4))
				_close(hud)
				for g in _got:
					_add("verb_" + id.substr(4), g[1])
					for ch in g[2]:
						_add("verb_choice", ch.get("text", ""))
		inter.force_outcome = null
	for i in 30:
		_add("chatter", copy.make("chatter", _rng))
	var enc = root.get_node("Encounters")
	for fid in ["paragon", "halcyon", "lumen", "gristle", "oxy", "consortium"]:  # what a verb prints when it moves a reputation
		for l in enc.apply_effects({"rep": {fid: -1}, "bounty": {fid: 1}, "credits": 3}):
			_add("effect", l)
	for h in causality.latest_headlines(5):
		_add("headline", h)
	if hud:  # what the ticker really shows (in Suzunari it writes fresh town news, not the ODD-SPACE ad list)
		for i in 30:
			hud._next_ticker()
			_add("ticker", hud._ticker_label.text)
	print("town_voice_test: %d lines harvested" % _lines.size())


func _close(hud) -> void:
	for i in 12:
		if hud and hud._dialogue_open:
			hud._on_choice("")


func _scan() -> void:
	var words := RegEx.create_from_string("(?i)\\b(credits?|paragon|planets?|consortium|corp|corporate|neon|drones?|ad network|ads?|ad-\\w+|gravity|scanning|collateral|uploading|android|robots?|cyborg|laser|blaster|hover|orbit|spaceport|galaxy|aliens?|synth|holograms?|holo|implants?|chrome|cyber\\w*|repo|bounty|plasma|starship|spaceship|airlock|oxygen|freighter|keytar|sprawl|lumen|halcyon|oxygenix|gristle|captain|crew)\\b")
	var grammar := RegEx.create_from_string("(^|[.!?]\\s+|\"\\s*)(the police|police officers|the bank|the town council|the konbini chain|the tv news)\\b|\\bon Suzunari\\b|\\{[a-z_]+\\}|#[a-z_.]+#|\\bI'm (?!a |an |the )[a-z]+ (teacher|clerk|cook|driver|nurse|baker|artist|fisher\\w*)\\b")
	var nick := RegEx.create_from_string("\\b[A-Z][a-z]+ '[A-Z][a-z]+' [A-Z][a-z]+")  # ODD-SPACE saga names: Rosa 'Quarterly' Quill
	var tone := RegEx.create_from_string("(?i)\\b(billing|billed|invoice\\w*|subscription|repossess\\w*|sponsored|taxed|fees?)\\b")
	var names := {}
	var game = root.get_node("Game")
	for p in game.galaxy:
		names[str(p.get("name", ""))] = "planet"
	var saga = root.get_node("Saga")
	for id in saga.personas:
		for part in str(saga.personas[id].get("name", "")).split(" "):
			if part.length() > 2:
				names[part] = "saga"
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/copy.json")).get("rules", {})
	for k in ["first", "last"]:
		for nm in base.get(k, []):
			if str(nm).length() > 2 and not "#" in str(nm):
				names[str(nm)] = "foreign"
	var jp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/suzunari/_manual/copy.json")).get("rules", {})
	for k in ["surname", "given"]:
		for nm in jp.get(k, []):
			names.erase(str(nm))  # Japanese names that happen to be in the base list (Tanaka...)
	var leaks := []
	var tones := []
	var by_src := {}
	var seen := {}
	for e in _lines:
		var t: String = e[1]
		if seen.has(t):
			continue
		seen[t] = true
		var why := ""
		var m := words.search(t)
		if m:
			why = "word '%s'" % m.get_string()
		if why == "":
			var g := grammar.search(t)
			if g:
				why = "grammar '%s'" % g.get_string().strip_edges()
		if why == "" and nick.search(t):
			why = "saga-style name '%s'" % nick.search(t).get_string()
		if why == "":
			for w in t.replace(",", " ").replace(".", " ").replace("\"", " ").replace("'", " ").replace("!", " ").replace("?", " ").split(" "):
				if names.has(w):
					why = "%s name '%s'" % [names[w], w]
					break
		if why != "":
			leaks.append("[%s] %s :: %s" % [e[0], why, t.substr(0, 140).replace("\n", " / ")])
			by_src[e[0]] = int(by_src.get(e[0], 0)) + 1
		elif tone.search(t):
			tones.append("[%s] %s" % [e[0], t.substr(0, 140).replace("\n", " / ")])
	print("town_voice_test: %d distinct lines, %d leaks, %d tone" % [seen.size(), leaks.size(), tones.size()])
	print("  leaks by source: %s" % str(by_src))
	for l in leaks.slice(0, 40):
		print("  LEAK " + l)
	for l in tones.slice(0, 12):
		print("  TONE " + l)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "all":  # every distinct line, for reading (args[0].all.txt)
		var fa := FileAccess.open(args[0] + ".all.txt", FileAccess.WRITE)
		if fa:
			fa.store_string("\n".join(PackedStringArray(seen.keys())) + "\n")
	if args.size() > 0:
		var f := FileAccess.open(args[0], FileAccess.WRITE)
		if f:
			f.store_string("\n".join(PackedStringArray(leaks)) + "\n\n" + "\n".join(PackedStringArray(tones)) + "\n")
	_fails = leaks.size() + maxi(0, tones.size() - 5)
	print("town_voice_test: %d failure(s)" % _fails)
