extends Node3D
## Tour ASMR 3D - V2.2
## Tu poses les squishies sur une tour infinie, ton personnage saute dessus.
## Amis a debloquer, ventilateur qui balance la tour, pluie de coeurs toutes les 5 minutes.
## Mode zen : la tour ne tombe jamais, aucun game over.

const PER_TIER := 8          # squishies poses par palier de rarete
const OVERLAP := 0.92        # les squishies s'ecrasent un peu les uns sur les autres
const R_MAX := 0.95          # decalage maximal du placement
const KEEP := 34             # squishies gardes en memoire (le reste est invisible, en dessous)
const TOWER_R := 1.4         # rayon ou le personnage peut marcher sur la tour
const SAVE_PATH := "user://tour_asmr_3d.cfg"
const EVENT_EVERY := 300.0   # pluie de coeurs toutes les 5 minutes
const FRIEND_NAMES: Array = ["Poussin", "Blob", "Canard", "Chaton", "Champignon", "Nuage", "Lapin", "Dino"]
const FRIEND_PRICES: Array = [10, 25, 45, 70, 100, 135, 175, 220]
const FRIEND_Z: Array = [-0.55, 0.5, -0.3, 0.65, -0.1, 0.3, -0.7, 0.05]
# objets a debloquer avec les pieces (inspires des constructions Lego)
const OBJETS: Array = [
	{"id": "filet", "name": "Filet de sécurité", "price": 40, "floor": 0},
	{"id": "reacteur", "name": "Réacteur à énergie", "price": 80, "floor": 8},
	{"id": "souff", "name": "Soufflerie", "price": 150, "floor": 16},
]
const PILOT_PRICE := 120
const ZONE_X := 2.9          # position du courant d'air de la soufflerie

# Index 0 = le plus rare (tout en haut), dernier = le plus commun (en bas)
var TIERS: Array = [
	{"id": "beurre", "name": "Beurre", "col": Color("#ffe27a"), "h": 0.5, "snd": [190.0, 0.38, 0.30, 0.5]},
	{"id": "needoh", "name": "Needoh", "col": Color("#c79bff"), "h": 1.0, "snd": [330.0, 0.30, 0.20, 0.6]},
	{"id": "bombe", "name": "Bombe à eau", "col": Color("#7fd1ff"), "h": 1.1, "snd": [260.0, 0.36, 0.80, -0.5]},
	{"id": "savon", "name": "Savon", "col": Color("#ffb3d1"), "h": 0.5, "snd": [420.0, 0.25, 0.35, 0.5]},
	{"id": "oeuf", "name": "Œuf", "col": Color("#fff1dc"), "h": 1.3, "snd": [260.0, 0.22, 0.60, 0.4]},
	{"id": "balle", "name": "Balle anti-stress", "col": Color("#5ec8ff"), "h": 1.2, "snd": [300.0, 0.30, 0.10, 0.7]},
	{"id": "ballon", "name": "Ballon de baudruche", "col": Color("#ff6b81"), "h": 1.25, "snd": [900.0, 0.30, 0.0, 0.0], "squeak": true},
	{"id": "dumpling", "name": "Dumpling", "col": Color("#f3e3cc"), "h": 0.9, "snd": [240.0, 0.28, 0.50, 0.5]},
	{"id": "clavier", "name": "Clavier", "col": Color("#9a9ab8"), "h": 0.35, "snd": [900.0, 0.06, 0.80, 0.1]},
	{"id": "glacon", "name": "Glaçon", "col": Color("#bfeaff"), "h": 1.0, "snd": [1400.0, 0.10, 0.90, 0.2]},
	{"id": "mousse", "name": "Mousse", "col": Color("#fbfbff"), "h": 0.9, "snd": [500.0, 0.40, 0.95, 0.3]},
	{"id": "neige", "name": "Neige", "col": Color("#e3eeff"), "h": 1.0, "snd": [700.0, 0.35, 0.90, 0.4]},
	{"id": "crayon", "name": "Crayon", "col": Color("#ffd23f"), "h": 0.35, "snd": [1100.0, 0.07, 0.60, 0.2]},
]

# --- tour
var count := 0
var coins := 0
var discovered: Array = []
var top_y := 0.0
var cam_y := 1.3
var pieces: Array = []
var hover: Node3D
var ring: MeshInstance3D
var ground: Node3D
var ox := 0.0
var oz := 0.0
var state := 0               # 0 = je place, 1 = ca tombe
var t_anim := 0.0
var sway_t := 99.0
var sway_a := 0.0
var sway_dir := Vector2.ZERO
var banner := ""
var banner_t := 0.0
var drops_done := 0
var touch_idx := -1
var combo := 0
var last_drop := -99.0
var lego_images: Array = []
var trophies: Array = []
var clouds: Array = []
var mesh_cache := {}

# --- monde
var cam: Camera3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var star_mat: StandardMaterial3D
var hud: Control
var btn_layer: CanvasLayer
var btns: Array = []
var pos_l := Vector2.ZERO
var pos_r := Vector2.ZERO
var pos_j := Vector2.ZERO
const R_ARROW := 80.0
const R_JUMP := 100.0

# --- personnage
var hero: Node3D
var hero_kind := 0           # 0 = pain, 1 = chat dans une banane
var chosen := false
var cx := 0.0
var cy := 0.0
var cvy := 0.0
var c_grounded := true
var c_state := 0             # 0 = jeu, 1 = "plouf"
var c_t := 0.0
var c_squash := 0.0
var c_lean := 0.0
var pilot_owned := false
var fuel := 1.0
var jet_parts: CPUParticles3D
var jet_t := 0.0
var bounce_assist := 0.0

# --- objets
var obj_owned := {"filet": false, "reacteur": false, "souff": false}
var net: Node3D
var net_dip := 0.0
var reactor: Node3D
var tube_fill: Array = []
var tube_mats: Array = []
var sparks: CPUParticles3D
var energy := 0.0
var overheat_t := 0.0
var turb: Node3D
var turb_spin: Node3D

# --- amis
var owned: Array = []
var friend_objs: Array = []

# --- ventilateur
var fan: Node3D
var fan_spin: Node3D
var fan_parts: CPUParticles3D
var fan_side := 1.0
var fan_speed := 2.0
var wind := 0.0
var wind_el := -1.0
var wind_dir := -1.0
var gust_timer := 25.0
const GUST_LEN := 4.0

# --- coeurs
var event_timer := EVENT_EVERY
var event_t := 0.0
var heart_spawn := 0.0
var hearts: Array = []

# --- boutique
var shop_open := false
var shop_msg := ""
var shop_msg_t := 0.0
var sbox := StyleBoxFlat.new()

# --- sons
var sfx_pop: AudioStreamWAV
var sfx_thud: AudioStreamWAV
var sfx_boing: AudioStreamWAV
var sfx_soft: AudioStreamWAV
var sfx_plouf: AudioStreamWAV
var sfx_coin: AudioStreamWAV
var sfx_new: AudioStreamWAV
var sfx_heart: AudioStreamWAV
var sfx_whoosh: AudioStreamWAV
var sfx_click: AudioStreamWAV
var sfx_jet: AudioStreamWAV
var sfx_over: AudioStreamWAV
var sfx_buy: AudioStreamWAV
var sfx_tier: Array = []
var players: Array = []
var play_i := 0

# --- test automatique (developpement)
var test_mode := false
var test_t := 0.0
var test_dir := 0.0
var test_jump := false
var n_gusts := 0
var n_hearts := 0
var n_hearts_got := 0
var n_falls := 0
var n_bounces := 0
var n_overheats := 0
var jet_frames := 0
var updraft_frames := 0
var test_hold := false


func _ready() -> void:
	test_mode = OS.get_environment("TOUR_TEST") != ""
	for i in TIERS.size():
		discovered.append(false)
	for i in FRIEND_NAMES.size():
		owned.append(false)
		friend_objs.append(null)
	setup_input()
	if test_mode:
		count = 70
		coins = 2000
		event_timer = 3.0
		gust_timer = 4.0
		chosen = true
	else:
		load_game()
	build_sounds()
	setup_world()
	rebuild_tower()
	build_fan()
	set_hero(hero_kind)
	for i in owned.size():
		if owned[i]:
			spawn_friend(i)
	for id in obj_owned:
		if obj_owned[id]:
			activate_obj(id)
	load_lego()
	new_hover()
	if not chosen:
		shop_open = true
		banner = "Choisis ton personnage !"
		banner_t = 3.0
	if test_mode:
		for i in owned.size():
			buy_friend(i)
		for i in OBJETS.size():
			buy_obj(i)
		pilot_owned = true
		set_hero(1)


func tier_of(i: int) -> int:
	return maxi(0, TIERS.size() - 1 - floori(float(i) / PER_TIER))


func th(tier: int) -> float:
	return float(TIERS[tier]["h"])


func setup_input() -> void:
	var map := {"move_left": [KEY_A, KEY_Q], "move_right": [KEY_D], "jump": [KEY_W, KEY_SHIFT]}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


# ---------------------------------------------------------------- monde 3D

func setup_world() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	cam.current = true

	star_mat = StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.albedo_color = Color(1, 1, 1, 0.0)
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	sm.radial_segments = 4
	sm.rings = 2
	sm.material = star_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = 120
	for i in 120:
		var d := Vector3(randf_range(-1.2, 1.2), randf_range(-0.3, 1.0), -randf_range(0.4, 1.0)).normalized() * 70.0
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, d))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	cam.add_child(mmi)

	ground = Node3D.new()
	add_child(ground)
	part(ground, se(Vector3(6.5, 0.9, 6.5), 2.6, 20), Color("#ffc2d9"), Vector3(0, -0.45, 0), 0.9)

	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	tm.rings = 24
	tm.ring_segments = 6
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.85)
	ring = MeshInstance3D.new()
	ring.mesh = tm
	ring.material_override = rm
	add_child(ring)

	# boutons tactiles : gauche, droite, saut
	btn_layer = CanvasLayer.new()
	add_child(btn_layer)
	make_btn("move_left", R_ARROW)
	make_btn("move_right", R_ARROW)
	make_btn("jump", R_JUMP)
	get_viewport().size_changed.connect(layout)

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = HUD.new()
	hud.g = self
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	layout()


