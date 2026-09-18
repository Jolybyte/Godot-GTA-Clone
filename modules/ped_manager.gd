extends Node
## Пешеходы, бандиты, их ИИ, динамический перенос, выброс водителей.
## Оптимизация: MultiMesh LOD, разделение движения и AI,
## кэш Basis для поворотов, frustum culling, отключение анимации для дальних.

const AI_BUDGET := 40          # сколько педов обрабатывать AI за кадр (round-robin)
const AI_MAX_DIST := 120.0     # дальше — вообще не трогаем AI
const ANIM_DIST := 50.0        # дальше — не анимируем (было 60)
const SIMPLE_DIST := 90.0      # дальше — показываем MultiMesh LOD
const FRUSTUM_MARGIN := 5.0    # запас за границей frustum (метры)

var _ai_cursor: int = 0
var _simple_mm: MultiMeshInstance3D = null
var _simple_count: int = 0

# --- Кэш Basis для 16 секторов поворота ---
var _rot_cache: Array = []
var _rot_cache_step: float = 0.0

# --- Frustum камеры (обновляется раз в кадр) ---
var _frustum_planes: Array = []
var _frustum_ready: bool = false


func _ready() -> void:
	_build_rot_cache()
	_setup_simple_multimesh()
	build_peds()


func _process(dt: float) -> void:
	if not Game.playing:
		return
	_update_frustum()
	update_peds(dt)
	dynamic_relocate(dt)


# =========================================================
# Базовые утилиты
# =========================================================

func _zero_transform() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)


func _valid_node(v) -> bool:
	if v == null:
		return false
	if typeof(v) != TYPE_OBJECT:
		return false
	return is_instance_valid(v)


func _pick_random(arr):
	if arr == null or arr.is_empty():
		return null
	return arr[randi() % arr.size()]


func _posmodi(value: int, modulus: int) -> int:
	if modulus <= 0:
		return 0
	var r = value % modulus
	if r < 0:
		r += modulus
	return r


func _safe_rot_index(h: float) -> int:
	if _rot_cache.is_empty() or _rot_cache_step <= 0.0:
		_build_rot_cache()

	if _rot_cache.is_empty() or _rot_cache_step <= 0.0:
		return 0

	if is_nan(h) or is_inf(h):
		return 0

	return _posmodi(int(h / _rot_cache_step), _rot_cache.size())


func _relocate_far_traffic_safe() -> void:
	if Game.vehicles != null and Game.vehicles.has_method("relocate_far_traffic"):
		Game.vehicles.relocate_far_traffic()


# =========================================================
# Кэш поворотов
# =========================================================

func _build_rot_cache() -> void:
	var n = 16
	_rot_cache.clear()
	_rot_cache_step = TAU / float(n)

	for i in range(n):
		_rot_cache.append(Basis().rotated(Vector3.UP, i * _rot_cache_step))


# =========================================================
# MultiMesh setup
# =========================================================

func _setup_simple_multimesh() -> void:
	if _simple_mm != null and is_instance_valid(_simple_mm):
		_simple_mm.queue_free()

	_simple_count = 0
	_simple_mm = MultiMeshInstance3D.new()

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = false

	var box = BoxMesh.new()
	box.size = Vector3(0.46, 1.62, 0.3)
	mm.mesh = box

	var reserve = int(Game.PED_COUNT) + 32
	if reserve < 32:
		reserve = 32
	mm.instance_count = reserve

	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	_simple_mm.multimesh = mm
	_simple_mm.material_override = mat
	_simple_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_simple_mm)

	var zero = _zero_transform()
	for i in range(mm.instance_count):
		mm.set_instance_transform(i, zero)
		mm.set_instance_color(i, Color.WHITE)


func _ensure_mm_capacity() -> void:
	if _simple_mm == null or _simple_mm.multimesh == null:
		return

	var mm = _simple_mm.multimesh
	if _simple_count < mm.instance_count:
		return

	var old_count = mm.instance_count
	var new_count = old_count + 32
	mm.instance_count = new_count

	var zero = _zero_transform()
	for j in range(old_count, new_count):
		mm.set_instance_transform(j, zero)
		mm.set_instance_color(j, Color.WHITE)


# =========================================================
# Спавн
# =========================================================

