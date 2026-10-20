class_name DecorGenerator
extends RefCounted

## Générateur procédural de décorations (arbres variés, cactus, rochers, fleurs, herbes).

const BlockTypes = preload("res://scripts/world/block_types.gd")

const CHUNK_WIDTH: int = 16
const CHUNK_DEPTH: int = 16
const CHUNK_HEIGHT: int = 128
const CELL_SIZE: int = 6


## Fonction de hachage 2D pseudo-aléatoire déterministe
static func hash2d(seed_val: int, x: int, z: int) -> int:
	var h: int = seed_val ^ (x * 374761393) ^ (z * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## Écrit un voxel dans le chunk s'il est dans ses limites
static func set_voxel_safe(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, block_type: int, overwrite: bool = false) -> void:
	if wy < 0 or wy >= CHUNK_HEIGHT:
		return

	var lx: int = wx - (chunk_coords.x * CHUNK_WIDTH)
	var lz: int = wz - (chunk_coords.y * CHUNK_DEPTH)

	if lx >= 0 and lx < CHUNK_WIDTH and lz >= 0 and lz < CHUNK_DEPTH:
		var idx: int = lx + (lz * CHUNK_WIDTH) + (wy * CHUNK_WIDTH * CHUNK_DEPTH)
		if overwrite or voxels[idx] == BlockTypes.Type.AIR or voxels[idx] == BlockTypes.Type.WATER:
			voxels[idx] = block_type


## Place un arbre classique (chêne) avec tronc et feuillage arrondi
static func place_oak_tree(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var trunk_h: int = 4 + (rng_val % 3)

	# Tronc
	for dy in range(trunk_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.WOOD, true)

	# Feuillage
	var leaf_base: int = wy + trunk_h - 1
	for ly in range(-1, 3):
		var radius: int = 2 if ly <= 1 else 1
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if dx * dx + dz * dz > (radius * radius + 1):
					continue
				set_voxel_safe(voxels, chunk_coords, wx + dx, leaf_base + ly, wz + dz, BlockTypes.Type.LEAVES, false)


## Place un bouleau (tronc blanc élevé et feuillage compact)
static func place_birch_tree(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var trunk_h: int = 6 + (rng_val % 3)

	for dy in range(trunk_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.BIRCH_WOOD, true)

	var leaf_base: int = wy + trunk_h - 2
	for ly in range(0, 3):
		var radius: int = 2 if ly == 0 else 1
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if dx * dx + dz * dz > radius * radius:
					continue
				set_voxel_safe(voxels, chunk_coords, wx + dx, leaf_base + ly, wz + dz, BlockTypes.Type.LEAVES, false)


## Place un pin / sapin conique avec aiguilles sombres
static func place_pine_tree(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var trunk_h: int = 7 + (rng_val % 3)

	for dy in range(trunk_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.PINE_WOOD, true)

	var leaf_start: int = wy + 3
	var leaf_end: int = wy + trunk_h

	for ly in range(leaf_start, leaf_end + 1):
		var dist_from_top: int = leaf_end - ly
		var radius: int = 1
		if dist_from_top >= 3:
			radius = 2 if (ly % 2 == 0) else 1
		elif dist_from_top >= 1:
			radius = 1

		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if absi(dx) == 2 and absi(dz) == 2:
					continue
				set_voxel_safe(voxels, chunk_coords, wx + dx, ly, wz + dz, BlockTypes.Type.PINE_LEAVES, false)

	# Pointe de l'arbre
	set_voxel_safe(voxels, chunk_coords, wx, leaf_end + 1, wz, BlockTypes.Type.PINE_LEAVES, false)


## Place un cactus avec tronc vertical et bras latéraux
static func place_cactus(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var cactus_h: int = 3 + (rng_val % 3)

	for dy in range(cactus_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.CACTUS, true)

	# Bras latéral gauche
	if (rng_val & 1) != 0 and cactus_h >= 3:
		var arm_y: int = wy + 1
		set_voxel_safe(voxels, chunk_coords, wx + 1, arm_y, wz, BlockTypes.Type.CACTUS, true)
		set_voxel_safe(voxels, chunk_coords, wx + 1, arm_y + 1, wz, BlockTypes.Type.CACTUS, true)

	# Bras latéral droit
	if (rng_val & 2) != 0 and cactus_h >= 4:
		var arm_y2: int = wy + 2
		set_voxel_safe(voxels, chunk_coords, wx - 1, arm_y2, wz, BlockTypes.Type.CACTUS, true)
		set_voxel_safe(voxels, chunk_coords, wx - 1, arm_y2 + 1, wz, BlockTypes.Type.CACTUS, true)


## Place un amas rocheux / rocher naturel
static func place_boulder(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var size_x: int = 2 if (rng_val & 1) != 0 else 1
	var size_z: int = 2 if (rng_val & 2) != 0 else 1

	for dx in range(size_x):
		for dz in range(size_z):
			set_voxel_safe(voxels, chunk_coords, wx + dx, wy, wz + dz, BlockTypes.Type.ROCK, true)
			if (rng_val & 4) != 0 and dx == 0 and dz == 0:
				set_voxel_safe(voxels, chunk_coords, wx + dx, wy + 1, wz + dz, BlockTypes.Type.ROCK, true)