func make_btn(action: String, radius: float) -> void:
	var b := TouchScreenButton.new()
	var cs := CircleShape2D.new()
	cs.radius = radius
	b.shape = cs
	b.action = action
	b.shape_visible = false
	btn_layer.add_child(b)
	btns.append(b)


func vsize() -> Vector2:
	return get_viewport().get_visible_rect().size


func layout() -> void:
	var vs := vsize()
	pos_l = Vector2(120.0, vs.y - 120.0)
	pos_r = Vector2(300.0, vs.y - 120.0)
	pos_j = Vector2(vs.x - 140.0, vs.y - 140.0)
	if btns.size() == 3:
		btns[0].position = pos_l
		btns[1].position = pos_r
		btns[2].position = pos_j


func rebuild_tower() -> void:
	top_y = 0.0
	var first_visible := maxi(0, count - 12)
	for i in count:
		var tier := tier_of(i)
		if i >= first_visible:
			var p := build_piece(tier)
			p.position = Vector3(randf_range(-0.5, 0.5), top_y, randf_range(-0.5, 0.5))
			p.rotation.y = randf_range(-0.35, 0.35)
			add_child(p)
			pieces.append({"node": p, "tier": tier})
		top_y += th(tier) * OVERLAP
	cam_y = top_y + 1.3
	cy = top_y


# ---------------------------------------------------------------- formes (superellipsoides)

func _sp(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() < 1e-20:
		return
	var nrm := Plane(a, b, c).normal
	if nrm.dot((a + b + c) / 3.0) < 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Forme arrondie : n = 2 donne une boule, n = 4 a 6 donne un coussin / bloc arrondi.
func se(size: Vector3, n: float, seg: int = 16) -> ArrayMesh:
	var key := "%s|%s|%d" % [size, n, seg]
	if mesh_cache.has(key):
		return mesh_cache[key]
	var e := 2.0 / n
	var rows := seg
	var cols := seg * 2
	var pts: Array = []
	for i in rows + 1:
		var phi := -PI / 2.0 + PI * float(i) / float(rows)
		var cp := cos(phi)
		var sp := sin(phi)
		var row: Array = []
		for j in cols + 1:
			if j == cols:
				row.append(row[0])
				continue
			var t := TAU * float(j) / float(cols)
			var v := Vector3(_sp(cp, e) * _sp(cos(t), e), _sp(sp, e), _sp(cp, e) * _sp(sin(t), e))
			row.append(Vector3(v.x * size.x, v.y * size.y, v.z * size.z) / 2.0)
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows:
		for j in cols:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j + 1]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i + 1][j]
			_tri(st, a, b, c)
			_tri(st, a, c, d)
	st.generate_normals()
	var m := st.commit()
	mesh_cache[key] = m
	return m


