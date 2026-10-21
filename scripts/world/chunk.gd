class_name Chunk
extends StaticBody3D

## Représente un chunk de terrain voxel (32x32x256 blocs avec VOXEL_SIZE=0.5m)
## avec biomes, greedy meshing haute performance et décorations.

const BlockTypes = preload("res://scripts/world/block_types.gd")
const DecorGenerator = preload("res://scripts/world/decor_generator.gd")
const VoxelConstants = preload("res://scripts/world/voxel_constants.gd")

const CHUNK_WIDTH: int = VoxelConstants.CHUNK_WIDTH
const CHUNK_DEPTH: int = VoxelConstants.CHUNK_DEPTH
const CHUNK_HEIGHT: int = VoxelConstants.CHUNK_HEIGHT
const TOTAL_VOXELS: int = VoxelConstants.TOTAL_VOXELS
const SEA_LEVEL: int = VoxelConstants.SEA_LEVEL
const VOXEL_SIZE: float = VoxelConstants.VOXEL_SIZE

var chunk_coords: Vector2i = Vector2i.ZERO
var voxels: PackedByteArray = PackedByteArray()
var mesh_instance: MeshInstance3D = null
var water_mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var decor_multimesh: MultiMeshInstance3D = null
var triangle_count: int = 0
var last_build_time_ms: float = 0.0

# Table des 6 directions de faces (UP, DOWN, NORTH, SOUTH, WEST, EAST)
const FACE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # UP (+Y)
	Vector3i(0, -1, 0),  # DOWN (-Y)
	Vector3i(0, 0, -1),  # NORTH (-Z)
	Vector3i(0, 0, 1),   # SOUTH (+Z)
	Vector3i(-1, 0, 0),  # WEST (-X)
	Vector3i(1, 0, 0),   # EAST (+X)
]

const FACE_TANGENTS: Array[Array] = [
	[Vector3i(-1, 0, 0), Vector3i(0, 0, 1)],  # UP
	[Vector3i(-1, 0, 0), Vector3i(0, 0, -1)], # DOWN
	[Vector3i(-1, 0, 0), Vector3i(0, 1, 0)],  # NORTH
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],   # SOUTH
	[Vector3i(0, 0, 1), Vector3i(0, 1, 0)],   # WEST
	[Vector3i(0, 0, -1), Vector3i(0, 1, 0)]   # EAST
]


func _init(coords: Vector2i = Vector2i.ZERO) -> void:
	chunk_coords = coords
	position = Vector3(
		float(chunk_coords.x) * VoxelConstants.CHUNK_SIZE_METERS,
		0.0,
		float(chunk_coords.y) * VoxelConstants.CHUNK_SIZE_METERS
	)
	collision_layer = 1
	collision_mask = 0


## Indexation linéaire d'un voxel dans le chunk
static func get_voxel_index(x: int, y: int, z: int) -> int:
	return x + (z * CHUNK_WIDTH) + (y * CHUNK_WIDTH * CHUNK_DEPTH)


## Calcule la hauteur du relief en voxels de façon déterministe
static func get_height_at(noise: FastNoiseLite, world_x: int, world_z: int) -> int:
	var wx_meters: float = float(world_x) * VOXEL_SIZE
	var wz_meters: float = float(world_z) * VOXEL_SIZE
	var base_val: float = noise.get_noise_2d(wx_meters, wz_meters)
	var h_meters: float = VoxelConstants.BASE_HEIGHT_METERS + (base_val * VoxelConstants.HEIGHT_VARIATION_METERS)
	var h_voxels: int = int(round(h_meters / VOXEL_SIZE))
	return clampi(h_voxels, 2, CHUNK_HEIGHT - int(round(6.0 / VOXEL_SIZE)))


## Hauteur exacte de surface en mètres
static func get_height_meters(noise: FastNoiseLite, wx_meters: float, wz_meters: float) -> float:
	var base_val: float = noise.get_noise_2d(wx_meters, wz_meters)
	return VoxelConstants.BASE_HEIGHT_METERS + (base_val * VoxelConstants.HEIGHT_VARIATION_METERS)


## Détermine le biome en fonction de la température, de l'humidité et de l'altitude
static func get_biome_at(temp: float, humid: float, height: int) -> int:
	var h_meters: float = float(height) * VOXEL_SIZE
	if h_meters <= VoxelConstants.SEA_LEVEL_METERS - 2.0:
		return BlockTypes.Biome.OCEAN
	if h_meters <= VoxelConstants.SEA_LEVEL_METERS + 2.0:
		return BlockTypes.Biome.BEACH
	if h_meters >= 56.0:
		return BlockTypes.Biome.MOUNTAIN

	if temp > 0.25 and humid < -0.05:
		return BlockTypes.Biome.DESERT
	if temp < -0.15:
		return BlockTypes.Biome.SNOW
	if humid > 0.18:
		return BlockTypes.Biome.FOREST
	return BlockTypes.Biome.PLAINS