func build_peds() -> void:
	var civ_count = int(Game.PED_COUNT) - int(Game.BANDIT_GROUPS) * 3
	if civ_count < 0:
		civ_count = 0

	for i in range(civ_count):
		spawn_civ()

	spawn_bandits()


func spawn_civ() -> void:
	if Game.block_info == null or Game.block_info.is_empty():
		return

	var b = _pick_random(Game.block_info)
	if b == null:
		return

	var s = Game.BLOCK / 2.0 - 2.0
	var corners = [[1, 1], [-1, 1], [-1, -1], [1, -1]]
	var c = _pick_random(corners)
	if c == null:
		return

	var shirts = [
		Color("#7a5a44"),
		Color("#4a5a6a"),
		Color("#6a644a"),
		Color("#4a6a55"),
		Color("#8a857a")
	]
	var pants_arr = [
		Color("#2e3238"),
		Color("#3a3228"),
		Color("#24343a"),
		Color("#33302a")
	]
	var skins = [
		Color("#c98d64"),
		Color("#8a5a3a"),
		Color("#e0b090"),
		Color("#6a4a30")
	]

	var shirt = _pick_random(shirts)
	var pants = _pick_random(pants_arr)
	var skin = _pick_random(skins)

	if shirt == null:
		shirt = Color("#7a5a44")
	if pants == null:
		pants = Color("#2e3238")
	if skin == null:
		skin = Color("#c98d64")

	var colors = {
		"shirt": shirt,
		"pants": pants,
		"skin": skin,
		"cap": Color.BLACK
	}

	var rig = make_human(colors.shirt, colors.pants, colors.skin, colors.cap, false)

	var bx = float(b.get("cx", 0.0))
	var bz = float(b.get("cz", 0.0))
	make_ped_obj(rig, bx + float(c[0]) * s, bz + float(c[1]) * s, b, colors)


func spawn_bandits() -> void:
	if Game.block_info == null or Game.block_info.is_empty():
		return

	for gi in range(int(Game.BANDIT_GROUPS)):
		var b = _pick_random(Game.block_info)
		if b == null:
			continue

		var s = Game.BLOCK / 2.0 - 2.0
		var corners = [[1, 1], [-1, 1], [-1, -1], [1, -1]]
		var c = _pick_random(corners)
		if c == null:
			continue

		for k in range(3):
			var shirt_arr = [
				Color("#3a2828"),
				Color("#24242c"),
				Color("#2c2a26")
			]
			var shirt = _pick_random(shirt_arr)
			if shirt == null:
				shirt = Color("#24242c")

			var colors = {
				"shirt": shirt,
				"pants": Color("#1a1a1e"),
				"skin": Color("#c98d64"),
				"cap": Color("#6a2020")
			}

			var rig = make_human(colors.shirt, colors.pants, colors.skin, colors.cap, true)

			var bx = float(b.get("cx", 0.0))
			var bz = float(b.get("cz", 0.0))

			var p = make_ped_obj(
				rig,
				bx + float(c[0]) * s + Game.rf(-2, 2),
				bz + float(c[1]) * s + Game.rf(-2, 2),
				b,
				colors
			)

			p.is_bandit = true
			p.hp = 50.0
			p.speed = Game.rf(4.5, 5.5)