func cone(r: float, h: float, seg: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	return m


func part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rough := 0.4, alpha := 1.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func add_face(root: Node3D, y: float, z: float) -> void:
	for s in [-1.0, 1.0]:
		part(root, se(Vector3(0.16, 0.2, 0.1), 2.0, 6), Color("#3a2a3a"), Vector3(s * 0.22, y, z), 0.3)
		part(root, se(Vector3(0.06, 0.06, 0.05), 2.0, 4), Color.WHITE, Vector3(s * 0.22 - 0.03, y + 0.05, z + 0.04), 0.2)
		part(root, se(Vector3(0.2, 0.1, 0.06), 2.0, 6), Color(1.0, 0.6, 0.7), Vector3(s * 0.42, y - 0.12, z - 0.01), 0.6, 0.7)


## Construit un squishy. L'origine est au centre du dessous.
func build_piece(tier: int) -> Node3D:
	var root := Node3D.new()
	var col: Color = TIERS[tier]["col"]
	var face_d := 0.0
	match String(TIERS[tier]["id"]):
		"beurre":
			part(root, se(Vector3(1.7, 0.5, 1.1), 5.0, 22), col, Vector3(0, 0.25, 0), 0.3)
			part(root, se(Vector3(1.66, 0.14, 1.06), 5.0, 8), Color("#fff4b8"), Vector3(0, 0.44, 0), 0.3)
			face_d = 1.1
		"needoh":
			part(root, se(Vector3(1.3, 1.0, 1.3), 2.4, 22), col, Vector3(0, 0.5, 0), 0.5)
			for k in 6:
				var a := float(k) * 1.05
				part(root, se(Vector3(0.16, 0.16, 0.16), 2.0, 6), Color("#ff7ac8"), Vector3(cos(a) * 0.35, 0.92 - 0.1 * float(k % 2), sin(a) * 0.35 - 0.1), 0.4)
			face_d = 1.3
		"bombe": # bombe a eau : ballon d'eau translucide avec noeud
			part(root, se(Vector3(1.1, 1.1, 1.1), 2.0, 22), col, Vector3(0, 0.55, 0), 0.05, 0.55)
			part(root, se(Vector3(0.95, 0.7, 0.95), 2.0, 16), Color("#3fa7e8"), Vector3(0, 0.38, 0), 0.1, 0.8)
			part(root, se(Vector3(0.22, 0.2, 0.22), 2.0, 8), Color("#ff9d4d"), Vector3(0, 1.1, 0), 0.5)
			part(root, se(Vector3(0.2, 0.3, 0.12), 2.0, 8), Color.WHITE, Vector3(-0.3, 0.85, 0.3), 0.1, 0.6)
			face_d = 1.1
		"savon":
			part(root, se(Vector3(1.5, 0.5, 1.0), 4.0, 20), col, Vector3(0, 0.25, 0), 0.25)
			part(root, se(Vector3(0.22, 0.22, 0.22), 2.0, 8), Color.WHITE, Vector3(0.5, 0.55, 0.15), 0.1, 0.6)
			part(root, se(Vector3(0.14, 0.14, 0.14), 2.0, 8), Color.WHITE, Vector3(0.65, 0.68, -0.1), 0.1, 0.6)
			face_d = 1.0
		"oeuf":
			part(root, se(Vector3(1.0, 1.3, 1.0), 2.0, 22), col, Vector3(0, 0.65, 0), 0.25)
			part(root, se(Vector3(0.2, 0.3, 0.12), 2.0, 8), Color.WHITE, Vector3(-0.25, 0.95, 0.3), 0.1, 0.5)
			face_d = 1.0
		"balle":
			part(root, se(Vector3(1.2, 1.2, 1.2), 2.0, 22), col, Vector3(0, 0.6, 0), 0.5)
			part(root, se(Vector3(0.3, 0.2, 0.15), 2.0, 8), Color.WHITE, Vector3(-0.3, 0.95, 0.3), 0.1, 0.5)
			face_d = 1.2
		"ballon": # ballon de baudruche : brillant, avec noeud
			part(root, se(Vector3(1.1, 1.25, 1.1), 2.1, 22), col, Vector3(0, 0.625, 0), 0.12)
			part(root, se(Vector3(0.18, 0.18, 0.18), 2.0, 8), Color("#d94a60"), Vector3(0, 1.22, 0), 0.3)
			part(root, se(Vector3(0.22, 0.4, 0.12), 2.0, 8), Color.WHITE, Vector3(-0.32, 0.9, 0.3), 0.05, 0.55)
			face_d = 1.1
		"dumpling":
			part(root, se(Vector3(1.6, 0.9, 1.2), 2.4, 22), col, Vector3(0, 0.45, 0), 0.6)
			for k in 4:
				part(root, se(Vector3(0.12, 0.3, 0.14), 2.0, 6), Color("#d9bf9b"), Vector3(-0.45 + 0.3 * float(k), 0.8, 0.0), 0.6)
			face_d = 1.2
		"clavier":
			part(root, se(Vector3(1.8, 0.35, 1.0), 6.0, 16), Color("#6c6c88"), Vector3(0, 0.175, 0), 0.5)
			for r in 3:
				for c in 6:
					part(root, se(Vector3(0.22, 0.08, 0.24), 4.0, 6), Color("#d8d8ee"), Vector3(-0.75 + 0.3 * float(c), 0.35, -0.3 + 0.3 * float(r)), 0.4)
		"glacon":
			part(root, se(Vector3(1.0, 1.0, 1.0), 5.0, 18), col, Vector3(0, 0.5, 0), 0.05, 0.6)
			part(root, se(Vector3(0.5, 0.06, 0.3), 3.0, 6), Color.WHITE, Vector3(-0.15, 0.98, 0.15), 0.1, 0.7)
			face_d = 1.0
		"mousse":
			part(root, se(Vector3(0.8, 0.8, 0.8), 2.0, 14), col, Vector3(-0.4, 0.4, 0.0), 0.9)
			part(root, se(Vector3(0.8, 0.8, 0.8), 2.0, 14), col, Vector3(0.4, 0.4, 0.0), 0.9)
			part(root, se(Vector3(0.8, 0.8, 0.8), 2.0, 14), col, Vector3(0.0, 0.4, -0.35), 0.9)
			part(root, se(Vector3(0.9, 0.8, 0.9), 2.0, 14), col, Vector3(0.0, 0.5, 0.0), 0.9)
			face_d = 0.9
		"neige":
			part(root, se(Vector3(1.1, 1.0, 1.1), 2.2, 20), col, Vector3(0, 0.5, 0), 0.9)
			part(root, se(Vector3(0.18, 0.18, 0.18), 2.0, 6), Color("#a9c8ff"), Vector3(0.4, 0.8, 0.3), 0.3, 0.8)
			part(root, se(Vector3(0.12, 0.12, 0.12), 2.0, 6), Color("#a9c8ff"), Vector3(-0.35, 0.7, 0.4), 0.3, 0.8)
			face_d = 1.1
		"crayon":
			var cols_p := [col, Color("#ff6b6b"), Color("#5ec8ff")]
			for k in 3:
				var z := (float(k) - 1.0) * 0.32
				var body := CylinderMesh.new()
				body.top_radius = 0.15
				body.bottom_radius = 0.15
				body.height = 1.5
				body.radial_segments = 10
				part(root, body, cols_p[k], Vector3(0, 0.17, z), 0.4, 1.0, Vector3(0, 0, 90))
				part(root, cone(0.15, 0.3, 10), Color("#f1d3a0"), Vector3(0.9, 0.17, z), 0.6, 1.0, Vector3(0, 0, -90))
				var end := CylinderMesh.new()
				end.top_radius = 0.155
				end.bottom_radius = 0.155
				end.height = 0.2
				end.radial_segments = 10
				part(root, end, Color("#ff8fa3"), Vector3(-0.82, 0.17, z), 0.6, 1.0, Vector3(0, 0, 90))
	if face_d > 0.0:
		add_face(root, th(tier) * 0.55, face_d * 0.5 - 0.02)
	return root


# ---------------------------------------------------------------- personnage et amis

func build_hero(kind: int) -> Node3D:
	var root := Node3D.new()
	if kind == 0: # le pain
		part(root, se(Vector3(0.95, 0.8, 0.8), 3.0, 18), Color("#d9964a"), Vector3(0, 0.45, 0), 0.7)
		part(root, se(Vector3(0.85, 0.4, 0.7), 3.0, 14), Color("#f2c27b"), Vector3(0, 0.62, 0.02), 0.7)
		part(root, se(Vector3(0.22, 0.14, 0.3), 2.0, 6), Color("#b8793a"), Vector3(-0.2, 0.05, 0.1), 0.7)
		part(root, se(Vector3(0.22, 0.14, 0.3), 2.0, 6), Color("#b8793a"), Vector3(0.2, 0.05, 0.1), 0.7)
		add_face(root, 0.5, 0.38)
	elif kind == 1: # le chat dans une banane
		var yel := Color("#ffe135")
		part(root, se(Vector3(0.7, 0.55, 0.6), 2.4, 14), yel, Vector3(0, 0.3, 0), 0.5)
		part(root, se(Vector3(0.66, 0.5, 0.56), 2.4, 14), yel, Vector3(0.04, 0.62, 0), 0.5)
		part(root, se(Vector3(0.45, 0.07, 0.28), 3.0, 6), yel, Vector3(-0.32, 0.86, 0.0), 0.5, 1.0, Vector3(0, 0, 30))
		part(root, se(Vector3(0.45, 0.07, 0.28), 3.0, 6), yel, Vector3(0.36, 0.86, 0.0), 0.5, 1.0, Vector3(0, 0, -30))
		part(root, se(Vector3(0.45, 0.07, 0.28), 3.0, 6), yel, Vector3(0.0, 0.86, -0.3), 0.5, 1.0, Vector3(-30, 0, 0))
		part(root, se(Vector3(0.14, 0.1, 0.14), 2.0, 6), Color("#7a5230"), Vector3(0, 0.03, 0), 0.6)
		var fur := Color("#ffa94d")
		part(root, se(Vector3(0.62, 0.5, 0.52), 2.2, 16), fur, Vector3(0, 0.98, 0.02), 0.7)
		part(root, cone(0.12, 0.22, 8), fur, Vector3(-0.2, 1.3, 0.0), 0.7, 1.0, Vector3(0, 0, 12))
		part(root, cone(0.12, 0.22, 8), fur, Vector3(0.2, 1.3, 0.0), 0.7, 1.0, Vector3(0, 0, -12))
		add_face(root, 0.98, 0.24)
		part(root, se(Vector3(0.08, 0.06, 0.05), 2.0, 4), Color("#ff7a90"), Vector3(0, 0.92, 0.27), 0.4)
		for s in [-1.0, 1.0]:
			part(root, se(Vector3(0.28, 0.015, 0.015), 2.0, 4), Color(0.3, 0.2, 0.2), Vector3(s * 0.36, 0.93, 0.2), 0.5, 1.0, Vector3(0, 0, s * 8.0))
	else: # le pilote au jetpack (inspire de ta construction Lego)
		var dark := Color("#2b2b33")
		part(root, se(Vector3(0.6, 0.7, 0.42), 3.0, 14), Color("#3a3a46"), Vector3(0, 0.62, 0), 0.5)
		part(root, se(Vector3(0.5, 0.08, 0.3), 3.0, 8), Color("#d94a4a"), Vector3(0, 0.78, 0.18), 0.5)
		part(root, se(Vector3(0.24, 0.5, 0.26), 3.0, 8), dark, Vector3(-0.14, 0.2, 0), 0.5)
		part(root, se(Vector3(0.24, 0.5, 0.26), 3.0, 8), dark, Vector3(0.14, 0.2, 0), 0.5)
		part(root, se(Vector3(0.14, 0.45, 0.16), 3.0, 8), dark, Vector3(-0.4, 0.62, 0), 0.5)
		part(root, se(Vector3(0.14, 0.45, 0.16), 3.0, 8), dark, Vector3(0.4, 0.62, 0), 0.5)
		part(root, se(Vector3(0.55, 0.55, 0.55), 2.4, 16), Color("#17171c"), Vector3(0, 1.17, 0), 0.25)
		part(root, se(Vector3(0.4, 0.14, 0.12), 3.0, 8), Color("#7a1f2b"), Vector3(0, 1.17, 0.26), 0.15)
		for s in [-1.0, 1.0]:
			part(root, se(Vector3(0.07, 0.07, 0.05), 2.0, 4), Color("#ffe9a8"), Vector3(s * 0.1, 1.17, 0.3), 0.2)
		part(root, se(Vector3(0.5, 0.6, 0.28), 4.0, 10), Color("#d62828"), Vector3(0, 0.7, -0.34), 0.4)
		part(root, se(Vector3(0.24, 0.16, 0.24), 4.0, 8), Color("#ffd23f"), Vector3(-0.13, 1.02, -0.34), 0.4)
		part(root, se(Vector3(0.24, 0.16, 0.24), 4.0, 8), Color("#ffd23f"), Vector3(0.13, 1.02, -0.34), 0.4)
		part(root, se(Vector3(0.14, 0.2, 0.14), 3.0, 6), Color("#17171c"), Vector3(0, 0.34, -0.34), 0.4)
		jet_parts = make_flames()
		jet_parts.position = Vector3(0, 0.26, -0.34)
		root.add_child(jet_parts)
		root.rotation.y = 0.55
	return root


func build_friend(i: int) -> Node3D:
	var root := Node3D.new()
	match i:
		0: # poussin
			part(root, se(Vector3(1.0, 1.0, 0.95), 2.0, 14), Color("#ffe45c"), Vector3(0, 0.5, 0), 0.7)
			part(root, cone(0.1, 0.2, 8), Color("#ff9d4d"), Vector3(0, 0.45, 0.5), 0.5, 1.0, Vector3(90, 0, 0))
			add_face(root, 0.58, 0.45)
		1: # blob
			part(root, se(Vector3(1.2, 0.95, 1.1), 2.2, 14), Color("#8be28b"), Vector3(0, 0.475, 0), 0.4)
			add_face(root, 0.5, 0.53)
		2: # canard
			part(root, se(Vector3(1.1, 0.8, 1.0), 2.2, 14), Color("#ffd84a"), Vector3(0, 0.4, 0), 0.6)
			part(root, se(Vector3(0.7, 0.7, 0.65), 2.0, 12), Color("#ffd84a"), Vector3(0, 0.95, 0.1), 0.6)
			part(root, se(Vector3(0.4, 0.12, 0.25), 3.0, 8), Color("#ff9d4d"), Vector3(0, 0.88, 0.45), 0.5)
			add_face(root, 1.0, 0.4)
		3: # chaton
			part(root, se(Vector3(1.0, 0.9, 0.9), 2.0, 14), Color("#b9b9c9"), Vector3(0, 0.45, 0), 0.7)
			part(root, cone(0.14, 0.26, 8), Color("#b9b9c9"), Vector3(-0.3, 1.0, 0), 0.7, 1.0, Vector3(0, 0, 14))
			part(root, cone(0.14, 0.26, 8), Color("#b9b9c9"), Vector3(0.3, 1.0, 0), 0.7, 1.0, Vector3(0, 0, -14))
			add_face(root, 0.5, 0.43)
		4: # champignon
			part(root, se(Vector3(0.6, 0.6, 0.6), 2.4, 12), Color("#fff0d6"), Vector3(0, 0.3, 0), 0.7)
			part(root, se(Vector3(1.3, 0.65, 1.3), 2.2, 16), Color("#ff5a5a"), Vector3(0, 0.8, 0), 0.5)
			for k in 4:
				var a := float(k) * 1.6
				part(root, se(Vector3(0.2, 0.1, 0.2), 2.0, 6), Color.WHITE, Vector3(cos(a) * 0.38, 1.08, sin(a) * 0.38), 0.5)
			add_face(root, 0.32, 0.27)
		5: # nuage
			part(root, se(Vector3(0.7, 0.7, 0.7), 2.0, 12), Color.WHITE, Vector3(-0.4, 0.4, 0), 0.9)
			part(root, se(Vector3(0.7, 0.7, 0.7), 2.0, 12), Color.WHITE, Vector3(0.4, 0.4, 0), 0.9)
			part(root, se(Vector3(0.9, 0.85, 0.85), 2.0, 14), Color.WHITE, Vector3(0, 0.5, 0), 0.9)
			add_face(root, 0.5, 0.4)
		6: # lapin
			part(root, se(Vector3(0.9, 0.9, 0.85), 2.0, 14), Color("#fdfdfd"), Vector3(0, 0.45, 0), 0.8)
			part(root, se(Vector3(0.2, 0.8, 0.12), 2.0, 8), Color("#fdfdfd"), Vector3(-0.22, 1.2, 0), 0.8)
			part(root, se(Vector3(0.2, 0.8, 0.12), 2.0, 8), Color("#fdfdfd"), Vector3(0.22, 1.2, 0), 0.8)
			part(root, se(Vector3(0.1, 0.55, 0.05), 2.0, 6), Color("#ffb3c1"), Vector3(-0.22, 1.2, 0.05), 0.8)
			part(root, se(Vector3(0.1, 0.55, 0.05), 2.0, 6), Color("#ffb3c1"), Vector3(0.22, 1.2, 0.05), 0.8)
			add_face(root, 0.5, 0.4)
		7: # dino
			part(root, se(Vector3(1.1, 0.9, 0.95), 2.2, 14), Color("#6cc08b"), Vector3(0, 0.45, 0), 0.6)
			part(root, se(Vector3(0.5, 0.3, 0.3), 2.0, 8), Color("#6cc08b"), Vector3(0, 0.3, -0.55), 0.6)
			for k in 3:
				part(root, cone(0.1, 0.22, 6), Color("#3fa56a"), Vector3(0, 0.95 - 0.1 * float(k), -0.15 - 0.15 * float(k)), 0.6)
			add_face(root, 0.55, 0.46)
	root.scale = Vector3.ONE * 0.55
	return root


func set_hero(kind: int) -> void:
	hero_kind = kind
	if is_instance_valid(hero):
		hero.queue_free()
	jet_parts = null
	hero = build_hero(kind)
	hero.position = Vector3(cx, cy, 0.25)
	add_child(hero)


func spawn_friend(i: int) -> void:
	var node := build_friend(i)
	node.position = Vector3(randf_range(-1.0, 1.0), top_y, float(FRIEND_Z[i]))
	add_child(node)
	friend_objs[i] = {"node": node, "x": randf_range(-1.0, 1.0), "tx": randf_range(-1.1, 1.1), "z": float(FRIEND_Z[i]), "wait": randf_range(0.0, 2.0), "vy": 0.0, "yoff": 0.0}


func friend_available(i: int) -> bool:
	return count >= i * PER_TIER


func buy_friend(i: int) -> bool:
	if owned[i] or not friend_available(i):
		return false
	var price: int = FRIEND_PRICES[i]
	if coins < price:
		return false
	coins -= price
	owned[i] = true
	spawn_friend(i)
	play(sfx_buy)
	banner = "%s est ton ami !" % FRIEND_NAMES[i]
	banner_t = 2.4
	save_game()
	return true


func update_friends(dt: float) -> void:
	for i in friend_objs.size():
		var f = friend_objs[i]
		if f == null:
			continue
		if f["wait"] > 0.0:
			f["wait"] -= dt
		else:
			var d: float = f["tx"] - f["x"]
			f["x"] += clampf(d, -0.6 * dt, 0.6 * dt)
			if absf(d) < 0.05:
				f["tx"] = randf_range(-1.1, 1.1)
				f["wait"] = randf_range(0.5, 2.5)
		f["vy"] -= 14.0 * dt
		f["yoff"] += f["vy"] * dt
		if f["yoff"] <= 0.0:
			f["yoff"] = 0.0
			f["vy"] = 0.0
			if randf() < dt * 0.35:
				f["vy"] = 3.2
		var node: Node3D = f["node"]
		node.position = Vector3(f["x"], top_y + f["yoff"], f["z"])


func friends_hop() -> void:
	for f in friend_objs:
		if f != null:
			f["vy"] = randf_range(3.5, 5.0)


# ---------------------------------------------------------------- ventilateur

func build_fan() -> void:
	fan = Node3D.new()
	add_child(fan)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = 1.4
	part(fan, pole, Color("#9ad7ff"), Vector3(0, -0.15, 0), 0.4)
	part(fan, se(Vector3(0.5, 0.5, 0.5), 2.0, 10), Color("#7fd1ff"), Vector3(0, 0.55, 0), 0.4)
	fan_spin = Node3D.new()
	fan_spin.position = Vector3(-0.3, 0.55, 0)
	fan.add_child(fan_spin)
	for k in 3:
		var pv := Node3D.new()
		pv.rotation_degrees = Vector3(float(k) * 120.0, 0, 0)
		fan_spin.add_child(pv)
		part(pv, se(Vector3(0.05, 0.55, 0.26), 2.4, 8), Color.WHITE, Vector3(0, 0.3, 0), 0.4)
	part(fan_spin, se(Vector3(0.14, 0.14, 0.14), 2.0, 8), Color("#ffd23f"), Vector3.ZERO, 0.4)
	var cage := TorusMesh.new()
	cage.inner_radius = 0.62
	cage.outer_radius = 0.67
	cage.rings = 24
	cage.ring_segments = 4
	part(fan, cage, Color("#7fd1ff"), Vector3(-0.3, 0.55, 0), 0.4, 1.0, Vector3(0, 0, 90))
	# traits de vent
	fan_parts = CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.03, 0.03)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1, 1, 1, 0.7)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	fan_parts.mesh = bm
	fan_parts.amount = 22
	fan_parts.lifetime = 1.0
	fan_parts.direction = Vector3(-1, 0, 0)
	fan_parts.spread = 6.0
	fan_parts.initial_velocity_min = 4.0
	fan_parts.initial_velocity_max = 5.0
	fan_parts.gravity = Vector3.ZERO
	fan_parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fan_parts.emission_box_extents = Vector3(0.05, 0.5, 0.5)
	fan_parts.position = Vector3(-0.6, 0.55, 0)
	fan_parts.emitting = false
	fan.add_child(fan_parts)
	fan.position = Vector3(4.2, top_y, 0)


