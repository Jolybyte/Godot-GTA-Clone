extends Node
## Машины, трафик, физика, водители, коллизии, поведение на светофорах.
## Фары и стоп-сигналы — OmniLight3D (гарантированно работают).

const CAR_R := 1.9
const PED_CAR_R := 2.35

var ai_cars: Array = []
var glass_mat: StandardMaterial3D = null
var wheel_mat: StandardMaterial3D = null
var hub_mat: StandardMaterial3D = null
var chrome_mat: StandardMaterial3D = null
var driver_palette: Array = []

func _ready() -> void:
	init_car_materials()
	build_cars()

func init_car_materials() -> void:
	glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.08, 0.1, 0.13, 0.8)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.metallic = 0.4
	wheel_mat = Game.make_mat(Color("#101010"), 0.95)
	hub_mat = Game.make_mat(Color("#777777"), 0.4, 0.8)
	chrome_mat = Game.make_mat(Color("#9a9a9a"), 0.3, 0.9)
	var shirts = [Color("#7a5a44"),Color("#4a5a6a"),Color("#6a644a"),Color("#5a4a5c"),Color("#4a6a55"),Color("#8a857a")]
	var pants = [Color("#2e3238"),Color("#3a3228"),Color("#24343a"),Color("#33302a")]
	var skins = [Color("#c98d64"),Color("#8a5a3a"),Color("#e0b090"),Color("#6a4a30")]
	driver_palette = [shirts, pants, skins]

func make_wheel(radius: float) -> Node3D:
	var pivot = Node3D.new()
	var tire = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.26
	cm.radial_segments = 12
	tire.mesh = cm
	tire.material_override = wheel_mat
	tire.rotation_degrees.z = 90
	tire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(tire)
	var hub = MeshInstance3D.new()
	var hm = CylinderMesh.new()
	hm.top_radius = radius * 0.5
	hm.bottom_radius = radius * 0.5
	hm.height = 0.27
	hm.radial_segments = 8
	hub.mesh = hm
	hub.material_override = hub_mat
	hub.rotation_degrees.z = 90
	pivot.add_child(hub)
	return pivot

func build_cars() -> void:
	for k in range(Game.PARKED_COUNT):
		var vert = Game.rf(0, 1) < 0.5
		var idx = Game.ri(0, Game.N)
		var side = 1.0 if Game.rf(0, 1) < 0.5 else -1.0
		var t = Game.rf(-Game.HALF + 9, Game.HALF - 9)
		var near = false
		for r in Game.road_centers:
			if abs(t - float(r)) < 10:
				near = true
				break
		if near:
			continue
		var x: float
		var z: float
		if vert:
			x = float(Game.road_centers[idx]) + side * 5.0
			z = t
		else:
			x = t
			z = float(Game.road_centers[idx]) + side * 5.0
		var h: float
		if vert:
			h = PI if side > 0 else 0.0
		else:
			h = PI / 2.0 if side > 0 else -PI / 2.0
		var kinds = ["sedan", "sedan", "van", "sport", "taxi"]
		add_car(Game.pick_arr(kinds), x, z, h, "parked")
	for k in range(Game.TRAFFIC_COUNT):
		spawn_traffic_car()
	add_car("sedan", 4.8, 16, 0, "parked")

