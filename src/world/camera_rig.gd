class_name CameraRig
extends Node3D
## HD-2D diorama camera: fixed yaw, tilted pitch, narrow FOV, plus the "lens":
## tilt-shift miniature blur, vignette, chromatic aberration, grain and split
## toning (assets/shaders/hd2d_post.gdshader). Also: smooth follow with
## look-ahead, combat framing (zooms out when enemies are near), zoom punches,
## screen shake, and fading of buildings that hide the player.

const POST := preload("res://assets/shaders/hd2d_post.gdshader")
const LENS := preload("res://assets/shaders/hd2d_depth.gdshader")

@export var distance := 18.0
@export var pitch_degrees := 38.0
@export var fov := 33.0
@export var follow_speed := 6.5
@export var look_ahead := 1.6
## "tilt_shift" = screen-space HD-2D lens (default, works on every GPU)
## "physical"   = depth-based DOF via CameraAttributes (GPU/driver dependent)
## "off"        = lens effects off (fastest)
@export_enum("depth", "tilt_shift", "physical", "off") var dof_mode := "depth"
@export var dof_near_margin := 6.0
@export var dof_far_margin := 5.0
@export var dof_amount := 0.05
@export var occluder_sweep_width := 5.0  # metres of buildings cut away around the sight line

var target: Node3D
var camera: Camera3D
var attributes: CameraAttributesPractical
var post_rect: ColorRect
var post_mat: ShaderMaterial
## "depth" lens (hd2d_depth.gdshader): depth of field by real distance + SSAO, drawn as a full-screen quad.
var lens_quad: MeshInstance3D
var lens_mat: ShaderMaterial
var dof_enabled := false
var _shake := 0.0
var _punch := 0.0
var _punch_time := 0.0
var _combat_zoom := 0.0
var _ahead := Vector3.ZERO
var _faded: Dictionary = {}
var _occ_shape: BoxShape3D
## Talk close-up (Suzunari / school): while a dialogue is open the lens moves in on the two people talking,
## lowers a little and turns Toru toward whoever he is talking to (never his back to the camera), so faces and
## emotes read at play distance (docs/REVIEW.md hard review #4).
var _talk := 0.0
var _talk_mid := Vector3.ZERO
var _hidden_labels: Array = []


