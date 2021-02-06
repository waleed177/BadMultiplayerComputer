extends Node

signal scene_changed

func change_scene(scene_path:String) -> void:
	get_tree().change_scene(scene_path)
	emit_signal("scene_changed")
