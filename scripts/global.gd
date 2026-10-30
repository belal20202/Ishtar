extends Node

const GOLD := Color("e7b84a")
var mode := "offline"
var player_name := "لاعب"
var world_seed := 1337
var font: Font

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0d0a1f"))
	if ResourceLoader.exists("res://assets/fonts/arabic.ttf"):
		font = load("res://assets/fonts/arabic.ttf")

func apply_theme(c: Control) -> void:
	var t := Theme.new()
	if font:
		t.default_font = font
	t.default_font_size = 28
	c.theme = t

func go(path: String) -> void:
	get_tree().change_scene_to_file(path)

func sbox(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	return s

func style_button(b: Button, round_btn := false) -> void:
	var r := 60 if round_btn else 20
	b.add_theme_stylebox_override("normal", sbox(Color("2a1b54"), GOLD, r))
	b.add_theme_stylebox_override("hover", sbox(Color("3d2a78"), GOLD, r))
	b.add_theme_stylebox_override("pressed", sbox(GOLD, Color.WHITE, r))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("fff3d6"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("1a1033"))
	b.add_theme_font_size_override("font_size", 30)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(0.94, 0.94), 0.08))
	b.button_up.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))

func make_flag() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	for c in [Color("ce1126"), Color.WHITE, Color("111111")]:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(54, 12)
		v.add_child(r)
	return v
