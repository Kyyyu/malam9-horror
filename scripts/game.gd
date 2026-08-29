extends Node3D

class_name GameScreen

signal ended(is_win: bool)
signal exit_requested

const TILE := 2.0
const WALL_H := 3.2
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const MAP := [
	"#################",
	"#P......#.......#",
	"#.#####.#.#####.#",
	"#.#.......#..K..#",
	"#.#...#####.###.#",
	"#.#...#.#.....#.#",
	"#.#.###.#.###.#.#",
	"#.#.#...#K..#.#.#",
	"#.#.#.#.#####.#.#",
	"#.#.#...#...#K#.#",
	"#.###.###...###.#",
	"#.............#.#",
	"##########E.###.#",
]

const MAP2 := [
	"#################",
	"#.......#......P#",
	"#.#####.#.#####.#",
	"#..K..#.......#.#",
	"#.###.#####...#.#",
	"#.#.....#.#...#.#",
	"#.#.###.#.###.#.#",
	"#.#.#..K#...#.#.#",
	"#.#.#####.#.#.#.#",
	"#.#K#...#...#.#.#",
	"#.###...###.###.#",
	"#.#.............#",
	"#.###.E##########",
]

const KEY_CELLS_L1 := [[13, 3], [9, 7], [13, 9]]
const KEY_CELLS_L2 := [[3, 3], [7, 7], [3, 9]]

const LAMP_CELLS := [[4, 1], [3, 3], [5, 5], [10, 5], [11, 7], [5, 9], [3, 12], [9, 3], [7, 1], [13, 7], [12, 5], [2, 11], [9, 1], [14, 1], [1, 3], [6, 3], [1, 5], [6, 5], [1, 7], [8, 7], [1, 9], [14, 9], [1, 11], [4, 11], [7, 11], [10, 11]]
const WHISPER_CELLS := [[8, 3], [11, 5], [3, 7], [2, 9], [6, 11]]

var level := 1
var player: PlayerController = null
var camera: Camera3D = null
var ghost: GhostController = null
var ghost_name := "HANTU"
var music: AudioStreamPlayer = null
var keys_total := 3
var keys_found := 0
var all_keys := []
var exit_area: Area3D = null
var door_light: OmniLight3D = null
var running := true
var jumped := false

var objective: Label = null
var key_label: Label = null
var hint: Label = null
var key_hint: Label = null
var vignette: TextureRect = null
var joystick: JoystickControl = null
var stamina_bar: ProgressBar = null
var minimap: Control = null
var pause_overlay: CanvasLayer = null
var scare_overlay: CanvasLayer = null
var ghost_label: Label = null
var _vib_cooldown := 0.0
var _minimap_t := 0.0

signal restart_requested

var ambient: AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var whisper: AudioStreamPlayer
var _step_timer := 0.0
var _loaded := false
var _near_key_t := 0.0
var _key_pinged := {}

var _mats := {}

func _ready():
	_build_environment()
	_build_world()
	_build_player()
	_build_ghost()
	_build_keys()
	_build_exit()
	_build_hud()
	_setup_audio()

	ghost.danger_changed.connect(_on_danger)
	ghost.caught.connect(_on_caught)

	var delay := 6.5 if level >= 2 else 8.0
	await get_tree().create_timer(delay).timeout
	if not running:
		return
	ghost.activate()
	_play_once("res://audio/door_slam.wav", -8.0)
	_play_once("res://audio/whisper.wav", -10.0)

func _map() -> Array:
	return MAP if level <= 1 else MAP2

func _key_cells() -> Array:
	return KEY_CELLS_L1 if level <= 1 else KEY_CELLS_L2

func _exit_cell() -> Vector2i:
	return Vector2i(10, 12) if level <= 1 else Vector2i(6, 12)

func _spawn_cell() -> Vector2i:
	return Vector2i(1, 1) if level <= 1 else Vector2i(15, 1)

func _is_on_android() -> bool:
	return DisplayServer.get_name() == "Android"

func _get_mat(key: String, color: Color, emissive := Color(0, 0, 0, 1), e_energy := 1.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = emissive.a > 0.0
		m.emission = emissive
		m.emission_energy_multiplier = e_energy
		_mats[key] = m
	return _mats[key]

func _procedural_mat(key: String, color: Color, brick := false, planks := false) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key] as ShaderMaterial
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 u_tint : source_color = vec4(0.85, 0.8, 0.7, 1.0);
uniform bool u_brick = false;
uniform bool u_planks = false;
uniform float u_bright : hint_range(0.0, 2.0) = 1.0;
uniform float u_roughness : hint_range(0.0, 1.0) = 0.95;

