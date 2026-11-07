extends NPC
## Someone Amane's cat spirited away (fate "hidden"), waiting in Ura-Suzunari (data/ura.json `hidden`). Talk to
## them and take their hand: they follow you (like a companion) until you walk down the thousandth step
## (Week.leave_ura -> Amane.rescue) - or until the second bell, when the hand slips (Week.leave_ura(true)).

var who := ""        ## the full name in Amane's books (closeness / fates key)
var following := false
var _talking_now := false


func _ready() -> void:
	npc_name = who
	var pid := People.id_of(who)
	if pid != "":
		look = CharacterLook.cast_look(str(People.profile(pid).get("look", pid)))
	loyal = true
	super._ready()
	name_label.text = who.split(" ")[-1] + " (hidden)"
	add_to_group("lost")
	if sprite:
		sprite.modulate = Color(0.75, 0.85, 1.0, 0.85)  # pale, half here


func short_name() -> String:
	return who.split(" ")[-1]


func _physics_process(delta: float) -> void:
	if state == "dead" or _talking_now:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	if not following:
		sprite.set_facing(p.global_position - global_position)
		sprite.play("idle")
		return
	var off := global_position - p.global_position
	off.y = 0.0
	if off.length() > 14.0:
		var lvl := get_tree().get_first_node_in_group("level")
		var spot := p.global_position - Vector3(0, 0, -1.6)
		if lvl and lvl.has_method("nearest_walkable"):
			spot = lvl.nearest_walkable(spot)
		global_position = spot + Vector3(0, 0.05, 0)
		return
	var to := p.global_position + off.normalized() * 1.4 - global_position
	to.y = 0.0
	var vel := to.normalized() * clampf(to.length() * 2.0, 0.0, 6.0) if to.length() > 0.4 else Vector3.ZERO
	velocity = Vector3(vel.x, 0.0, vel.z)
	move_and_slide()
	if vel.length() > 0.1:
		sprite.set_facing(vel)
		sprite.play("run" if vel.length() > 4.0 else "walk")
	else:
		sprite.set_facing(p.global_position - global_position)
		sprite.play("idle")


func _on_talk(_player: Node) -> void:
	if _talking_now:
		return
	var lvl := get_tree().get_first_node_in_group("level")
	var hud: Node = lvl.get("hud") if lvl else null
	if hud == null:
		return
	_talking_now = true
	var h: Dictionary = Week.ura.get("hidden", {})
	var n := short_name()
	if following:
		await hud.say(n, str(h.get("holding", "")).replace("{who}", n))
	else:
		var pick: String = await hud.say(n, str(h.get("text", "")).replace("{who}", n),
			[{"id": "take", "text": str(h.get("take", "")).replace("{who}", n)}, {"id": "later", "text": str(h.get("not_yet", ""))}])
		if pick == "take":
			following = true
			var list: Array = Game.flags.get("ura_rescue", [])
			if not list.has(who):
				list.append(who)
			Game.flags["ura_rescue"] = list
			Ledger.capture("Taking %s's hand on the other side" % n)
			await hud.say(n, str(h.get("taken", "")).replace("{who}", n))
	_talking_now = false
