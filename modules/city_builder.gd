extends Node3D
## Город: остров, кварталы, здания, деревья, фонари, пропы,
## разметка (штриховая, кромки, зебры, стоп-линии), светофоры с состояниями.

var tl_mm: MultiMesh = null
var tl_data: Array = []
const TL_CYCLE := 14.0
const CROSS_OFF := 6.0
const STOP_OFF := 8.2

func _ready() -> void:
	build_island()
	build_city()
	build_road_markings()
	build_street_lamps()
	build_traffic_lights()
	build_dynamic_lights()
	build_props()

func _process(_dt: float) -> void:
	if tl_mm == null:
		return
	for d in tl_data:
		var s_ns = light_state(d.i, d.j, 1)
		var s_ew = light_state(d.i, d.j, 0)
		var key = s_ns * 10 + s_ew
		if key == d.last:
			continue
		d.last = key
		_set_lamp(d.ns, s_ns)
		_set_lamp(d.ew, s_ew)

## axis: 1 = движение вдоль Z (север-юг), 0 = вдоль X (восток-запад). 0=зелёный,1=жёлтый,2=красный
func light_state(ci: int, cj: int, axis: int) -> int:
	var t = fmod(Time.get_ticks_msec() * 0.001 + (ci * 3 + cj * 5) * 0.7, TL_CYCLE)
	if axis == 1:
		if t < 6.0: return 0
		if t < 7.0: return 1
		return 2
	else:
		if t >= 7.0 and t < 13.0: return 0
		if t >= 13.0: return 1
		return 2

func _set_lamp(idx: Array, st: int) -> void:
	tl_mm.set_instance_color(idx[0], Color(1.0, 0.06, 0.06) if st == 2 else Color(0.22, 0.03, 0.03))
	tl_mm.set_instance_color(idx[1], Color(1.0, 0.55, 0.05) if st == 1 else Color(0.22, 0.14, 0.02))
	tl_mm.set_instance_color(idx[2], Color(0.12, 1.0, 0.25) if st == 0 else Color(0.03, 0.18, 0.06))

func set_shadows_deep(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for ch in n.get_children():
		set_shadows_deep(ch)

func add_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: StandardMaterial3D, collide := false) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = sz
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)
	if collide:
		Game.colliders.append({"x1": pos.x - sz.x / 2.0, "z1": pos.z - sz.z / 2.0, "x2": pos.x + sz.x / 2.0, "z2": pos.z + sz.z / 2.0})
	return m

func build_island() -> void:
	add_box(self, Vector3(4000, 0.1, 4000), Vector3(0, -0.7, 0), Game.make_mat(Color("#4a6a80"), 0.4, 0.15))
	add_box(self, Vector3(Game.CITY + 18, 5, Game.CITY + 18), Vector3(0, -2.5, 0), Game.make_mat(Color("#4a463e"), 1.0))
	# асфальт: высокая шероховатость = без влажных бликов
	add_box(self, Vector3(Game.CITY, 0.05, Game.CITY), Vector3(0, 0.02, 0), Game.textured_mat(Game.assets.road_tex, Color("#20242a"), 1.0, 8.0))