## Détermine le type de bloc selon le biome et la profondeur
static func get_block_type_for_biome(biome: int, y: int, terrain_h: int) -> int:
	if y <= 0:
		return BlockTypes.Type.STONE
	if y > terrain_h:
		if y <= SEA_LEVEL:
			return BlockTypes.Type.WATER
		return BlockTypes.Type.AIR

	var is_surface: bool = (y == terrain_h)
	var is_subsurface: bool = (y > terrain_h - int(round(2.0 / VOXEL_SIZE)))

	match biome:
		BlockTypes.Biome.OCEAN:
			return BlockTypes.Type.SAND if is_subsurface else BlockTypes.Type.STONE
		BlockTypes.Biome.BEACH:
			return BlockTypes.Type.SAND if is_subsurface else BlockTypes.Type.SANDSTONE
		BlockTypes.Biome.DESERT:
			return BlockTypes.Type.SAND if is_surface else (BlockTypes.Type.SANDSTONE if is_subsurface else BlockTypes.Type.STONE)
		BlockTypes.Biome.SNOW:
			return BlockTypes.Type.SNOW if is_surface else (BlockTypes.Type.SNOW_DIRT if is_subsurface else BlockTypes.Type.STONE)
		BlockTypes.Biome.FOREST:
			return BlockTypes.Type.GRASS if is_surface else (BlockTypes.Type.DIRT if is_subsurface else BlockTypes.Type.STONE)
		BlockTypes.Biome.MOUNTAIN:
			return BlockTypes.Type.ROCK if is_surface else BlockTypes.Type.STONE
		_: # PLAINS
			return BlockTypes.Type.GRASS if is_surface else (BlockTypes.Type.DIRT if is_subsurface else BlockTypes.Type.STONE)


