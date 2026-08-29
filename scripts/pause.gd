extends CanvasLayer

class_name PauseOverlay

signal restart_requested
signal exit_requested

var host: Node = null

func _ready():
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var rg := ColorRect.new()
	rg.color = Color(0, 0, 0, 0.72)
	rg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSE"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Hantu berhenti... sementara."
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var resume := _btn("LANJUT", 46)
	var restart := _btn("ULANG LEVEL", 32)
	var quit := _btn("KELUAR", 32)
	vbox.add_child(resume)
	vbox.add_child(restart)
	vbox.add_child(quit)
	resume.pressed.connect(func(): toggle())
	restart.pressed.connect(func(): _leave(true))
	quit.pressed.connect(func(): _leave(false))

func _btn(text: String, fs: int) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(360, 96)
	b.add_theme_font_size_override("font_size", fs)
	return b

func toggle():
	if not host or not host.running:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	visible = paused

func _leave(do_restart: bool):
	get_tree().paused = false
	visible = false
	if do_restart:
		restart_requested.emit()
	else:
		exit_requested.emit()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if host and host.running:
			toggle()
			get_viewport().set_input_as_handled()