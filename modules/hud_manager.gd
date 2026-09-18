extends Node
## HUD, миникарта, экраны смерти/ареста, интро, тосты.
## Дизайн: минимализм без панелей — только текст поверх игры.
## Миникарта — единственная панель с glassmorphism.

var ui: CanvasLayer = null
var intro: Control = null
var hud: Control = null
var dmg_flash: ColorRect = null
var post_mat: ShaderMaterial = null
var clock_l: Label = null
var debug_l: Label = null
var stars_l: Label = null
var score_l: Label = null
var mission_box: VBoxContainer = null
var mtext_l: Label = null
var mprog_l: Label = null
var mprog_bar: ProgressBar = null
var weap_l: Label = null
var minimap_tr: TextureRect = null
var minimap_panel: PanelContainer = null
var hp_bar: ProgressBar = null
var hp_val_l: Label = null
var veh_bar: ProgressBar = null
var veh_val_l: Label = null
var hp_box: VBoxContainer = null
var speedo: HBoxContainer = null
var spv_l: Label = null
var toast_l: Label = null
var bigmsg_wasted: Control = null
var bigmsg_busted: Control = null
var cut_name_l: Label = null
var cut_text_l: Label = null
var stars_box: VBoxContainer = null
var crosshair: Control = null

# --- Палитра ---
const BG_GLASS_DARK := Color(0.04, 0.05, 0.07, 0.46)
const BORDER_ACCENT := Color(1, 1, 1, 0.12)
const TEXT := Color(0.95, 0.95, 0.93, 0.92)
const TEXT_DIM := Color(0.68, 0.69, 0.72, 0.65)
const ACCENT := Color(0.98, 0.78, 0.36, 0.95)
const DANGER := Color(0.95, 0.35, 0.42, 0.95)
const SUCCESS := Color(0.42, 0.85, 0.60, 0.95)

# --- Сетка ---
const MARGIN := 20
const GAP := 10
const RADIUS_LG := 16
const RADIUS_MD := 12

func _ready() -> void:
	build_ui()
	Game.toast_requested.connect(_on_toast)
	Game.player_damaged.connect(_on_player_damaged)
	Game.player_died.connect(_on_player_died)
	Game.player_arrested.connect(_on_player_arrested)
	Game.respawned.connect(_on_respawned)

func _on_toast(text: String, bad: bool) -> void:
	toast_l.text = text
	toast_l.add_theme_color_override("font_color", DANGER if bad else TEXT)
	var tw = create_tween().set_parallel(true)
	toast_l.visible = true
	toast_l.modulate.a = 0.0
	toast_l.position.y = 110.0
	tw.tween_property(toast_l, "modulate:a", 1.0, 0.22)
	tw.tween_property(toast_l, "position:y", 120.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(toast_l, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func(): toast_l.visible = false)

func _on_player_damaged(_amount: float) -> void:
	dmg_flash.color.a = 0.5
	var tw = create_tween()
	tw.tween_property(dmg_flash, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD)

func _on_player_died() -> void:
	bigmsg_wasted.visible = true
	bigmsg_wasted.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(bigmsg_wasted, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.2)
	tw.tween_callback(func(): Game.respawn())

func _on_player_arrested() -> void:
	bigmsg_busted.visible = true
	bigmsg_busted.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(bigmsg_busted, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.0)
	tw.tween_callback(func(): Game.respawn())

func _on_respawned() -> void:
	bigmsg_wasted.visible = false
	bigmsg_busted.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			Game.headlights_forced = not Game.headlights_forced
			Game.toast("Фары: " + ("ВКЛ" if Game.headlights_forced else "АВТО"))
		if event.keycode == KEY_B:
			Game.blur_on = false
			Game.toast("Моушен-блюр: ВЫКЛ")
		if event.keycode == KEY_M:
			Game.muted = not Game.muted

# --- Стили ---
func glass_style(radius: int = RADIUS_MD, bg: Color = BG_GLASS_DARK, border: Color = BORDER_ACCENT, pad: int = 10) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad - 2
	sb.content_margin_bottom = pad - 2
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_offset = Vector2(0, 3)
	return sb

func glass_panel(radius: int = RADIUS_MD, bg: Color = BG_GLASS_DARK, border: Color = BORDER_ACCENT, pad: int = 10) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass_style(radius, bg, border, pad))
	return p

