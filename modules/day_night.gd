extends Node
## Кинематографичное окружение: SSAO + SSR, TAA, глубинный туман, цикл дня/ночи.
## Фары: передние — ночью / по H. Задние — только у машины игрока при торможении.

var env: Environment = null
var sky_mat: ProceduralSkyMaterial = null
var sun: DirectionalLight3D = null
var moon: DirectionalLight3D = null
var sun_spr: MeshInstance3D = null
var cam_attrs = null
var _lamp_check_accum := 0.0

func _ready() -> void:
	var vp = get_viewport()
	vp.use_taa = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = false

	env = Environment.new()
	env.background_mode = Environment.BG_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 3.0
	env.ssao_intensity = 4.0
	env.ssao_power = 3.0
	env.ssao_detail = 1.0
	env.ssao_horizon = 0.12
	env.ssao_sharpness = 0.99
	env.ssao_light_affect = 0.0

	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.0
	env.ssr_fade_out = 8.0
	env.ssr_depth_tolerance = 0.5

	env.sdfgi_enabled = false

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#c9a888")
	env.fog_light_energy = 0.6
	env.fog_density = 1.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = false
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 220.0
	env.fog_depth_curve = 2.0

	env.volumetric_fog_enabled = false
	env.glow_enabled = false

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color("#ffd9b0")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sky = Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f6fb5")
	sky_mat.sky_horizon_color = Color("#e8d4b8")
	sky_mat.sky_curve = 0.12
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color = Color("#0a1020")
	sky_mat.ground_horizon_color = Color("#2a3a55")
	sky_mat.ground_curve = 0.05
	sky_mat.ground_energy_multiplier = 0.8
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky

	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff4dc")
	sun.light_energy = 2.6
	sun.light_specular = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.rotation_degrees = Vector3(-45, -20, 0)
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.light_color = Color("#9db4ff")
	moon.light_energy = 0.0
	moon.light_specular = 0.4
	moon.shadow_enabled = true
	moon.shadow_blur = 3.0
	moon.rotation_degrees = Vector3(-35, 160, 0)
	add_child(moon)

	sun_spr = MeshInstance3D.new()
	var spm = SphereMesh.new()
	spm.radius = 30.0
	spm.height = 60.0
	sun_spr.mesh = spm
	var sgm = Game.make_mat(Color("#fff0c0"), 0.1, 0.0, Color("#fff0c0"), 8.0)
	sgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_spr.material_override = sgm
	sun_spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sun_spr)

	cam_attrs = CameraAttributesPractical.new()
	cam_attrs.auto_exposure_enabled = false
	cam_attrs.dof_blur_far_enabled = false
	cam_attrs.dof_blur_near_enabled = false

func _process(dt: float) -> void:
	if Game.camera != null and Game.camera.attributes == null:
		Game.camera.attributes = cam_attrs
	if Game.playing:
		Game.sim_time = fmod(Game.sim_time + dt * 0.01, 24.0)
	update_sky()
	update_street_lights()
	update_car_lights()

