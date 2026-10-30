extends Node3D

const CS := 16
const NC := 6
const W := CS * NC
const H := 40
const BASE := 14
const REACH := 6.0
const HOTBAR := [7, 8, 4, 3, 5, 9, 10]
const COLORS := {
	1: Color(0.40, 0.46, 0.22), 2: Color(0.47, 0.33, 0.20), 3: Color(0.50, 0.50, 0.53),
	4: Color(0.86, 0.76, 0.52), 5: Color(0.45, 0.30, 0.15), 6: Color(0.20, 0.52, 0.22),
	7: Color(0.78, 0.60, 0.38), 8: Color(0.70, 0.66, 0.58), 9: Color(0.17, 0.64, 0.62),
	10: Color(0.95, 0.75, 0.20),
}
const FACE_N := [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const FACE_V := [
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	[Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)],
]
const FACE_SHADE := [1.0, 0.5, 0.8, 0.8, 0.65, 0.65]

var blocks := PackedByteArray()
var chunks := {}
var mat: StandardMaterial3D
var player: CharacterBody3D
var cam: Camera3D
var pitch := 0.0
var selected := 0
var world_ready := false
var touch := false
var hud: Control
var joy_ui: Control
var wait_label: Label
var hotbar_btns: Array[Button] = []
var joy_id := -1
var look_id := -1
var joy_center := Vector2.ZERO
var joy_vec := Vector2.ZERO
var jump_held := false

func _ready() -> void:
	touch = DisplayServer.is_touchscreen_available()
	_setup_ui()
	await get_tree().process_frame
	blocks.resize(W * W * H)
	_generate()
	_build_city()
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	_setup_env()
	for cx in NC:
		for cz in NC:
			_build_chunk(cx, cz)
			await get_tree().process_frame
	_setup_player()
	wait_label.queue_free()
	world_ready = true

# ---------------- العالم ----------------
func get_block(x: int, y: int, z: int) -> int:
	if y < 0:
		return 3
	if y >= H:
		return 0
	if x < 0 or z < 0 or x >= W or z >= W:
		return 3
	return blocks[x + z * W + y * W * W]

func set_block(x: int, y: int, z: int, id: int) -> void:
	if y < 0 or y >= H or x < 0 or z < 0 or x >= W or z >= W:
		return
	blocks[x + z * W + y * W * W] = id

func _generate() -> void:
	var n := FastNoiseLite.new()
	n.seed = Global.world_seed
	n.frequency = 0.018
	var rng := RandomNumberGenerator.new()
	rng.seed = Global.world_seed
	var palms: Array[Vector3i] = []
	for x in W:
		for z in W:
			var h := BASE + int(n.get_noise_2d(x, z) * 7.0)
			var sandy := h <= BASE - 2
			for y in h + 1:
				var id := 3
				if y == h:
					id = 4 if sandy else 1
				elif y >= h - 3 and y > 0:
					id = 4 if sandy else 2
				set_block(x, y, z, id)
			if x > 3 and z > 3 and x < W - 4 and z < W - 4 and rng.randf() < 0.012:
				palms.append(Vector3i(x, h + 1, z))
	for p in palms:
		_palm(p.x, p.y, p.z)

func _palm(x: int, y: int, z: int) -> void:
	var th := 4 + (x + z) % 2
	for i in th:
		set_block(x, y + i, z, 5)
	var top := y + th
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		set_block(x + d.x, top, z + d.y, 6)
		set_block(x + d.x * 2, top, z + d.y * 2, 6)
		set_block(x + d.x * 2, top - 1, z + d.y * 2, 6)
	set_block(x, top, z, 6)
	set_block(x, top + 1, z, 6)

func _build_city() -> void:
	var c := W / 2
	for x in range(c - 22, c + 23):
		for z in range(c - 22, c + 23):
			for y in H:
				var id := 0
				if y < BASE - 1:
					id = 3 if y < BASE - 4 else 2
				elif y == BASE - 1:
					id = 8
				set_block(x, y, z, id)
	_house(c - 7, c - 7, 15, 15, 9, true)
	_minaret(c + 9, c - 9, 20)
	_house(c - 19, c + 4, 7, 7, 5, true)
	_house(c + 13, c + 4, 7, 7, 5, true)
	_house(c - 19, c - 12, 7, 7, 5, true)
	_house(c + 13, c - 12, 7, 7, 5, false)

func _house(x0: int, z0: int, w: int, d: int, hgt: int, dome: bool) -> void:
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var edge := x == x0 or x == x0 + w - 1 or z == z0 or z == z0 + d - 1
			for y in range(BASE, BASE + hgt):
				if edge:
					var door := z == z0 + d - 1 and absi(x - (x0 + w / 2)) <= 1 and y < BASE + 3
					var win := y == BASE + 2 and (x + z) % 3 == 0
					set_block(x, y, z, 0 if (door or win) else 7)
			set_block(x, BASE + hgt, z, 7)
	if dome:
		_dome(x0 + w / 2, BASE + hgt + 1, z0 + d / 2, mini(w, d) / 2)

