extends Node2D
## Tour ASMR - V1
## Tour infinie de squishies. On saute dessus, on ramasse des squishies,
## la tour monte. Plus c'est haut, plus c'est rare. Mode zen : jamais de game over.

const LH := 56.0            # hauteur d'un etage
const TW := 460.0           # largeur de la tour
const PER_TIER := 8         # etages par palier de rarete
const GRAV := 1900.0
const JUMP_V := 840.0
const SPEED := 340.0
const SAVE_PATH := "user://tour_asmr.cfg"

# Index 0 = le plus rare (tout en haut), dernier = le plus commun (en bas)
var TIERS: Array = [
	{"name": "Beurre", "col": Color("#ffe27a"), "snd": [190.0, 0.38, 0.30, 0.5]},
	{"name": "Needoh", "col": Color("#c79bff"), "snd": [330.0, 0.30, 0.20, 0.6]},
	{"name": "Savon", "col": Color("#ffb3d1"), "snd": [420.0, 0.25, 0.35, 0.5]},
	{"name": "Œuf", "col": Color("#fff1dc"), "snd": [260.0, 0.22, 0.60, 0.4]},
	{"name": "Balle anti-stress", "col": Color("#5ec8ff"), "snd": [300.0, 0.30, 0.10, 0.7]},
	{"name": "Dumpling", "col": Color("#f3e3cc"), "snd": [240.0, 0.28, 0.50, 0.5]},
	{"name": "Clavier", "col": Color("#9a9ab8"), "snd": [900.0, 0.06, 0.80, 0.1]},
	{"name": "Glaçon", "col": Color("#bfeaff"), "snd": [1400.0, 0.10, 0.90, 0.2]},
	{"name": "Mousse", "col": Color("#fbfbff"), "snd": [500.0, 0.40, 0.95, 0.3]},
	{"name": "Neige", "col": Color("#e3eeff"), "snd": [700.0, 0.35, 0.90, 0.4]},
	{"name": "Crayon", "col": Color("#ffd23f"), "snd": [1100.0, 0.07, 0.60, 0.2]},
]

var vs := Vector2(1280, 720)
var layers := 3
var height_vis := 3.0 * LH
var coins := 0
var discovered: Array = []
var px := 0.0
var py := 0.0
var vy := 0.0
var grounded := true
var state := 0               # 0 = jeu, 1 = "plouf" (chute au sol)
var state_t := 0.0
var squash := 0.0
var top_squash := 0.0
var t_anim := 0.0
var items: Array = []
var popups: Array = []
var banner := ""
var banner_t := 0.0
var lego_images: Array = []

var sfx_jump: AudioStreamWAV
var sfx_fall: AudioStreamWAV
var sfx_pop: AudioStreamWAV
var sfx_tier: Array = []
var players: Array = []
var play_i := 0

var pos_l := Vector2.ZERO
var pos_r := Vector2.ZERO
var pos_j := Vector2.ZERO
const R_ARROW := 80.0
const R_JUMP := 100.0

var stars: PackedVector2Array = PackedVector2Array()
var clouds: PackedVector2Array = PackedVector2Array()
var sb := StyleBoxFlat.new()
var font: Font = ThemeDB.fallback_font


func _ready() -> void:
	for i in TIERS.size():
		discovered.append(false)
	load_game()
	height_vis = layers * LH
	py = -height_vis
	build_sounds()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	make_btn("ui_left", R_ARROW)
	make_btn("ui_right", R_ARROW)
	make_btn("ui_accept", R_JUMP)
	get_viewport().size_changed.connect(layout)
	layout()
	load_lego()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		stars.append(Vector2(rng.randf(), rng.randf()))
	for i in 12:
		clouds.append(Vector2(rng.randf(), rng.randf()))
	spawn_items()


func tier_of(i: int) -> int:
	return maxi(0, TIERS.size() - 1 - floori(float(i) / PER_TIER))


