extends CharacterBody3D

class_name GhostController

enum State { PATROL, CHASE, STALK }

signal caught
signal danger_changed(level: float)

var target: Node3D = null
var game: Node3D = null

var active := false
var state: State = State.PATROL
var home := Vector3.ZERO
var wander_radius := 9.0

var patrol_speed := 1.7
var chase_speed := 3.7
var stalk_speed := 3.0

var last_seen := Vector3.ZERO
var lose_time := 0.0

var danger := 0.0
var _face: MeshInstance3D = null

var goal := Vector3.ZERO
var waypoints := PackedVector3Array()
var repath_t := 0.0
var patrol_done := false
var _bob := 0.0

const REPATH_INTERVAL := 0.4

func _ready():
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 8

func activate():
	active = true
	global_position = home
	waypoints = PackedVector3Array()
	patrol_done = false
	state = State.PATROL

func set_face(n: MeshInstance3D):
	_face = n

func _physics_process(delta: float):
	if not active or not target:
		return
	_bob += delta

	var sees := _check_sight()
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()

	if sees:
		last_seen = target.global_position
		lose_time = 0.0
		if state != State.CHASE:
			state = State.CHASE
	elif state == State.CHASE:
		lose_time += delta
		if lose_time > 2.5:
			state = State.STALK

	if state == State.CHASE:
		_go_to(target.global_position, chase_speed, delta)
	elif state == State.STALK:
		_go_to(last_seen, stalk_speed, delta)
		if waypoints.size() == 0:
			state = State.PATROL
			patrol_done = true
	else:
		if patrol_done or waypoints.size() == 0:
			patrol_done = false
			_pick_patrol()
		_go_to(goal, patrol_speed, delta)

	if dist < 1.25 and _sees_player_cell():
		caught.emit()
		active = false
		return

	if _face and _face.get_surface_override_material(0) is StandardMaterial3D:
		var mat := _face.get_surface_override_material(0) as StandardMaterial3D
		var flicker := 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.02)
		mat.emission_energy_multiplier = flicker * (1.0 + danger * 2.0)

	var new_danger := 0.0
	if state == State.CHASE:
		new_danger = clampf(1.0 - dist / 14.0, 0.0, 1.0)
	elif dist < 6.0:
		new_danger = clampf((6.0 - dist) / 6.0, 0.0, 1.0) * 0.5
	danger = lerp(danger, new_danger, 3.0 * delta)
	danger_changed.emit(danger)

	var hop := absf(sin(_bob * 8.5)) * 0.18
	global_position.y = lerp(global_position.y, hop, 0.3)
	rotation.z = sin(_bob * 1.9) * 0.035

func _pick_patrol():
	if game and game.has_method("random_floor_goal"):
		goal = game.random_floor_goal(home, wander_radius)

func _go_to(target_pos: Vector3, spd: float, delta: float):
	repath_t -= delta
	if waypoints.size() == 0 or repath_t <= 0.0:
		repath_t = REPATH_INTERVAL
		if game and game.has_method("find_path"):
			waypoints = game.find_path(global_position, target_pos)
		if waypoints.size() == 0:
			velocity = Vector3.ZERO
			return
	var wp: Vector3 = waypoints[0]
	wp.y = global_position.y
	var to := wp - global_position
	if Vector2(to.x, to.z).length() < 0.45:
		waypoints.remove_at(0)
		if waypoints.size() == 0:
			velocity = Vector3.ZERO
			velocity.y = 0.0
			return
		wp = waypoints[0]
		wp.y = global_position.y
		to = wp - global_position
	var dir := Vector3(to.x, 0.0, to.z)
	if dir.length() > 0.1:
		dir = dir.normalized()
	velocity = dir * spd
	velocity.y = 0.0
	move_and_slide()
	_look_toward(dir)

func _look_toward(dir: Vector3):
	if dir.length() < 0.1:
		return
	var ang := atan2(dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, ang, 0.25)

func _sees_player_cell() -> bool:
	var from := global_position + Vector3.UP * 0.3
	var to := target.global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	return res.is_empty()

func _check_sight() -> bool:
	if not target:
		return false
	var from := global_position + Vector3.UP * 0.3
	var to := target.global_position + Vector3.UP * 1.3
	var dist := from.distance_to(to)
	if dist > 14.0:
		return false
	var to_p := to - from
	to_p.y = 0.0
	to_p = to_p.normalized()
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if fwd.dot(to_p) < 0.35:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(q)
	if result.is_empty():
		return false
	return result.collider == target