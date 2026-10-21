class_name VoxelConstants
extends RefCounted

## Configuration globale et fonctions utilitaires de conversion Voxelands (Cube World style).
## Tout le jeu dépend de VOXEL_SIZE.

## Taille d'un voxel unitaire en mètres (facilement modifiable pour essais : 0.5, 0.33, 0.25, 1.0)
const VOXEL_SIZE: float = 0.5

## Dimensions de référence du monde physique en mètres (invariantes quelle que soit VOXEL_SIZE)
const WORLD_HEIGHT_METERS: float = 128.0
const CHUNK_SIZE_METERS: float = 16.0
const SEA_LEVEL_METERS: float = 32.0
const BASE_HEIGHT_METERS: float = 38.0
const HEIGHT_VARIATION_METERS: float = 26.0

## Dimensions d'un chunk en nombre de voxels (dérivées automatiquement de VOXEL_SIZE)
const CHUNK_WIDTH: int = int(round(CHUNK_SIZE_METERS / VOXEL_SIZE))   # 32 voxels si VOXEL_SIZE = 0.5
const CHUNK_DEPTH: int = int(round(CHUNK_SIZE_METERS / VOXEL_SIZE))   # 32 voxels si VOXEL_SIZE = 0.5
const CHUNK_HEIGHT: int = int(round(WORLD_HEIGHT_METERS / VOXEL_SIZE)) # 256 voxels si VOXEL_SIZE = 0.5
const TOTAL_VOXELS: int = CHUNK_WIDTH * CHUNK_DEPTH * CHUNK_HEIGHT

## Hauteurs de référence en voxels
const SEA_LEVEL: int = int(round(SEA_LEVEL_METERS / VOXEL_SIZE))

## Sauvegarde & Versioning
const SAVE_VERSION: int = 4


## Conversion position monde 3D (mètres) -> coordonnées voxel entières
static func world_to_block(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(world_pos.x / VOXEL_SIZE)),
		int(floor(world_pos.y / VOXEL_SIZE)),
		int(floor(world_pos.z / VOXEL_SIZE))
	)


## Conversion coordonnées voxel entières -> position monde 3D (mètres au coin inférieur)
static func block_to_world(block_pos: Vector3i) -> Vector3:
	return Vector3(
		float(block_pos.x) * VOXEL_SIZE,
		float(block_pos.y) * VOXEL_SIZE,
		float(block_pos.z) * VOXEL_SIZE
	)


## Conversion position monde 2D (mètres) -> coordonnées voxel 2D
static func world_to_block_2d(wx: float, wz: float) -> Vector2i:
	return Vector2i(
		int(floor(wx / VOXEL_SIZE)),
		int(floor(wz / VOXEL_SIZE))
	)


## Conversion coordonnées voxel 2D -> position monde 2D (mètres)
static func block_to_world_2d(bx: int, bz: int) -> Vector2:
	return Vector2(
		float(bx) * VOXEL_SIZE,
		float(bz) * VOXEL_SIZE
	)


## Conversion position monde 3D -> coordonnées de chunk
static func world_to_chunk_coords(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE_METERS)),
		int(floor(world_pos.z / CHUNK_SIZE_METERS))
	)


## Conversion coordonnées de chunk -> position d'origine du chunk en mètres
static func chunk_coords_to_world_pos(coords: Vector2i) -> Vector3:
	return Vector3(
		float(coords.x) * CHUNK_SIZE_METERS,
		0.0,
		float(coords.y) * CHUNK_SIZE_METERS
	)
