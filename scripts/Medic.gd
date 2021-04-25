extends TileMapEntity
class_name Medic

var menu_index

# Called when the node enters the scene tree for the first time.
func _ready():
	collision_layer = 0b10
	collision_mask = 0
