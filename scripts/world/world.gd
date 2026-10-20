class_name World
extends Node3D

## Gestionnaire du monde voxel infini par chunks avec génération multithreadée.

const Chunk = preload("res://scripts/world/chunk.gd")

@export var render_distance: int = 4
@export var noise_seed: int = 1337
@export var noise_frequency: float = 0.007
@export var target_node: Node3D = null

const MAX_CONCURRENT_TASKS: int = 4

var noise: FastNoiseLite = FastNoiseLite.new()
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
	_init_noise()
	_init_material()

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
	# Attente propre de la fin des tâches au déchargement
	for task_id: int in active_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
	active_tasks.clear()


func _init_noise() -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5


func _init_material() -> void:
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.9
	terrain_material.cull_mode = BaseMaterial3D.CULL_BACK


func _process(delta: float) -> void:
	# 1. Vérification des tâches terminées dans le WorkerThreadPool
	_check_worker_tasks()

	# 2. Intégration sur le thread principal des maillages prêts
	_process_completed_chunks()

	# 3. Lancement des prochaines tâches en attente
	_dispatch_pending_chunks()

	# 4. Vérification périodique du déplacement de la caméra
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


## Met à jour les listes de chunks nécessaires et décharge les chunks distants
func _update_chunks_around_target() -> void:
	var target_chunk: Vector2i = last_player_chunk

	# Déchargement des chunks hors de portée
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

	# Tri par proximité pour charger les chunks proches en priorité
	var new_coords: Array[Vector2i] = []
	for dx in range(-render_distance, render_distance + 1):
		for dz in range(-render_distance, render_distance + 1):
			if (dx * dx + dz * dz) > (render_distance * render_distance):
				continue

			var coords := Vector2i(target_chunk.x + dx, target_chunk.y + dz)
			if not active_chunks.has(coords) and not pending_coords.has(coords) and not _is_task_running_for(coords):
				new_coords.append(coords)

	# Tri par distance croissante à la cible
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


## Lance les tâches de calcul dans WorkerThreadPool
func _dispatch_pending_chunks() -> void:
	while active_tasks.size() < MAX_CONCURRENT_TASKS and not pending_coords.is_empty():
		var coords: Vector2i = pending_coords.pop_front()
		var task_id: int = WorkerThreadPool.add_task(
			Callable(self, "_worker_task_generate").bind(coords),
			false,
			"ChunkGen_" + str(coords)
		)
		active_tasks[task_id] = coords


## Méthode exécutée dans le thread de travail (100% calcul pur de données)
func _worker_task_generate(coords: Vector2i) -> void:
	var gen_result: Dictionary = Chunk.generate_voxel_data(coords, noise)
	var voxels: PackedByteArray = gen_result["voxels"]
	var max_y: int = gen_result["max_y"]
	var mesh_arrays: Array = Chunk.build_mesh_data(voxels, coords, max_y, noise)

	thread_mutex.lock()
	completed_queue.append({
		"coords": coords,
		"voxels": voxels,
		"mesh_arrays": mesh_arrays
	})
	thread_mutex.unlock()


## Libère les tâches terminées dans le WorkerThreadPool
func _check_worker_tasks() -> void:
	var finished_tasks: Array[int] = []
	for task_id: int in active_tasks.keys():
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			finished_tasks.append(task_id)

	for task_id in finished_tasks:
		active_tasks.erase(task_id)


## Intègre les maillages et collisions sur le thread principal
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

		var dx: int = coords.x - last_player_chunk.x
		var dz: int = coords.y - last_player_chunk.y
		var max_dist_sq: int = (render_distance + 2) * (render_distance + 2)

		if (dx * dx + dz * dz) <= max_dist_sq:
			var chunk := Chunk.new(coords)
			chunk.voxels = voxels
			add_child(chunk)
			chunk.apply_mesh_and_collision(mesh_arrays, terrain_material)
			active_chunks[coords] = chunk
