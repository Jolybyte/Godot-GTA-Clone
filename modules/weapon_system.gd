extends Node
# Оружие, стрельба, перезарядка, прицел, визуальная отдача, гильзы.

const WEAPONS = [
	{"name": "КУЛАКИ", "type": "melee", "dmg": 12, "rate": 2.2, "range": 1.7, "mag": 0},
	{"name": "НОЖ", "type": "melee", "dmg": 34, "rate": 2.6, "range": 1.9, "mag": 0},
	{"name": "БИТА", "type": "melee", "dmg": 46, "rate": 1.6, "range": 2.4, "mag": 0},
	{"name": "ПИСТОЛЕТ", "type": "gun", "dmg": 26, "rate": 3.2, "spread": 0.012, "range": 120, "auto": false, "mag": 12, "reload": 1.1, "zoom": 0.55},
	{"name": "УЗИ", "type": "gun", "dmg": 13, "rate": 11, "spread": 0.035, "range": 70, "auto": true, "mag": 30, "reload": 1.6, "zoom": 0.5},
	{"name": "ДРОБОВИК", "type": "gun", "dmg": 14, "rate": 1.1, "spread": 0.07, "range": 34, "auto": false, "mag": 6, "reload": 2.2, "zoom": 0.45, "pellets": 7},
	{"name": "АВТОМАТ", "type": "gun", "dmg": 20, "rate": 8.5, "spread": 0.02, "range": 150, "auto": true, "mag": 30, "reload": 1.9, "zoom": 0.6},
	{"name": "СНАЙПЕРКА", "type": "gun", "dmg": 120, "rate": 0.8, "spread": 0.002, "range": 500, "auto": false, "mag": 5, "reload": 2.6, "zoom": 0.12},
	{"name": "ГРАНАТА", "type": "throw", "rate": 0.9, "mag": 5, "reload": 2.0, "range": 0.0},
	{"name": "ГРАНАТОМЁТ", "type": "gun", "launcher": true, "dmg": 0, "rate": 1.1, "spread": 0.01, "range": 200, "auto": false, "mag": 6, "reload": 2.6, "zoom": 0.55},
]

var cur_w := 0
var mag: Array = []
var fire_cd := 0.0
var reload_t := 0.0
var swing_t := -1.0
var melee_applied := false
var recoil := 0.0
var fov_kick := 0.0
var aiming := false
var trigger_held := false
var trigger_pressed := false
var weapon_meshes: Array = []
var weapon_kick := 0.0
var muzzle_flash_t := 0.0

func _ready() -> void:
	init_mags()
	attach_weapon()

func zoom_cur() -> float:
	return WEAPONS[cur_w].get("zoom", 1.0)

func init_mags() -> void:
	mag.clear()
	for w in WEAPONS:
		mag.append(int(w.get("mag", 0)))

func attach_weapon() -> void:
	var rig = Game.player_rig
	if rig.has("wGrp") and rig.wGrp != null:
		rig.armR.remove_child(rig.wGrp)
		rig.wGrp = null
	if cur_w == 0 or cur_w == 1 or cur_w == 2:
		return
	if weapon_meshes.size() <= cur_w:
		weapon_meshes.resize(cur_w + 1)
	if weapon_meshes[cur_w] == null:
		weapon_meshes[cur_w] = build_weapon_mesh(cur_w)
	rig.wGrp = weapon_meshes[cur_w].grp
	rig.armR.add_child(rig.wGrp)

func build_weapon_mesh(_i: int) -> Dictionary:
	var g = Node3D.new()
	var dk = Game.make_mat(Color("#1e2126"), 0.5, 0.4)
	var box = BoxMesh.new()
	box.size = Vector3(0.12, 0.16, 0.55)
	var m = MeshInstance3D.new()
	m.mesh = box
	m.material_override = dk
	m.position = Vector3(0, -0.3, 0)
	g.add_child(m)
	var muzzle = Node3D.new()
	muzzle.position = Vector3(0, -0.55, 0)
	g.add_child(muzzle)
	# Дульная вспышка
	var flash = MeshInstance3D.new()
	var fm = SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.24
	flash.mesh = fm
	var fmat = StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.8, 0.2)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.8, 0.2)
	fmat.emission_energy_multiplier = 4.0
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = fmat
	flash.visible = false
	muzzle.add_child(flash)
	g.position = Vector3(0, -0.5, 0.08)
	return {"grp": g, "muzzle": muzzle, "flash": flash}

