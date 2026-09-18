extends Node
## Миссии, катсцены, маяк.

const MISSIONS = [
	{"type":"delivery","name":"ДОСТАВКА","text":"ДОСТАВКА: доберитесь до жёлтого маяка","lines":["Заказ ждёт на другом конце города.","Жёлтый маяк — точка сброса."]},
	{"type":"rampage","name":"ЗАЧИСТКА","need":6,"text":"ЗАЧИСТКА: уничтожьте 6 бандитов","lines":["Банда держит квартал в страхе.","Шестеро должны упасть."]},
	{"type":"race","name":"ГОНКА","time":45,"text":"ГОНКА: успейте к маяку за 45 секунд","lines":["Время — деньги. 45 секунд.","Опоздаешь — сделка сорвётся."]},
	{"type":"collect","name":"СБОР","need":6,"text":"СБОР: подберите 6 пакетов","lines":["Пакеты разбросаны по кварталам.","Шесть штук. Быстро."]},
	{"type":"destroy","name":"ПОДРЫВ","need":4,"text":"ПОДРЫВ: уничтожьте 4 машины","lines":["Четыре тачки — в металлолом.","Способ не важен."]},
	{"type":"getaway","name":"ПОГОНЯ","text":"ПОГОНЯ: наберите 3★ и уйдите","lines":["Подними шум до трёх звёзд.","Затем уйди от погони."]},
]

var mission: Dictionary = {}
var mission_idx := 0
var mission_cd := 2.0
var cutscene: Dictionary = {}
var packs: Array = []
var marker: Node3D = null

func _ready() -> void:
	build_marker()
	Game.respawned.connect(_on_respawned)

func _on_respawned() -> void:
	pass

func build_marker() -> void:
	marker = Node3D.new()
	add_child(marker)
	var bm = Game.make_mat(Color("#c9a24a"), 0.5)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color("#c9a24a", 0.3)
	var beam = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 1.05
	cm.bottom_radius = 1.05
	cm.height = 30
	beam.mesh = cm
	beam.material_override = bm
	beam.position.y = 15
	marker.add_child(beam)
	var ring = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(4, 4)
	ring.mesh = pm
	ring.material_override = bm
	ring.rotation_degrees.x = -90
	ring.position.y = 0.06
	marker.add_child(ring)
	Game.marker = marker
	new_target()

func new_target() -> void:
	var i = Game.ri(0, Game.N)
	var j = Game.ri(0, Game.N)
	var dirs = [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]
	var d = Game.pick_arr(dirs)
	var dist = Game.rf(5, 17)
	marker.position = Vector3(float(Game.road_centers[i]) + d.x * dist, 0, float(Game.road_centers[j]) + d.z * dist)

func _process(dt: float) -> void:
	if not Game.playing:
		return
	marker.rotation.y += dt * 0.6
	update_missions(dt)

func update_missions(dt: float) -> void:
	if mission.is_empty():
		if not cutscene.is_empty():
			update_cutscene(dt)
			return
		mission_cd -= dt
		if mission_cd <= 0:
			var def = MISSIONS[mission_idx % MISSIONS.size()]
			mission_idx += 1
			start_cutscene(def)
			mission_cd = 99
		return
	var pp = Game.get_focus_pos()
	if mission.type == "collect":
		var i = packs.size() - 1
		while i >= 0:
			var p = packs[i]
			p.rotation.y += dt * 2
			if Vector3(p.global_position.x, 0, p.global_position.z).distance_to(pp) < 2.2:
				p.queue_free()
				packs.remove_at(i)
				mission.got = mission.got + 1
				if mission.got >= mission.need:
					complete_mission()
					return
			i -= 1
	elif mission.type == "race":
		mission.t -= dt
		var d = Vector3(marker.global_position.x, 0, marker.global_position.z).distance_to(pp)
		if mission.t <= 0:
			Game.toast("ВРЕМЯ ВЫШЛО — ПРОВАЛ", true)
			mission = {}
			mission_cd = 2.5
			return
		if d < 4.2:
			complete_mission()
			return
	elif mission.type == "delivery":
		var d = Vector3(marker.global_position.x, 0, marker.global_position.z).distance_to(pp)
		if d < 4.2:
			complete_mission()
			return
	elif mission.type == "getaway":
		if mission.phase == 1:
			if Game.wanted >= 3:
				mission.phase = 2
				Game.toast("ОТОРВИСЬ ОТ ПОЛИЦИИ!", true)
		else:
			if Game.wanted == 0:
				complete_mission()
				return

func update_cutscene(dt: float) -> void:
	cutscene.t = cutscene.t + dt
	var lines = cutscene.lines
	var idx = min(lines.size() - 1, int(cutscene.t / 2.8))
	# текст выводит HUDManager через Game
	if cutscene.t > lines.size() * 2.8 + 0.4:
		end_cutscene()

func start_cutscene(def: Dictionary) -> void:
	cutscene = {"def": def, "lines": def.get("lines", ["..."]), "t": 0.0}

func end_cutscene() -> void:
	if cutscene.is_empty():
		return
	var def = cutscene.def
	cutscene = {}
	start_mission(def)

func start_mission(def: Dictionary) -> void:
	mission = {"type": def.type, "text": def.text, "need": def.get("need", 0), "got": 0, "t": def.get("time", 0), "phase": 1, "target": null}
	if def.type == "delivery" or def.type == "race":
		new_target()
		marker.visible = true
	else:
		marker.visible = false
	if def.type == "collect":
		spawn_packs()
	Game.toast("НОВОЕ ЗАДАНИЕ")

func complete_mission() -> void:
	if mission.is_empty():
		return
	Game.toast("ЗАДАНИЕ ВЫПОЛНЕНО! +5")
	Game.score += 5
	mission = {}
	clear_packs()
	marker.visible = true
	mission_cd = 4

func add_rampage_kill() -> void:
	if mission.get("type") == "rampage":
		mission.got = mission.got + 1
		if mission.got >= mission.need:
			complete_mission()

func add_destroy_kill() -> void:
	if mission.get("type") == "destroy":
		mission.got = mission.got + 1
		if mission.got >= mission.need:
			complete_mission()

func complete_target_kill() -> void:
	complete_mission()

func spawn_packs() -> void:
	clear_packs()
	for i in range(6):
		var b = Game.pick_arr(Game.block_info)
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.45, 0.45, 0.45)
		m.mesh = bm
		m.material_override = Game.make_mat(Color("#8ab87e"), 0.4, 0.0, Color("#6a9a5e"), 2.0)
		m.position = Vector3(float(b.cx) + Game.rf(-14, 14), 0.5, float(b.cz) + Game.rf(-14, 14))
		add_child(m)
		packs.append(m)

func clear_packs() -> void:
	for p in packs:
		if is_instance_valid(p):
			p.queue_free()
	packs.clear()
