extends CanvasLayer

func _ready():
	Networking.connect("player_joined", self, "_on_player_list_changed")
	Networking.connect("player_left", self, "_on_player_list_changed")
	Networking.connect("player_ready", self, "_on_player_ready")
	Networking.connect("connection_success", self, "_on_connection_success")

# Login Screen
func _on_HostServer_pressed():
	Networking.host_server($Login/Username.text)
	$Login.visible = false
	$WaitingScreen.visible = true

func _on_JoinServer_pressed():
	Networking.join_server($Login/IP.text, $Login/Username.text)

func _on_connection_success(success):
	#client
	if(success):
		$Login.visible = false
		$WaitingScreen.visible = true
	else:
		print("Error cannot connect.") #TODO: Make a UI for this error

# Waiting Screen
func _on_player_ready(player_id: int, player_ready: bool) -> void:
	_refresh_waiting_screen()

func _on_player_list_changed(id: int) -> void:
	_refresh_waiting_screen()

func _refresh_waiting_screen():
	$WaitingScreen/PlayerList.clear()
	for player_id in Networking.players_info:
		var player = Networking.players_info[player_id]
		$WaitingScreen/PlayerList.add_item(player.name + (" (ready)" if player.ready else " (not ready)"))

func _on_Ready_pressed():
	Networking.set_ready(!Networking.my_info.ready)
