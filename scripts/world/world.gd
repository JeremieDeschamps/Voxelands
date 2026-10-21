class_name World
extends Node3D

## Gestionnaire du monde voxel infini par chunks avec biomes, décorations et graine reproductible.

const Chunk = preload("res://scripts/world/chunk.gd")
const VillageGenerator = preload("res://scripts/world/village_generator.gd")
const DungeonGenerator = preload("res://scripts/world/dungeon_generator.gd")

@export var world_seed: int = 1337
@export var render_distance: int = 4
@export var target_node: Node3D = null

const MAX_CONCURRENT_TASKS: int = 4

var village_generator: VillageGenerator = null
var dungeon_generator: DungeonGenerator = null


# Générateurs de bruit reproductibles
var terrain_noise: FastNoiseLite = FastNoiseLite.new()
var temperature_noise: FastNoiseLite = FastNoiseLite.new()
var humidity_noise: FastNoiseLite = FastNoiseLite.new()

var terrain_material: StandardMaterial3D = StandardMaterial3D.new()

# Dictionnaires d'état des chunks
var active_chunks: Dictionary = {}    # Vector2i -> Chunk
var pending_coords: Array[Vector2i] = []
var active_tasks: Dictionary = {}     # int (task_id) -> Vector2i (coords)

# Synchronisation inter-threads
var thread_mutex: Mutex = Mutex.new()
var completed_queue: Array[Dictionary] = []

var last_player_chunk: Vector2i = Vector2i(0, 0)
var update_timer: float = 0.0


func _ready() -> void:
	_init_noises()
	_init_material()

	village_generator = VillageGenerator.new()
	village_generator.name = "VillageGenerator"
	village_generator.setup(world_seed, terrain_noise, temperature_noise, humidity_noise)
	add_child(village_generator)

	dungeon_generator = DungeonGenerator.new()
	dungeon_generator.name = "DungeonGenerator"
	dungeon_generator.setup(world_seed, terrain_noise)
	add_child(dungeon_generator)

	if target_node == null:
		target_node = get_viewport().get_camera_3d()

	if target_node != null:
		var target_pos: Vector3 = target_node.global_position
		last_player_chunk = Vector2i(
			int(floor(target_pos.x / float(Chunk.CHUNK_WIDTH))),
			int(floor(target_pos.z / float(Chunk.CHUNK_DEPTH)))
		)

	_update_chunks_around_target()


func _exit_tree() -> void:
	for task_id: int in active_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
	active_tasks.clear()


## Réinitialise entièrement le monde avec une nouvelle graine (seed)
func reinitialize_world(new_seed: int) -> void:
	# 1. Attente et nettoyage des tâches de threads en cours
	for task_id: int in active_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
	active_tasks.clear()
	pending_coords.clear()

	thread_mutex.lock()
	completed_queue.clear()
	thread_mutex.unlock()

	# 2. Suppression de tous les chunks existants
	for chunk in active_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	active_chunks.clear()

	# 3. Réinitialisation des bruits et générateurs
	world_seed = new_seed
	_init_noises()

	if village_generator != null:
		village_generator.setup(world_seed, terrain_noise, temperature_noise, humidity_noise)
	if dungeon_generator != null:
		dungeon_generator.setup(world_seed, terrain_noise)

	if target_node != null:
		var target_pos: Vector3 = target_node.global_position
		last_player_chunk = Vector2i(
			int(floor(target_pos.x / float(Chunk.CHUNK_WIDTH))),
			int(floor(target_pos.z / float(Chunk.CHUNK_DEPTH)))
		)

	_update_chunks_around_target()


func _init_noises() -> void:
	# 1. Relief et élévation
	terrain_noise.seed = world_seed
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.006
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_lacunarity = 2.0
	terrain_noise.fractal_gain = 0.5

	# 2. Carte de température des biomes (froid / tempéré / chaud)
	temperature_noise.seed = world_seed + 101
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temperature_noise.frequency = 0.002
	temperature_noise.fractal_octaves = 2

	# 3. Carte d'humidité des biomes (aride / modéré / luxuriant)
	humidity_noise.seed = world_seed + 202
	humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	humidity_noise.frequency = 0.0025
	humidity_noise.fractal_octaves = 2


func _init_material() -> void:
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.85
	terrain_material.cull_mode = BaseMaterial3D.CULL_BACK


func _process(delta: float) -> void:
	_check_worker_tasks()
	_process_completed_chunks()
	_dispatch_pending_chunks()

	update_timer += delta
	if update_timer >= 0.2:
		update_timer = 0.0
		if target_node == null:
			target_node = get_viewport().get_camera_3d()

		if target_node != null:
			var target_pos: Vector3 = target_node.global_position
			var current_chunk := Vector2i(
				int(floor(target_pos.x / float(Chunk.CHUNK_WIDTH))),
				int(floor(target_pos.z / float(Chunk.CHUNK_DEPTH)))
			)

			if current_chunk != last_player_chunk:
				last_player_chunk = current_chunk
				_update_chunks_around_target()

			if village_generator != null:
				village_generator.update_villages_around(target_pos)
			if dungeon_generator != null:
				dungeon_generator.update_dungeons_around(target_pos)


