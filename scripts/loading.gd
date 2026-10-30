extends Control

const TIPS := ["جارٍ تجهيز أرض الرافدين...", "نبني الزقورات والقباب...", "نزرع النخيل على ضفاف دجلة...", "عشتار تفتح أبوابها..."]
var t := 0.0
var bar: ProgressBar
var tip: Label

func _ready() -> void:
	Global.apply_theme(self)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var title := _label("عشتار", 110, Global.GOLD, 0.0, 0.50, 1.0, 0.70)
	title.add_theme_color_override("font_outline_color", Color("3a1a6e"))
	title.add_theme_constant_override("outline_size", 14)
	_label("ISHTAR", 28, Color("b9a7e6"), 0.0, 0.69, 1.0, 0.75)
	tip = _label(TIPS[0], 26, Color("e8def8"), 0.0, 0.76, 1.0, 0.82)

	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.anchor_left = 0.25
	bar.anchor_right = 0.75
	bar.anchor_top = 0.86
	bar.anchor_bottom = 0.86
	bar.offset_bottom = 22
	bar.add_theme_stylebox_override("background", Global.sbox(Color("1b1040"), Color("5b4a99"), 12))
	var fill := Global.sbox(Global.GOLD, Global.GOLD, 12)
	fill.shadow_size = 0
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)

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
	made.add_theme_font_size_override("font_size", 26)
	made.add_theme_color_override("font_color", Color.WHITE)
	foot.add_child(made)
	add_child(foot)

	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "scale", Vector2(1.06, 1.06), 1.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	var tw := create_tween()
	for i in 4:
		tw.tween_callback(func(): tip.text = TIPS[i])
		tw.tween_property(bar, "value", 25.0 * (i + 1), 0.8).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(Global.go.bind("res://scenes/menu.tscn"))

func _label(text: String, fs: int, col: Color, l: float, tp: float, r: float, b: float) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.anchor_left = l
	lb.anchor_top = tp
	lb.anchor_right = r
	lb.anchor_bottom = b
	add_child(lb)
	return lb

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.27)
	var r := minf(size.x, size.y) * 0.17
	for i in 2:
		var pts := PackedVector2Array()
		for k in 5:
			var a := t * (0.6 if i == 0 else -0.6) + i * PI / 4.0 + k * TAU / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Global.GOLD, 5.0, true)
	draw_arc(c, r * 0.55, 0.0, TAU, 48, Color("b9a7e6"), 3.0, true)
	draw_circle(c, r * 0.12 + sin(t * 3.0) * 4.0, Global.GOLD)
