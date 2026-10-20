class_name Chunk
extends StaticBody3D

## Représente un chunk de terrain voxel de 16x16x128 blocs avec biomes et décorations.

const BlockTypes = preload("res://scripts/world/block_types.gd")
const DecorGenerator = preload("res://scripts/world/decor_generator.gd")

const CHUNK_WIDTH: int = 16
const CHUNK_DEPTH: int = 16
const CHUNK_HEIGHT: int = 128
const TOTAL_VOXELS: int = CHUNK_WIDTH * CHUNK_DEPTH * CHUNK_HEIGHT
const SEA_LEVEL: int = 32

var chunk_coords: Vector2i = Vector2i.ZERO
var voxels: PackedByteArray = PackedByteArray()
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var decor_multimesh: MultiMeshInstance3D = null

# Table des 6 faces d'un cube (UP, DOWN, NORTH, SOUTH, WEST, EAST)
const FACE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # UP
	Vector3i(0, -1, 0),  # DOWN
	Vector3i(0, 0, -1),  # NORTH (-Z)
	Vector3i(0, 0, 1),   # SOUTH (+Z)
	Vector3i(-1, 0, 0),  # WEST (-X)
	Vector3i(1, 0, 0),   # EAST (+X)
]

# Définition des 4 sommets par face
const FACE_VERTICES: Array[Array] = [
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], # UP
	[Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], # DOWN
	[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)], # NORTH
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], # SOUTH
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)], # WEST
	[Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]  # EAST
]

# Vecteurs tangents (U, V) pour l'Ambient Occlusion (AO)
const FACE_TANGENTS: Array[Array] = [
	[Vector3i(-1, 0, 0), Vector3i(0, 0, 1)],  # UP
	[Vector3i(-1, 0, 0), Vector3i(0, 0, -1)], # DOWN
	[Vector3i(-1, 0, 0), Vector3i(0, 1, 0)],  # NORTH
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],   # SOUTH
	[Vector3i(0, 0, 1), Vector3i(0, 1, 0)],   # WEST
	[Vector3i(0, 0, -1), Vector3i(0, 1, 0)],  # EAST
]


func _init(coords: Vector2i = Vector2i.ZERO) -> void:
	chunk_coords = coords
	position = Vector3(chunk_coords.x * CHUNK_WIDTH, 0, chunk_coords.y * CHUNK_DEPTH)


## Indexation linéaire d'un voxel dans le chunk
static func get_voxel_index(x: int, y: int, z: int) -> int:
	return x + (z * CHUNK_WIDTH) + (y * CHUNK_WIDTH * CHUNK_DEPTH)


## Calcule la hauteur du relief de façon déterministe
static func get_height_at(noise: FastNoiseLite, world_x: int, world_z: int) -> int:
	var base_val: float = noise.get_noise_2d(float(world_x), float(world_z))
	var h: float = 38.0 + (base_val * 26.0)
	return clampi(int(round(h)), 2, CHUNK_HEIGHT - 12)


## Détermine le biome en fonction de la température, de l'humidité et de l'altitude
static func get_biome_at(temp: float, humid: float, height: int) -> int:
	if height <= SEA_LEVEL - 2:
		return BlockTypes.Biome.OCEAN
	if height <= SEA_LEVEL + 2:
		return BlockTypes.Biome.BEACH
	if height >= 56:
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
	var is_subsurface: bool = (y > terrain_h - 4)

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
			return BlockTypes.Type.FOREST_GRASS if is_surface else (BlockTypes.Type.DIRT if is_subsurface else BlockTypes.Type.STONE)
		BlockTypes.Biome.MOUNTAIN:
			if is_surface and y >= 64:
				return BlockTypes.Type.SNOW
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
	var temp: float = temp_noise.get_noise_2d(float(wx), float(wz))
	var hum: float = hum_noise.get_noise_2d(float(wx), float(wz))
	var biome: int = get_biome_at(temp, hum, terrain_h)

	return get_block_type_for_biome(biome, y, terrain_h)


