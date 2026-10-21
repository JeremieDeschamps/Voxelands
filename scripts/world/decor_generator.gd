class_name DecorGenerator
extends RefCounted

## Générateur procédural de décorations végétales et minérales (arbres détaillés, cactus, rochers, fleurs).
## Modélisé à l'échelle métrique avec des petits voxels (VOXEL_SIZE).

const BlockTypes = preload("res://scripts/world/block_types.gd")
const VoxelConstants = preload("res://scripts/world/voxel_constants.gd")

const CHUNK_WIDTH: int = VoxelConstants.CHUNK_WIDTH
const CHUNK_DEPTH: int = VoxelConstants.CHUNK_DEPTH
const CHUNK_HEIGHT: int = VoxelConstants.CHUNK_HEIGHT

## Taille de cellule d'espacement des décorations (environ 6 mètres en voxels)
const CELL_SIZE: int = int(round(6.0 / VoxelConstants.VOXEL_SIZE))


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


## Place un grand chêne détaillé (tronc 2x2 voxels et feuillage sphérique volumique)
static func place_oak_tree(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var height_m: float = 4.5 + float(rng_val % 4) * 0.5
	var trunk_h: int = int(round(height_m / VoxelConstants.VOXEL_SIZE))

	# Tronc 2x2 voxels (1m de diamètre)
	for dy in range(trunk_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.WOOD, true)
		set_voxel_safe(voxels, chunk_coords, wx + 1, wy + dy, wz, BlockTypes.Type.WOOD, true)
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz + 1, BlockTypes.Type.WOOD, true)
		set_voxel_safe(voxels, chunk_coords, wx + 1, wy + dy, wz + 1, BlockTypes.Type.WOOD, true)

	# Couronne de feuillage sphérique généreuse
	var leaf_radius_m: float = 2.2 + float((rng_val >> 3) % 3) * 0.3
	var rad_v: int = int(round(leaf_radius_m / VoxelConstants.VOXEL_SIZE))
	var center_y: int = wy + trunk_h - 1

	for dy in range(-rad_v, rad_v + 1):
		for dx in range(-rad_v, rad_v + 2):
			for dz in range(-rad_v, rad_v + 2):
				var dist_sq: float = float(dx * dx + dy * dy * 1.3 + dz * dz)
				if dist_sq <= float(rad_v * rad_v) + 0.5:
					# Éviter d'écraser le tronc principal
					set_voxel_safe(voxels, chunk_coords, wx + dx, center_y + dy, wz + dz, BlockTypes.Type.LEAVES, false)


