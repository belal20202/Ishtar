extends Node3D

const EnemyScript := preload("res://scripts/enemy.gd")

const CS := 16
const NC := 6
const W := CS * NC
const H := 40
const BASE := 14
const REACH := 6.0
const MAX_HP := 20.0
const SLOTS := 10
const COLORS := {
	1: Color(0.40, 0.46, 0.22), 2: Color(0.47, 0.33, 0.20), 3: Color(0.50, 0.50, 0.53),
	4: Color(0.86, 0.76, 0.52), 5: Color(0.45, 0.30, 0.15), 6: Color(0.20, 0.52, 0.22),
	7: Color(0.78, 0.60, 0.38), 8: Color(0.70, 0.66, 0.58), 9: Color(0.17, 0.64, 0.62),
	10: Color(0.95, 0.75, 0.20),
}
const HARD := {1: 0.6, 2: 0.5, 3: 1.5, 4: 0.5, 5: 1.0, 6: 0.2, 7: 1.2, 8: 1.5, 9: 1.0, 10: 1.5}
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

# الحالة
var hp := MAX_HP
var inv: Array = []
var atk_cd := 0.0
var regen_t := 0.0
var spawn_t := 3.0
var kb := Vector3.ZERO
var arrows: Array = []
var breaking := false
var break_target := Vector3i(-1, -1, -1)
var break_progress := 0.0

# الواجهة
var hud: Control
var joy_ui: Control
var wait_label: Label
var hp_bar: ProgressBar
var flash: ColorRect
var msg_lbl: Label
var msg_tw: Tween
var hotbar_btns: Array[Button] = []
var joy_id := -1
var look_id := -1
var joy_center := Vector2.ZERO
var joy_vec := Vector2.ZERO
var jump_held := false

func _ready() -> void:
	touch = DisplayServer.is_touchscreen_available()
	_setup_ui()
	_init_inv()
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

# ---------------- المخزن ----------------
func _init_inv() -> void:
	inv.clear()
	for i in SLOTS:
		inv.append({"id": 0, "n": 0})
	for p in [[100, 1], [101, 1], [102, 1], [103, 24], [7, 32], [4, 16], [104, 3]]:
		add_item(p[0], p[1])
	_select(0)

func add_item(id: int, n: int) -> void:
	var it: Dictionary = Global.ITEMS[id]
	var stack: bool = it.t in ["block", "ammo", "food"]
	if stack:
		for s in inv:
			if s.id == id:
				s.n += n
				_refresh_hotbar()
				return
	for s in inv:
		if s.id == 0:
			s.id = id
			s.n = n
			_refresh_hotbar()
			return
	_msg("المخزن ممتلئ")

func _find_item(id: int) -> int:
	for i in inv.size():
		if inv[i].id == id:
			return i
	return -1

func _consume(slot: int) -> void:
	inv[slot].n -= 1
	if inv[slot].n <= 0:
		inv[slot] = {"id": 0, "n": 0}
	_refresh_hotbar()

func _held_type() -> String:
	var s: Dictionary = inv[selected]
	if s.id == 0:
		return ""
	return Global.ITEMS[s.id].t

func _select(i: int) -> void:
	selected = i
	_refresh_hotbar()

func _refresh_hotbar() -> void:
	if inv.size() < hotbar_btns.size():
		return
	for k in hotbar_btns.size():
		var s: Dictionary = inv[k]
		var b := hotbar_btns[k]
		var col := Color(0.12, 0.10, 0.20, 0.85)
		var txt := ""
		if s.id != 0:
			var it: Dictionary = Global.ITEMS[s.id]
			col = it.c
			txt = it.n
			if it.t in ["block", "ammo", "food"]:
				txt += "\n" + str(s.n)
		b.text = txt
		var st := Global.sbox(col, Global.GOLD if k == selected else Color(0, 0, 0, 0.6), 10, 4)
		st.set_border_width_all(6 if k == selected else 2)
		for name in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(name, st)

