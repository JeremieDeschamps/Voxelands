class_name VillageGenerator
extends Node3D

## Générateur procédural de villages avec styles architecturaux par biome et PNJ donneurs de quêtes.

const BlockTypes = preload("res://scripts/world/block_types.gd")
const VillageNPC = preload("res://scripts/world/village_npc.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const VoxelConstants = preload("res://scripts/world/voxel_constants.gd")

const REGION_SIZE: int = 120 # Espacement moyen des villages en blocs

# Liste des villages générés : Vector2i (centre) -> Node3D
var spawned_villages: Dictionary = {}

var terrain_noise: FastNoiseLite = null
var temperature_noise: FastNoiseLite = null
var humidity_noise: FastNoiseLite = null
var world_seed: int = 1337


func setup(seed_val: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> void:
	world_seed = seed_val
	terrain_noise = t_noise
	temperature_noise = temp_noise
	humidity_noise = hum_noise


## Trouve le village le plus proche d'une position donnée
func get_nearest_village(world_pos: Vector3) -> Dictionary:
	var rx: int = int(floor(world_pos.x / float(REGION_SIZE)))
	var rz: int = int(floor(world_pos.z / float(REGION_SIZE)))

	var nearest_info: Dictionary = {}
	var min_dist: float = 999999.0

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var v_info: Dictionary = get_village_info_for_region(rx + dx, rz + dz)
			if not v_info.is_empty():
				var d: float = world_pos.distance_to(v_info["position"])
				if d < min_dist:
					min_dist = d
					nearest_info = v_info

	return nearest_info


## Calcule les métadonnées d'un village pour une cellule de région
func get_village_info_for_region(rx: int, rz: int) -> Dictionary:
	var hash_val: int = int(posmod((rx * 73856093) ^ (rz * 19349663) ^ world_seed, 100000))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_val

	# 75% de chance qu'une cellule contienne un village
	if rng.randf() > 0.75:
		return {}

	var local_x: float = rng.randf_range(20.0, float(REGION_SIZE - 20))
	var local_z: float = rng.randf_range(20.0, float(REGION_SIZE - 20))

	var vx: int = rx * REGION_SIZE + int(local_x)
	var vz: int = rz * REGION_SIZE + int(local_z)

	var bpos := VoxelConstants.world_to_block_2d(float(vx), float(vz))
	var h_vox: int = Chunk.get_height_at(terrain_noise, bpos.x, bpos.y)
	var h_m: float = float(h_vox) * VoxelConstants.VOXEL_SIZE
	# Ne pas générer au fond de l'océan
	if h_m < VoxelConstants.SEA_LEVEL_METERS - 1.0:
		return {}

	var temp: float = temperature_noise.get_noise_2d(float(vx), float(vz))
	var hum: float = humidity_noise.get_noise_2d(float(vx), float(vz))
	var biome: int = Chunk.get_biome_at(temp, hum, h_vox)

	var v_names: Array[String] = ["Oakhaven", "Sable-d'Or", "Givrecime", "Roc-Vaillant", "Port-Azul", "Brumeval", "Soléria"]
	var v_name: String = v_names[posmod(hash_val, v_names.size())]

	return {
		"id": "village_%d_%d" % [rx, rz],
		"region": Vector2i(rx, rz),
		"position": Vector3(float(vx), h_m, float(vz)),
		"biome": biome,
		"name": v_name
	}


## Met à jour les villages autour du joueur
func update_villages_around(center_pos: Vector3, max_dist: float = 140.0) -> void:
	var min_rx: int = int(floor((center_pos.x - max_dist) / float(REGION_SIZE)))
	var max_rx: int = int(floor((center_pos.x + max_dist) / float(REGION_SIZE)))
	var min_rz: int = int(floor((center_pos.z - max_dist) / float(REGION_SIZE)))
	var max_rz: int = int(floor((center_pos.z + max_dist) / float(REGION_SIZE)))

	# Déchargement des villages trop distants
	var keys_to_remove: Array[Vector2i] = []
	for reg in spawned_villages.keys():
		var node: Node3D = spawned_villages[reg]
		if is_instance_valid(node):
			if node.global_position.distance_to(center_pos) > max_dist + 50.0:
				keys_to_remove.append(reg)
				node.queue_free()
		else:
			keys_to_remove.append(reg)

	for k in keys_to_remove:
		spawned_villages.erase(k)

	# Apparition des nouveaux villages
	for rx in range(min_rx, max_rx + 1):
		for rz in range(min_rz, max_rz + 1):
			var reg := Vector2i(rx, rz)
			if not spawned_villages.has(reg):
				var v_info: Dictionary = get_village_info_for_region(rx, rz)
				if not v_info.is_empty():
					var d: float = center_pos.distance_to(v_info["position"])
					if d <= max_dist:
						_spawn_village(v_info)


func _spawn_village(v_info: Dictionary) -> void:
	var root := Node3D.new()
	root.name = v_info["id"]
	root.position = v_info["position"]
	add_child(root)
	spawned_villages[v_info["region"]] = root

	var biome: int = v_info["biome"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v_info["position"].x * 31.0 + v_info["position"].z)

	# 1. Bâtiment central / Place de village
	_build_plaza(root, biome)

	# 2. 3 à 4 maisons aux alentours
	var house_offsets: Array[Vector3] = [
		Vector3(-10.0, 0.0, -8.0),
		Vector3(10.0, 0.0, -6.0),
		Vector3(-8.0, 0.0, 10.0),
		Vector3(9.0, 0.0, 9.0)
	]

	for i in range(house_offsets.size()):
		var off: Vector3 = house_offsets[i]
		var world_x: float = root.position.x + off.x
		var world_z: float = root.position.z + off.z
		var bpos_h := VoxelConstants.world_to_block_2d(world_x, world_z)
		var terrain_y_vox: int = Chunk.get_height_at(terrain_noise, bpos_h.x, bpos_h.y)
		var terrain_y_m: float = float(terrain_y_vox) * VoxelConstants.VOXEL_SIZE
		var local_y: float = terrain_y_m - root.position.y
		_build_house(root, Vector3(off.x, local_y, off.z), biome, i)

	# 3. PNJ du village
	_spawn_village_npcs(root, biome, v_info["name"])


func _create_voxel_block(parent: Node3D, pos: Vector3, sz: Vector3, col: Color, with_collision: bool = true) -> void:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	box.material = mat
	inst.mesh = box
	inst.position = pos
	parent.add_child(inst)

	if with_collision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sz
		cs.shape = shape
		sb.add_child(cs)
		sb.position = pos
		parent.add_child(sb)


## Place centrale / Puits ou fontaine selon biome
func _build_plaza(parent: Node3D, biome: int) -> void:
	match biome:
		BlockTypes.Biome.DESERT:
			# Bassin oasis carré avec palmier
			_create_voxel_block(parent, Vector3(0, 0.2, 0), Vector3(4.0, 0.4, 4.0), Color(0.85, 0.75, 0.45))
			_create_voxel_block(parent, Vector3(0, 0.35, 0), Vector3(3.0, 0.2, 3.0), Color(0.25, 0.65, 0.85))
		BlockTypes.Biome.SNOW:
			# Feu de camp de village avec pierre et bois
			_create_voxel_block(parent, Vector3(0, 0.2, 0), Vector3(3.0, 0.4, 3.0), Color(0.35, 0.35, 0.40))
			_create_voxel_block(parent, Vector3(0, 0.5, 0), Vector3(1.2, 0.5, 1.2), Color(0.95, 0.50, 0.15), false)
		BlockTypes.Biome.MOUNTAIN:
			# Brasero imposant de forteresse
			_create_voxel_block(parent, Vector3(0, 0.8, 0), Vector3(1.6, 1.6, 1.6), Color(0.25, 0.25, 0.28))
			_create_voxel_block(parent, Vector3(0, 1.8, 0), Vector3(1.2, 0.6, 1.2), Color(0.98, 0.60, 0.10), false)
		_:
			# Puits en pierre traditionnel avec toit en bois
			_create_voxel_block(parent, Vector3(0, 0.5, 0), Vector3(2.5, 1.0, 2.5), Color(0.55, 0.55, 0.58))
			_create_voxel_block(parent, Vector3(0, 0.7, 0), Vector3(1.5, 0.8, 1.5), Color(0.25, 0.55, 0.85), false)
			# Piliers et toit
			_create_voxel_block(parent, Vector3(-0.9, 1.8, 0), Vector3(0.2, 1.6, 0.2), Color(0.40, 0.28, 0.18))
			_create_voxel_block(parent, Vector3(0.9, 1.8, 0), Vector3(0.2, 1.6, 0.2), Color(0.40, 0.28, 0.18))
			_create_voxel_block(parent, Vector3(0, 2.7, 0), Vector3(2.8, 0.3, 2.2), Color(0.65, 0.35, 0.20))


## Maison adaptée au biome
func _build_house(parent: Node3D, pos: Vector3, biome: int, house_idx: int) -> void:
	var wall_col: Color
	var roof_col: Color

	match biome:
		BlockTypes.Biome.DESERT:
			# Maison en adobe sandstone cubique
			wall_col = Color(0.82, 0.72, 0.48)
			roof_col = Color(0.72, 0.60, 0.38)
			# Murs
			_create_voxel_block(parent, pos + Vector3(0, 1.8, 0), Vector3(4.5, 3.6, 4.5), wall_col)
			# Poutres saillantes en bois
			_create_voxel_block(parent, pos + Vector3(0, 3.4, 0), Vector3(4.9, 0.3, 0.3), Color(0.40, 0.25, 0.15))
			# Auvent en tissu coloré
			_create_voxel_block(parent, pos + Vector3(0, 2.2, 2.6), Vector3(2.6, 0.1, 1.4), Color(0.85, 0.30, 0.25), false)

		BlockTypes.Biome.SNOW:
			# Chalet en rondins sombres avec toit enneigé
			wall_col = Color(0.30, 0.20, 0.14)
			roof_col = Color(0.94, 0.96, 0.98) # Neige
			_create_voxel_block(parent, pos + Vector3(0, 1.6, 0), Vector3(5.0, 3.2, 4.5), wall_col)
			_create_voxel_block(parent, pos + Vector3(0, 3.6, 0), Vector3(5.4, 1.0, 4.9), roof_col)
			# Cheminée en pierre
			_create_voxel_block(parent, pos + Vector3(1.8, 3.8, 1.2), Vector3(0.9, 2.2, 0.9), Color(0.45, 0.45, 0.48))

		BlockTypes.Biome.MOUNTAIN:
			# Bastion fortifié en pierre
			wall_col = Color(0.48, 0.49, 0.52)
			roof_col = Color(0.32, 0.33, 0.36)
			_create_voxel_block(parent, pos + Vector3(0, 2.2, 0), Vector3(4.8, 4.4, 4.8), wall_col)
			# Créneaux / Mur de rempart
			_create_voxel_block(parent, pos + Vector3(0, 4.6, 0), Vector3(5.2, 0.6, 5.2), roof_col)

		BlockTypes.Biome.BEACH, BlockTypes.Biome.OCEAN:
			# Cabane sur pilotis
			wall_col = Color(0.55, 0.42, 0.28)
			roof_col = Color(0.80, 0.72, 0.45) # Chaume
			# 4 Pilotis
			_create_voxel_block(parent, pos + Vector3(-1.8, 0.6, -1.8), Vector3(0.35, 1.6, 0.35), wall_col)
			_create_voxel_block(parent, pos + Vector3(1.8, 0.6, -1.8), Vector3(0.35, 1.6, 0.35), wall_col)
			_create_voxel_block(parent, pos + Vector3(-1.8, 0.6, 1.8), Vector3(0.35, 1.6, 0.35), wall_col)
			_create_voxel_block(parent, pos + Vector3(1.8, 0.6, 1.8), Vector3(0.35, 1.6, 0.35), wall_col)
			# Maison surélevée
			_create_voxel_block(parent, pos + Vector3(0, 2.6, 0), Vector3(4.4, 2.6, 4.4), wall_col)
			_create_voxel_block(parent, pos + Vector3(0, 4.1, 0), Vector3(4.8, 0.8, 4.8), roof_col)

		_:
			# Chaumière en bois et toit en tuiles de prairie/forêt
			wall_col = Color(0.45, 0.32, 0.20)
			roof_col = Color(0.70, 0.35, 0.22) if (house_idx % 2 == 0) else Color(0.85, 0.78, 0.45)
			_create_voxel_block(parent, pos + Vector3(0, 1.6, 0), Vector3(4.6, 3.2, 4.2), wall_col)
			_create_voxel_block(parent, pos + Vector3(0, 3.6, 0), Vector3(5.2, 1.1, 4.8), roof_col)
			# Porte d'entrée
			_create_voxel_block(parent, pos + Vector3(0, 0.9, 2.15), Vector3(1.0, 1.8, 0.15), Color(0.28, 0.18, 0.10), false)


## Fait apparaître les PNJ donneurs de quêtes
func _spawn_village_npcs(parent: Node3D, biome: int, v_name: String) -> void:
	var elder := VillageNPC.new()
	elder.npc_name = "Ancien de " + v_name
	elder.npc_role = "Chef du Village"
	elder.biome = biome
	elder.quest_index = 0
	elder.position = Vector3(2.5, 0.0, 2.0)
	parent.add_child(elder)

	var guard := VillageNPC.new()
	guard.npc_name = "Sentinelle " + v_name
	guard.npc_role = "Garde"
	guard.biome = biome
	guard.quest_index = 1
	guard.position = Vector3(-3.0, 0.0, -2.5)
	parent.add_child(guard)
