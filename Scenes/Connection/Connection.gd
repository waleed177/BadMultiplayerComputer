extends Node2D

func _ready():
	Networking.connect("game_ready", self, "_on_game_ready")

func _on_game_ready():
	SceneManager.change_scene("res://Scenes/Game/Game.tscn")
	
