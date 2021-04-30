extends Node2D

export (int) var width = 64
export (int) var height = 64
export (int) var starting_money = 300
export (int) var wait_between_waves = 10
export (float) var tower_cost = 20
export var movement_costs = {}
export (PackedScene) var obstacle_entity
var entities = []
var defences = {}
var tile_map
var dijkstra = {}
var graphs = {}
var entity_lookups = {}
var spawners = []
var enemies = []
const quadrants = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
var friendlies = []
var lower_life = 0
var lower_towers = []
var wave_index = 0
var wave_timer: Timer

signal on_change

# retourner le coût de déplacement d'une case
func get_cost(pos):
	var group = tile_map.get_group(pos)
	# les cases eau et arbre ne peuvent pas être traversées
	if group == 'water' || group == 'tree': return null
	# si on a renseigné un coût pour ce type de terrain, on l'applique ici
	elif movement_costs.has(group): return movement_costs[group]
	# sinon le coût par défaut c'est 1
	return 1

# _ready est une fonction Godot qui sera invoquée à la création de l'objet
func _ready():
	# initialiser la grille des entités
	for x in range(width):
		entities.append([])
		entities[x].resize(height)
		friendlies.append([])
		friendlies[x].resize(height)
		
	# stocker une référence à la "tile map"
	tile_map = get_node("TileMap")
	
	# intialiser la grille des coûts de déplacement
	graphs['cost'] = []
	for x in range(width):
		graphs['cost'].append([])
		graphs['cost'][x].resize(height)
		for y in range(height):
			graphs['cost'][x][y] = get_cost(Vector2(x, y))
		
	# intialiser la grille des coûts de déplacement pour les medics
	graphs['cost_medic'] = []
	for x in range(width):
		graphs['cost_medic'].append([])
		graphs['cost_medic'][x].resize(height)
		for y in range(height):
			graphs['cost_medic'][x][y] = get_cost(Vector2(x, y))
		
	# initialiser la grille des coûts modifiée par les tours	
	graphs['range_cost'] = []
	for x in range(width):
		graphs['range_cost'].append([])
		graphs['range_cost'][x].resize(height)
		for y in range(height):
			graphs['range_cost'][x][y] = get_cost(Vector2(x, y))
		
	# il faut ajouter la base aux entités gérées par ce script	
	var base = get_node("Base")
	add_entity(base, base.position)
	
	# on veut déclencher la défaite si la base est détruite
	base.connect("tree_exited", self, "_on_defeat")
	
	# ajout des entités "obstacles" sur les cases destructibles
	for x in range(width):
		for y in range(height):
				var group = tile_map.get_group(Vector2(x, y));
				
				if group == 'destructible':
					add_obstacle(obstacle_entity.instance(), Vector2(x, y));
	
	# Create a timer node
	var timer = Timer.new()

	# Set timer interval
	timer.set_wait_time(5.0)

	# Set it as repeat
	timer.set_one_shot(false)

	# Connect its timeout signal to the function you want to repeat
	timer.connect("timeout", self, "getTowerLowLife")

	# Add to the tree as child of the current node
	add_child(timer)

	timer.start()

	wave_timer = Timer.new()
	wave_timer.connect("timeout", self, "_on_wave_timer")
	add_child(wave_timer)
	
	_trigger_new_wave()
	
func add_shooter_cost(pos, attack_range):
	var tile_range = ceil(attack_range / tile_map.cell_size.x)
	for x in range(tile_range):
		for y in range(tile_range):
			if Vector2(x, y).length() > tile_range: continue
			for quadrant in quadrants:
				var map_x = pos.x + x * quadrant.x
				var map_y = pos.y + y * quadrant.y
				if map_x < 0 || map_x >= width || map_y < 0 || map_y >= height: continue
				if graphs['range_cost'][map_x][map_y] == null: continue
				graphs['range_cost'][map_x][map_y] = max(graphs['range_cost'][map_x][map_y], get_cost(Vector2(map_x, map_y)) + tower_cost)
				
func reset_shooter_cost(pos, attack_range):
	var tile_range = ceil(attack_range / tile_map.cell_size.x)
	for x in range(tile_range):
		for y in range(tile_range):
			if Vector2(x, y).length() > tile_range: continue
			for quadrant in quadrants:
				var map_x = pos.x + x * quadrant.x
				var map_y = pos.y + y * quadrant.y
				if map_x < 0 || map_x >= width || map_y < 0 || map_y >= height: continue
				if graphs['range_cost'][map_x][map_y] == null: continue
				graphs['range_cost'][map_x][map_y] = get_cost(Vector2(map_x, map_y))
	