func make_human(shirt: Color, pants: Color, skin: Color, cap: Color, armed: bool) -> Dictionary:
	var g = Node3D.new()
	var detail = Node3D.new()
	g.add_child(detail)

	var ms = Game.make_mat(shirt, 0.95)
	var mp = Game.make_mat(pants, 0.95)
	var mk = Game.make_mat(skin, 0.85)

	var lg = BoxMesh.new()
	lg.size = Vector3(0.17, 0.78, 0.17)

	var ag = BoxMesh.new()
	ag.size = Vector3(0.13, 0.6, 0.13)

	var legL = Node3D.new()
	legL.position = Vector3(0.1, 0.8, 0)
	detail.add_child(legL)

	var legLm = MeshInstance3D.new()
	legLm.mesh = lg
	legLm.material_override = mp
	legLm.position = Vector3(0, -0.39, 0)
	legL.add_child(legLm)

	var legR = Node3D.new()
	legR.position = Vector3(-0.1, 0.8, 0)
	detail.add_child(legR)

	var legRm = MeshInstance3D.new()
	legRm.mesh = lg
	legRm.material_override = mp
	legRm.position = Vector3(0, -0.39, 0)
	legR.add_child(legRm)

	var torso = MeshInstance3D.new()
	var tb = BoxMesh.new()
	tb.size = Vector3(0.42, 0.56, 0.24)
	torso.mesh = tb
	torso.material_override = ms
	torso.position = Vector3(0, 1.08, 0)
	detail.add_child(torso)

	var armL = Node3D.new()
	armL.position = Vector3(0.28, 1.32, 0)
	detail.add_child(armL)

	var armLm = MeshInstance3D.new()
	armLm.mesh = ag
	armLm.material_override = ms
	armLm.position = Vector3(0, -0.3, 0)
	armL.add_child(armLm)

	var armR = Node3D.new()
	armR.position = Vector3(-0.28, 1.32, 0)
	detail.add_child(armR)

	var armRm = MeshInstance3D.new()
	armRm.mesh = ag
	armRm.material_override = ms
	armRm.position = Vector3(0, -0.3, 0)
	armR.add_child(armRm)

	var head = MeshInstance3D.new()
	var hg = BoxMesh.new()
	hg.size = Vector3(0.25, 0.27, 0.25)
	head.mesh = hg
	head.material_override = mk
	head.position = Vector3(0, 1.53, 0)
	detail.add_child(head)

	if cap != Color.BLACK:
		var cap_mesh = MeshInstance3D.new()
		var cg = BoxMesh.new()
		cg.size = Vector3(0.28, 0.08, 0.3)
		cap_mesh.mesh = cg
		cap_mesh.material_override = Game.make_mat(cap, 0.95)
		cap_mesh.position = Vector3(0, 1.7, 0)
		detail.add_child(cap_mesh)

	if armed:
		var gun = MeshInstance3D.new()
		var gg = BoxMesh.new()
		gg.size = Vector3(0.05, 0.09, 0.26)
		gun.mesh = gg
		gun.material_override = Game.make_mat(Color("#1e2126"), 0.5, 0.4)
		gun.position = Vector3(0, -0.55, 0.1)
		armR.add_child(gun)

	return {
		"grp": g,
		"detail": detail,
		"legL": legL,
		"legR": legR,
		"armL": armL,
		"armR": armR
	}


func make_ped_obj(rig: Dictionary, x: float, z: float, block: Dictionary, colors: Dictionary) -> Dictionary:
	rig.grp.position = Vector3(x, 0, z)
	add_child(rig.grp)

	var p = {
		"rig": rig,
		"x": x,
		"z": z,
		"heading": Game.rf(0, TAU),
		"phase": Game.rf(0, TAU),
		"state": "walk",
		"hp": 30.0,
		"is_cop": false,
		"is_bandit": false,
		"is_target": false,
		"speed": Game.rf(2.2, 3.2),
		"block": block,
		"idx": randi() % 4,
		"cw": Game.rf(0, 1) < 0.5,
		"flee_t": 0.0,
		"flee_h": 0.0,
		"grab_t": 0.0,
		"shoot_cd": 0.0,
		"aggro": false,
		"partner": null,
		"state_t": 0.0,
		"seed": Game.rf(0, 10),
		"colors": colors,
		"hit_y": 1.1,
		"hit_side": 1.0,
		"headshot": false,
		"_mm_slot": -1,
		"_is_simple": false,
		"_move_intent": "stand",
		"dead": false,
		"_last_rot_idx": -1,
		"_frustum_visible": true
	}

	if _simple_mm != null and _simple_mm.multimesh != null:
		_ensure_mm_capacity()
		var mm = _simple_mm.multimesh
		if _simple_count < mm.instance_count:
			p._mm_slot = _simple_count
			_simple_count += 1

			var col = Color.WHITE
			if typeof(colors) == TYPE_DICTIONARY:
				col = colors.get("shirt", Color.WHITE)

			mm.set_instance_color(p._mm_slot, col)

	if Game.peds == null:
		Game.peds = []

	Game.peds.append(p)
	return p