varying vec3 v_wp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec3 nrm = normalize(NORMAL);
	vec2 uv;
	if (abs(nrm.x) > abs(nrm.y) && abs(nrm.x) > abs(nrm.z)) uv = v_wp.zy;
	else if (abs(nrm.y) > abs(nrm.z)) uv = v_wp.xz;
	else uv = v_wp.xy;

	float grunge = vnoise(uv * 0.18);
	float fine = vnoise(uv * 1.4);
	vec3 col = u_tint.rgb;
	col *= mix(0.84, 1.12, grunge);
	col *= mix(0.95, 1.05, fine) * u_bright;
	col *= 0.96 + 0.08 * hash(floor(v_wp.xz * 3.0 + v_wp.y * 13.0));

	if (u_planks) {
		float px = fract(uv.x * 2.4);
		col *= 0.86 + 0.22 * hash(vec2(floor(uv.x * 2.4), 0.0));
		col *= smoothstep(0.0, 0.02, min(px, 1.0 - px));
		float py = fract(uv.y);
		col *= 0.85 + 0.15 * smoothstep(0.0, 0.02, min(py, 1.0 - py));
	}
	if (u_brick) {
		vec2 br = uv * vec2(1.7, 5.0);
		float row = floor(br.y);
		br.x += 0.5 * mod(row, 2.0);
		vec2 bb = fract(br);
		float mm = min(bb.x, 1.0 - bb.x);
		float mh = min(bb.y, 1.0 - bb.y);
		float mortar = (1.0 - smoothstep(0.0, 0.05, mm)) * 0.6 + (1.0 - smoothstep(0.0, 0.09, mh));
		mortar = clamp(mortar, 0.0, 1.0);
		col *= mix(1.0, 0.42, mortar);
		col *= 0.9 + 0.2 * hash(vec2(floor(br.x + step(0.5, mod(row, 2.0))), row));
	}
	ALBEDO = col;
	ROUGHNESS = u_roughness;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("u_tint", color)
	m.set_shader_parameter("u_brick", brick)
	m.set_shader_parameter("u_planks", planks)
	m.set_shader_parameter("u_bright", 1.0)
	m.set_shader_parameter("u_roughness", 0.95)
	_mats[key] = m
	return m

func _build_environment():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.012, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.21, 0.3)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.05)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-45, -35, 0)
	moon.light_energy = 0.42
	moon.light_color = Color(0.42, 0.45, 0.7)
	add_child(moon)

func _add_static_box(path, size: Vector3, mat: Material) -> StaticBody3D:
	var r := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	r.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	r.add_child(cs)
	add_child(r)
	r.global_position = path
	return r

func _build_world():
	var floor_mat := _procedural_mat("floor_p", Color(0.44, 0.37, 0.3), false, true)
	_add_static_box(Vector3(17.0, -0.25, 13.0), Vector3(34.0, 0.5, 26.0), floor_mat)

	var wall_mats := [
		_procedural_mat("wall_plaster", Color(0.52, 0.46, 0.43), false, false),
		_procedural_mat("wall_brick", Color(0.48, 0.33, 0.26), true, false),
	]
	var wall_i := 0
	var open_cells: Array[Vector2i] = []

	for row in range(_map().size()):
		var line: String = _map()[row]
		for col in range(line.length()):
			var ch: String = line[col]
			if ch == '#':
				var p := Vector3(col * TILE + 1.0, WALL_H / 2.0, row * TILE + 1.0)
				_add_static_box(p, Vector3(TILE, WALL_H, TILE), wall_mats[wall_i % 2])
				wall_i += 1
			else:
				open_cells.append(Vector2i(col, row))

	_build_lamps()
	_build_furniture(open_cells)
	_build_whispers()
	_build_ceiling()

func _build_ceiling():
	var ceil_mat := _procedural_mat("ceiling_p", Color(0.42, 0.4, 0.4), false, false)
	_add_static_box(Vector3(17.0, WALL_H + 0.18, 13.0), Vector3(36.0, 0.35, 28.0), ceil_mat)
	var beam_mat := _get_mat("beam", Color(0.14, 0.11, 0.1), Color(0, 0, 0), 1.0)
	for bx in range(1, 15):
		_add_static_box(Vector3(bx * TILE + 1.0, WALL_H - 0.2, 13.0), Vector3(0.18, 0.35, 26.0), beam_mat)
	var dust := CPUParticles3D.new()
	dust.amount = 120
	dust.lifetime = 7.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(17, 1.3, 13)
	dust.position = Vector3(17.0, 1.5, 13.0)
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 60.0
	dust.gravity = Vector3(0.02, -0.02, 0.015)
	dust.initial_velocity_min = 0.04
	dust.initial_velocity_max = 0.18
	dust.scale_amount_min = 0.012
	dust.scale_amount_max = 0.04
	dust.color = Color(1, 1, 1, 0.5)
	add_child(dust)

func _build_lamps():
	for lam in LAMP_CELLS:
		var cell := Vector2i(lam[0], lam[1])
		if _map()[cell.y][cell.x] == '#':
			continue
		var light := OmniLight3D.new()
		light.light_energy = 4.2
		light.light_color = Color(1.0, 0.82, 0.55)
		light.omni_range = 12.0
		light.position = Vector3(cell.x * TILE + 1.0, 2.6, cell.y * TILE + 1.0)
		add_child(light)
		var lamp := Lamp.new()
		lamp.light = light
		lamp.base = light.light_energy
		add_child(lamp)
		var iron_mat := _get_mat("lamp_iron", Color(0.12, 0.11, 0.12), Color(0, 0, 0), 1.0)
		var fixture := _add_static_box(Vector3(cell.x * TILE + 1.0, 2.52, cell.y * TILE + 1.0), Vector3(0.6, 0.12, 0.6), iron_mat)
		var bulb_mat := _get_mat("lamp_bulb", Color(0.9, 0.75, 0.5), Color(1.0, 0.8, 0.5, 1), 2.0)
		var bulb := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.14
		bm.height = 0.28
		bulb.mesh = bm
		bulb.material_override = bulb_mat
		bulb.position = Vector3(cell.x * TILE + 1.0, 2.44, cell.y * TILE + 1.0)
		add_child(bulb)

