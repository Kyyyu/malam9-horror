extends Node3D

class_name GameScreen

signal ended(is_win: bool)
signal exit_requested

const TILE := 2.0
const WALL_H := 3.2

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

const LAMP_CELLS := [[4, 1], [3, 3], [5, 5], [10, 5], [11, 7], [5, 9], [3, 12], [9, 3]]
const WHISPER_CELLS := [[8, 3], [11, 5], [3, 7], [2, 9], [6, 11]]

var player: PlayerController = null
var camera: Camera3D = null
var ghost: GhostController = null

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
var vignette: TextureRect = null
var joystick: JoystickControl = null

var ambient: AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var whisper: AudioStreamPlayer
var _step_timer := 0.0
var _loaded := false

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

	await get_tree().create_timer(8.0).timeout
	ghost.activate()
	_play_once("res://audio/door_slam.wav", -8.0)
	_play_once("res://audio/whisper.wav", -10.0)

func _get_mat(key: String, color: Color, emissive := Color(0, 0, 0, 1), e_energy := 1.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = emissive.a > 0.0
		m.emission = emissive
		m.emission_energy_multiplier = e_energy
		_mats[key] = m
	return _mats[key]

func _build_environment():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.005, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_energy = 0.4
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.05)
	env.fog_density = 0.055
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-45, -35, 0)
	moon.light_energy = 0.22
	moon.light_color = Color(0.4, 0.45, 0.7)
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
	var floor_mat := _get_mat("floor", Color(0.11, 0.09, 0.1), Color(0, 0, 0), 1.0)
	_add_static_box(Vector3(17.0, -0.25, 13.0), Vector3(34.0, 0.5, 26.0), floor_mat)

	var wall_mats := [
		_get_mat("wall1", Color(0.17, 0.13, 0.15), Color(0, 0, 0), 1.0),
		_get_mat("wall2", Color(0.20, 0.15, 0.14), Color(0, 0, 0), 1.0),
	]
	var wall_i := 0
	var open_cells: Array[Vector2i] = []

	for row in range(MAP.size()):
		var line: String = MAP[row]
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

func _build_lamps():
	for lam in LAMP_CELLS:
		var cell := Vector2i(lam[0], lam[1])
		if MAP[cell.y][cell.x] == '#':
			continue
		var light := OmniLight3D.new()
		light.light_energy = 2.4
		light.light_color = Color(1.0, 0.75, 0.45)
		light.omni_range = 10.0
		light.position = Vector3(cell.x * TILE + 1.0, 2.6, cell.y * TILE + 1.0)
		add_child(light)
		var lamp := Lamp.new()
		lamp.light = light
		lamp.base = light.light_energy
		add_child(lamp)

func _build_furniture(open_cells: Array[Vector2i]):
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var candidates: Array[Vector2i] = []
	for c in open_cells:
		var nc := _wall_neighbors(c, open_cells)
		if nc >= 2 and not _is_special(c):
			candidates.append(c)
	candidates.shuffle()
	var count := mini(candidates.size(), 12)
	var box_mat := _get_mat("box", Color(0.13, 0.1, 0.09), Color(0, 0, 0), 1.0)
	var wood_mat := _get_mat("wood", Color(0.22, 0.16, 0.1), Color(0, 0, 0), 1.0)
	for i in range(count):
		var c := candidates[i]
		var pos := Vector3(c.x * TILE + 1.0, 0.0, c.y * TILE + 1.0)
		var r := rng.randf_range(0.0, TAU)
		var which := i % 3
		if which == 0:
			var b := _add_static_box(pos + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), box_mat)
			b.rotation.y = r
		elif which == 1:
			var b := _add_static_box(pos + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 0.8), wood_mat)
			b.rotation.y = r
		else:
			var b := _add_static_box(pos + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.7), box_mat)
			b.rotation.y = r

func _is_special(c: Vector2i) -> bool:
	if MAP[c.y][c.x] in ['P', 'K', 'E']:
		return true
	for l in LAMP_CELLS:
		if Vector2i(l[0], l[1]) == c:
			return true
	for k in [[13, 3], [9, 7], [13, 9]]:
		if Vector2i(k[0], k[1]) == c:
			return true
	return false

func _wall_neighbors(c: Vector2i, open_cells: Array[Vector2i]) -> int:
	var count := 0
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if open_cells.has(c + off):
			continue
		count += 1
	return count

func _build_whispers():
	for cell in WHISPER_CELLS:
		var v := Vector2i(cell[0], cell[1])
		if MAP[v.y][v.x] == '#':
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
	fl.spot_range = 24.0
	fl.spot_angle = deg_to_rad(32.0)
	fl.spot_attenuation = 1.1
	fl.light_energy = 3.0
	fl.light_color = Color(0.95, 0.9, 0.75)
	fl.shadow_enabled = true
	fl.position.y = -0.15
	camera.add_child(fl)

	add_child(player)
	player.collision_layer = 4
	player.collision_mask = 1
	player.global_position = Vector3(1.0 * TILE + 1.0, 0.2, 1.0 * TILE + 1.0)

