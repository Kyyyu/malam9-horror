extends Control
class_name LobbyScreen

signal host_begin
signal client_begin
signal back_pressed

var _status: Label = null
var _ip_input: LineEdit = null
var _mulai_btn: Button = null
var _col: int = 0

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.01, 0.05, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := Label.new()
	title.text = "MABAR (LAN)"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	title.add_theme_color_override("font_shadow_color", Color(0.5, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Satu pemain jadi HANTU, yang lain jadi MANUSIA.\nSemua harus terhubung ke WiFi/hotspot yang sama."
	info.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info.custom_minimum_size = Vector2(560, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", Color(0.7, 0.65, 0.75))
	vbox.add_child(info)

	var host_btn := Button.new()
	host_btn.text = "JADI HANTU (HOST)"
	host_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host_btn.custom_minimum_size = Vector2(400, 76)
	host_btn.add_theme_font_size_override("font_size", 32)
	host_btn.add_theme_stylebox_override("normal", _style(Color(0.55, 0.12, 0.2, 0.9)))
	host_btn.add_theme_stylebox_override("hover", _style(Color(0.7, 0.16, 0.25, 0.95)))
	host_btn.add_theme_stylebox_override("pressed", _style(Color(0.35, 0.08, 0.14, 1)))
	host_btn.pressed.connect(_on_host)
	vbox.add_child(host_btn)

	var sep := Label.new()
	sep.text = "— atau gabung —"
	sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sep.add_theme_font_size_override("font_size", 22)
	sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(sep)

	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "IP HOST, contoh: 192.168.1.5"
	_ip_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ip_input.custom_minimum_size = Vector2(440, 64)
	_ip_input.add_theme_font_size_override("font_size", 28)
	_ip_input.text = "192.168."
	vbox.add_child(_ip_input)

	var join_btn := Button.new()
	join_btn.text = "GABUNG SEBAGAI MANUSIA"
	join_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	join_btn.custom_minimum_size = Vector2(400, 76)
	join_btn.add_theme_font_size_override("font_size", 30)
	join_btn.add_theme_stylebox_override("normal", _style(Color(0.2, 0.35, 0.5, 0.9)))
	join_btn.add_theme_stylebox_override("hover", _style(Color(0.26, 0.44, 0.6, 0.95)))
	join_btn.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.22, 0.33, 1)))
	join_btn.pressed.connect(_on_join)
	vbox.add_child(join_btn)

	_mulai_btn = Button.new()
	_mulai_btn.text = "MULAI (khusus HOST)"
	_mulai_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mulai_btn.custom_minimum_size = Vector2(400, 76)
	_mulai_btn.add_theme_font_size_override("font_size", 30)
	_mulai_btn.add_theme_stylebox_override("normal", _style(Color(0.35, 0.3, 0.12, 0.9)))
	_mulai_btn.add_theme_stylebox_override("hover", _style(Color(0.45, 0.4, 0.16, 0.95)))
	_mulai_btn.add_theme_stylebox_override("pressed", _style(Color(0.22, 0.18, 0.08, 1)))
	_mulai_btn.pressed.connect(_on_start)
	_mulai_btn.disabled = true
	vbox.add_child(_mulai_btn)

	_status = Label.new()
	_status.text = "Pilih peran di atas."
	_status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status.custom_minimum_size = Vector2(560, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_status)

	var ip := Label.new()
	ip.text = "IP perangkat ini: %s" % _local_ip()
	ip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ip.add_theme_font_size_override("font_size", 22)
	ip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.5))
	vbox.add_child(ip)

	var back := Button.new()
	back.text = "KEMBALI"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(200, 60)
	back.add_theme_font_size_override("font_size", 26)
	back.add_theme_stylebox_override("normal", _style(Color(0.25, 0.2, 0.28, 0.9)))
	back.add_theme_stylebox_override("hover", _style(Color(0.35, 0.28, 0.38, 0.95)))
	back.add_theme_stylebox_override("pressed", _style(Color(0.15, 0.12, 0.17, 1)))
	back.pressed.connect(func(): back_pressed.emit())
	vbox.add_child(back)

	Net.unlisten(Net.OP_START, _on_start_cmd)
	Net.listen(Net.OP_START, _on_start_cmd)

func _exit_tree():
	Net.unlisten(Net.OP_START, _on_start_cmd)

func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if a != "127.0.0.1" and "." in a and not a.begins_with("169.254"):
			return a
	return "0.0.0.0"

func _on_host():
	if Net.started():
		return
	var err := Net.start_host()
	if err != OK:
		_status.text = "Gagal buka ruangan: %d" % err
		return
	_mulai_btn.disabled = false
	_status.text = "RUANGAN DIBUKA. Bagikan IP: %s\nTekan MULAI saat pemain lain sudah gabung." % _local_ip()

func _on_join():
	if Net.started():
		return
	var ip := _ip_input.text.strip_edges()
	if ip == "" or ip == "192.168.":
		_status.text = "Masukkan IP host dulu."
		return
	var err := Net.join(ip)
	if err != OK:
		_status.text = "Tidak bisa terhubung ke %s (%d)" % [ip, err]
		return
	_status.text = "MENGHUBUNGKAN ke %s... Menunggu HOST tekan MULAI..." % ip

func _on_start():
	if not Net.started():
		return
	Net.send(Net.OP_START, PackedByteArray([1]))
	_status.text = "MENUJU KE RUANGAN..."
	host_begin.emit()

func _on_start_cmd(_sender: int, _pkt: PackedByteArray):
	_status.text = "HOST MULAI! MENUJU KE RUANGAN..."
	client_begin.emit()

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