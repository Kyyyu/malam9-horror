extends Control
class_name EndScreen

signal retry_pressed
signal menu_pressed

var is_win := false

func set_result(win: bool):
	is_win = win

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var title := Label.new()
	if is_win:
		title.text = "KAMU BERHASIL LARI"
		title.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	else:
		title.text = "TERTANGKAP HANTU..."
		title.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	vbox.add_child(title)

	var msg := Label.new()
	if is_win:
		msg.text = "Kamu berhasil lolos dari rumah itu sebelum jam 12 malam.\nBersih... untuk sekarang."
	else:
		msg.text = "Hantu itu tidak akan membiarkanmu pergi.\nMalam 9, kamu tidak selamat."
	msg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	msg.custom_minimum_size = Vector2(520, 0)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", Color(0.75, 0.7, 0.8))
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	var retry := Button.new()
	retry.text = "COBA LAGI"
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.custom_minimum_size = Vector2(320, 88)
	retry.add_theme_font_size_override("font_size", 40)
	retry.pressed.connect(func(): retry_pressed.emit())
	vbox.add_child(retry)

	var back := Button.new()
	back.text = "MENU UTAMA"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(320, 88)
	back.add_theme_font_size_override("font_size", 34)
	back.pressed.connect(func(): menu_pressed.emit())
	vbox.add_child(back)