# ---------------------------------------------------------------- boutons tactiles

var _btns: Array = []

func make_btn(action: String, radius: float) -> void:
	var b := TouchScreenButton.new()
	var cs := CircleShape2D.new()
	cs.radius = radius
	b.shape = cs
	b.action = action
	b.shape_visible = false
	add_child(b)
	_btns.append(b)


func layout() -> void:
	vs = get_viewport_rect().size
	pos_l = Vector2(120.0, vs.y - 120.0)
	pos_r = Vector2(300.0, vs.y - 120.0)
	pos_j = Vector2(vs.x - 140.0, vs.y - 140.0)
	if _btns.size() == 3:
		_btns[0].position = pos_l
		_btns[1].position = pos_r
		_btns[2].position = pos_j


# ---------------------------------------------------------------- sons

func make_sound(freq: float, dur: float, noise: float, sweep: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0 + dur * 100.0)
	for i in n:
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 2.2) * minf(1.0, t * 60.0)
		var f := freq * (1.0 - sweep * t)
		phase += TAU * f / float(rate)
		var tone := sin(phase)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		var v := (tone * (1.0 - noise) + lp * 2.0 * noise) * env * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


func build_sounds() -> void:
	# Le "bruit de pain" : un petit "pof" mou et etouffe
	sfx_jump = make_sound(180.0, 0.18, 0.35, 0.5)
	sfx_fall = make_sound(110.0, 0.5, 0.45, 0.6)
	sfx_pop = make_sound(420.0, 0.12, 0.1, -0.5)
	for t in TIERS:
		var p: Array = t["snd"]
		sfx_tier.append(make_sound(p[0], p[1], p[2], p[3]))


func play(s: AudioStream, pitch := 1.0, vol := 0.0) -> void:
	var p: AudioStreamPlayer = players[play_i]
	play_i = (play_i + 1) % players.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = vol
	p.play()


# ---------------------------------------------------------------- sauvegarde / Lego

func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "layers", layers)
	cf.set_value("game", "coins", coins)
	cf.set_value("game", "discovered", discovered)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	layers = maxi(3, int(cf.get_value("game", "layers", 3)))
	coins = int(cf.get_value("game", "coins", 0))
	var d = cf.get_value("game", "discovered", [])
	if d is Array and d.size() == TIERS.size():
		discovered = d


func load_lego() -> void:
	var dir := "res://lego/"
	for f in DirAccess.get_files_at(dir):
		var nm := f.trim_suffix(".import")
		var ext := nm.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp"]:
			var tex = load(dir + nm)
			if tex is Texture2D and not lego_images.has(tex):
				lego_images.append(tex)


# ---------------------------------------------------------------- jeu

func spawn_items() -> void:
	while items.size() < 2:
		items.append({
			"x": randf_range(-TW / 2.0 + 50.0, TW / 2.0 - 50.0),
			"rel": randf_range(60.0, 165.0),
			"ph": randf() * TAU,
		})


func item_pos(it: Dictionary) -> Vector2:
	return Vector2(it["x"], -height_vis - it["rel"] + sin(t_anim * 2.0 + it["ph"]) * 6.0)


func collect(it: Dictionary) -> void:
	var tier := tier_of(layers)
	var first: bool = not discovered[tier]
	discovered[tier] = true
	var val := TIERS.size() - tier
	coins += val
	var at := item_pos(it)
	layers += 1
	popups.append({"p": at, "t": 0.0, "txt": "+%d" % val})
	play(sfx_tier[tier], randf_range(0.92, 1.08))
	if first:
		banner = "Nouveau : %s !" % TIERS[tier]["name"]
		banner_t = 2.4
	items.erase(it)
	spawn_items()
	save_game()


func splat() -> void:
	state = 1
	state_t = 0.9
	squash = 1.0
	play(sfx_fall, 1.0)
	banner = "Plouf ! On remonte…"
	banner_t = 1.4


