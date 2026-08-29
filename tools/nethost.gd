extends Node

var _role := "host"
var _t := 0.0
var _game: GameScreen = null
var _built := false
var _pass := false

func _ready():
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--role="):
			_role = a.get_slice("=", 1)
	_boot_or_cleanup()
	if _role == "host":
		var err := Net.start_host()
		print("NETGAME host bind=", err, " role=", _role)
	else:
		var err := Net.join("127.0.0.1")
		print("NETGAME client join=", err, " role=", _role)

func _boot_or_cleanup():
	pass

func _process(delta: float):
	_t += delta
	if not _built and _t > 1.2 and Net.started():
		_built = true
		var g := GameScreen.new()
		g.level = 1
		g.net_flag = true
		g.net_is_host_role = (_role == "host")
		add_child(g)
		_game = g
		print("NETGAME[", _role, "] game built manager=", g.net_manager != null)

	if _role == "client" and _built and not _pass and _t > 5.0:
		var gm: GameScreen = _game
		var ghost_pos := Vector3(3.0, 0.0, 3.0)
		var gd := gm.ghost.global_position if gm.ghost else Vector3.ZERO
		var cocktail := gd.distance_to(ghost_pos) < 1.2
		var caught := gm.net_flag and gm.running == false
		var scare := gm.scare_overlay != null or gm.jumped
		var ended := gm._net_ended
		var mgr := gm.get_node("NetManager")
		if cocktail and caught and ended:
			_pass = true
			print("NETGAME_CLIENT_PASS ghost_dist=", gd.distance_to(ghost_pos), " caught=", caught, " scare=", scare, " ended=", ended, " mgr=", mgr != null)
			get_tree().quit(0)

	if _role == "host" and _built and not _pass and _t > 4.0:
		var gm: GameScreen = _game
		var mgr = gm.get_node("NetManager")
		if mgr and mgr._saw_human and mgr._dead.size() > 0:
			_pass = true
			print("NETGAME_HOST_PASS dead=", mgr._dead.size(), " saw=", mgr._saw_human, " ended=", gm._net_ended)
			get_tree().quit(0)

	if _t > 25.0:
		print("NETGAME_FAIL[", _role, "]")
		get_tree().quit(1)