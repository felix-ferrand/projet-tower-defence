extends Node2D

export var towers = []
export var medics = []
export (PackedScene) var map
var world
var state = "playing" setget state_set
var current_map
var tower_index = 0
var medic_index = 0
var type_building = ''
var money setget money_set
export var cost_update = 0
export var increase_cost = 20
export var nb_entities = 0

var building_ui = load("res://scripts/BuildingUI.gd").new()

signal state_change(state)
signal scene_change(scene)
signal money_change(amount)

func state_set(new_value):
	state = new_value
	emit_signal("state_change", state)
	
func money_set(new_value):
	money = new_value
	emit_signal("money_change", money)

func _ready():
	set_map(map)

func _unhandled_input(event):
	if !world: return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT && event.pressed && towers.size() && type_building == 'tower':
			var cost = towers[tower_index].cost
			if cost > money: return
			var new_tower = towers[tower_index].scene.instance()
			new_tower.menu_index = tower_index
			if nb_entities != 0:
				cost_update = cost + increase_cost * nb_entities
			else:
				cost_update = cost
			if money - cost_update < 0:
					return
			var entity = world.add_entity(new_tower, event.position)
			if entity: 
				money_set(money - cost_update)
				building_ui.increase_cost_tower()
				nb_entities += 1
		if event.button_index == BUTTON_LEFT && event.pressed && medics.size() && type_building == 'medic':
			var cost = medics[medic_index].cost
			if cost > money: return
			if nb_entities != 0:
				cost_update = cost + increase_cost * nb_entities
			else:
				cost_update = cost
			if money - cost_update < 0:
					return
			var new_medic = medics[medic_index].scene.instance()
			new_medic.menu_index = medic_index
			var entity = world.add_friendly(new_medic, event.position)
			if entity: 
				money_set(money - cost_update)
				building_ui.increase_cost_medic()
				nb_entities += 1
		if event.button_index == BUTTON_RIGHT && event.pressed:
			var tile_pos = world.tile_map.world_to_map(event.position)
			if tile_pos.x > 0 && tile_pos.x < world.width && tile_pos.y > 0 && tile_pos.y < world.height && world.entities[tile_pos.x][tile_pos.y]:
				var entity = world.entities[tile_pos.x][tile_pos.y]
				if entity is Tower:
					var cost = towers[entity.menu_index].cost
					if nb_entities != 0:
						cost_update = cost + increase_cost * (nb_entities - 1)
					else:
						cost_update = cost
					money_set(money + cost_update / 2)
					building_ui.decrease_cost_tower()
					world.remove_entity(entity)
					nb_entities -= 1
			var tile_map = world.get_tile_map()
	if Input.is_action_just_pressed("toggle_debug"):
		get_node("DebugDrawing").cycle()
	if Input.is_action_just_pressed("force_reload"):
		set_map(current_map)
		
func set_map(scene):
	if world: world.queue_free()
	world = scene.instance()
	current_map = scene
	money_set(world.starting_money)
	add_child(world)
	emit_signal("scene_change", world)