func add_car(kind: String, x: float, z: float, heading: float, mode: String) -> Dictionary:
	var g = Node3D.new()
	g.position = Vector3(x, 0, z)
	g.rotation.y = heading
	var L = 4.4
	var W = 1.9
	var BH = 0.6
	var BY = 0.6
	var CH = 0.5
	var CY = 1.16
	var wheel_r = 0.34
	if kind == "sport":
		L = 4.2; BH = 0.5; BY = 0.5; CH = 0.42; CY = 1.0; wheel_r = 0.32
	if kind == "van":
		L = 4.7; BH = 1.3; BY = 0.95; CH = 0; wheel_r = 0.36
	var color: Color
	if kind == "taxi":
		color = Color("#c9a23c")
	elif kind == "police":
		color = Color("#e8e8e8")
	else:
		color = Game.pick_arr([Color("#5a5f66"),Color("#6b5b4a"),Color("#4a5560"),Color("#707068"),Color("#5c4a42"),Color("#3f4a3f"),Color("#8a857a"),Color("#2f3338"),Color("#7a4a3a")])
	var bmat = Game.make_mat(color, 0.35, 0.6)
	Game.car_body_mats.append(bmat)
	var body = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(W, BH, L)
	body.mesh = bm
	body.material_override = bmat
	body.position.y = BY
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	g.add_child(body)
	if CH > 0:
		var cab = MeshInstance3D.new()
		var cbm = BoxMesh.new()
		cbm.size = Vector3(W * 0.86, CH, L * 0.46)
		cab.mesh = cbm
		cab.material_override = glass_mat
		cab.position = Vector3(0, CY, -L * 0.06)
		cab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		g.add_child(cab)
		var roof = MeshInstance3D.new()
		var rfm = BoxMesh.new()
		rfm.size = Vector3(W * 0.86, 0.06, L * 0.46)
		roof.mesh = rfm
		roof.material_override = bmat
		roof.position = Vector3(0, CY + CH / 2.0, -L * 0.06)
		g.add_child(roof)
	var fbum = MeshInstance3D.new()
	var fbm = BoxMesh.new()
	fbm.size = Vector3(W + 0.1, 0.25, 0.3)
	fbum.mesh = fbm
	fbum.material_override = chrome_mat
	fbum.position = Vector3(0, 0.35, L / 2.0 + 0.1)
	g.add_child(fbum)
	var rbum = MeshInstance3D.new()
	rbum.mesh = fbm
	rbum.material_override = chrome_mat
	rbum.position = Vector3(0, 0.35, -L / 2.0 - 0.1)
	g.add_child(rbum)

	# --- индивидуальные материалы фар и стопов ---
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color("#2a2a24")
	head_mat.emission_enabled = true
	head_mat.emission = Color("#fff2c8")
	head_mat.emission_energy_multiplier = 0.0
	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color("#3a1010")
	tail_mat.emission_enabled = true
	tail_mat.emission = Color("#ff2222")
	tail_mat.emission_energy_multiplier = 0.0

	var head_meshes: Array = []
	var tail_meshes: Array = []
	for sx in [-1.0, 1.0]:
		var hl = MeshInstance3D.new()
		var hlm = BoxMesh.new()
		hlm.size = Vector3(0.35, 0.15, 0.08)
		hl.mesh = hlm
		hl.material_override = head_mat
		hl.position = Vector3(sx * (W / 2.0 - 0.35), BY + 0.05, L / 2.0 + 0.02)
		g.add_child(hl)
		head_meshes.append(hl)
		var tl = MeshInstance3D.new()
		var tlm = BoxMesh.new()
		tlm.size = Vector3(0.35, 0.15, 0.08)
		tl.mesh = tlm
		tl.material_override = tail_mat
		tl.position = Vector3(sx * (W / 2.0 - 0.35), BY + 0.05, -L / 2.0 - 0.02)
		g.add_child(tl)
		tail_meshes.append(tl)

	# --- ДВА OmniLight3D впереди (фары) ---
	var head_lights: Array = []
	for sx in [-1.0, 1.0]:
		var om = OmniLight3D.new()
		om.light_color = Color("#fff2c8")
		om.light_energy = 0.0
		om.omni_range = 12.0                 
		om.omni_attenuation = 2.5           
		om.shadow_enabled = false
		om.position = Vector3(sx * (W / 2.0 - 0.35), BY + 0.15, L / 2.0 + 1.2)
		om.distance_fade_enabled = true
		om.distance_fade_begin = 80.0
		om.distance_fade_length = 40.0
		g.add_child(om)
		head_lights.append(om)

	# --- ДВА OmniLight3D сзади (стопы) ---
	var tail_glows: Array = []
	for sx in [-1.0, 1.0]:
		var tg = OmniLight3D.new()
		tg.light_color = Color("#ff2a2a")
		tg.light_energy = 0.0
		tg.omni_range = 8.0             # было 12 — компактнее
		tg.omni_attenuation = 2.2       # было 1.6 — быстрее затухает
		tg.shadow_enabled = false
		tg.position = Vector3(sx * (W / 2.0 - 0.35), BY + 0.15, L / 2.0 + 1.2)
		tg.distance_fade_enabled = true
		tg.distance_fade_begin = 60.0
		tg.distance_fade_length = 30.0
		g.add_child(tg)
		tail_glows.append(tg)

	var wheels: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w = make_wheel(wheel_r)
			w.position = Vector3(sx * (W / 2.0 + 0.02), wheel_r, sz * (L / 2.0 - 0.85))
			g.add_child(w)
			wheels.append(w)
	var lr_mat = null
	var lb_mat = null
	if kind == "police" and CH > 0:
		var bar = MeshInstance3D.new()
		var bar_m = BoxMesh.new()
		bar_m.size = Vector3(W * 0.6, 0.12, 0.3)
		bar.mesh = bar_m
		bar.material_override = Game.make_mat(Color("#222222"), 0.5)
		bar.position = Vector3(0, CY + CH / 2.0 + 0.12, -L * 0.06)
		g.add_child(bar)
		lr_mat = StandardMaterial3D.new()
		lr_mat.albedo_color = Color("#ff2222")
		lr_mat.emission_enabled = true
		lr_mat.emission = Color("#ff2222")
		lr_mat.emission_energy_multiplier = 2.0
		lb_mat = StandardMaterial3D.new()
		lb_mat.albedo_color = Color("#2255ff")
		lb_mat.emission_enabled = true
		lb_mat.emission = Color("#2255ff")
		lb_mat.emission_energy_multiplier = 2.0
		var lr = MeshInstance3D.new()
		var lrm = BoxMesh.new(); lrm.size = Vector3(0.3, 0.1, 0.28)
		lr.mesh = lrm; lr.material_override = lr_mat
		lr.position = Vector3(-0.3, CY + CH / 2.0 + 0.12, -L * 0.06)
		g.add_child(lr)
		var lb = MeshInstance3D.new()
		var lbm = BoxMesh.new(); lbm.size = Vector3(0.3, 0.1, 0.28)
		lb.mesh = lbm; lb.material_override = lb_mat
		lb.position = Vector3(0.3, CY + CH / 2.0 + 0.12, -L * 0.06)
		g.add_child(lb)
	if kind == "taxi" and CH > 0:
		var sign = MeshInstance3D.new()
		var sm = BoxMesh.new(); sm.size = Vector3(0.6, 0.2, 0.3)
		sign.mesh = sm
		sign.material_override = Game.make_mat(Color("#ffd23f"), 0.5, 0.0, Color("#ffd23f"), 1.0)
		sign.position = Vector3(0, CY + CH / 2.0 + 0.16, -L * 0.06)
		g.add_child(sign)
	add_child(g)
	var names = {"sedan":"Сайгак","taxi":"Такси","van":"Кабан","sport":"Буревестник","police":"Полиция"}
	var car = {"grp": g, "body": body, "kind": kind, "name": names[kind], "L": L, "body_mat": bmat,
		"x": x, "z": z, "heading": heading, "vel": Vector3.ZERO, "mode": mode, "hp": 240.0, "max_hp": 240.0,
		"speed": 0.0, "spin_v": 0.0, "steer_vis": 0.0, "seed": Game.rf(0, 10), "is_police": kind == "police",
		"hit_cd": 0.0, "stuck_t": 0.0, "rev_t": 0.0, "block_t": 0.0, "smoke": null, "fire": null, "burn_t": 0.0,
		"last_player": false, "ti": 0, "tj": 0, "dir": Vector3.ZERO, "target": Vector3.ZERO,
		"wheels": wheels, "light_r_mat": lr_mat, "light_b_mat": lb_mat,
		"driver_node": null, "driver_colors": null, "at_light": false,
		"head_lights": head_lights, "tail_glows": tail_glows,
		"head_mat": head_mat, "tail_mat": tail_mat,
		"head_meshes": head_meshes, "tail_meshes": tail_meshes,
		"light_on": false, "brake_on": false}
	if kind == "police":
		car.hp = 320
		car.max_hp = 320
	if kind != "police" and CH > 0:
		car.driver_node = make_sitting_driver(g, W, L, BY, CH, CY)
		if car.driver_node != null:
			car.driver_colors = car.driver_node.colors
	Game.cars.append(car)
	return car

