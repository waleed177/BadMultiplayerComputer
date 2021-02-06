extends Panel

remotesync var _text: String setget _set_text, _get_text
func _set_text(val): $RichTextLabel.bbcode_text = str(val)
func _get_text(): return $RichTextLabel.bbcode_text

func _ready():
	var besh = get_parent().besh
	besh.bind_property("text", self, "_text", true)\
	

func _on_RichTextLabel_gui_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		get_parent()._on_GameObject_input_event(null, event, null)