func _ready() -> void:
	add_to_group("camera_rig")
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 0.3
	camera.far = 260.0
	attributes = CameraAttributesPractical.new()
	camera.attributes = attributes
	add_child(camera)
	camera.make_current()
	_apply_pose(0.0)
	lens_mat = ShaderMaterial.new()
	lens_mat.shader = LENS
	lens_mat.render_priority = -128  # first in the transparent pass: sees the opaque frame, under labels/rain
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	lens_quad = MeshInstance3D.new()
	lens_quad.name = "DepthLens"
	lens_quad.mesh = q
	lens_quad.material_override = lens_mat
	lens_quad.extra_cull_margin = 16384.0
	lens_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens_quad.position = Vector3(0, 0, -1.0)
	lens_quad.visible = false
	camera.add_child(lens_quad)
	var layer := CanvasLayer.new()
	layer.layer = 1  # under the HUD (layer 10)
	add_child(layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST
	post_rect.material = post_mat
	layer.add_child(post_rect)
	set_dof_mode(str(Game.settings.get("dof_mode", dof_mode)))


func configure(p_pitch: float, p_distance: float, p_fov: float) -> void:
	pitch_degrees = p_pitch
	distance = p_distance
	fov = p_fov
	if camera:
		camera.fov = fov
		_apply_pose(0.0)


func _apply_pose(extra_zoom: float) -> void:
	var pitch := deg_to_rad(pitch_degrees - 7.0 * _talk)
	var dist := distance * (1.0 + extra_zoom)
	camera.position = Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	camera.rotation = Vector3(-pitch, 0, 0)


func set_dof_mode(mode: String) -> void:
	dof_mode = mode
	dof_enabled = mode == "physical"
	attributes.dof_blur_far_enabled = dof_enabled
	attributes.dof_blur_near_enabled = dof_enabled
	attributes.dof_blur_amount = dof_amount
	if post_mat:
		post_rect.visible = mode != "off"
		post_mat.set_shader_parameter("tilt_shift", mode == "tilt_shift")
	if lens_quad:
		lens_quad.visible = mode == "depth" and str(Game.settings.get("graphics", "high")) != "low"


func set_grade(shadow: Color, highlight: Color, toning: float = 0.22) -> void:
	if post_mat:
		post_mat.set_shader_parameter("shadow_tint", shadow)
		post_mat.set_shader_parameter("highlight_tint", highlight)
		post_mat.set_shader_parameter("toning", toning)


func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position + Vector3(0, 0.9, 0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Quick zoom-in punch.
func punch(amount: float = 0.12, duration: float = 0.25) -> void:
	_punch = amount
	_punch_time = duration


func _process(delta: float) -> void:
	var rdelta := delta / maxf(Engine.time_scale, 0.05)  # real-time camera feel during slow-mo
	if lens_quad and lens_quad.visible and target != null and is_instance_valid(target):
		var local := camera.global_transform.affine_inverse() * (target.global_position + Vector3(0, 0.9, 0))
		lens_mat.set_shader_parameter("focus_dist", maxf(2.0, -local.z))
	if target != null and is_instance_valid(target):
		var vel := Vector3.ZERO
		if target is CharacterBody3D:
			vel = (target as CharacterBody3D).velocity * Vector3(1, 0, 1)
		_ahead = _ahead.lerp(vel.limit_length(6.0) / 6.0 * look_ahead, 1.0 - exp(-3.0 * rdelta))
		var goal := target.global_position + Vector3(0, 0.9, 0) + _ahead
		var partner := _talk_partner()
		var talking := partner != null or _dialogue_open()
		_talk = lerpf(_talk, 1.0 if talking else 0.0, 1.0 - exp(-5.0 * rdelta))
		if partner:
			_talk_mid = (target.global_position + partner.global_position) * 0.5 + Vector3(0, 0.9, 0)
			_face_each_other(partner)
		elif talking:
			_talk_mid = target.global_position + Vector3(0, 0.9, 0)
		if _talk > 0.01:
			goal = goal.lerp(_talk_mid, _talk)
		_talk_labels(talking)
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * rdelta))
		# Combat framing: pull back a little when hostiles are around.
		var near := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.hostile and e.global_position.distance_to(target.global_position) < 11.0:
				near += 1
		_combat_zoom = lerpf(_combat_zoom, 0.12 if near > 0 else 0.0, 1.0 - exp(-1.5 * rdelta))
	ViewLod.focus = global_position  # what the lens is centred on (player, or a cutscene subject)
	var punch_amt := 0.0
	if _punch_time > 0.0:
		_punch_time -= rdelta
		punch_amt = -_punch * clampf(_punch_time / 0.25, 0.0, 1.0)
	_apply_pose(_combat_zoom + punch_amt - 0.4 * _talk)
	if _shake > 0.0:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.32
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.32
		_shake = maxf(0.0, _shake - rdelta * 2.6)
	else:
		camera.h_offset = 0.0
		camera.v_offset = -0.9 * _talk  # lift the pair above the dialogue box
	if dof_enabled:
		var focus := camera.global_position.distance_to(global_position)
		attributes.dof_blur_far_distance = focus + dof_far_margin
		attributes.dof_blur_far_transition = 12.0
		attributes.dof_blur_near_distance = maxf(0.5, focus - dof_near_margin)
		attributes.dof_blur_near_transition = 4.0
	_update_occluders()


## Close up, everyone's 3D name tag would fill the frame: hide them while talking (the box names the speaker).
func _talk_labels(talking: bool) -> void:
	if talking and _hidden_labels.is_empty():
		for n in get_tree().get_nodes_in_group("npc"):
			var l = n.get("name_label")
			if l is Label3D and l.visible:
				l.visible = false
				_hidden_labels.append(l)
			var bub = n.get("_bubble")
			if bub is Label3D:
				bub.visible = false  # its fade tween ends hidden anyway; the next say() shows it again
	elif not talking and not _hidden_labels.is_empty():
		for l in _hidden_labels:
			if is_instance_valid(l):
				l.visible = true
		_hidden_labels.clear()