func _build_furniture(open_cells: Array[Vector2i]):
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var candidates: Array[Vector2i] = []
	for c in open_cells:
		var nc := _wall_neighbors(c, open_cells)
		if nc >= 2 and not _is_special(c) and not _is_adjacent_special(c):
			candidates.append(c)
	candidates.shuffle()
	var count := mini(candidates.size(), 12)
	var box_mat := _get_mat("box", Color(0.13, 0.1, 0.09), Color(0, 0, 0), 1.0)
	var wood_mat := _get_mat("wood", Color(0.22, 0.16, 0.1), Color(0, 0, 0), 1.0)
	var barrel_mat := _get_mat("barrel", Color(0.3, 0.22, 0.14), Color(0, 0, 0), 1.0)
	for i in range(count):
		var c := candidates[i]
		var which := i % 4
		var push := _wall_push_dir(c, open_cells)
		if which == 3:
			var r := 0.32
			var h := 0.72
			var pos := Vector3(c.x * TILE + 1.0 + push.x * (TILE * 0.5 - r), h * 0.5, c.y * TILE + 1.0 + push.z * (TILE * 0.5 - r))
			_add_static_cyl(pos, r, h, barrel_mat)
			continue
		var size: Vector3
		var mat: Material
		match which:
			0:
				size = Vector3(0.8, 0.8, 0.8)
				mat = box_mat
			1:
				size = Vector3(1.2, 1.0, 0.6)
				mat = wood_mat
			_:
				size = Vector3(0.6, 1.6, 0.6)
				mat = box_mat
		var pos := Vector3(c.x * TILE + 1.0 + push.x * (TILE * 0.5 - size.x * 0.5), size.y * 0.5, c.y * TILE + 1.0 + push.z * (TILE * 0.5 - size.z * 0.5))
		_add_static_box(pos, size, mat)

func _add_static_cyl(path: Vector3, radius: float, height: float, mat: Material) -> StaticBody3D:
	var r := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mi.mesh = mesh
	mi.material_override = mat
	r.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	r.add_child(cs)
	add_child(r)
	r.global_position = path
	return r

func _wall_push_dir(c: Vector2i, open_cells: Array[Vector2i]) -> Vector3:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not open_cells.has(c + off):
			return Vector3(off.x, 0, off.y)
	return Vector3.ZERO

func _is_special(c: Vector2i) -> bool:
	if _map()[c.y][c.x] in ['P', 'K', 'E']:
		return true
	for l in LAMP_CELLS:
		if Vector2i(l[0], l[1]) == c:
			return true
	for k in _key_cells():
		if Vector2i(k[0], k[1]) == c:
			return true
	return false

func _is_adjacent_special(c: Vector2i) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + off
		if n.x >= 0 and n.y >= 0 and n.y < _map().size() and n.x < _map()[n.y].length():
			if _is_special(n):
				return true
	return false

func _wall_neighbors(c: Vector2i, open_cells: Array[Vector2i]) -> int:
	var count := 0
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if open_cells.has(c + off):
			continue
		count += 1
	return count

func _cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE + 1.0, 0.0, c.y * TILE + 1.0)

func _cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE)), int(floor(pos.z / TILE)))

func _is_floor_cell(c: Vector2i) -> bool:
	if c.y < 0 or c.y >= _map().size() or c.x < 0 or c.x >= _map()[c.y].length():
		return false
	return _map()[c.y][c.x] != '#'

func _nearest_floor(c: Vector2i) -> Vector2i:
	if _is_floor_cell(c):
		return c
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := Vector2i(c.x + dx, c.y + dy)
				if _is_floor_cell(n):
					return n
	return c

func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var s := _nearest_floor(_cell_of(from))
	var g := _nearest_floor(_cell_of(to))
	if s == g:
		return PackedVector3Array()
	var prev := {}
	var visited := {s: true}
	var queue: Array[Vector2i] = [s]
	var guard := 0
	while queue.size() > 0 and guard < 1200:
		guard += 1
		var c: Vector2i = queue.pop_front()
		if c == g:
			break
		for off in DIRS4:
			var n: Vector2i = c + off
			if not _is_floor_cell(n) or visited.has(n):
				continue
			visited[n] = true
			prev[n] = c
			queue.append(n)
	if not (prev.has(g) or s == g):
		return PackedVector3Array()
	var back: Array[Vector2i] = []
	var cur := g
	while true:
		back.append(cur)
		if cur == s:
			break
		cur = prev[cur]
	var path := PackedVector3Array()
	for i in range(back.size() - 1, -1, -1):
		path.append(_cell_center(back[i]))
	if path.size() > 1:
		path.remove_at(0)
	return path

func random_floor_goal(near: Vector3, radius: float) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for tries in range(10):
		var c := _cell_of(near + Vector3(rng.randf_range(-radius, radius), 0.0, rng.randf_range(-radius, radius)))
		if _is_floor_cell(c):
			return _cell_center(c)
	return _cell_center(_nearest_floor(_cell_of(near)))

func _build_whispers():
	for cell in WHISPER_CELLS:
		var v := Vector2i(cell[0], cell[1])
		if level >= 2 or _map()[v.y][v.x] == '#':
			continue
		var a := Area3D.new()
		a.collision_mask = 4
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(2.5, 2.5, 2.5)
		cs.shape = s
		a.add_child(cs)
		a.position = Vector3(v.x * TILE + 1.0, 1.2, v.y * TILE + 1.0)
		a.body_entered.connect(_on_whisper_trigger)
		_whisper_areas.append(a)
		add_child(a)

var _whisper_areas := []

func _on_whisper_trigger(body: Node3D):
	if body == player and not _whisper_active:
		_whisper_active = true
		_play_once("res://audio/whisper.wav", -7.0, randf_range(0.9, 1.2))
		await get_tree().create_timer(2.0).timeout
		_whisper_active = false

var _whisper_active := false