## Détermine le bloc monde pour les voisins hors-limites (Thread-safe)
static func get_world_block_at(coords: Vector2i, x: int, y: int, z: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> int:
	if y <= 0:
		return BlockTypes.Type.STONE
	if y >= CHUNK_HEIGHT:
		return BlockTypes.Type.AIR

	var wx: int = (coords.x * CHUNK_WIDTH) + x
	var wz: int = (coords.y * CHUNK_DEPTH) + z

	var terrain_h: int = get_height_at(t_noise, wx, wz)
	var wx_m: float = float(wx) * VOXEL_SIZE
	var wz_m: float = float(wz) * VOXEL_SIZE
	var temp: float = temp_noise.get_noise_2d(wx_m, wz_m)
	var hum: float = hum_noise.get_noise_2d(wx_m, wz_m)
	var biome: int = get_biome_at(temp, hum, terrain_h)

	return get_block_type_for_biome(biome, y, terrain_h)


## Génération complète des données de voxels du chunk + décorations (Thread-safe)
static func generate_voxel_data(coords: Vector2i, master_seed: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> Dictionary:
	var data := PackedByteArray()
	data.resize(TOTAL_VOXELS)

	var world_origin_x: int = coords.x * CHUNK_WIDTH
	var world_origin_z: int = coords.y * CHUNK_DEPTH
	var max_y: int = SEA_LEVEL

	# 1. Relief de base et biomes
	for x in range(CHUNK_WIDTH):
		var wx: int = world_origin_x + x
		for z in range(CHUNK_DEPTH):
			var wz: int = world_origin_z + z

			var terrain_h: int = get_height_at(t_noise, wx, wz)
			if terrain_h > max_y:
				max_y = terrain_h

			var wx_m: float = float(wx) * VOXEL_SIZE
			var wz_m: float = float(wz) * VOXEL_SIZE
			var temp: float = temp_noise.get_noise_2d(wx_m, wz_m)
			var hum: float = hum_noise.get_noise_2d(wx_m, wz_m)
			var biome: int = get_biome_at(temp, hum, terrain_h)

			for y in range(CHUNK_HEIGHT):
				data[get_voxel_index(x, y, z)] = get_block_type_for_biome(biome, y, terrain_h)

	# 2. Décorations végétales et minérales
	var cell_sz: int = DecorGenerator.CELL_SIZE
	var margin: int = int(round(5.0 / VOXEL_SIZE))
	var min_cell_x: int = int(floor(float(world_origin_x - margin) / float(cell_sz)))
	var max_cell_x: int = int(floor(float(world_origin_x + CHUNK_WIDTH + margin) / float(cell_sz)))
	var min_cell_z: int = int(floor(float(world_origin_z - margin) / float(cell_sz)))
	var max_cell_z: int = int(floor(float(world_origin_z + CHUNK_DEPTH + margin) / float(cell_sz)))

	for cx in range(min_cell_x, max_cell_x + 1):
		for cz in range(min_cell_z, max_cell_z + 1):
			var h_val: int = DecorGenerator.hash2d(master_seed, cx, cz)
			var rx: int = cx * cell_sz + (h_val % (cell_sz - 1))
			var rz: int = cz * cell_sz + ((h_val >> 4) % (cell_sz - 1))

			var ry: int = get_height_at(t_noise, rx, rz)
			if ry <= SEA_LEVEL:
				continue

			var rx_m: float = float(rx) * VOXEL_SIZE
			var rz_m: float = float(rz) * VOXEL_SIZE
			var temp: float = temp_noise.get_noise_2d(rx_m, rz_m)
			var hum: float = hum_noise.get_noise_2d(rx_m, rz_m)
			var biome: int = get_biome_at(temp, hum, ry)
			var roll: int = (h_val >> 8) % 100

			match biome:
				BlockTypes.Biome.DESERT:
					if roll < 25:
						DecorGenerator.place_cactus(data, coords, rx, ry + 1, rz, h_val)
						max_y = maxi(max_y, ry + int(round(4.0 / VOXEL_SIZE)))
					elif roll < 45:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.DRY_SHRUB)
					elif roll < 55:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)

				BlockTypes.Biome.PLAINS:
					if roll < 12:
						DecorGenerator.place_oak_tree(data, coords, rx, ry + 1, rz, h_val)
						max_y = maxi(max_y, ry + int(round(7.0 / VOXEL_SIZE)))
					elif roll < 40:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.TALL_GRASS)
					elif roll < 55:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.FLOWER_RED)
					elif roll < 70:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.FLOWER_YELLOW)
					elif roll < 78:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)

				BlockTypes.Biome.FOREST:
					if roll < 45:
						DecorGenerator.place_oak_tree(data, coords, rx, ry + 1, rz, h_val)
						max_y = maxi(max_y, ry + int(round(7.0 / VOXEL_SIZE)))
					elif roll < 70:
						DecorGenerator.place_birch_tree(data, coords, rx, ry + 1, rz, h_val)
						max_y = maxi(max_y, ry + int(round(9.0 / VOXEL_SIZE)))
					elif roll < 82:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.TALL_GRASS)
					elif roll < 92:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.FLOWER_RED)

				BlockTypes.Biome.SNOW:
					if roll < 50:
						DecorGenerator.place_pine_tree(data, coords, rx, ry + 1, rz, h_val)
						max_y = maxi(max_y, ry + int(round(10.0 / VOXEL_SIZE)))
					elif roll < 65:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)

				BlockTypes.Biome.MOUNTAIN:
					if roll < 45:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)
					elif roll < 60 and ry < int(round(62.0 / VOXEL_SIZE)):
						DecorGenerator.place_pine_tree(data, coords, rx, ry + 1, rz, h_val)
						max_y = maxi(max_y, ry + int(round(10.0 / VOXEL_SIZE)))

	return {
		"voxels": data,
		"max_y": mini(max_y + 1, CHUNK_HEIGHT - 1)
	}


## Lecture d'un bloc local ou consultation du relief voisin
static func get_block_from_data(data: PackedByteArray, coords: Vector2i, x: int, y: int, z: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> int:
	if y < 0:
		return BlockTypes.Type.STONE
	if y >= CHUNK_HEIGHT:
		return BlockTypes.Type.AIR

	if x >= 0 and x < CHUNK_WIDTH and z >= 0 and z < CHUNK_DEPTH:
		return data[get_voxel_index(x, y, z)]

	return get_world_block_at(coords, x, y, z, t_noise, temp_noise, hum_noise)


## Calcul de l'Ambient Occlusion par vertex en entier (0 à 3)
static func compute_vertex_ao_level(data: PackedByteArray, coords: Vector2i, pos: Vector3i, norm: Vector3i, side1: Vector3i, side2: Vector3i, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> int:
	var s1: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side1.x, pos.y + norm.y + side1.y, pos.z + norm.z + side1.z, t_noise, temp_noise, hum_noise))
	var s2: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side2.x, pos.y + norm.y + side2.y, pos.z + norm.z + side2.z, t_noise, temp_noise, hum_noise))
	var c: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side1.x + side2.x, pos.y + norm.y + side1.y + side2.y, pos.z + norm.z + side1.z + side2.z, t_noise, temp_noise, hum_noise))

	if s1 and s2:
		return 3
	return (1 if s1 else 0) + (1 if s2 else 0) + (1 if c else 0)


static func ao_level_to_factor(lvl: int) -> float:
	match lvl:
		1: return 0.84
		2: return 0.68
		3: return 0.48
		_: return 1.0


