extends CharacterBody3D

var game
var hp := 12.0
var speed := 2.8
var atk_cd := 0.0
var t := 0.0
var hurt_t := 0.0
var kb := Vector3.ZERO
var model: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var mats: Array = []

func setup(g, pos: Vector3) -> void:
	game = g
	position = pos
	add_to_group("enemies")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = Node3D.new()
	add_child(model)
	_build()

func _part(parent: Node3D, size: Vector3, pos: Vector3, col: Color, glow := false) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mats.append([m, col])
	mi.material_override = m
	parent.add_child(mi)

func _limb(x: float, y: float, size: Vector3, col: Color) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(x, y, 0.0)
	model.add_child(p)
	_part(p, size, Vector3(0.0, -size.y / 2.0, 0.0), col)
	return p

func _build() -> void:
	var skin := Color(0.72, 0.20, 0.15)
	var cloth := Color(0.15, 0.12, 0.20)
	var gold := Color(0.90, 0.70, 0.20)
	_part(model, Vector3(0.6, 0.8, 0.32), Vector3(0, 1.0, 0), cloth)
	_part(model, Vector3(0.64, 0.12, 0.36), Vector3(0, 0.66, 0), gold)
	_part(model, Vector3(0.52, 0.52, 0.52), Vector3(0, 1.72, 0), skin)
	_part(model, Vector3(0.10, 0.25, 0.10), Vector3(-0.18, 2.12, 0), Color(0.1, 0.1, 0.1))
	_part(model, Vector3(0.10, 0.25, 0.10), Vector3(0.18, 2.12, 0), Color(0.1, 0.1, 0.1))
	_part(model, Vector3(0.10, 0.08, 0.05), Vector3(-0.13, 1.76, -0.27), Color(1, 0.9, 0.2), true)
	_part(model, Vector3(0.10, 0.08, 0.05), Vector3(0.13, 1.76, -0.27), Color(1, 0.9, 0.2), true)
	arm_l = _limb(-0.40, 1.38, Vector3(0.2, 0.7, 0.2), skin)
	arm_r = _limb(0.40, 1.38, Vector3(0.2, 0.7, 0.2), skin)
	leg_l = _limb(-0.16, 0.6, Vector3(0.24, 0.6, 0.24), cloth)
	leg_r = _limb(0.16, 0.6, Vector3(0.24, 0.6, 0.24), cloth)

func _physics_process(delta: float) -> void:
	if game == null or game.player == null or not game.world_ready:
		return
	t += delta
	atk_cd = maxf(0.0, atk_cd - delta)
	var to: Vector3 = game.player.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	var dir := Vector3.ZERO
	var moving := false
	if dist < 24.0 and dist > 1.1:
		dir = flat.normalized()
		moving = true
	if dist > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-flat.x, -flat.z), 8.0 * delta)
	velocity.x = dir.x * speed + kb.x
	velocity.z = dir.z * speed + kb.z
	kb = kb.move_toward(Vector3.ZERO, 18.0 * delta)
	if is_on_floor():
		if is_on_wall() and moving:
			velocity.y = 7.5
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()
	if dist < 1.6 and absf(to.y) < 2.0 and atk_cd <= 0.0:
		atk_cd = 1.0
		game.hurt_player(3.0, global_position)
	# أنيميشن المشي والهجوم
	var sw := sin(t * 9.0) * (0.9 if moving else 0.0)
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	var arms := 1.4 if moving else 0.0
	arm_l.rotation.x = arms + sw * 0.25
	arm_r.rotation.x = arms - sw * 0.25
	hurt_t = maxf(0.0, hurt_t - delta)
	for m in mats:
		m[0].albedo_color = Color.WHITE if hurt_t > 0.0 else m[1]

func hit(dmg: float, from: Vector3) -> void:
	hp -= dmg
	hurt_t = 0.18
	var d := global_position - from
	d.y = 0.0
	if d.length() > 0.01:
		kb = d.normalized() * 7.0
	velocity.y = 4.0
	if hp <= 0.0:
		game.on_enemy_killed(self)
		queue_free()