func make_sitting_driver(g: Node3D, W: float, L: float, BY: float, CH: float, CY: float):
	if CH <= 0:
		return null
	var shirts = driver_palette[0]
	var pants = driver_palette[1]
	var skins = driver_palette[2]
	var colors = {"shirt": Game.pick_arr(shirts), "pants": Game.pick_arr(pants), "skin": Game.pick_arr(skins)}
	var ms = Game.make_mat(colors.shirt, 0.95)
	var mk = Game.make_mat(colors.skin, 0.85)
	var root = Node3D.new()
	root.position = Vector3(0, CY - 0.15, -L * 0.06)
	g.add_child(root)
	var torso = MeshInstance3D.new()
	var tb = BoxMesh.new()
	tb.size = Vector3(0.42, 0.56, 0.24)
	torso.mesh = tb
	torso.material_override = ms
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(torso)
	var head = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(0.25, 0.27, 0.25)
	head.mesh = hm
	head.material_override = mk
	head.position.y = 0.45
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(head)
	var ag = BoxMesh.new()
	ag.size = Vector3(0.13, 0.5, 0.13)
	for sx in [-1.0, 1.0]:
		var arm = MeshInstance3D.new()
		arm.mesh = ag
		arm.material_override = ms
		arm.position = Vector3(sx * 0.28, 0.1, -0.35)
		arm.rotation_degrees.x = -70
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(arm)
	return {"node": root, "colors": colors}

