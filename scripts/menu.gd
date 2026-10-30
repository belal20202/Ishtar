extends Control

var t := 0.0
var pattern: Control
var toast: Label
var toast_tw: Tween
var btn_count := 0

func _fill(c: Control) -> void:
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	Global.apply_theme(self)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color("1b1040"))
	g.set_color(1, Color("0d0a1f"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_fill(bg)
	add_child(bg)
	pattern = Control.new()
	_fill(pattern)
	pattern.draw.connect(_draw_pattern)
	add_child(pattern)

	var title := Label.new()
	title.text = "عشتار"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 130)
	title.add_theme_color_override("font_color", Global.GOLD)
	title.add_theme_color_override("font_outline_color", Color("3a1a6e"))
	title.add_theme_constant_override("outline_size", 16)
	title.anchor_right = 1.0
	title.anchor_top = 0.03
	title.anchor_bottom = 0.27
	add_child(title)
	var sub := Label.new()
	sub.text = "ISHTAR  ·  عالم المكعبات العراقي"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color("b9a7e6"))
	sub.anchor_right = 1.0
	sub.anchor_top = 0.26
	sub.anchor_bottom = 0.32
	add_child(sub)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.36
	box.anchor_bottom = 0.36
	box.offset_left = -230
	box.offset_right = 230
	box.grow_vertical = Control.GROW_DIRECTION_END
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	_add_btn(box, "العب أوفلاين", _play_offline)
	_add_btn(box, "العب أونلاين", func(): _toast("الأونلاين (Firebase) في المرحلة الثالثة"))
	_add_btn(box, "الإعدادات", func(): _toast("الإعدادات قريباً"))
	_add_btn(box, "خروج", func(): get_tree().quit())

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.anchor_left = 0.3
	foot.anchor_right = 0.7
	foot.anchor_top = 0.92
	foot.anchor_bottom = 0.99
	foot.add_theme_constant_override("separation", 16)
	foot.add_child(Global.make_flag())
	var made := Label.new()
	made.text = "صنع في العراق"
	made.add_theme_font_size_override("font_size", 24)
	foot.add_child(made)
	add_child(foot)

	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_right = 1.0
	toast.anchor_top = 0.85
	toast.anchor_bottom = 0.9
	toast.add_theme_color_override("font_color", Global.GOLD)
	toast.modulate.a = 0.0
	add_child(toast)

	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "scale", Vector2(1.05, 1.05), 1.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)

func _add_btn(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	Global.style_button(b)
	b.pressed.connect(cb)
	b.modulate.a = 0.0
	box.add_child(b)
	create_tween().tween_property(b, "modulate:a", 1.0, 0.35).set_delay(0.15 * btn_count)
	btn_count += 1

func _play_offline() -> void:
	Global.mode = "offline"
	Global.go("res://scenes/game.tscn")

func _toast(msg: String) -> void:
	toast.text = msg
	if toast_tw:
		toast_tw.kill()
	toast_tw = create_tween()
	toast_tw.tween_property(toast, "modulate:a", 1.0, 0.2)
	toast_tw.tween_interval(2.0)
	toast_tw.tween_property(toast, "modulate:a", 0.0, 0.4)

func _process(delta: float) -> void:
	t += delta
	pattern.queue_redraw()

func _draw_pattern() -> void:
	var s := 150.0
	var off := fmod(t * 12.0, s)
	for i in int(pattern.size.x / s) + 3:
		for j in int(pattern.size.y / s) + 3:
			_star(Vector2(i * s - off, j * s - off), 34.0, Color(1.0, 0.8, 0.3, 0.07))

func _star(c: Vector2, r: float, col: Color) -> void:
	for i in 2:
		var pts := PackedVector2Array()
		for k in 5:
			var a := i * PI / 4.0 + k * TAU / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		pattern.draw_polyline(pts, col, 2.0, true)