## GREEDY MESHING 3D multithreadé : fusionne les faces coplanaires adjacentes
static func build_mesh_data(data: PackedByteArray, coords: Vector2i, max_y: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite, lod_level: int = 0) -> Dictionary:
	var t_start: int = Time.get_ticks_usec()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	var decor_instances: Array[Dictionary] = []

	var water_vertices := PackedVector3Array()
	var water_normals := PackedVector3Array()
	var water_colors := PackedColorArray()
	var water_indices := PackedInt32Array()

	var vertex_counter: int = 0
	var water_vertex_counter: int = 0
	var vs: float = VOXEL_SIZE

	# Décor surfacique (fleurs, herbes) collecté
	if lod_level == 0:
		for x in range(CHUNK_WIDTH):
			for y in range(max_y + 1):
				for z in range(CHUNK_DEPTH):
					var b: int = data[get_voxel_index(x, y, z)]
					if BlockTypes.is_plant(b):
						var p_col: Color = BlockTypes.get_face_color(b, Vector3i.UP)
						decor_instances.append({
							"pos": Vector3((float(x) + 0.5) * vs, float(y) * vs, (float(z) + 0.5) * vs),
							"color": p_col
						})

	# Grille 2D réutilisable pour le slice greedy meshing
	var slice_mask := PackedInt32Array()

	# Traitement des 6 directions de faces
	for face_idx in range(6):
		var dir: Vector3i = FACE_DIRECTIONS[face_idx]
		var face_norm := Vector3(dir.x, dir.y, dir.z)
		var tangents: Array = FACE_TANGENTS[face_idx]
		var tan_u: Vector3i = tangents[0]
		var tan_v: Vector3i = tangents[1]

		# Configuration selon l'axe normal de balayage
		match face_idx:
			0, 1: # UP (+Y) et DOWN (-Y) : slices horizontales X x Z
				var u_size: int = CHUNK_WIDTH
				var v_size: int = CHUNK_DEPTH
				slice_mask.resize(u_size * v_size)

				var y_start: int = 0 if face_idx == 0 else 1 # y=0 pas de face inférieure
				var y_end: int = max_y

				for y in range(y_start, y_end + 1):
					slice_mask.fill(0)
					var has_any_face: bool = false

					for x in range(u_size):
						for z in range(v_size):
							var block: int = data[get_voxel_index(x, y, z)]
							if block == BlockTypes.Type.AIR or BlockTypes.is_plant(block):
								continue

							var neighbor: int = get_block_from_data(data, coords, x + dir.x, y + dir.y, z + dir.z, t_noise, temp_noise, hum_noise)
							if BlockTypes.is_opaque(neighbor):
								continue
							if block == BlockTypes.Type.WATER and neighbor == BlockTypes.Type.WATER:
								continue

							var ao_0: int = 0
							var ao_1: int = 0
							var ao_2: int = 0
							var ao_3: int = 0
							if lod_level == 0:
								var bpos := Vector3i(x, y, z)
								ao_0 = compute_vertex_ao_level(data, coords, bpos, dir, -tan_u, -tan_v, t_noise, temp_noise, hum_noise)
								ao_1 = compute_vertex_ao_level(data, coords, bpos, dir, -tan_u, tan_v, t_noise, temp_noise, hum_noise)
								ao_2 = compute_vertex_ao_level(data, coords, bpos, dir, tan_u, tan_v, t_noise, temp_noise, hum_noise)
								ao_3 = compute_vertex_ao_level(data, coords, bpos, dir, tan_u, -tan_v, t_noise, temp_noise, hum_noise)

							# Clé de fusion : bloc + 4 niveaux d'AO
							var key: int = (block & 0xFF) | (ao_0 << 8) | (ao_1 << 10) | (ao_2 << 12) | (ao_3 << 14)
							slice_mask[x + z * u_size] = key
							has_any_face = true

					if not has_any_face:
						continue

					# Fusion gloutonne (Greedy Merge) sur le plan X (u) x Z (v)
					for z in range(v_size):
						for x in range(u_size):
							var key: int = slice_mask[x + z * u_size]
							if key == 0:
								continue

							# Élargir le long de X
							var w: int = 1
							while (x + w) < u_size and slice_mask[(x + w) + z * u_size] == key:
								w += 1

							# Étendre le long de Z
							var h: int = 1
							var can_extend: bool = true
							while (z + h) < v_size and can_extend:
								for k in range(w):
									if slice_mask[(x + k) + (z + h) * u_size] != key:
										can_extend = false
										break
								if can_extend:
									h += 1

							# Effacer la région fusionnée
							for dv in range(h):
								for du in range(w):
									slice_mask[(x + du) + (z + dv) * u_size] = 0

							var block_t: int = key & 0xFF
							var base_col: Color = BlockTypes.get_face_color(block_t, dir)
							var a0: float = ao_level_to_factor((key >> 8) & 3)
							var a1: float = ao_level_to_factor((key >> 10) & 3)
							var a2: float = ao_level_to_factor((key >> 12) & 3)
							var a3: float = ao_level_to_factor((key >> 14) & 3)

							var v0: Vector3
							var v1: Vector3
							var v2: Vector3
							var v3: Vector3

							if face_idx == 0: # UP (+Y)
								var y_top: float = float(y + 1) * vs
								v0 = Vector3(float(x) * vs, y_top, float(z) * vs)
								v1 = Vector3(float(x) * vs, y_top, float(z + h) * vs)
								v2 = Vector3(float(x + w) * vs, y_top, float(z + h) * vs)
								v3 = Vector3(float(x + w) * vs, y_top, float(z) * vs)
							else: # DOWN (-Y)
								var y_bot: float = float(y) * vs
								v0 = Vector3(float(x) * vs, y_bot, float(z + h) * vs)
								v1 = Vector3(float(x) * vs, y_bot, float(z) * vs)
								v2 = Vector3(float(x + w) * vs, y_bot, float(z) * vs)
								v3 = Vector3(float(x + w) * vs, y_bot, float(z + h) * vs)

							if block_t == BlockTypes.Type.WATER:
								water_vertices.push_back(v0)
								water_vertices.push_back(v1)
								water_vertices.push_back(v2)
								water_vertices.push_back(v3)
								for _k in range(4):
									water_normals.push_back(face_norm)
								for _k in range(4):
									water_colors.push_back(base_col)
								water_indices.push_back(water_vertex_counter + 0)
								water_indices.push_back(water_vertex_counter + 1)
								water_indices.push_back(water_vertex_counter + 2)
								water_indices.push_back(water_vertex_counter + 0)
								water_indices.push_back(water_vertex_counter + 2)
								water_indices.push_back(water_vertex_counter + 3)
								water_vertex_counter += 4
							else:
								vertices.push_back(v0)
								vertices.push_back(v1)
								vertices.push_back(v2)
								vertices.push_back(v3)
								for _k in range(4):
									normals.push_back(face_norm)
								colors.push_back(Color(base_col.r * a0, base_col.g * a0, base_col.b * a0, base_col.a))
								colors.push_back(Color(base_col.r * a1, base_col.g * a1, base_col.b * a1, base_col.a))
								colors.push_back(Color(base_col.r * a2, base_col.g * a2, base_col.b * a2, base_col.a))
								colors.push_back(Color(base_col.r * a3, base_col.g * a3, base_col.b * a3, base_col.a))
								indices.push_back(vertex_counter + 0)
								indices.push_back(vertex_counter + 1)
								indices.push_back(vertex_counter + 2)
								indices.push_back(vertex_counter + 0)
								indices.push_back(vertex_counter + 2)
								indices.push_back(vertex_counter + 3)
								if lod_level == 0 and BlockTypes.is_solid(block_t):
									collision_faces.push_back(v0)
									collision_faces.push_back(v1)
									collision_faces.push_back(v2)
									collision_faces.push_back(v0)
									collision_faces.push_back(v2)
									collision_faces.push_back(v3)
								vertex_counter += 4

			2, 3: # NORTH (-Z) et SOUTH (+Z) : slices X x Y
				var u_size: int = CHUNK_WIDTH
				var v_size: int = max_y + 1
				slice_mask.resize(u_size * v_size)

				for z in range(CHUNK_DEPTH):
					slice_mask.fill(0)
					var has_any_face: bool = false

					for x in range(u_size):
						for y in range(v_size):
							var block: int = data[get_voxel_index(x, y, z)]
							if block == BlockTypes.Type.AIR or BlockTypes.is_plant(block):
								continue

							var neighbor: int = get_block_from_data(data, coords, x + dir.x, y + dir.y, z + dir.z, t_noise, temp_noise, hum_noise)
							if BlockTypes.is_opaque(neighbor):
								continue
							if block == BlockTypes.Type.WATER and neighbor == BlockTypes.Type.WATER:
								continue

							var ao_0: int = 0
							var ao_1: int = 0
							var ao_2: int = 0
							var ao_3: int = 0
							if lod_level == 0:
								var bpos := Vector3i(x, y, z)
								ao_0 = compute_vertex_ao_level(data, coords, bpos, dir, -tan_u, -tan_v, t_noise, temp_noise, hum_noise)
								ao_1 = compute_vertex_ao_level(data, coords, bpos, dir, -tan_u, tan_v, t_noise, temp_noise, hum_noise)
								ao_2 = compute_vertex_ao_level(data, coords, bpos, dir, tan_u, tan_v, t_noise, temp_noise, hum_noise)
								ao_3 = compute_vertex_ao_level(data, coords, bpos, dir, tan_u, -tan_v, t_noise, temp_noise, hum_noise)

							var key: int = (block & 0xFF) | (ao_0 << 8) | (ao_1 << 10) | (ao_2 << 12) | (ao_3 << 14)
							slice_mask[x + y * u_size] = key
							has_any_face = true

					if not has_any_face:
						continue

					for y in range(v_size):
						for x in range(u_size):
							var key: int = slice_mask[x + y * u_size]
							if key == 0:
								continue

							var w: int = 1
							while (x + w) < u_size and slice_mask[(x + w) + y * u_size] == key:
								w += 1

							var h: int = 1
							var can_extend: bool = true
							while (y + h) < v_size and can_extend:
								for k in range(w):
									if slice_mask[(x + k) + (y + h) * u_size] != key:
										can_extend = false
										break
								if can_extend:
									h += 1

							for dv in range(h):
								for du in range(w):
									slice_mask[(x + du) + (y + dv) * u_size] = 0

							var block_t: int = key & 0xFF
							var base_col: Color = BlockTypes.get_face_color(block_t, dir)
							var a0: float = ao_level_to_factor((key >> 8) & 3)
							var a1: float = ao_level_to_factor((key >> 10) & 3)
							var a2: float = ao_level_to_factor((key >> 12) & 3)
							var a3: float = ao_level_to_factor((key >> 14) & 3)

							var v0: Vector3
							var v1: Vector3
							var v2: Vector3
							var v3: Vector3

							if face_idx == 2: # NORTH (-Z)
								var z_pos: float = float(z) * vs
								v0 = Vector3(float(x + w) * vs, float(y) * vs, z_pos)
								v1 = Vector3(float(x) * vs, float(y) * vs, z_pos)
								v2 = Vector3(float(x) * vs, float(y + h) * vs, z_pos)
								v3 = Vector3(float(x + w) * vs, float(y + h) * vs, z_pos)
							else: # SOUTH (+Z)
								var z_pos: float = float(z + 1) * vs
								v0 = Vector3(float(x) * vs, float(y) * vs, z_pos)
								v1 = Vector3(float(x + w) * vs, float(y) * vs, z_pos)
								v2 = Vector3(float(x + w) * vs, float(y + h) * vs, z_pos)
								v3 = Vector3(float(x) * vs, float(y + h) * vs, z_pos)

							if block_t == BlockTypes.Type.WATER:
								water_vertices.push_back(v0)
								water_vertices.push_back(v1)
								water_vertices.push_back(v2)
								water_vertices.push_back(v3)
								for _k in range(4):
									water_normals.push_back(face_norm)
								for _k in range(4):
									water_colors.push_back(base_col)
								water_indices.push_back(water_vertex_counter + 0)
								water_indices.push_back(water_vertex_counter + 1)
								water_indices.push_back(water_vertex_counter + 2)
								water_indices.push_back(water_vertex_counter + 0)
								water_indices.push_back(water_vertex_counter + 2)
								water_indices.push_back(water_vertex_counter + 3)
								water_vertex_counter += 4
							else:
								vertices.push_back(v0)
								vertices.push_back(v1)
								vertices.push_back(v2)
								vertices.push_back(v3)
								for _k in range(4):
									normals.push_back(face_norm)
								colors.push_back(Color(base_col.r * a0, base_col.g * a0, base_col.b * a0, base_col.a))
								colors.push_back(Color(base_col.r * a1, base_col.g * a1, base_col.b * a1, base_col.a))
								colors.push_back(Color(base_col.r * a2, base_col.g * a2, base_col.b * a2, base_col.a))
								colors.push_back(Color(base_col.r * a3, base_col.g * a3, base_col.b * a3, base_col.a))
								indices.push_back(vertex_counter + 0)
								indices.push_back(vertex_counter + 1)
								indices.push_back(vertex_counter + 2)
								indices.push_back(vertex_counter + 0)
								indices.push_back(vertex_counter + 2)
								indices.push_back(vertex_counter + 3)
								if lod_level == 0 and BlockTypes.is_solid(block_t):
									collision_faces.push_back(v0)
									collision_faces.push_back(v1)
									collision_faces.push_back(v2)
									collision_faces.push_back(v0)
									collision_faces.push_back(v2)
									collision_faces.push_back(v3)
								vertex_counter += 4

			4, 5: # WEST (-X) et EAST (+X) : slices Z x Y
				var u_size: int = CHUNK_DEPTH
				var v_size: int = max_y + 1
				slice_mask.resize(u_size * v_size)

				for x in range(CHUNK_WIDTH):
					slice_mask.fill(0)
					var has_any_face: bool = false

					for z in range(u_size):
						for y in range(v_size):
							var block: int = data[get_voxel_index(x, y, z)]
							if block == BlockTypes.Type.AIR or BlockTypes.is_plant(block):
								continue

							var neighbor: int = get_block_from_data(data, coords, x + dir.x, y + dir.y, z + dir.z, t_noise, temp_noise, hum_noise)
							if BlockTypes.is_opaque(neighbor):
								continue
							if block == BlockTypes.Type.WATER and neighbor == BlockTypes.Type.WATER:
								continue

							var ao_0: int = 0
							var ao_1: int = 0
							var ao_2: int = 0
							var ao_3: int = 0
							if lod_level == 0:
								var bpos := Vector3i(x, y, z)
								ao_0 = compute_vertex_ao_level(data, coords, bpos, dir, -tan_u, -tan_v, t_noise, temp_noise, hum_noise)
								ao_1 = compute_vertex_ao_level(data, coords, bpos, dir, -tan_u, tan_v, t_noise, temp_noise, hum_noise)
								ao_2 = compute_vertex_ao_level(data, coords, bpos, dir, tan_u, tan_v, t_noise, temp_noise, hum_noise)
								ao_3 = compute_vertex_ao_level(data, coords, bpos, dir, tan_u, -tan_v, t_noise, temp_noise, hum_noise)

							var key: int = (block & 0xFF) | (ao_0 << 8) | (ao_1 << 10) | (ao_2 << 12) | (ao_3 << 14)
							slice_mask[z + y * u_size] = key
							has_any_face = true

					if not has_any_face:
						continue

					for y in range(v_size):
						for z in range(u_size):
							var key: int = slice_mask[z + y * u_size]
							if key == 0:
								continue

							var w: int = 1
							while (z + w) < u_size and slice_mask[(z + w) + y * u_size] == key:
								w += 1

							var h: int = 1
							var can_extend: bool = true
							while (y + h) < v_size and can_extend:
								for k in range(w):
									if slice_mask[(z + k) + (y + h) * u_size] != key:
										can_extend = false
										break
								if can_extend:
									h += 1

							for dv in range(h):
								for du in range(w):
									slice_mask[(z + du) + (y + dv) * u_size] = 0

							var block_t: int = key & 0xFF
							var base_col: Color = BlockTypes.get_face_color(block_t, dir)
							var a0: float = ao_level_to_factor((key >> 8) & 3)
							var a1: float = ao_level_to_factor((key >> 10) & 3)
							var a2: float = ao_level_to_factor((key >> 12) & 3)
							var a3: float = ao_level_to_factor((key >> 14) & 3)

							var v0: Vector3
							var v1: Vector3
							var v2: Vector3
							var v3: Vector3

							if face_idx == 4: # WEST (-X)
								var x_pos: float = float(x) * vs
								v0 = Vector3(x_pos, float(y) * vs, float(z) * vs)
								v1 = Vector3(x_pos, float(y) * vs, float(z + w) * vs)
								v2 = Vector3(x_pos, float(y + h) * vs, float(z + w) * vs)
								v3 = Vector3(x_pos, float(y + h) * vs, float(z) * vs)
							else: # EAST (+X)
								var x_pos: float = float(x + 1) * vs
								v0 = Vector3(x_pos, float(y) * vs, float(z + w) * vs)
								v1 = Vector3(x_pos, float(y) * vs, float(z) * vs)
								v2 = Vector3(x_pos, float(y + h) * vs, float(z) * vs)
								v3 = Vector3(x_pos, float(y + h) * vs, float(z + w) * vs)

							if block_t == BlockTypes.Type.WATER:
								water_vertices.push_back(v0)
								water_vertices.push_back(v1)
								water_vertices.push_back(v2)
								water_vertices.push_back(v3)
								for _k in range(4):
									water_normals.push_back(face_norm)
								for _k in range(4):
									water_colors.push_back(base_col)
								water_indices.push_back(water_vertex_counter + 0)
								water_indices.push_back(water_vertex_counter + 1)
								water_indices.push_back(water_vertex_counter + 2)
								water_indices.push_back(water_vertex_counter + 0)
								water_indices.push_back(water_vertex_counter + 2)
								water_indices.push_back(water_vertex_counter + 3)
								water_vertex_counter += 4
							else:
								vertices.push_back(v0)
								vertices.push_back(v1)
								vertices.push_back(v2)
								vertices.push_back(v3)
								for _k in range(4):
									normals.push_back(face_norm)
								colors.push_back(Color(base_col.r * a0, base_col.g * a0, base_col.b * a0, base_col.a))
								colors.push_back(Color(base_col.r * a1, base_col.g * a1, base_col.b * a1, base_col.a))
								colors.push_back(Color(base_col.r * a2, base_col.g * a2, base_col.b * a2, base_col.a))
								colors.push_back(Color(base_col.r * a3, base_col.g * a3, base_col.b * a3, base_col.a))
								indices.push_back(vertex_counter + 0)
								indices.push_back(vertex_counter + 1)
								indices.push_back(vertex_counter + 2)
								indices.push_back(vertex_counter + 0)
								indices.push_back(vertex_counter + 2)
								indices.push_back(vertex_counter + 3)
								if lod_level == 0 and BlockTypes.is_solid(block_t):
									collision_faces.push_back(v0)
									collision_faces.push_back(v1)
									collision_faces.push_back(v2)
									collision_faces.push_back(v0)
									collision_faces.push_back(v2)
									collision_faces.push_back(v3)
								vertex_counter += 4

	var mesh_arrays := []
	if not vertices.is_empty():
		mesh_arrays.resize(Mesh.ARRAY_MAX)
		mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh_arrays[Mesh.ARRAY_NORMAL] = normals
		mesh_arrays[Mesh.ARRAY_COLOR] = colors
		mesh_arrays[Mesh.ARRAY_INDEX] = indices

	var water_arrays := []
	if not water_vertices.is_empty():
		water_arrays.resize(Mesh.ARRAY_MAX)
		water_arrays[Mesh.ARRAY_VERTEX] = water_vertices
		water_arrays[Mesh.ARRAY_NORMAL] = water_normals
		water_arrays[Mesh.ARRAY_COLOR] = water_colors
		water_arrays[Mesh.ARRAY_INDEX] = water_indices

	var elapsed_ms: float = float(Time.get_ticks_usec() - t_start) / 1000.0

	return {
		"mesh_arrays": mesh_arrays,
		"water_arrays": water_arrays,
		"collision_faces": collision_faces,
		"decor_instances": decor_instances,
		"triangles": (indices.size() + water_indices.size()) / 3,
		"build_time_ms": elapsed_ms
	}


