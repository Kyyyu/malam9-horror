extends Node

var screen: Node = null

func _ready():
	_show_menu()

func _clear():
	if screen:
		screen.queue_free()
		screen = null

func _show_menu():
	_clear()
	var m: MenuScreen = MenuScreen.new()
	add_child(m)
	screen = m
	m.started.connect(_start_game)

func _start_game():
	_clear()
	var g: GameScreen = GameScreen.new()
	add_child(g)
	screen = g
	g.ended.connect(_on_game_ended)
	g.exit_requested.connect(_show_menu)

func _on_game_ended(is_win: bool):
	_clear()
	var e: EndScreen = EndScreen.new()
	e.set_result(is_win)
	add_child(e)
	screen = e
	e.retry_pressed.connect(_start_game)
	e.menu_pressed.connect(_show_menu)