func _update_chunks_around_target() -> void:
	var target_chunk: Vector2i = last_player_chunk

	# Déchargement des chunks éloignés
	var unload_distance_sq: int = (render_distance + 2) * (render_distance + 2)
	var coords_to_remove: Array[Vector2i] = []

	for coords: Vector2i in active_chunks.keys():
		var dx: int = coords.x - target_chunk.x
		var dz: int = coords.y - target_chunk.y
		if (dx * dx + dz * dz) > unload_distance_sq:
			coords_to_remove.append(coords)

	for coords in coords_to_remove:
		var chunk: Chunk = active_chunks[coords]
		active_chunks.erase(coords)
		if is_instance_valid(chunk):
			chunk.queue_free()

	# Priorisation des nouveaux chunks par distance
	var new_coords: Array[Vector2i] = []
	for dx in range(-render_distance, render_distance + 1):
		for dz in range(-render_distance, render_distance + 1):
			if (dx * dx + dz * dz) > (render_distance * render_distance):
				continue

			var coords := Vector2i(target_chunk.x + dx, target_chunk.y + dz)
			if not active_chunks.has(coords) and not pending_coords.has(coords) and not _is_task_running_for(coords):
				new_coords.append(coords)

	new_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a.x - target_chunk.x) * (a.x - target_chunk.x) + (a.y - target_chunk.y) * (a.y - target_chunk.y)
		var db: int = (b.x - target_chunk.x) * (b.x - target_chunk.x) + (b.y - target_chunk.y) * (b.y - target_chunk.y)
		return da < db
	)

	for c in new_coords:
		pending_coords.append(c)


func _is_task_running_for(coords: Vector2i) -> bool:
	for c in active_tasks.values():
		if c == coords:
			return true
	return false


func _dispatch_pending_chunks() -> void:
	while active_tasks.size() < MAX_CONCURRENT_TASKS and not pending_coords.is_empty():
		var coords: Vector2i = pending_coords.pop_front()
		var task_id: int = WorkerThreadPool.add_task(
			Callable(self, "_worker_task_generate").bind(coords),
			false,
			"ChunkGen_" + str(coords)
		)
		active_tasks[task_id] = coords


## Tâche de calcul en thread d'arrière-plan (Thread-safe)
func _worker_task_generate(coords: Vector2i) -> void:
	var gen_result: Dictionary = Chunk.generate_voxel_data(coords, world_seed, terrain_noise, temperature_noise, humidity_noise)
	var voxels: PackedByteArray = gen_result["voxels"]
	var max_y: int = gen_result["max_y"]

	var dx: int = coords.x - last_player_chunk.x
	var dz: int = coords.y - last_player_chunk.y
	# Chunks distants (> 2 chunks) générés en LOD 1 (sans collisions lourdes et AO simplifié)
	var lod: int = 1 if (dx * dx + dz * dz) > 4 else 0

	var mesh_result: Dictionary = Chunk.build_mesh_data(voxels, coords, max_y, terrain_noise, temperature_noise, humidity_noise, lod)

	thread_mutex.lock()
	completed_queue.append({
		"coords": coords,
		"voxels": voxels,
		"mesh_arrays": mesh_result["mesh_arrays"],
		"collision_faces": mesh_result["collision_faces"],
		"decor_instances": mesh_result.get("decor_instances", [])
	})
	thread_mutex.unlock()


func _check_worker_tasks() -> void:
	var finished_tasks: Array[int] = []
	for task_id: int in active_tasks.keys():
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			finished_tasks.append(task_id)

	for task_id in finished_tasks:
		active_tasks.erase(task_id)


## Intégration sur le thread principal
func _process_completed_chunks() -> void:
	var batch: Array[Dictionary] = []

	thread_mutex.lock()
	if not completed_queue.is_empty():
		batch = completed_queue.duplicate()
		completed_queue.clear()
	thread_mutex.unlock()

	for item in batch:
		var coords: Vector2i = item["coords"]
		var voxels: PackedByteArray = item["voxels"]
		var mesh_arrays: Array = item["mesh_arrays"]
		var collision_faces: PackedVector3Array = item["collision_faces"]
		var decor_instances: Array = item.get("decor_instances", [])

		var dx: int = coords.x - last_player_chunk.x
		var dz: int = coords.y - last_player_chunk.y
		var max_dist_sq: int = (render_distance + 2) * (render_distance + 2)

		if (dx * dx + dz * dz) <= max_dist_sq:
			var chunk := Chunk.new(coords)
			chunk.voxels = voxels
			add_child(chunk)
			chunk.apply_mesh_and_collision(mesh_arrays, collision_faces, terrain_material, decor_instances)
			active_chunks[coords] = chunk
