extends Node
# Урон, взрывы, рэгдолл (цельный или расчленёнка), снаряды, эффекты, следы от пуль, кровь.

var ragdolls: Array = []
var effects: Array = []
var projectiles: Array = []
var decals: Array = []

func _process(dt: float) -> void:
	update_ragdolls(dt)
	update_fx(dt)
	update_projectiles(dt)

# ===== ХИТ-ДЕТЕКТ =====
func ray_sphere(ro: Vector3, rd: Vector3, center: Vector3, radius: float) -> float:
	var oc = ro - center
	var b = oc.dot(rd)
	var c = oc.dot(oc) - radius * radius
	var disc = b * b - c
	if disc < 0.0:
		return -1.0
	var sq = sqrt(disc)
	var t = -b - sq
	if t < 0.0:
		t = -b + sq
	if t < 0.0:
		return -1.0
	return t

func fire_ray(origin: Vector3, dir: Vector3, muzzle: Vector3, w: Dictionary) -> void:
	var best_t = w.range
	var best_target = null
	var best_type = ""
	var hit_normal = Vector3.UP
	for p in Game.peds:
		if p.state == "dead":
			continue
		var center = Vector3(p.x, 1.0, p.z)
		var t = ray_sphere(origin, dir, center, 0.55)
		if t > 0.0 and t < best_t:
			best_t = t
			best_target = p
			best_type = "ped"
			hit_normal = (origin + dir * t - center).normalized()
	for c in Game.cars:
		if c.mode == "wreck":
			continue
		var center = Vector3(c.x, 0.7, c.z)
		var t = ray_sphere(origin, dir, center, 1.5)
		if t > 0.0 and t < best_t:
			best_t = t
			best_target = c
			best_type = "car"
			hit_normal = (origin + dir * t - center).normalized()
	for pr in Game.props:
		if pr.dead:
			continue
		var center = Vector3(pr.x, 0.5, pr.z)
		var r = max(pr.r, 0.4)
		var t = ray_sphere(origin, dir, center, r)
		if t > 0.0 and t < best_t:
			best_t = t
			best_target = pr
			best_type = "prop"
			hit_normal = (origin + dir * t - center).normalized()
	var end = origin + dir * best_t
	add_tracer(muzzle, end)
	if best_type == "ped":
		var p = best_target
		var hit_y = origin.y + dir.y * best_t
		p.hp -= w.dmg
		add_blood_puff(end)
		if p.hp <= 0:
			p.headshot = hit_y > 1.4
			kill_ped(p, "gun", dir.x, dir.z, w.dmg / 20.0)
		elif p.is_bandit:
			p.aggro = true
		if Game.player_controller != null:
			Game.player_controller.add_camera_shake(0.15)
	elif best_type == "car":
		damage_car(best_target, w.dmg * 0.55, true)
		add_spark(end, hit_normal, Color("#c89858"))
		add_decal(end, hit_normal, Color(0.1, 0.1, 0.1, 0.8))
	elif best_type == "prop":
		best_target.hp -= w.dmg
		add_spark(end, hit_normal, Color("#a89878"))
		add_decal(end, hit_normal, Color(0.05, 0.05, 0.05, 0.9))
		if best_target.hp <= 0:
			destroy_prop(best_target, w.dmg / 15.0, dir.x, dir.z)
	else:
		add_decal(end, hit_normal, Color(0.05, 0.05, 0.05, 0.8))

# ===== ЭФФЕКТЫ =====
func add_tracer(a: Vector3, b: Vector3) -> void:
	var mesh = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	mesh.mesh = im
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#ffea80", 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	effects.append({"node": mesh, "mat": mat, "life": 0.12, "max_life": 0.12, "kind": "tracer"})

func add_spark(pos: Vector3, normal: Vector3, col: Color) -> void:
	var m = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	m.mesh = s
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	m.material_override = mat
	m.position = pos + normal * 0.05
	add_child(m)
	effects.append({"node": m, "life": 0.15, "max_life": 0.15, "kind": "spark"})

func add_blood_puff(pos: Vector3) -> void:
	for i in range(4):
		var m = MeshInstance3D.new()
		var s = SphereMesh.new()
		s.radius = Game.rf(0.05, 0.12)
		s.height = s.radius * 2
		m.mesh = s
		var mat = StandardMaterial3D.new()
		var c = Color("#6a0a0a")
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c * 0.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.position = pos
		add_child(m)
		var vel = Vector3(Game.rf(-2, 2), Game.rf(1, 3), Game.rf(-2, 2))
		effects.append({"node": m, "vel": vel, "life": 0.4, "max_life": 0.4, "kind": "blood"})