## Génération complète des données de voxels du chunk + décorations (Thread-safe)
static func generate_voxel_data(coords: Vector2i, master_seed: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> Dictionary:
	var data := PackedByteArray()
	data.resize(TOTAL_VOXELS)

	var world_origin_x: int = coords.x * CHUNK_WIDTH
	var world_origin_z: int = coords.y * CHUNK_DEPTH
	var max_y: int = SEA_LEVEL

	# 1. Génération du terrain de base et biomes
	for x in range(CHUNK_WIDTH):
		var wx: int = world_origin_x + x
		for z in range(CHUNK_DEPTH):
			var wz: int = world_origin_z + z

			var terrain_h: int = get_height_at(t_noise, wx, wz)
			if terrain_h > max_y:
				max_y = terrain_h

			var temp: float = temp_noise.get_noise_2d(float(wx), float(wz))
			var hum: float = hum_noise.get_noise_2d(float(wx), float(wz))
			var biome: int = get_biome_at(temp, hum, terrain_h)

			for y in range(CHUNK_HEIGHT):
				data[get_voxel_index(x, y, z)] = get_block_type_for_biome(biome, y, terrain_h)

	# 2. Placement des éléments de décor procéduraux
	var min_cell_x: int = int(floor(float(world_origin_x - 4) / float(DecorGenerator.CELL_SIZE)))
	var max_cell_x: int = int(floor(float(world_origin_x + CHUNK_WIDTH + 3) / float(DecorGenerator.CELL_SIZE)))
	var min_cell_z: int = int(floor(float(world_origin_z - 4) / float(DecorGenerator.CELL_SIZE)))
	var max_cell_z: int = int(floor(float(world_origin_z + CHUNK_DEPTH + 3) / float(DecorGenerator.CELL_SIZE)))

	for cx in range(min_cell_x, max_cell_x + 1):
		for cz in range(min_cell_z, max_cell_z + 1):
			var h_val: int = DecorGenerator.hash2d(master_seed, cx, cz)
			var rx: int = cx * DecorGenerator.CELL_SIZE + (h_val % (DecorGenerator.CELL_SIZE - 1))
			var rz: int = cz * DecorGenerator.CELL_SIZE + ((h_val >> 4) % (DecorGenerator.CELL_SIZE - 1))

			var ry: int = get_height_at(t_noise, rx, rz)
			if ry <= SEA_LEVEL:
				continue

			var temp: float = temp_noise.get_noise_2d(float(rx), float(rz))
			var hum: float = hum_noise.get_noise_2d(float(rx), float(rz))
			var biome: int = get_biome_at(temp, hum, ry)
			var roll: int = (h_val >> 8) % 100

			match biome:
				BlockTypes.Biome.DESERT:
					if roll < 25:
						DecorGenerator.place_cactus(data, coords, rx, ry + 1, rz, h_val)
						if ry + 6 > max_y:
							max_y = ry + 6
					elif roll < 45:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.DRY_SHRUB)
					elif roll < 55:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)

				BlockTypes.Biome.PLAINS:
					if roll < 8:
						DecorGenerator.place_oak_tree(data, coords, rx, ry + 1, rz, h_val)
						if ry + 8 > max_y:
							max_y = ry + 8
					elif roll < 40:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.TALL_GRASS)
					elif roll < 55:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.FLOWER_RED)
					elif roll < 70:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.FLOWER_YELLOW)
					elif roll < 78:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)

				BlockTypes.Biome.FOREST:
					if roll < 35:
						DecorGenerator.place_oak_tree(data, coords, rx, ry + 1, rz, h_val)
						if ry + 8 > max_y:
							max_y = ry + 8
					elif roll < 60:
						DecorGenerator.place_birch_tree(data, coords, rx, ry + 1, rz, h_val)
						if ry + 10 > max_y:
							max_y = ry + 10
					elif roll < 80:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.TALL_GRASS)
					elif roll < 90:
						DecorGenerator.set_voxel_safe(data, coords, rx, ry + 1, rz, BlockTypes.Type.FLOWER_RED)

				BlockTypes.Biome.SNOW:
					if roll < 45:
						DecorGenerator.place_pine_tree(data, coords, rx, ry + 1, rz, h_val)
						if ry + 12 > max_y:
							max_y = ry + 12
					elif roll < 60:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)

				BlockTypes.Biome.MOUNTAIN:
					if roll < 40:
						DecorGenerator.place_boulder(data, coords, rx, ry + 1, rz, h_val)
					elif roll < 55 and ry < 62:
						DecorGenerator.place_pine_tree(data, coords, rx, ry + 1, rz, h_val)
						if ry + 12 > max_y:
							max_y = ry + 12

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


## Calcul de l'Ambient Occlusion par vertex (Thread-safe)
static func compute_vertex_ao(data: PackedByteArray, coords: Vector2i, pos: Vector3i, norm: Vector3i, side1: Vector3i, side2: Vector3i, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite) -> float:
	var s1: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side1.x, pos.y + norm.y + side1.y, pos.z + norm.z + side1.z, t_noise, temp_noise, hum_noise))
	var s2: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side2.x, pos.y + norm.y + side2.y, pos.z + norm.z + side2.z, t_noise, temp_noise, hum_noise))
	var c: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side1.x + side2.x, pos.y + norm.y + side1.y + side2.y, pos.z + norm.z + side1.z + side2.z, t_noise, temp_noise, hum_noise))

	var ao_level: int = 0
	if s1 and s2:
		ao_level = 3
	else:
		ao_level = (1 if s1 else 0) + (1 if s2 else 0) + (1 if c else 0)

	match ao_level:
		1:
			return 0.82
		2:
			return 0.65
		3:
			return 0.45
		_:
			return 1.0