func respawn() -> void:
	state = 0
	px = 0.0
	py = -height_vis - 320.0
	vy = 0.0
	grounded = false
	play(sfx_pop, 1.3)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	t_anim += delta
	squash = move_toward(squash, 0.0, delta * 3.0)
	top_squash = move_toward(top_squash, 0.0, delta * 2.5)
	height_vis = lerpf(height_vis, layers * LH, 1.0 - exp(-7.0 * delta))
	if banner_t > 0.0:
		banner_t -= delta
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.2)

	var top := -height_vis
	if state == 1:
		state_t -= delta
		if state_t <= 0.0:
			respawn()
	else:
		var dir := Input.get_axis("ui_left", "ui_right")
		px = clampf(px + dir * SPEED * delta, -vs.x / 2.0 + 40.0, vs.x / 2.0 - 40.0)
		var on_tower := absf(px) < TW / 2.0
		var jump_pressed := Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
		if grounded:
			if not on_tower:
				grounded = false
			else:
				py = top
				vy = 0.0
				if jump_pressed:
					vy = -JUMP_V
					grounded = false
					squash = -0.5
					play(sfx_jump, randf_range(0.9, 1.1))
		if not grounded:
			vy += GRAV * delta
			var ny := py + vy * delta
			if on_tower and vy >= 0.0 and py <= top + 70.0 and ny >= top:
				py = top
				vy = 0.0
				grounded = true
				squash = 0.7
				top_squash = 1.0
				play(sfx_jump, 0.7)
			else:
				py = ny
			if py >= 0.0:
				py = 0.0
				splat()
		# ramassage
		var pc := Vector2(px, py - 26.0)
		for it in items.duplicate():
			if pc.distance_to(item_pos(it)) < 54.0:
				collect(it)
	queue_redraw()


# ---------------------------------------------------------------- dessin

func sky(h: float) -> Color:
	var c0 := Color("#ffd6e0")
	var c1 := Color("#c7b8ff")
	var c2 := Color("#1b1a3a")
	if h < 0.5:
		return c0.lerp(c1, h * 2.0)
	return c1.lerp(c2, (h - 0.5) * 2.0)


func _rr(r: Rect2, col: Color, rad: int, border := Color(0, 0, 0, 0.16)) -> void:
	sb.bg_color = col
	sb.set_corner_radius_all(rad)
	sb.border_color = border
	sb.set_border_width_all(2)
	draw_style_box(sb, r)


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func face(c: Vector2, s: float) -> void:
	var dark := Color("#3a2a3a")
	draw_circle(c + Vector2(-11, -4) * s, 3.6 * s, dark)
	draw_circle(c + Vector2(11, -4) * s, 3.6 * s, dark)
	draw_circle(c + Vector2(-12, -5.2) * s, 1.1 * s, Color.WHITE)
	draw_circle(c + Vector2(10, -5.2) * s, 1.1 * s, Color.WHITE)
	draw_arc(c + Vector2(0, 3) * s, 6.0 * s, 0.25, PI - 0.25, 8, dark, 2.0 * s)
	draw_circle(c + Vector2(-19, 4) * s, 4.0 * s, Color(1, 0.5, 0.6, 0.35))
	draw_circle(c + Vector2(19, 4) * s, 4.0 * s, Color(1, 0.5, 0.6, 0.35))


