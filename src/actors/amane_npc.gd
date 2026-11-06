class_name AmaneNPC
extends NPC
## Amane in the world: trails Senpai at a route-dependent distance, freezes and peeks when looked at
## (ears up), slips back behind you when you get too far (cats are always somehow there), walks up
## to talk now and then, and cries the town's rain (Amane autoload). Talking opens Amane.converse().

var target: Node3D
var _caught := false
var _approaching := false
var _talking_now := false
var _approach_cd := 25.0
var _stuck := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	npc_name = "Amane"
	look = CharacterLook.cast_look("amane")
	loyal = true
	super._ready()
	name_label.text = "Amane"
	add_to_group("amane")
	Amane.tears_changed.connect(_on_tears)


func _physics_process(delta: float) -> void:
	if state == "dead" or _talking_now:
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			return
	var to_me := global_position - target.global_position
	to_me.y = 0.0
	var dist := to_me.length()
	var face: Vector3 = target.get("facing") if target.get("facing") is Vector3 else Vector3.BACK
	var looked_at := dist < 13.0 and dist > 0.1 and Vector3(face.x, 0, face.z).normalized().dot(to_me / dist) > 0.6
	var vel := Vector3.ZERO
	_approach_cd -= delta
	if _approaching:
		if dist <= 1.7:
			_approaching = false
			_start_talk()
			return
		vel = -to_me.normalized() * 3.4
	elif looked_at and dist > 2.4:
		if not _caught:
			_caught = true
			Emotion.express(self, "peek", 1.8)
			if randf() < 0.35:
				say(Amane.fill(str(Amane.data.get("peek_bark", ["!"]).pick_random())), 1.4)
	else:
		_caught = false
		var want := Amane.follow_distance()
		if dist > 22.0 and not looked_at:
			_slip_behind(want)
		elif dist > want + 0.8:
			vel = -to_me.normalized() * (3.6 if dist > want + 5.0 else 2.2)
		if _approach_cd <= 0.0 and dist < 10.0 and Amane.st()["met"] and Amane.route() != "ignore":
			_approaching = true
			say(str(Amane.data.get("approach_bark", ["Senpai!"]).pick_random()), 1.2)
	velocity.x = vel.x
	velocity.z = vel.z
	velocity.y = 0.0
	move_and_slide()
	# Walls and benches: if he hasn't moved while trying to, pop to a spot behind Senpai.
	if vel.length() > 0.1 and global_position.distance_to(_last_pos) < 0.01:
		_stuck += delta
		if _stuck > 1.2 and not looked_at:
			_slip_behind(Amane.follow_distance())
	else:
		_stuck = 0.0
	_last_pos = global_position
	if vel.length() > 0.1:
		sprite.set_facing(vel)
		sprite.play("run" if vel.length() > 3.0 else "walk")
	else:
		sprite.set_facing(-to_me)
		sprite.play("idle")


func _slip_behind(want: float) -> void:
	var face: Vector3 = target.get("facing") if target.get("facing") is Vector3 else Vector3.BACK
	face.y = 0.0
	var spot := target.global_position - face.normalized() * want
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl and lvl.has_method("nearest_walkable"):
		spot = lvl.nearest_walkable(spot)
	global_position = spot + Vector3(0, 0.05, 0)
	_stuck = 0.0


func _on_talk(_player: Node) -> void:
	if not _talking_now:
		_start_talk()


func _start_talk() -> void:
	var lvl := get_tree().get_first_node_in_group("level")
	var hud: Node = lvl.get("hud") if lvl else null
	if hud == null:
		return
	_talking_now = true
	sprite.set_facing(target.global_position - global_position if target else Vector3.BACK)
	await Amane.converse(self, hud)
	_talking_now = false
	_approach_cd = randf_range(70.0, 140.0) if Amane.route() != "romance" else randf_range(40.0, 80.0)


func _on_tears(level: int) -> void:
	if level >= 4:
		Emotion.express(self, "wail", 4.0)
	elif level >= 2:
		Emotion.express(self, "cry", 3.0)
