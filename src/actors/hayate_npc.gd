class_name HayateNPC
extends NPC
## Inukai Hayate (docs/CAST.md): your loud best friend from the dog shrine, the week-2 rival by default.
## In class time he hangs around the courtyard; after school he walks you home (okuri-inu habit from a past
## life). Talking: hang out / warn him about the cat / ask about the dog shrine. His state follows Amane's
## plan: tired (1), soaked shoes (2), cats hate him (3), forgets you (4), injured or missing (not spawned).

var lines: Dictionary = {}
var spot := Vector3.ZERO
var _talking_now := false


func _ready() -> void:
	npc_name = Amane.FRIEND
	look = CharacterLook.cast_look("hayate")
	loyal = true
	if FileAccess.file_exists("res://data/hayate.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/hayate.json"))
		if parsed is Dictionary:
			lines = parsed
	super._ready()
	name_label.text = "Inukai Hayate"
	spot = global_position


func _physics_process(delta: float) -> void:
	if state == "dead" or _talking_now:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var dest := spot
	var escort := Clock.minute() >= 920 and Clock.minute() < Clock.NIGHT and Amane.fate(npc_name) == ""
	if escort and p:
		dest = p.global_position + (global_position - p.global_position).normalized() * 3.2
	var to := dest - global_position
	to.y = 0.0
	var vel := Vector3.ZERO
	if to.length() > (0.6 if not escort else 1.2):
		vel = to.normalized() * (3.0 if to.length() > 6.0 else 1.9)
	velocity = Vector3(vel.x, 0.0, vel.z)
	move_and_slide()
	if vel.length() > 0.1:
		sprite.set_facing(vel)
		sprite.play("run" if vel.length() > 2.5 else "walk")
	else:
		if p:
			sprite.set_facing(p.global_position - global_position)
		sprite.play("idle")


func _pick(arr) -> String:
	if not arr is Array or (arr as Array).is_empty():
		return ""
	return Amane.fill(str(arr[randi() % arr.size()]))


func _on_talk(_player: Node) -> void:
	if _talking_now:
		return
	var lvl := get_tree().get_first_node_in_group("level")
	var hud: Node = lvl.get("hud") if lvl else null
	if hud == null:
		return
	_talking_now = true
	var stage := int(Amane.st()["plan"]["stage"]) if Amane.rival() == npc_name else 0
	var close := int(Amane.st()["closeness"].get(npc_name, 0))
	var opener := Amane.fill(str(lines.get("stage_lines", {}).get(str(stage), "")))
	if opener == "":
		opener = _pick(lines.get("openers", {}).get("high" if close >= 40 else ("mid" if close >= 15 else "low"), []))
	var c: Dictionary = lines.get("choices", {})
	var picked: String = await hud.say("Hayate", opener, [{"id": "hang", "text": str(c.get("hang", "Hang out."))},
		{"id": "warn", "text": str(c.get("warn", "Warn him."))}, {"id": "shrine", "text": str(c.get("shrine", "Ask about the shrine."))},
		{"id": "bye", "text": str(c.get("bye", "Bye."))}])
	var reply := ""
	match picked:
		"hang":
			Amane.add_closeness(npc_name, 12)
			reply = _pick(lines.get("hang", []))
			Emotion.express(self, "laugh", 2.5)
			var a := get_tree().get_first_node_in_group("amane") as Node3D
			if a and a.global_position.distance_to(global_position) < 14.0:
				Amane.notice_rival(npc_name, a)
		"warn":
			var first := Amane.warn(npc_name)
			reply = Amane.fill(str(lines.get("warn_first" if first else "warn_again", "")))
			if Amane.rival() != npc_name:
				reply = Amane.fill("\"Cats? What about cats?\" He laughs it off. (He isn't the one Amane is watching this week.)")
			Emotion.express(self, "confused", 2.0)
		"shrine":
			Amane.add_closeness(npc_name, 2)
			reply = _pick(lines.get("shrine", []))
		_:
			reply = _pick(lines.get("bye", []))
	await hud.say("Hayate", reply)
	_talking_now = false
