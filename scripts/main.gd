extends Node

var screen: Node = null
var music: AudioStreamPlayer = null
var _level := 1

func _ready():
	_setup_music()
	_show_menu()

func _setup_music():
	music = AudioStreamPlayer.new()
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	var stream: AudioStream = null
	for cand in ["res://audio/bersenja_gurau.mp3", "res://audio/bersenja_gurau.ogg", "res://audio/bersenja_gurau.wav"]:
		if ResourceLoader.exists(cand):
			stream = load(cand)
			break
	if stream == null:
		var gurau := load("res://audio/musik_gurau.wav") as AudioStreamWAV
		if gurau:
			gurau.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream = gurau
	if stream == null:
		var wav := load("res://audio/music_loop.wav") as AudioStreamWAV
		if wav:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream = wav
	if stream:
		music.stream = stream
		music.volume_db = -8.0
		add_child(music)
		music.play()

func _clear():
	if screen:
		screen.queue_free()
		screen = null
	get_tree().paused = false

func _show_menu():
	_clear()
	var m: MenuScreen = MenuScreen.new()
	add_child(m)
	screen = m
	m.started.connect(func(lv: int):
		_level = lv
		_start_game())

func _start_game():
	_clear()
	var g: GameScreen = GameScreen.new()
	g.level = _level
	add_child(g)
	screen = g
	g.ended.connect(_on_game_ended)
	g.exit_requested.connect(_show_menu)
	g.restart_requested.connect(_start_game)

func _on_game_ended(is_win: bool):
	_clear()
	var e: EndScreen = EndScreen.new()
	e.set_result(is_win)
	add_child(e)
	screen = e
	e.retry_pressed.connect(_start_game)
	e.menu_pressed.connect(_show_menu)