func _build_player():
	player = PlayerController.new()
	player.name = "Player"
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	player.add_child(cs)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 78.0
	camera.position.y = 1.62
	player.add_child(camera)

	var fl := SpotLight3D.new()
	fl.name = "Flashlight"
	fl.spot_range = 32.0
	fl.spot_angle = deg_to_rad(56.0)
	fl.spot_attenuation = 0.85
	fl.light_energy = 16.0
	fl.light_color = Color(0.95, 0.9, 0.75)
	fl.shadow_enabled = true
	fl.position.y = -0.1
	camera.add_child(fl)

	var fill := OmniLight3D.new()
	fill.light_energy = 0.9
	fill.light_color = Color(0.5, 0.5, 0.62)
	fill.omni_range = 7.0
	fill.position = Vector3(0, 2.1, 0)
	fill.shadow_enabled = false
	player.add_child(fill)

	add_child(player)
	player.collision_layer = 4
	player.collision_mask = 1
	var sp := _spawn_cell()
	player.global_position = Vector3(sp.x * TILE + 1.0, 0.2, sp.y * TILE + 1.0)

func _build_ghost():
	ghost_name = "GUFRON" if level >= 2 else "BAHLIL"
	var pal := {
		"cloth": Color(0.85, 0.83, 0.79) if level <= 1 else Color(0.2, 0.18, 0.22),
		"face": Color(0.85, 0.8, 0.75) if level <= 1 else Color(0.58, 0.48, 0.5),
		"emission": Color(0.35, 0.45, 0.7, 1) if level <= 1 else Color(0.95, 0.25, 0.1, 1.6),
		"eye": Color(1, 0.02, 0.02) if level <= 1 else Color(1, 0.5, 0.1),
		"aura": Color(1.0, 0.1, 0.08) if level <= 1 else Color(0.55, 0.1, 1.0),
	}
	ghost = GhostController.new()
	ghost.name = "Ghost"
	ghost.game = self
	var gcs := CollisionShape3D.new()
	var gs := SphereShape3D.new()
	gs.radius = 0.58
	gcs.shape = gs
	gcs.position.y = 1.0
	ghost.add_child(gcs)

	var shroud_mat := _procedural_mat("pocong_cloth", pal["cloth"], false, false)
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.33
	bm.bottom_radius = 0.47
	bm.height = 1.35
	bm.radial_segments = 14
	body.mesh = bm
	body.material_override = shroud_mat
	body.position.y = 0.9
	ghost.add_child(body)

	var wrap := MeshInstance3D.new()
	var wm := SphereMesh.new()
	wm.radius = 0.4
	wm.height = 0.8
	wm.rings = 12
	wm.radial_segments = 18
	wrap.mesh = wm
	wrap.material_override = shroud_mat
	wrap.position.y = 1.72
	ghost.add_child(wrap)

	var face := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.27
	fm.height = 0.54
	fm.rings = 16
	fm.radial_segments = 22
	face.mesh = fm
	var face_mat := _get_mat("pocong_face", pal["face"], pal["emission"], 1.0)
	face.material_override = face_mat
	face.position.y = 2.1
	face.rotation.x = deg_to_rad(8)
	ghost.add_child(face)
	ghost.set_face(face)

	var dark_mat := _get_mat("pocong_dark", Color(0.02, 0.01, 0.01, 1), Color(0, 0, 0, 1), 0.0)
	var eye_mat := _get_mat("pocong_eye", Color(0, 0, 0, 1), pal["eye"], 7.0)
	for ex in [-0.12, 0.12]:
		var sok := MeshInstance3D.new()
		var sokm := SphereMesh.new()
		sokm.radius = 0.085
		sokm.height = 0.17
		sok.mesh = sokm
		sok.material_override = dark_mat
		sok.position = Vector3(ex, 2.14, -0.21)
		ghost.add_child(sok)
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.03
		es.height = 0.06
		eye.mesh = es
		eye.material_override = eye_mat
		eye.position = Vector3(ex, 2.16, -0.245)
		ghost.add_child(eye)

	var mouth := MeshInstance3D.new()
	var mom := CylinderMesh.new()
	mom.top_radius = 0.045
	mom.bottom_radius = 0.045
	mom.height = 0.3
	mom.radial_segments = 10
	mouth.mesh = mom
	mouth.material_override = dark_mat
	mouth.rotation.x = deg_to_rad(90)
	mouth.position = Vector3(-0.015, 1.93, -0.225)
	ghost.add_child(mouth)

	var rope_mat := _get_mat("pocong_rope", Color(0.36, 0.27, 0.19), Color(0, 0, 0, 1), 0.0)
	for ry in [0.55, 0.95, 1.42]:
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.08
		cm.radial_segments = 14
		ring.mesh = cm
		ring.material_override = rope_mat
		ring.rotation.x = deg_to_rad(90)
		ring.position.y = ry
		ghost.add_child(ring)

	var aura := OmniLight3D.new()
	aura.light_energy = 0.8
	aura.light_color = pal["aura"]
	aura.omni_range = 4.0
	aura.position.y = 1.9
	ghost.add_child(aura)

	add_child(ghost)
	ghost.target = player
	if level >= 2:
		ghost.home = Vector3(1.0 * TILE + 1.0, 1.4, 12.0 * TILE + 1.0)
		ghost.patrol_speed = 2.1
		ghost.chase_speed = 4.4
		ghost.stalk_speed = 3.6
		ghost.wander_radius = 12.0
	else:
		ghost.home = Vector3(15.0 * TILE + 1.0, 1.4, 1.0 * TILE + 1.0)
	ghost.global_position = ghost.home
	ghost.visible = true

