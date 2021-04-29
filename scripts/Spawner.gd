extends Node2D
class_name Spawner

export (int) var money = 100
export (int) var money_per_wave = 100
export (int) var money_increase_per_wave = 100
export (int) var spawner_index = 0
export var units = []
var wave = {}
var spawn_index = 0
var spawn_timer: Timer
var world: Node

func _ready():
	world = get_node("..")
	world.spawners.append(self)
	
	spawn_timer = Timer.new()
	spawn_timer.connect("timeout", self, "_on_spawn_timer")
	add_child(spawn_timer)
	
	get_node("/root/Main").connect("state_change", self, "_on_game_state")
	
func _create_wave():
	print_debug("Spawner %s" % spawner_index)
	
	# add money to the spawner
	money += money_per_wave + money_increase_per_wave * world.wave_index
	print_debug("Money = %s" % money)
	
	# generate wave array
	wave = []
	
	var units_to_use = []
	
	# for the first waves : only one unit type to teach the player how they work
	if world.wave_index < units.size():
		units_to_use.append(units[world.wave_index]);

	# detect player defences and select which units_to_use
	else:
		# get player defences
		var defences = get_node("..").defences
		
		# add unit to use depending on defences
		if "blue-tower" in defences:
			units_to_use.append(units[0])
			units_to_use.append(units[2])
		if "red-tower" in defences:
			units_to_use.append(units[1])
			units_to_use.append(units[3])
		
		if units_to_use.empty():
			units_to_use.append(units[0])
	
	# select from the units to use, while checking the price
	while money >= 50:
		var selected_unit = units_to_use[randi() % units_to_use.size()].instance()
		if (selected_unit.price > money):
			selected_unit = units[0].instance()
		money -= selected_unit.price
		wave.append(selected_unit)

func _start_wave():
	var interval = randi() % 3 + 1
	spawn_timer.start(interval)
	print_debug("Wave %s!" % (world.wave_index + 1))

func _on_spawn_timer():
	if spawn_index < wave.size():
		var enemy = wave[spawn_index]
		world.add_enemy(enemy)
		enemy.position = position
		enemy.z_index = position.y
		spawn_index += 1
		
func _on_game_state(state):
	if state != "playing":
		world.wave_timer.stop()
		spawn_timer.stop()
