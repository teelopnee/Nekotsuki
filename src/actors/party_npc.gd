extends CompanionNPC
## A friend hanging out with you (Party autoload, data/party.json): follows like an escort, but talking to them
## offers their gift (once a day), keeps hanging out, or splits up.


func _ready() -> void:
	super._ready()
	add_to_group("party")


func _on_talk(_player: Node) -> void:
	if _talking_now or leaving:
		return
	var lvl := get_tree().get_first_node_in_group("level")
	var hud: Node = lvl.get("hud") if lvl else null
	if hud == null:
		return
	_talking_now = true
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		sprite.set_facing(p.global_position - global_position)
	var m := Party.member(person)
	var who := People.short(person)
	var banter: Array = m.get("banter", ["..."])
	var picked: String = await hud.say(who, Amane.fill(str(banter[randi() % banter.size()])),
		[{"id": "gift", "text": str(m.get("ask_t", "\"...\""))}, {"id": "on", "text": "\"Let's keep going.\""},
		{"id": "part", "text": "\"I'll head off on my own now.\""}])
	match picked:
		"gift":
			await hud.say(who, Party.ask_gift(person))
		"part":
			Party.leave(person, "part")
			await hud.say(who, str(m.get("part", "")))
	_talking_now = false


func leave(dir: Vector3) -> void:
	remove_from_group("party")  # off home: no more banter, and a new hang-out spawns a fresh body
	super.leave(dir)