func style_bar(bar: ProgressBar, fill_col: Color, height: int = 4) -> void:
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(1, 1, 1, 0.10)
	bg_sb.corner_radius_top_left = height
	bg_sb.corner_radius_top_right = height
	bg_sb.corner_radius_bottom_left = height
	bg_sb.corner_radius_bottom_right = height
	bar.add_theme_stylebox_override("background", bg_sb)
	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = fill_col
	fill_sb.corner_radius_top_left = height
	fill_sb.corner_radius_top_right = height
	fill_sb.corner_radius_bottom_left = height
	fill_sb.corner_radius_bottom_right = height
	bar.add_theme_stylebox_override("fill", fill_sb)

func mono_font() -> Font:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["JetBrains Mono", "Cascadia Mono", "Consolas", "monospace"])
	return f

# Хелпер: текст с тенью для читаемости поверх игры
func shadowed(l: Label) -> void:
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))

# --- Сборка ---
func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# Пост-обработка
	var post_rect = ColorRect.new()
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = post_shader_code()
	post_mat.shader = sh
	for k in ["motion_blur", "chromatic", "bloom", "grade", "vignette", "grain"]:
		post_mat.set_shader_parameter(k, 0.0)
	post_rect.material = post_mat
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(post_rect)

	dmg_flash = ColorRect.new()
	dmg_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dmg_flash.color = Color(0.65, 0.05, 0.10, 0)
	dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dmg_flash)

	_build_cutscene()
	_build_hud()
	_build_big_messages()
	_build_intro()

# ---------- Катсцена ----------
func _build_cutscene() -> void:
	cut_name_l = Label.new()
	cut_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_name_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cut_name_l.anchor_left = 0.0
	cut_name_l.anchor_right = 1.0
	cut_name_l.offset_top = 90
	cut_name_l.offset_bottom = 130
	cut_name_l.add_theme_font_size_override("font_size", 22)
	cut_name_l.add_theme_color_override("font_color", TEXT)
	shadowed(cut_name_l)
	cut_name_l.visible = false
	ui.add_child(cut_name_l)

	cut_text_l = Label.new()
	cut_text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_text_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cut_text_l.anchor_left = 0.0
	cut_text_l.anchor_right = 1.0
	cut_text_l.offset_top = -140
	cut_text_l.offset_bottom = -100
	cut_text_l.add_theme_font_size_override("font_size", 15)
	cut_text_l.add_theme_color_override("font_color", TEXT_DIM)
	shadowed(cut_text_l)
	cut_text_l.visible = false
	ui.add_child(cut_text_l)

# ---------- HUD ----------
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_bottom_right()
	_build_bottom_left()
	_build_crosshair()

# --- Левый верх: часы + отладка (без панели) ---
func _build_top_left() -> void:
	var vb = VBoxContainer.new()
	vb.position = Vector2(MARGIN, MARGIN)
	vb.add_theme_constant_override("separation", 3)
	hud.add_child(vb)

	clock_l = Label.new()
	clock_l.text = "17:24"
	clock_l.add_theme_font_override("font", mono_font())
	clock_l.add_theme_font_size_override("font_size", 22)
	clock_l.add_theme_color_override("font_color", TEXT)
	shadowed(clock_l)
	vb.add_child(clock_l)

	debug_l = Label.new()
	debug_l.text = "60 FPS"
	debug_l.add_theme_font_override("font", mono_font())
	debug_l.add_theme_font_size_override("font_size", 11)
	debug_l.add_theme_color_override("font_color", TEXT_DIM)
	shadowed(debug_l)
	vb.add_child(debug_l)

