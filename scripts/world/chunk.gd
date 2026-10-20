class_name Chunk
extends StaticBody3D

## Représente un chunk de terrain voxel de 16x16x128 blocs.

const BlockTypes = preload("res://scripts/world/block_types.gd")

const CHUNK_WIDTH: int = 16
const CHUNK_DEPTH: int = 16
const CHUNK_HEIGHT: int = 128
const TOTAL_VOXELS: int = CHUNK_WIDTH * CHUNK_DEPTH * CHUNK_HEIGHT
const SEA_LEVEL: int = 30

var chunk_coords: Vector2i = Vector2i.ZERO
var voxels: PackedByteArray = PackedByteArray()
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

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

# Vecteurs tangents (U, V) pour le calcul de l'occlusion ambiante (AO)
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
	var h: float = 38.0 + (base_val * 24.0)
	return clampi(int(round(h)), 1, CHUNK_HEIGHT - 2)


## Détermine le type de bloc en coordonnées monde
static func get_block_type_at(noise: FastNoiseLite, world_x: int, y: int, world_z: int) -> int:
	if y <= 0:
		return BlockTypes.Type.STONE
	if y >= CHUNK_HEIGHT:
		return BlockTypes.Type.AIR

	var terrain_h: int = get_height_at(noise, world_x, world_z)

	if y > terrain_h:
		if y <= SEA_LEVEL:
			return BlockTypes.Type.WATER
		return BlockTypes.Type.AIR

	if y == terrain_h:
		if y <= SEA_LEVEL + 1:
			return BlockTypes.Type.SAND
		elif y >= 55:
			return BlockTypes.Type.STONE
		else:
			return BlockTypes.Type.GRASS

	if y > terrain_h - 4:
		if terrain_h <= SEA_LEVEL + 1:
			return BlockTypes.Type.SAND
		return BlockTypes.Type.DIRT

	return BlockTypes.Type.STONE


## Génère les données de voxels sous forme de PackedByteArray pur (Thread-safe)
static func generate_voxel_data(coords: Vector2i, noise: FastNoiseLite) -> Dictionary:
	var data := PackedByteArray()
	data.resize(TOTAL_VOXELS)

	var world_origin_x: int = coords.x * CHUNK_WIDTH
	var world_origin_z: int = coords.y * CHUNK_DEPTH
	var max_y: int = SEA_LEVEL

	for x in range(CHUNK_WIDTH):
		var wx: int = world_origin_x + x
		for z in range(CHUNK_DEPTH):
			var wz: int = world_origin_z + z
			var terrain_h: int = get_height_at(noise, wx, wz)
			if terrain_h > max_y:
				max_y = terrain_h

			for y in range(CHUNK_HEIGHT):
				var block: int = BlockTypes.Type.AIR

				if y <= terrain_h:
					if y == terrain_h:
						if y <= SEA_LEVEL + 1:
							block = BlockTypes.Type.SAND
						elif y >= 55:
							block = BlockTypes.Type.STONE
						else:
							block = BlockTypes.Type.GRASS
					elif y > terrain_h - 4:
						if terrain_h <= SEA_LEVEL + 1:
							block = BlockTypes.Type.SAND
						else:
							block = BlockTypes.Type.DIRT
					else:
						block = BlockTypes.Type.STONE
				elif y <= SEA_LEVEL:
					block = BlockTypes.Type.WATER

				data[get_voxel_index(x, y, z)] = block

	return {
		"voxels": data,
		"max_y": mini(max_y + 1, CHUNK_HEIGHT - 1)
	}


## Lecture d'un bloc local ou consultation du relief voisin
static func get_block_from_data(data: PackedByteArray, coords: Vector2i, x: int, y: int, z: int, noise: FastNoiseLite) -> int:
	if y < 0:
		return BlockTypes.Type.STONE
	if y >= CHUNK_HEIGHT:
		return BlockTypes.Type.AIR

	if x >= 0 and x < CHUNK_WIDTH and z >= 0 and z < CHUNK_DEPTH:
		return data[get_voxel_index(x, y, z)]

	var wx: int = (coords.x * CHUNK_WIDTH) + x
	var wz: int = (coords.y * CHUNK_DEPTH) + z
	return get_block_type_at(noise, wx, y, wz)


## Calcul de l'Ambient Occlusion par vertex (Thread-safe)
static func compute_vertex_ao(data: PackedByteArray, coords: Vector2i, pos: Vector3i, norm: Vector3i, side1: Vector3i, side2: Vector3i, noise: FastNoiseLite) -> float:
	var s1: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side1.x, pos.y + norm.y + side1.y, pos.z + norm.z + side1.z, noise))
	var s2: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side2.x, pos.y + norm.y + side2.y, pos.z + norm.z + side2.z, noise))
	var c: bool = BlockTypes.is_opaque(get_block_from_data(data, coords, pos.x + norm.x + side1.x + side2.x, pos.y + norm.y + side1.y + side2.y, pos.z + norm.z + side1.z + side2.z, noise))

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


## Construit les tableaux de géométrie sans aucune allocation de noeud (Thread-safe)
static func build_mesh_data(data: PackedByteArray, coords: Vector2i, max_y: int, noise: FastNoiseLite) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var vertex_counter: int = 0

	for x in range(CHUNK_WIDTH):
		for y in range(max_y + 1):
			for z in range(CHUNK_DEPTH):
				var block: int = data[get_voxel_index(x, y, z)]
				if block == BlockTypes.Type.AIR:
					continue

				var block_pos := Vector3i(x, y, z)
				var base_offset := Vector3(x, y, z)

				for face_idx in range(6):
					var dir: Vector3i = FACE_DIRECTIONS[face_idx]
					var neighbor_block: int = get_block_from_data(data, coords, x + dir.x, y + dir.y, z + dir.z, noise)

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

					var ao_factors: Array[float] = [
						compute_vertex_ao(data, coords, block_pos, dir, -tan_u, -tan_v, noise),
						compute_vertex_ao(data, coords, block_pos, dir, -tan_u, tan_v, noise),
						compute_vertex_ao(data, coords, block_pos, dir, tan_u, tan_v, noise),
						compute_vertex_ao(data, coords, block_pos, dir, tan_u, -tan_v, noise)
					]

					for i in range(4):
						vertices.push_back(base_offset + face_verts[i])
						normals.push_back(face_norm)
						var shaded_color := Color(
							base_color.r * ao_factors[i],
							base_color.g * ao_factors[i],
							base_color.b * ao_factors[i],
							base_color.a
						)
						colors.push_back(shaded_color)

					if ao_factors[0] + ao_factors[2] > ao_factors[1] + ao_factors[3]:
						indices.push_back(vertex_counter + 1)
						indices.push_back(vertex_counter + 2)
						indices.push_back(vertex_counter + 3)

						indices.push_back(vertex_counter + 1)
						indices.push_back(vertex_counter + 3)
						indices.push_back(vertex_counter + 0)
					else:
						indices.push_back(vertex_counter + 0)
						indices.push_back(vertex_counter + 1)
						indices.push_back(vertex_counter + 2)

						indices.push_back(vertex_counter + 0)
						indices.push_back(vertex_counter + 2)
						indices.push_back(vertex_counter + 3)

					vertex_counter += 4

	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	return mesh_arrays


## Applique le maillage et la collision sur le Chunk (Thread Principal)
func apply_mesh_and_collision(mesh_arrays: Array, material: Material) -> void:
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

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(array_mesh.get_faces())
	collision_shape.shape = shape