func eject_driver_as_fleeing_ped(car: Dictionary) -> void:
	if car == null:
		return

	var c = car.get("driver_colors", null)
	if typeof(c) != TYPE_DICTIONARY:
		c = {
			"shirt": Color("#7a5a44"),
			"pants": Color("#2e3238"),
			"skin": Color("#c98d64"),
			"cap": Color.BLACK
		}
	else:
		c = {
			"shirt": c.get("shirt", Color("#7a5a44")),
			"pants": c.get("pants", Color("#2e3238")),
			"skin": c.get("skin", Color("#c98d64")),
			"cap": Color.BLACK
		}

	var heading = float(car.get("heading", 0.0))
	var fwd = Vector3(sin(heading), 0, cos(heading))
	var r = Vector3(-fwd.z, 0, fwd.x)

	var cx = float(car.get("x", 0.0))
	var cz = float(car.get("z", 0.0))

	var ex = cx + r.x * 2.2
	var ez = cz + r.z * 2.2

	var rig = make_human(c.shirt, c.pants, c.skin, c.cap, false)
	var p = make_ped_obj(rig, ex, ez, {}, c)

	p.state = "flee"
	p.flee_t = 5.0
	p.flee_h = atan2(ex - cx, ez - cz)

	var vel = car.get("vel", Vector3.ZERO)
	if typeof(vel) == TYPE_VECTOR3:
		p.x += vel.x * 0.1
		p.z += vel.z * 0.1
	else:
		p.x += float(car.get("vx", 0.0)) * 0.1
		p.z += float(car.get("vz", 0.0)) * 0.1


# =========================================================
# Frustum
# =========================================================

func _update_frustum() -> void:
	_frustum_ready = false

	if Game.camera == null:
		return

	var cam = Game.camera
	if not cam.has_method("get_frustum"):
		return

	var planes = cam.get_frustum()
	if planes != null and planes.size() >= 6:
		_frustum_planes = planes
		_frustum_ready = true


func _in_frustum(x: float, z: float) -> bool:
	if not _frustum_ready:
		return true

	var pt = Vector3(x, 1.0, z)
	for pl in _frustum_planes:
		if pl.distance_to(pt) < -FRUSTUM_MARGIN:
			return false

	return true


# =========================================================
# Обновление пешеходов
# =========================================================

func update_peds(dt: float) -> void:
	var cp = Vector3.ZERO
	if Game.camera != null and Game.camera is Node3D:
		cp = Game.camera.global_position

	var peds = Game.peds
	if peds == null or peds.is_empty():
		return

	# --- ФАЗА 1: движение + видимость + анимация ---
	for p in peds:
		if typeof(p) != TYPE_DICTIONARY or bool(p.get("dead", false)):
			if typeof(p) == TYPE_DICTIONARY:
				_clear_mm_slot(p)
			continue

		if not _is_rig_valid(p):
			_clear_mm_slot(p)
			continue

		var px = float(p.get("x", 0.0))
		var pz = float(p.get("z", 0.0))

		var dx = px - cp.x
		var dz = pz - cp.z
		var d2 = dx * dx + dz * dz

		var frustum_visible = bool(p.get("_frustum_visible", true))
		var is_simple = bool(p.get("_is_simple", false))

		# --- Frustum culling: если далеко и вне поля зрения — не трогаем ---
		if d2 > 2500.0 and not _in_frustum(px, pz):
			if frustum_visible:
				p._frustum_visible = false
				if not is_simple:
					_set_rig_visible(p, false)
				_clear_mm_slot(p)
			continue
		elif not frustum_visible:
			# вернулся в поле зрения
			p._frustum_visible = true
			if is_simple:
				_set_mm_transform(p)
			else:
				_set_rig_visible(p, true)

		# Видимость LOD
		var should_be_simple = d2 > SIMPLE_DIST * SIMPLE_DIST
		if should_be_simple != is_simple:
			p._is_simple = should_be_simple
			is_simple = should_be_simple

			_set_rig_visible(p, not is_simple)

			if is_simple:
				_set_mm_transform(p)
			else:
				_clear_mm_slot(p)

		# Дальше — обрабатываем только близких (< AI_MAX_DIST)
		if d2 > AI_MAX_DIST * AI_MAX_DIST:
			continue

		# Движение
		var move = str(p.get("_move_intent", "stand"))
		if move == "move":
			p.x = float(p.x) + sin(float(p.heading)) * float(p.speed) * dt
			p.z = float(p.z) + cos(float(p.heading)) * float(p.speed) * dt

		# Коллизия только для близких
		if d2 < 2500.0:
			var corrected = Game.collide_circle(Vector3(float(p.x), 0, float(p.z)), 0.35)
			p.x = corrected.x
			p.z = corrected.z

		# Анимация только для близких
		if d2 < ANIM_DIST * ANIM_DIST and not is_simple:
			animate(p, move)

		# Обновить трансформ
		if is_simple:
			_set_mm_transform(p)
		else:
			_set_rig_world_transform(p)

	# --- ФАЗА 2: AI (бюджетно, round-robin, безопасно) ---
	var budget = AI_BUDGET
	var processed = 0
	var checked = 0

	var max_checks = Game.peds.size()
	if max_checks <= 0:
		return

	var i = _ai_cursor
	if i < 0 or i >= max_checks:
		i = 0

	while checked < max_checks and processed < budget:
		var arr = Game.peds
		if arr == null or arr.is_empty():
			break

		if i < 0 or i >= arr.size():
			i = 0

		var p = arr[i]
		checked += 1

		var next_i = (i + 1) % arr.size()

		if typeof(p) != TYPE_DICTIONARY or bool(p.get("dead", false)) or not bool(p.get("_frustum_visible", true)):
			i = next_i
			continue

		var ax = float(p.get("x", 0.0)) - cp.x
		var az = float(p.get("z", 0.0)) - cp.z
		var ad2 = ax * ax + az * az

		if ad2 > AI_MAX_DIST * AI_MAX_DIST:
			i = next_i
			continue

		var need = ad2 < 2500.0 or (checked % 3 == 0)
		if not need:
			i = next_i
			continue

		processed += 1

		var mv = "stand"
		if bool(p.get("is_cop", false)):
			mv = update_cop_ai(p, dt)
		elif bool(p.get("is_bandit", false)):
			mv = update_bandit_ai(p, dt)
		else:
			mv = update_civ_ai(p, dt)

		p._move_intent = mv

		# После AI массив мог измениться.
		arr = Game.peds
		if arr == null or arr.is_empty():
			i = 0
			break

		if next_i >= arr.size():
			next_i = 0

		i = next_i

	_ai_cursor = i