# ajouter une entité aux systèmes "world"	
func add_entity(entity, pos):
	if get_node("/root/Main").state != "playing": return
	# il faut traduire la position en coordonnées grille  
	var tile_pos = tile_map.world_to_map(pos)
	# si la position est en dehors de la grille, on ne peut rien faire
	# s'il existe déjà une entité à cette position, on veut éviter de construire par dessus
	if tile_pos.x < 0 || tile_pos.x > entities.size() - 1 || tile_pos.y < 0 || tile_pos.y > entities[tile_pos.x].size() - 1 || entities[tile_pos.x][tile_pos.y]: return
	
	for enemie in enemies:
		if tile_pos == tile_map.world_to_map(enemie.position):
			return
			
	# on veut savoir quel catégorie de terrain se trouve à cette position
	var group = tile_map.get_group(tile_pos)
	if group == 'road' || group == 'water' || group == 'tree': return	
	# || group == 'destructible'
	if !group:
		print_debug("tile %s has no group" % tile_map.get_cell_autotile_coord(tile_pos.x, tile_pos.y))
	
	# certaines entités occupent plusieurs cases et on doit traiter chacune d'elles
	var tilemap_entity = entity as TileMapEntity
	var entity_positions = []
	if tilemap_entity:
		for x in range(tilemap_entity.width):
			for y in range(tilemap_entity.height):
				entity_positions.append(Vector2(tile_pos.x + x, tile_pos.y + y))

		# pour chaque "tag" on a une liste d'entités et un graphe Dijkstra
		# on les créé ici s'ils n'existent pas déjà
		if tilemap_entity.tag:
			if !entity_lookups.has(tilemap_entity.tag): entity_lookups[tilemap_entity.tag] = []
			if !dijkstra.has('distance_to_%s' % tilemap_entity.tag): dijkstra['distance_to_%s' % tilemap_entity.tag] = DijkstraMap.new(entity_lookups[tilemap_entity.tag], graphs['cost'])
			if !dijkstra.has('avoid_range_go_to_%s' % tilemap_entity.tag): dijkstra['avoid_range_go_to_%s' % tilemap_entity.tag] = DijkstraMap.new(entity_lookups[tilemap_entity.tag], graphs['range_cost'])	
	else: entity_positions.append(tile_pos)
	
	var shooter = entity.get_node_or_null("Shooter")
	
	for pos in entity_positions:
		# on remplit la liste des défenses
		if "type" in entity:
			var type = entity.type
			if type in defences:
				defences[type] += 1
			else:
				defences[type] = 1
		# on remplit la grille des entités
		entities[pos.x][pos.y] = entity
		
		# et on met à jour la grille des coûts, car on ne peut pas traverser une entité (pour le moment!)
		for graph in graphs:
			if graph != 'cost_medic':
				graphs[graph][pos.x][pos.y] = null
				
		# on l'ajoute aussi à la liste de son tag
		if tilemap_entity && tilemap_entity.tag:
			entity_lookups[tilemap_entity.tag].append(pos)
		if shooter:
			add_shooter_cost(pos, shooter.attack_range)
			
	# on doit recalculer tous le graphes car il y a de nouveaux obstacles à contourner
	for map in dijkstra:
		dijkstra[map].calculate()
	
	# ajouter l'entité dans la hierarchie et la positionner correctement
	var parent = entity.get_node_or_null("..")
	if parent != self:
		add_child(entity)
	entity.position = Vector2(tile_pos.x * tile_map.cell_size.x, tile_pos.y * tile_map.cell_size.y)
	entity.z_index = tile_pos.y
	emit_signal("on_change")
	return entity
	
func calculateMissingLife(tower):
	var missing_life = tower.hitpoints_max - tower.hitpoints
	return missing_life

func getTowerLowLife():
	lower_towers = []
	# s'il existe au moins une tour
	if entity_lookups && entity_lookups.has('tower'):
		
		# Pour toutes les tours qui existent
		for tower_pos in entity_lookups['tower']:
			
			var tower = entities[tower_pos.x][tower_pos.y]
			var missing_life = calculateMissingLife(tower)
			
			# si la tour possède moins de point de vie que la tour stockée actuelement
			if missing_life > 0 && !lower_towers.has(tower_pos):
				#lower_towers = [tower_pos]
				lower_towers.append(tower_pos)
				
		# s'il n'y a pas de tour de renseignée on renseigne toute les tours
		if !lower_towers:
				lower_towers = entity_lookups['tower']	
				
	if lower_towers: 
		dijkstra['test'] = DijkstraMap.new(lower_towers, graphs['cost_medic'])	
		dijkstra['test'].calculate()
	