func add_decal(pos: Vector3, normal: Vector3, col: Color) -> void:
	if decals.size() > 80:
		var old = decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var m = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(Game.rf(0.1, 0.2), Game.rf(0.1, 0.2))
	m.mesh = q
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos + normal * 0.015
	var up = Vector3.UP if abs(normal.y) < 0.99 else Vector3.FORWARD
	m.look_at(pos - normal, up)
	add_child(m)
	decals.append(m)

func update_fx(dt: float) -> void:
	var i = effects.size() - 1
	while i >= 0:
		var f = effects[i]
		f.life -= dt
		if f.kind == "tracer":
			f.mat.albedo_color.a = clamp(f.life / f.max_life, 0.0, 1.0)
		elif f.kind == "spark":
			var s = max(0.01, f.life / f.max_life)
			f.node.scale = Vector3(s, s, s)
		elif f.kind == "blood":
			f.node.position += f.vel * dt
			f.vel.y -= 9.8 * dt
			f.vel *= 0.9
			var s = max(0.0, f.life / f.max_life)
			f.node.scale = Vector3(s, s, s)
			f.node.material_override.albedo_color.a = s
		elif f.kind == "debris":
			f.vel.y -= 16.0 * dt
			f.node.position += f.vel * dt
			f.node.rotation.x += f.av.x * dt
			f.node.rotation.y += f.av.y * dt
			f.node.rotation.z += f.av.z * dt
			if f.node.position.y < 0.1:
				f.node.position.y = 0.1
				if f.vel.y < -1:
					f.vel.y *= -0.3
				else:
					f.vel.y = 0
				f.vel.x *= 0.85
				f.vel.z *= 0.85
				f.av *= 0.8
			if f.life < 1.0:
				f.node.scale *= max(0.0, 1.0 - dt)
		if f.life <= 0:
			f.node.queue_free()
			effects.remove_at(i)
		i -= 1

# ===== РЭГДОЛЛ =====
func mk_part(parts: Array, x: float, y: float, z: float, w: float, h: float, d: float, col: Color, dx: float, dz: float, imp: float, up: float, sev: bool) -> void:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(w, h, d)
	m.mesh = bm
	m.material_override = Game.make_mat(col, 0.9)
	m.position = Vector3(x, y, z)
	add_child(m)
	var scatter = 1.5 if sev else 1.0
	parts.append({"m": m, "g": min(w, h, d) * 0.45,
		"vel": Vector3(dx * imp * scatter + Game.rf(-1, 1) * scatter, up + (2.0 if sev else 0.0) + Game.rf(0, 2), dz * imp * scatter + Game.rf(-1, 1) * scatter),
		"av": Vector3(Game.rf(-9, 9) * scatter, Game.rf(-9, 9) * scatter, Game.rf(-9, 9) * scatter)})
	if sev:
		add_blood_puff(Vector3(x, y, z))

func spawn_ragdoll_at(x: float, z: float, colors: Dictionary, dx: float, dz: float, power: float, sever: Array, headshot: bool) -> void:
	if ragdolls.size() > 26:
		var old = ragdolls.pop_front()
		for pt in old.parts:
			if is_instance_valid(pt.m):
				pt.m.queue_free()
	var parts: Array = []
	mk_part(parts, x, 1.0, z, 0.42, 0.56, 0.24, colors.shirt, dx, dz, power * 0.6, 2.5 + power * 0.3, sever.has("torso"))
	mk_part(parts, x, 1.55, z, 0.25, 0.27, 0.25, colors.skin, dx, dz, power * (1.6 if headshot else 0.8), (4.0 + power * 0.5) if headshot else (3.0 + power * 0.4), sever.has("head"))
	mk_part(parts, x + 0.3, 1.2, z, 0.13, 0.6, 0.13, colors.shirt, dx, dz, power * 0.7, 2.0 + power * 0.3, sever.has("armL"))
	mk_part(parts, x - 0.3, 1.2, z, 0.13, 0.6, 0.13, colors.shirt, dx, dz, power * 0.7, 2.0 + power * 0.3, sever.has("armR"))
	mk_part(parts, x + 0.1, 0.45, z, 0.16, 0.7, 0.16, colors.pants, dx, dz, power * 0.5, 1.6 + power * 0.25, sever.has("legL"))
	mk_part(parts, x - 0.1, 0.45, z, 0.16, 0.7, 0.16, colors.pants, dx, dz, power * 0.5, 1.6 + power * 0.25, sever.has("legR"))
	ragdolls.append({"parts": parts, "t": 0.0})

