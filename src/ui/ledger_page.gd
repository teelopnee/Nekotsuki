extends Control
## The last page of the episode (docs/GDD.md 4.14): Enma's Ledger, written in front of you by the two thumb-sized
## scribes from Toru's shoulders - Dosho (left, black, teasing) and Domyo (right, white, polite). Each entry is
## brushed in line by line, they argue about it, and it gets a stamp: GOOD DEED / BAD DEED / UNDECIDED. Then the
## Johari mirror shows the moments that mattered (real frames kept by Ledger.capture), then a tally and the close.
## Tap / A / NEXT turns the page; SKIP writes everything at once. Emits `closed`.

signal closed

const PAPER := Color(0.94, 0.9, 0.8)
const INK := Color(0.13, 0.09, 0.08)
const INK_DOSHO := Color(0.32, 0.06, 0.1)
const INK_DOMYO := Color(0.1, 0.16, 0.3)
const RED := Color(0.78, 0.1, 0.12)
const WRITE_CPS := 70.0

var entries: Array = []
var data: Dictionary = {}
var index := -1
var stage := "intro"  ## intro -> entry -> mirror -> tally -> done
var tally := {"good": 0, "bad": 0, "argued": 0}
var _busy := false
var _skip := false

var _center: VBoxContainer
var _heading: Label
var _text: Label
var _stamp: Label
var _dosho_line: Label
var _domyo_line: Label
var _dosho_spr: TextureRect
var _domyo_spr: TextureRect
var _next: Button
var _mirror: TextureRect
var _mirror_caption: Label
var _dosho_font: FontVariation
var _domyo_font: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	data = Ledger.scribes
	entries = Ledger.entries()
	# Handwriting (OFL fonts, assets/fonts): Domyo writes a neat brush hand (Yuji Syuku, which also carries the
	# ledger's kanji), Dosho scrawls with a dry brush (Caveat Brush). Falls back to the UI font, slanted.
	var base := get_theme_default_font()
	_dosho_font = FontVariation.new()
	_dosho_font.base_font = _font("res://assets/fonts/caveat_brush.woff2", base)
	if _dosho_font.base_font == base:
		_dosho_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.28, 1), Vector2.ZERO)
	_domyo_font = FontVariation.new()
	_domyo_font.base_font = _font("res://assets/fonts/yuji_syuku_ledger.woff2", base)
	_build()
	_show_intro()