func _build_ghost():
	ghost = GhostController.new()
	ghost.name = "Ghost"
	var gcs := CollisionShape3D.new()
	var gs := SphereShape3D.new()
	gs.radius = 0.55
	gcs.shape = gs
	gcs.position.y = 1.3
	ghost.add_child(gcs)

	var body_mat := _get_mat("ghost_body", Color(0.9, 0.95, 1, 0.85), Color(0.55, 0.75, 1, 1), 1.6)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.42
	cm.height = 1.5
	body.mesh = cm
	body.material_override = body_mat
	body.position.y = 1.15
	ghost.add_child(body)

	var face := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.86
	face.mesh = sm
	var face_mat := _get_mat("ghost_face", Color(0.92, 0.97, 1, 1), Color(0.5, 0.8, 1, 1), 2.0)
	face.material_override = face_mat
	face.position.y = 2.0
	ghost.add_child(face)
	ghost.set_face(face)

	var eye_mat := _get_mat("ghost_eye", Color(0, 0, 0, 1), Color(1, 0, 0, 1), 4.0)
	for ex in [-0.14, 0.14]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.05
		es.height = 0.1
		eye.mesh = es
		eye.material_override = eye_mat
		eye.position = Vector3(ex, 2.06, -0.35)
		ghost.add_child(eye)

	add_child(ghost)
	ghost.target = player
	ghost.home = Vector3(15.0 * TILE + 1.0, 1.4, 1.0 * TILE + 1.0)
	ghost.global_position = ghost.home
	ghost.visible = true

func _build_keys():
	for cell in [[13, 3], [9, 7], [13, 9]]:
		var v := Vector2i(cell[0], cell[1])
		var pos := Vector3(v.x * TILE + 1.0, 1.0, v.y * TILE + 1.0)
		var key := KeyPickup.new()
		key.game = self
		var kcs := CollisionShape3D.new()
		var ks := SphereShape3D.new()
		ks.radius = 0.6
		kcs.shape = ks
		key.add_child(kcs)
		var gmat := _get_mat("key", Color(1.0, 0.85, 0.2, 1), Color(1.0, 0.7, 0.1, 1), 3.0)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		mi.mesh = sm
		mi.material_override = gmat
		key.add_child(mi)
		var kl := OmniLight3D.new()
		kl.light_energy = 1.6
		kl.light_color = Color(1.0, 0.8, 0.3)
		kl.omni_range = 4.0
		key.add_child(kl)
		key.position = pos
		add_child(key)
		all_keys.append(key)

func _build_exit():
	var v := Vector2i(10, 12)
	var pos := Vector3(v.x * TILE + 1.0, 1.6, v.y * TILE + 1.0)
	var door_mat := _get_mat("door", Color(0.28, 0.16, 0.1), Color(0.3, 0.05, 0.05, 1), 1.0)
	_add_static_box(pos, Vector3(0.4, 3.2, 2.0), door_mat)

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
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	objective = Label.new()
	objective.text = "Cari kunci: 0/%d" % keys_total
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
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	key_label.offset_top = 66
	key_label.add_theme_font_size_override("font_size", 26)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(key_label)

	hint = Label.new()
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
	fl_btn.text = "SENTER"
	fl_btn.add_theme_font_size_override("font_size", 26)
	fl_btn.custom_minimum_size = Vector2(150, 90)
	fl_btn.anchor_left = 1.0
	fl_btn.anchor_top = 1.0
	fl_btn.anchor_right = 1.0
	fl_btn.anchor_bottom = 1.0
	fl_btn.offset_left = -190
	fl_btn.offset_top = -260
	fl_btn.offset_right = -30
	fl_btn.offset_bottom = -160
	fl_btn.pressed.connect(func(): player.toggle_flashlight())
	root.add_child(fl_btn)

	var quit_btn := Button.new()
	quit_btn.text = "KELUAR"
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.custom_minimum_size = Vector2(110, 54)
	quit_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quit_btn.offset_left = 12
	quit_btn.offset_top = 12
	quit_btn.offset_right = 122
	quit_btn.offset_bottom = 66
	quit_btn.pressed.connect(func(): exit_requested.emit())
	root.add_child(quit_btn)

	vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if player and is_instance_valid(player):
		if player.is_on_floor():
			_step_timer -= delta * (2.0 if _moving() else 0.0)
			if _step_timer <= 0.0 and _moving():
				_step_timer = 0.4
				_play_once("res://audio/footstep.wav", -16.0, randf_range(0.85, 1.15))
	if is_instance_valid(ghost) and is_instance_valid(player):
		if ghost.global_position.distance_to(player.global_position) < 4.0:
			_shake_camera()

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

func _on_caught():
	if not running:
		return
	running = false
	player.set_control(false)
	_play_once("res://audio/jumpscare.wav", -2.0)
	_build_jumpscare()
	await get_tree().create_timer(1.6).timeout
	ended.emit(false)

func _build_jumpscare():
	if jumped:
		return
	jumped = true
	var root := Node3D.new()
	if camera:
		root.global_transform = camera.global_transform
		root.global_position = camera.global_position - root.global_transform.basis.z * 1.4
	add_child(root)
	var mat := _get_mat("jump", Color(0.93, 0.97, 1, 1), Color(0.55, 0.75, 1, 1), 4.0)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	mi.mesh = sm
	mi.material_override = mat
	root.add_child(mi)
	for ex in [-0.22, 0.22]:
		var mk := MeshInstance3D.new()
		var ek := SphereMesh.new()
		ek.radius = 0.09
		ek.height = 0.18
		mk.mesh = ek
		mk.material_override = _get_mat("jump_eye", Color(0, 0, 0, 1), Color(1, 0.05, 0.05, 1), 6.0)
		mk.position = Vector3(ex, 0.12, -0.4)
		root.add_child(mk)
	root.scale = Vector3.ONE * 0.02
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(root, "scale", Vector3.ONE * 1.4, 0.4)
	await get_tree().create_timer(1.8).timeout
	root.queue_free()

func _win():
	if not running:
		return
	running = false
	player.set_control(false)
	_play_once("res://audio/win.wav", -4.0)
	await get_tree().create_timer(1.2).timeout
	ended.emit(true)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if running:
			exit_requested.emit()
			get_viewport().set_input_as_handled()

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