func make_building_mat(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D
	if Game.assets.facade_textures.size() > 0:
		m = StandardMaterial3D.new()
		m.albedo_texture = Game.pick_arr(Game.assets.facade_textures)
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	else:
		m = Game.make_mat(col, 0.98)
		m.emission_enabled = true
		m.emission = Color("#d8b070")
		m.emission_energy_multiplier = 0.02
		Game.bld_mats.append(m)
	return m

func build_city() -> void:
	var facade_cols = [Color("#7d7a74"),Color("#8a7d70"),Color("#6f6a64"),Color("#7e7168"),Color("#64686b"),Color("#7a6a5e"),Color("#5f5c57"),Color("#767058")]
	var roof_m = Game.make_mat(Color("#33352f"), 1.0)
	var grass_m = Game.textured_mat(Game.assets.grass_tex, Color("#6f6a3c"), 1.0, 4.0)
	var slab_m = Game.textured_mat(Game.assets.sidewalk_tex, Color("#77736a"), 1.0, 4.0)
	var trunk_m = Game.make_mat(Color("#4a3a28"), 1.0)
	var fol_cols = [Color("#b5651d"),Color("#c9a227"),Color("#8b5a2b"),Color("#7a3b2e"),Color("#9a6b28")]
	for i in range(Game.N):
		for j in range(Game.N):
			var cx = float(Game.road_centers[i]) + Game.PITCH / 2.0
			var cz = float(Game.road_centers[j]) + Game.PITCH / 2.0
			var is_park = (i == 3 and j == 3)
			var is_house = (i == 2 and j == 3)
			var slab_mat = grass_m if (is_park or is_house) else slab_m
			add_box(self, Vector3(Game.BLOCK, 0.3, Game.BLOCK), Vector3(cx, 0.17, cz), slab_mat)
			Game.block_info.append({"cx": cx, "cz": cz, "park": is_park, "house": is_house})
			if is_house:
				add_tree(cx + 11, cz + 9, trunk_m, fol_cols)
				add_tree(cx - 11, cz - 8, trunk_m, fol_cols)
				add_box(self, Vector3(10, 5.5, 9), Vector3(cx, Game.SLAB + 2.75, cz), make_building_mat(Game.pick_arr(facade_cols)), true)
				add_box(self, Vector3(10.3, 0.2, 9.3), Vector3(cx, Game.SLAB + 5.6, cz), roof_m, true)
				add_box(self, Vector3(1.3, 2.3, 0.1), Vector3(cx, Game.SLAB + 1.15, cz - 4.56), Game.make_mat(Color("#3ac95e"), 0.5, 0.0, Color("#3ac95e"), 2.0))
				add_prop(cx + 3.5, cz - 6, "trash")
				continue
			if is_park:
				for k in range(12):
					add_tree(cx + Game.rf(-13, 13), cz + Game.rf(-13, 13), trunk_m, fol_cols)
				continue
			var boost = 1.0 + (5.0 - (abs(float(i) - 2.5) + abs(float(j) - 2.5))) * 0.12
			for li in range(2):
				for lj in range(2):
					if Game.rf(0, 1) < 0.08:
						continue
					var lx = cx + (1.0 if li == 1 else -1.0) * Game.BLOCK / 4.0 + Game.rf(-1, 1)
					var lz = cz + (1.0 if lj == 1 else -1.0) * Game.BLOCK / 4.0 + Game.rf(-1, 1)
					var h = Game.rf(7, 15)
					if Game.rf(0, 1) < 0.33:
						h += Game.rf(8, 30) * boost
					h = min(h, 52.0)
					var w = min(Game.rf(9.5, 13.5), 2.0 * (15.4 - abs(lx - cx)))
					var d = min(Game.rf(9.5, 13.5), 2.0 * (15.4 - abs(lz - cz)))
					add_building(lx, lz, max(w, 5.0), max(d, 5.0), h, Game.pick_arr(facade_cols), roof_m)
			if Game.rf(0, 1) < 0.45:
				var e = Game.ri(0, 3)
				var o = Game.rf(-8, 8)
				var inset = Game.BLOCK / 2.0 - 0.8
				var tx = cx + (inset if e == 0 else (-inset if e == 1 else o))
				var tz = cz + (inset if e == 2 else (-inset if e == 3 else o))
				add_tree(tx, tz, trunk_m, fol_cols)

func add_building(x: float, z: float, w: float, d: float, h: float, col: Color, roof_m: StandardMaterial3D) -> void:
	add_box(self, Vector3(w, h, d), Vector3(x, Game.SLAB + h / 2.0, z), make_building_mat(col), true)
	add_box(self, Vector3(w + 0.15, 0.16, d + 0.15), Vector3(x, Game.SLAB + h + 0.08, z), roof_m, true)
	if h > 32 and Game.rf(0, 1) < 0.7:
		var a = MeshInstance3D.new()
		var am = CylinderMesh.new()
		am.top_radius = 0.04
		am.bottom_radius = 0.04
		am.height = 3
		a.mesh = am
		a.material_override = roof_m
		a.position = Vector3(x, Game.SLAB + h + 1.5, z)
		add_child(a)

func add_tree(x: float, z: float, trunk_m: StandardMaterial3D, fol_cols: Array) -> void:
	var s = Game.rf(0.8, 1.35)
	if Game.assets.models.has("tree"):
		var inst = Game.assets.models["tree"].instantiate()
		inst.position = Vector3(x, 0, z)
		inst.scale = Vector3(s, s, s)
		inst.rotation.y = Game.rf(0, TAU)
		add_child(inst)
		set_shadows_deep(inst)
	else:
		var g = Node3D.new()
		g.position = Vector3(x, 0, z)
		var t = MeshInstance3D.new()
		var tm = CylinderMesh.new()
		tm.top_radius = 0.14 * s
		tm.bottom_radius = 0.2 * s
		tm.height = 1.6 * s
		t.mesh = tm
		t.material_override = trunk_m
		t.position.y = 0.8 * s
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		g.add_child(t)
		if Game.rf(0, 1) < 0.75:
			var f = MeshInstance3D.new()
			var fm = SphereMesh.new()
			fm.radius = 1.3 * s
			fm.height = 2.6 * s
			f.mesh = fm
			f.material_override = Game.make_mat(Game.pick_arr(fol_cols), 1.0)
			f.position.y = (1.6 + 0.9) * s
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			g.add_child(f)
		add_child(g)
	Game.colliders.append({"x1": x - 0.3, "z1": z - 0.3, "x2": x + 0.3, "z2": z + 0.3})

## Вся разметка одним MultiMesh: штриховая, кромочные линии, зебры, стоп-линии.
## ВАЖНО: sx = длина по мировой X, sz = длина по мировой Z.
func build_road_markings() -> void:
	var items: Array = []  # {x, z, sx, sz}
	var RC = Game.road_centers
	# штриховая осевая
	for r in RC:
		# вертикальная дорога (идёт вдоль Z), штрихи вытянуты вдоль Z
		var z = -Game.HALF + 4.0
		while z < Game.HALF - 4:
			var skip = false
			for q in RC:
				if abs(z - float(q)) < 10.0:
					skip = true
					break
			if not skip:
				items.append({"x": float(r), "z": z, "sx": 0.22, "sz": 2.6})
			z += 6.0
		# горизонтальная дорога (идёт вдоль X), штрихи вытянуты вдоль X
		var x = -Game.HALF + 4.0
		while x < Game.HALF - 4:
			var skip = false
			for q in RC:
				if abs(x - float(q)) < 10.0:
					skip = true
					break
			if not skip:
				items.append({"x": x, "z": float(r), "sx": 2.6, "sz": 0.22})
			x += 6.0
	# кромочные сплошные по сегментам между перекрёстками
	for r in RC:
		for j in range(Game.N):
			var mid = (float(RC[j]) + float(RC[j + 1])) * 0.5
			var len = Game.PITCH - 22.0
			for s in [-1.0, 1.0]:
				items.append({"x": float(r) + s * 6.3, "z": mid, "sx": 0.18, "sz": len})
				items.append({"x": mid, "z": float(r) + s * 6.3, "sx": len, "sz": 0.18})
	# перекрёстки: зебры + стоп-линии
	for cx in RC:
		for cz in RC:
			var cxf = float(cx)
			var czf = float(cz)
			for s in [-1.0, 1.0]:
				for k in range(-3, 4):
					# зебра на северной/южной стороне: полосы длинные вдоль X,
					# стоят в ряд вдоль Z (пешеход идёт вдоль X, полосы поперёк)
					items.append({"x": cxf, "z": czf + s * CROSS_OFF + k * 1.2, "sx": 2.4, "sz": 0.6})
					# зебра на западной/восточной стороне: полосы длинные вдоль Z,
					# стоят в ряд вдоль X
					items.append({"x": cxf + s * CROSS_OFF + k * 1.2, "z": czf, "sx": 0.6, "sz": 2.4})
			# стоп-линии
			items.append({"x": cxf, "z": czf - STOP_OFF, "sx": 5.0, "sz": 0.4})
			items.append({"x": cxf, "z": czf + STOP_OFF, "sx": 5.0, "sz": 0.4})
			items.append({"x": cxf - STOP_OFF, "z": czf, "sx": 0.4, "sz": 5.0})
			items.append({"x": cxf + STOP_OFF, "z": czf, "sx": 0.4, "sz": 5.0})
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = items.size()
	mm.visible_instance_count = items.size()
	# PlaneMesh в Godot 4 лежит в плоскости XZ, нормаль вверх.
	# Никаких поворотов не нужно — просто масштабируем по X и Z.
	var pm = PlaneMesh.new()
	pm.size = Vector2(1, 1)
	pm.orientation = PlaneMesh.FACE_Y
	mm.mesh = pm
	for k in range(items.size()):
		var it = items[k]
		var tr = Transform3D()
		# масштаб по мировой X = sx, по мировой Z = sz, Y не трогаем
		tr.basis = Basis.from_scale(Vector3(it.sx, 1.0, it.sz))
		tr.origin = Vector3(it.x, 0.047, it.z)
		mm.set_instance_transform(k, tr)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Game.make_mat(Color("#c8c4b4"), 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func build_street_lamps() -> void:
	var pole_m = Game.make_mat(Color("#33363a"), 0.8)
	var head_m = Game.make_mat(Color("#2e2e2c"), 0.5, 0.0, Color("#ffc37e"), 0.0)
	var defs: Array = []
	for i in range(Game.N + 1):
		var z = -Game.HALF + 8.0
		while z <= Game.HALF - 8:
			var near_road = false
			for r in Game.road_centers:
				if abs(z - float(r)) < 9.0:
					near_road = true
					break
			if not near_road:
				for s in [-1.0, 1.0]:
					defs.append({"x": float(Game.road_centers[i]) + s * (Game.ROAD / 2.0 + 0.9), "z": z, "ry": atan2(-s, 0)})
			z += 20.0
		var x = -Game.HALF + 8.0
		while x <= Game.HALF - 8:
			var near_road = false
			for r in Game.road_centers:
				if abs(x - float(r)) < 9.0:
					near_road = true
					break
			if not near_road:
				for s in [-1.0, 1.0]:
					defs.append({"x": x, "z": float(Game.road_centers[i]) + s * (Game.ROAD / 2.0 + 0.9), "ry": atan2(0, -s)})
			x += 20.0
	for L in defs:
		var dx = sin(L.ry)
		var dz = cos(L.ry)
		if Game.assets.models.has("lamp"):
			var inst = Game.assets.models["lamp"].instantiate()
			inst.position = Vector3(L.x, 0, L.z)
			inst.rotation.y = L.ry
			add_child(inst)
			set_shadows_deep(inst)
		else:
			var pole = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.07
			pm.bottom_radius = 0.09
			pm.height = 5.2
			pole.mesh = pm
			pole.material_override = pole_m
			pole.position = Vector3(L.x, 2.6, L.z)
			add_child(pole)
			var head = MeshInstance3D.new()
			var hm = BoxMesh.new()
			hm.size = Vector3(0.7, 0.16, 0.35)
			head.mesh = hm
			head.material_override = head_m
			head.position = Vector3(L.x + dx, 5.15, L.z + dz)
			head.rotation.y = L.ry
			add_child(head)
		var gl = MeshInstance3D.new()
		var sp = SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		gl.mesh = sp
		var gmat = Game.make_mat(Color("#ffc37e"), 0.1, 0.0, Color("#ffc37e"), 0.0)
		gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gmat.albedo_color = Color("#ffc37e", 0.0)
		gl.material_override = gmat
		gl.position = Vector3(L.x + dx, 4.95, L.z + dz)
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(gl)
		Game.lamp_glows.append(gl)
		Game.street_lights.append({"pos": Vector3(L.x + dx, 4.9, L.z + dz), "light": null})

## Светофоры: корпус — серый (shaded, с тенями), лампы — отдельный MultiMesh (unshaded).
## Итого 2 MultiMeshInstance3D на все перекрёстки.
func build_traffic_lights() -> void:
	var body_col = Color("#6e7176")     # серый корпус
	var dark = Color("#2a2c2f")         # тёмная подложка под лампы
	var items_body: Array = []          # {t:Transform3D, c:Color}
	var items_lamp: Array = []          # {t:Transform3D, c:Color}
	tl_data.clear()
	for i in range(Game.N + 1):
		for j in range(Game.N + 1):
			var cx = float(Game.road_centers[i])
			var cz = float(Game.road_centers[j])
			var body_base = items_body.size()
			var lamp_base = items_lamp.size()
			# NS-голова: западно-северный угол, смотрит на юг (-Z)
			var nx = cx - 7.8
			var nz = cz + 7.8
			items_body.append(_tl_inst(Vector3(nx, 1.4, nz), 0.0, Vector3(0.09, 2.8, 0.09), body_col))
			items_body.append(_tl_inst(Vector3(nx, 2.85, nz), 0.0, Vector3(0.18, 0.66, 0.16), body_col))
			# 3 лампы NS
			items_lamp.append(_tl_inst(Vector3(nx, 3.05, nz - 0.1), 0.0, Vector3(0.11, 0.11, 0.06), dark))
			items_lamp.append(_tl_inst(Vector3(nx, 2.85, nz - 0.1), 0.0, Vector3(0.11, 0.11, 0.06), dark))
			items_lamp.append(_tl_inst(Vector3(nx, 2.65, nz - 0.1), 0.0, Vector3(0.11, 0.11, 0.06), dark))
			# EW-голова: юго-восточный угол, смотрит на запад (-X)
			var ex = cx + 7.8
			var ez = cz + 7.8
			items_body.append(_tl_inst(Vector3(ex, 1.4, ez), PI / 2.0, Vector3(0.09, 2.8, 0.09), body_col))
			items_body.append(_tl_inst(Vector3(ex, 2.85, ez), PI / 2.0, Vector3(0.18, 0.66, 0.16), body_col))
			# 3 лампы EW
			items_lamp.append(_tl_inst(Vector3(ex - 0.1, 3.05, ez), PI / 2.0, Vector3(0.11, 0.11, 0.06), dark))
			items_lamp.append(_tl_inst(Vector3(ex - 0.1, 2.85, ez), PI / 2.0, Vector3(0.11, 0.11, 0.06), dark))
			items_lamp.append(_tl_inst(Vector3(ex - 0.1, 2.65, ez), PI / 2.0, Vector3(0.11, 0.11, 0.06), dark))
			tl_data.append({"i": i, "j": j, "last": -1,
				"ns": [lamp_base + 0, lamp_base + 1, lamp_base + 2],
				"ew": [lamp_base + 3, lamp_base + 4, lamp_base + 5]})
	# --- корпус ---
	var mm_body = MultiMesh.new()
	mm_body.transform_format = MultiMesh.TRANSFORM_3D
	mm_body.use_colors = true
	mm_body.instance_count = items_body.size()
	mm_body.visible_instance_count = items_body.size()
	var bm_body = BoxMesh.new()
	bm_body.size = Vector3(1, 1, 1)
	mm_body.mesh = bm_body
	for k in range(items_body.size()):
		mm_body.set_instance_transform(k, items_body[k].t)
		mm_body.set_instance_color(k, items_body[k].c)
	var mi_body = MultiMeshInstance3D.new()
	mi_body.multimesh = mm_body
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color.WHITE
	body_mat.roughness = 0.55
	body_mat.metallic = 0.35
	mi_body.material_override = body_mat
	mi_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi_body)
	# --- лампы ---
	var mm_lamp = MultiMesh.new()
	mm_lamp.transform_format = MultiMesh.TRANSFORM_3D
	mm_lamp.use_colors = true
	mm_lamp.instance_count = items_lamp.size()
	mm_lamp.visible_instance_count = items_lamp.size()
	var bm_lamp = BoxMesh.new()
	bm_lamp.size = Vector3(1, 1, 1)
	mm_lamp.mesh = bm_lamp
	for k in range(items_lamp.size()):
		mm_lamp.set_instance_transform(k, items_lamp[k].t)
		mm_lamp.set_instance_color(k, items_lamp[k].c)
	tl_mm = mm_lamp
	var mi_lamp = MultiMeshInstance3D.new()
	mi_lamp.multimesh = mm_lamp
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color.WHITE
	lamp_mat.roughness = 0.5
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi_lamp.material_override = lamp_mat
	mi_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi_lamp)
	# форсируем обновление ламп
	for d in tl_data:
		d.last = -2