func _build_keys():
	for cell in _key_cells():
		var v := Vector2i(cell[0], cell[1])
		var pos := Vector3(v.x * TILE + 1.0, 1.0, v.y * TILE + 1.0)
		var key := KeyPickup.new()
		key.game = self
		var kcs := CollisionShape3D.new()
		var ks := SphereShape3D.new()
		ks.radius = 0.6
		kcs.shape = ks
		key.add_child(kcs)
		var gmat := _get_mat("key", Color(1.0, 0.85, 0.2, 1), Color(1.0, 0.75, 0.15, 1), 6.0)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.68
		mi.mesh = sm
		mi.material_override = gmat
		key.add_child(mi)
		var kl := OmniLight3D.new()
		kl.light_energy = 3.5
		kl.light_color = Color(1.0, 0.82, 0.3)
		kl.omni_range = 7.0
		key.add_child(kl)
		var beam_mat := _get_mat("key_beam", Color(1.0, 0.9, 0.3, 0.6), Color(1.0, 0.8, 0.25, 1), 4.0)
		beam_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var beam := MeshInstance3D.new()
		var bm2 := CylinderMesh.new()
		bm2.top_radius = 0.04
		bm2.bottom_radius = 0.09
		bm2.height = 6.0
		beam.mesh = bm2
		beam.material_override = beam_mat
		beam.position.y = 3.4
		key.add_child(beam)
		var sp := CPUParticles3D.new()
		sp.amount = 26
		sp.lifetime = 1.8
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sp.emission_sphere_radius = 0.1
		sp.position.y = 1.0
		sp.direction = Vector3(0, 1, 0)
		sp.spread = 180.0
		sp.gravity = Vector3(0, 0.4, 0)
		sp.initial_velocity_min = 0.2
		sp.initial_velocity_max = 0.8
		sp.scale_amount_min = 0.03
		sp.scale_amount_max = 0.06
		sp.color = Color(1, 0.9, 0.4, 0.9)
		key.add_child(sp)
		key.position = pos
		add_child(key)
		all_keys.append(key)

func _build_exit():
	var v := _exit_cell()
	var pos := Vector3(v.x * TILE + 1.0, 1.6, v.y * TILE + 1.0)
	var door_mat := _get_mat("door", Color(0.28, 0.16, 0.1), Color(0.3, 0.05, 0.05, 1), 1.0)
	_add_static_box(pos, Vector3(0.4, 3.2, 2.0), door_mat)
	var frame_mat := _get_mat("frame", Color(0.24, 0.16, 0.11), Color(0, 0, 0), 1.0)
	for sx in [-1.6, 1.6]:
		_add_static_box(pos + Vector3(sx, 1.2, 0.0), Vector3(0.4, 2.9, 0.5), frame_mat)
	_add_static_box(pos + Vector3(0.0, 2.9, 0.0), Vector3(4.0, 0.35, 0.55), frame_mat)

	exit_area = Area3D.new()
	exit_area.collision_mask = 4
	var ecs := CollisionShape3D.new()
	var es := BoxShape3D.new()
	es.size = Vector3(2.6, 3.4, 2.6)
	ecs.shape = es
	exit_area.add_child(ecs)
	exit_area.position = pos
	exit_area.body_entered.connect(_on_exit_entered)
	add_child(exit_area)

	door_light = OmniLight3D.new()
	door_light.light_energy = 0.0
	door_light.omni_range = 6.0
	door_light.light_color = Color(1.0, 0.2, 0.2)
	door_light.position = pos + Vector3(0, 1.8, 0)
	add_child(door_light)

func _on_exit_entered(body: Node3D):
	if body == player and running:
		if keys_found >= keys_total:
			_win()
		else:
			hint.text = "TERKUNCI! Cari kunci lain (%d/%d)" % [keys_found, keys_total]
			hint.modulate.a = 1.0
			_play_once("res://audio/door_slam.wav", -6.0, 1.1)
			await get_tree().create_timer(2.0).timeout
			hint.modulate.a = 0.0

func collected_key():
	keys_found += 1
	key_label.text = "Kunci: %d/%d" % [keys_found, keys_total]
	_play_once("res://audio/pickup.wav", -4.0)
	if keys_found >= keys_total:
		objective.text = "PINTU TERBUKA! LARI KE PINTU KELUAR!"
		door_light.light_energy = 3.0
		door_light.light_color = Color(0.3, 1.0, 0.4)
		_play_once("res://audio/door_slam.wav", -4.0, 0.8)
	else:
		objective.text = "Cari kunci: %d/%d" % [keys_found, keys_total]

