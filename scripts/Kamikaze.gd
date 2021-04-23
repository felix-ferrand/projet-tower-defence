extends Area2D
class_name Kamikaze

export (float) var speed = 1
export (float) var hitpoints = 20
export (float) var damage_points = 20
export (String) var dijkstra
export (int) var reward = 30
var destination
var target
var world

func _process(delta):
	if !dijkstra:
		print_debug("no dijkstra map assigned!")
		return
	z_index = position.y
	if get_node("/root/Main").state != "playing": return
	if world.dijkstra.has(dijkstra):
		var tile_map = world.tile_map
		var distance = 0
		if destination:
			distance = position.distance_to(destination)
			target = world.dijkstra[dijkstra]
			
		var tile_pos = tile_map.world_to_map(position)
		var move_amount = delta * speed / world.get_cost(tile_pos)
		if (distance < move_amount):
			destination = tile_map.map_to_world(world.dijkstra[dijkstra].get_next(tile_pos))
			
		position = position.move_toward(destination, move_amount)
		
		if position == destination:
			for tower in world.entity_tab: 
				print(tower)
				if tower && tower.position == Vector2(target.destinations[0].x, target.destinations[0].y): 
					give_damage(tower.tower)

		
func take_damage(amount):
	hitpoints -= amount
	if (hitpoints <= 0):
		queue_free()
		var main = get_node("/root/Main")
		# on donne la récompense au joueur pour avoir tué un ennemi
		main.money += reward

			
func give_damage(target):
	print(target.hitpoints)	 
	if target.has_method("take_damage"): 
		target.take_damage(damage_points)
		print(target.hitpoints)	
		
	queue_free()		
		
func _exit_tree():
	world.remove_enemy(self)
