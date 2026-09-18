extends Node
## Игрок, движение, камера, вход/выход из машины.

var jump_requested := false
var cam_yaw := 0.0
var cam_pitch := 0.35
var cam_look := Vector3(9, 1.4, 9)
var drag_idle := 9.0
var mouse_down := false
var aim_held := false
var cam_shake := 0.0
var _walk_phase := 0.0

func _ready() -> void:
	build_player()
	Game.player_died.connect(_on_player_died)
	Game.respawned.connect(_on_respawned)

func build_player() -> void:
	var player = Node3D.new()
	player.position = Vector3(9, 0, 9)
	add_child(player)
	Game.player_node = player
	Game.player_rig = make_human(Color("#5a5648"), Color("#33363c"), Color("#c98d64"), Color("#3a3630"), false)
	player.add_child(Game.player_rig.grp)
	var camera = Camera3D.new()
	camera.fov = 62
	camera.near = 0.1
	camera.far = 3000
	add_child(camera)
	camera.current = true
	Game.camera = camera

func make_human(shirt: Color, pants: Color, skin: Color, cap: Color, armed: bool) -> Dictionary:
	var g = Node3D.new()
	var detail = Node3D.new()
	g.add_child(detail)
	var ms = Game.make_mat(shirt, 0.95)
	var mp = Game.make_mat(pants, 0.95)
	var mk = Game.make_mat(skin, 0.85)
	var lg = BoxMesh.new(); lg.size = Vector3(0.17, 0.78, 0.17)
	var ag = BoxMesh.new(); ag.size = Vector3(0.13, 0.6, 0.13)
	var legL = Node3D.new(); legL.position = Vector3(0.1, 0.8, 0); detail.add_child(legL)
	var legLm = MeshInstance3D.new(); legLm.mesh = lg; legLm.material_override = mp; legLm.position = Vector3(0, -0.39, 0); legL.add_child(legLm)
	var legR = Node3D.new(); legR.position = Vector3(-0.1, 0.8, 0); detail.add_child(legR)
	var legRm = MeshInstance3D.new(); legRm.mesh = lg; legRm.material_override = mp; legRm.position = Vector3(0, -0.39, 0); legR.add_child(legRm)
	var torso = MeshInstance3D.new(); var tb = BoxMesh.new(); tb.size = Vector3(0.42, 0.56, 0.24)
	torso.mesh = tb; torso.material_override = ms; torso.position = Vector3(0, 1.08, 0); detail.add_child(torso)
	var armL = Node3D.new(); armL.position = Vector3(0.28, 1.32, 0); detail.add_child(armL)
	var armLm = MeshInstance3D.new(); armLm.mesh = ag; armLm.material_override = ms; armLm.position = Vector3(0, -0.3, 0); armL.add_child(armLm)
	var armR = Node3D.new(); armR.position = Vector3(-0.28, 1.32, 0); detail.add_child(armR)
	var armRm = MeshInstance3D.new(); armRm.mesh = ag; armRm.material_override = ms; armRm.position = Vector3(0, -0.3, 0); armR.add_child(armRm)
	var head = MeshInstance3D.new(); var hg = BoxMesh.new(); hg.size = Vector3(0.25, 0.27, 0.25)
	head.mesh = hg; head.material_override = mk; head.position = Vector3(0, 1.53, 0); detail.add_child(head)
	if cap != Color.BLACK:
		var cap_mesh = MeshInstance3D.new(); var cg = BoxMesh.new(); cg.size = Vector3(0.28, 0.08, 0.3)
		cap_mesh.mesh = cg; cap_mesh.material_override = Game.make_mat(cap, 0.95); cap_mesh.position = Vector3(0, 1.7, 0); detail.add_child(cap_mesh)
	if armed:
		var gun = MeshInstance3D.new(); var gg = BoxMesh.new(); gg.size = Vector3(0.05, 0.09, 0.26)
		gun.mesh = gg; gun.material_override = Game.make_mat(Color("#1e2126"), 0.5, 0.4); gun.position = Vector3(0, -0.55, 0.1); armR.add_child(gun)
	var simple = MeshInstance3D.new(); var sb = BoxMesh.new(); sb.size = Vector3(0.46, 1.62, 0.3)
	simple.mesh = sb; simple.material_override = ms; simple.position.y = 0.86; simple.visible = false; g.add_child(simple)
	return {"grp": g, "detail": detail, "simple": simple, "legL": legL, "legR": legR, "armL": armL, "armR": armR, "wGrp": null}

