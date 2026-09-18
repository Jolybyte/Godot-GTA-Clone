extends Node
## Розыск, спавн и поведение полиции.

var police_foot: Array = []
var police_cars: Array = []
var spawn_cd := 0.0
var car_spawn_cd := 0.0

func _ready() -> void:
	Game.wanted_changed.connect(_on_wanted_changed)
	Game.respawned.connect(_on_respawned)

func _on_wanted_changed(stars: int) -> void:
	Game.toast("РОЗЫСК: " + "★".repeat(stars), true)

func _on_respawned() -> void:
	clear_police()

func clear_police() -> void:
	for c in police_foot.duplicate():
		Game.peds.erase(c)
		if is_instance_valid(c.rig.grp):
			c.rig.grp.queue_free()
	for c in police_cars.duplicate():
		Game.vehicles.remove_car(c)
	police_foot.clear()
	police_cars.clear()

func _process(dt: float) -> void:
	if not Game.playing:
		return
	update_spawns(dt)
	update_decay(dt)
	update_police_cars(dt)

func update_spawns(dt: float) -> void:
	if Game.dead or Game.arrested:
		return
	spawn_cd -= dt
	car_spawn_cd -= dt
	var need_f = min(Game.wanted + 1, 4) if Game.wanted > 0 else 0
	var have_f = 0
	for c in police_foot:
		if c.state != "dead":
			have_f += 1
	if have_f < need_f and spawn_cd <= 0:
		spawn_cop_foot()
		spawn_cd = 1.4
	var need_c = min(Game.wanted - 1, 3) if Game.wanted >= 2 else 0
	var have_c = 0
	for c in police_cars:
		if c.mode == "police":
			have_c += 1
	if have_c < need_c and car_spawn_cd <= 0:
		spawn_cop_car()
		car_spawn_cd = 7.0

func update_decay(dt: float) -> void:
	if Game.heat > 0:
		Game.heat -= dt
		if Game.heat <= 0 and Game.wanted > 0:
			Game.wanted -= 1
			Game.heat = 9.0
			Game.toast("Розыск снижен")

func spawn_cop_foot() -> void:
	for a in range(10):
		var an = Game.rf(0, TAU)
		var d = Game.rf(26, 42)
		var x = clamp(Game.player_pos.x + sin(an) * d, -Game.HALF + 2, Game.HALF - 2)
		var z = clamp(Game.player_pos.z + cos(an) * d, -Game.HALF + 2, Game.HALF - 2)
		if not Game.point_free(x, z, 0.6):
			continue
		var colors = {"shirt": Color("#2a3650"), "pants": Color("#1c2230"), "skin": Color("#c98d64"), "cap": Color("#1c2230")}
		var rig = Game.peds_m.make_human(colors.shirt, colors.pants, colors.skin, colors.cap, true)
		var cop = Game.peds_m.make_ped_obj(rig, x, z, {}, colors)
		cop.is_cop = true
		cop.hp = 60
		cop.speed = 4.6
		cop.state = "chase"
		cop.shoot_cd = 1
		police_foot.append(cop)
		return

func spawn_cop_car() -> void:
	var pp = Game.get_focus_pos()
	for a in range(20):
		var vert = Game.rf(0, 1) < 0.5
		var idx = Game.ri(0, Game.N)
		var t = Game.rf(-Game.HALF + 8, Game.HALF - 8)
		var side = 2.8 if Game.rf(0, 1) < 0.5 else -2.8
		var x = float(Game.road_centers[idx]) + side if vert else t
		var z = t if vert else float(Game.road_centers[idx]) + side
		var d = Vector3(x, 0, z).distance_to(pp)
		if d < 80 or d > 140:
			continue
		var car = Game.vehicles.add_car("police", x, z, atan2(pp.x - x, pp.z - z), "police")
		car.speed = 0.0
		police_cars.append(car)
		return

func update_police_cars(dt: float) -> void:
	for c in police_cars:
		if c.mode != "police":
			continue
		var pp = Game.get_focus_pos()
		var dx = pp.x - c.x
		var dz = pp.z - c.z
		var d = sqrt(dx * dx + dz * dz)
		var des_h = atan2(dx, dz)
		var delta = Game.norm_ang(des_h - c.heading)
		var spd = sqrt(c.vel.x * c.vel.x + c.vel.z * c.vel.z)
		var thr = 1.0
		var brk = 0.0
		var hb = 0.0
		var steer = clamp(-delta * 2.0, -1.0, 1.0)
		if Game.in_car == null and d < 7:
			thr = 0.0
			brk = 1.0
		if abs(delta) > 2 and spd < 2:
			thr = 0.2
		c.rev_t -= dt
		if thr > 0 and spd < 0.8:
			c.stuck_t += dt
		else:
			c.stuck_t = 0
		if c.stuck_t > 1.1:
			c.rev_t = 0.8
			c.stuck_t = 0
		if c.rev_t > 0:
			thr = -0.7
			brk = 0
			steer = -steer
		var max_s = 13.0 + float(Game.wanted) * 1.5
		var vf = c.vel.x * sin(c.heading) + c.vel.z * cos(c.heading)
		if vf > max_s:
			thr = 0
		Game.vehicles.drive_car(c, thr, brk, hb, steer, dt)
		Game.vehicles.car_world_collide(c)
		Game.vehicles.resolve_car_vs_cars(c)
		c.spin_v = vf
