extends Control
## Title screen: synthwave sunset, logo, Continue / New Game.

const SLOGANS := [
	"Rain on the 999 steps. Somebody is still waiting.",
	"Don't count the steps after six.",
	"When a cat washes its face, it's going to rain.",
	"A promise is a word with a soul in it.",
	"Tadaima. Okaeri.",
	"Senpai, you came back.",
]

var _slogan: Label
var _slogan_i := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := RetroBackdrop.new()
	bg.mode = "sunset"
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -330
	v.offset_right = 330
	v.offset_top = -330
	v.offset_bottom = 150
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := HUD.make_label("NEKOTSUKI", 96, Color(0.95, 0.76, 0.31))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.24, 0.9, 1.0))
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)
	var sub := HUD.make_label("THE 32ND CENTURY IS UNDER NEW MANAGEMENT", 18, Color(0.6, 0.95, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(Control.new())
	if Game.has_save():
		var cont := _button("CONTINUE", _on_continue)
		v.add_child(cont)
		var info := HUD.make_label(Game.save_summary(Game.AUTOSAVE_SLOT), 14, Color(0.8, 0.8, 1.0))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# A dark plate: the line used to sit straight on the striped sun and was hard to read.
		var plate := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.01, 0.08, 0.82)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		plate.add_theme_stylebox_override("panel", sb)
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate.add_child(info)
		v.add_child(plate)
	v.add_child(_button("NEW GAME", _content_notice))
	var seen: Dictionary = Week.endings_seen()
	if seen.has("_last"):
		var total: int = (Week.endings.get("endings", {}) as Dictionary).size()
		var n := seen.size() - 1
		var last: Dictionary = seen.get(str(seen["_last"]), {})
		var el := HUD.make_label("Endings reached: %d / %d   -   last: %s" % [n, total, str(last.get("title", ""))], 15, Color(1.0, 0.86, 0.6))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(el)
	v.add_child(_button("CREDITS & LICENSES", _show_credits))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		v.add_child(_button("QUIT", func(): get_tree().quit()))
	_slogan = HUD.make_label(SLOGANS[0], 16, Color(1.0, 0.85, 0.3))
	_slogan.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_slogan.offset_top = -44
	_slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_slogan)
	var ver := HUD.make_label("v%s  //  Godot %s" % [ProjectSettings.get_setting("application/config/version", "0"), Engine.get_version_info().string], 12, Color(1, 1, 1, 0.4))
	ver.position = Vector2(10, 8)
	add_child(ver)
	Audio.play_music("suzunari_dusk")
	for c in v.get_children():
		if c is Button:
			_safe_focus.call_deferred(c)
			break
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.autostart = true
	timer.timeout.connect(_next_slogan)
	add_child(timer)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 58)
	b.add_theme_font_size_override("font_size", 24)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		Audio.play_sfx("confirm")
		cb.call())
	return b


func _next_slogan() -> void:
	_slogan_i = (_slogan_i + 1) % SLOGANS.size()
	# Every other slot is a freshly written sponsor message.
	_slogan.text = SLOGANS[_slogan_i] if _slogan_i % 2 == 0 else Copy.make("sponsor_line")


func _on_continue() -> void:
	if Game.load_game():
		Router.continue_run()


