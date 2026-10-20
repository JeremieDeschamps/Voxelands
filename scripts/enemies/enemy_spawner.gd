class_name EnemySpawner
extends Node3D

## Gestionnaire d'apparition dynamique des ennemis selon le biome et la proximité du joueur.

const BlockTypes = preload("res://scripts/world/block_types.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const EnemyBase = preload("res://scripts/enemies/enemy_base.gd")
const WolfEnemy = preload("res://scripts/enemies/wolf.gd")
const SkeletonEnemy = preload("res://scripts/enemies/skeleton.gd")
const SlimeEnemy = preload("res://scripts/enemies/slime.gd")
const GolemEnemy = preload("res://scripts/enemies/golem.gd")

@export var max_enemies: int = 14
@export var spawn_interval: float = 3.5
@export var min_spawn_dist: float = 18.0
@export var max_spawn_dist: float = 38.0
@export var despawn_dist: float = 65.0

var world_ref: Node3D = null
var spawn_timer: float = 0.0


func _ready() -> void:
	world_ref = get_parent()


func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_attempt_spawn()
		_cleanup_distant_enemies()


func _attempt_spawn() -> void:
	var active_enemies := get_tree().get_nodes_in_group("enemies")
	if active_enemies.size() >= max_enemies:
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: CharacterBody3D = players[0]
	var player_pos: Vector3 = player.global_position

	# Position circulaire aléatoire autour du joueur
	var angle: float = randf() * TAU
	var dist: float = randf_range(min_spawn_dist, max_spawn_dist)
	var sx: int = int(player_pos.x + cos(angle) * dist)
	var sz: int = int(player_pos.z + sin(angle) * dist)

	if world_ref == null or not ("terrain_noise" in world_ref):
		return

	var t_noise: FastNoiseLite = world_ref.terrain_noise
	var temp_noise: FastNoiseLite = world_ref.temperature_noise
	var hum_noise: FastNoiseLite = world_ref.humidity_noise

	var sy: int = Chunk.get_height_at(t_noise, sx, sz)
	if sy <= Chunk.SEA_LEVEL:
		return # Évite de faire apparaître des ennemis terrestres sous l'eau

	var temp: float = temp_noise.get_noise_2d(float(sx), float(sz))
	var hum: float = hum_noise.get_noise_2d(float(sx), float(sz))
	var biome: int = Chunk.get_biome_at(temp, hum, sy)

	var enemy_instance: EnemyBase = null
	var roll: float = randf()

	match biome:
		BlockTypes.Biome.DESERT:
			if roll < 0.6:
				enemy_instance = SkeletonEnemy.new()
			else:
				enemy_instance = GolemEnemy.new()

		BlockTypes.Biome.SNOW:
			if roll < 0.65:
				enemy_instance = WolfEnemy.new()
			else:
				enemy_instance = GolemEnemy.new()

		BlockTypes.Biome.MOUNTAIN:
			if roll < 0.7:
				enemy_instance = GolemEnemy.new()
			else:
				enemy_instance = SkeletonEnemy.new()

		BlockTypes.Biome.FOREST:
			if roll < 0.5:
				enemy_instance = WolfEnemy.new()
			elif roll < 0.8:
				enemy_instance = SlimeEnemy.new()
			else:
				enemy_instance = SkeletonEnemy.new()

		_: # PLAINS / BEACH
			if roll < 0.4:
				enemy_instance = SlimeEnemy.new()
			elif roll < 0.75:
				enemy_instance = WolfEnemy.new()
			else:
				enemy_instance = SkeletonEnemy.new()

	if enemy_instance != null:
		enemy_instance.position = Vector3(float(sx), float(sy) + 1.2, float(sz))
		add_child(enemy_instance)


func _cleanup_distant_enemies() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player_pos: Vector3 = players[0].global_position
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if is_instance_valid(enemy):
			if enemy.global_position.distance_to(player_pos) > despawn_dist:
				enemy.queue_free()