func _tl_inst(pos: Vector3, ry: float, scale: Vector3, col: Color) -> Dictionary:
	var tr = Transform3D()
	tr.basis = Basis(Vector3.UP, ry) * Basis.from_scale(scale)
	tr.origin = pos
	return {"t": tr, "c": col}

func build_dynamic_lights() -> void:
	# каждому фонарю — СВОЙ OmniLight3D, постоянно привязанный к позиции
	for sl in Game.street_lights:
		var l = OmniLight3D.new()
		l.light_color = Color("#ffc37e")
		l.light_energy = 0.0
		l.omni_range = 26.0
		l.omni_attenuation = 1.5
		l.position = sl.pos
		add_child(l)
		sl.light = l

func build_props() -> void:
	for b in Game.block_info:
		var n = Game.ri(2, 4)
		for k in range(n):
			var e = Game.ri(0, 3)
			var t = Game.rf(-15, 15)
			var ins = 16.2
			var x = float(b.cx) + (ins if e == 0 else (-ins if e == 1 else t))
			var z = float(b.cz) + (ins if e == 2 else (-ins if e == 3 else t))
			var types = ["trash","trash","crate","hydrant","dumpster","barrier","crate"]
			var type = Game.pick_arr(types)
			if b.park and Game.rf(0, 1) < 0.5:
				type = "bench"
			add_prop(x, z, type)