## Applique le maillage, les collisions et le décor MultiMesh sur le Chunk (Thread Principal)
func apply_mesh_and_collision(mesh_arrays: Array, col_faces: PackedVector3Array, material: Material, decor_data: Array = [], num_tris: int = 0, build_ms: float = 0.0, water_arrays: Array = [], water_material: Material = null) -> void:
	triangle_count = num_tris
	last_build_time_ms = build_ms

	var has_terrain: bool = not mesh_arrays.is_empty() and not (mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty()
	if has_terrain:
		var array_mesh := ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
		array_mesh.surface_set_material(0, material)

		if mesh_instance == null:
			mesh_instance = MeshInstance3D.new()
			add_child(mesh_instance)

		mesh_instance.mesh = array_mesh
		mesh_instance.visible = true
	elif mesh_instance != null:
		mesh_instance.visible = false

	var has_water: bool = not water_arrays.is_empty() and not (water_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty()
	if has_water:
		var water_mesh := ArrayMesh.new()
		water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water_arrays)
		if water_material != null:
			water_mesh.surface_set_material(0, water_material)

		if water_mesh_instance == null:
			water_mesh_instance = MeshInstance3D.new()
			water_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(water_mesh_instance)

		water_mesh_instance.mesh = water_mesh
		water_mesh_instance.visible = true
	elif water_mesh_instance != null:
		water_mesh_instance.visible = false

	# Collision (uniquement pour les chunks en LOD 0)
	if not col_faces.is_empty():
		if collision_shape == null:
			collision_shape = CollisionShape3D.new()
			add_child(collision_shape)

		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(col_faces)
		collision_shape.shape = shape
	elif collision_shape != null:
		collision_shape.shape = null

	# Décor via MultiMeshInstance3D
	_apply_decor_multimesh(decor_data)


func _apply_decor_multimesh(decor_data: Array) -> void:
	if decor_data.is_empty():
		if decor_multimesh != null:
			decor_multimesh.visible = false
		return

	if decor_multimesh == null:
		decor_multimesh = MultiMeshInstance3D.new()
		decor_multimesh.name = "DecorMultiMesh"
		add_child(decor_multimesh)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = decor_data.size()

	var cross_box := BoxMesh.new()
	var vs: float = VOXEL_SIZE
	cross_box.size = Vector3(vs * 0.9, vs * 1.5, vs * 0.9)
	var cross_mat := StandardMaterial3D.new()
	cross_mat.vertex_color_use_as_albedo = true
	cross_mat.roughness = 0.9
	cross_mat.cull_mode = BaseMaterial3D.CULL_BACK
	cross_box.material = cross_mat
	mm.mesh = cross_box

	for i in range(decor_data.size()):
		var d: Dictionary = decor_data[i]
		mm.set_instance_transform(i, Transform3D(Basis(), d["pos"]))
		mm.set_instance_color(i, d["color"])

	decor_multimesh.multimesh = mm
	decor_multimesh.visible = true