func _font(path: String, fallback: Font) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	return fallback


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.05, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	add_child(m)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = Color(0.45, 0.3, 0.18)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	paper.add_theme_stylebox_override("panel", sb)
	m.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	paper.add_child(col)
	var title := _label("閻魔帳  " + str(data.get("title", "ENMA'S LEDGER")), 34, RED)
	title.add_theme_font_override("font", _domyo_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _label(str(data.get("subtitle", "")), 15, Color(0.4, 0.32, 0.26))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	# Left shoulder: Dosho.
	var left := _scribe_column("DOSHO  (left shoulder)", "res://assets/ui/scribe_dosho.png", INK_DOSHO, _dosho_font)
	_dosho_spr = left[0]
	_dosho_line = left[1]
	row.add_child(left[2])
	# The page itself.
	_center = VBoxContainer.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.add_theme_constant_override("separation", 12)
	row.add_child(_center)
	_heading = _label("", 16, Color(0.45, 0.35, 0.28))
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.add_child(_heading)
	_text = _label("", 27, INK)
	_text.add_theme_font_override("font", _domyo_font)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(300, 120)
	_center.add_child(_text)
	_mirror = TextureRect.new()
	_mirror.custom_minimum_size = Vector2(300, 300)
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_SCALE
	_mirror.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mirror.material = _mirror_material()
	_mirror.visible = false
	_center.add_child(_mirror)
	_mirror_caption = _label("", 18, INK)
	_mirror_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mirror_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mirror_caption.visible = false
	_center.add_child(_mirror_caption)
	_stamp = _label("", 30, RED)
	_stamp.add_theme_font_override("font", _domyo_font)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.custom_minimum_size = Vector2(0, 54)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0)
	ssb.border_color = RED
	ssb.set_border_width_all(4)
	ssb.set_corner_radius_all(10)
	ssb.content_margin_left = 16
	ssb.content_margin_right = 16
	_stamp.add_theme_stylebox_override("normal", ssb)
	_stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamp.modulate.a = 0.0
	_center.add_child(_stamp)
	# Right shoulder: Domyo.
	var right := _scribe_column("DOMYO  (right shoulder)", "res://assets/ui/scribe_domyo.png", INK_DOMYO, _domyo_font)
	_domyo_spr = right[0]
	_domyo_line = right[1]
	row.add_child(right[2])
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)
	_next = Button.new()
	_next.text = "TURN THE PAGE"
	_next.custom_minimum_size = Vector2(230, 50)
	_next.pressed.connect(advance)
	bottom.add_child(_next)
	var skip := Button.new()
	skip.text = "WRITE IT ALL"
	skip.custom_minimum_size = Vector2(190, 50)
	skip.pressed.connect(skip_all)
	bottom.add_child(skip)
	_next.grab_focus.call_deferred()


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 0)  # ink on paper: no HUD outline or shadow
	l.add_theme_constant_override("shadow_outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


func _scribe_column(name: String, tex_path: String, ink: Color, font: Font) -> Array:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(250, 0)
	v.add_theme_constant_override("separation", 6)
	var spr := TextureRect.new()
	if ResourceLoader.exists(tex_path):
		var at := AtlasTexture.new()
		at.atlas = load(tex_path)
		at.region = Rect2(0, 0, 48, 64)
		spr.texture = at
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.custom_minimum_size = Vector2(144, 192)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(spr)
	var n := _label(name, 14, Color(0.45, 0.35, 0.28))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var line := _label("", 18, ink)
	line.add_theme_font_override("font", font)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(250, 0)
	v.add_child(line)
	return [spr, line, v]


## A round mirror of pure crystal: circular mask, a pale rim, a slow shimmer.
func _mirror_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float t = 0.0;
uniform float aspect = 1.6;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 uv = vec2(0.5 + (UV.x - 0.5) / aspect, UV.y);
	if (aspect < 1.0) { uv = vec2(UV.x, 0.5 + (UV.y - 0.5) * aspect); }
	float r = length(p);
	if (r > 1.0) { discard; }
	vec4 c = texture(TEXTURE, uv + vec2(sin(UV.y * 18.0 + t) * 0.002, 0.0));
	c.rgb = mix(c.rgb, vec3(0.75, 0.85, 1.0), 0.12 + 0.08 * sin(t * 0.7 + UV.x * 3.0));
	float rim = smoothstep(0.86, 1.0, r);
	c.rgb = mix(c.rgb, vec3(0.92, 0.86, 0.6), rim);
	COLOR = vec4(c.rgb, c.a);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _process(delta: float) -> void:
	if _mirror and _mirror.visible:
		var mat := _mirror.material as ShaderMaterial
		mat.set_shader_parameter("t", float(Time.get_ticks_msec()) / 1000.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		advance()


## Write `t` into `l` the way a brush would: a few characters at a time, the scribe's brush bobbing.
func _write(l: Label, t: String, spr: TextureRect = null) -> void:
	l.text = t
	if _skip or t == "":
		l.visible_ratio = 1.0
		return
	l.visible_ratio = 0.0
	var dur := maxf(0.25, t.length() / WRITE_CPS)
	var elapsed := 0.0
	while elapsed < dur and not _skip:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
		l.visible_ratio = clampf(elapsed / dur, 0.0, 1.0)
		if spr and spr.texture is AtlasTexture:
			(spr.texture as AtlasTexture).region = Rect2(48 * (int(elapsed * 8.0) % 2), 0, 48, 64)
	l.visible_ratio = 1.0
	if spr and spr.texture is AtlasTexture:
		(spr.texture as AtlasTexture).region = Rect2(0, 0, 48, 64)


func _show_intro() -> void:
	_busy = true
	var intro: Dictionary = data.get("intro", {})
	_heading.text = "Asagiri %s  ·  %s" % [Game.player_name, Clock.date_text()]
	await _write(_text, "%d entries." % entries.size())
	await _write(_dosho_line, str(intro.get("dosho", "")), _dosho_spr)
	await _write(_domyo_line, str(intro.get("domyo", "")), _domyo_spr)
	_busy = false


func _show_entry(e: Dictionary) -> void:
	_busy = true
	_stamp.modulate.a = 0.0
	_dosho_line.text = ""
	_domyo_line.text = ""
	_heading.text = "Entry %d of %d" % [index + 1, entries.size()]
	await _write(_text, str(e.get("text", "")))
	await _write(_dosho_line, str(e.get("dosho", "")), _dosho_spr)
	await _write(_domyo_line, str(e.get("domyo", "")), _domyo_spr)
	var v := str(e.get("verdict", "argued"))
	tally[v] = int(tally.get(v, 0)) + 1
	_stamp.text = {"good": "善  ", "bad": "悪  "}.get(v, "") + str(data.get("stamps", {}).get(v, v.to_upper()))
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.rotation = deg_to_rad(-9.0 if v == "good" else (8.0 if v == "bad" else -3.0))
	if _skip:
		_stamp.modulate.a = 1.0
	else:
		Audio.play_sfx("land", 0.0, -4.0)
		_stamp.scale = Vector2.ONE * 1.6
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_stamp, "modulate:a", 1.0, 0.12)
		tw.tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
	_busy = false


func _show_mirror() -> void:
	_busy = true
	_stamp.modulate.a = 0.0
	_text.text = ""
	_heading.text = str(data.get("mirror_title", "THE JOHARI MIRROR"))
	_dosho_line.text = ""
	_domyo_line.text = ""
	_mirror.visible = true
	_mirror_caption.visible = true
	await _write(_mirror_caption, str(data.get("mirror_intro", "")))
	var shots: Array = (Game.flags.get("mirror", []) as Array).duplicate()
	if shots.is_empty():  # no frames kept (an old save): the mirror only remembers in words
		for e in entries:
			if str(e.get("mirror", "")) != "":
				shots.append({"caption": str(e.mirror), "path": ""})
	_write(_dosho_line, str(data.get("mirror_dosho", "")))
	_write(_domyo_line, str(data.get("mirror_domyo", "")))
	if shots.is_empty():
		_mirror.texture = _mist()
		await _write(_mirror_caption, str(data.get("mirror_empty", "")))
	for s in shots:
		if _skip:
			break
		var tex: Texture2D = _mist()
		var path := str(s.get("path", ""))
		var aspect := 1.6
		if path != "" and FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img:
				tex = ImageTexture.create_from_image(img)
				aspect = float(img.get_width()) / maxf(1.0, float(img.get_height()))
		_mirror.texture = tex
		(_mirror.material as ShaderMaterial).set_shader_parameter("aspect", aspect)
		_mirror.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_mirror, "modulate:a", 1.0, 0.35)
		await _write(_mirror_caption, "Day %d - %s" % [int(s.get("day", Clock.day())), str(s.get("caption", ""))] if s.has("day") else str(s.get("caption", "")))
		await get_tree().create_timer(1.4, true, false, true).timeout
		if not is_inside_tree():
			return
	_busy = false