func add_prop(x: float, z: float, type: String) -> void:
	var hp = 30.0
	var r = 0.4
	if type == "dumpster": hp = 50.0; r = 0.9
	elif type == "hydrant": hp = 20.0; r = 0.25
	elif type == "barrier": hp = 80.0; r = 0.9
	elif type == "crate": hp = 15.0; r = 0.35
	elif type == "bench": hp = 40.0; r = 0.8
	var node: Node3D = null
	if Game.assets.models.has(type):
		node = Game.assets.models[type].instantiate()
		node.position = Vector3(x, 0, z)
		node.rotation.y = Game.rf(0, TAU)
		set_shadows_deep(node)
	else:
		var mesh = MeshInstance3D.new()
		if type == "trash":
			var cm = CylinderMesh.new(); cm.top_radius = 0.28; cm.bottom_radius = 0.3; cm.height = 0.8
			mesh.mesh = cm; mesh.material_override = Game.make_mat(Color("#4a5a4a"), 0.9); mesh.position = Vector3(x, 0.4, z)
		elif type == "dumpster":
			var bm = BoxMesh.new(); bm.size = Vector3(1.7, 1, 1.1)
			mesh.mesh = bm; mesh.material_override = Game.make_mat(Color("#2e4a36"), 0.9); mesh.position = Vector3(x, 0.5, z); mesh.rotation.y = Game.rf(0, TAU)
		elif type == "hydrant":
			var cm = CylinderMesh.new(); cm.top_radius = 0.14; cm.bottom_radius = 0.18; cm.height = 0.6
			mesh.mesh = cm; mesh.material_override = Game.make_mat(Color("#8a3a2e"), 0.8); mesh.position = Vector3(x, 0.3, z)
		elif type == "barrier":
			var bm = BoxMesh.new(); bm.size = Vector3(1.8, 0.8, 0.4)
			mesh.mesh = bm; mesh.material_override = Game.make_mat(Color("#7a7a72"), 0.95); mesh.position = Vector3(x, 0.4, z); mesh.rotation.y = Game.rf(0, TAU)
		elif type == "crate":
			var bm = BoxMesh.new(); bm.size = Vector3(0.6, 0.6, 0.6)
			mesh.mesh = bm; mesh.material_override = Game.make_mat(Color("#6a5232"), 0.95); mesh.position = Vector3(x, 0.3, z); mesh.rotation.y = Game.rf(0, TAU)
		elif type == "bench":
			var bm = BoxMesh.new(); bm.size = Vector3(1.6, 0.45, 0.5)
			mesh.mesh = bm; mesh.material_override = Game.make_mat(Color("#5a4632"), 0.9); mesh.position = Vector3(x, 0.25, z); mesh.rotation.y = Game.rf(0, TAU)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node = mesh
	add_child(node)
	var prop = {"mesh": node, "x": x, "z": z, "hp": hp, "max_hp": hp, "dead": false, "r": r, "type": type}
	node.set_meta("kind", "prop")
	node.set_meta("ref", prop)
	Game.props.append(prop)
	Game.colliders.append({"x1": x - r, "z1": z - r, "x2": x + r, "z2": z + r})