func update_fan(dt: float) -> void:
	gust_timer -= dt
	if wind_el < 0.0 and gust_timer <= 0.0:
		wind_el = 0.0
		fan_side = 1.0 if randf() < 0.5 else -1.0
		wind_dir = -fan_side
		fan.position.x = fan_side * 4.2
		fan.rotation.y = 0.0 if fan_side > 0.0 else PI
		fan_parts.emitting = true
		play(sfx_whoosh, 1.0, -3.0)
		banner = "Ça souffle !"
		banner_t = 1.6
		n_gusts += 1
	if wind_el >= 0.0:
		wind_el += dt
		wind = sin(PI * clampf(wind_el / GUST_LEN, 0.0, 1.0))
		if wind_el >= GUST_LEN:
			wind_el = -1.0
			wind = 0.0
			fan_parts.emitting = false
			gust_timer = randf_range(22.0, 38.0)
	fan_speed = lerpf(fan_speed, 2.0 + wind * 26.0, 1.0 - exp(-3.0 * dt))
	fan_spin.rotation.x += fan_speed * dt
	fan.position.y = lerpf(fan.position.y, top_y + 0.1, 1.0 - exp(-5.0 * dt))


func wind_vel() -> float:
	return wind_dir * wind * 1.6


# ---------------------------------------------------------------- coeurs

func build_heart() -> Node3D:
	var root := Node3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#ff5c8a")
	var a := MeshInstance3D.new()
	a.mesh = se(Vector3(0.36, 0.36, 0.2), 2.0, 8)
	a.position = Vector3(-0.14, 0.12, 0)
	a.material_override = m
	root.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = se(Vector3(0.36, 0.36, 0.2), 2.0, 8)
	b.position = Vector3(0.14, 0.12, 0)
	b.material_override = m
	root.add_child(b)
	var c := MeshInstance3D.new()
	c.mesh = se(Vector3(0.36, 0.36, 0.2), 5.0, 8)
	c.position = Vector3(0, -0.06, 0)
	c.rotation_degrees = Vector3(0, 0, 45)
	c.material_override = m
	root.add_child(c)
	root.scale = Vector3.ONE * 1.3
	return root


func start_hearts() -> void:
	event_t = 20.0
	heart_spawn = 0.0
	banner = "Pluie de cœurs !"
	banner_t = 2.5
	play(sfx_new)


func update_hearts(dt: float) -> void:
	event_timer -= dt
	if event_timer <= 0.0 and event_t <= 0.0:
		start_hearts()
		event_timer = EVENT_EVERY
	if event_t > 0.0:
		event_t -= dt
		heart_spawn -= dt
		if heart_spawn <= 0.0:
			heart_spawn = 0.45
			var h := build_heart()
			h.position = Vector3(randf_range(-2.2, 2.2), top_y + randf_range(0.8, 3.0), randf_range(-0.4, 0.6))
			add_child(h)
			hearts.append({"node": h, "t": 0.0, "ph": randf() * TAU})
			n_hearts += 1
	var hp := Vector3(cx, cy + 0.5, 0.25)
	for d in hearts.duplicate():
		d["t"] += dt
		var node: Node3D = d["node"]
		node.position.x += wind_dir * wind * 1.2 * dt
		node.position.y += 0.15 * dt + sin(t_anim * 3.0 + d["ph"]) * 0.004
		node.rotation.y += 1.5 * dt
		var life := 9.0
		var left := life - float(d["t"])
		node.scale = Vector3.ONE * 1.3 * clampf(left, 0.0, 1.0)
		if c_state == 0 and node.position.distance_to(hp) < 0.85:
			coins += 5
			n_hearts_got += 1
			play(sfx_heart, randf_range(0.9, 1.3))
			burst(node.position, Color("#ff5c8a"))
			node.queue_free()
			hearts.erase(d)
		elif left <= 0.0:
			node.queue_free()
			hearts.erase(d)


# ---------------------------------------------------------------- sons

func make_sound(freq: float, dur: float, noise: float, sweep: float, seed_v := 0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0 + dur * 100.0) + seed_v * 7919
	for i in n:
		var t := float(i) / float(n)
		var env_v := pow(1.0 - t, 2.2) * minf(1.0, t * 60.0)
		var f := freq * (1.0 - sweep * t)
		phase += TAU * f / float(rate)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		var v := (sin(phase) * (1.0 - noise) + lp * 2.0 * noise) * env_v * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return wav_from(data, rate)


