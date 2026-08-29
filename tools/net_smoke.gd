extends SceneTree

var _role := "host"
var _net: Node = null
var _t := 0.0
var _joined := false
var _got_pos := 0
var _got_echo := 0
var _got_keys := false
var _got_end := false
var _sent_pos := false
var _wrote_pass := false

class Driver extends Node:
	var host: SceneTree
	func _process(delta: float):
		host._tick(delta)

func _initialize():
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--role="):
			_role = a.get_slice("=", 1)
	var d := Driver.new()
	d.host = self
	root.add_child(d)
	_net = (load("res://scripts/net.gd") as GDScript).new()
	_net.name = "NetTest"
	root.add_child(_net)
	if _role == "host":
		var err: int = _net.start_host()
		print("NET_SMOKE host bind err=", err, " status=", _net.peer.get_connection_status())
		_net.listen(_net.OP_POS, _on_pos)
	else:
		print("NET_SMOKE client ready; waiting to connect")
		_net.listen(_net.OP_START, _on_start)
		_net.listen(_net.OP_KEYS, _on_keys)
		_net.listen(_net.OP_END, _on_end)
		_net.listen(_net.OP_POS, _on_pos)

func _on_start(_sender: int, _pkt: PackedByteArray):
	print("NET_SMOKE CLIENT: got START")
	if _sent_pos:
		return
	_sent_pos = true
	var b := PackedByteArray()
	b.append_array(PackedInt32Array([_net.my_id()]).to_byte_array())
	b.append_array(PackedFloat32Array([3.0, 1.0, 4.0, 0.25]).to_byte_array())
	_net.send(_net.OP_POS, b)

func _on_pos(sender: int, pkt: PackedByteArray):
	if _role == "host":
		_got_pos += 1
		_net.send(_net.OP_POS, pkt, PackedInt32Array([sender]))
	else:
		_got_echo += 1

func _on_keys(_sender: int, pkt: PackedByteArray):
	var arr := pkt.to_int32_array()
	if arr.size() >= 1 and arr[0] == 5:
		_got_keys = true
		print("NET_SMOKE CLIENT: got KEYS mask=", arr[0])

func _on_end(_sender: int, pkt: PackedByteArray):
	if _role == "client":
		var w := 0
		if pkt.size() >= 1:
			w = pkt[0]
		print("NET_SMOKE CLIENT: got END win=", w)
		if _got_keys:
			_write_pass()
			quit(0)

func _tick(delta: float):
	_t += delta
	if int(_t * 1.0) % 2 == 0 and _last_log != int(_t * 0.5):
		_last_log = int(_t * 0.5)
		var st := -1
		if _net.peer:
			st = _net.peer.get_connection_status()
		print("NET_SMOKE[", _role, "] t=", _t, " status=", st, " pos=", _got_pos, " echo=", _got_echo)
	if _role == "client" and not _joined and _t > 1.0:
		_joined = true
		var err: int = _net.join("127.0.0.1")
		print("NET_SMOKE CLIENT: join err=", err, " status=", _net.peer.get_connection_status())
	if _role == "host":
		if _t > 2.5 and not _sent_start:
			_sent_start = true
			_net.send(_net.OP_START, PackedByteArray([1]))
			print("NET_SMOKE HOST: sent START")
		if _got_pos > 0 and not _dispatched_end():
			_dispatched = true
			var b := PackedInt32Array([5]).to_byte_array()
			_net.send(_net.OP_KEYS, b)
			_net.send(_net.OP_END, PackedByteArray([1]))
			print("NET_SMOKE HOST: sent KEYS+END after pos=", _got_pos)
	if _t > 30.0:
		print("NET_SMOKE_FAIL: timeout ", _role, " pos=", _got_pos, " echo=", _got_echo, " keys=", _got_keys, " end=", _got_end)
		quit(1)
	if _role == "host" and _file_exists("/tmp/netsmoke_pass"):
		print("NET_SMOKE_OK (host sees pass)")
		quit(0)

var _dispatched := false
var _sent_start := false
var _last_log := -1

func _dispatched_end() -> bool:
	return _dispatched

func _file_exists(p: String) -> bool:
	return FileAccess.file_exists(p)

func _write_pass():
	if _wrote_pass:
		return
	_wrote_pass = true
	var f := FileAccess.open("/tmp/netsmoke_pass", FileAccess.WRITE)
	if f:
		f.store_string("ok")
	print("NET_SMOKE_OK (client)")
	print("PASS_WRITTEN")