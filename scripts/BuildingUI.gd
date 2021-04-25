extends HBoxContainer

export (NodePath) var building_item
var main

# Called when the node enters the scene tree for the first time.
func _ready():
	main = get_node("/root/Main")
	for index in range(main.towers.size()):
		var button = get_node(building_item).duplicate()
		add_child(button)
		button.get_node("VBoxContainer/Label").text = main.towers[index].name
		button.get_node("VBoxContainer/HBoxContainer/Label").text = String(main.towers[index].cost)
		button.connect("pressed", self, "_on_button", [index])
	for indexMedic in range(main.medics.size()):
		var button = get_node(building_item).duplicate()
		add_child(button)
		button.get_node("VBoxContainer/Label").text = main.medics[indexMedic].name
		button.get_node("VBoxContainer/HBoxContainer/Label").text = String(main.medics[indexMedic].cost)
		button.connect("pressed", self, "_on_button_medic", [indexMedic])
		get_node(building_item).queue_free()
		
func _on_button(index):
	main.tower_index = index
	main.type_building = 'tower'
	
func _on_button_medic(indexMedic):
	main.medic_index = indexMedic
	main.type_building = 'medic'
