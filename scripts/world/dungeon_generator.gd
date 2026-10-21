class_name DungeonGenerator
extends Node3D

## Générateur procédural de donjons souterrains : cryptes de surface, couloirs, salles aux monstres, coffres et arène de boss.

const Chunk = preload("res://scripts/world/chunk.gd")
const TreasureChest = preload("res://scripts/items/treasure_chest.gd")
const DungeonBoss = preload("res://scripts/enemies/dungeon_boss.gd")
const SkeletonEnemy = preload("res://scripts/enemies/skeleton.gd")
const GolemEnemy = preload("res://scripts/enemies/golem.gd")
const VoxelConstants = preload("res://scripts/world/voxel_constants.gd")

const DUNGEON_REGION_SIZE: int = 160
const SUBTERRANEAN_Y: float = 12.0

var spawned_dungeons: Dictionary = {} # Vector2i -> Node3D
var terrain_noise: FastNoiseLite = null
var world_seed: int = 1337


func setup(seed_val: int, t_noise: FastNoiseLite) -> void:
	world_seed = seed_val
	terrain_noise = t_noise


## Informations du donjon le plus proche
func get_nearest_dungeon(pos: Vector3) -> Dictionary:
	var rx: int = int(floor(pos.x / float(DUNGEON_REGION_SIZE)))
	var rz: int = int(floor(pos.z / float(DUNGEON_REGION_SIZE)))

	var nearest: Dictionary = {}
	var min_d: float = 999999.0

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var d_info: Dictionary = get_dungeon_info_for_region(rx + dx, rz + dz)
			if not d_info.is_empty():
				var dist: float = pos.distance_to(d_info["surface_position"])
				if dist < min_d:
					min_d = dist
					nearest = d_info

	return nearest


func get_dungeon_info_for_region(rx: int, rz: int) -> Dictionary:
	var hash_val: int = int(posmod((rx * 524287) ^ (rz * 131071) ^ (world_seed + 777), 100000))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_val

	# 70% de chance d'un donjon par région
	if rng.randf() > 0.7:
		return {}

	var local_x: float = rng.randf_range(30.0, float(DUNGEON_REGION_SIZE - 30))
	var local_z: float = rng.randf_range(30.0, float(DUNGEON_REGION_SIZE - 30))

	var dx: int = rx * DUNGEON_REGION_SIZE + int(local_x)
	var dz: int = rz * DUNGEON_REGION_SIZE + int(local_z)

	var bpos := VoxelConstants.world_to_block_2d(float(dx), float(dz))
	var h_vox: int = Chunk.get_height_at(terrain_noise, bpos.x, bpos.y)
	var h_m: float = float(h_vox) * VoxelConstants.VOXEL_SIZE
	if h_m < VoxelConstants.SEA_LEVEL_METERS + 1.0:
		return {}

	var d_names: Array[String] = ["Crypte d'Ossements", "Catacombes de l'Ombre", "Donjon des Âmes", "Gouffre Maudit"]
	var d_name: String = d_names[posmod(hash_val, d_names.size())]

	return {
		"id": "dungeon_%d_%d" % [rx, rz],
		"region": Vector2i(rx, rz),
		"surface_position": Vector3(float(dx), h_m, float(dz)),
		"subterranean_position": Vector3(float(dx), SUBTERRANEAN_Y, float(dz)),
		"name": d_name
	}