func _dome(cx: int, cy: int, cz: int, r: int) -> void:
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for dy in range(0, r + 1):
				var dist := Vector3(dx, dy, dz).length()
				if dist <= r + 0.5 and dist >= r - 1.0:
					set_block(cx + dx, cy + dy, cz + dz, 9)
	set_block(cx, cy + r + 1, cz, 10)
	set_block(cx, cy + r + 2, cz, 10)

func _minaret(x0: int, z0: int, hgt: int) -> void:
	for x in 3:
		for z in 3:
			for y in hgt:
				set_block(x0 + x, BASE + y, z0 + z, 10 if y == hgt - 4 else 7)
	for x in range(x0 - 1, x0 + 4):
		for z in range(z0 - 1, z0 + 4):
			set_block(x, BASE + hgt, z, 8)
	_dome(x0 + 1, BASE + hgt + 1, z0 + 1, 2)

func _face_color(id: int, f: int, x: int, y: int, z: int) -> Color:
	var c: Color = COLORS[id]
	if id == 1 and f == 0:
		c = Color(0.36, 0.62, 0.25)
	var v := 0.94 + 0.06 * float(((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) & 7) / 7.0
	var s: float = FACE_SHADE[f] * v
	return Color(c.r * s, c.g * s, c.b * s)

func _build_chunk(cx: int, cz: int) -> void:
	var key := Vector2i(cx, cz)
	if chunks.has(key):
		chunks[key].queue_free()
		chunks.erase(key)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for x in range(cx * CS, cx * CS + CS):
		for z in range(cz * CS, cz * CS + CS):
			for y in H:
				var id := get_block(x, y, z)
				if id == 0:
					continue
				for f in 6:
					var n: Vector3i = FACE_N[f]
					if get_block(x + n.x, y + n.y, z + n.z) != 0:
						continue
					var o := verts.size()
					var col := _face_color(id, f, x, y, z)
					for v in FACE_V[f]:
						verts.append(Vector3(x, y, z) + v)
						norms.append(Vector3(n))
						cols.append(col)
					idx.append(o)
					idx.append(o + 1)
					idx.append(o + 2)
					idx.append(o)
					idx.append(o + 2)
					idx.append(o + 3)
	if verts.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	mi.add_child(body)
	add_child(mi)
	chunks[key] = mi

func _setup_env() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3a7bd5")
	sm.sky_horizon_color = Color("f6d7a7")
	sm.ground_horizon_color = Color("f6d7a7")
	sm.ground_bottom_color = Color("c9a66b")
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("f6d7a7")
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.8
	add_child(sun)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	player.add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.55
	cam.fov = 75.0
	cam.near = 0.05
	player.add_child(cam)
	add_child(player)
	_respawn()

func _respawn() -> void:
	player.position = Vector3(W / 2 + 0.5, BASE + 1.5, W / 2 + 14.5)
	player.velocity = Vector3.ZERO

# ---------------- الحركة والتفاعل ----------------
func _physics_process(delta: float) -> void:
	if not world_ready:
		return
	var inp := joy_vec
	if not touch:
		inp = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		jump_held = Input.is_key_pressed(KEY_SPACE)
	var dir := player.global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	player.velocity.x = dir.x * 5.0
	player.velocity.z = dir.z * 5.0
	if player.is_on_floor():
		if jump_held:
			player.velocity.y = 8.5
	else:
		player.velocity.y -= 25.0 * delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x, 1.0, W - 1.0)
	player.position.z = clampf(player.position.z, 1.0, W - 1.0)
	if player.position.y < -20.0:
		_respawn()

func _look(rel: Vector2) -> void:
	player.rotate_y(-rel.x)
	pitch = clampf(pitch - rel.y, -1.5, 1.5)
	cam.rotation.x = pitch