# enlever une entité des systèmes "world"
func remove_entity(entity):
	if get_node("/root/Main").state != "playing": return
	# convertir la position de l'entité en position sur la grille
	var tile_pos = tile_map.world_to_map(entity.position)
	# si la position est en dehors de la grille on ne peut rien faire
	if tile_pos.x < 0 || tile_pos.x > entities.size() - 1 || tile_pos.y < 0 || tile_pos.y > entities[tile_pos.x].size() - 1: return
	
	# certaines entités occupent plusieurs cases
	var entity_positions = []
	var tilemap_entity = entity as TileMapEntity
	if tilemap_entity:
		for x in range(tilemap_entity.width):
			for y in range(tilemap_entity.height):
				entity_positions.append(Vector2(tile_pos.x + x, tile_pos.y + y))
	else: entity_positions.append(tile_pos)
	
	var shooter = entity.get_node_or_null("Shooter")
	for pos in entity_positions:
		# enlever de la liste des défenses
		if "type" in entity:
			var type = entity.type
			if type in defences:
				if defences[type] > 1:
					defences[type] -= 1
				else:
					defences.erase(type)
					
		if "tag" in entity && entity.tag == "obstacle":
			tile_map.set_cell(tile_pos.x, tile_pos.y, 0, false, false, false, Vector2(0, 0))
			
		# enlever de la grille des entités
		entities[pos.x][pos.y] = null
		# rétablir le coût maintenant qu'on peut traverser la case
		for graph in graphs:
			graphs[graph][pos.x][pos.y] = get_cost(pos)
		# enlever de la liste par tag
		if tilemap_entity && tilemap_entity.tag && entity_lookups[tilemap_entity.tag]:
			entity_lookups[tilemap_entity.tag].erase(pos)
			getTowerLowLife()
		if shooter:
			reset_shooter_cost(pos, shooter.attack_range)
			
	if shooter && entity_lookups['tower']:
		for tower_pos in entity_lookups['tower']:
			var tower = entities[tower_pos.x][tower_pos.y]
			var tower_shooter = tower.get_node_or_null("Shooter")
			if !tower_shooter: continue
			for x in range(tower.width):
				for y in range(tower.height):
					add_shooter_cost(Vector2(tower_pos.x + x, tower_pos.y + y), tower_shooter.attack_range)
		
	# on doit recalculer tous les graphes Dijkstra car de nouveaux chemins pourraient être ouverts	
	for map in dijkstra:
		dijkstra[map].calculate()
		
	# enlever l'entité de la hierarchie
	entity.queue_free()
	emit_signal("on_change")
	
func add_enemy(enemy):
	enemies.append(enemy)
	add_child(enemy)
	enemy.world = self
	
func remove_enemy(enemy):
	enemies.erase(enemy)
	_check_wave_status()
	var main = get_node("/root/Main")

func _on_defeat():
	if !is_inside_tree(): return
	print_debug("Defeat!")
	get_node("/root/Main").state = "defeated"

func add_friendly(friendly, pos):
	var tile_pos = tile_map.world_to_map(pos)
	# si la position est en dehors de la grille, on ne peut rien faire
	# s'il existe déjà une entité à cette position, on veut éviter de construire par dessus
	if tile_pos.x < 0 || tile_pos.x > entities.size() - 1 || tile_pos.y < 0 || tile_pos.y > entities[tile_pos.x].size() - 1 || entities[tile_pos.x][tile_pos.y]: return
	
	# on veut savoir quel catégorie de terrain se trouve à cette position
	var group = tile_map.get_group(tile_pos)
	if group == 'road' || group == 'water' || group == 'tree' || group == 'destructible': return
	if !group:
		print_debug("tile %s has no group" % tile_map.get_cell_autotile_coord(tile_pos.x, tile_pos.y))
		
	friendly.position = Vector2(tile_pos.x * tile_map.cell_size.x, tile_pos.y * tile_map.cell_size.y)
	friendly.z_index = tile_pos.y
	friendlies.append(friendly)
	add_child(friendly)
	if "world" in friendly:
		friendly.world = self
	return friendly

func remove_friendly(friendly):
	friendlies.erase(friendly)
	friendly.queue_free()
	emit_signal("on_change")
		
func add_obstacle(obstacle, tile_pos):
	var pos_x = (tile_pos.x * tile_map.cell_size.x) + (tile_map.cell_size.x / 2);
	var pos_y = (tile_pos.y * tile_map.cell_size.y) + (tile_map.cell_size.y / 2);
	add_entity(obstacle, Vector2(pos_x, pos_y));
	
func get_tile_map():
	return tile_map

func _check_wave_status():
	var all_spawned = true
	for spawner in spawners:
		if all_spawned && spawner.wave.has("ennemies") :
			all_spawned = spawner.wave.enemies.size() == spawner.spawn_index
	
	if all_spawned && enemies.size() == 0:
		wave_index += 1
		_trigger_new_wave()

func _trigger_new_wave():
	for spawner in spawners:
		spawner.spawn_index = 0
		spawner.spawn_timer.stop()
		if wave_index >= spawner.spawner_index * 3:
			print_debug("Wave %s starting in %s seconds" % [wave_index + 1, wait_between_waves])
			wave_timer.start(wait_between_waves)
			spawner._create_wave()
			
func _on_wave_timer():
	for spawner in spawners:
		if wave_index >= spawner.spawner_index * 3:
			spawner._start_wave()