func _mist() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.62, 0.78))
	g.set_color(1, Color(0.16, 0.18, 0.3))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.width = 256
	gt.height = 160
	return gt


func _show_tally() -> void:
	_busy = true
	_mirror.visible = false
	_mirror_caption.visible = false
	_stamp.modulate.a = 0.0
	_heading.text = "Totals"
	var lines: Array[String] = ["Good deeds: %d    Bad deeds: %d    Undecided: %d" % [int(tally.good), int(tally.bad), int(tally.argued)]]
	var rel: Array[String] = []
	var c: Dictionary = Amane.st()["closeness"]
	for who in c:
		if int(c[who]) >= 20:
			rel.append("%s (%s)" % [str(who).split(" ")[-1], "close" if int(c[who]) >= 45 else "friendly"])
	if not rel.is_empty():
		lines.append("People who will remember you: " + ", ".join(rel.slice(0, 6)))
	lines.append("Written into Enma's Ledger. The next episode will read it.")
	await _write(_text, "\n\n".join(lines))
	var outro: Dictionary = data.get("outro", {})
	await _write(_dosho_line, str(outro.get("dosho", "")), _dosho_spr)
	await _write(_domyo_line, str(outro.get("domyo", "")), _domyo_spr)
	_next.text = str(data.get("close", "Close the ledger")).to_upper()
	_busy = false


## Next step (NEXT button, tap, A). While a line is still being written, finish it instead.
func advance() -> void:
	if _busy:
		return
	match stage:
		"intro", "entry":
			index += 1
			if index < entries.size():
				stage = "entry"
				await _show_entry(entries[index])
			else:
				stage = "mirror"
				await _show_mirror()
		"mirror":
			stage = "tally"
			await _show_tally()
		"tally":
			stage = "done"
			closed.emit()


## Write every remaining entry at once (tallies included) and jump to the totals.
func skip_all() -> void:
	_skip = true
	while stage != "tally" and stage != "done":
		while _busy:
			await get_tree().process_frame
		await advance()
	_skip = false