func set_weapon(i: int) -> void:
	if i == cur_w or i < 0 or i >= WEAPONS.size():
		return
	cur_w = i
	reload_t = 0
	swing_t = -1
	attach_weapon()

func _input(event: InputEvent) -> void:
	if not Game.playing:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			trigger_held = event.pressed
			if event.pressed:
				trigger_pressed = true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			pass
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_weapon((cur_w - 1 + 10) % 10)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_weapon((cur_w + 1) % 10)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			start_reload()
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			set_weapon(event.keycode - KEY_1)
		if event.keycode == KEY_0:
			set_weapon(9)

func _process(dt: float) -> void:
	if not Game.playing:
		return
	fire_cd -= dt
	fov_kick = max(0.0, fov_kick - 4.0 * dt)
	recoil = max(0.0, recoil - 2.5 * dt)
	if reload_t > 0:
		reload_t -= dt
		if reload_t <= 0:
			mag[cur_w] = int(WEAPONS[cur_w].get("mag", 0))
	if swing_t >= 0:
		swing_t += dt
		var k = swing_t / 0.26
		if k < 0.35:
			Game.player_rig.armR.rotation.x = lerp(-1.05, -2.3, k / 0.35)
		else:
			Game.player_rig.armR.rotation.x = lerp(-2.3, 0.5, (k - 0.35) / 0.65)
		if k >= 0.4 and not melee_applied:
			melee_applied = true
			melee_hit()
		if k >= 1.0:
			swing_t = -1.0
	# Анимация отдачи оружия
	if weapon_kick > 0:
		weapon_kick = max(0.0, weapon_kick - dt * 14.0)
		var rig = Game.player_rig
		if rig.wGrp != null:
			rig.wGrp.position.z = 0.08 - weapon_kick * 0.18
			rig.wGrp.rotation.x = -weapon_kick * 0.35
	# Затухание вспышки
	if muzzle_flash_t > 0:
		muzzle_flash_t -= dt
		var rig = Game.player_rig
		if rig.wGrp != null and cur_w >= 3 and cur_w < weapon_meshes.size():
			var w_data = weapon_meshes[cur_w]
			if w_data != null and w_data.flash != null:
				var alpha = clamp(muzzle_flash_t / 0.05, 0.0, 1.0)
				w_data.flash.material_override.albedo_color.a = alpha
				w_data.flash.visible = alpha > 0.01
				var s = 0.8 + alpha * 0.5
				w_data.flash.scale = Vector3(s, s, s)
	if Game.dead or Game.arrested:
		aiming = false
		trigger_pressed = false
		return
	var w = WEAPONS[cur_w]
	var usable = (w.type != "melee") if Game.in_car != null else true
	aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and w.type == "gun" and usable
	if usable:
		if w.type == "gun":
			if w.get("auto", false):
				if trigger_held:
					fire_gun(w)
			else:
				if trigger_pressed:
					fire_gun(w)
		elif w.type == "throw":
			if trigger_pressed and fire_cd <= 0 and mag[cur_w] > 0:
				fire_cd = 1.0 / w.rate
				mag[cur_w] -= 1
				Game.combat.throw_grenade()
		else:
			if trigger_pressed and swing_t < 0:
				swing_t = 0
				melee_applied = false
	if Game.audio != null:
		Game.audio.play_explosion(Game.player_pos)
	trigger_pressed = false

func start_reload() -> void:
	var w = WEAPONS[cur_w]
	if w.type != "gun" or reload_t > 0 or mag[cur_w] >= int(w.get("mag", 0)):
		return
	reload_t = w.reload
	if Game.audio != null:
		Game.audio.play_reload()