## Construit les tableaux de géométrie pour le maillage et les collisions (Thread-safe) avec support LOD
static func build_mesh_data(data: PackedByteArray, coords: Vector2i, max_y: int, t_noise: FastNoiseLite, temp_noise: FastNoiseLite, hum_noise: FastNoiseLite, lod_level: int = 0) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	var decor_instances: Array[Dictionary] = []

	var vertex_counter: int = 0

	for x in range(CHUNK_WIDTH):
		for y in range(max_y + 1):
			for z in range(CHUNK_DEPTH):
				var block: int = data[get_voxel_index(x, y, z)]
				if block == BlockTypes.Type.AIR:
					continue

				var base_offset := Vector3(x, y, z)

				# Décor surfacique géré via MultiMeshInstance3D pour des performances optimales
				if BlockTypes.is_plant(block):
					if lod_level == 0:
						var plant_color: Color = BlockTypes.get_face_color(block, Vector3i.UP)
						decor_instances.append({
							"pos": base_offset + Vector3(0.5, 0.45, 0.5),
							"color": plant_color
						})
					continue

				# Rendu voxel cubique standard
				var block_pos := Vector3i(x, y, z)
				var is_block_solid: bool = BlockTypes.is_solid(block)

				for face_idx in range(6):
					var dir: Vector3i = FACE_DIRECTIONS[face_idx]
					var neighbor_block: int = get_block_from_data(data, coords, x + dir.x, y + dir.y, z + dir.z, t_noise, temp_noise, hum_noise)

					if BlockTypes.is_opaque(neighbor_block):
						continue

					if block == BlockTypes.Type.WATER and neighbor_block == BlockTypes.Type.WATER:
						continue

					var face_norm := Vector3(dir.x, dir.y, dir.z)
					var base_color: Color = BlockTypes.get_face_color(block, dir)
					var face_verts: Array = FACE_VERTICES[face_idx]
					var tangents: Array = FACE_TANGENTS[face_idx]
					var tan_u: Vector3i = tangents[0]
					var tan_v: Vector3i = tangents[1]

					var ao_factors: Array[float]
					if lod_level > 0:
						ao_factors = [1.0, 1.0, 1.0, 1.0]
					else:
						ao_factors = [
							compute_vertex_ao(data, coords, block_pos, dir, -tan_u, -tan_v, t_noise, temp_noise, hum_noise),
							compute_vertex_ao(data, coords, block_pos, dir, -tan_u, tan_v, t_noise, temp_noise, hum_noise),
							compute_vertex_ao(data, coords, block_pos, dir, tan_u, tan_v, t_noise, temp_noise, hum_noise),
							compute_vertex_ao(data, coords, block_pos, dir, tan_u, -tan_v, t_noise, temp_noise, hum_noise)
						]

					var v0: Vector3 = base_offset + face_verts[0]
					var v1: Vector3 = base_offset + face_verts[1]
					var v2: Vector3 = base_offset + face_verts[2]
					var v3: Vector3 = base_offset + face_verts[3]

					vertices.push_back(v0)
					vertices.push_back(v1)
					vertices.push_back(v2)
					vertices.push_back(v3)

					for i in range(4):
						normals.push_back(face_norm)
						var shaded := Color(
							base_color.r * ao_factors[i],
							base_color.g * ao_factors[i],
							base_color.b * ao_factors[i],
							base_color.a
						)
						colors.push_back(shaded)

					var flip: bool = (ao_factors[0] + ao_factors[2] > ao_factors[1] + ao_factors[3])
					if flip:
						indices.push_back(vertex_counter + 1)
						indices.push_back(vertex_counter + 2)
						indices.push_back(vertex_counter + 3)
						indices.push_back(vertex_counter + 1)
						indices.push_back(vertex_counter + 3)
						indices.push_back(vertex_counter + 0)

						if lod_level == 0 and is_block_solid:
							collision_faces.push_back(v1)
							collision_faces.push_back(v2)
							collision_faces.push_back(v3)
							collision_faces.push_back(v1)
							collision_faces.push_back(v3)
							collision_faces.push_back(v0)
					else:
						indices.push_back(vertex_counter + 0)
						indices.push_back(vertex_counter + 1)
						indices.push_back(vertex_counter + 2)
						indices.push_back(vertex_counter + 0)
						indices.push_back(vertex_counter + 2)
						indices.push_back(vertex_counter + 3)

						if lod_level == 0 and is_block_solid:
							collision_faces.push_back(v0)
							collision_faces.push_back(v1)
							collision_faces.push_back(v2)
							collision_faces.push_back(v0)
							collision_faces.push_back(v2)
							collision_faces.push_back(v3)

					vertex_counter += 4

	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	return {
		"mesh_arrays": mesh_arrays,
		"collision_faces": collision_faces,
		"decor_instances": decor_instances
	}


## Applique le maillage, les collisions et le décor MultiMesh sur le Chunk (Thread Principal)
func apply_mesh_and_collision(mesh_arrays: Array, collision_faces: PackedVector3Array, material: Material, decor_data: Array = []) -> void:
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	array_mesh.surface_set_material(0, material)

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)

	mesh_instance.mesh = array_mesh

	# Collision (uniquement pour les chunks proches en LOD 0)
	if not collision_faces.is_empty():
		if collision_shape == null:
			collision_shape = CollisionShape3D.new()
			add_child(collision_shape)

		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
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
	cross_box.size = Vector3(0.5, 0.75, 0.5)
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