func spawn_traffic_car() -> void:
	for a in range(14):
		var i = Game.ri(1, Game.N - 1)
		var j = Game.ri(1, Game.N - 1)
		var dirs = [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]
		var d = Game.pick_arr(dirs)
		var ti = i + int(d.x)
		var tj = j + int(d.z)
		if ti < 0 or ti > Game.N or tj < 0 or tj > Game.N:
			continue
		var x = float(Game.road_centers[i]) - d.z * 2.8
		var z = float(Game.road_centers[j]) + d.x * 2.8
		var pp = Game.get_focus_pos()
		if Vector3(x, 0, z).distance_to(pp) < 20:
			continue
		var kinds = ["sedan","sedan","sedan","taxi","van","sport"]
		var car = add_car(Game.pick_arr(kinds), x, z, atan2(d.x, d.z), "traffic")
		car.ti = ti
		car.tj = tj
		car.dir = d
		car.speed = Game.rf(6, 8)
		car.target = Vector3(float(Game.road_centers[ti]) - d.z * 2.8 + d.x * 2, 0, float(Game.road_centers[tj]) + d.x * 2.8 + d.z * 2)
		ai_cars.append(car)
		return

func relocate_far_traffic() -> void:
	var pp = Game.get_focus_pos()
	for c in ai_cars.duplicate():
		var d = Vector3(c.x, 0, c.z).distance_to(pp)
		if d > 150:
			remove_car(c)
			spawn_traffic_car()

func remove_car(car: Dictionary) -> void:
	Game.cars.erase(car)
	ai_cars.erase(car)
	if is_instance_valid(car.grp):
		car.grp.queue_free()

func _process(dt: float) -> void:
	if not Game.playing:
		return
	update_traffic(dt)
	sync_cars(dt)

func traffic_light_stop(c: Dictionary) -> float:
	if Game.city == null:
		return -1.0
	var axis = 0 if abs(c.dir.x) > 0.5 else 1
	if axis == 1:
		var ix = nearest_road_idx(c.x)
		var step = 1.0 if c.dir.z > 0.0 else -1.0
		var bd = 1e9
		var bj = -1
		for j in range(Game.N + 1):
			var dd = (float(Game.road_centers[j]) - c.z) * step
			if dd > 0.5 and dd < bd:
				bd = dd
				bj = j
		if bj < 0 or bd > 14.0:
			return -1.0
		var st = Game.city.light_state(ix, bj, 1)
		if st == 0:
			return -1.0
		var stop_line = float(Game.road_centers[bj]) - step * Game_city_stop_off()
		var dist = (stop_line - c.z) * step
		if dist < -0.5:
			return -1.0
		if st == 1 and dist < 4.0:
			return -1.0
		return dist
	else:
		var jj = nearest_road_idx(c.z)
		var step = 1.0 if c.dir.x > 0.0 else -1.0
		var bd = 1e9
		var bi = -1
		for i in range(Game.N + 1):
			var dd = (float(Game.road_centers[i]) - c.x) * step
			if dd > 0.5 and dd < bd:
				bd = dd
				bi = i
		if bi < 0 or bd > 14.0:
			return -1.0
		var st = Game.city.light_state(bi, jj, 0)
		if st == 0:
			return -1.0
		var stop_line = float(Game.road_centers[bi]) - step * Game_city_stop_off()
		var dist = (stop_line - c.x) * step
		if dist < -0.5:
			return -1.0
		if st == 1 and dist < 4.0:
			return -1.0
		return dist

