class_name HayateNPC
extends NPC
## Inukai Hayate (docs/CAST.md): your loud best friend from the dog shrine, the week-2 rival by default.
## He leaves the Inukai house at 7:50 and is in the courtyard from 8:10 (People autoload: pick him up at his
## door); after school he can't stand you walking home alone (okuri-inu habit from a past life), so he comes
## over and offers to walk you home - People escort. Talking: hang out / warn him about the cat / ask about the dog shrine. His state follows Amane's
## plan: tired (1), soaked shoes (2), cats hate him (3), forgets you (4), injured or missing (not spawned).

var lines: Dictionary = {}
var spot := Vector3.ZERO
var _talking_now := false
var _layer := 1
var _offering := false


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
	_layer = collision_layer


func _physics_process(_delta: float) -> void:
	if state == "dead" or _talking_now:
		return
	# At home before 8:10, gone home after 16:40, or walking with you as a companion (People autoload).
	var away := People.hides("hayate")
	if away == visible:
		visible = not away
		talk.enabled = not away
		collision_layer = 0 if away else _layer
	if away:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var dest := spot
	var offer := _wants_to_offer(p)
	if offer:
		dest = p.global_position + (global_position - p.global_position).normalized() * 1.6
	var to := dest - global_position
	to.y = 0.0
	var vel := Vector3.ZERO
	if to.length() > (0.6 if not offer else 0.3):
		vel = to.normalized() * (3.6 if to.length() > 6.0 else 1.9)
	elif offer and not _offering:
		_offer_walk()
	velocity = Vector3(vel.x, 0.0, vel.z)
	move_and_slide()
	if vel.length() > 0.1:
		sprite.set_facing(vel)
		sprite.play("run" if vel.length() > 2.5 else "walk")
	else:
		if p:
			sprite.set_facing(p.global_position - global_position)
		sprite.play("idle")


## After school, if he likes you even a little and you're nearby: come over and offer to walk you home.
func _wants_to_offer(p: Node3D) -> bool:
	if p == null or _offering or Clock.minute() < 920 or Clock.minute() >= Clock.NIGHT or People.escorting():
		return false
	var t := People.today("hayate")
	if bool(t.get("offered", false)) or bool(t.get("walked", false)) or People.close("hayate") < 20:
		return false
	var lvl := get_tree().get_first_node_in_group("level")
	var hud: Node = lvl.get("hud") if lvl else null
	return hud != null and not hud._dialogue_open and p.global_position.distance_to(global_position) < 16.0


func _offer_walk() -> void:
	var lvl := get_tree().get_first_node_in_group("level")
	var hud: Node = lvl.get("hud") if lvl else null
	if hud == null:
		return
	_offering = true
	_talking_now = true
	say("Toru! Wait up!", 1.4)
	await People.maybe_offer_home("hayate", hud)
	_talking_now = false
	_offering = false


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
	var menu := [{"id": "hang", "text": str(c.get("hang", "Hang out."))},
		{"id": "warn", "text": str(c.get("warn", "Warn him."))}, {"id": "shrine", "text": str(c.get("shrine", "Ask about the shrine."))}]
	menu.append_array(People.menu_items("hayate"))
	menu.append({"id": "bye", "text": str(c.get("bye", "Bye."))})
	var picked: String = await hud.say("Hayate", opener, menu)
	if picked.begins_with("p:"):
		await People.run_item(picked, hud)
		_talking_now = false
		return
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