# =========================================================
# MultiMesh transform helpers
# =========================================================

func _set_mm_transform(p: Dictionary) -> void:
	if _simple_mm == null or _simple_mm.multimesh == null:
		return

	var slot = int(p.get("_mm_slot", -1))
	if slot < 0:
		return

	var mm = _simple_mm.multimesh
	if slot >= mm.instance_count:
		p._mm_slot = -1
		return

	var idx = _safe_rot_index(float(p.get("heading", 0.0)))
	if idx < 0 or idx >= _rot_cache.size():
		idx = 0

	p._last_rot_idx = idx
	var t = Transform3D(_rot_cache[idx], Vector3(float(p.get("x", 0.0)), 0, float(p.get("z", 0.0))))
	mm.set_instance_transform(slot, t)


func _clear_mm_slot(p: Dictionary) -> void:
	if _simple_mm == null or _simple_mm.multimesh == null:
		return

	var slot = int(p.get("_mm_slot", -1))
	if slot < 0:
		return

	var mm = _simple_mm.multimesh
	if slot >= mm.instance_count:
		p._mm_slot = -1
		return

	mm.set_instance_transform(slot, _zero_transform())


# =========================================================
# Rig helpers
# =========================================================

func _is_rig_valid(p: Dictionary) -> bool:
	var rig = p.get("rig", {})
	if typeof(rig) != TYPE_DICTIONARY:
		return false
	return _valid_node(rig.get("grp"))


func _set_rig_visible(p: Dictionary, v: bool) -> void:
	var rig = p.get("rig", {})
	if typeof(rig) != TYPE_DICTIONARY:
		return

	var grp = rig.get("grp")
	if _valid_node(grp):
		grp.visible = v


func _set_rig_world_transform(p: Dictionary) -> void:
	var rig = p.get("rig", {})
	if typeof(rig) != TYPE_DICTIONARY:
		return

	var grp = rig.get("grp")
	if _valid_node(grp):
		grp.global_position = Vector3(float(p.get("x", 0.0)), 0, float(p.get("z", 0.0)))
		grp.rotation.y = float(p.get("heading", 0.0))