func update_dungeons_around(center_pos: Vector3, max_dist: float = 160.0) -> void:
	var min_rx: int = int(floor((center_pos.x - max_dist) / float(DUNGEON_REGION_SIZE)))
	var max_rx: int = int(floor((center_pos.x + max_dist) / float(DUNGEON_REGION_SIZE)))
	var min_rz: int = int(floor((center_pos.z - max_dist) / float(DUNGEON_REGION_SIZE)))
	var max_rz: int = int(floor((center_pos.z + max_dist) / float(DUNGEON_REGION_SIZE)))

	# Déchargement des donjons distants
	var to_remove: Array[Vector2i] = []
	for reg in spawned_dungeons.keys():
		var node: Node3D = spawned_dungeons[reg]
		if is_instance_valid(node):
			if node.global_position.distance_to(center_pos) > max_dist + 60.0:
				to_remove.append(reg)
				node.queue_free()
		else:
			to_remove.append(reg)

	for k in to_remove:
		spawned_dungeons.erase(k)

	# Apparition
	for rx in range(min_rx, max_rx + 1):
		for rz in range(min_rz, max_rz + 1):
			var reg := Vector2i(rx, rz)
			if not spawned_dungeons.has(reg):
				var d_info: Dictionary = get_dungeon_info_for_region(rx, rz)
				if not d_info.is_empty():
					var d: float = center_pos.distance_to(d_info["surface_position"])
					if d <= max_dist:
						_spawn_dungeon(d_info)


func _create_voxel_block(parent: Node3D, pos: Vector3, sz: Vector3, col: Color, with_collision: bool = true) -> void:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
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


func _spawn_dungeon(d_info: Dictionary) -> void:
	var root := Node3D.new()
	root.name = d_info["id"]
	root.position = d_info["surface_position"]
	add_child(root)
	spawned_dungeons[d_info["region"]] = root

	var stone_dark := Color(0.24, 0.25, 0.28)
	var stone_brick := Color(0.38, 0.40, 0.44)
	var crypt_gold := Color(0.85, 0.70, 0.25)

	# 1. Entrée en surface : Mausolée / Crypte de pierre
	_build_surface_crypt(root, stone_dark, stone_brick, crypt_gold, d_info)

	# 2. Complexe souterrain à y = SUBTERRANEAN_Y
	var local_sub_y: float = SUBTERRANEAN_Y - root.position.y
	_build_subterranean_dungeon(root, local_sub_y, stone_dark, stone_brick)


## Mausolée de surface avec escalier descendant
func _build_surface_crypt(parent: Node3D, stone_dark: Color, stone_brick: Color, crypt_gold: Color, d_info: Dictionary) -> void:
	# Murs d'enceinte
	_create_voxel_block(parent, Vector3(0, 2.0, 0), Vector3(7.0, 4.0, 7.0), stone_dark)
	# Toit pyramidal
	_create_voxel_block(parent, Vector3(0, 4.5, 0), Vector3(7.6, 1.0, 7.6), stone_brick)
	# Arche d'entrée
	_create_voxel_block(parent, Vector3(0, 1.2, 3.6), Vector3(2.2, 2.8, 0.4), Color(0.08, 0.08, 0.1), false)

	# Panneau / Marqueur au-dessus
	var sign_label := Label3D.new()
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.position = Vector3(0, 5.5, 0)
	sign_label.text = "💀 %s\n[Donjon Souterrain]" % d_info["name"]
	sign_label.modulate = Color(1.0, 0.35, 0.35)
	parent.add_child(sign_label)

	# Puits d'escalier descendant vers le sous-sol
	var depth_to_sub: float = root_to_sub_depth(parent)
	for step in range(12):
		var sy: float = -float(step) * (depth_to_sub / 12.0)
		var sz: float = float(step) * 1.5
		_create_voxel_block(parent, Vector3(0, sy, sz), Vector3(2.4, 0.8, 1.5), stone_brick)


func root_to_sub_depth(parent: Node3D) -> float:
	return absf(parent.position.y - SUBTERRANEAN_Y)