func wav_from(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


## Couinement de ballon de baudruche : ton qui monte et descend avec vibrato.
func make_squeak(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := freq * (1.0 + 0.35 * sin(PI * t)) * (1.0 + 0.04 * sin(t * 220.0))
		phase += TAU * f / float(rate)
		var env_v := sin(PI * t) * 0.5
		var v := (sin(phase) + 0.4 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0)) * env_v * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return wav_from(data, rate)


## Suite de notes (carillon) : pieces, nouveau squishy, coeurs.
func make_chime(freqs: Array, note_dur: float, decay := 4.0) -> AudioStreamWAV:
	var rate := 22050
	var total := note_dur * float(freqs.size()) + note_dur * 2.0
	var n := int(rate * total)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in freqs.size():
		var start := int(rate * note_dur * float(k))
		var len_n := int(rate * note_dur * 3.0)
		for i in len_n:
			if start + i >= n:
				break
			var t := float(i) / float(rate)
			var env_v := exp(-t * decay * 2.0) * minf(1.0, t * 200.0)
			var w := TAU * float(freqs[k]) * t
			buf[start + i] += (sin(w) + 0.3 * sin(w * 2.0)) * env_v * 0.35
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return wav_from(data, rate)


## Souffle de vent : bruit adouci qui monte puis redescend.
func make_whoosh(dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var k := 0.04 + 0.12 * sin(PI * t)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var v := lp * 3.0 * pow(sin(PI * t), 1.5)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0 * 0.6))
	return wav_from(data, rate)


func build_sounds() -> void:
	sfx_pop = make_sound(420.0, 0.12, 0.1, -0.5)
	sfx_thud = make_sound(110.0, 0.25, 0.45, 0.6, 1)
	sfx_boing = make_sound(180.0, 0.18, 0.35, 0.5, 2)   # le "pof" de pain au saut
	sfx_soft = make_sound(140.0, 0.12, 0.5, 0.4, 3)
	sfx_plouf = make_sound(110.0, 0.5, 0.45, 0.6, 4)
	sfx_coin = make_chime([1320.0, 1760.0], 0.05, 5.0)
	sfx_new = make_chime([523.0, 659.0, 784.0, 1047.0], 0.08, 3.0)
	sfx_heart = make_chime([880.0, 1320.0], 0.04, 6.0)
	sfx_buy = make_chime([660.0, 880.0, 1320.0], 0.06, 4.0)
	sfx_click = make_sound(700.0, 0.04, 0.2, 0.3, 5)
	sfx_whoosh = make_whoosh(1.4)
	sfx_jet = make_whoosh(0.22)
	sfx_over = make_chime([392.0, 523.0, 659.0, 784.0, 1047.0, 1318.0], 0.07, 2.5)
	for t in TIERS:
		var p: Array = t["snd"]
		var variants: Array = []
		if t.has("squeak"):
			variants.append(make_squeak(p[0], p[1]))
			variants.append(make_squeak(p[0] * 1.25, p[1] * 0.8))
		else:
			variants.append(make_sound(p[0], p[1], p[2], p[3], 0))
			variants.append(make_sound(p[0] * 1.12, p[1] * 0.9, p[2], p[3], 9))
		sfx_tier.append(variants)
	for i in 8:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players.append(pl)


func play(s: AudioStream, pitch := 1.0, vol := 0.0) -> void:
	var p: AudioStreamPlayer = players[play_i]
	play_i = (play_i + 1) % players.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = vol
	p.play()


# ---------------------------------------------------------------- sauvegarde / Lego

func save_game() -> void:
	if test_mode:
		return
	var cf := ConfigFile.new()
	cf.set_value("game", "count", count)
	cf.set_value("game", "coins", coins)
	cf.set_value("game", "discovered", discovered)
	cf.set_value("game", "owned", owned)
	cf.set_value("game", "hero", hero_kind)
	cf.set_value("game", "chosen", chosen)
	cf.set_value("game", "objs", obj_owned)
	cf.set_value("game", "pilot", pilot_owned)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	count = maxi(0, int(cf.get_value("game", "count", 0)))
	coins = int(cf.get_value("game", "coins", 0))
	var d = cf.get_value("game", "discovered", [])
	if d is Array:
		for i in mini(d.size(), discovered.size()):
			discovered[i] = d[i]
	var o = cf.get_value("game", "owned", [])
	if o is Array:
		for i in mini(o.size(), owned.size()):
			owned[i] = o[i]
	hero_kind = int(cf.get_value("game", "hero", 0))
	chosen = bool(cf.get_value("game", "chosen", false))
	pilot_owned = bool(cf.get_value("game", "pilot", false))
	var ob = cf.get_value("game", "objs", {})
	if ob is Dictionary:
		for k in obj_owned:
			if ob.has(k):
				obj_owned[k] = bool(ob[k])


func load_lego() -> void:
	var dir := "res://lego/"
	for f in DirAccess.get_files_at(dir):
		var nm := f.trim_suffix(".import")
		var ext := nm.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp"]:
			var tex = load(dir + nm)
			if tex is Texture2D and not lego_images.has(tex):
				lego_images.append(tex)


# ---------------------------------------------------------------- jeu : poser un squishy

func new_hover() -> void:
	hover = build_piece(tier_of(count))
	hover.rotation.y = randf_range(-0.35, 0.35)
	add_child(hover)
	hover.position = Vector3(ox, top_y + 3.0, oz)
	play(sfx_pop, 1.4, -8.0)
	state = 0