## Deferred focus that tolerates the control (or its scene) being freed meanwhile.
func _safe_focus(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree():
		c.grab_focus()


## Credits + the licences we must ship (Godot is MIT and bundles third-party code).
var _credits: PanelContainer


func _show_credits() -> void:
	if _credits:
		_credits.queue_free()
	_credits = PanelContainer.new()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits.offset_left = 60
	_credits.offset_right = -60
	_credits.offset_top = 40
	_credits.offset_bottom = -40
	add_child(_credits)
	var v := VBoxContainer.new()
	_credits.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("normal_font_size", 15)
	t.text = credits_text()
	scroll.add_child(t)
	var back := _button("BACK", func():
		_credits.queue_free()
		_credits = null
		for c in get_children():
			if c is VBoxContainer:
				for b in c.get_children():
					if b is Button:
						_safe_focus.call_deferred(b)
						return)
	v.add_child(back)
	_safe_focus.call_deferred(back)


static func credits_text() -> String:
	var t := "[b][color=#f2c14e]NEKOTSUKI[/color][/b]  v%s\n\n" % ProjectSettings.get_setting("application/config/version", "0")
	t += "Design, code, writing, art, music and sound: the NEKOTSUKI team (engine from ODD-SPACE).\n"
	t += "All characters, art, music and sound are original and generated by the game's own tools.\n"
	t += "Ground, wall, roof and bark textures in Suzunari are pixelized from Poly Haven photo textures (CC0, polyhaven.com):\n"
	t += "  gravel_floor_02, precast_stone_paving, grey_stone_path, rectangular_paving, asphalt_02, leafy_grass,\n"
	t += "  playground_sand, coast_sand_01, wood_floor_worn, grey_roof_tiles(_02), japanese_cedar_planks, hinoki_planks,\n"
	t += "  weathered_plank_siding, white_plaster_02, japanese_stone_wall, concrete_wall_005, japanese_cedar_bark,\n"
	t += "  mossy_rock, forest_leaves_02, rusty_painted_metal, green_metal_rust, distressed_painted_planks,\n"
	t += "  old_sandstone_02, denim_fabric, corrugated_iron_02, lacquered_cherry_wood, linoleum_brown, terrazzo_tiles,\n"
	t += "  floor_tiles_06, long_white_tiles, tatami_mat, plank_flooring_02. Thank you, Poly Haven.\n\n"
	t += "[b][color=#3ee6ff]Made with Godot Engine[/color][/b]\n%s\n\n" % Engine.get_license_text()
	t += "[b][color=#3ee6ff]Third-party components bundled with Godot[/color][/b]\n"
	for c in Engine.get_copyright_info():
		t += "\n[b]%s[/b]\n" % str(c.get("name", ""))
		for part in c.get("parts", []):
			for cr in part.get("copyright", []):
				t += "  (c) %s\n" % str(cr)
			t += "  License: %s\n" % str(part.get("license", ""))
	t += "\n[b][color=#3ee6ff]License texts[/color][/b]\n"
	var lic: Dictionary = Engine.get_license_info()
	for k in lic:
		t += "\n[b]%s[/b]\n%s\n" % [str(k), str(lic[k])]
	return t


## Content notice before a new game (docs/REVIEW.md hard review #4): the game is about an obsessive, jealous
## love that the player can encourage, set boundaries for, or turn down - say so before it starts.
const NOTICE := "CONTENT NOTICE\n\nNEKOTSUKI is a gentle-looking game about an unhealthy kind of love.\n\n" + \
	"A character becomes attached to you to the point of following you, watching who you talk to, crying when you " + \
	"are with others, and making it hard to say no (some answers shrink while he cries). The story shows jealousy, " + \
	"possessiveness and emotional pressure, abandonment, grief, and supernatural harm coming to people around you.\n\n" + \
	"It does not show sexual content, self-harm or gore. Saying no, and setting boundaries, are real choices with " + \
	"their own good ending.\n\nIf something in your own life looks like this, it is not romantic - talk to someone you trust."


func _content_notice() -> void:
	var layer := ColorRect.new()
	layer.color = Color(0.03, 0.02, 0.06, 0.94)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(760, 0)
	box.position -= Vector2(380, 230)
	box.add_theme_constant_override("separation", 18)
	layer.add_child(box)
	var t := HUD.make_label(NOTICE, 19, Color(1.0, 0.94, 0.86))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(760, 0)
	box.add_child(t)
	var go := _button("I UNDERSTAND - START", func(): Router.new_suzunari())
	var back := _button("BACK", func(): layer.queue_free())
	box.add_child(go)
	box.add_child(back)
	go.grab_focus()