func Game_city_stop_off() -> float:
	return 8.2

func update_traffic(dt: float) -> void:
	for c in ai_cars.duplicate():
		if c.mode != "traffic":
			continue
		var tp = c.target
		var dx = tp.x - c.x
		var dz = tp.z - c.z
		var d = sqrt(dx * dx + dz * dz)
		if d < 2.2:
			var dirs = [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]
			var opts: Array = []
			for v in dirs:
				if not (v.x == -c.dir.x and v.z == -c.dir.z):
					if c.ti + int(v.x) >= 0 and c.ti + int(v.x) <= Game.N and c.tj + int(v.z) >= 0 and c.tj + int(v.z) <= Game.N:
						opts.append(v)
			if opts.is_empty():
				remove_car(c)
				spawn_traffic_car()
				continue
			var sel = Game.pick_arr(opts)
			c.dir = sel
			c.ti += int(sel.x)
			c.tj += int(sel.z)
			c.target = Vector3(float(Game.road_centers[c.ti]) - sel.z * 2.8 + sel.x * 2, 0, float(Game.road_centers[c.tj]) + sel.x * 2.8 + sel.z * 2)
		var des_h = atan2(c.target.x - c.x, c.target.z - c.z)
		c.heading = Game.ang_lerp(c.heading, des_h, 2.2 * dt)
		var fwd = Vector3(sin(c.heading), 0, cos(c.heading))
		var ts = 7.5
		if abs(Game.norm_ang(des_h - c.heading)) > 0.6:
			ts = 4.0
		var blocked = false
		var blocked_by_light = false
		for o in ai_cars:
			if o == c:
				continue
			var ox = o.x - c.x
			var oz = o.z - c.z
			var od = sqrt(ox * ox + oz * oz)
			if od < 8:
				var dot = (ox * fwd.x + oz * fwd.z) / max(od, 0.001)
				if dot > 0.8 and abs(-ox * fwd.z + oz * fwd.x) < 2 and od > 1.4:
					blocked = true
					blocked_by_light = o.at_light
					break
		if blocked:
			if blocked_by_light:
				c.block_t = 0.0
			else:
				c.block_t += dt
			ts = 0.0
		else:
			c.block_t = 0.0
		var ld = traffic_light_stop(c)
		if ld >= 0.0 and ld < 9.0:
			ts = 0.0
			c.at_light = true
			c.block_t = 0.0
		else:
			c.at_light = false
		if c.block_t > 3.5:
			ts = maxf(ts, 5.0)
		c.speed = lerpf(c.speed, ts, clampf(3.0 * dt, 0.0, 1.0))
		c.x += fwd.x * c.speed * dt
		c.z += fwd.z * c.speed * dt
		c.vel = Vector3(fwd.x * c.speed, 0, fwd.z * c.speed)
		c.spin_v = c.speed
		resolve_car_vs_cars(c)

