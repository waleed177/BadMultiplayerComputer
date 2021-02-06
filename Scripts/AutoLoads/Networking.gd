extends Node2D
# Manages connecting or hosting a server
# And checking if the game is ready
# Its an autoload to access the folowing:
#	the signals
#	players_info
#	my_info
# 		id: int
# 		name: String
# 		ready: bool
#	my_id

signal player_joined
signal player_left
signal player_ready
signal connection_success
signal game_ready

const SERVER_PORT = 25565
var players_info = {}
var my_info = {}
var my_id : int

func host_server(username: String) -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(SERVER_PORT, 8)
	get_tree().network_peer = peer
	my_id = 1
	my_info.id = my_id
	_setup_my_info(username)
	players_info[1] = my_info
	emit_signal("player_joined", 1)

func join_server(ip_address: String, username: String) -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip_address, SERVER_PORT)
	get_tree().network_peer = peer
	_setup_my_info(username)

#Sets up my info for both client and server.
func _setup_my_info(username: String):
	my_info.ready = false
	my_info.name = username

func _ready() -> void:
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

func _player_connected(id : int) -> void:
	rpc_id(id, "register_player", my_info)

func _player_disconnected(id : int) -> void:
	players_info.erase(id) # Erase player from info.
	emit_signal("player_left", id)

func _connected_ok() -> void:
	my_id = get_tree().get_network_unique_id()
	my_info.id = my_id
	players_info[my_id] = my_info
	emit_signal("connection_success", true)
	emit_signal("player_joined", my_id)
	
func _server_disconnected() -> void:
	pass # Server kicked us; TODO: show error and abort.

func _connected_fail() -> void:
	emit_signal("connection_success", false)

remote func register_player(info: Dictionary) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	info.id = sender_id #To avoid faking the id.
	players_info[sender_id] = info
	emit_signal("player_joined", sender_id)

func set_ready(ready: bool) -> void:
	rpc("player_is_ready", ready)

remotesync func player_is_ready(ready: bool) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	players_info[sender_id].ready = ready
	emit_signal("player_ready", sender_id, ready)
	
	# If everyone is ready, then signal that the game is ready.
	var game_ready = true
	for player_id in players_info:
		var player = players_info[player_id]
		if !player.ready:
			game_ready = false
			break
	if game_ready:
		emit_signal("game_ready")
