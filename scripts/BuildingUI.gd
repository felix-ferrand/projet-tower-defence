extends HBoxContainer

export (NodePath) var building_item
var main
export var labels_cost = []

# Called when the node enters the scene tree for the first time.
func _ready():
	main = get_node("/root/Main")
	for index in range(main.towers.size()):
		var button = get_node(building_item).duplicate()
		add_child(button)
		button.get_node("VBoxContainer/Label").text = main.towers[index].name
		button.get_node("VBoxContainer/HBoxContainer/Label").text = String(main.towers[index].cost)
		button.connect("pressed", self, "_on_button", [index])
		labels_cost.append(button.get_node("VBoxContainer/HBoxContainer/Label"))
		print_debug(labels_cost)
	for indexWizard in range(main.medics.size()):
		var button = get_node(building_item).duplicate()
		add_child(button)
		button.get_node("VBoxContainer/Label").text = main.medics[indexWizard].name
		button.get_node("VBoxContainer/HBoxContainer/Label").text = String(main.medics[indexWizard].cost)
		button.connect("pressed", self, "_on_button_medic", [indexWizard])
		get_node(building_item).queue_free()
		
func _on_button(index):
	main.tower_index = index
	main.type_building = 'tower'
	
func _on_button_medic(indexWizard):
	main.medic_index = indexWizard
	main.type_building = 'medic'
	
func calculate_cost(label_cost, nb_entities):
	var cost = float(label_cost.text) * pow(1.5,nb_entities)
	cost = round(cost/10)*10
	return str(cost)
	
func update_cost(nb_entities):
	for label_cost in labels_cost:
		label_cost.text = calculate_cost(label_cost, nb_entities)