# --- Центр верх: миссия + тост (без панелей) ---
func _build_top_center() -> void:
	mission_box = VBoxContainer.new()
	mission_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mission_box.anchor_left = 0.5
	mission_box.anchor_right = 0.5
	mission_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mission_box.offset_top = MARGIN
	mission_box.add_theme_constant_override("separation", 6)
	mission_box.visible = false
	hud.add_child(mission_box)

	mtext_l = Label.new()
	mtext_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtext_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mtext_l.add_theme_font_override("font", mono_font())
	mtext_l.add_theme_font_size_override("font_size", 12)
	mtext_l.add_theme_color_override("font_color", ACCENT)
	shadowed(mtext_l)
	mission_box.add_child(mtext_l)

	mprog_l = Label.new()
	mprog_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mprog_l.add_theme_font_override("font", mono_font())
	mprog_l.add_theme_font_size_override("font_size", 18)
	mprog_l.add_theme_color_override("font_color", TEXT)
	shadowed(mprog_l)
	mission_box.add_child(mprog_l)

	mprog_bar = ProgressBar.new()
	mprog_bar.custom_minimum_size = Vector2(240, 3)
	mprog_bar.max_value = 100
	mprog_bar.show_percentage = false
	mprog_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_bar(mprog_bar, ACCENT, 3)
	mission_box.add_child(mprog_bar)

	# Тост — просто Label с тенью, без панели
	toast_l = Label.new()
	toast_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_l.anchor_left = 0.5
	toast_l.anchor_right = 0.5
	toast_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_l.offset_top = 120
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_l.add_theme_font_size_override("font_size", 15)
	toast_l.add_theme_color_override("font_color", TEXT)
	toast_l.add_theme_constant_override("outline_size", 5)
	toast_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_l.visible = false
	hud.add_child(toast_l)

# --- Правый верх: розыск + очки (без панели) ---
func _build_top_right() -> void:
	stars_box = VBoxContainer.new()
	stars_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stars_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stars_box.position = Vector2(-MARGIN, MARGIN)
	stars_box.add_theme_constant_override("separation", 2)
	hud.add_child(stars_box)

	stars_l = Label.new()
	stars_l.text = "☆☆☆☆☆"
	stars_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars_l.add_theme_font_size_override("font_size", 20)
	stars_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.16))
	shadowed(stars_l)
	stars_box.add_child(stars_l)

	score_l = Label.new()
	score_l.text = "$ 0"
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_l.add_theme_font_override("font", mono_font())
	score_l.add_theme_font_size_override("font_size", 14)
	score_l.add_theme_color_override("font_color", TEXT_DIM)
	shadowed(score_l)
	stars_box.add_child(score_l)

