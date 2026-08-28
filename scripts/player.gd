extends CharacterBody3D

class_name PlayerController

signal flashlight_toggled(on: bool)

const GRAVITY := 22.0

var camera: Camera3D
var flashlight: SpotLight3D
var joystick: JoystickControl = null

var walk_speed := 3.6
var run_speed := 5.2
var control_enabled := true

var look_speed := 0.0032
var _pitch := 0.0
var _bob_time := 0.0
var _bob_base := 1.62

var _move_on := false
var _look_on := false
var _move_finger := -1
var _move_anchor := Vector2.ZERO
var _look_last := {}

var safe_to_move := true

func _ready():
	camera = get_node_or_null("Camera3D")
	flashlight = get_node_or_null("Camera3D/Flashlight")
	if camera:
		_bob_base = camera.position.y

func set_control(on: bool):
	control_enabled = on
	if not on:
		_move_on = false
		_look_on = false
		_move_finger = -1
		_move_anchor = Vector2.ZERO
		_look_last.clear()
		if joystick:
			joystick.visible = false

func toggle_flashlight():
	if flashlight:
		flashlight.visible = not flashlight.visible
		flashlight_toggled.emit(flashlight.visible)

func _physics_process(delta: float):
	if not control_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_vec := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_vec.y += 1.0
	if Input.is_action_pressed("move_back"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0

	if joystick and _move_on:
		var jv := joystick.value()
		input_vec.x += jv.x
		input_vec.y += -jv.y
		input_vec = input_vec.limit_length(1.0)

	var moving := input_vec.length() > 0.05
	var speed := run_speed if input_vec.length() > 0.9 else walk_speed
	var dir := Vector3.ZERO
	if moving:
		var b := global_transform.basis
		dir = (b.x * input_vec.x + -b.z * input_vec.y).normalized()

	var target := dir * speed
	velocity.x = lerp(velocity.x, target.x, minf(1.0, 14.0 * delta))
	velocity.z = lerp(velocity.z, target.z, minf(1.0, 14.0 * delta))
	velocity.y -= GRAVITY * delta
	move_and_slide()

	if camera:
		if moving and is_on_floor():
			_bob_time += delta * (1.4 if speed > 4.5 else 1.0)
			var bob := sin(_bob_time * TAU) * 0.035 * clampf(input_vec.length(), 0, 1)
			camera.position.y = _bob_base + bob
		else:
			camera.position.y = lerp(camera.position.y, _bob_base, 10.0 * delta)

func _look(rel: Vector2):
	if not control_enabled:
		return
	rotate_y(-rel.x * look_speed)
	_pitch = clampf(_pitch - rel.y * look_speed * 0.6, -1.25, 1.25)
	if camera:
		camera.rotation.x = _pitch

func _unhandled_input(event: InputEvent):
	if not control_enabled:
		return

	if event is InputEventMouseMotion:
		if _look_on:
			_look(event.relative)
	elif event is InputEventMouseButton:
		if event.pressed:
			_look_on = true
		else:
			_look_on = false
	elif event is InputEventScreenTouch:
		var size := get_viewport().get_visible_rect().size
		if event.pressed:
			if event.index == _move_finger:
				return
			if _move_finger == -1 and event.position.x < size.x * 0.42:
				_move_finger = event.index
				_move_anchor = event.position
				_move_on = true
				if joystick:
					joystick.visible = true
					joystick.set_joy(_move_anchor, _move_anchor)
				_update_move(event.position)
			else:
				_look_last[event.index] = event.position
		else:
			if event.index == _move_finger:
				_move_finger = -1
				_move_on = false
				if joystick:
					joystick.visible = false
			_look_last.erase(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _move_finger:
			_update_move(event.position)
		elif _look_last.has(event.index):
			_look(event.position - _look_last[event.index])
			_look_last[event.index] = event.position

func _update_move(pos: Vector2):
	if not _move_on or _move_finger < 0:
		return
	var max_dist := joystick.radius if joystick else 90.0
	var v := pos - _move_anchor
	if v.length() > max_dist:
		_move_anchor = pos - v.normalized() * max_dist
		v = pos - _move_anchor
	var knob := _move_anchor + v
	if joystick:
		joystick.set_joy(_move_anchor, knob)