func drop() -> void:
	if state != 0 or not is_instance_valid(hover):
		return
	state = 1
	var piece := hover
	var tier := tier_of(count)
	piece.position = Vector3(ox, piece.position.y, oz)
	var tw := create_tween()
	tw.tween_property(piece, "position:y", top_y, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(land.bind(piece, tier, Vector2(ox, oz)))


func land(piece: Node3D, tier: int, off: Vector2) -> void:
	piece.position.y = top_y
	var val := (TIERS.size() - tier) * (2 if overheat_t > 0.0 else 1)
	coins += val
	var first: bool = not discovered[tier]
	discovered[tier] = true
	count += 1
	pieces.append({"node": piece, "tier": tier})
	var h := th(tier)
	var burst_pos := piece.position + Vector3(0, h * 0.5, 0)
	top_y += h * OVERLAP
	# effet "squish"
	piece.scale = Vector3.ONE
	var tw := create_tween()
	tw.tween_property(piece, "scale", Vector3(1.25, 0.72, 1.25), 0.07)
	tw.tween_property(piece, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# combo : plus on enchaine vite, plus le son monte
	if t_anim - last_drop < 2.5:
		combo = mini(combo + 1, 8)
	else:
		combo = 0
	last_drop = t_anim
	var pitch := (1.0 + 0.04 * float(combo)) * randf_range(0.96, 1.04) * (1.1 if overheat_t > 0.0 else 1.0)
	var variants: Array = sfx_tier[tier]
	play(variants[randi() % variants.size()], pitch, 3.0 if overheat_t > 0.0 else 0.0)
	add_energy()
	play(sfx_thud, randf_range(0.9, 1.1), -6.0)
	get_tree().create_timer(0.12).timeout.connect(play.bind(sfx_pop, 1.2 + 0.05 * float(combo), -10.0))
	get_tree().create_timer(0.2).timeout.connect(play.bind(sfx_coin, 1.0 + 0.03 * float(combo), -8.0))
	Input.vibrate_handheld(25)
	burst(burst_pos, TIERS[tier]["col"])
	sway_t = 0.0
	sway_a = 0.05 + 0.12 * off.length()
	sway_dir = off.normalized() if off.length() > 0.05 else Vector2(0.3, 0.2)
	# le personnage rebondit si le squishy tombe pres de lui
	if c_state == 0 and c_grounded and absf(off.x - cx) < 1.1:
		cvy = 8.5
		c_grounded = false
		c_squash = -0.5
		play(sfx_boing, 1.2)
	friends_hop()
	if first:
		banner = "Nouveau : %s !" % TIERS[tier]["name"]
		banner_t = 2.4
		play(sfx_new)
	drops_done += 1
	cleanup()
	if randf() < 0.6:
		spawn_cloud()
	maybe_trophy()
	save_game()
	new_hover()


func burst(pos: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.mesh = sm
	p.amount = 14
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -6, 0)
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func cleanup() -> void:
	while pieces.size() > KEEP:
		var d: Dictionary = pieces.pop_front()
		d["node"].queue_free()
	for c in clouds.duplicate():
		if c.position.y < top_y - 25.0:
			c.queue_free()
			clouds.erase(c)
	for t in trophies.duplicate():
		if t.position.y < top_y - 25.0:
			t.queue_free()
			trophies.erase(t)
	if is_instance_valid(ground) and top_y > 40.0:
		ground.queue_free()


func spawn_cloud() -> void:
	var c := Node3D.new()
	var s: float = [0.8, 1.0, 1.3][randi() % 3]
	for k in 3:
		part(c, se(Vector3(1.6, 1.0, 1.2) * s, 2.0, 10), Color.WHITE, Vector3((float(k) - 1.0) * 0.9 * s, randf_range(-0.1, 0.2), 0.0), 1.0, 0.85)
	c.position = Vector3(randf_range(-9.0, 9.0), top_y + randf_range(4.0, 12.0), randf_range(-12.0, -4.0))
	add_child(c)
	clouds.append(c)


## Tous les 20 squishies, un tableau avec une de tes photos Lego apparait a cote de la tour.
func maybe_trophy() -> void:
	if lego_images.size() == 0 or count % 20 != 0:
		return
	var k := floori(float(count) / 20.0)
	var tex: Texture2D = lego_images[(k - 1) % lego_images.size()]
	var ts := tex.get_size()
	var asp := ts.x / ts.y
	var ww := minf(2.2 * asp, 3.2)
	var hh := ww / asp
	var t := Node3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(ww + 0.25, hh + 0.25, 0.08)
	part(t, fm, Color("#fffaf0"), Vector3.ZERO, 0.6)
	var qm := QuadMesh.new()
	qm.size = Vector2(ww, hh)
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = Vector3(0, 0, 0.05)
	t.add_child(mi)
	var side := 1.0 if k % 2 == 0 else -1.0
	t.position = Vector3(side * 4.8, top_y, -1.2)
	t.rotation.y = -side * 0.25
	add_child(t)
	trophies.append(t)


# ---------------------------------------------------------------- objets (filet, reacteur, soufflerie)

func obj_index(id: String) -> int:
	for i in OBJETS.size():
		if OBJETS[i]["id"] == id:
			return i
	return -1


func buy_obj(i: int) -> bool:
	var o: Dictionary = OBJETS[i]
	var id: String = o["id"]
	if obj_owned[id] or count < int(o["floor"]) or coins < int(o["price"]):
		return false
	coins -= int(o["price"])
	obj_owned[id] = true
	activate_obj(id)
	play(sfx_buy)
	banner = "%s débloqué !" % o["name"]
	banner_t = 2.4
	save_game()
	return true


func activate_obj(id: String) -> void:
	match id:
		"filet":
			build_net()
		"reacteur":
			build_reactor()
		"souff":
			build_turbine()


func make_net_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 32:
		for y in 32:
			if absi(posmod(x + y, 16) - 8) < 2 or absi(posmod(x - y, 16) - 8) < 2:
				img.set_pixel(x, y, Color("#ffd23f"))
	return ImageTexture.create_from_image(img)


func build_net() -> void:
	net = Node3D.new()
	add_child(net)
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.8, 2.6)
	var m := StandardMaterial3D.new()
	m.albedo_texture = make_net_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(7.0, 2.6, 1.0)
	m.roughness = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	net.add_child(mi)
	var bar := BoxMesh.new()
	bar.size = Vector3(6.9, 0.1, 0.1)
	part(net, bar, Color("#ffd23f"), Vector3(0, 0, 1.3), 0.4)
	part(net, bar, Color("#ffd23f"), Vector3(0, 0, -1.3), 0.4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(net, se(Vector3(0.35, 0.5, 0.35), 5.0, 6), Color("#d62828"), Vector3(sx * 3.4, -0.25, sz * 1.3), 0.4)
	net.position = Vector3(0, net_y(), 0)


func make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#ffb347")
	sm.material = m
	p.mesh = sm
	p.amount = 24
	p.lifetime = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -3, 0)
	p.emitting = false
	return p


func make_flames() -> CPUParticles3D:
	var p := make_sparks()
	p.amount = 18
	p.lifetime = 0.35
	p.direction = Vector3(0, -1, 0)
	p.spread = 18.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3.ZERO
	return p


func build_reactor() -> void:
	reactor = Node3D.new()
	add_child(reactor)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.1
	mast.bottom_radius = 0.1
	mast.height = 60.0
	part(reactor, mast, Color("#33333c"), Vector3(0, -30.0, 0), 0.5)
	part(reactor, se(Vector3(1.7, 0.5, 1.0), 5.0, 16), Color("#d62828"), Vector3(0, 0.25, 0), 0.4)
	add_face(reactor, 0.27, 0.48)
	for s in [-1.0, 1.0]:
		part(reactor, se(Vector3(0.22, 1.1, 0.22), 4.0, 8), Color("#222228"), Vector3(s * 0.72, 1.0, 0), 0.5)
		var tube := CylinderMesh.new()
		tube.top_radius = 0.24
		tube.bottom_radius = 0.24
		tube.height = 1.4
		part(reactor, tube, Color("#ff9d2e"), Vector3(s * 0.36, 1.2, 0), 0.1, 0.3)
		var pv := Node3D.new()
		pv.position = Vector3(s * 0.36, 0.5, 0)
		reactor.add_child(pv)
		var liq := CylinderMesh.new()
		liq.top_radius = 0.18
		liq.bottom_radius = 0.18
		liq.height = 1.3
		var lm := part(pv, liq, Color("#ff7a1a"), Vector3(0, 0.65, 0), 0.3)
		var mat := lm.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color("#ff6a00")
		mat.emission_energy_multiplier = 1.0
		tube_mats.append(mat)
		tube_fill.append(pv)
	part(reactor, se(Vector3(0.9, 0.35, 0.5), 4.0, 8), Color("#ffd23f"), Vector3(0, 1.98, 0), 0.4)
	sparks = make_sparks()
	sparks.position = Vector3(0, 2.1, 0)
	reactor.add_child(sparks)
	reactor.position = Vector3(-3.1, top_y - 0.2, -1.4)


func add_energy() -> void:
	if not obj_owned["reacteur"] or overheat_t > 0.0:
		return
	energy = minf(1.0, energy + 0.125 + 0.02 * float(combo))
	if energy >= 1.0:
		overheat_t = 10.0
		n_overheats += 1
		if is_instance_valid(sparks):
			sparks.emitting = true
		banner = "SURCHAUFFE ! Pièces x2"
		banner_t = 2.6
		play(sfx_over)


func build_turbine() -> void:
	turb = Node3D.new()
	add_child(turb)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.1
	mast.bottom_radius = 0.1
	mast.height = 60.0
	part(turb, mast, Color("#33333c"), Vector3(0, -30.4, 0), 0.5)
	part(turb, se(Vector3(1.7, 0.3, 1.7), 3.0, 14), Color("#4a4a55"), Vector3(0, 0.0, 0), 0.5)
	var rm := TorusMesh.new()
	rm.inner_radius = 0.7
	rm.outer_radius = 0.82
	rm.rings = 28
	rm.ring_segments = 6
	part(turb, rm, Color("#2b2b33"), Vector3(0, 0.25, 0), 0.4)
	turb_spin = Node3D.new()
	turb_spin.position = Vector3(0, 0.25, 0)
	turb.add_child(turb_spin)
	for k in 9:
		var pv := Node3D.new()
		pv.rotation_degrees = Vector3(0, float(k) * 40.0, 0)
		turb_spin.add_child(pv)
		part(pv, se(Vector3(0.5, 0.04, 0.16), 2.4, 6), Color("#6b6b78"), Vector3(0.36, 0, 0), 0.4, 1.0, Vector3(0, 0, 18))
	part(turb_spin, se(Vector3(0.24, 0.2, 0.24), 2.0, 8), Color("#3a3a46"), Vector3.ZERO, 0.4)
	# traits d'air qui montent
	var air := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.45, 0.03)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1, 1, 1, 0.6)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	air.mesh = bm
	air.amount = 30
	air.lifetime = 1.8
	air.direction = Vector3(0, 1, 0)
	air.spread = 4.0
	air.initial_velocity_min = 3.0
	air.initial_velocity_max = 4.0
	air.gravity = Vector3.ZERO
	air.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	air.emission_sphere_radius = 0.6
	air.position = Vector3(0, 0.3, 0)
	turb.add_child(air)
	turb.position = Vector3(ZONE_X, top_y - 3.0, 0)


func update_objects(dt: float) -> void:
	if is_instance_valid(net):
		net.position.y = lerpf(net.position.y, net_y() - 0.5 * net_dip, 1.0 - exp(-6.0 * dt))
	if is_instance_valid(reactor):
		reactor.position.y = lerpf(reactor.position.y, top_y - 0.2, 1.0 - exp(-4.0 * dt))
		if overheat_t > 0.0:
			overheat_t -= dt
			energy = clampf(overheat_t / 10.0, 0.0, 1.0)
			if overheat_t <= 0.0:
				energy = 0.0
				if is_instance_valid(sparks):
					sparks.emitting = false
		var glow := 1.0
		if overheat_t > 0.0:
			glow = 3.5 + 1.2 * sin(t_anim * 12.0)
		for i in tube_fill.size():
			tube_fill[i].scale.y = maxf(energy, 0.03)
			tube_mats[i].emission_energy_multiplier = glow
	if is_instance_valid(turb):
		turb.position.y = lerpf(turb.position.y, turb_y(), 1.0 - exp(-4.0 * dt))
		turb_spin.rotation.y += 14.0 * dt


# ---------------------------------------------------------------- personnage : sauter

func get_move() -> float:
	if test_mode:
		return test_dir
	return Input.get_axis("move_left", "move_right")


func want_jump() -> bool:
	if test_mode:
		var j := test_jump
		test_jump = false
		return j
	return Input.is_action_just_pressed("jump")


func land_hero() -> void:
	cy = top_y
	cvy = 0.0
	c_grounded = true
	c_squash = 0.7
	play(sfx_soft, randf_range(0.9, 1.1), -4.0)


func plouf() -> void:
	c_state = 1
	c_t = 0.9
	hero.visible = false
	burst(Vector3(cx, top_y - 2.0, 0.25), Color.WHITE)
	play(sfx_plouf)
	banner = "Plouf ! On remonte…"
	banner_t = 1.4
	n_falls += 1


func respawn_hero() -> void:
	c_state = 0
	cx = 0.0
	cy = top_y + 3.0
	cvy = 0.0
	c_grounded = false
	hero.visible = true
	play(sfx_pop, 1.3)


func jump_held() -> bool:
	if test_mode:
		return test_hold
	return Input.is_action_pressed("jump")


func net_y() -> float:
	return top_y - 4.5


func turb_y() -> float:
	return top_y - 3.0


func net_bounce() -> void:
	cy = net_y() + 0.02
	cvy = 15.5
	bounce_assist = 1.0
	net_dip = 1.0
	c_squash = 0.5
	n_bounces += 1
	play(sfx_boing, 1.5)
	play(sfx_coin, 1.2, -6.0)
	banner = "Boing !"
	banner_t = 1.0
	burst(Vector3(cx, net_y(), 0.25), Color("#ffd23f"))