# --- Правый низ: оружие + миникарта + HP (без панелей кроме миникарты) ---
func _build_bottom_right() -> void:
	var stack = VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stack.position = Vector2(-MARGIN, -MARGIN)
	stack.add_theme_constant_override("separation", GAP)
	hud.add_child(stack)

	# 1. Оружие
	weap_l = Label.new()
	weap_l.text = "КУЛАКИ"
	weap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weap_l.size_flags_horizontal = Control.SIZE_SHRINK_END
	weap_l.add_theme_font_override("font", mono_font())
	weap_l.add_theme_font_size_override("font_size", 12)
	weap_l.add_theme_color_override("font_color", TEXT_DIM)
	shadowed(weap_l)
	stack.add_child(weap_l)

	# 2. Миникарта — ЕДИНСТВЕННАЯ панель
	minimap_panel = glass_panel(RADIUS_LG, BG_GLASS_DARK, BORDER_ACCENT, 6)
	minimap_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	stack.add_child(minimap_panel)

	minimap_tr = TextureRect.new()
	minimap_tr.custom_minimum_size = Vector2(208, 162)
	minimap_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_tr.modulate.a = 0.92
	minimap_panel.add_child(minimap_tr)

	# 3. HP / Vehicle — без панели
	hp_box = VBoxContainer.new()
	hp_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	hp_box.custom_minimum_size = Vector2(208, 0)
	hp_box.add_theme_constant_override("separation", 6)
	stack.add_child(hp_box)

	# HP row
	var hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_box.add_child(hp_row)
	var hp_tag = Label.new()
	hp_tag.text = "HP"
	hp_tag.add_theme_font_override("font", mono_font())
	hp_tag.add_theme_font_size_override("font_size", 11)
	hp_tag.add_theme_color_override("font_color", DANGER)
	hp_tag.custom_minimum_size = Vector2(22, 0)
	hp_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shadowed(hp_tag)
	hp_row.add_child(hp_tag)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(140, 5)
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_bar(hp_bar, DANGER, 3)
	hp_row.add_child(hp_bar)
	hp_val_l = Label.new()
	hp_val_l.text = "100"
	hp_val_l.add_theme_font_override("font", mono_font())
	hp_val_l.add_theme_font_size_override("font_size", 12)
	hp_val_l.add_theme_color_override("font_color", TEXT)
	hp_val_l.custom_minimum_size = Vector2(32, 0)
	hp_val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shadowed(hp_val_l)
	hp_row.add_child(hp_val_l)

	# Vehicle row
	var vh_row = HBoxContainer.new()
	vh_row.add_theme_constant_override("separation", 8)
	hp_box.add_child(vh_row)
	var vh_tag = Label.new()
	vh_tag.text = "V"
	vh_tag.add_theme_font_override("font", mono_font())
	vh_tag.add_theme_font_size_override("font_size", 11)
	vh_tag.add_theme_color_override("font_color", ACCENT)
	vh_tag.custom_minimum_size = Vector2(22, 0)
	vh_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shadowed(vh_tag)
	vh_row.add_child(vh_tag)
	veh_bar = ProgressBar.new()
	veh_bar.custom_minimum_size = Vector2(140, 5)
	veh_bar.max_value = 100
	veh_bar.value = 100
	veh_bar.show_percentage = false
	veh_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	veh_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_bar(veh_bar, ACCENT, 3)
	vh_row.add_child(veh_bar)
	veh_val_l = Label.new()
	veh_val_l.text = "100"
	veh_val_l.add_theme_font_override("font", mono_font())
	veh_val_l.add_theme_font_size_override("font_size", 12)
	veh_val_l.add_theme_color_override("font_color", TEXT)
	veh_val_l.custom_minimum_size = Vector2(32, 0)
	veh_val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shadowed(veh_val_l)
	vh_row.add_child(veh_val_l)

# --- Левый низ: спидометр (без панели) ---
func _build_bottom_left() -> void:
	speedo = HBoxContainer.new()
	speedo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	speedo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speedo.position = Vector2(MARGIN, -MARGIN)
	speedo.add_theme_constant_override("separation", 8)
	speedo.visible = false
	hud.add_child(speedo)

	spv_l = Label.new()
	spv_l.text = "0"
	spv_l.add_theme_font_override("font", mono_font())
	spv_l.add_theme_font_size_override("font_size", 48)
	spv_l.add_theme_color_override("font_color", TEXT)
	shadowed(spv_l)
	speedo.add_child(spv_l)

	var unit_l = Label.new()
	unit_l.text = "км/ч"
	unit_l.add_theme_font_size_override("font_size", 13)
	unit_l.add_theme_color_override("font_color", TEXT_DIM)
	unit_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	shadowed(unit_l)
	speedo.add_child(unit_l)

# --- Прицел ---
func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)

	var dot = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.size = Vector2(3, 3)
	dot.position = Vector2(-1.5, -1.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(dot)

# ---------- Экраны смерти/ареста ----------
func _build_big_messages() -> void:
	bigmsg_wasted = _make_big_msg("ПОТРАЧЕНО", Color(0.35, 0.02, 0.05, 0.4))
	bigmsg_busted = _make_big_msg("ЗАДЕРЖАН", Color(0.02, 0.06, 0.20, 0.4))

func _make_big_msg(text: String, bg: Color) -> Control:
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = bg
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_rect)

	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = -40
	l.offset_bottom = 40
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	root.add_child(l)

	return root