func draw_item(c: Vector2, tier: int, s: float) -> void:
	var col: Color = TIERS[tier]["col"]
	var sz := Vector2(72, 56) * s
	var r := Rect2(c - sz / 2.0, sz)
	var with_face := true
	match tier:
		0: # beurre : pave + papier
			_rr(r, col, 10)
			_rr(Rect2(r.position, Vector2(sz.x, sz.y * 0.3)), Color("#fff4b8"), 10)
		1: # Needoh : boule violette avec pois
			ellipse(c, 34 * s, 28 * s, col)
			for k in 6:
				var a := float(k) * 1.05
				draw_circle(c + Vector2(cos(a) * 26, sin(a) * 18) * s, 3.5 * s, Color("#ff7ac8"))
		2: # savon
			_rr(r, col, 14)
			draw_circle(c + Vector2(24, -16) * s, 5 * s, Color(1, 1, 1, 0.7))
			draw_circle(c + Vector2(30, -8) * s, 3 * s, Color(1, 1, 1, 0.7))
		3: # oeuf
			ellipse(c, 26 * s, 30 * s, col)
			ellipse(c + Vector2(-8, -10) * s, 6 * s, 9 * s, Color(1, 1, 1, 0.5))
		4: # balle anti-stress
			draw_circle(c, 30 * s, col)
			draw_arc(c, 22 * s, 3.6, 5.2, 10, Color(1, 1, 1, 0.6), 4 * s)
		5: # dumpling
			ellipse(c + Vector2(0, 4) * s, 34 * s, 24 * s, col)
			for k in 5:
				draw_line(c + Vector2(-20 + k * 10, -14) * s, c + Vector2(-16 + k * 8, -4) * s, Color("#d9bf9b"), 2 * s)
		6: # clavier
			with_face = false
			_rr(r, Color("#6c6c88"), 8)
			for row in 3:
				for k in 5:
					_rr(Rect2(r.position + Vector2(6 + k * 12.5, 6 + row * 15) * s, Vector2(10, 11) * s), Color("#d8d8ee"), 3, Color(0, 0, 0, 0.1))
		7: # glacon
			_rr(r, Color(col.r, col.g, col.b, 0.85), 8, Color(1, 1, 1, 0.8))
			draw_line(c + Vector2(-26, -18) * s, c + Vector2(-8, -24) * s, Color(1, 1, 1, 0.9), 3 * s)
		8: # mousse
			draw_circle(c + Vector2(-16, 6) * s, 18 * s, col)
			draw_circle(c + Vector2(16, 6) * s, 18 * s, col)
			draw_circle(c + Vector2(0, -8) * s, 20 * s, col)
			draw_circle(c + Vector2(-6, -14) * s, 5 * s, Color(0.8, 0.85, 1, 0.5))
		9: # neige
			draw_circle(c, 29 * s, col)
			draw_circle(c + Vector2(-10, -10) * s, 6 * s, Color(1, 1, 1, 0.8))
			draw_circle(c + Vector2(14, 10) * s, 3 * s, Color(0.7, 0.8, 1, 0.8))
		10: # crayon
			with_face = false
			_rr(Rect2(r.position + Vector2(8, 14) * s, Vector2(46, 28) * s), col, 4)
			_rr(Rect2(r.position + Vector2(0, 14) * s, Vector2(12, 28) * s), Color("#ff8fa3"), 4)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(18, -14) * s, c + Vector2(36, 0) * s, c + Vector2(18, 14) * s]), Color("#f1d3a0"))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(29, -6) * s, c + Vector2(36, 0) * s, c + Vector2(29, 6) * s]), Color("#3a2a3a"))
	if with_face:
		face(c, s * 0.8)


