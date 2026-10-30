extends Node

const GOLD := Color("e7b84a")
var mode := "offline"
var player_name := "لاعب"
var world_seed := 1337
var font: Font

# تعريف كل العناصر: n=الاسم c=اللون t=النوع
const ITEMS := {
	1: {"n": "عشب", "c": Color(0.40, 0.46, 0.22), "t": "block"},
	2: {"n": "تراب", "c": Color(0.47, 0.33, 0.20), "t": "block"},
	3: {"n": "حجر", "c": Color(0.50, 0.50, 0.53), "t": "block"},
	4: {"n": "رمل", "c": Color(0.86, 0.76, 0.52), "t": "block"},
	5: {"n": "خشب", "c": Color(0.45, 0.30, 0.15), "t": "block"},
	6: {"n": "سعف", "c": Color(0.20, 0.52, 0.22), "t": "block"},
	7: {"n": "لبن", "c": Color(0.78, 0.60, 0.38), "t": "block"},
	8: {"n": "بلاط", "c": Color(0.70, 0.66, 0.58), "t": "block"},
	9: {"n": "فيروز", "c": Color(0.17, 0.64, 0.62), "t": "block"},
	10: {"n": "ذهب", "c": Color(0.95, 0.75, 0.20), "t": "block"},
	100: {"n": "معول", "c": Color(0.55, 0.58, 0.65), "t": "tool", "dmg": 2.0},
	101: {"n": "سيف", "c": Color(0.75, 0.78, 0.90), "t": "weapon", "dmg": 5.0},
	102: {"n": "قوس", "c": Color(0.55, 0.35, 0.15), "t": "bow"},
	103: {"n": "سهم", "c": Color(0.85, 0.80, 0.70), "t": "ammo"},
	104: {"n": "تمر", "c": Color(0.40, 0.20, 0.10), "t": "food", "heal": 4.0},
}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0d0a1f"))
	_load_font()

func _load_font() -> void:
	for p in ["res://assets/fonts/arabic.ttf", "res://assets/fonts/arabic.otf"]:
		if ResourceLoader.exists(p):
			font = load(p)
			return
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Noto Sans Arabic", "Noto Naskh Arabic", "Cairo", "Droid Arabic Naskh", "Tahoma", "Arial", "Roboto"])
	sf.allow_system_fallback = true
	font = sf

func apply_theme(c: Control) -> void:
	var t := Theme.new()
	if font:
		t.default_font = font
	t.default_font_size = 28
	c.theme = t

func go(path: String) -> void:
	get_tree().change_scene_to_file(path)

func sbox(bg: Color, border: Color, radius: int, margin: int = 28) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = 14 if margin > 12 else 6
	s.content_margin_bottom = 14 if margin > 12 else 6
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	return s

func bar_style(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(10)
	return s

func style_button(b: Button, round_btn := false) -> void:
	var r := 60 if round_btn else 20
	var m := 10 if round_btn else 28
	b.add_theme_stylebox_override("normal", sbox(Color("2a1b54"), GOLD, r, m))
	b.add_theme_stylebox_override("hover", sbox(Color("3d2a78"), GOLD, r, m))
	b.add_theme_stylebox_override("pressed", sbox(GOLD, Color.WHITE, r, m))
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