# ---------- Интро ----------
func _build_intro() -> void:
	intro = Control.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(intro)

	var intro_bg = ColorRect.new()
	intro_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_bg.color = Color("#0b0d10")
	intro.add_child(intro_bg)

	var glow = ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0.98, 0.78, 0.36, 0.03)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(glow)

	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	intro.add_child(center)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 48)
	center.add_child(spacer)

	var start = Button.new()
	start.text = "НАЧАТЬ"
	start.custom_minimum_size = Vector2(280, 56)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 15)
	var btn = StyleBoxFlat.new()
	btn.bg_color = Color(1, 1, 1, 0.06)
	btn.border_width_left = 1
	btn.border_width_right = 1
	btn.border_width_top = 1
	btn.border_width_bottom = 1
	btn.border_color = BORDER_ACCENT
	btn.corner_radius_top_left = RADIUS_MD
	btn.corner_radius_top_right = RADIUS_MD
	btn.corner_radius_bottom_left = RADIUS_MD
	btn.corner_radius_bottom_right = RADIUS_MD
	var btn_h = btn.duplicate()
	btn_h.bg_color = Color(1, 1, 1, 0.12)
	btn_h.border_color = Color(0.98, 0.78, 0.36, 0.5)
	var btn_p = btn.duplicate()
	btn_p.bg_color = Color(1, 1, 1, 0.18)
	start.add_theme_stylebox_override("normal", btn)
	start.add_theme_stylebox_override("hover", btn_h)
	start.add_theme_stylebox_override("pressed", btn_p)
	start.add_theme_color_override("font_color", TEXT)
	start.add_theme_color_override("font_hover_color", ACCENT)
	center.add_child(start)
	start.pressed.connect(start_game)

func start_game() -> void:
	if Game.playing:
		return
	Game.playing = true
	intro.visible = false
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.missions.mission_cd = 1.5