func update_sky() -> void:
	var ang = (Game.sim_time - 6.0) / 12.0 * PI
	var elev = sin(ang)
	var day_f = Game.sm_step(-0.07, 0.22, elev)
	Game.night_f = 1.0 - day_f
	var golden_f = exp(-abs(elev - 0.12) * 6.0)
	var dusk_f = exp(-abs(elev) * 3.5) * (1.0 if elev > -0.35 else 0.0)

	var top = Color("#081020").lerp(Color("#3f6fb5"), day_f)
	top = top.lerp(Color("#2a3a78"), dusk_f * 0.5)
	var hor = Color("#1b2740").lerp(Color("#e8d4b8"), day_f)
	hor = hor.lerp(Color("#ff8a3c"), dusk_f * 0.85)
	hor = hor.lerp(Color("#ffc070"), golden_f * 0.5)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor * 0.75
	sky_mat.ground_bottom_color = Color("#0a1020").lerp(Color("#2e3a48"), day_f)

	env.ambient_light_color = hor.lerp(Color("#ffe0b8"), 0.35)
	env.ambient_light_energy = 0.35 + day_f * 0.25

	env.ssao_intensity = 4.0
	env.ssao_radius = 3.0
	env.ssao_power = 3.0
	env.ssao_detail = 1.0
	env.ssao_horizon = 0.12
	env.ssao_sharpness = 0.99

	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.0
	env.ssr_fade_out = 8.0
	env.ssr_depth_tolerance = 0.5

	env.fog_light_color = hor.lerp(Color("#c9a888"), 0.3)
	env.fog_light_energy = 0.55 + day_f * 0.25
	env.fog_depth_begin = 50.0 + day_f * 60.0
	env.fog_depth_end = 180.0 + day_f * 140.0
	env.fog_depth_curve = 1.8 + dusk_f * 0.8

	sun.light_energy = day_f * 2.6 + golden_f * 0.9 + dusk_f * 0.5
	sun.light_color = Color("#fff4dc").lerp(Color("#ff8a4a"), clamp(dusk_f + golden_f, 0.0, 1.0))
	var sun_pitch = lerp(-12.0, -85.0, clamp(elev, 0.0, 1.0))
	var day_prog = clamp((Game.sim_time - 6.0) / 12.0, 0.0, 1.0)
	var sun_yaw = lerp(-110.0, 110.0, day_prog)
	sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0.0)

	moon.light_energy = Game.night_f * 0.30
	moon.rotation_degrees = Vector3(-35.0, sun_yaw + 180.0, 0.0)

	if Game.camera != null:
		var light_dir = -sun.global_transform.basis.z
		sun_spr.global_position = Game.camera.global_position - light_dir * 1400
	sun_spr.visible = elev > -0.05
	if sun_spr.material_override != null:
		var a = clamp(elev * 2.2 + 0.3, 0.0, 1.0) if elev > -0.05 else 0.0
		var disc_col = Color(1.0, 0.94, 0.75).lerp(Color(1.0, 0.62, 0.35), dusk_f + golden_f * 0.5)
		sun_spr.material_override.albedo_color = Color(disc_col.r, disc_col.g, disc_col.b, a)
		sun_spr.material_override.emission_energy_multiplier = 4.0 + 5.0 * a

	var em_i = 0.02 + Game.night_f * 0.3 + dusk_f * 0.05
	for m in Game.bld_mats:
		m.emission_energy_multiplier = em_i

func update_street_lights() -> void:
	if Game.camera == null:
		return
	var cp = Game.camera.global_position
	var night = Game.night_f
	for gl in Game.lamp_glows:
		var gm = gl.material_override
		gm.albedo_color = Color(1.0, 0.76, 0.49, night * 0.85)
		gm.emission_energy_multiplier = night * 3.0
		gl.visible = night > 0.15 and gl.global_position.distance_to(cp) < 300
	_lamp_check_accum += get_process_delta_time()
	if _lamp_check_accum < 0.3:
		return
	_lamp_check_accum = 0.0
	var light_on = night > 0.15
	for sl in Game.street_lights:
		if sl.light == null:
			continue
		var want_on = light_on and sl.pos.distance_to(cp) < 200.0
		sl.light.light_energy = night * 6.0 if want_on else 0.0

# --- Фары: передние ночью/H, задние только у игрока при торможении ---
func update_car_lights() -> void:
	if Game.cars.is_empty():
		return
	var night = Game.night_f > 0.35
	var cp = Game.camera.global_position if Game.camera != null else Vector3.ZERO

	var player_brake = false
	if Game.in_car != null:
		player_brake = Input.is_key_pressed(KEY_S)

	for c in Game.cars:
		if not c.has("head_lights"):
			continue
		var hl: Array = c.head_lights
		var tg: Array = c.tail_glows
		var h_mat: StandardMaterial3D = c.head_mat
		var t_mat: StandardMaterial3D = c.tail_mat
		var is_player = (c == Game.in_car)

		# Разбитая машина — всё выключено
		if c.mode == "wreck":
			for s in hl:
				s.light_energy = 0.0
			for s in tg:
				s.light_energy = 0.0
			if h_mat != null:
				h_mat.emission_energy_multiplier = 0.0
			if t_mat != null:
				t_mat.emission_energy_multiplier = 0.0
			continue

		var d2 = (c.x - cp.x) * (c.x - cp.x) + (c.z - cp.z) * (c.z - cp.z)

				# --- Передние фары ---
		var head_on = false
		if is_player:
			head_on = night or Game.headlights_forced
		else:
			head_on = night and d2 < 140.0 * 140.0
		var base = 3.0 if is_player else 2.0
		for s in hl:
			s.light_energy = base if head_on else 0.0
		if h_mat != null:
			h_mat.emission_energy_multiplier = 4.0 if head_on else 0.0

		# --- Задние стопы: только у игрока при нажатой S ---
		var brake_on = is_player and player_brake
		if t_mat != null:
			t_mat.emission_energy_multiplier = 2.5 if brake_on else 0.0
		for s in tg:
			s.light_energy = 1.8 if brake_on else 0.0

		c.light_on = head_on
		c.brake_on = brake_on