## Place un bouleau détaillé (tronc élancé blanc et feuillage ovoïde compact)
static func place_birch_tree(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var height_m: float = 6.0 + float(rng_val % 4) * 0.6
	var trunk_h: int = int(round(height_m / VoxelConstants.VOXEL_SIZE))

	for dy in range(trunk_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.BIRCH_WOOD, true)
		if dy < trunk_h - 4 and (dy % 3 == 0):
			set_voxel_safe(voxels, chunk_coords, wx + 1, wy + dy, wz, BlockTypes.Type.BIRCH_WOOD, true)

	var rad_v: int = int(round(1.6 / VoxelConstants.VOXEL_SIZE))
	var leaf_start: int = wy + trunk_h - int(round(3.5 / VoxelConstants.VOXEL_SIZE))
	var leaf_end: int = wy + trunk_h + 1

	for ly in range(leaf_start, leaf_end + 1):
		var dy_f: float = float(ly - (leaf_start + leaf_end) / 2)
		var cur_rad: int = int(round(float(rad_v) * (1.0 - (dy_f * dy_f) / float(rad_v * rad_v * 3))))
		cur_rad = maxi(cur_rad, 1)
		for dx in range(-cur_rad, cur_rad + 1):
			for dz in range(-cur_rad, cur_rad + 1):
				if dx * dx + dz * dz <= cur_rad * cur_rad + 1:
					set_voxel_safe(voxels, chunk_coords, wx + dx, ly, wz + dz, BlockTypes.Type.LEAVES, false)


## Place un pin / sapin détaillé (étages coniques réguliers d'aiguilles sombres)
static func place_pine_tree(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var height_m: float = 7.5 + float(rng_val % 4) * 0.8
	var trunk_h: int = int(round(height_m / VoxelConstants.VOXEL_SIZE))

	# Tronc de pin
	for dy in range(trunk_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.PINE_WOOD, true)

	var leaf_start: int = wy + int(round(2.0 / VoxelConstants.VOXEL_SIZE))
	var leaf_end: int = wy + trunk_h

	for ly in range(leaf_start, leaf_end + 1):
		var dist_from_top: float = float(leaf_end - ly) * VoxelConstants.VOXEL_SIZE
		var layer_m: float = 0.5 + dist_from_top * 0.32
		var rad: int = int(round(layer_m / VoxelConstants.VOXEL_SIZE))
		# Alternance de motifs pour créer des branches distinctes
		var is_rim: bool = (ly % 2 == 0)
		for dx in range(-rad, rad + 1):
			for dz in range(-rad, rad + 1):
				var d2: int = dx * dx + dz * dz
				if d2 <= rad * rad:
					if is_rim and (absi(dx) == rad and absi(dz) == rad):
						continue
					set_voxel_safe(voxels, chunk_coords, wx + dx, ly, wz + dz, BlockTypes.Type.PINE_LEAVES, false)

	# Cime pointue
	set_voxel_safe(voxels, chunk_coords, wx, leaf_end + 1, wz, BlockTypes.Type.PINE_LEAVES, false)
	set_voxel_safe(voxels, chunk_coords, wx, leaf_end + 2, wz, BlockTypes.Type.PINE_LEAVES, false)


## Place un cactus détaillé avec bras asymétriques en voxels
static func place_cactus(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var height_m: float = 2.5 + float(rng_val % 3) * 0.5
	var cactus_h: int = int(round(height_m / VoxelConstants.VOXEL_SIZE))

	# Tronc principal
	for dy in range(cactus_h):
		set_voxel_safe(voxels, chunk_coords, wx, wy + dy, wz, BlockTypes.Type.CACTUS, true)

	var arm_offset: int = int(round(0.8 / VoxelConstants.VOXEL_SIZE))
	# Bras latéral gauche
	if (rng_val & 1) != 0 and cactus_h >= 5:
		var arm_y: int = wy + int(round(cactus_h * 0.35))
		for o in range(1, arm_offset + 1):
			set_voxel_safe(voxels, chunk_coords, wx + o, arm_y, wz, BlockTypes.Type.CACTUS, true)
		for h in range(1, arm_offset + 2):
			set_voxel_safe(voxels, chunk_coords, wx + arm_offset, arm_y + h, wz, BlockTypes.Type.CACTUS, true)

	# Bras latéral droit
	if (rng_val & 2) != 0 and cactus_h >= 6:
		var arm_y2: int = wy + int(round(cactus_h * 0.55))
		for o in range(1, arm_offset + 1):
			set_voxel_safe(voxels, chunk_coords, wx - o, arm_y2, wz, BlockTypes.Type.CACTUS, true)
		for h in range(1, arm_offset + 2):
			set_voxel_safe(voxels, chunk_coords, wx - arm_offset, arm_y2 + h, wz, BlockTypes.Type.CACTUS, true)


## Place un rocher / bloc minéral sculpté en voxels
static func place_boulder(voxels: PackedByteArray, chunk_coords: Vector2i, wx: int, wy: int, wz: int, rng_val: int) -> void:
	var radius_m: float = 0.8 + float(rng_val % 3) * 0.4
	var rad: int = int(round(radius_m / VoxelConstants.VOXEL_SIZE))

	for dy in range(0, rad + 1):
		for dx in range(-rad, rad + 1):
			for dz in range(-rad, rad + 1):
				if dx * dx + dy * dy * 1.4 + dz * dz <= rad * rad + 1:
					set_voxel_safe(voxels, chunk_coords, wx + dx, wy + dy, wz + dz, BlockTypes.Type.ROCK, true)