func _input(event: InputEvent) -> void:
	if not Game.playing:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if mouse_down or aim_held:
			cam_yaw -= event.relative.x * 0.0052
			cam_pitch = clamp(cam_pitch + event.relative.y * 0.0035, -1.3, 1.3)
			drag_idle = 0
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = event.pressed
		if event.button_index == MOUSE_BUTTON_RIGHT:
			aim_held = event.pressed
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and not event.echo:
			jump_requested = true
		if event.keycode == KEY_E:
			if Game.in_car != null:
				exit_car(false)
			else:
				try_enter()

func _process(dt: float) -> void:
	if not Game.playing:
		update_intro_camera(dt)
		return
	if not (Game.dead or Game.arrested or not Game.missions.cutscene.is_empty()):
		if Game.in_car != null:
			update_driving(dt)
		else:
			update_foot(dt)
	update_camera(dt)

func update_foot(dt: float) -> void:
	var ix = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	var iz = (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
	var fx = sin(cam_yaw)
	var fz = cos(cam_yaw)
	var rx = -fz
	var rz = fx
	var mxx = fx * iz + rx * ix
	var mz = fz * iz + rz * ix
	var ml = sqrt(mxx * mxx + mz * mz)
	var aiming = Game.weapons.aiming if Game.weapons != null else false
	var sprint = Input.is_key_pressed(KEY_SHIFT) and not aiming
	var sp = (7.4 if sprint else 3.7) * (0.55 if aiming else 1.0)
	if ml > 0:
		mxx /= ml
		mz /= ml
		Game.player_pos.x += mxx * sp * dt
		Game.player_pos.z += mz * sp * dt
	Game.player_pos = Game.collide_circle(Game.player_pos, 0.42)
		# машины непроницаемы пешком + урон от наезда трафика
	for c in Game.cars:
		var cdx = Game.player_pos.x - c.x
		var cdz = Game.player_pos.z - c.z
		var cd2 = cdx * cdx + cdz * cdz
		var crr = 2.35
		if cd2 >= crr * crr or cd2 < 0.0001:
			continue
		var cd = sqrt(cd2)
		var cpush = (crr - cd) / cd
		Game.player_pos.x += cdx * cpush
		Game.player_pos.z += cdz * cpush
		var cs = sqrt(c.vel.x * c.vel.x + c.vel.z * c.vel.z)
		if c != Game.in_car and cs > 6.0 and c.hit_cd <= 0.0:
			c.hit_cd = 0.8
			Game.damage_player(cs * 0.7, "car")
			Game.player_pos.x += c.vel.x * 0.15
			Game.player_pos.z += c.vel.z * 0.15
			cam_shake = min(1.0, cs / 20.0)
	if jump_requested and Game.player_py <= 0.001 and Game.player_vy == 0:
		Game.player_vy = 5.4
	jump_requested = false
	Game.player_vy -= 14.0 * dt
	Game.player_py = max(0.0, Game.player_py + Game.player_vy * dt)
	if Game.player_py == 0:
		Game.player_vy = max(0.0, Game.player_vy)
	var gun = Game.weapons.cur_w > 0 if Game.weapons != null else false
	if gun:
		Game.player_heading = Game.ang_lerp(Game.player_heading, cam_yaw, 14.0 * dt)
	elif ml > 0:
		Game.player_heading = Game.ang_lerp(Game.player_heading, atan2(mxx, mz), 12.0 * dt)
	if Game.player_regen_t > 0:
		Game.player_regen_t -= dt
	elif Game.player_hp < 100:
		Game.player_hp = min(100.0, Game.player_hp + 6.0 * dt)
	if ml > 0:
		_walk_phase += sp * dt * 1.55
	animate_walk(ml, sp, aiming, gun)
	Game.player_node.position = Vector3(Game.player_pos.x, Game.player_py, Game.player_pos.z)
	Game.player_rig.grp.position = Vector3(0, Game.player_py, 0)
	Game.player_rig.grp.rotation.y = Game.player_heading

func animate_walk(ml: float, sp: float, aiming: bool, gun: bool) -> void:
	var rig = Game.player_rig
	var s = sin(_walk_phase)
	var s2 = sin(_walk_phase + PI)
	var amp = clamp(sp / 5.0, 0.35, 1.0) if ml > 0 else 0.0
	rig.legL.rotation.x = s * 0.75 * amp
	rig.legR.rotation.x = s2 * 0.75 * amp
	if gun:
		rig.armR.rotation.x = -1.52 if aiming else -1.05
		rig.armR.rotation.z = -0.12
		rig.armL.rotation.x = -1.25 if aiming else s2 * 0.3 * amp
	else:
		rig.armL.rotation.x = s * 0.6 * amp
		rig.armR.rotation.x = s2 * 0.6 * amp
		rig.armL.rotation.z = 0
		rig.armR.rotation.z = 0

func update_driving(dt: float) -> void:
	var c = Game.in_car
	var thr = 1.0 if Input.is_key_pressed(KEY_W) else 0.0
	var brk = 1.0 if Input.is_key_pressed(KEY_S) else 0.0
	var hb = 1.0 if Input.is_key_pressed(KEY_SPACE) else 0.0
	var steer = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	Game.vehicles.drive_car(c, thr, brk, hb, steer, dt)
	Game.vehicles.car_world_collide(c)
	Game.vehicles.resolve_car_vs_cars(c)
	c.spin_v = c.vel.x * sin(c.heading) + c.vel.z * cos(c.heading)
	var spd = sqrt(c.vel.x * c.vel.x + c.vel.z * c.vel.z)
	if spd > 5:
		var fwd = Vector3(sin(c.heading), 0, cos(c.heading))
		for p in Game.peds.duplicate():
			if p.state != "dead" and Vector3(p.x, 0, p.z).distance_to(Vector3(c.x, 0, c.z)) < 1.8:
				Game.combat.kill_ped(p, "car", fwd.x, fwd.z, spd / 4.0)
	Game.player_pos.x = c.x
	Game.player_pos.z = c.z
	Game.player_node.position = Vector3(c.x, 1.2, c.z)

func update_camera(dt: float) -> void:
	drag_idle += dt
	var foc = Game.get_focus_pos()
	if Game.in_car != null and drag_idle > 0.7:
		cam_yaw = Game.ang_lerp(cam_yaw, Game.in_car.heading, 1.4 * dt)
	var spd = sqrt(Game.in_car.vel.x * Game.in_car.vel.x + Game.in_car.vel.z * Game.in_car.vel.z) if Game.in_car != null else 0.0
	var dist = 0.0
	var hgt = 0.0
	var fov_t = 0.0
	var aiming = Game.weapons.aiming if Game.weapons != null else false
	var zoom = Game.weapons.zoom_cur() if Game.weapons != null else 1.0
	if Game.in_car != null:
		dist = min(13.0, 7.0 + spd * 0.08)
		hgt = 2.6 + spd * 0.02
		fov_t = 62.0 * zoom if aiming else (62.0 + spd * 0.3)
		if aiming:
			dist *= 0.85
	elif aiming:
		dist = 2.1
		hgt = 1.75
		fov_t = 62.0 * zoom
	else:
		dist = 5.2
		hgt = dist * sin(cam_pitch) + 0.6
		fov_t = 62.0
	var hd = dist if Game.in_car != null else dist * cos(cam_pitch)
	var fx = sin(cam_yaw)
	var fz = cos(cam_yaw)
	var tx = foc.x - fx * hd
	var tz = foc.z - fz * hd
	var ty = foc.y + hgt
	if aiming and Game.in_car == null:
		tx += -fz * 0.55
		tz += fx * 0.55
	var k = 1.0 - exp(-8.0 * dt)
	var cam = Game.camera
	cam.position.x += (tx - cam.position.x) * k
	cam.position.y += (ty - cam.position.y) * k
	cam.position.z += (tz - cam.position.z) * k
	if cam.position.y < 0.5:
		cam.position.y = 0.5
	if cam_shake > 0.001:
		cam.position.x += Game.rf(-1, 1) * cam_shake * 0.35
		cam.position.y += Game.rf(-1, 1) * cam_shake * 0.25
		cam.position.z += Game.rf(-1, 1) * cam_shake * 0.35
		cam_shake *= exp(-5.0 * dt)
	var ld = 4.0 if Game.in_car != null else (9.0 if aiming else 1.4)
	var look_target = Vector3(foc.x + fx * ld, foc.y + (1.62 if aiming else 1.45), foc.z + fz * ld)
	cam_look = cam_look.lerp(look_target, k)
	cam.look_at(cam_look)
	var fov_kick = Game.weapons.fov_kick if Game.weapons != null else 0.0
	cam.fov += ((fov_t + fov_kick * 3.0) - cam.fov) * min(1.0, 10.0 * dt)

func update_intro_camera(dt: float) -> void:
	cam_yaw += dt * 0.06
	Game.camera.position = Vector3(sin(cam_yaw) * 210, 105, cos(cam_yaw) * 210)
	Game.camera.look_at(Vector3(0, 20, 0))

func try_enter() -> void:
	var best = null
	var bd = 4.0
	for c in Game.cars:
		if c.mode == "wreck" or c == Game.in_car:
			continue
		var dx = c.x - Game.player_pos.x
		var dz = c.z - Game.player_pos.z
		var d = sqrt(dx * dx + dz * dz)
		if d < bd:
			bd = d
			best = c
	if best == null:
		return
	var spd = sqrt(best.vel.x * best.vel.x + best.vel.z * best.vel.z)
	if spd > 3.0 and best.driver_node != null:
		Game.peds_m.eject_driver_as_fleeing_ped(best)
		Game.toast("Водитель выброшен!", false)
	if best.driver_node != null and is_instance_valid(best.driver_node.node):
		best.driver_node.node.queue_free()
	best.driver_node = null
	Game.in_car = best
	Game.vehicles.ai_cars.erase(best)
	Game.police.police_cars.erase(best)
	if best.is_police:
		best.is_police = false
		Game.add_wanted(1)
		Game.toast("Угнана полицейская машина!", true)
	best.mode = "player"
	Game.player_rig.grp.visible = false
	Game.player_entered_car.emit(best)

func exit_car(forced: bool) -> void:
	if Game.in_car == null:
		return
	var c = Game.in_car
	Game.in_car = null
	if c.mode == "player":
		c.mode = "parked"
	c.vel = Vector3.ZERO
	c.spin_v = 0
	var f = Vector3(sin(c.heading), 0, cos(c.heading))
	var r = Vector3(-f.z, 0, f.x)
	var spots = [[r.x * 2.4, r.z * 2.4], [-r.x * 2.4, -r.z * 2.4], [-f.x * 3.4, -f.z * 3.4], [f.x * 3.4, f.z * 3.4]]
	var px = c.x + r.x * 2.4
	var pz = c.z + r.z * 2.4
	for s in spots:
		if forced or Game.point_free(c.x + s[0], c.z + s[1], 0.5):
			px = c.x + s[0]
			pz = c.z + s[1]
			break
	Game.player_pos.x = clamp(px, -Game.HALF + 1, Game.HALF - 1)
	Game.player_pos.z = clamp(pz, -Game.HALF + 1, Game.HALF - 1)
	Game.player_py = 0
	Game.player_vy = 0
	Game.player_rig.grp.visible = true
	Game.player_node.position = Vector3(Game.player_pos.x, Game.player_py, Game.player_pos.z)
	Game.player_exited_car.emit()

func _on_player_died() -> void:
	Game.player_rig.grp.visible = false
	Game.combat.spawn_player_ragdoll()

func _on_respawned() -> void:
	Game.player_rig.grp.visible = true
	Game.player_node.position = Vector3(Game.player_pos.x, Game.player_py, Game.player_pos.z)