func _dialogue_open() -> bool:
	if DataDB.theme != "suzunari":
		return false
	var lvl := get_tree().get_first_node_in_group("level")
	var hud = lvl.get("hud") if lvl else null
	return hud != null and bool(hud.get("_dialogue_open"))


## While a dialogue is open: the nearest person (or cat) within 4.5 m of the hero is who you're talking to.
func _talk_partner() -> Node3D:
	if target == null or not _dialogue_open():
		return null
	var best: Node3D = null
	var best_d := 4.5
	for n in get_tree().get_nodes_in_group("npc"):
		var n3 := n as Node3D
		if n3 == null or not n3.visible or n3 == target:
			continue
		var d := n3.global_position.distance_to(target.global_position)
		if d < best_d:
			best_d = d
			best = n3
	return best


## Toru turns to the person he talks to; if they stand behind him (north, away from the lens) he turns
## side-on instead, so his face is in the shot. They turn to him.
func _face_each_other(partner: Node3D) -> void:
	var to := partner.global_position - target.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var face := to.normalized()
	if face.z < 0.2:
		face = Vector3(1.0 if to.x >= 0.0 else -1.0, 0.0, 0.35).normalized()
	var ts = target.get("sprite")
	if ts and ts.has_method("set_facing"):
		ts.set_facing(face)
	var ps = partner.get("sprite")
	if ps and ps.has_method("set_facing"):
		ps.set_facing(-to)


func _update_occluders() -> void:
	if target == null or not is_instance_valid(target):
		return
	var space := get_world_3d().direct_space_state
	var hits := {}
	var from := camera.global_position
	var to := target.global_position + Vector3(0, 1.0, 0)
	# Sweep a slab along the sight line, not a thin ray: a whole row of buildings across a
	# narrow street must cut away together, or the neighbours leave a dark band over the hero.
	var dir := to - from
	var length := dir.length()
	if length > 1.0:
		if _occ_shape == null:
			_occ_shape = BoxShape3D.new()
		_occ_shape.size = Vector3(occluder_sweep_width, 2.2, maxf(0.5, length - 1.2))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _occ_shape
		q.collision_mask = 128
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		q.transform = Transform3D(basis, from + dir * 0.5 - dir.normalized() * 0.6)
		for r in space.intersect_shape(q, 24):
			hits[r.collider] = true
	# Foreground trees: crowns between the lens and the hero (south of him, inside the frame) fade too -
	# they used to cover a third of the town shot.
	var tp := target.global_position
	for t in get_tree().get_nodes_in_group("foliage_fg"):
		var t3 := t as Node3D
		if t3 and t3.global_position.z > tp.z + 2.2 and t3.global_position.z < from.z and absf(t3.global_position.x - tp.x) < 10.0:
			hits[t3] = true
	if target.has_meta("standing_on"):  # the cat on a roof: never fade the house under its paws
		var under = target.get_meta("standing_on")
		hits.erase(under)
		if under is Node and (under as Node).get_parent():
			hits.erase((under as Node).get_parent())
	for body in hits:
		if not _faded.has(body):
			_set_faded(body, true)
	for body in _faded.keys():
		if not hits.has(body):
			_set_faded(body, false)


func _set_faded(body: Object, faded: bool) -> void:
	if not is_instance_valid(body):
		_faded.erase(body)
		return
	if faded:
		_faded[body] = true
	else:
		_faded.erase(body)
	for mat in body.get_meta("fade_mats", []):
		var m: StandardMaterial3D = mat
		var tw := create_tween()
		# Full cut-away: a hashed alpha of ~0.2 leaves a dotted veil over the whole frame.
		tw.tween_property(m, "albedo_color:a", 0.0 if faded else 1.0, 0.18)
	for n in body.get_meta("fade_hide", []):
		if is_instance_valid(n):
			n.visible = not faded


func _exit_tree() -> void:
	ViewLod.focus = Vector3.INF  # next scene: unknown until its camera runs