func _unhandled_input(e: InputEvent) -> void:
	if not world_ready:
		return
	var vs := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.position.x < vs.x * 0.4 and joy_id == -1:
				joy_id = e.index
				joy_center = e.position
				joy_vec = Vector2.ZERO
			elif e.position.x >= vs.x * 0.4 and look_id == -1:
				look_id = e.index
		else:
			if e.index == joy_id:
				joy_id = -1
				joy_vec = Vector2.ZERO
			elif e.index == look_id:
				look_id = -1
		joy_ui.queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == joy_id:
			joy_vec = ((e.position - joy_center) / 80.0).limit_length(1.0)
			joy_ui.queue_redraw()
		elif e.index == look_id:
			_look(e.relative * 0.006)
	elif not touch and e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(e.relative * 0.003)
	elif not touch and e is InputEventMouseButton and e.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_break()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_place()
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select((selected - 1 + HOTBAR.size()) % HOTBAR.size())
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select((selected + 1) % HOTBAR.size())
	elif not touch and e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _raycast() -> Dictionary:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var prev := Vector3i(floori(from.x), floori(from.y), floori(from.z))
	var d := 0.0
	while d < REACH:
		var p := from + dir * d
		var cell := Vector3i(floori(p.x), floori(p.y), floori(p.z))
		if get_block(cell.x, cell.y, cell.z) > 0:
			return {"hit": cell, "prev": prev}
		prev = cell
		d += 0.05
	return {}

func _break() -> void:
	var r := _raycast()
	if r.is_empty():
		return
	var c: Vector3i = r.hit
	if c.y > 0:
		_edit(c, 0)

func _place() -> void:
	var r := _raycast()
	if r.is_empty():
		return
	var c: Vector3i = r.prev
	var p := player.position
	if absf(c.x + 0.5 - p.x) < 0.65 and absf(c.z + 0.5 - p.z) < 0.65 and c.y < p.y + 1.8 and c.y + 1 > p.y:
		return
	_edit(c, HOTBAR[selected])

func _edit(c: Vector3i, id: int) -> void:
	set_block(c.x, c.y, c.z, id)
	var todo := {}
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var kx := floori((c.x + dx) / float(CS))
			var kz := floori((c.z + dz) / float(CS))
			if kx >= 0 and kz >= 0 and kx < NC and kz < NC:
				todo[Vector2i(kx, kz)] = true
	for k in todo:
		_build_chunk(k.x, k.y)

# ---------------- الواجهة ----------------
func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Global.apply_theme(hud)
	layer.add_child(hud)
	joy_ui = Control.new()
	joy_ui.anchor_right = 1.0
	joy_ui.anchor_bottom = 1.0
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.draw.connect(_draw_joy)
	hud.add_child(joy_ui)

	wait_label = _hud_label("جارٍ بناء عالم عشتار...", 40)
	var cross := _hud_label("+", 44)
	cross.add_theme_color_override("font_outline_color", Color.BLACK)
	cross.add_theme_constant_override("outline_size", 6)

	var mode_lbl := Label.new()
	mode_lbl.text = "عشتار  ·  " + ("أوفلاين" if Global.mode == "offline" else "أونلاين")
	mode_lbl.position = Vector2(24, 16)
	mode_lbl.add_theme_color_override("font_color", Global.GOLD)
	mode_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	mode_lbl.add_theme_constant_override("outline_size", 6)
	hud.add_child(mode_lbl)

	var back := Button.new()
	back.text = "القائمة"
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -190
	back.offset_right = -20
	back.offset_top = 14
	back.offset_bottom = 74
	Global.style_button(back)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Global.go("res://scenes/menu.tscn"))
	hud.add_child(back)

	var jump := _corner_btn("قفز", 120, 30, 30)
	jump.button_down.connect(func(): jump_held = true)
	jump.button_up.connect(func(): jump_held = false)
	_corner_btn("اكسر", 100, 170, 60).pressed.connect(_break)
	_corner_btn("ضع", 100, 40, 170).pressed.connect(_place)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hb.offset_bottom = -16
	hud.add_child(hb)
	for i in HOTBAR.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.pressed.connect(_select.bind(i))
		hb.add_child(b)
		hotbar_btns.append(b)
	_select(0)

func _hud_label(text: String, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	return l

func _corner_btn(text: String, sz: float, ox: float, oy: float) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -ox - sz
	b.offset_right = -ox
	b.offset_top = -oy - sz
	b.offset_bottom = -oy
	Global.style_button(b, true)
	b.add_theme_font_size_override("font_size", 26)
	hud.add_child(b)
	return b

func _select(i: int) -> void:
	selected = i
	for k in hotbar_btns.size():
		var col: Color = COLORS[HOTBAR[k]]
		var s := Global.sbox(col, Global.GOLD if k == i else Color(0, 0, 0, 0.6), 10)
		s.set_border_width_all(6 if k == i else 2)
		for st in ["normal", "hover", "pressed"]:
			hotbar_btns[k].add_theme_stylebox_override(st, s)

func _draw_joy() -> void:
	if joy_id == -1:
		return
	joy_ui.draw_circle(joy_center, 80.0, Color(1, 1, 1, 0.12))
	joy_ui.draw_arc(joy_center, 80.0, 0.0, TAU, 40, Global.GOLD, 3.0, true)
	joy_ui.draw_circle(joy_center + joy_vec * 80.0, 34.0, Color(1.0, 0.8, 0.3, 0.6))