# =========================================================
# Анимация
# =========================================================

func animate(p: Dictionary, mv: String) -> void:
	var rig = p.get("rig", {})
	if typeof(rig) != TYPE_DICTIONARY:
		return

	var legL = rig.get("legL")
	var legR = rig.get("legR")
	var armL = rig.get("armL")
	var armR = rig.get("armR")

	if not _valid_node(legL) or not _valid_node(legR) or not _valid_node(armL) or not _valid_node(armR):
		return

	var gun = (bool(p.get("is_cop", false)) and Game.wanted >= 2) or bool(p.get("aggro", false))

	var phase = float(p.get("phase", 0.0))
	if mv == "move":
		phase += float(p.get("speed", 1.0)) * get_process_delta_time() * 1.8
		p.phase = phase

	var s = sin(phase)
	var s2 = sin(phase + PI)
	var amp = 0.75 if mv == "move" else 0.06

	legL.rotation.x = s * 0.75 * amp
	legR.rotation.x = s2 * 0.75 * amp

	if gun:
		armR.rotation.x = -1.52
		armR.rotation.z = -0.12
		armL.rotation.x = -1.25
	else:
		armL.rotation.x = s * 0.6 * amp
		armR.rotation.x = s2 * 0.6 * amp


# =========================================================
# AI
# =========================================================

func update_civ_ai(p: Dictionary, dt: float) -> String:
	var state = str(p.get("state", "walk"))

	if state == "flee":
		var flee_t = float(p.get("flee_t", 0.0)) - dt
		p.flee_t = flee_t

		p.heading = Game.ang_lerp(
			float(p.get("heading", 0.0)),
			float(p.get("flee_h", 0.0)),
			8.0 * dt
		)

		if flee_t <= 0.0:
			p.state = "walk"

		return "move"

	if state == "idle":
		var state_t = float(p.get("state_t", 0.0)) - dt
		p.state_t = state_t

		if state_t <= 0.0:
			p.state = "walk"

		return "stand"

	var block = p.get("block", {})
	if typeof(block) != TYPE_DICTIONARY or block.is_empty():
		return "stand"

	var s = Game.BLOCK / 2.0 - 2.0
	var corners = [[1, 1], [-1, 1], [-1, -1], [1, -1]]

	var idx = _posmodi(int(p.get("idx", 0)), 4)
	var c = corners[idx]

	var tx = float(block.get("cx", 0.0)) + float(c[0]) * s
	var tz = float(block.get("cz", 0.0)) + float(c[1]) * s

	var dx = tx - float(p.x)
	var dz = tz - float(p.z)
	var d = sqrt(dx * dx + dz * dz)

	if d < 0.4:
		var dir = 1 if bool(p.get("cw", false)) else 3
		p.idx = _posmodi(idx + dir, 4)
	else:
		p.heading = Game.ang_lerp(float(p.heading), atan2(dx, dz), 8.0 * dt)

	return "move"


func update_bandit_ai(p: Dictionary, dt: float) -> String:
	var pp = Game.get_focus_pos()
	var d = Vector3(float(p.x), 0, float(p.z)).distance_to(pp)

	if not bool(p.get("aggro", false)):
		return update_civ_ai(p, dt)

	if d > 48.0:
		p.aggro = false
		return "stand"

	p.heading = Game.ang_lerp(
		float(p.heading),
		atan2(pp.x - float(p.x), pp.z - float(p.z)),
		10.0 * dt
	)

	var mv = "stand"

	if d > 14.0:
		p.heading = atan2(pp.x - float(p.x), pp.z - float(p.z))
		mv = "move"
	elif d < 6.0:
		p.heading = atan2(float(p.x) - pp.x, float(p.z) - pp.z)
		mv = "move"

	p.shoot_cd = float(p.get("shoot_cd", 0.0)) - dt

	if p.shoot_cd <= 0.0 and d < 40.0 and not Game.dead and not Game.arrested:
		p.shoot_cd = Game.rf(0.9, 1.7)
		npc_shoot(p, 0.5, 6.0)

	return mv


