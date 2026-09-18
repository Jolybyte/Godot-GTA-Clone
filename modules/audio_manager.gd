extends Node
## Аудио: пользовательские файлы из res://assets/audio.
## Шины: Master(компрессор) / SFX / AMBIENT / MUSIC.

var pools := {}
var sfx: Array = []
var sfx3d: Array = []
var amb_a: AudioStreamPlayer = null
var amb_b: AudioStreamPlayer = null
var amb_cur := -1
var amb_key := ""
var engine_p: AudioStreamPlayer = null
var siren_p: AudioStreamPlayer3D = null
var music_p: AudioStreamPlayer = null
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_setup_buses()
	for k in ["shot_pistol","shot_smg","shot_shotgun","shot_rifle","shot_sniper","shot","explosion","siren","engine","reload","melee","horn","step","crash","ui","ambient_day","ambient_night","ambient","music"]:
		pools[k] = []
	_scan_files()
	_build_players()

func _setup_buses() -> void:
	for bname in ["SFX", "AMBIENT", "MUSIC"]:
		if AudioServer.get_bus_index(bname) == -1:
			AudioServer.add_bus()
			var i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bname)
			AudioServer.set_bus_send(i, "Master")
	var mi = AudioServer.get_bus_index("Master")
	if mi != -1 and AudioServer.get_bus_effect_count(mi) == 0:
		var comp = AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 4.0
		AudioServer.add_bus_effect(mi, comp)

func _scan_files() -> void:
	for dirpath in ["res://assets/audio", "res://audio", "res://assets/sounds"]:
		var d = DirAccess.open(dirpath)
		if d == null:
			continue
		d.list_dir_begin()
		var fn = d.get_next()
		while fn != "":
			if not d.current_is_dir():
				var ext = fn.get_extension().to_lower()
				if ext == "ogg" or ext == "wav" or ext == "mp3":
					var res = load(dirpath + "/" + fn)
					if res != null:
						_categorize(fn.get_basename().to_lower(), res)
			fn = d.get_next()
		d.list_dir_end()

func _categorize(low: String, res) -> void:
	if low.begins_with("ambient") or low.begins_with("amb_") or low.begins_with("city") or low.begins_with("wind") or low.begins_with("rain"):
		if low.find("night") != -1:
			pools.ambient_night.append(res)
		elif low.find("day") != -1:
			pools.ambient_day.append(res)
		else:
			pools.ambient.append(res)
	elif low.begins_with("shot") or low.begins_with("gun") or low.begins_with("fire"):
		if low.find("pistol") != -1: pools.shot_pistol.append(res)
		elif low.find("smg") != -1 or low.find("uzi") != -1: pools.shot_smg.append(res)
		elif low.find("shotgun") != -1 or low.find("drob") != -1: pools.shot_shotgun.append(res)
		elif low.find("sniper") != -1: pools.shot_sniper.append(res)
		elif low.find("rifle") != -1 or low.find("ak") != -1 or low.find("avto") != -1: pools.shot_rifle.append(res)
		else: pools.shot.append(res)
	elif low.begins_with("explo") or low.begins_with("boom") or low.begins_with("grenade"): pools.explosion.append(res)
	elif low.begins_with("siren"): pools.siren.append(res)
	elif low.begins_with("engine") or low.begins_with("motor"): pools.engine.append(res)
	elif low.begins_with("reload") or low.begins_with("clip"): pools.reload.append(res)
	elif low.begins_with("melee") or low.begins_with("swing") or low.begins_with("punch") or low.begins_with("hit"): pools.melee.append(res)
	elif low.begins_with("horn"): pools.horn.append(res)
	elif low.begins_with("step") or low.begins_with("foot"): pools.step.append(res)
	elif low.begins_with("crash") or low.begins_with("metal") or low.begins_with("udarn"): pools.crash.append(res)
	elif low.begins_with("ui") or low.begins_with("click") or low.begins_with("beep"): pools.ui.append(res)
	elif low.begins_with("music") or low.begins_with("theme"): pools.music.append(res)

func _set_loop(st: AudioStream, on: bool) -> void:
	if st is AudioStreamOggVorbis:
		st.loop = on
	elif st is AudioStreamMP3:
		st.loop = on
	elif st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED

func _build_players() -> void:
	for i in range(14):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx.append(p)
	for i in range(8):
		var p = AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 10.0
		add_child(p)
		sfx3d.append(p)
	amb_a = AudioStreamPlayer.new()
	amb_a.bus = "AMBIENT"
	add_child(amb_a)
	amb_b = AudioStreamPlayer.new()
	amb_b.bus = "AMBIENT"
	add_child(amb_b)
	
	engine_p = AudioStreamPlayer.new()
	engine_p.bus = "SFX"
	engine_p.stream = _pick("engine")
	if engine_p.stream != null:
		_set_loop(engine_p.stream, true)
	engine_p.volume_db = -80.0
	add_child(engine_p)
	engine_p.play()
	
	siren_p = AudioStreamPlayer3D.new()
	siren_p.bus = "SFX"
	siren_p.unit_size = 10.0
	siren_p.stream = _pick("siren")
	if siren_p.stream != null:
		_set_loop(siren_p.stream, true)
	siren_p.volume_db = -80.0
	add_child(siren_p)
	siren_p.play()
	
	music_p = AudioStreamPlayer.new()
	music_p.bus = "MUSIC"
	add_child(music_p)
	music_p.finished.connect(_next_music)
	if pools.music.size() > 0:
		_next_music()

func _next_music() -> void:
	if pools.music.is_empty():
		return
	music_p.stream = _pick("music")
	music_p.play()

func _pick(key: String):
	var arr = pools.get(key, [])
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]

func _free(pool: Array):
	for p in pool:
		if not p.playing:
			return p
	return null

# ===== ПУБЛИЧНОЕ API =====

func play_one(key: String, vol_db := 0.0) -> void:
	var p = _free(sfx)
	if p != null:
		p.stream = _pick(key)
		if p.stream != null:
			p.volume_db = vol_db
			p.play()

func play_3d(key: String, pos: Vector3, vol_db := 0.0) -> void:
	var p = _free(sfx3d)
	if p != null:
		p.stream = _pick(key)
		if p.stream != null:
			p.global_position = pos
			p.volume_db = vol_db
			p.play()

func play_shot(weapon_index: int) -> void:
	var keys = ["shot", "shot", "shot", "shot_pistol", "shot_smg", "shot_shotgun", "shot_rifle", "shot_sniper", "shot", "shot"]
	var key = keys[clamp(weapon_index, 0, keys.size() - 1)]
	play_one(key)

func play_reload() -> void:
	play_one("reload")

func play_explosion(pos: Vector3) -> void:
	play_3d("explosion", pos)
