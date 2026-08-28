extends Control

class_name JoystickControl

var base_pos := Vector2.ZERO
var knob_pos := Vector2.ZERO
var radius := 110.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func _draw():
	if not visible:
		return
	draw_circle(base_pos, radius, Color(1, 1, 1, 0.08))
	draw_arc(base_pos, radius, 0, TAU, 64, Color(1, 1, 1, 0.25), 3.0)
	draw_circle(base_pos, 10, Color(1, 1, 1, 0.4))
	draw_circle(knob_pos, 42, Color(1, 1, 1, 0.28))
	draw_arc(knob_pos, 42, 0, TAU, 48, Color(1, 1, 1, 0.5), 4.0)

func set_joy(bp: Vector2, kp: Vector2):
	base_pos = bp
	knob_pos = kp
	queue_redraw()

func value() -> Vector2:
	if base_pos == Vector2.ZERO:
		return Vector2.ZERO
	return (knob_pos - base_pos) / radius