func resolve_car_vs_cars(car: Dictionary) -> void:
	for o in Game.cars:
		if o == car:
			continue
		var dx = car.x - o.x
		var dz = car.z - o.z
		var d2 = dx * dx + dz * dz
		var rr = CAR_R * 2.0
		if d2 >= rr * rr or d2 < 0.0001:
			continue
		var d = sqrt(d2)
		var nx = dx / d
		var nz = dz / d
		var pen = rr - d
		var static_o = (o.mode == "parked" or o.mode == "wreck")
		if static_o:
			car.x += nx * pen
			car.z += nz * pen
		else:
			car.x += nx * pen * 0.5
			car.z += nz * pen * 0.5
			o.x -= nx * pen * 0.5
			o.z -= nz * pen * 0.5
		var rvx = car.vel.x - o.vel.x
		var rvz = car.vel.z - o.vel.z
		var vn = rvx * nx + rvz * nz
		if vn < 0.0:
			var imp = -vn
			if static_o:
				car.vel.x -= nx * vn * 1.3
				car.vel.z -= nz * vn * 1.3
				car.vel *= 0.85
			else:
				car.vel.x -= nx * vn * 0.6
				car.vel.z -= nz * vn * 0.6
				o.vel.x += nx * vn * 0.6
				o.vel.z += nz * vn * 0.6
			if imp > 5.0:
				Game.combat.damage_car(car, imp * 0.35, car == Game.in_car)
				if not static_o:
					Game.combat.damage_car(o, imp * 0.35, o == Game.in_car)

func sync_cars(dt: float) -> void:
	for c in Game.cars:
		c.grp.position = Vector3(c.x, 0, c.z)
		c.grp.rotation.y = c.heading
		c.hit_cd = max(0.0, c.hit_cd - dt)
		if c.has("wheels"):
			for w in c.wheels:
				w.rotation.x += c.spin_v * dt / 0.34
		if c.is_police and c.light_r_mat != null:
			var phase = int(Time.get_ticks_msec() / 1000.0 * 4.0) % 2
			c.light_r_mat.emission_energy_multiplier = 2.5 if phase == 0 else 0.2
			c.light_b_mat.emission_energy_multiplier = 0.2 if phase == 0 else 2.5

func drive_car(c: Dictionary, thr: float, brk: float, hb: float, steer: float, dt: float) -> void:
	var fwd = Vector3(sin(c.heading), 0, cos(c.heading))
	var vf = c.vel.x * fwd.x + c.vel.z * fwd.z
	var sf = clamp(abs(vf) / 5.0, 0.0, 1.0) * (-1.0 if vf < 0 else 1.0)
	c.heading -= steer * (3.0 if hb > 0 else 2.0) * sf * dt / (1.0 + abs(vf) * 0.012)
	fwd = Vector3(sin(c.heading), 0, cos(c.heading))
	var rv = Vector3(-fwd.z, 0, fwd.x)
	if thr > 0:
		var acc = 13.5 * (1.0 - clamp(vf / 33.0, 0.0, 1.0)) * thr
		c.vel.x += fwd.x * acc * dt
		c.vel.z += fwd.z * acc * dt
	if brk > 0:
		if vf > 0.6:
			c.vel.x -= fwd.x * 26.0 * dt
			c.vel.z -= fwd.z * 26.0 * dt
		else:
			c.vel.x -= fwd.x * 7.5 * dt
			c.vel.z -= fwd.z * 7.5 * dt
	var dr = max(0.0, 1.0 - 0.42 * dt)
	c.vel.x *= dr
	c.vel.z *= dr
	if hb > 0:
		var h = max(0.0, 1.0 - 1.5 * dt)
		c.vel.x *= h
		c.vel.z *= h
	var lat = c.vel.x * rv.x + c.vel.z * rv.z
	var gl = lat * min(1.0, (2.2 if hb > 0 else 9.0) * dt)
	c.vel.x -= rv.x * gl
	c.vel.z -= rv.z * gl
	vf = c.vel.x * fwd.x + c.vel.z * fwd.z
	if vf < -9.0:
		var k = -9.0 / vf
		c.vel.x *= k
		c.vel.z *= k
	c.x += c.vel.x * dt
	c.z += c.vel.z * dt

func car_world_collide(car: Dictionary) -> void:
	var cp = Game.collide_circle(Vector3(car.x, 0, car.z), 1.55)
	car.x = cp.x
	car.z = cp.z

func nearest_road_idx(v: float) -> int:
	var bi = 0
	var bd = 999999.0
	for i in range(Game.road_centers.size()):
		var dd = abs(v - float(Game.road_centers[i]))
		if dd < bd:
			bd = dd
			bi = i
	return bi