func update_cop_ai(p: Dictionary, dt: float) -> String:
	var pp = Game.get_focus_pos()

	var dx = pp.x - float(p.x)
	var dz = pp.z - float(p.z)
	var d = sqrt(dx * dx + dz * dz)

	p.heading = Game.ang_lerp(float(p.heading), atan2(dx, dz), 10.0 * dt)

	var mv = "stand"
	var shoot_mode = Game.wanted >= 2

	if Game.in_car == null:
		if d < 1.6:
			p.grab_t = float(p.get("grab_t", 0.0)) + dt
			if p.grab_t > 0.55 and not Game.dead and not Game.arrested:
				Game.do_arrest()
			return "stand"

	p.grab_t = 0.0

	if shoot_mode:
		if d > 16.0:
			mv = "move"

		p.shoot_cd = float(p.get("shoot_cd", 0.0)) - dt

		if p.shoot_cd <= 0.0 and d < 26.0 and not Game.dead and not Game.arrested:
			p.shoot_cd = Game.rf(1.0, 1.6)
			npc_shoot(p, 0.55, 7.0)
	else:
		if d > 1.3:
			mv = "move"

	return mv


func npc_shoot(sh: Dictionary, acc: float, dmg: float) -> void:
	var pp = Game.get_focus_pos()
	var d = Vector3(float(sh.x), 0, float(sh.z)).distance_to(pp)

	if d > 45.0:
		return

	var hit = Game.rf(0, 1) < clamp(acc - d * 0.005, 0.08, 0.6)

	var start = Vector3(float(sh.x), 1.35, float(sh.z))
	var end = Vector3(pp.x, 0.9 if Game.in_car != null else 1.2, pp.z)

	if not hit:
		end.x += Game.rf(-1.6, 1.6)
		end.y += Game.rf(-0.4, 0.8)
		end.z += Game.rf(-1.6, 1.6)

	if Game.combat != null and Game.combat.has_method("add_tracer"):
		Game.combat.add_tracer(start, end)

	if hit:
		if Game.in_car != null:
			if Game.combat != null and Game.combat.has_method("damage_car"):
				Game.combat.damage_car(Game.in_car, dmg * 0.5, false)
		else:
			if Game.has_method("damage_player"):
				Game.damage_player(dmg, "gun")


# =========================================================
# Динамический перенос дальних пешеходов
# =========================================================

func dynamic_relocate(dt: float) -> void:
	if Game.block_info == null or Game.block_info.is_empty():
		_relocate_far_traffic_safe()
		return

	if Game.rf(0, 1) > dt / 1.5:
		return

	var pp = Game.get_focus_pos()
	var cands: Array = []

	for b in Game.block_info:
		if typeof(b) != TYPE_DICTIONARY:
			continue

		var bx = float(b.get("cx", 0.0))
		var bz = float(b.get("cz", 0.0))

		var dd = sqrt((bx - pp.x) * (bx - pp.x) + (bz - pp.z) * (bz - pp.z))
		if dd > 25.0 and dd < 85.0:
			cands.append(b)

	if cands.is_empty():
		_relocate_far_traffic_safe()
		return

	if Game.peds == null or Game.peds.is_empty():
		_relocate_far_traffic_safe()
		return

	var s = Game.BLOCK / 2.0 - 2.0
	var corners = [[1, 1], [-1, 1], [-1, -1], [1, -1]]

	for p in Game.peds:
		if typeof(p) != TYPE_DICTIONARY:
			continue

		if bool(p.get("is_cop", false)) or bool(p.get("is_target", false)):
			continue

		var px = float(p.get("x", 0.0))
		var pz = float(p.get("z", 0.0))
		var d2 = (px - pp.x) * (px - pp.x) + (pz - pp.z) * (pz - pp.z)

		if d2 > 115.0 * 115.0:
			var b = _pick_random(cands)
			if b == null:
				continue

			var c = _pick_random(corners)
			if c == null:
				continue

			p.block = b
			p.idx = randi() % 4
			p.cw = Game.rf(0, 1) < 0.5
			p.state = "walk"
			p.flee_t = 0.0
			p.partner = null

			p.x = float(b.get("cx", 0.0)) + float(c[0]) * s
			p.z = float(b.get("cz", 0.0)) + float(c[1]) * s
			p._move_intent = "stand"

			if bool(p.get("_is_simple", false)) and bool(p.get("_frustum_visible", true)):
				_set_mm_transform(p)

	_relocate_far_traffic_safe()