func _build_hud():
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	objective = Label.new()
	objective.text = "Cari kunci: 0/%d" % keys_total
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective.offset_top = 24
	objective.add_theme_font_size_override("font_size", 34)
	objective.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	objective.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(objective)

	key_label = Label.new()
	key_label.text = "Kunci: 0/%d" % keys_total
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	key_label.offset_top = 66
	key_label.add_theme_font_size_override("font_size", 26)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(key_label)

	hint = Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_bottom = -60
	hint.offset_top = -110
	hint.offset_left = 20
	hint.offset_right = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	hint.modulate.a = 0.0
	root.add_child(hint)

	var fl_btn := Button.new()
	fl_btn.text = "SENTER ON"
	fl_btn.add_theme_font_size_override("font_size", 26)
	fl_btn.custom_minimum_size = Vector2(170, 96)
	fl_btn.anchor_left = 1.0
	fl_btn.anchor_top = 1.0
	fl_btn.anchor_right = 1.0
	fl_btn.anchor_bottom = 1.0
	fl_btn.offset_left = -210
	fl_btn.offset_top = -280
	fl_btn.offset_right = -30
	fl_btn.offset_bottom = -180
	fl_btn.pressed.connect(func(): player.toggle_flashlight())
	root.add_child(fl_btn)

	var update_fl := func(on: bool):
		fl_btn.text = "SENTER ON" if on else "SENTER OFF"
		fl_btn.modulate = Color(1, 1, 1, 1) if on else Color(0.55, 0.55, 0.58)
	player.flashlight_toggled.connect(func(on: bool):
		update_fl.call(on)
		_play_once("res://audio/click.wav", -13.0)
	)
	update_fl.call(true)

	var quit_btn := Button.new()
	quit_btn.text = "II"
	quit_btn.add_theme_font_size_override("font_size", 30)
	quit_btn.custom_minimum_size = Vector2(110, 54)
	quit_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quit_btn.offset_left = 12
	quit_btn.offset_top = 12
	quit_btn.offset_right = 122
	quit_btn.offset_bottom = 66
	quit_btn.pressed.connect(func():
		if pause_overlay:
			pause_overlay.toggle())
	root.add_child(quit_btn)

	var badge := Label.new()
	badge.text = "LEVEL 2" if level >= 2 else "LEVEL 1"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = 12
	badge.offset_top = 78
	badge.add_theme_font_size_override("font_size", 24)
	badge.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	root.add_child(badge)

	ghost_label = Label.new()
	ghost_label.text = "HANTU: %s" % ghost_name
	ghost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ghost_label.offset_top = 150
	ghost_label.add_theme_font_size_override("font_size", 26)
	ghost_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.18))
	ghost_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ghost_label.add_theme_constant_override("shadow_offset_y", 2)
	ghost_label.modulate.a = 0.75
	root.add_child(ghost_label)

	key_hint = Label.new()
	key_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	key_hint.offset_top = 90
	key_hint.offset_bottom = 150
	key_hint.offset_left = -300
	key_hint.offset_right = 300
	key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_hint.add_theme_font_size_override("font_size", 30)
	key_hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	key_hint.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0, 0.8))
	key_hint.add_theme_constant_override("shadow_offset_x", 2)
	key_hint.add_theme_constant_override("shadow_offset_y", 2)
	key_hint.modulate.a = 0.0
	root.add_child(key_hint)

	vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var gd := Gradient.new()
	gd.set_color(0, Color(0, 0, 0, 0))
	gd.set_color(1, Color(0.65, 0.02, 0.02, 1))
	var gt := GradientTexture2D.new()
	gt.gradient = gd
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	vignette.texture = gt
	vignette.modulate.a = 0.0
	root.add_child(vignette)

	joystick = JoystickControl.new()
	root.add_child(joystick)
	player.joystick = joystick

	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(420, 22)
	stamina_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.anchor_left = 0.5
	stamina_bar.anchor_right = 0.5
	stamina_bar.offset_left = -210
	stamina_bar.offset_right = 210
	stamina_bar.offset_top = -300
	stamina_bar.offset_bottom = -278
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.add_theme_stylebox_override("background", _bar_style(Color(0.06, 0.05, 0.07, 0.85)))
	stamina_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.12, 0.55, 0.3, 1)))
	root.add_child(stamina_bar)
	player.stamina_changed.connect(func(v: float): stamina_bar.value = v)
	var on_stamina_low := func(low: bool):
		stamina_bar.modulate = Color(1, 0.4, 0.35) if low else Color(1, 1, 1)
	player.stamina_low_changed.connect(on_stamina_low)

	minimap = Minimap.new()
	minimap.game = self
	minimap.custom_minimum_size = Vector2(190, 148)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -202
	minimap.offset_right = -12
	minimap.offset_top = 12
	minimap.offset_bottom = 160
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)

	pause_overlay = PauseOverlay.new()
	pause_overlay.host = self
	add_child(pause_overlay)
	pause_overlay.restart_requested.connect(func(): restart_requested.emit())
	pause_overlay.exit_requested.connect(func(): exit_requested.emit())

func _bar_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	return s

func _setup_audio():
	ambient = _loop_player("res://audio/ambient_drone.wav", -13.0)
	heartbeat = _loop_player("res://audio/heartbeat.wav", -30.0)
	whisper = _loop_player("res://audio/whisper.wav", -30.0)
	whisper.volume_db = -80.0

func _loop_player(path: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := load(path) as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	p.stream = s
	p.volume_db = vol
	add_child(p)
	p.play()
	return p

func _play_once(path: String, vol := -6.0, pitch := 1.0):
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = vol
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

func _process(delta: float):
	if not running:
		return
	_minimap_t -= delta
	if minimap and _minimap_t <= 0.0:
		_minimap_t = 0.12
		minimap.queue_redraw()
	if player and is_instance_valid(player):
		if player.is_on_floor():
			_step_timer -= delta * (2.0 if _moving() else 0.0)
			if _step_timer <= 0.0 and _moving():
				_step_timer = 0.4
				_play_once("res://audio/footstep.wav", -16.0, randf_range(0.85, 1.15))
	if is_instance_valid(ghost) and is_instance_valid(player):
		var gd := ghost.global_position.distance_to(player.global_position)
		if gd < 4.0:
			_shake_camera()
		if ghost_label:
			var near := clampf(1.0 - gd / 9.0, 0.0, 1.0)
			ghost_label.modulate.a = 0.3 + near * 0.7
			ghost_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.18).lerp(Color(1.0, 0.05, 0.05), near))
	_check_key_hint(delta)

