extends Node
## Загружает текстуры и модели из res://assets/. Запускается первым.
## Ключ "face_tex" создаётся здесь принудительно, чтобы не было
## Invalid access to property or key 'face_tex' на Dictionary.

func _ready() -> void:
	load_assets()

func list_files(path: String, exts: Array) -> Array:
	var out: Array = []
	var dir = DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != "":
		if not dir.current_is_dir():
			var ext = fn.get_extension().to_lower()
			if exts.has(ext):
				out.append(fn)
		fn = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

func load_assets() -> void:
	# Гарантируем наличие всех ключей в словаре (Dictionary)
	if not Game.assets.has("road_tex"):
		Game.assets["road_tex"] = null
	if not Game.assets.has("sidewalk_tex"):
		Game.assets["sidewalk_tex"] = null
	if not Game.assets.has("grass_tex"):
		Game.assets["grass_tex"] = null
	if not Game.assets.has("facade_textures"):
		Game.assets["facade_textures"] = []
	if not Game.assets.has("models"):
		Game.assets["models"] = {}
	if not Game.assets.has("face_tex"):
		Game.assets["face_tex"] = null

	# --- текстуры из res://assets/textures/ ---
	for f in list_files("res://assets/textures", ["png", "jpg", "jpeg", "webp"]):
		var t = load("res://assets/textures/" + f)
		if t == null:
			continue
		var low = f.to_lower()
		if low.begins_with("road") or low.begins_with("asphalt"):
			Game.assets["road_tex"] = t
		elif low.begins_with("sidewalk") or low.begins_with("concrete") or low.begins_with("pavement"):
			Game.assets["sidewalk_tex"] = t
		elif low.begins_with("grass") or low.begins_with("ground"):
			Game.assets["grass_tex"] = t
		elif low.begins_with("face"):
			Game.assets["face_tex"] = t
		else:
			Game.assets["facade_textures"].append(t)

	# --- лицо игрока прямо из res://assets/ ---
	if Game.assets["face_tex"] == null:
		for f in list_files("res://assets", ["png", "jpg", "jpeg", "webp"]):
			var low = f.to_lower()
			if low.begins_with("face"):
				var t2 = load("res://assets/" + f)
				if t2 != null:
					Game.assets["face_tex"] = t2
					break

	# --- модели ---
	for n in ["tree", "bench", "trash", "dumpster", "hydrant", "barrier", "crate", "lamp"]:
		for ext in ["glb", "gltf"]:
			var path = "res://assets/models/" + n + "." + ext
			if ResourceLoader.exists(path):
				Game.assets["models"][n] = load(path)
				break

	# --- если текстуры лица нет — сгенерируем простую процедурную ---
	if Game.assets["face_tex"] == null:
		make_default_face()

func make_default_face() -> void:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color("#c98d64")
	for y in range(size):
		for x in range(size):
			var dx := (x - size * 0.5) / (size * 0.5)
			var dy := (y - size * 0.5) / (size * 0.5)
			if dx * dx + dy * dy < 0.92:
				img.set_pixel(x, y, skin)
	# глаза (белки)
	_draw_ellipse(img, int(size * 0.35), int(size * 0.38), int(size * 0.07), int(size * 0.045), Color("#f4f1ea"))
	_draw_ellipse(img, int(size * 0.65), int(size * 0.38), int(size * 0.07), int(size * 0.045), Color("#f4f1ea"))
	# зрачки
	_draw_ellipse(img, int(size * 0.35), int(size * 0.38), int(size * 0.03), int(size * 0.03), Color("#2a1e14"))
	_draw_ellipse(img, int(size * 0.65), int(size * 0.38), int(size * 0.03), int(size * 0.03), Color("#2a1e14"))
	# брови
	for x in range(int(size * 0.27), int(size * 0.44)):
		img.set_pixel(x, int(size * 0.30), Color("#3a2a1c"))
		img.set_pixel(x, int(size * 0.31), Color("#3a2a1c"))
	for x in range(int(size * 0.56), int(size * 0.73)):
		img.set_pixel(x, int(size * 0.30), Color("#3a2a1c"))
		img.set_pixel(x, int(size * 0.31), Color("#3a2a1c"))
	# рот
	for x in range(int(size * 0.42), int(size * 0.58)):
		img.set_pixel(x, int(size * 0.72), Color("#6a2a24"))
		img.set_pixel(x, int(size * 0.73), Color("#6a2a24"))
	# нос
	for y in range(int(size * 0.46), int(size * 0.58)):
		img.set_pixel(int(size * 0.5), y, Color("#a06a44"))
	Game.assets["face_tex"] = ImageTexture.create_from_image(img)

func _draw_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := float(x - cx) / float(max(rx, 1))
			var dy := float(y - cy) / float(max(ry, 1))
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)
