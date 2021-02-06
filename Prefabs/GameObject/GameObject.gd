extends Node2D
class_name GameObject

var besh: Besh
var code: String setget set_code

func _enter_tree():
	set_network_master(1, true)
	besh = Besh.new()
	code = ""

func _ready():
	besh.bind_vector2_property("position", self, "position", false)
	besh.setup(get_tree())
	
func set_code(value):
	besh.compile(value)
	code = value
	rpc("_remote_set_code", value)

remote func _remote_set_code(value):
	besh.compile(value)
	code = value

func _on_GameObject_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton && event.is_pressed():
		if event.button_index == BUTTON_LEFT:
			rpc_id(1, "_execute")
		else:
			get_tree().current_scene.show_script_editor_for(self)
			
remotesync func _execute():
	besh.execute()
