extends CharacterBody3D

class_name GhostController

enum State { PATROL, CHASE, STALK }

signal caught
signal danger_changed(level: float)

var target: Node3D = null

var active := false
var state: State = State.PATROL
var home := Vector3.ZERO
var wander_radius := 9.0

var patrol_speed := 1.7
var chase_speed := 3.7
var stalk_speed := 3.0

var last_seen := Vector3.ZERO
var lose_time := 0.0
var wander_time := 0.0
var patrol_point := Vector3.ZERO
var fatigue := 0.0

var danger := 0.0
var _face: MeshInstance3D = null

func _ready():
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 8

func activate():
	active = true
	global_position = home
	_pick_patrol()

func set_face(n: MeshInstance3D):
	_face = n

func _pick_patrol():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := rng.randf() * TAU
	var r := rng.randf_range(2.0, wander_radius)
	patrol_point = Vector3(
		home.x + cos(a) * r,
		home.y,
		home.z + sin(a) * r
	)

func _physics_process(delta: float):
	if not active or not target:
		return

	var sees_player := _check_sight()
	var to_p := target.global_position - global_position
	var dist := to_p.length()

	if sees_player:
		last_seen = target.global_position
		lose_time = 0.0
		if state != State.CHASE:
			state = State.CHASE
	elif state == State.CHASE:
		lose_time += delta
		if lose_time > 3.0:
			state = State.STALK

	match state:
		State.PATROL:
			if global_position.distance_to(patrol_point) < 0.7 or wander_time <= 0.0:
				wander_time = 1.5
				_pick_patrol()
			wander_time -= delta
			_move_toward(patrol_point, patrol_speed, delta)
			if sees_player:
				pass
		State.CHASE:
			_move_toward(target.global_position, chase_speed + fatigue, delta)
			if dist < 1.35:
				caught.emit()
				active = false
		State.STALK:
			_move_toward(last_seen, stalk_speed, delta)
			if global_position.distance_to(last_seen) < 0.8:
				state = State.PATROL
				_pick_patrol()

	var new_danger := 0.0
	if state == State.CHASE:
		new_danger = clampf(1.0 - dist / 14.0, 0.0, 1.0)
	elif dist < 6.0:
		new_danger = clampf((6.0 - dist) / 6.0, 0.0, 1.0) * 0.5
	danger = lerp(danger, new_danger, 3.0 * delta)
	danger_changed.emit(danger)

	if _face:
		var flicker := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
		var mat := _face.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = flicker * (1.0 + danger * 2.0)

func _move_toward(p: Vector3, spd: float, delta: float):
	var dir := (p - global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		dir = dir.normalized()
	velocity = dir * spd
	velocity.y = 0.0
	move_and_slide()
	_look_toward(dir)

func _look_toward(dir: Vector3):
	if dir.length() < 0.1:
		return
	var b := global_transform.basis
	var ang := atan2(dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, ang, 0.2)

func _check_sight() -> bool:
	if not target:
		return false
	var from := global_position + Vector3.UP * 0.2
	var to := target.global_position + Vector3.UP * 1.3
	var dist := from.distance_to(to)
	if dist > 15.0:
		return false
	var to_p := to - from
	to_p.y = 0.0
	to_p = to_p.normalized()
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if fwd.dot(to_p) < 0.4:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(q)
	if result.is_empty():
		return false
	return result.collider == target