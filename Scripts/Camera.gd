extends Camera2D

var target: Node2D

func _process(delta):
	if is_instance_valid(target):
		position = Vector2(floor(target.position.x), floor(target.position.y))