func spawn_whole_ragdoll(x: float, z: float, colors: Dictionary, dx: float, dz: float, power: float) -> void:
	if ragdolls.size() > 26:
		var old = ragdolls.pop_front()
		for pt in old.parts:
			if is_instance_valid(pt.m):
				pt.m.queue_free()
	var body_root = Node3D.new()
	var torso = MeshInstance3D.new()
	var cm = CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.3
	torso.mesh = cm
	torso.material_override = Game.make_mat(colors.shirt, 0.9)
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body_root.add_child(torso)
	var head = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.22
	hm.height = 0.44
	head.mesh = hm
	head.material_override = Game.make_mat(colors.skin, 0.85)
	head.position = Vector3(0, 0.85, 0)
	body_root.add_child(head)
	body_root.position = Vector3(x, 0.85, z)
	add_child(body_root)
	var imp = power * 2.5 + 2.0
	var parts: Array = []
	parts.append({"m": body_root, "g": 0.3,
		"vel": Vector3(dx * imp + Game.rf(-1, 1), 3.0 + Game.rf(0, 2), dz * imp + Game.rf(-1, 1)),
		"av": Vector3(Game.rf(-7, 7), Game.rf(-7, 7), Game.rf(-7, 7))})
	ragdolls.append({"parts": parts, "t": 0.0})

func spawn_player_ragdoll() -> void:
	var colors = {"shirt": Color("#5a5648"), "pants": Color("#33363c"), "skin": Color("#c98d64")}
	spawn_whole_ragdoll(Game.player_pos.x, Game.player_pos.z, colors, 0.0, 0.0, 3.0)

func update_ragdolls(dt: float) -> void:
	var i = ragdolls.size() - 1
	while i >= 0:
		var r = ragdolls[i]
		r.t += dt
		for pt in r.parts:
			pt.vel.y -= 16.0 * dt
			pt.m.position += pt.vel * dt
			pt.m.rotation.x += pt.av.x * dt
			pt.m.rotation.y += pt.av.y * dt
			pt.m.rotation.z += pt.av.z * dt
			if pt.m.position.y < pt.g:
				pt.m.position.y = pt.g
				if pt.vel.y < -1:
					pt.vel.y *= -0.3
				else:
					pt.vel.y = 0
				pt.vel.x *= 0.85
				pt.vel.z *= 0.85
				pt.av *= 0.8
		if r.t > 7.0:
			for pt in r.parts:
				pt.m.scale *= max(0.0, 1.0 - dt * 0.5)
				pt.m.position.y -= dt * 0.3
		if r.t > 9.5:
			for pt in r.parts:
				pt.m.queue_free()
			ragdolls.remove_at(i)
		i -= 1

# ===== УРОН =====
func kill_ped(p: Dictionary, cause: String, dx: float, dz: float, power: float) -> void:
	if p.state == "dead":
		return
	p.state = "dead"
	if p.is_cop:
		Game.add_wanted(2)
		Game.toast("Полицейский уничтожен", true)
	elif p.is_bandit:
		Game.score += 1
		if Game.missions != null:
			Game.missions.add_rampage_kill()
	else:
		Game.add_wanted(1)
	if p.get("is_target", false):
		if Game.missions != null:
			Game.missions.complete_target_kill()
	if cause == "boom":
		spawn_ragdoll_at(p.x, p.z, p.colors, dx, dz, power, ["head", "armL", "armR", "legL", "legR"], false)
	else:
		spawn_whole_ragdoll(p.x, p.z, p.colors, dx, dz, power)
	Game.peds.erase(p)
	Game.police.police_foot.erase(p)
	if is_instance_valid(p.rig.grp):
		p.rig.grp.queue_free()
	Game.ped_killed.emit(p, cause)

func damage_car(car: Dictionary, dmg: float, by_player: bool) -> void:
	if car.is_empty() or car.mode == "wreck" or dmg <= 0:
		return
	if by_player:
		car.last_player = true
		car.hp -= dmg
		if car.hp <= 0:
			car.hp = 0
			explode_car(car)

func explode_car(car: Dictionary) -> void:
	if car.mode == "wreck":
		return
	car.mode = "wreck"
	car.vel = Vector3.ZERO
	car.body_mat.albedo_color = Color("#151514")
	if car == Game.in_car:
		Game.in_car = null
		Game.player_rig.grp.visible = true
		Game.damage_player(45, "boom")
	if car.is_police:
		Game.add_wanted(2)
	if car.last_player and Game.missions != null:
		Game.missions.add_destroy_kill()
	explode(Vector3(car.x, 0.9, car.z), 60, car.last_player)
	Game.car_exploded.emit(car)