func update_hero(dt: float) -> void:
	c_squash = move_toward(c_squash, 0.0, dt * 3.0)
	net_dip = move_toward(net_dip, 0.0, dt * 2.0)
	if c_state == 1:
		c_t -= dt
		if c_t <= 0.0:
			respawn_hero()
		return
	var dir := get_move()
	cx = clampf(cx + (dir * 3.2 + wind_vel()) * dt, -6.0, 6.0)
	if bounce_assist > 0.0:
		bounce_assist -= dt
		cx = lerpf(cx, clampf(cx, -1.0, 1.0), 1.0 - exp(-3.0 * dt))
	var on_tower := absf(cx) < TOWER_R
	var thrusting := false
	if c_grounded:
		fuel = minf(1.0, fuel + dt * 2.0)
		if not on_tower:
			c_grounded = false
		else:
			cy = top_y
			cvy = 0.0
			if want_jump():
				cvy = 7.6
				c_grounded = false
				c_squash = -0.5
				play(sfx_boing, randf_range(0.9, 1.1))
	if not c_grounded:
		var prev := cy
		cvy -= 22.0 * dt
		# jetpack du pilote : garder le saut appuye
		if hero_kind == 2 and jump_held() and fuel > 0.0 and cvy < 3.0:
			cvy = minf(cvy + 46.0 * dt, 3.2)
			fuel = maxf(0.0, fuel - dt * 0.9)
			thrusting = true
		# soufflerie : un courant d'air qui fait flotter
		if obj_owned["souff"] and absf(cx - ZONE_X) < 0.85 and cy > turb_y() and cy < top_y + 3.6:
			var target := 2.8 if cy < top_y + 2.4 else 0.0
			cvy = lerpf(cvy, target, 1.0 - exp(-5.0 * dt))
			updraft_frames += 1
		cy += cvy * dt
		if on_tower and cvy <= 0.0 and prev >= top_y - 0.12 and cy <= top_y:
			land_hero()
		elif on_tower and cy < top_y and cy > top_y - 1.3:
			land_hero()
		elif obj_owned["filet"] and cvy < 0.0 and cy <= net_y() and absf(cx) < 3.3 and prev > net_y() - 1.0:
			net_bounce()
		elif cy < top_y - 6.0:
			plouf()
	if is_instance_valid(jet_parts):
		jet_parts.emitting = thrusting
	if thrusting:
		jet_frames += 1
		jet_t -= dt
		if jet_t <= 0.0:
			jet_t = 0.18
			play(sfx_jet, randf_range(0.95, 1.1), -9.0)
	c_lean = lerpf(c_lean, -dir * 0.15, 1.0 - exp(-10.0 * dt))
	var sx := 1.0 + 0.2 * c_squash
	var sy := 1.0 - 0.25 * c_squash
	if not c_grounded:
		sy *= 1.0 + clampf(cvy / 40.0, -0.1, 0.15)
	hero.scale = Vector3(sx, sy, sx)
	hero.rotation.z = c_lean
	hero.position = Vector3(cx, cy, 0.25)


# ---------------------------------------------------------------- entrees

func in_circle(p: Vector2, c: Vector2, r: float) -> bool:
	return p.distance_to(c) <= r


func panel_rect() -> Rect2:
	var s := vsize()
	return Rect2(s.x * 0.5 - 470.0, s.y * 0.5 - 300.0, 940.0, 600.0)


func shop_btn_rect() -> Rect2:
	return Rect2(20, 100, 180, 58)


func hero_card(i: int) -> Rect2:
	var p := panel_rect()
	return Rect2(p.position.x + 30.0 + float(i) * 305.0, p.position.y + 70.0, 285.0, 100.0)


func obj_cell(i: int) -> Rect2:
	var p := panel_rect()
	return Rect2(p.position.x + 30.0 + float(i) * 305.0, p.position.y + 185.0, 285.0, 70.0)


func friend_cell(i: int) -> Rect2:
	var p := panel_rect()
	return Rect2(p.position.x + 30.0 + float(i % 2) * 460.0, p.position.y + 270.0 + float(i / 2) * 70.0, 430.0, 62.0)


func close_rect() -> Rect2:
	var p := panel_rect()
	return Rect2(p.end.x - 70.0, p.position.y + 10.0, 56.0, 56.0)


func shop_tap(pos: Vector2) -> void:
	if close_rect().has_point(pos) or not panel_rect().has_point(pos):
		shop_open = false
		chosen = true
		play(sfx_click)
		save_game()
		return
	for i in 3:
		if hero_card(i).has_point(pos):
			if i == 2 and not pilot_owned:
				if coins >= PILOT_PRICE:
					coins -= PILOT_PRICE
					pilot_owned = true
					play(sfx_buy)
					shop_msg = ""
				else:
					shop_msg = "Pas assez de pièces"
					shop_msg_t = 2.0
					return
			set_hero(i)
			chosen = true
			play(sfx_click)
			save_game()
			return
	for i in OBJETS.size():
		if obj_cell(i).has_point(pos):
			var o: Dictionary = OBJETS[i]
			if obj_owned[o["id"]]:
				return
			if count < int(o["floor"]):
				shop_msg = "%s arrive à l'étage %d" % [o["name"], int(o["floor"]) + 1]
			elif coins < int(o["price"]):
				shop_msg = "Pas assez de pièces"
			else:
				buy_obj(i)
				shop_msg = ""
			shop_msg_t = 2.0
			return
	for i in FRIEND_NAMES.size():
		if friend_cell(i).has_point(pos):
			if owned[i]:
				return
			if not friend_available(i):
				shop_msg = "%s arrive à l'étage %d" % [FRIEND_NAMES[i], i * PER_TIER + 1]
			elif coins < int(FRIEND_PRICES[i]):
				shop_msg = "Pas assez de pièces"
			else:
				buy_friend(i)
				shop_msg = ""
			shop_msg_t = 2.0
			return


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if shop_open:
			if event.pressed:
				shop_tap(pos)
			return
		if event.pressed:
			if shop_btn_rect().has_point(pos):
				shop_open = true
				play(sfx_click)
				return
			if in_circle(pos, pos_l, R_ARROW) or in_circle(pos, pos_r, R_ARROW) or in_circle(pos, pos_j, R_JUMP):
				return
			if touch_idx == -1:
				touch_idx = event.index
		elif event.index == touch_idx:
			touch_idx = -1
			drop()
	elif event is InputEventScreenDrag and event.index == touch_idx and state == 0 and not shop_open:
		var k := 3.0 / vsize().y
		ox += event.relative.x * k
		oz += event.relative.y * k
		clamp_offset()


func clamp_offset() -> void:
	var v := Vector2(ox, oz)
	if v.length() > R_MAX:
		v = v.normalized() * R_MAX
		ox = v.x
		oz = v.y


func sky(h: float) -> Color:
	var c0 := Color("#ffd6e0")
	var c1 := Color("#c7b8ff")
	var c2 := Color("#1b1a3a")
	if h < 0.5:
		return c0.lerp(c1, h * 2.0)
	return c1.lerp(c2, (h - 0.5) * 2.0)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	t_anim += delta
	if banner_t > 0.0:
		banner_t -= delta
	if shop_msg_t > 0.0:
		shop_msg_t -= delta
	for b in btns:
		b.visible = not shop_open
	# camera
	cam_y = lerpf(cam_y, top_y + 1.3, 1.0 - exp(-4.0 * delta))
	cam.position = Vector3(sin(t_anim * 0.35) * 0.7, cam_y + 2.5, 8.4)
	cam.look_at(Vector3(0, cam_y - 0.1, 0), Vector3.UP)
	# ciel
	var h01 := clampf(cam_y / 70.0, 0.0, 1.0)
	var c_top := sky(clampf(h01 + 0.18, 0.0, 1.0))
	var c_hor := sky(h01)
	sky_mat.sky_top_color = c_top
	sky_mat.sky_horizon_color = c_hor
	sky_mat.ground_horizon_color = c_hor
	sky_mat.ground_bottom_color = c_hor
	star_mat.albedo_color.a = clampf((h01 - 0.4) * 2.0, 0.0, 1.0)
	# placement du squishy
	if state == 0 and is_instance_valid(hover):
		if not shop_open:
			ox += Input.get_axis("ui_left", "ui_right") * 2.0 * delta
			oz += Input.get_axis("ui_up", "ui_down") * 2.0 * delta
			clamp_offset()
			if Input.is_action_just_pressed("ui_accept"):
				drop()
		hover.position = Vector3(ox, top_y + 3.0 + sin(t_anim * 2.5) * 0.12, oz)
		ring.position = Vector3(ox, top_y + 0.05, oz)
		ring.visible = true
	else:
		ring.visible = false
	update_fan(delta)
	update_objects(delta)
	update_hero(delta)
	update_friends(delta)
	update_hearts(delta)
	# la tour se balance apres une pose et quand le vent souffle
	sway_t += delta
	var amp := sway_a * exp(-sway_t * 2.2) * sin(sway_t * 8.0)
	var n := pieces.size()
	for k in mini(14, n):
		var node: Node3D = pieces[n - 1 - k]["node"]
		var f := exp(-float(k) * 0.35) if k < 10 else 0.0
		var lean := wind_dir * wind * 0.05 * f + sin(t_anim * 9.0) * wind * 0.012 * f
		node.rotation.z = -amp * f * sway_dir.x - lean
		node.rotation.x = amp * f * sway_dir.y
	hud.queue_redraw()
	if test_mode:
		run_test(delta)


func run_test(delta: float) -> void:
	test_t += delta
	test_dir = sin(test_t * 0.9) * 1.0
	if randf() < delta * 1.2:
		test_jump = true
	test_hold = fmod(test_t, 1.5) < 0.9
	if test_t > 15.0 and hero_kind != 2:
		set_hero(2)
	if state == 0 and not shop_open and test_t > 0.2:
		if fmod(test_t, 0.5) < delta * 2.0:
			ox = randf_range(-0.9, 0.9)
			oz = randf_range(-0.9, 0.9)
			drop()
	if test_t > 400.0 or (count >= 130 and n_gusts >= 1 and n_hearts >= 3 and n_bounces >= 1 and n_overheats >= 1 and jet_frames > 5 and updraft_frames > 5):
		print("TEST OK count=%d top=%.2f coins=%d pieces=%d gusts=%d hearts=%d got=%d falls=%d bounces=%d overheats=%d jet=%d updraft=%d friends=%d hero=%d" % [count, top_y, coins, pieces.size(), n_gusts, n_hearts, n_hearts_got, n_falls, n_bounces, n_overheats, jet_frames, updraft_frames, friend_objs.filter(func(f): return f != null).size(), hero_kind])
		get_tree().quit()


