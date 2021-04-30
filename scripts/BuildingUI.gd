extends HBoxContainer

export (NodePath) var building_item
var main
export var labels_cost_tower = []
export var labels_cost_medic = []

# Called when the node enters the scene tree for the first time.
func _ready():
	main = get_node("/root/Main")
	for index in range(main.towers.size()):
		var button = get_node(building_item).duplicate()
		add_child(button)
		button.get_node("VBoxContainer/Label").text = main.towers[index].name
		button.get_node("VBoxContainer/HBoxContainer/Label").text = String(main.towers[index].cost)
		button.connect("pressed", self, "_on_button", [index])
		labels_cost_tower.append(button.get_node("VBoxContainer/HBoxContainer/Label"))
		get_node(building_item).queue_free()
	for indexWizard in range(main.medics.size()):
		var button = get_node(building_item).duplicate()
		add_child(button)
		button.get_node("VBoxContainer/Label").text = main.medics[indexWizard].name
		button.get_node("VBoxContainer/HBoxContainer/Label").text = String(main.medics[indexWizard].cost)
		button.connect("pressed", self, "_on_button_medic", [indexWizard])
		labels_cost_medic.append(button.get_node("VBoxContainer/HBoxContainer/Label"))
		get_node(building_item).queue_free()
		
func _on_button(index):
	main.tower_index = index
	main.type_building = 'tower'
	
func _on_button_medic(indexWizard):
	main.medic_index = indexWizard
	main.type_building = 'medic'
	
func increase_cost_tower():
	for label_cost in labels_cost_tower:
		label_cost.text = str(float(label_cost.text) + 20)
	
func decrease_cost_tower():
	for label_cost in labels_cost_tower:
		label_cost.text = str(float(label_cost.text) - 20)
		
func increase_cost_medic():
	for label_cost in labels_cost_medic:
		label_cost.text = str(float(label_cost.text) + 20)
	
func decrease_cost_medic():
	for label_cost in labels_cost_medic:
		label_cost.text = str(float(label_cost.text) - 20)