func post_shader_code() -> String:
	return """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float motion_blur : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic : hint_range(0.0, 1.0) = 0.0;
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
uniform float grade : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_texture, uv).rgb;
	if (motion_blur > 0.01) {
		float off = 0.0012 * motion_blur;
		vec3 b = texture(screen_texture, uv + vec2(off, 0.0)).rgb;
		b += texture(screen_texture, uv + vec2(-off, 0.0)).rgb;
		b += texture(screen_texture, uv + vec2(0.0, off)).rgb;
		b += texture(screen_texture, uv + vec2(0.0, -off)).rgb;
		c = mix(c, b * 0.25, 0.22);
	}
	if (chromatic > 0.01) {
		vec2 ca = (uv - 0.5) * 0.0028 * dot(uv - 0.5, uv - 0.5) * 4.0 * chromatic;
		c.r = texture(screen_texture, uv + ca).r;
		c.b = texture(screen_texture, uv - ca).b;
	}
	if (bloom > 0.01) {
		vec3 bl = vec3(0.0);
		float bs = 0.0045;
		bl += max(texture(screen_texture, uv + vec2(bs, 0.0)).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(-bs, 0.0)).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(0.0, bs)).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(0.0, -bs)).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(bs, bs) * 0.7).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(-bs, bs) * 0.7).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(bs, -bs) * 0.7).rgb - 0.72, vec3(0.0));
		bl += max(texture(screen_texture, uv + vec2(-bs, -bs) * 0.7).rgb - 0.72, vec3(0.0));
		c += bl * 0.30 * bloom;
	}
	if (grade > 0.01) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(l), c, 0.82);
		c *= vec3(0.88, 0.94, 1.10);
		c = (c - 0.5) * 1.05 + 0.5;
		c = mix(texture(screen_texture, uv).rgb, c, grade);
	}
	if (vignette > 0.01) {
		vec2 q = uv * 2.0 - 1.0;
		c *= 1.0 - dot(q, q) * 0.16 * vignette;
	}
	if (grain > 0.01) {
		float n = fract(sin(dot(uv + fract(time * 0.0173), vec2(12.9898, 78.233))) * 43758.5453);
		c += (n - 0.5) * 0.035 * grain;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

# ---------- Логика обновления ----------
func _process(dt: float) -> void:
	if post_mat != null:
		for k in ["motion_blur", "chromatic", "bloom", "grade", "vignette", "grain"]:
			post_mat.set_shader_parameter(k, 0.0)
	if not Game.playing:
		return

	_update_clock()
	_update_debug()
	_update_wanted_and_score()
	_update_vitals()
	_update_mission()
	_update_cutscene()
	update_minimap()

func _update_clock() -> void:
	var h = int(Game.sim_time) % 24
	var m = int((Game.sim_time - int(Game.sim_time)) * 60)
	clock_l.text = "%02d:%02d" % [h, m]

func _update_debug() -> void:
	var fps = Engine.get_frames_per_second()
	var proc_objs = Performance.get_monitor(Performance.OBJECT_COUNT)
	var proc_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vram = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var pos = Game.get_focus_pos()
	debug_l.text = "%d FPS · %.0f MB · %d dc · %d/%d\nX %.0f  Z %.0f" % [
		fps, vram, int(draw_calls), int(proc_objs), int(proc_nodes), pos.x, pos.z
	]

func _update_wanted_and_score() -> void:
	var sh = ""
	for i in range(5):
		sh += "★" if i < Game.wanted else "☆"
	stars_l.text = sh
	if Game.wanted > 0:
		stars_l.add_theme_color_override("font_color", ACCENT)
		var pulse = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
		stars_box.modulate.a = pulse if Game.wanted >= 3 else 1.0
	else:
		stars_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		stars_box.modulate.a = 1.0
	score_l.text = "$ " + str(Game.score)

func _update_vitals() -> void:
	hp_bar.value = Game.player_hp
	hp_val_l.text = str(int(Game.player_hp))
	if Game.player_hp < 25.0:
		var a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		hp_box.modulate.a = 0.7 + 0.3 * a
	else:
		hp_box.modulate.a = 1.0

	if Game.in_car != null:
		veh_bar.visible = true
		veh_val_l.visible = true
		veh_bar.value = Game.in_car.hp / Game.in_car.max_hp * 100
		veh_val_l.text = str(int(veh_bar.value))
		speedo.visible = true
		var kmh = int(sqrt(Game.in_car.vel.x * Game.in_car.vel.x + Game.in_car.vel.z * Game.in_car.vel.z) * 3.6)
		spv_l.text = str(kmh)
		if kmh > 140:
			spv_l.add_theme_color_override("font_color", DANGER)
		elif kmh > 90:
			spv_l.add_theme_color_override("font_color", ACCENT)
		else:
			spv_l.add_theme_color_override("font_color", TEXT)
	else:
		veh_bar.visible = false
		veh_val_l.visible = false
		speedo.visible = false

func _update_mission() -> void:
	var miss = Game.missions.mission
	if miss.is_empty():
		mission_box.visible = false
		return
	mission_box.visible = true
	mtext_l.text = miss.text
	mprog_bar.value = 0
	if miss.type == "rampage" or miss.type == "destroy" or miss.type == "collect":
		mprog_l.text = str(miss.got) + " / " + str(miss.need)
		if miss.need > 0:
			mprog_bar.value = float(miss.got) / float(miss.need) * 100.0
	elif miss.type == "race":
		var pp = Game.get_focus_pos()
		var d = Vector3(Game.marker.global_position.x, 0, Game.marker.global_position.z).distance_to(pp)
		mprog_l.text = str(int(d)) + " м  ·  " + str(max(0, int(miss.t))) + " с"
	elif miss.type == "delivery":
		var pp = Game.get_focus_pos()
		var d = Vector3(Game.marker.global_position.x, 0, Game.marker.global_position.z).distance_to(pp)
		mprog_l.text = str(int(d)) + " м"
	elif miss.type == "getaway":
		if miss.phase == 1:
			mprog_l.text = "РОЗЫСК: " + str(Game.wanted) + " / 3 ★"
			mprog_bar.value = float(Game.wanted) / 3.0 * 100.0
		else:
			mprog_l.text = "СКРОЙСЯ: " + str(Game.wanted) + " ★"

func _update_cutscene() -> void:
	var cut = Game.missions.cutscene
	if not cut.is_empty():
		cut_name_l.text = cut.def.name
		cut_name_l.visible = true
		var lines = cut.lines
		var idx = min(lines.size() - 1, int(cut.t / 2.8))
		cut_text_l.text = lines[idx]
		cut_text_l.visible = true
	else:
		cut_name_l.visible = false
		cut_text_l.visible = false

# ---------- Миникарта ----------
var _minimap_img: Image = null
var _minimap_tex: ImageTexture = null
var _minimap_accum := 0.0

func update_minimap() -> void:
	_minimap_accum += get_process_delta_time()
	if _minimap_accum < 0.05:
		return
	_minimap_accum = 0.0

	if _minimap_img == null:
		_minimap_img = Image.create(208, 162, false, Image.FORMAT_RGBA8)
		_minimap_tex = ImageTexture.create_from_image(_minimap_img)
		minimap_tr.texture = _minimap_tex

	_minimap_img.fill(Color(0.09, 0.10, 0.12, 0.85))
	var pp = Game.get_focus_pos()

	for b in Game.block_info:
		var color = Color(0.20, 0.28, 0.18, 0.85) if b.park else Color(0.20, 0.22, 0.26, 0.85)
		var x1 = int((float(b.cx) - 17 - pp.x) * 1.15 + 104)
		var y1 = int((float(b.cz) - 17 - pp.z) * 1.15 + 81)
		var w = int(34 * 1.15)
		if x1 + w < 0 or x1 > 208 or y1 + w < 0 or y1 > 162:
			continue
		_minimap_img.fill_rect(Rect2i(x1, y1, w, w), color)
		_minimap_img.fill_rect(Rect2i(x1, y1, w, 1), Color(1, 1, 1, 0.08))
		_minimap_img.fill_rect(Rect2i(x1, y1 + w - 1, w, 1), Color(1, 1, 1, 0.08))
		_minimap_img.fill_rect(Rect2i(x1, y1, 1, w), Color(1, 1, 1, 0.08))
		_minimap_img.fill_rect(Rect2i(x1 + w - 1, y1, 1, w), Color(1, 1, 1, 0.08))

	if Game.marker != null and Game.marker.visible:
		var mmx = int((Game.marker.global_position.x - pp.x) * 1.15 + 104)
		var mmy = int((Game.marker.global_position.z - pp.z) * 1.15 + 81)
		var ring = int(6 + 3 * sin(Time.get_ticks_msec() * 0.005))
		_minimap_img.fill_rect(Rect2i(mmx - ring, mmy - ring, ring * 2, ring * 2), Color(0.98, 0.78, 0.36, 0.25))
		_minimap_img.fill_rect(Rect2i(mmx - 4, mmy - 4, 8, 8), ACCENT)
		_minimap_img.fill_rect(Rect2i(mmx - 2, mmy - 2, 4, 4), Color(1, 1, 0.9, 1))

	_minimap_img.fill_rect(Rect2i(101, 78, 6, 6), Color(1, 1, 1, 0.9))
	_minimap_img.fill_rect(Rect2i(102, 79, 4, 4), Color(0.98, 0.78, 0.36, 1))

	_minimap_tex.update(_minimap_img)