# ---------------------------------------------------------------- interface

func txt(c: Control, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	c.draw_string_outline(f, pos, s, align, width, size, 8, Color(0.2, 0.1, 0.3, col.a * 0.6))
	c.draw_string(f, pos, s, align, width, size, col)


func rbox(c: Control, r: Rect2, col: Color, rad := 18, border := Color(1, 1, 1, 0.0)) -> void:
	sbox.bg_color = col
	sbox.set_corner_radius_all(rad)
	sbox.border_color = border
	sbox.set_border_width_all(3 if border.a > 0.0 else 0)
	c.draw_style_box(sbox, r)


func draw_heart_icon(c: Control, p: Vector2, s: float, col: Color) -> void:
	c.draw_circle(p + Vector2(-0.5, -0.3) * s, 0.55 * s, col)
	c.draw_circle(p + Vector2(0.5, -0.3) * s, 0.55 * s, col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-1.0, 0.0) * s, p + Vector2(1.0, 0.0) * s, p + Vector2(0.0, 1.1) * s]), col)


func draw_btn(c: Control, p: Vector2, r: float, col: Color, pressed: bool) -> void:
	var a := 0.85 if pressed else 0.5
	c.draw_circle(p, r, Color(col.r, col.g, col.b, a))
	c.draw_arc(p, r, 0, TAU, 40, Color(1, 1, 1, 0.8), 4.0)


func draw_hud(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	c.draw_circle(Vector2(40, 40), 16, Color("#ffd23f"))
	c.draw_circle(Vector2(40, 40), 10, Color("#ffeb85"))
	txt(c, Vector2(66, 52), str(coins), 36, Color.WHITE)
	var tier := tier_of(count)
	txt(c, Vector2(0, 52), "Étage %d  ·  %s" % [count + 1, TIERS[tier]["name"]], 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	var found := 0
	for k in TIERS.size():
		var col: Color = TIERS[k]["col"]
		if discovered[k]:
			found += 1
		else:
			col = Color(1, 1, 1, 0.25)
		c.draw_circle(Vector2(w - 30.0 - float(k) * 24.0, 90), 9, col)
	txt(c, Vector2(w - 300.0, 60), "Découverts : %d/%d" % [found, TIERS.size()], 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 285.0)
	# bouton amis + compte a rebours des coeurs
	var sb := shop_btn_rect()
	rbox(c, sb, Color(1, 0.55, 0.75, 0.9), 22, Color(1, 1, 1, 0.9))
	txt(c, Vector2(sb.position.x, sb.position.y + 40.0), "Amis", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sb.size.x)
	draw_heart_icon(c, Vector2(34, 190), 14.0, Color("#ff5c8a"))
	var left := int(maxf(event_timer, 0.0))
	var heart_txt := "Pluie de cœurs !  %d s" % int(event_t) if event_t > 0.0 else "dans %d:%02d" % [left / 60, left % 60]
	txt(c, Vector2(60, 200), heart_txt, 26, Color.WHITE)
	if combo >= 2 and t_anim - last_drop < 2.5:
		txt(c, Vector2(0, 130), "Combo x%d" % (combo + 1), 36, Color(1, 0.9, 0.4, clampf((2.5 - (t_anim - last_drop)), 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, w)
	if obj_owned["reacteur"]:
		var br := Rect2(w * 0.5 - 150.0, 68.0, 300.0, 16.0)
		rbox(c, br, Color(0, 0, 0, 0.35), 8)
		var fr := Rect2(br.position, Vector2(br.size.x * clampf(energy, 0.0, 1.0), br.size.y))
		if fr.size.x > 4.0:
			rbox(c, fr, Color("#ff8a1e") if overheat_t <= 0.0 else Color("#ffd23f"), 8)
		if overheat_t > 0.0:
			txt(c, Vector2(0, 100.0), "SURCHAUFFE x2  %d s" % int(ceilf(overheat_t)), 24, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, w)
	if hero_kind == 2 and not shop_open:
		var fb := Rect2(w * 0.5 - 100.0, hgt - 95.0, 200.0, 14.0)
		rbox(c, fb, Color(0, 0, 0, 0.35), 7)
		var ff := Rect2(fb.position, Vector2(fb.size.x * clampf(fuel, 0.0, 1.0), fb.size.y))
		if ff.size.x > 4.0:
			rbox(c, ff, Color("#ff8a1e"), 7)
		txt(c, Vector2(0, hgt - 100.0), "Jetpack : garde SAUT appuyé", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	if banner_t > 0.0:
		txt(c, Vector2(0, hgt * 0.3), banner, 54, Color(1, 1, 1, clampf(banner_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, w)
	if drops_done < 5 and state == 0 and not shop_open:
		txt(c, Vector2(0, hgt - 50.0), "Glisse pour placer  ·  Lâche pour poser", 30, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, w)
	if not shop_open:
		draw_btn(c, pos_l, R_ARROW, Color.WHITE, Input.is_action_pressed("move_left"))
		c.draw_colored_polygon(PackedVector2Array([pos_l + Vector2(-26, 0), pos_l + Vector2(18, -30), pos_l + Vector2(18, 30)]), Color(0.3, 0.2, 0.4, 0.8))
		draw_btn(c, pos_r, R_ARROW, Color.WHITE, Input.is_action_pressed("move_right"))
		c.draw_colored_polygon(PackedVector2Array([pos_r + Vector2(26, 0), pos_r + Vector2(-18, -30), pos_r + Vector2(-18, 30)]), Color(0.3, 0.2, 0.4, 0.8))
		draw_btn(c, pos_j, R_JUMP, Color("#ff8a1e"), Input.is_action_pressed("jump"))
		var f := ThemeDB.fallback_font
		var tw := f.get_string_size("SAUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		txt(c, pos_j + Vector2(-tw / 2.0, 12), "SAUT", 36, Color.WHITE)
	else:
		draw_shop(c)


func draw_shop(c: Control) -> void:
	var w := c.size.x
	c.draw_rect(Rect2(0, 0, w, c.size.y), Color(0.15, 0.08, 0.25, 0.55))
	var p := panel_rect()
	rbox(c, p, Color("#fff4fa"), 30, Color("#ff8fc0"))
	txt(c, Vector2(p.position.x, p.position.y + 52.0), "Mon personnage, mes objets et mes amis", 32, Color("#5a2a6e"), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
	var cl := close_rect()
	rbox(c, cl, Color("#ff8fc0"), 16)
	txt(c, Vector2(cl.position.x, cl.position.y + 42.0), "X", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, cl.size.x)
	var names := ["Le pain", "Chat-banane", "Pilote jetpack"]
	var cols := [Color("#f2c27b"), Color("#ffe135"), Color("#8a8a99")]
	for i in 3:
		var r := hero_card(i)
		var locked := i == 2 and not pilot_owned
		var sel := chosen and hero_kind == i
		rbox(c, r, Color(cols[i].r, cols[i].g, cols[i].b, 0.55), 20, Color("#5a2a6e") if sel else Color(1, 1, 1, 0.0))
		c.draw_circle(r.position + Vector2(45, 50), 28, cols[i])
		if i == 1:
			c.draw_circle(r.position + Vector2(45, 38), 16, Color("#ffa94d"))
		if i == 2:
			c.draw_rect(Rect2(r.position + Vector2(30, 38), Vector2(30, 10)), Color("#7a1f2b"))
		txt(c, Vector2(r.position.x + 85.0, r.position.y + 45.0), names[i], 24, Color("#5a2a6e"))
		var st := "Choisi" if sel else "Toucher pour choisir"
		if locked:
			st = "%d pièces" % PILOT_PRICE
		txt(c, Vector2(r.position.x + 85.0, r.position.y + 76.0), st, 19, Color("#8a5aa0"))
	for i in OBJETS.size():
		var r := obj_cell(i)
		var o: Dictionary = OBJETS[i]
		var bg := Color("#ffe9b8")
		var st := "%d pièces" % int(o["price"])
		if obj_owned[o["id"]]:
			st = "Débloqué !"
			bg = Color("#d9f7d9")
		elif count < int(o["floor"]):
			st = "Étage %d" % (int(o["floor"]) + 1)
			bg = Color("#e4e0ea")
		rbox(c, r, bg, 18)
		txt(c, Vector2(r.position.x + 16.0, r.position.y + 30.0), String(o["name"]), 22, Color("#5a2a6e"))
		txt(c, Vector2(r.position.x + 16.0, r.position.y + 56.0), st, 19, Color("#8a5aa0"))
	for i in FRIEND_NAMES.size():
		var r := friend_cell(i)
		var price: int = FRIEND_PRICES[i]
		var status := ""
		var bg := Color("#ffe6f1")
		if owned[i]:
			status = "Ami !"
			bg = Color("#d9f7d9")
		elif not friend_available(i):
			status = "Étage %d" % (i * PER_TIER + 1)
			bg = Color("#e4e0ea")
		else:
			status = "%d pièces" % price
		rbox(c, r, bg, 18)
		txt(c, Vector2(r.position.x + 24.0, r.position.y + 28.0), FRIEND_NAMES[i], 25, Color("#5a2a6e"))
		txt(c, Vector2(r.position.x + 24.0, r.position.y + 52.0), status, 19, Color("#8a5aa0"))
	if shop_msg_t > 0.0:
		txt(c, Vector2(p.position.x, p.end.y - 20.0), shop_msg, 28, Color("#d6336c"), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
	else:
		txt(c, Vector2(p.position.x, p.end.y - 20.0), "Un nouvel ami arrive à chaque palier de la tour", 24, Color("#8a5aa0"), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)


class HUD extends Control:
	var g: Node
	func _draw() -> void:
		if g:
			g.draw_hud(self)
