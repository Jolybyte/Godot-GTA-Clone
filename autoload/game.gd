extends Node
# Автозагрузчик "Game": общее состояние, константы, сигналы и хелперы.

# ===== КОНСТАНТЫ ГОРОДА =====
const N := 6
const ROAD := 14.0
const BLOCK := 34.0
const PITCH := ROAD + BLOCK
const CITY := float(N) * PITCH + ROAD
const HALF := CITY / 2.0
const SLAB := 0.32
const PED_COUNT := 300
const BANDIT_GROUPS := 8
const TRAFFIC_COUNT := 60
const PARKED_COUNT := 55
const LOD_DIST := 55.0

# ===== СОСТОЯНИЕ ИГРОКА =====
var player_pos := Vector3(9, 0, 9)
var player_heading := 0.0
var player_py := 0.0
var player_vy := 0.0
var player_hp := 100.0
var player_regen_t := 0.0

# ===== СОСТОЯНИЕ ИГРЫ =====
var wanted := 0
var heat := 0.0
var score := 0
var sim_time := 22.4
var night_f := 0.0
var playing := false
var dead := false
var arrested := false
var in_car = null
var muted := false
var blur_on := true

# --- Фары и погода (для day_night.gd) ---
var headlights_forced: bool = false
var rain: bool = false

# ===== ССЫЛКИ (заполняют модули) =====
var player_node: Node3D = null
var player_rig: Dictionary = {}
var camera: Camera3D = null
var marker: Node3D = null
var player_controller = null

# ===== ОБЩИЕ КОЛЛЕКЦИИ =====
var colliders: Array = []
var road_centers: Array = []
var block_info: Array = []
var peds: Array = []
var cars: Array = []
var props: Array = []

# ===== ОСВЕЩЕНИЕ/МАТЕРИАЛЫ =====
var lamp_glows: Array = []
var street_lights: Array = []
var bld_mats: Array = []
var car_body_mats: Array = []
var headlight_mat = null
var taillight_mat = null

# ===== АССЕТЫ =====
var assets := {
	"facade_textures": [],
	"face_tex": null,
	"road_tex": null,
	"sidewalk_tex": null,
	"grass_tex": null,
	"models": {},
}

# ===== РЕЕСТР МОДУЛЕЙ (заполняет main) =====
var combat = null
var police = null
var missions = null
var weapons = null
var vehicles = null
var peds_m = null
var city = null
var audio = null

# ===== СИГНАЛЫ =====
signal ped_killed(ped, cause)
signal wanted_changed(stars)
signal player_damaged(amount)
signal player_died
signal player_arrested
signal respawned
signal car_exploded(car)
signal player_entered_car(car)
signal player_exited_car
signal toast_requested(text, bad)

# ===== RNG =====
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for i in range(N + 1):
		road_centers.append(-HALF + ROAD / 2.0 + float(i) * PITCH)

# ===== ХЕЛПЕРЫ =====
func rf(a: float, b: float) -> float: return rng.randf_range(a, b)
func ri(a: int, b: int) -> int: return rng.randi_range(a, b)
func pick_arr(a: Array): return a[ri(0, a.size() - 1)]
func norm_ang(a: float) -> float:
	a = fmod(a + PI, TAU)
	if a < 0: a += TAU
	return a - PI
func ang_lerp(a: float, b: float, t: float) -> float:
	return a + norm_ang(b - a) * min(1.0, t)
func sm_step(a: float, b: float, x: float) -> float:
	x = clamp((x - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func make_mat(color: Color, rough := 0.8, metal := 0.0, emission := Color.BLACK, em_e := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if em_e > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = em_e
	return m

func textured_mat(tex: Texture2D, fallback_col: Color, rough: float, tile_m: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	if tex != null:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(1.0 / tile_m, 1.0 / tile_m, 1.0 / tile_m)
	else:
		m.albedo_color = fallback_col
		m.roughness = rough
	return m

# ===== КОЛЛИЗИИ =====
func collide_circle(pos: Vector3, r: float) -> Vector3:
	var cmx := 0.0
	var cmz := 0.0
	for b in colliders:
		if pos.x < b.x1 - r or pos.x > b.x2 + r or pos.z < b.z1 - r or pos.z > b.z2 + r:
			continue
		var cx = clamp(pos.x, float(b.x1), float(b.x2))
		var cz = clamp(pos.z, float(b.z1), float(b.z2))
		var dx = pos.x - cx
		var dz = pos.z - cz
		var d2 = dx * dx + dz * dz
		if d2 < r * r:
			if d2 > 0.000001:
				var d = sqrt(d2)
				var k = (r - d) / d
				cmx += dx * k
				cmz += dz * k
			else:
				var l = pos.x - float(b.x1)
				var rr = float(b.x2) - pos.x
				var t = pos.z - float(b.z1)
				var bb = float(b.z2) - pos.z
				var m = min(l, rr, t, bb)
				if m == l: cmx -= l + r
				elif m == rr: cmx += rr + r
				elif m == t: cmz -= t + r
				else: cmz += bb + r
	pos.x += cmx
	pos.z += cmz
	pos.x = clamp(pos.x, -HALF + 1, HALF - 1)
	pos.z = clamp(pos.z, -HALF + 1, HALF - 1)
	return pos

func point_free(x: float, z: float, r: float) -> bool:
	for b in colliders:
		var cx = clamp(x, float(b.x1), float(b.x2))
		var cz = clamp(z, float(b.z1), float(b.z2))
		if (x - cx) * (x - cx) + (z - cz) * (z - cz) < r * r:
			return false
	return abs(x) < HALF - 1 and abs(z) < HALF - 1

# ===== ДОСТУП =====
func get_focus_pos() -> Vector3:
	if in_car != null:
		return Vector3(in_car.x, 0, in_car.z)
	return player_pos

func toast(text: String, bad := false) -> void:
	toast_requested.emit(text, bad)

# ===== РОЗЫСК / УРОН =====
func add_wanted(n: int) -> void:
	var old = wanted
	wanted = min(5, wanted + n)
	heat = max(heat, 9.0 + float(wanted) * 3.0)
	if wanted > old:
		wanted_changed.emit(wanted)

func damage_player(amount: float, _cause := "") -> void:
	if dead or arrested:
		return
	player_hp -= amount
	player_regen_t = 6.0
	player_damaged.emit(amount)
	if player_controller != null:
		player_controller.add_camera_shake(amount * 0.02)
	if player_hp <= 0:
		player_hp = 0
		dead = true
		player_died.emit()

func do_arrest() -> void:
	if arrested or dead:
		return
	arrested = true
	player_arrested.emit()

func respawn() -> void:
	dead = false
	arrested = false
	player_hp = 100
	player_pos = Vector3(9, 0, 9)
	player_py = 0.0
	player_vy = 0.0
	player_heading = 0.0
	wanted = 0
	heat = 0.0
	if in_car != null:
		in_car.mode = "parked"
		in_car.vel = Vector3.ZERO
		in_car = null
	respawned.emit()
