extends Node2D

signal all_cars_placed
signal network_game_ready

const Player = preload("res://Prefabs/Player/Player.tscn")
var client_not_ready_set = {}

func _ready():
	#Spawn all the players
	for player_id in Networking.players_info:
		var player_info = Networking.players_info[player_id]
		var player_car = Player.instance()
		player_car.set_network_master(player_id, true)
		player_car.setup(player_info)
		$Players.add_child(player_car)
		
		if Networking.my_id == 1:
			client_not_ready_set[player_id] = true
	
	$Camera.target = $Players.get_node(str(Networking.my_id))

func show_script_editor_for(obj):
	$CanvasLayer/ScriptEditor.edit_script_for(obj)
