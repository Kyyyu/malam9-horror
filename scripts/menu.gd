extends Control
class_name MenuScreen

signal started(level: int)
signal lobby_requested

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.01, 0.05, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.4, 0.1, 0.35, 0.10)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var title := Label.new()
	title.text = "MALAM 9"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(0.85, 0.88, 1))
	title.add_theme_color_override("font_shadow_color", Color(0.6, 0, 0.4, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "· H O R O R  3 D ·"
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var start := Button.new()
	start.text = "LEVEL 1"
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.custom_minimum_size = Vector2(360, 88)
	start.add_theme_font_size_override("font_size", 40)
	start.pressed.connect(func(): started.emit(1))
	start.add_theme_stylebox_override("normal", _style(Color(0.55, 0.12, 0.2, 0.9)))
	start.add_theme_stylebox_override("hover", _style(Color(0.7, 0.16, 0.25, 0.95)))
	start.add_theme_stylebox_override("pressed", _style(Color(0.35, 0.08, 0.14, 1)))
	vbox.add_child(start)

	var start2 := Button.new()
	start2.text = "LEVEL 2"
	start2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start2.custom_minimum_size = Vector2(360, 88)
	start2.add_theme_font_size_override("font_size", 40)
	start2.pressed.connect(func(): started.emit(2))
	start2.add_theme_stylebox_override("normal", _style(Color(0.4, 0.14, 0.3, 0.9)))
	start2.add_theme_stylebox_override("hover", _style(Color(0.55, 0.2, 0.4, 0.95)))
	start2.add_theme_stylebox_override("pressed", _style(Color(0.25, 0.08, 0.2, 1)))
	vbox.add_child(start2)

	var hint := Label.new()
	hint.text = "Temukan 3 kunci lalu kabur sebelum HANTU menangkapmu..."
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.custom_minimum_size = Vector2(520, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.65, 0.6, 0.7))
	vbox.add_child(hint)

	var mabar := Button.new()
	mabar.text = "MABAR (LAN)"
	mabar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mabar.custom_minimum_size = Vector2(360, 76)
	mabar.add_theme_font_size_override("font_size", 34)
	mabar.add_theme_stylebox_override("normal", _style(Color(0.35, 0.3, 0.1, 0.9)))
	mabar.add_theme_stylebox_override("hover", _style(Color(0.48, 0.42, 0.15, 0.95)))
	mabar.add_theme_stylebox_override("pressed", _style(Color(0.2, 0.17, 0.06, 1)))
	mabar.pressed.connect(func(): lobby_requested.emit())
	vbox.add_child(mabar)

	var ofl := Label.new()
	ofl.text = "BERTANDING: 1 jadi HANTU · lain jadi MANUSIA · WiFi sama"
	ofl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ofl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ofl.add_theme_font_size_override("font_size", 20)
	ofl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.3))
	vbox.add_child(ofl)

	var ctrl := Label.new()
	ctrl.text = "- Gerak: drag kiri / WASD / stik kiri\n- Lihat: drag kanan / mouse / stik kanan\n- Lari: joystick full / Shift / tombol A\n- Senter: tombol kanan bawah / F / tombol X"
	ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ctrl.custom_minimum_size = Vector2(540, 0)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.add_theme_font_size_override("font_size", 22)
	ctrl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.5))
	vbox.add_child(ctrl)

	var anim := create_tween()
	title.modulate.a = 0.0
	anim.tween_property(title, "modulate:a", 1.0, 1.2)
	start.modulate.a = 0.0
	anim.parallel().tween_property(start, "modulate:a", 1.0, 1.2)

func _style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	s.corner_radius_bottom_left = 16
	s.corner_radius_bottom_right = 16
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = Color(1, 1, 1, 0.15)
	return s