func _check_key_hint(delta: float):
	if not player or not is_instance_valid(player):
		return
	var best := INF
	var best_key: Node3D = null
	for k in all_keys:
		if is_instance_valid(k):
			var d: float = k.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				best_key = k
	if best_key == null:
		return
	if best < 7.0:
		if not _key_pinged.has(best_key.get_instance_id()):
			_key_pinged[best_key.get_instance_id()] = true
			_play_once("res://audio/pickup.wav", -15.0, 1.4)
		_near_key_t = minf(_near_key_t + delta * 2.0, 1.0)
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
		key_hint.text = "Kunci keemasan ada di dekat sini!"
		key_hint.modulate.a = _near_key_t * pulse
	else:
		_near_key_t = maxf(_near_key_t - delta, 0.0)
		key_hint.modulate.a = _near_key_t

func _moving() -> bool:
	if not player:
		return false
	var v := player.velocity
	return absf(v.x) > 0.4 or absf(v.z) > 0.4

func _shake_camera():
	if not camera:
		return
	var t := Time.get_ticks_msec() * 0.35
	camera.rotation.z = sin(t * 0.9) * 0.01
	camera.position.x = sin(t * 1.3) * 0.015
	camera.position.y = 1.62 + sin(t * 1.1) * 0.02

func _on_danger(level: float):
	var d := clampf(level, 0.0, 1.0)
	vignette.modulate.a = d * 0.75
	heartbeat.pitch_scale = 0.8 + d * 1.4
	heartbeat.volume_db = -30.0 + d * 22.0
	if d > 0.35:
		whisper.volume_db = lerp(whisper.volume_db, -26.0 + d * 10.0, 0.1)
	else:
		whisper.volume_db = lerp(whisper.volume_db, -80.0, 0.1)
	if _is_on_android() and d > 0.65:
		_vib_cooldown -= get_process_delta_time()
		if _vib_cooldown <= 0.0:
			_vib_cooldown = 0.85
			Input.vibrate_handheld(int(25 + d * 40))

func _on_caught():
	if not running:
		return
	running = false
	player.set_control(false)
	if _is_on_android():
		Input.vibrate_handheld(700)
	if music:
		var m: AudioStreamPlayer = music
		m.volume_db = -26.0
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(m):
			m.volume_db = -8.0
	_play_once("res://audio/jumpscare.wav", -2.0)
	_build_jumpscare()
	if camera:
		var tw := create_tween()
		tw.tween_property(camera, "rotation:z", 0.12, 0.04).set_trans(Tween.TRANS_SINE)
		tw.tween_property(camera, "rotation:z", -0.12, 0.05)
		tw.tween_property(camera, "rotation:z", 0.0, 0.05)
		tw.set_loops(5)
	await get_tree().create_timer(1.7).timeout
	if camera:
		camera.rotation.z = 0.0
	ended.emit(false)

func _build_jumpscare():
	if jumped:
		return
	jumped = true
	scare_overlay = CanvasLayer.new()
	scare_overlay.layer = 40
	scare_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(scare_overlay)
	var scare := PocongScare.new()
	scare.game = self
	scare.name = "Jumpscare"
	scare.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_overlay.add_child(scare)
	await get_tree().create_timer(1.7).timeout
	if scare_overlay and is_instance_valid(scare_overlay):
		scare_overlay.queue_free()
		scare_overlay = null

func _win():
	if not running:
		return
	running = false
	player.set_control(false)
	_play_once("res://audio/win.wav", -4.0)
	await get_tree().create_timer(1.2).timeout
	ended.emit(true)

class Lamp extends Node:
	var light: OmniLight3D
	var base := 1.0
	var phase := 0.0
	func _ready():
		phase = randf() * TAU
	func _physics_process(_d: float):
		if not light:
			return
		var t := Time.get_ticks_msec() * 0.001
		var flick := 0.8 + 0.22 * sin(t * 8.0 + phase) + 0.12 * sin(t * 23.0 + phase * 2.7)
		if sin(t * 0.47 + phase) > 0.96:
			flick = 0.06
		light.light_energy = base * clampf(flick, 0.0, 1.3)

class KeyPickup extends Area3D:
	var game: GameScreen
	var t := 0.0
	func _ready():
		monitoring = true
		collision_layer = 0
		collision_mask = 4
		body_entered.connect(func(body):
			if body == game.player and game.running:
				game.collected_key()
				queue_free())
	func _physics_process(delta: float):
		t += delta
		rotation.y += delta * 2.0
		position.y = 1.0 + sin(t * 2.0) * 0.15

