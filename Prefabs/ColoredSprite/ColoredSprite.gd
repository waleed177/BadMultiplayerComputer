extends Sprite

remotesync var _color setget _set_color, _get_color
func _set_color(val): modulate = val
func _get_color(): return modulate

func _enter_tree():
	get_parent().besh.bind_color_property("color", self, "_color", true)