# ---------------- الحركة ----------------
func _physics_process(delta: float) -> void:
	if not world_ready:
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	var inp := joy_vec
	if not touch:
		inp = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		jump_held = Input.is_key_pressed(KEY_SPACE)
	var dir := player.global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	player.velocity.x = dir.x * 5.0 + kb.x
	player.velocity.z = dir.z * 5.0 + kb.z
	kb = kb.move_toward(Vector3.ZERO, 22.0 * delta)
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
	regen_t += delta
	if regen_t >= 3.0:
		regen_t = 0.0
		if hp < MAX_HP:
			hp += 1.0
			hp_bar.value = hp
	_update_break(delta)
	_update_arrows(delta)
	_spawn_logic(delta)

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
	elif not touch and e is InputEventMouseButton:
		if e.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif e.button_index == MOUSE_BUTTON_LEFT:
				_break_down()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				_use()
			elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
				_select((selected - 1 + SLOTS) % SLOTS)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_select((selected + 1) % SLOTS)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_break_up()
	elif not touch and e is InputEventKey and e.pressed:
		if e.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif e.keycode >= KEY_1 and e.keycode <= KEY_9:
			_select(e.keycode - KEY_1)

# ---------------- كسر / ضرب / استخدام ----------------
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

func _break_down() -> void:
	if _attack():
		return
	breaking = true

func _break_up() -> void:
	breaking = false
	break_progress = 0.0
	break_target = Vector3i(-1, -1, -1)
	joy_ui.queue_redraw()

func _attack() -> bool:
	if atk_cd > 0.0:
		return false
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var best = null
	var best_d := 99.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position + Vector3(0, 1.0, 0) - from
		var along := to.dot(dir)
		if along < 0.0 or along > 3.2:
			continue
		var perp := (to - dir * along).length()
		if perp < 0.9 and along < best_d:
			best = e
			best_d = along
	if best == null:
		return false
	var dmg := 1.0
	if _held_type() != "":
		dmg = Global.ITEMS[inv[selected].id].get("dmg", 1.0)
	best.hit(dmg, player.global_position)
	atk_cd = 0.45
	return true

func _update_break(_delta: float) -> void:
	if not breaking:
		return
	var r := _raycast()
	if r.is_empty():
		break_progress = 0.0
		joy_ui.queue_redraw()
		return
	var c: Vector3i = r.hit
	if c.y <= 0:
		return
	if c != break_target:
		break_target = c
		break_progress = 0.0
	var id := get_block(c.x, c.y, c.z)
	var sp := 3.0 if _held_type() == "tool" else 1.0
	break_progress += _delta * sp / float(HARD.get(id, 1.0))
	if break_progress >= 1.0:
		break_progress = 0.0
		if HARD.has(id):
			add_item(id, 1)
		_edit(c, 0)
		break_target = Vector3i(-1, -1, -1)
	joy_ui.queue_redraw()

func _use() -> void:
	match _held_type():
		"block":
			_place()
		"food":
			_eat()
		"bow":
			_shoot()

func _place() -> void:
	var r := _raycast()
	if r.is_empty():
		return
	var c: Vector3i = r.prev
	var p := player.position
	if absf(c.x + 0.5 - p.x) < 0.65 and absf(c.z + 0.5 - p.z) < 0.65 and c.y < p.y + 1.8 and c.y + 1 > p.y:
		return
	_edit(c, inv[selected].id)
	_consume(selected)

func _eat() -> void:
	if hp >= MAX_HP:
		_msg("صحتك كاملة")
		return
	hp = minf(MAX_HP, hp + Global.ITEMS[inv[selected].id].heal)
	hp_bar.value = hp
	_consume(selected)

func _shoot() -> void:
	if atk_cd > 0.0:
		return
	var slot := _find_item(103)
	if slot == -1:
		_msg("لا توجد أسهم")
		return
	_consume(slot)
	atk_cd = 0.6
	var dir := -cam.global_transform.basis.z
	var a := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.7)
	a.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.75, 0.55)
	a.material_override = m
	add_child(a)
	a.global_position = cam.global_position + dir * 0.6
	a.look_at(a.global_position + dir)
	arrows.append({"n": a, "v": dir * 28.0, "life": 3.0})

func _update_arrows(delta: float) -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		var n: Node3D = a.n
		var v: Vector3 = a.v
		v.y -= 9.0 * delta
		a.v = v
		a.life -= delta
		var np := n.global_position + v * delta
		var dead: bool = a.life <= 0.0 or get_block(floori(np.x), floori(np.y), floori(np.z)) > 0
		if not dead:
			for e in get_tree().get_nodes_in_group("enemies"):
				if (np - (e.global_position + Vector3(0, 1.0, 0))).length() < 0.9:
					e.hit(5.0, e.global_position - v)
					dead = true
					break
		if dead:
			n.queue_free()
			arrows.remove_at(i)
		else:
			n.global_position = np
			n.look_at(np + v)

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

