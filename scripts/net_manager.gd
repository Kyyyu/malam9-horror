extends Node

const GHOST_KIND := 1
const HUMAN_KIND := 0

var game: GameScreen = null
var keys_mask := 0
var _pos := {}          # sender_id -> Vector3
var _yaw := {}          # sender_id -> float
var _dummy := {}        # sender_id -> Node3D
var _dead := {}         # sender_id -> bool
var _stale := {}        # sender_id -> float
var _t := 0.0
var _my_id := 1
var _ended := false
var _saw_human := false

func _ready():
	_my_id = Net.my_id()
	Net.unlisten(Net.OP_POS, _on_pos)
	Net.listen(Net.OP_POS, _on_pos)
	Net.unlisten(Net.OP_KEYS, _on_keys)
	Net.listen(Net.OP_KEYS, _on_keys)
	Net.unlisten(Net.OP_CATCH, _on_catch)
	Net.listen(Net.OP_CATCH, _on_catch)
	Net.unlisten(Net.OP_KEY_PICK, _on_key_pick)
	Net.listen(Net.OP_KEY_PICK, _on_key_pick)
	Net.unlisten(Net.OP_WIN_REQ, _on_win_req)
	Net.listen(Net.OP_WIN_REQ, _on_win_req)
	Net.unlisten(Net.OP_END, _on_end)
	Net.listen(Net.OP_END, _on_end)

func _exit_tree():
	Net.unlisten(Net.OP_POS, _on_pos)
	Net.unlisten(Net.OP_KEYS, _on_keys)
	Net.unlisten(Net.OP_CATCH, _on_catch)
	Net.unlisten(Net.OP_KEY_PICK, _on_key_pick)
	Net.unlisten(Net.OP_WIN_REQ, _on_win_req)
	Net.unlisten(Net.OP_END, _on_end)

func report_end():
	if _ended:
		return
	_ended = true
	if game:
		game.on_net_end_relay()

func _physics_process(delta: float):
	if not Net.started() or not game:
		return
	_t += delta
	if _t >= 0.05:
		_t = 0.0
		_send_own()

	if Net.is_host:
		_host_logic(delta)

func _send_own():
	if not game.player:
		return
	var src := _my_id
	var pos := game.player.global_position
	var yaw := game.player.global_rotation.y
	var b := PackedByteArray()
	b.append_array(PackedInt32Array([src]).to_byte_array())
	b.append_array(PackedFloat32Array([pos.x, pos.y, pos.z, yaw]).to_byte_array())
	Net.send(Net.OP_POS, b)

func _host_logic(delta: float):
	if not game.ghost:
		return
	var gpos := game.player.global_position
	if game.ghost:
		game.ghost.global_position = gpos
		game.ghost.global_rotation.y = game.player.global_rotation.y
	for id in _pos.keys():
		if id == 1:
			continue
		if _dead.get(id, false):
			continue
		if not _pos.has(id):
			continue
		var hp: Vector3 = _pos[id]
		if hp.distance_to(gpos) < 1.35:
			_dead[id] = true
			var p := PackedInt32Array([id]).to_byte_array()
			Net.send(Net.OP_CATCH, p)
	_stale_check(delta)
	_check_all_dead()

func _check_all_dead():
	if _ended:
		return
	if not _saw_human:
		return
	var any_alive := false
	for id in _pos.keys():
		if id == 1 or _dead.get(id, false):
			continue
		any_alive = true
	if not any_alive:
		var b := PackedByteArray([0])
		Net.send(Net.OP_END, b)
		if game:
			game.on_net_end(0)

func _stale_check(delta: float):
	for id in _stale.keys():
		_stale[id] -= delta
		if _stale[id] <= 0.0 and not _dead.get(id, false):
			_dead[id] = true

func on_key_pick_local(idx: int):
	if Net.started():
		var b := PackedInt32Array([idx]).to_byte_array()
		Net.send(Net.OP_KEY_PICK, b)

func on_exit_enter_local():
	if Net.started() and keys_mask == 0b111:
		Net.send(Net.OP_WIN_REQ)

func on_pos_cb_wrapper(sender: int, pkt: PackedByteArray):
	_on_pos(sender, pkt)

func _on_pos(sender: int, pkt: PackedByteArray):
	var arr := pkt.to_int32_array()
	if arr.size() < 1:
		return
	var src: int = arr[0]
	var farr := pkt.slice(4).to_float32_array()
	if farr.size() < 4:
		return
	var pos := Vector3(farr[0], farr[1], farr[2])
	_pos[src] = pos
	_yaw[src] = farr[3]
	_stale[src] = 4.0

	if src == Net.host_id():
		if game and is_instance_valid(game.ghost):
			game.ghost.global_position = pos
			game.ghost.global_rotation.y = _yaw[src]
		return

	_saw_human = true
	if Net.is_host:
		Net.send(Net.OP_POS, pkt)
	if src == _my_id:
		return
	if not _dummy.has(src):
		_dummy[src] = _make_dummy()
		if game:
			game.add_child(_dummy[src])
	if _dummy.has(src):
		var d: Node3D = _dummy[src]
		d.global_position = pos
		d.global_rotation.y = _yaw[src]

func _make_dummy() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.7
	body.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.35)
	mat.roughness = 0.9
	body.material_override = mat
	body.position.y = 0.85
	n.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.19
	hm.height = 0.38
	head.mesh = hm
	head.position.y = 1.75
	n.add_child(head)
	return n

func _on_key_pick(sender: int, pkt: PackedByteArray):
	if not Net.is_host:
		return
	if _ended:
		return
	var arr := pkt.to_int32_array()
	if arr.size() < 1:
		return
	var idx: int = arr[0]
	if idx < 0 or idx >= 3:
		return
	keys_mask |= 1 << idx
	var b := PackedInt32Array([keys_mask]).to_byte_array()
	Net.send(Net.OP_KEYS, b)

func _on_keys(sender: int, pkt: PackedByteArray):
	var arr := pkt.to_int32_array()
	if arr.size() < 1:
		return
	var mask: int = arr[0]
	_apply_keys(mask)

func _apply_keys(mask: int):
	for i in range(3):
		var was := keys_mask & (1 << i)
		var now := mask & (1 << i)
		if now != 0 and was == 0:
			if game:
				game.register_key_net(i)
	keys_mask = mask
	if game:
		game.keys_found = popcount(keys_mask)
		game.update_objective_net()

func popcount(mask: int) -> int:
	var c := 0
	for i in range(31):
		if mask & (1 << i):
			c += 1
	return c

func _on_catch(sender: int, pkt: PackedByteArray):
	if _ended:
		return
	var arr := pkt.to_int32_array()
	if arr.size() < 1:
		return
	var target: int = arr[0]
	if target == _my_id:
		if game:
			game.on_net_caught()
	elif _dummy.has(target):
		if is_instance_valid(_dummy[target]):
			_dummy[target].queue_free()
		_dummy.erase(target)

func _on_win_req(sender: int, pkt: PackedByteArray):
	if not Net.is_host or _ended:
		return
	if keys_mask == 0b111:
		var b := PackedByteArray([1])
		Net.send(Net.OP_END, b)
		game.on_net_end(1)

func _on_end(sender: int, pkt: PackedByteArray):
	if _ended:
		return
	_ended = true
	var win := 0
	if pkt.size() >= 1:
		win = pkt[0]
	if game:
		game.on_net_end(win)