func draw_layer(rect: Rect2, tier: int, idx: int) -> void:
	var col: Color = TIERS[tier]["col"]
	if idx % 2 == 1:
		col = col.darkened(0.05)
	_rr(rect, col, 16)
	_rr(Rect2(rect.position + Vector2(14, 6), Vector2(rect.size.x - 28, 6)), Color(1, 1, 1, 0.35), 3, Color(0, 0, 0, 0))
	var h := (idx * 7919) % 97
	match tier:
		0, 10: # lignes douces
			for k in 6:
				var x := rect.position.x + 40.0 + float((h * 13 + k * 71) % int(rect.size.x - 80.0))
				draw_line(Vector2(x, rect.position.y + 16), Vector2(x, rect.end.y - 8), Color(0, 0, 0, 0.07), 3)
		1, 8, 9: # pois
			for k in 7:
				var x := rect.position.x + 30.0 + float((h * 17 + k * 61) % int(rect.size.x - 60.0))
				var y := rect.position.y + 18.0 + float((h + k * 13) % 20)
				draw_circle(Vector2(x, y), 4.0, Color(1, 1, 1, 0.45))
		2, 7: # bulles
			for k in 4:
				var x := rect.position.x + 30.0 + float((h * 19 + k * 97) % int(rect.size.x - 60.0))
				draw_arc(Vector2(x, rect.position.y + 26), 6.0, 0, TAU, 12, Color(1, 1, 1, 0.6), 2.0)
		6: # touches
			for k in 14:
				_rr(Rect2(rect.position + Vector2(24 + k * 30, 18), Vector2(22, 18)), Color(1, 1, 1, 0.35), 4, Color(0, 0, 0, 0.08))


func draw_player(feet: Vector2, sx: float, sy: float) -> void:
	var xf := Transform2D(0.0, Vector2(vs.x / 2.0, vs.y * 0.62 + height_vis))
	xf = xf.translated_local(feet).scaled_local(Vector2(sx, sy))
	draw_set_transform_matrix(xf)
	_rr(Rect2(-28, -46, 56, 46), Color("#d9964a"), 20)
	_rr(Rect2(-24, -44, 48, 28), Color("#f2c27b"), 18, Color(0, 0, 0, 0))
	face(Vector2(0, -22), 1.0)