## Construction des salles souterraines
func _build_subterranean_dungeon(parent: Node3D, sub_y: float, stone_dark: Color, stone_brick: Color) -> void:
	# Salle 1 : Hall d'entrée (0, sub_y, 20)
	_build_dungeon_room(parent, Vector3(0, sub_y, 20), Vector3(10, 5, 10), stone_dark, stone_brick)

	# Couloir 1 vers Salle 2 (0, sub_y, 35)
	_build_corridor(parent, Vector3(0, sub_y, 30), Vector3(3, 4, 10), stone_dark, stone_brick)

	# Salle 2 : Crypte des Monstres (0, sub_y, 45)
	_build_dungeon_room(parent, Vector3(0, sub_y, 45), Vector3(12, 5, 12), stone_dark, stone_brick)
	_spawn_room_monsters(parent, Vector3(0, sub_y + 0.5, 45))

	# Couloir 2 vers Salle aux trésors (15, sub_y, 45)
	_build_corridor(parent, Vector3(10, sub_y, 45), Vector3(10, 4, 3), stone_dark, stone_brick)

	# Salle 3 : Chambre du Trésor (20, sub_y, 45)
	_build_dungeon_room(parent, Vector3(20, sub_y, 45), Vector3(8, 4, 8), stone_dark, stone_brick)
	var chest := TreasureChest.new()
	chest.position = Vector3(20, sub_y + 0.1, 45)
	parent.add_child(chest)

	# Couloir 3 vers Arène du Boss (0, sub_y, 65)
	_build_corridor(parent, Vector3(0, sub_y, 58), Vector3(4, 5, 14), stone_dark, stone_brick)

	# Salle 4 : Grande Arène du Titan (0, sub_y, 82)
	_build_dungeon_room(parent, Vector3(0, sub_y, 82), Vector3(18, 7, 18), stone_dark, stone_brick)
	_build_arena_pillars(parent, Vector3(0, sub_y, 82), stone_brick)

	# Boss du donjon
	var boss := DungeonBoss.new()
	boss.boss_name = "Titan Gorgaroth - Maître des Cryptes"
	boss.boss_level = 3
	boss.position = Vector3(0, sub_y + 0.5, 84)
	parent.add_child(boss)


func _build_dungeon_room(parent: Node3D, center: Vector3, sz: Vector3, wall_col: Color, floor_col: Color) -> void:
	# Sol
	_create_voxel_block(parent, center + Vector3(0, -0.4, 0), Vector3(sz.x, 0.8, sz.z), floor_col)
	# Plafond
	_create_voxel_block(parent, center + Vector3(0, sz.y + 0.4, 0), Vector3(sz.x, 0.8, sz.z), wall_col)
	# Murs Ouest & Est
	_create_voxel_block(parent, center + Vector3(-sz.x * 0.5, sz.y * 0.5, 0), Vector3(0.8, sz.y, sz.z), wall_col)
	_create_voxel_block(parent, center + Vector3(sz.x * 0.5, sz.y * 0.5, 0), Vector3(0.8, sz.y, sz.z), wall_col)


func _build_corridor(parent: Node3D, center: Vector3, sz: Vector3, wall_col: Color, floor_col: Color) -> void:
	# Sol
	_create_voxel_block(parent, center + Vector3(0, -0.4, 0), Vector3(sz.x, 0.8, sz.z), floor_col)
	# Plafond
	_create_voxel_block(parent, center + Vector3(0, sz.y + 0.4, 0), Vector3(sz.x, 0.8, sz.z), wall_col)


func _build_arena_pillars(parent: Node3D, arena_center: Vector3, col: Color) -> void:
	var offsets: Array[Vector3] = [
		Vector3(-5, 3.0, -5),
		Vector3(5, 3.0, -5),
		Vector3(-5, 3.0, 5),
		Vector3(5, 3.0, 5)
	]
	for off in offsets:
		_create_voxel_block(parent, arena_center + off, Vector3(1.2, 6.0, 1.2), col)


func _spawn_room_monsters(parent: Node3D, room_pos: Vector3) -> void:
	for i in range(2):
		var skel := SkeletonEnemy.new()
		skel.level = 2
		skel.position = room_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		parent.add_child(skel)