class Minimap extends Control:
	var game: GameScreen
	func _draw():
		if not game:
			return
		var w := size.x
		var h := size.y
		var map: Array = game._map()
		var cw := w / 17.0
		var ch := h / 13.0
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
		var wall_c := Color(0.16, 0.15, 0.17, 0.95)
		var floor_c := Color(0.3, 0.27, 0.32, 0.85)
		for y in range(map.size()):
			for x in range(map[y].length()):
				var r := Rect2(x * cw, y * ch, cw, ch)
				if map[y][x] == '#':
					draw_rect(r, wall_c)
				else:
					draw_rect(r, floor_c)
		var exit_c := Vector2i(game._exit_cell())
		draw_rect(Rect2(exit_c.x * cw, exit_c.y * ch, cw, ch), Color(0.2, 0.9, 0.35))
		for k in game.all_keys:
			if is_instance_valid(k):
				var kp: Vector2 = Vector2(k.position.x, k.position.z) / 2.0
				var cc := Vector2(kp.x - 1.0, kp.y - 1.0)
				draw_rect(Rect2(cc.x * cw + cw * 0.2, cc.y * ch + ch * 0.2, cw * 0.6, ch * 0.6), Color(1, 0.85, 0.3))
		if game.player and is_instance_valid(game.player):
			var pp: Vector2 = Vector2(game.player.global_position.x, game.player.global_position.z) / 2.0 - Vector2.ONE
			var pc := Vector2(pp.x * cw + cw * 0.5, pp.y * ch + ch * 0.5)
			draw_circle(pc, 3.2, Color(1, 1, 1))
		if game.ghost and is_instance_valid(game.ghost):
			var gp: Vector2 = Vector2(game.ghost.global_position.x, game.ghost.global_position.z) / 2.0 - Vector2.ONE
			var gc := Vector2(gp.x * cw + cw * 0.5, gp.y * ch + ch * 0.5)
			draw_circle(gc, 3.6, Color(1, 0.15, 0.1))
		draw_rect(Rect2(0, 0, w, h), Color(1, 0.2, 0.2, 0.7), false, 1.5)

class PocongScare extends Control:
	var game: GameScreen
	var _t := 0.0
	var _seed := 0.0
	func _ready():
		_seed = randf() * TAU
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO
		size = get_viewport_rect().size
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.08)
	func _process(delta: float):
		_t += delta
		var vs := get_viewport_rect().size
		if position != Vector2.ZERO or size != vs:
			position = Vector2.ZERO
			size = vs
		if _t > 1.4:
			modulate.a = maxf(modulate.a - delta * 2.2, 0.0)
		queue_redraw()
	func _draw():
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		var shake := maxf(18.0 - _t * 10.0, 0.0)
		var off := Vector2(
			sin((_t * 60.0 + _seed) * 1.0) * shake * 0.35,
			cos((_t * 55.0 + _seed) * 1.0) * shake * 0.35
		)
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 1))
		draw_set_transform(off, 0.0, Vector2.ONE)
		var cx := w * 0.5
		var cy := h * 0.52
		var rx := w * 0.24
		var ry := h * 0.36
		draw_circle(Vector2(cx, cy), rx * 1.15, Color(0.5, 0.03, 0.03, 0.55))
		draw_circle(Vector2(cx - rx * 0.4, cy + ry * 0.2), rx * 0.5, Color(0.35, 0.1, 0.1, 0.4))
		draw_circle(Vector2(cx + rx * 0.4, cy + ry * 0.2), rx * 0.5, Color(0.35, 0.1, 0.1, 0.4))
		var face: PackedVector2Array = _ellipse(cx, cy, rx, ry, 40)
		draw_colored_polygon(face, Color(0.9, 0.86, 0.82))
		draw_polyline(face, Color(0.5, 0.45, 0.42), 2.0)
		var tex: PackedVector2Array = _ellipse(cx - rx * 0.1, cy + ry * 0.05, rx * 0.9, ry * 0.7, 40)
		draw_colored_polygon(tex, Color(0.82, 0.76, 0.72))
		var eye_c := Color(0.04, 0.02, 0.02)
		for i2 in range(2):
			var sx: float = 0.38 if i2 == 1 else -0.38
			var ex := cx + rx * sx
			var ey := cy - ry * 0.08
			draw_colored_polygon(_ellipse(ex - rx * 0.02, ey, rx * 0.26, ry * 0.3, 26), eye_c)
			var gl := 0.5 + 0.5 * sin(_t * 40.0)
			var glow := Color(1, 0.1, 0.08, 0.6 + gl * 0.4)
			draw_circle(Vector2(ex - rx * 0.03, ey + ry * 0.02), rx * 0.07, glow)
			draw_circle(Vector2(ex - rx * 0.03, ey + ry * 0.02), rx * 0.045, Color(1, 0.5, 0.2))
		var mouth_pts: PackedVector2Array = _ellipse(cx + rx * 0.04, cy + ry * 0.42, rx * 0.28, ry * 0.16, 26)
		draw_colored_polygon(mouth_pts, Color(0.03, 0.01, 0.01))
		draw_line(Vector2(cx - rx * 0.25, cy + ry * 0.5), Vector2(cx + rx * 0.3, cy + ry * 0.52), Color(0.4, 0.33, 0.3), 3.0)
		draw_line(Vector2(cx - rx * 0.72, cy - ry * 0.72), Vector2(cx + rx * 0.72, cy - ry * 0.72), Color(0.9, 0.85, 0.8), 10.0)
		draw_colored_polygon(_ellipse(cx, cy - ry * 0.78, rx * 0.5, ry * 0.1, 24), Color(0.85, 0.8, 0.76))
		for i in range(4):
			var tx := cx - rx * 0.5 + rx * 0.3 * i
			draw_line(Vector2(tx, cy - ry * 0.66), Vector2(tx - rx * 0.08, cy - ry * 0.9), Color(0.35, 0.28, 0.24), 3.0)
		if game and game.ghost_name != "":
			var name_c := Color(1, 0.28, 0.22)
			draw_string(ThemeDB.fallback_font, Vector2(cx - rx * 0.85, cy - ry * 1.05), game.ghost_name, HORIZONTAL_ALIGNMENT_CENTER, rx * 1.7, int(w * 0.075), name_c)
	func _ellipse(cenx: float, ceny: float, rx: float, ry: float, n: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(n + 1):
			var a := TAU * float(i) / float(n)
			pts.append(Vector2(cenx + cos(a) * rx, ceny + sin(a) * ry))
		return pts