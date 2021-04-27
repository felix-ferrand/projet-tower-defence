extends Node2D
class_name Spawner

export (int) var money = 100
export (int) var money_per_wave = 100
export (int) var money_increase_per_wave = 100
export (int) var spawner_index = 0
export var units = []
var wave = {}
var spawn_index = 0
var wave_timer: Timer
var spawn_timer: Timer
var restart_timer: Timer
var world: Node

func _ready():
	world = get_node("..")
	wave_timer = Timer.new()
	wave_timer.one_shot = true
	wave_timer.connect("timeout", self, "_on_wave_timer")
	add_child(wave_timer)
	spawn_timer = Timer.new()
	spawn_timer.connect("timeout", self, "_on_spawn_timer")
	add_child(spawn_timer)
	restart_timer = Timer.new()
	restart_timer.connect("timeout", self, "_start_wave")
	add_child(restart_timer)
	_start_wave()
	world.spawners.append(self)
	get_node("/root/Main").connect("state_change", self, "_on_game_state")
	
func _create_wave():
	# add money to the spawner
	money += money_per_wave + (money_increase_per_wave * world.wave_index)
	
	# generate wave dict
	wave = {
		"enemies": [],
		"wait": 5.0
	}
	
	var units_to_use = []
	
	# for the first waves : only one unit type to teach the player how they work
	if world.wave_index < units.size():
		units_to_use.append(units[2])

	# detect player defences and select which units_to_use
	else:
		# get player defences
		var defences = get_node("..").defences
		
		# add unit to use depending on defences
		if "blue-tower" in defences:
			units_to_use.append(units[1])
		if "red-tower" in defences:
			units_to_use.append(units[0])
		
		if units_to_use.empty():
			units_to_use.append(units[0])
	
	# select from the units to use, while checking the price
	while money >= 50:
		var selected_unit = units_to_use[randi() % units_to_use.size()].instance()
		if (selected_unit.price > money):
			selected_unit = units[0].instance()
		money -= selected_unit.price
		wave.enemies.append(selected_unit)
	
func _start_wave():
	# for the first waves : the Spawner activates one after the other
	if world.wave_index >= spawner_index * 3:
		_create_wave()
		spawn_timer.stop()
		wave_timer.start(wave.wait)
		print_debug("Wave %s starting in %s seconds" % [world.wave_index + 1, wave.wait])
	else:
		restart_timer.start(10)

func _on_wave_timer():
	var interval = randi() % 4 + 1
	spawn_timer.start(interval)
	print_debug("Wave %s!" % (world.wave_index + 1))
	
func _on_spawn_timer():
	if spawn_index < wave.enemies.size():
		var enemy = wave.enemies[spawn_index]
		world.add_enemy(enemy)
		enemy.position = position
		enemy.z_index = position.y
		spawn_index += 1
	if world.enemies.size() == 0:
		spawn_index = 0
		if spawner_index == 0:
			world.wave_index += 1
		_start_wave()
		
func _on_game_state(state):
	if state != "playing":
		wave_timer.stop()
		spawn_timer.stop()
