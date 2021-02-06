extends Node
class_name NetworkTransform

# Only the master of this node will broadcast the location of its parent
# Every SYNC_PERIOD seconds. All puppets (non-master) will move their
# parents to the location the master sent.

const SYNC_PERIOD: float = 0.1

onready var sync_time_left: float = SYNC_PERIOD
puppet var net_position: Vector2
puppet var net_rotation: float
var parent: Node2D

func _ready() -> void:
	parent = get_parent() as Node2D

func _process(delta: float) -> void:
	if is_network_master():
		sync_time_left -= delta
		if sync_time_left < 0:
			sync_time_left = SYNC_PERIOD
			rset_unreliable("net_position", parent.position)
			rset_unreliable("net_rotation", parent.rotation)
	else:
		var multiplier = delta/SYNC_PERIOD
		parent.position += (net_position - parent.position)*multiplier
		parent.rotation += \
			Utils.angle_difference(parent.rotation, net_rotation)*multiplier
