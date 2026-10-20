class_name BlockTypes
extends RefCounted

## Définition des identifiants et propriétés des différents types de blocs voxel.

enum Type {
	AIR = 0,
	DIRT = 1,
	GRASS = 2,
	STONE = 3,
	SAND = 4,
	WATER = 5,
	WOOD = 6,
	LEAVES = 7,
}

# Couleurs par vertex pour chaque type de bloc
const COLOR_DIRT := Color(0.46, 0.33, 0.22)
const COLOR_GRASS_TOP := Color(0.34, 0.65, 0.24)
const COLOR_GRASS_SIDE := Color(0.42, 0.40, 0.22)
const COLOR_STONE := Color(0.52, 0.53, 0.56)
const COLOR_SAND := Color(0.86, 0.78, 0.52)
const COLOR_WATER := Color(0.22, 0.45, 0.78, 0.8)
const COLOR_WOOD := Color(0.38, 0.26, 0.16)
const COLOR_LEAVES := Color(0.20, 0.52, 0.18)

## Indique si le bloc est opaque et bloque la vue des faces adjacentes
static func is_opaque(block_type: int) -> bool:
	return block_type != Type.AIR and block_type != Type.WATER and block_type != Type.LEAVES

## Indique si le bloc est solide pour les collisions
static func is_solid(block_type: int) -> bool:
	return block_type != Type.AIR and block_type != Type.WATER

## Retourne la couleur par vertex du bloc selon la normale de la face (0: UP, 1: DOWN, 2: NORTH, 3: SOUTH, 4: EAST, 5: WEST)
static func get_face_color(block_type: int, face_direction: Vector3i) -> Color:
	match block_type:
		Type.GRASS:
			if face_direction == Vector3i.UP:
				return COLOR_GRASS_TOP
			elif face_direction == Vector3i.DOWN:
				return COLOR_DIRT
			else:
				return COLOR_GRASS_SIDE
		Type.DIRT:
			return COLOR_DIRT
		Type.STONE:
			return COLOR_STONE
		Type.SAND:
			return COLOR_SAND
		Type.WATER:
			return COLOR_WATER
		Type.WOOD:
			return COLOR_WOOD
		Type.LEAVES:
			return COLOR_LEAVES
		_:
			return Color.WHITE
