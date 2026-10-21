class_name BlockTypes
extends RefCounted

## Définition des identifiants, biomes et propriétés des blocs voxel.

enum Type {
	AIR = 0,
	DIRT = 1,
	GRASS = 2,
	FOREST_GRASS = 3,
	STONE = 4,
	SAND = 5,
	SANDSTONE = 6,
	WATER = 7,
	WOOD = 8,
	LEAVES = 9,
	SNOW = 10,
	SNOW_DIRT = 11,
	CACTUS = 12,
	PINE_WOOD = 13,
	PINE_LEAVES = 14,
	BIRCH_WOOD = 15,
	ROCK = 16,
	FLOWER_RED = 17,
	FLOWER_YELLOW = 18,
	TALL_GRASS = 19,
	DRY_SHRUB = 20,
}

enum Biome {
	OCEAN = 0,
	BEACH = 1,
	DESERT = 2,
	PLAINS = 3,
	FOREST = 4,
	SNOW = 5,
	MOUNTAIN = 6,
}

# Palettes de couleurs par vertex (style RPG voxel vif et saturé)
const COLOR_DIRT := Color(0.46, 0.30, 0.18)
const COLOR_GRASS_TOP := Color(0.24, 0.78, 0.20)         # Vert vif prairie
const COLOR_GRASS_SIDE := Color(0.38, 0.55, 0.22)
const COLOR_FOREST_GRASS_TOP := Color(0.16, 0.64, 0.18)  # Vert émeraude forêt
const COLOR_FOREST_GRASS_SIDE := Color(0.32, 0.48, 0.18)
const COLOR_STONE := Color(0.50, 0.46, 0.42)             # Roche gris-brun chaude
const COLOR_SAND := Color(0.96, 0.84, 0.46)              # Sable chaud doré
const COLOR_SANDSTONE := Color(0.85, 0.72, 0.38)
const COLOR_WATER := Color(0.12, 0.52, 0.90, 0.78)
const COLOR_WOOD := Color(0.40, 0.24, 0.14)
const COLOR_LEAVES := Color(0.20, 0.68, 0.18)
const COLOR_SNOW := Color(0.90, 0.95, 1.0)               # Neige blanc-bleuté
const COLOR_SNOW_DIRT_SIDE := Color(0.68, 0.62, 0.58)
const COLOR_CACTUS := Color(0.22, 0.66, 0.22)
const COLOR_PINE_WOOD := Color(0.26, 0.16, 0.10)
const COLOR_PINE_LEAVES := Color(0.10, 0.42, 0.22)
const COLOR_BIRCH_WOOD := Color(0.92, 0.90, 0.86)
const COLOR_ROCK := Color(0.42, 0.38, 0.36)              # Roche gris-brun
const COLOR_FLOWER_RED := Color(0.96, 0.18, 0.18)
const COLOR_FLOWER_YELLOW := Color(1.0, 0.88, 0.12)
const COLOR_TALL_GRASS := Color(0.28, 0.78, 0.22)
const COLOR_DRY_SHRUB := Color(0.72, 0.58, 0.32)

## Indique si le bloc est opaque pour le culling des faces adjacentes
static func is_opaque(block_type: int) -> bool:
	match block_type:
		Type.AIR, Type.WATER, Type.LEAVES, Type.PINE_LEAVES, \
		Type.FLOWER_RED, Type.FLOWER_YELLOW, Type.TALL_GRASS, Type.DRY_SHRUB:
			return false
		_:
			return true

## Indique si le bloc possède une collision solide pour le joueur
static func is_solid(block_type: int) -> bool:
	match block_type:
		Type.AIR, Type.WATER, \
		Type.FLOWER_RED, Type.FLOWER_YELLOW, Type.TALL_GRASS, Type.DRY_SHRUB:
			return false
		_:
			return true

## Indique si le bloc est un élément végétal de type croix (fleurs, herbes)
static func is_plant(block_type: int) -> bool:
	match block_type:
		Type.FLOWER_RED, Type.FLOWER_YELLOW, Type.TALL_GRASS, Type.DRY_SHRUB:
			return true
		_:
			return false

## Retourne la couleur selon le type de bloc et l'orientation de la face
static func get_face_color(block_type: int, face_direction: Vector3i) -> Color:
	match block_type:
		Type.GRASS:
			if face_direction == Vector3i.UP:
				return COLOR_GRASS_TOP
			elif face_direction == Vector3i.DOWN:
				return COLOR_DIRT
			return COLOR_GRASS_SIDE
		Type.FOREST_GRASS:
			if face_direction == Vector3i.UP:
				return COLOR_FOREST_GRASS_TOP
			elif face_direction == Vector3i.DOWN:
				return COLOR_DIRT
			return COLOR_FOREST_GRASS_SIDE
		Type.SNOW_DIRT:
			if face_direction == Vector3i.UP:
				return COLOR_SNOW
			elif face_direction == Vector3i.DOWN:
				return COLOR_DIRT
			return COLOR_SNOW_DIRT_SIDE
		Type.DIRT:
			return COLOR_DIRT
		Type.STONE:
			return COLOR_STONE
		Type.SAND:
			return COLOR_SAND
		Type.SANDSTONE:
			return COLOR_SANDSTONE
		Type.WATER:
			return COLOR_WATER
		Type.WOOD:
			return COLOR_WOOD
		Type.LEAVES:
			return COLOR_LEAVES
		Type.SNOW:
			return COLOR_SNOW
		Type.CACTUS:
			return COLOR_CACTUS
		Type.PINE_WOOD:
			return COLOR_PINE_WOOD
		Type.PINE_LEAVES:
			return COLOR_PINE_LEAVES
		Type.BIRCH_WOOD:
			return COLOR_BIRCH_WOOD
		Type.ROCK:
			return COLOR_ROCK
		Type.FLOWER_RED:
			return COLOR_FLOWER_RED
		Type.FLOWER_YELLOW:
			return COLOR_FLOWER_YELLOW
		Type.TALL_GRASS:
			return COLOR_TALL_GRASS
		Type.DRY_SHRUB:
			return COLOR_DRY_SHRUB
		_:
			return Color.WHITE
