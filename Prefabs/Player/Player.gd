extends KinematicBody2D
class_name Player

signal current_lap_changed

export(float) var speed = 150
export(float) var rotation_speed = deg2rad(100)
var player_info: Dictionary

func setup(player_info: Dictionary) -> void:
	self.player_info = player_info
	name = str(player_info.id)
	$Name.text = player_info.name

func _process(delta):
	if is_network_master():
		if Input.is_action_pressed("gm_up"):
			move_and_collide(Vector2(0, -speed*delta))
		if Input.is_action_pressed("gm_down"):
			move_and_collide(Vector2(0, speed*delta))
		if Input.is_action_pressed("gm_left"):
			move_and_collide(Vector2(-speed*delta, 0))
		if Input.is_action_pressed("gm_right"):
			move_and_collide(Vector2(speed*delta, 0))
