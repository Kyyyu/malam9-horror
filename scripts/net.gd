extends Node

const PORT := 29333

const OP_POS := 1
const OP_KEY_PICK := 2
const OP_KEYS := 3
const OP_CATCH := 4
const OP_WIN_REQ := 5
const OP_END := 6
const OP_START := 7

var peer: ENetMultiplayerPeer = null
var is_host := false

var _known_peers := PackedInt32Array()
var _listeners := {}  # opcode -> Array[Callable]

func note_peer(id: int):
	if id <= 1:
		return
	if id not in _known_peers:
		_known_peers.append(id)
		_known_peers.sort()

func _process(_delta: float):
	if peer == null:
		return
	peer.poll()
	if peer.get_connection_status() != ENetMultiplayerPeer.CONNECTION_CONNECTED:
		return
	while peer.get_available_packet_count() > 0:
		var pkt := peer.get_packet()
		var sender := peer.get_packet_peer()
		if sender != 1 and sender != 0:
			note_peer(sender)
		if pkt.is_empty():
			continue
		var op: int = pkt[0]
		if _listeners.has(op):
			for cb in _listeners[op]:
				cb.call(sender, pkt.slice(1))

func listen(op: int, cb: Callable):
	if not _listeners.has(op):
		_listeners[op] = []
	if cb not in _listeners[op]:
		_listeners[op].append(cb)

func unlisten(op: int, cb: Callable):
	if _listeners.has(op):
		_listeners[op].erase(cb)

func my_id() -> int:
	if peer == null:
		return 1
	return peer.get_unique_id()

func host_id() -> int:
	return 1

func start_host() -> int:
	if peer:
		cleanup()
	peer = ENetMultiplayerPeer.new()
	var ok := peer.create_server(PORT)
	if ok != OK:
		cleanup()
		return ERR_CANT_CREATE
	is_host = true
	if peer.get_connection_status() != ENetMultiplayerPeer.CONNECTION_CONNECTED:
		cleanup()
		return ERR_CANT_CREATE
	return OK

func join(ip: String) -> int:
	if peer:
		cleanup()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	is_host = false
	return err

func started() -> bool:
	return peer != null and peer.get_connection_status() == ENetMultiplayerPeer.CONNECTION_CONNECTED

func connected_peers() -> PackedInt32Array:
	return _known_peers

func send(op: int, payload := PackedByteArray(), targets: PackedInt32Array = PackedInt32Array()):
	if peer == null or not started():
		return
	var out := PackedByteArray([op])
	out.append_array(payload)
	if targets.is_empty():
		if is_host:
			peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
			peer.put_packet(out)
		else:
			peer.set_target_peer(1)
			peer.put_packet(out)
	else:
		for id in targets:
			peer.set_target_peer(id)
			peer.put_packet(out)

func cleanup():
	if peer:
		peer.close()
		peer = null
	is_host = false
	_known_peers = PackedInt32Array()
	_listeners.clear()