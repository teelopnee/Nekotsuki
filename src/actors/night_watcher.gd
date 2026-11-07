extends Node3D
## The night watch on a cat spirit night (data/cat_night.json `watchers`): Omawari-san with his torch, a drunk
## salaryman, the Inukai stone dogs. A patrol walks its points; a dog stays put and sees all round. Suspicion
## grows while the cat is in sight ("?") - faster up close, half as far while SNEAKing, never on a roof - and at
## "!" they spot it (`spotted`). They don't fight; they chase the cat off and the town talks.

signal spotted(watcher: Node)

var spec := {}
var level: Node
var points: Array[Vector3] = []
var facing := Vector3.FORWARD
var alert := 0.0
var spotted_count := 0
var sprite: BillboardSprite
var _label: Label3D
var _torch: SpotLight3D
var _i := 0
var _cool := 0.0


func setup(s: Dictionary, lvl: Node) -> void:
	spec = s
	level = lvl
	var b = lvl.get("builder")
	if s.has("points"):
		for pt in s.points:
			points.append(b.center(int(pt[0]), int(pt[1])) + Vector3(0, 0.05, 0))
	elif s.has("tile"):
		points.append(b.center(int(s.tile[0]), int(s.tile[1])) + Vector3(0, 0.05, 0))


func _ready() -> void:
	add_to_group("night_watch")
	if not points.is_empty():
		global_position = points[0]
	if str(spec.get("kind", "patrol")) == "patrol":
		sprite = BillboardSprite.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(spec.get("name", "")))
		sprite.set_look(CharacterLook.random_look(rng, "civilian"))
		add_child(sprite)
		sprite.play("walk")
	else:
		for sx in [-0.22, 0.22]:
			var eye := OmniLight3D.new()
			eye.light_color = Color(1.0, 0.3, 0.2)
			eye.light_energy = 0.0
			eye.omni_range = 1.2
			eye.position = Vector3(sx, 1.3, 0.3)
			eye.name = "Eye"
			add_child(eye)
	if bool(spec.get("light", false)):
		_torch = SpotLight3D.new()
		_torch.light_color = Color(1.0, 0.95, 0.8)
		_torch.light_energy = 3.0
		_torch.spot_range = float(spec.get("sight", 8.0)) + 1.0
		_torch.spot_angle = 30.0
		_torch.position = Vector3(0, 1.3, 0)
		add_child(_torch)
	_label = Label3D.new()
	_label.font_size = 64
	_label.pixel_size = 0.01
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.6, 0)
	_label.modulate = Color(1.0, 0.85, 0.3)
	add_child(_label)


func _physics_process(delta: float) -> void:
	var hud = level.get("hud") if level else null
	if hud and hud._dialogue_open:
		return
	_cool = maxf(0.0, _cool - delta)
	if points.size() > 1:
		var to := points[_i] - global_position
		to.y = 0.0
		if to.length() < 0.4:
			_i = (_i + 1) % points.size()
		else:
			facing = to.normalized()
			global_position += facing * float(spec.get("speed", 1.4)) * delta
		if sprite:
			sprite.set_facing(facing)
			sprite.play("walk")
	if _torch:
		_torch.look_at(_torch.global_position + facing + Vector3(0, -0.35, 0), Vector3.UP)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or _cool > 0.0:
		_label.text = ""
		return
	if sees(p):
		var d := global_position.distance_to(p.global_position)
		alert += delta * (2.2 if d < float(spec.get("sight", 8.0)) * 0.5 else 1.0)
	else:
		alert = maxf(0.0, alert - delta * 0.6)
	_label.text = "!" if alert >= 1.0 else ("?" if alert > 0.15 else "")
	for e in get_children():
		if e is OmniLight3D and e.name.begins_with("Eye"):
			e.light_energy = alert * 4.0
	if alert >= 1.0:
		alert = 0.0
		_cool = 4.0
		spotted_count += 1
		spotted.emit(self)


## Can this watcher see the cat right now? Range (halved while sneaking), cone (dogs see all round),
## never on the roofs, never mid-leap, and only with a clear line of sight.
func sees(p: Node3D) -> bool:
	if p.has_meta("hopping") or p.global_position.y > 2.2:
		return false
	var rng := float(spec.get("sight", 8.0)) * (0.5 if p.get_meta("sneaking", false) else 1.0)
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() > rng:
		return false
	if str(spec.get("kind", "patrol")) == "patrol" and to.length() > 1.5 and facing.dot(to.normalized()) < 0.8:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.2, 0), p.global_position + Vector3(0, 0.4, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