func fire_gun(w: Dictionary) -> void:
	if reload_t > 0 or fire_cd > 0:
		return
	if mag[cur_w] <= 0:
		start_reload()
		return
	fire_cd = 1.0 / w.rate
	mag[cur_w] -= 1
	if w.get("launcher", false):
		Game.combat.fire_shell()
		fov_kick += 0.4
		if Game.player_controller != null:
			Game.player_controller.add_camera_shake(0.4)
		return
	recoil = min(0.07, recoil + w.spread * 0.9)
	fov_kick += w.dmg * 0.012
	weapon_kick = 1.0
	muzzle_flash_t = 0.05
	if Game.player_controller != null:
		Game.player_controller.add_camera_shake(0.08 + w.dmg * 0.002)
	eject_shell()
	var cam = Game.camera
	var cam_dir = -cam.global_transform.basis.z
	var cam_right = cam.global_transform.basis.x
	var cam_up = cam.global_transform.basis.y
	var origin = cam.global_position
	var muzzle = Vector3(Game.player_pos.x, Game.player_py + 1.25, Game.player_pos.z) + cam_dir * 0.6
	var pellets = int(w.get("pellets", 1))
	var spread = w.spread
	if aiming:
		spread *= 0.5
	for pi in range(pellets):
		var dir = cam_dir.normalized()
		if spread > 0.0:
			var a = Game.rf(0, TAU)
			var r = Game.rf(0, spread)
			dir = (cam_dir + cam_right * cos(a) * r + cam_up * sin(a) * r).normalized()
		Game.combat.fire_ray(origin, dir, muzzle, w)
	if Game.audio != null:
		Game.audio.play_shot(cur_w)
	on_shot(origin)

func eject_shell() -> void:
	if Game.player_node == null:
		return
	var shell = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.06
	shell.mesh = cm
	shell.material_override = Game.make_mat(Color("#d4af37"), 0.3, 0.8)
	var cam = Game.camera
	var right = cam.global_transform.basis.x
	shell.global_position = cam.global_position + right * 0.2 + Vector3(0, 1.2, 0)
	shell.rotation.z = PI / 2.0
	Game.player_node.add_child(shell)
	var vel = right * Game.rf(2.0, 3.5) + Vector3(0, Game.rf(2.0, 3.0), Game.rf(-1, 1))
	var av = Vector3(Game.rf(-10, 10), Game.rf(-10, 10), Game.rf(-10, 10))
	Game.combat.effects.append({"node": shell, "vel": vel, "av": av, "life": 1.5, "kind": "debris"})

func on_shot(pos: Vector3) -> void:
	for p in Game.peds:
		if p.state == "dead":
			continue
		var d = Vector3(p.x, 0, p.z).distance_to(pos)
		if p.is_bandit:
			if d < 10:
				p.aggro = true
			continue
		if not p.is_cop and d < 16:
			p.flee_t = 3.5
			p.flee_h = atan2(p.x - pos.x, p.z - pos.z) + Game.rf(-0.5, 0.5)
			p.state = "flee"

func melee_hit() -> void:
	var w = WEAPONS[cur_w]
	var fdx = sin(Game.player_heading)
	var fdz = cos(Game.player_heading)
	for p in Game.peds:
		if p.state == "dead":
			continue
		var dx = p.x - Game.player_pos.x
		var dz = p.z - Game.player_pos.z
		var d = sqrt(dx * dx + dz * dz)
		if d < w.range and abs(Game.norm_ang(atan2(dx, dz) - Game.player_heading)) < 1.1:
			p.hp -= w.dmg
			if p.hp > 0 and p.is_bandit:
				p.aggro = true
			if p.hp <= 0:
				Game.combat.kill_ped(p, "melee", fdx, fdz, 3.0)
	for c in Game.cars:
		if c.mode == "wreck":
			continue
		var dx = c.x - Game.player_pos.x
		var dz = c.z - Game.player_pos.z
		var d = sqrt(dx * dx + dz * dz)
		if d < w.range + 1.2 and abs(Game.norm_ang(atan2(dx, dz) - Game.player_heading)) < 1.2:
			Game.combat.damage_car(c, w.dmg * 0.35, true)
	for pr in Game.props:
		if pr.dead:
			continue
		var dx = pr.x - Game.player_pos.x
		var dz = pr.z - Game.player_pos.z
		var d = sqrt(dx * dx + dz * dz)
		if d < w.range + 0.6:
			pr.hp -= w.dmg * 1.5
			if pr.hp <= 0:
				Game.combat.destroy_prop(pr, 2.0, fdx, fdz)