func _draw() -> void:
	var cam := vs.y * 0.62 + height_vis
	var h01 := clampf(height_vis / (LH * PER_TIER * 10.0), 0.0, 1.0)
	# fond
	var c_top := sky(clampf(h01 + 0.18, 0.0, 1.0))
	var c_bot := sky(h01)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
		PackedColorArray([c_top, c_top, c_bot, c_bot]))
	var star_a := clampf((h01 - 0.4) * 2.0, 0.0, 1.0)
	if star_a > 0.0:
		for s in stars:
			var tw := 0.5 + 0.5 * sin(t_anim * 2.0 + s.x * 20.0)
			draw_circle(Vector2(s.x * vs.x, s.y * vs.y), 1.8, Color(1, 1, 1, star_a * tw))
	var cloud_a := 0.55 * (1.0 - h01 * 0.7)
	for c in clouds:
		var cy := fposmod(c.y * (vs.y + 300.0) + cam * 0.25, vs.y + 300.0) - 150.0
		var cx := c.x * vs.x
		draw_circle(Vector2(cx, cy), 36, Color(1, 1, 1, cloud_a))
		draw_circle(Vector2(cx + 34, cy + 6), 28, Color(1, 1, 1, cloud_a))
		draw_circle(Vector2(cx - 34, cy + 8), 26, Color(1, 1, 1, cloud_a))

	# monde
	draw_set_transform_matrix(Transform2D(0.0, Vector2(vs.x / 2.0, cam)))
	draw_rect(Rect2(-vs.x, 0, vs.x * 2.0, vs.y * 2.0), Color("#ffc2d9"))
	draw_rect(Rect2(-vs.x, 0, vs.x * 2.0, 10), Color("#ffe0ec"))
	var n_vis := ceili(height_vis / LH)
	var i_min := maxi(0, floori((cam - vs.y) / LH) - 1)
	for i in range(i_min, n_vis):
		var h := minf(LH, height_vis - i * LH)
		if h <= 0.5:
			continue
		var tier := tier_of(i)
		var w := TW + sin(t_anim * 1.5 + i * 0.9) * 3.0
		var hh := h
		if i == n_vis - 1:
			hh = h * (1.0 - 0.22 * top_squash)
			w += 10.0 * top_squash
		var rect := Rect2(-w / 2.0, -i * LH - hh, w, hh - 3.0)
		draw_layer(rect, tier, i)
		# trophees Lego
		if lego_images.size() > 0 and i > 0 and i % 20 == 0:
			var tex: Texture2D = lego_images[(i / 20 - 1) % lego_images.size()]
			var ts := tex.get_size()
			var k := minf(150.0 / ts.x, 150.0 / ts.y)
			var sz := ts * k
			var c := Vector2(TW / 2.0 + 130.0, -i * LH - LH / 2.0)
			_rr(Rect2(c - sz / 2.0 - Vector2(8, 8), sz + Vector2(16, 16)), Color("#fffaf0"), 10)
			draw_texture_rect(tex, Rect2(c - sz / 2.0, sz), false)
	# squishies a ramasser
	var cur := tier_of(layers)
	for it in items:
		draw_item(item_pos(it), cur, 1.0)
	# joueur
	var sx := 1.0
	var sy := 1.0
	if squash >= 0.0:
		sx = 1.0 + 0.25 * squash
		sy = 1.0 - 0.3 * squash
	else:
		sx = 1.0 + 0.2 * squash
		sy = 1.0 - 0.3 * squash
	if not grounded and state == 0:
		sy *= 1.0 + clampf(-vy / 4000.0, -0.08, 0.15)
	draw_player(Vector2(px, py), sx, sy)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(vs.x / 2.0, cam)))
	# "+N"
	for p in popups:
		var a := 1.0 - float(p["t"]) / 1.2
		draw_string(font, p["p"] + Vector2(-14, -30.0 - p["t"] * 60.0), p["txt"], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 0.95, 0.4, a))

	# interface
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(Vector2(40, 40), 16, Color("#ffd23f"))
	draw_circle(Vector2(40, 40), 10, Color("#ffeb85"))
	draw_string(font, Vector2(66, 52), str(coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
	var cur_name: String = TIERS[cur]["name"]
	var line := "Étage %d  ·  %s" % [layers, cur_name]
	draw_string(font, Vector2(0, 52), line, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 34, Color.WHITE)
	# collection (du plus rare au plus commun)
	var found := 0
	for k in TIERS.size():
		var x := vs.x - 30.0 - k * 26.0
		var col: Color = TIERS[k]["col"]
		if discovered[k]:
			found += 1
		else:
			col = Color(1, 1, 1, 0.25)
		draw_circle(Vector2(x, 90), 10, col)
	draw_string(font, Vector2(vs.x - 300, 60), "Découverts : %d/%d" % [found, TIERS.size()], HORIZONTAL_ALIGNMENT_RIGHT, 285, 26, Color.WHITE)
	if banner_t > 0.0:
		var a2 := clampf(banner_t, 0.0, 1.0)
		draw_string(font, Vector2(0, vs.y * 0.3), banner, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 54, Color(1, 1, 1, a2))
	# boutons
	draw_btn(pos_l, R_ARROW, Color("#ffffff"), Input.is_action_pressed("ui_left"))
	draw_colored_polygon(PackedVector2Array([pos_l + Vector2(-26, 0), pos_l + Vector2(18, -30), pos_l + Vector2(18, 30)]), Color(0.3, 0.2, 0.4, 0.8))
	draw_btn(pos_r, R_ARROW, Color("#ffffff"), Input.is_action_pressed("ui_right"))
	draw_colored_polygon(PackedVector2Array([pos_r + Vector2(26, 0), pos_r + Vector2(-18, -30), pos_r + Vector2(-18, 30)]), Color(0.3, 0.2, 0.4, 0.8))
	draw_btn(pos_j, R_JUMP, Color("#ff8a1e"), Input.is_action_pressed("ui_accept"))
	var tw := font.get_string_size("SAUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(font, pos_j + Vector2(-tw / 2.0, 12), "SAUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)


func draw_btn(c: Vector2, r: float, col: Color, pressed: bool) -> void:
	var a := 0.85 if pressed else 0.5
	draw_circle(c, r, Color(col.r, col.g, col.b, a))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)
