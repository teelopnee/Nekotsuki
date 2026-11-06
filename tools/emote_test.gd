extends SceneTree
## Every emotion in data/emotions.json has its body animation in every cast/student sheet
## and its manga emote sheet in assets/sprites/fx. Exit code = failures.
## godot --headless --path . --script res://tools/emote_test.gd

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _init() -> void:
	var fails := 0
	var emotions := _json("res://data/emotions.json")
	var fx := _json("res://assets/sprites/fx/fx.json")
	var variants := _json("res://assets/sprites/characters/variants.json")
	var school: Array = []
	for v in variants:
		var cfg: Dictionary = variants[v].get("cfg", {})
		if cfg.get("school", false):
			school.append(v)
	if school.size() < 19:
		printerr("expected 19 school/cast variants, found %d" % school.size())
		fails += 1
	for v in school:
		var meta := _json("res://assets/sprites/characters/%s.json" % v)
		var anims: Dictionary = meta.get("anims", {})
		for feel in emotions:
			if feel.begins_with("_"):
				continue
			var a := str(emotions[feel].get("anim", ""))
			if a != "" and not anims.has(a):
				printerr("%s: no anim '%s' for '%s'" % [v, a, feel])
				fails += 1
	for feel in emotions:
		if feel.begins_with("_"):
			continue
		var k := str(emotions[feel].get("fx", ""))
		if k != "" and not fx.has("emote_" + k):
			printerr("no emote sheet for %s (%s)" % [feel, k])
			fails += 1
	var looks := _json("res://data/cast_looks.json")
	for id in looks:
		if id.begins_with("_"):
			continue
		if not variants.has(str(looks[id].get("variant", ""))):
			printerr("cast %s: missing variant" % id)
			fails += 1
	print("emote_test: %d school variants, %d emotions, %d failures" % [school.size(), emotions.size() - 1, fails])
	quit(fails)