# ---------------- الأعداء والصحة ----------------
func _spawn_logic(delta: float) -> void:
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	spawn_t = 4.0
	var es := get_tree().get_nodes_in_group("enemies")
	for e in es:
		if e.global_position.distance_to(player.global_position) > 45.0:
			e.queue_free()
	if es.size() >= 5:
		return
	var a := randf() * TAU
	var d := randf_range(14.0, 24.0)
	var x := clampi(int(player.position.x + cos(a) * d), 2, W - 3)
	var z := clampi(int(player.position.z + sin(a) * d), 2, W - 3)
	if absi(x - W / 2) < 27 and absi(z - W / 2) < 27:
		return
	var y := H - 1
	while y > 0 and get_block(x, y, z) == 0:
		y -= 1
	var en = EnemyScript.new()
	en.setup(self, Vector3(x + 0.5, y + 1.2, z + 0.5))
	add_child(en)

func on_enemy_killed(_e) -> void:
	if randf() < 0.6:
		var n := 1 + randi() % 2
		add_item(104, n)
		_msg("+ تمر × " + str(n))
	if randf() < 0.2:
		add_item(10, 1)

func hurt_player(dmg: float, from: Vector3) -> void:
	hp -= dmg
	var d := player.global_position - from
	d.y = 0.0
	if d.length() > 0.01:
		kb = d.normalized() * 7.0
	player.velocity.y = 4.0
	flash.color.a = 0.4
	create_tween().tween_property(flash, "color:a", 0.0, 0.35)
	hp_bar.value = maxf(hp, 0.0)
	if hp <= 0.0:
		_die()

func _die() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	hp = MAX_HP
	hp_bar.value = hp
	kb = Vector3.ZERO
	_break_up()
	_respawn()
	_msg("سقطت! عدت إلى المدينة")

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

	flash = ColorRect.new()
	flash.color = Color(0.9, 0.1, 0.1, 0.0)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)

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

	hp_bar = ProgressBar.new()
	hp_bar.max_value = MAX_HP
	hp_bar.value = MAX_HP
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(260, 20)
	hp_bar.position = Vector2(24, 72)
	hp_bar.add_theme_stylebox_override("background", Global.bar_style(Color(0, 0, 0, 0.55)))
	hp_bar.add_theme_stylebox_override("fill", Global.bar_style(Color("d63a3a")))
	hud.add_child(hp_bar)

	msg_lbl = Label.new()
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.anchor_right = 1.0
	msg_lbl.anchor_top = 0.14
	msg_lbl.anchor_bottom = 0.2
	msg_lbl.add_theme_color_override("font_color", Global.GOLD)
	msg_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_lbl.add_theme_constant_override("outline_size", 6)
	msg_lbl.modulate.a = 0.0
	msg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(msg_lbl)

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
	var brk := _corner_btn("اكسر", 100, 170, 60)
	brk.button_down.connect(_break_down)
	brk.button_up.connect(_break_up)
	_corner_btn("استخدم", 100, 40, 170).pressed.connect(_use)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hb.offset_bottom = -14
	hud.add_child(hb)
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 66)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color.BLACK)
		b.add_theme_constant_override("outline_size", 5)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_select.bind(i))
		hb.add_child(b)
		hotbar_btns.append(b)

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
	b.add_theme_font_size_override("font_size", 22)
	hud.add_child(b)
	return b

func _msg(text: String) -> void:
	if msg_lbl == null:
		return
	msg_lbl.text = text
	if msg_tw:
		msg_tw.kill()
	msg_tw = create_tween()
	msg_tw.tween_property(msg_lbl, "modulate:a", 1.0, 0.15)
	msg_tw.tween_interval(1.6)
	msg_tw.tween_property(msg_lbl, "modulate:a", 0.0, 0.4)

func _draw_joy() -> void:
	if joy_id != -1:
		joy_ui.draw_circle(joy_center, 80.0, Color(1, 1, 1, 0.12))
		joy_ui.draw_arc(joy_center, 80.0, 0.0, TAU, 40, Global.GOLD, 3.0, true)
		joy_ui.draw_circle(joy_center + joy_vec * 80.0, 34.0, Color(1.0, 0.8, 0.3, 0.6))
	if break_progress > 0.0:
		var c := get_viewport().get_visible_rect().size / 2.0
		joy_ui.draw_arc(c, 34.0, -PI / 2.0, -PI / 2.0 + TAU * break_progress, 32, Color.WHITE, 5.0, true)