func explode(pos: Vector3, dmg: float, by_player: bool) -> void:
	if Game.audio != null:
		Game.audio.play_explosion(pos)
	if by_player:
		Game.add_wanted(1)
	for pd in Game.peds.duplicate():
		if pd.state == "dead":
			continue
		var d = Vector3(pd.x, 0, pd.z).distance_to(pos)
		if d < 7:
			var nx = (pd.x - pos.x) / max(d, 0.001)
			var nz = (pd.z - pos.z) / max(d, 0.001)
			kill_ped(pd, "boom", nx, nz, 12.0)
	for pd in Game.peds:
		if pd.is_bandit and pd.state != "dead" and Vector3(pd.x, 0, pd.z).distance_to(pos) < 16:
			pd.aggro = true
	for c2 in Game.cars:
		if c2.mode == "wreck":
			continue
		var d = Vector3(c2.x, 0, c2.z).distance_to(pos)
		if d < 7.5:
			damage_car(c2, dmg * (1.0 - d / 7.5), by_player)
	for pr in Game.props:
		if pr.dead:
			continue
		var d = Vector3(pr.x, 0, pr.z).distance_to(pos)
		if d < 7:
			destroy_prop(pr, 8.0, (pr.x - pos.x) / max(d, 0.001), (pr.z - pos.z) / max(d, 0.001))
	if Game.in_car == null:
		var pp = Game.player_pos
		var d = pp.distance_to(pos)
		if d < 8:
			Game.damage_player(dmg * 0.9 * (1.0 - d / 8.0), "boom")
	else:
		var d = Vector3(Game.in_car.x, 0, Game.in_car.z).distance_to(pos)
		if d < 8:
			damage_car(Game.in_car, dmg * 0.7 * (1.0 - d / 8.0), false)
	if Game.player_controller != null:
		Game.player_controller.add_camera_shake(0.6)

func destroy_prop(p: Dictionary, imp: float, dx: float, dz: float) -> void:
	if p.dead:
		return
	p.dead = true
	if is_instance_valid(p.mesh):
		p.mesh.queue_free()
	var dmat = null
	if p.mesh is MeshInstance3D:
		dmat = p.mesh.material_override
	if dmat == null:
		dmat = Game.make_mat(Color("#6a5232"), 0.9)
	for k in range(3):
		var ch = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(Game.rf(0.12, 0.3), Game.rf(0.12, 0.3), Game.rf(0.12, 0.3))
		ch.mesh = bm
		ch.material_override = dmat
		ch.position = Vector3(p.x, 0.5, p.z)
		add_child(ch)
		effects.append({"node": ch, "life": 3.0, "kind": "debris",
			"vel": Vector3(dx * imp + Game.rf(-2, 2), Game.rf(2, 4), dz * imp + Game.rf(-2, 2)),
			"av": Vector3(Game.rf(-8, 8), Game.rf(-8, 8), Game.rf(-8, 8))})

# ===== СНАРЯДЫ =====
func fire_shell() -> void:
	var cam = Game.camera
	var dir = -cam.global_transform.basis.z
	var mesh = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.28
	mesh.mesh = cm
	mesh.material_override = Game.make_mat(Color("#33383c"), 0.4, 0.5)
	mesh.global_position = cam.global_position + dir * 0.8
	add_child(mesh)
	var vel = dir * 36.0
	vel.y += 1.0
	projectiles.append({"mesh": mesh, "vel": vel, "fuse": 4.0, "type": "shell"})

func throw_grenade() -> void:
	var cam = Game.camera
	var dir = -cam.global_transform.basis.z
	var mesh = MeshInstance3D.new()
	var spm = SphereMesh.new()
	spm.radius = 0.13
	spm.height = 0.26
	mesh.mesh = spm
	mesh.material_override = Game.make_mat(Color("#2e3a28"), 0.7)
	mesh.global_position = cam.global_position + dir * 0.5
	add_child(mesh)
	var vel = dir * 16.0
	vel.y += 4.0 if Game.in_car == null else 2.0
	projectiles.append({"mesh": mesh, "vel": vel, "fuse": 2.2, "type": "nade"})

func update_projectiles(dt: float) -> void:
	var i = projectiles.size() - 1
	while i >= 0:
		var p = projectiles[i]
		p.vel.y -= (18.0 if p.type == "nade" else 7.0) * dt
		p.mesh.global_position += p.vel * dt
		p.mesh.rotation.x += dt * 8
		p.mesh.rotation.z += dt * 5
		var boom_now = false
		var mp = p.mesh.global_position
		if mp.y < 0.13:
			if p.type == "nade":
				mp.y = 0.13
				p.vel.y *= -0.4
				p.vel.x *= 0.65
				p.vel.z *= 0.65
				if abs(p.vel.y) < 1.2:
					p.vel.y = 0
			else:
				boom_now = true
		p.fuse -= dt
		if p.fuse <= 0:
			boom_now = true
		if boom_now:
			p.mesh.queue_free()
			projectiles.remove_at(i)
			explode(Vector3(mp.x, max(0.3, mp.y), mp.z), 60, true)
		i -= 1
