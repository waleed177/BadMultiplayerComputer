extends Panel

var _obj: GameObject

func edit_script_for(obj: GameObject):
	visible = true
	_obj = obj
	$ScriptTxt.text = obj.code

func _on_CompileBtn_pressed():
	visible = false
	_obj.code = $ScriptTxt.text
