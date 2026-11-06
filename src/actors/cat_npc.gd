class_name CatNPC
extends CharacterBody3D
## A Suzunari cat (Cats autoload). Wanders near home, sits, loafs, washes its face (more often when Amane
## is about to cry - "when a cat washes its face, it will rain"). A cat that sees you get close to someone
## runs off to tell Amane, unless it likes you. Pet it to win it over (or to make it forget mid-report).

var cat_id := ""
var cat_name := "Mochi"
var look: Dictionary = {}
var sprite: BillboardSprite
var home := Vector3.ZERO
var reporting := ""
var report_left := 0.0
const REPORT_TIME := 12.0
var _target := Vector3.ZERO
var _t := 0.0
var _act := "idle"
var _label: Label3D
var _talk: Interactable
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("cat")
	_rng.randomize()
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	col.shape = sh
	col.position.y = 0.25
	add_child(col)
	sprite = BillboardSprite.new()
	sprite.name = "Sprite"
	sprite.pixel_size = 0.034 * 1.4
	sprite.set_look(look)
	add_child(sprite)
	_talk = Interactable.new()
	_talk.prompt = "Pet %s" % cat_name
	_talk.radius = 1.3
	add_child(_talk)
	_talk.interacted.connect(func(_p): Cats.pet(self))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.004
	_label.font_size = 32
	_label.outline_size = 10
	_label.position = Vector3(0, 1.2, 0)
	_label.visible = false
	add_child(_label)
	home = global_position
	_t = _rng.randf_range(0.5, 4.0)


func start_report(about: String) -> void:
	reporting = about
	report_left = REPORT_TIME
	FX.emote(self, "exclaim", 1.5)


func cancel_report() -> void:
	reporting = ""
	_label.visible = false


func _physics_process(delta: float) -> void:
	var vel := Vector3.ZERO
	if reporting != "":
		report_left -= delta
		var a := get_tree().get_first_node_in_group("amane") as Node3D
		var dest := a.global_position if a else home
		var to := dest - global_position
		to.y = 0.0
		if to.length() > 0.8:
			vel = to.normalized() * 2.6
		_label.visible = true
		_label.text = "MEOW... telling Amane %d%%" % int(100.0 * (1.0 - report_left / REPORT_TIME))
		if report_left <= 0.0:
			var who := reporting
			cancel_report()
			Cats.report_done(self, who)
	else:
		_t -= delta
		if _t <= 0.0:
			_pick_act()
		if _act == "walk":
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.3:
				_act = "idle"
			else:
				vel = to.normalized() * 0.9
	velocity = Vector3(vel.x, 0.0, vel.z)
	move_and_slide()
	if vel.length() > 0.1:
		sprite.set_facing(vel)
		sprite.play("run" if vel.length() > 2.0 else "walk")
	else:
		sprite.play(_act if _act != "walk" else "idle")


func _pick_act() -> void:
	var wash := 0.6 if Amane.tears_level() >= 2 else 0.15
	var r := _rng.randf()
	if r < wash:
		_act = "wash"
	elif r < wash + 0.4:
		_act = "walk"
		_target = home + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
	elif r < wash + 0.6:
		_act = "sit"
	else:
		_act = "loaf"
	_t = _rng.randf_range(3.0, 8.0)
