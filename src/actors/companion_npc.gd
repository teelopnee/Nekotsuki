class_name CompanionNPC
extends NPC
## Someone walking with you (People escort, src/world/home_visits.gd): keeps pace beside the player, chats in
## speech bubbles, waits if you stop, catches up if you run ahead ("Hey, wait up!"). Talk to them to keep
## walking or to split up. leave() walks them off and frees them.

var person := ""
var leaving := false
var follow_offset := Vector3.ZERO  ## where beside you to walk (two companions take different sides)
var _leave_dir := Vector3.ZERO
var _leave_t := 0.0
var _talking_now := false
var _stuck := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	npc_name = People.full_name(person)
	look = CharacterLook.cast_look(str(People.profile(person).get("look", person)))
	loyal = true
	super._ready()
	name_label.text = npc_name
	add_to_group("companion")


func _physics_process(delta: float) -> void:
	if state == "dead" or _talking_now:
		return
	if leaving:
		_leave_t -= delta
		velocity = _leave_dir * 2.2
		move_and_slide()
		sprite.set_facing(_leave_dir)
		sprite.play("walk")
		if _leave_t <= 0.0:
			queue_free()
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var off := global_position - p.global_position
	off.y = 0.0
	if off.length() > 20.0:
		_catch_up(p)
		return
	var side := off.normalized() if off.length() > 0.2 else Vector3(1, 0, 0.4).normalized()
	var to := p.global_position + side * 1.7 + follow_offset - global_position
	to.y = 0.0
	var vel := Vector3.ZERO
	if to.length() > 0.45:
		vel = to.normalized() * (6.2 if to.length() > 5.0 else clampf(to.length() * 1.8, 1.3, 4.2))
	velocity = Vector3(vel.x, 0.0, vel.z)
	move_and_slide()
	if vel.length() > 0.1 and global_position.distance_to(_last_pos) < 0.01:
		_stuck += delta
		if _stuck > 1.4:
			_catch_up(p)
	else:
		_stuck = 0.0
	_last_pos = global_position
	if vel.length() > 0.1:
		sprite.set_facing(vel)
		sprite.play("run" if vel.length() > 4.5 else "walk")
	else:
		sprite.set_facing(p.global_position - global_position)
		sprite.play("idle")


## Left behind or stuck on a wall: pop up just behind the player, like anyone hurrying to catch up.
func _catch_up(p: Node3D) -> void:
	var face: Vector3 = p.get("facing") if p.get("facing") is Vector3 else Vector3.BACK
	face.y = 0.0
	var spot := p.global_position - face.normalized() * 2.0 + face.normalized().cross(Vector3.UP) * 0.8
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl and lvl.has_method("nearest_walkable"):
		spot = lvl.nearest_walkable(spot)
	global_position = spot + Vector3(0, 0.05, 0)
	_stuck = 0.0
	if randf() < 0.5:
		say("Hey - wait up!", 1.6)


func leave(dir: Vector3) -> void:
	leaving = true
	dir.y = 0.0
	_leave_dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	_leave_t = 3.0
	talk.enabled = false


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
	var mode := str(People.escort().get("mode", "school"))
	var key := "walk" if mode == "school" else "home_walk"
	var picked: String = await hud.say(People.short(person), People.line(person, key),
		[{"id": "on", "text": "\"Let's keep going.\""}, {"id": "split", "text": "\"Let's split up here.\""}])
	if picked == "split":
		People.add_close(person, -1)
		People.end_escort()
		await hud.say(People.short(person), "%s blinks. \"Oh. Okay. See you, then.\"\n> %s goes on alone." % [People.short(person), People.short(person)])
		var home = lvl.get("home") if lvl else null
		if home and home.has_method("dismiss"):
			home.dismiss()
		else:
			leave(global_position - (p.global_position if p else global_position))
	_talking_now = false
