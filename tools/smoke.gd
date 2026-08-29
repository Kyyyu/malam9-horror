extends SceneTree

var _level := 1
var game: GameScreen = null
var _time := 0.0

class Driver extends Node:
	var host: SceneTree
	func _process(delta: float):
		host._tick(delta)

func _initialize():
	var d := Driver.new()
	d.host = self
	root.add_child(d)
	_start_level(_level)

func _start_level(lv: int):
	if game:
		game.free()
	game = GameScreen.new()
	game.level = lv
	root.add_child(game)
	_time = 0.0

func _tick(delta: float):
	_time += delta
	if _time < 2.0:
		return
	var keys_ok := 0
	for k in game.all_keys:
		if is_instance_valid(k) and game.find_path(game.player.global_position, k.global_position).size() > 0:
			keys_ok += 1
	var ec := game._exit_cell()
	var exit_ok := game.find_path(game.player.global_position, Vector3(ec.x * 2.0 + 1.0, 0.0, ec.y * 2.0 + 1.0)).size() > 0
	var ghost := game.ghost
	ghost.activate()
	var gpath_ok := game.find_path(ghost.global_position, game.player.global_position).size() > 0
	print("LEVEL ", game.level, " keys=", keys_ok, "/", game.all_keys.size(), " exit=", exit_ok, " ghost_active=", ghost.active, " ghost_path=", gpath_ok)
	if _level == 1:
		_level = 2
		_start_level(2)
	else:
		print("SMOKE_OK")
		quit(0)