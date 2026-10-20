class_name PetCompanion
extends CharacterBody3D

## Animal voxel procédural : sauvage puis apprivoisable comme compagnon de combat fidèle.

const CompanionData = preload("res://scripts/player/companion_data.gd")
const DamageLabel3D = preload("res://scripts/ui/damage_label_3d.gd")
const DeathParticles = preload("res://scripts/enemies/death_particles.gd")

enum State {
	WILD,
	TAMED_FOLLOW,
	TAMED_ATTACK,
	TAMED_STAY
}

@export var species_type: int = CompanionData.Species.SHEPHERD_DOG
@export var is_tamed: bool = false
@export var pet_level: int = 1

var state: State = State.WILD
var player_ref: CharacterBody3D = null
var current_target: CharacterBody3D = null

# Caractéristiques
var max_health: float = 100.0
var current_health: float = 100.0
var attack_damage: float = 20.0
var move_speed: float = 6.5
var attack_range: float = 2.2
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0

# Références visuelles
var visuals_node: Node3D = null
var body_mesh: MeshInstance3D = null
var head_node: Node3D = null
var collar_mesh: MeshInstance3D = null
var leg_nodes: Array[Node3D] = []
var wing_nodes: Array[Node3D] = []
var overhead_label: Label3D = null

var walk_phase: float = 0.0
var wander_timer: float = 0.0
var wander_dir: Vector3 = Vector3.ZERO
var gravity: float = 19.6

signal pet_tamed(pet: PetCompanion)
signal pet_died(pet: PetCompanion)
signal pet_hp_changed(current: float, maximum: float)


func _ready() -> void:
	add_to_group("companions")
	_init_stats()
	_build_model()
	_build_overhead_ui()

	if is_tamed:
		state = State.TAMED_FOLLOW
		_update_tamed_visuals()


func _init_stats() -> void:
	var cfg: Dictionary = CompanionData.get_config(species_type)
	var lvl_mult: float = 1.0 + (float(pet_level - 1) * 0.15)
	max_health = cfg["hp"] * lvl_mult
	current_health = max_health
	attack_damage = cfg["dmg"] * lvl_mult
	move_speed = cfg["speed"]
	attack_range = cfg["range"]
	attack_cooldown = cfg["cd"]


func _create_voxel_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	box.material = mat
	mesh_inst.mesh = box
	return mesh_inst


func _build_model() -> void:
	visuals_node = Node3D.new()
	visuals_node.name = "Visuals"
	add_child(visuals_node)

	var cfg: Dictionary = CompanionData.get_config(species_type)
	var body_sz: Vector3 = cfg["size"]
	var b_col: Color = cfg["body_color"]
	var s_col: Color = cfg["secondary_color"]
	var legs_count: int = cfg["legs"]
	var is_flyer: bool = cfg["flyer"]

	# 1. Corps principal
	body_mesh = _create_voxel_cube(body_sz, b_col)
	body_mesh.position = Vector3(0, body_sz.y * 0.6, 0)
	visuals_node.add_child(body_mesh)

	# 2. Tête
	head_node = Node3D.new()
	var h_sz: Vector3 = body_sz * 0.6
	head_node.position = Vector3(0, body_sz.y * 0.9, -body_sz.z * 0.45)
	visuals_node.add_child(head_node)

	var head_cube := _create_voxel_cube(h_sz, b_col)
	head_node.add_child(head_cube)

	# Yeux mignons
	var eye_col := Color(0.12, 0.12, 0.15)
	var left_eye := _create_voxel_cube(Vector3(h_sz.x * 0.25, h_sz.y * 0.25, 0.05), eye_col)
	left_eye.position = Vector3(-h_sz.x * 0.3, h_sz.y * 0.1, -h_sz.z * 0.52)
	head_node.add_child(left_eye)

	var right_eye := _create_voxel_cube(Vector3(h_sz.x * 0.25, h_sz.y * 0.25, 0.05), eye_col)
	right_eye.position = Vector3(h_sz.x * 0.3, h_sz.y * 0.1, -h_sz.z * 0.52)
	head_node.add_child(right_eye)

	# Oreilles / Cornes / Bec
	if is_flyer:
		var beak := _create_voxel_cube(Vector3(h_sz.x * 0.3, h_sz.y * 0.2, h_sz.z * 0.4), s_col)
		beak.position = Vector3(0, -h_sz.y * 0.1, -h_sz.z * 0.65)
		head_node.add_child(beak)
	else:
		var ear_l := _create_voxel_cube(Vector3(h_sz.x * 0.25, h_sz.y * 0.4, h_sz.z * 0.2), s_col)
		ear_l.position = Vector3(-h_sz.x * 0.35, h_sz.y * 0.6, 0.0)
		head_node.add_child(ear_l)

		var ear_r := _create_voxel_cube(Vector3(h_sz.x * 0.25, h_sz.y * 0.4, h_sz.z * 0.2), s_col)
		ear_r.position = Vector3(h_sz.x * 0.35, h_sz.y * 0.6, 0.0)
		head_node.add_child(ear_r)

	# Collier doré (visible quand apprivoisé)
	collar_mesh = _create_voxel_cube(Vector3(body_sz.x * 1.05, 0.08, body_sz.z * 0.3), Color(0.95, 0.82, 0.20))
	collar_mesh.position = Vector3(0, body_sz.y * 0.65, -body_sz.z * 0.3)
	collar_mesh.visible = false
	visuals_node.add_child(collar_mesh)

	# 3. Pattes ou Ailes
	if is_flyer:
		var wing_l := _create_voxel_cube(Vector3(body_sz.x * 0.9, 0.06, body_sz.z * 0.8), s_col)
		wing_l.position = Vector3(-body_sz.x * 0.7, body_sz.y * 0.7, 0)
		visuals_node.add_child(wing_l)
		wing_nodes.append(wing_l)

		var wing_r := _create_voxel_cube(Vector3(body_sz.x * 0.9, 0.06, body_sz.z * 0.8), s_col)
		wing_r.position = Vector3(body_sz.x * 0.7, body_sz.y * 0.7, 0)
		visuals_node.add_child(wing_r)
		wing_nodes.append(wing_r)
	else:
		var leg_h: float = body_sz.y * 0.55
		var leg_w: float = body_sz.x * 0.28
		var offsets: Array[Vector3] = []
		if legs_count == 4:
			offsets = [
				Vector3(-body_sz.x * 0.35, leg_h * 0.5, -body_sz.z * 0.3),
				Vector3(body_sz.x * 0.35, leg_h * 0.5, -body_sz.z * 0.3),
				Vector3(-body_sz.x * 0.35, leg_h * 0.5, body_sz.z * 0.3),
				Vector3(body_sz.x * 0.35, leg_h * 0.5, body_sz.z * 0.3)
			]
		else:
			offsets = [
				Vector3(-body_sz.x * 0.3, leg_h * 0.5, 0),
				Vector3(body_sz.x * 0.3, leg_h * 0.5, 0)
			]

		for off in offsets:
			var leg := _create_voxel_cube(Vector3(leg_w, leg_h, leg_w), s_col)
			leg.position = off
			visuals_node.add_child(leg)
			leg_nodes.append(leg)

	# 4. Forme de collision
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(body_sz.x * 1.2, body_sz.y * 1.3, body_sz.z * 1.2)
	col.shape = box_col
	col.position = Vector3(0, body_sz.y * 0.6, 0)
	add_child(col)


func _build_overhead_ui() -> void:
	overhead_label = Label3D.new()
	overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_label.fixed_size = false
	overhead_label.pixel_size = 0.007
	var cfg: Dictionary = CompanionData.get_config(species_type)
	overhead_label.position = Vector3(0, cfg["size"].y + 0.85, 0)
	overhead_label.modulate = Color(0.9, 0.9, 0.95)
	add_child(overhead_label)
	_update_overhead_text()


func _update_overhead_text() -> void:
	if overhead_label == null:
		return
	var cfg: Dictionary = CompanionData.get_config(species_type)
	var sp_name: String = cfg["name"]
	if is_tamed:
		overhead_label.text = "🐾 %s (Niv.%d)\nHP: %d/%d" % [sp_name, pet_level, int(current_health), int(max_health)]
		overhead_label.modulate = Color(0.35, 0.92, 0.45)
	else:
		overhead_label.text = "%s [F: Apprivoiser]" % sp_name
		overhead_label.modulate = Color(0.85, 0.85, 0.9)


func _update_tamed_visuals() -> void:
	if collar_mesh != null:
		collar_mesh.visible = true
	_update_overhead_text()


## Apprivoise l'animal par le joueur
func tame(player: CharacterBody3D) -> void:
	is_tamed = true
	player_ref = player
	state = State.TAMED_FOLLOW
	pet_level = player_ref.level if "level" in player_ref else 1
	_init_stats()
	_update_tamed_visuals()
	pet_tamed.emit(self)
	pet_hp_changed.emit(current_health, max_health)


## Alterne entre Suivre et Rester
func toggle_command() -> void:
	if not is_tamed:
		return
	if state == State.TAMED_STAY:
		state = State.TAMED_FOLLOW
	else:
		state = State.TAMED_STAY


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_timer > 0.0:
		attack_timer -= delta

	match state:
		State.WILD:
			_process_wild(delta)
		State.TAMED_FOLLOW:
			_process_tamed_follow(delta)
		State.TAMED_ATTACK:
			_process_tamed_attack(delta)
		State.TAMED_STAY:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)

	move_and_slide()
	_animate(delta)


func _process_wild(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(3.0, 6.0)
		if randf() > 0.4:
			var ang: float = randf_range(0, TAU)
			wander_dir = Vector3(cos(ang), 0, sin(ang))
		else:
			wander_dir = Vector3.ZERO

	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * (move_speed * 0.4)
		velocity.z = wander_dir.z * (move_speed * 0.4)
		var look_target: Vector3 = global_position + wander_dir
		visuals_node.look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 3.0)


func _process_tamed_follow(delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0] as CharacterBody3D
		return

	# Recherche d'ennemis menaçants proches du joueur ou de l'animal
	var enemy: CharacterBody3D = _find_nearest_hostile()
	if enemy != null:
		current_target = enemy
		state = State.TAMED_ATTACK
		return

	var dist_to_player: float = global_position.distance_to(player_ref.global_position)

	# Téléportation de secours si trop loin
	if dist_to_player > 35.0:
		global_position = player_ref.global_position + Vector3(randf_range(-2, 2), 1.0, randf_range(-2, 2))
		return

	if dist_to_player > 3.2:
		var dir: Vector3 = (player_ref.global_position - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		var look_target: Vector3 = global_position + dir
		visuals_node.look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)

		if is_on_floor() and is_on_wall():
			velocity.y = 6.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)


func _process_tamed_attack(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target) or ("current_health" in current_target and current_target.current_health <= 0):
		current_target = null
		state = State.TAMED_FOLLOW
		return

	var dist: float = global_position.distance_to(current_target.global_position)
	var dir: Vector3 = (current_target.global_position - global_position).normalized()
	dir.y = 0.0

	var look_target: Vector3 = global_position + dir
	visuals_node.look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)

	if dist > attack_range:
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		if is_on_floor() and is_on_wall():
			velocity.y = 6.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 8.0)

		# Attaque
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_perform_attack(current_target)


func _perform_attack(target: CharacterBody3D) -> void:
	# Animation bond d'attaque
	velocity.y = 3.5
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		DamageLabel3D.spawn(get_parent(), target.global_position + Vector3(0, 1.2, 0), attack_damage, false)


func _find_nearest_hostile() -> CharacterBody3D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var nearest: CharacterBody3D = null
	var min_dist: float = 14.0

	var anchor_pos: Vector3 = player_ref.global_position if player_ref != null else global_position

	for n in enemies:
		if n is CharacterBody3D and is_instance_valid(n):
			var d: float = anchor_pos.distance_to(n.global_position)
			if d < min_dist:
				min_dist = d
				nearest = n as CharacterBody3D

	return nearest


func take_damage(dmg: float) -> void:
	current_health = maxf(current_health - dmg, 0.0)
	_update_overhead_text()
	pet_hp_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_die()


func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	_update_overhead_text()
	pet_hp_changed.emit(current_health, max_health)


func _die() -> void:
	DeathParticles.spawn(get_parent(), global_position)
	pet_died.emit(self)
	queue_free()


func _animate(delta: float) -> void:
	var h_vel := Vector2(velocity.x, velocity.z).length()
	if h_vel > 0.2:
		walk_phase += h_vel * delta * 3.0
		var swing: float = sin(walk_phase) * 0.45
		for i in range(leg_nodes.size()):
			var mult: float = 1.0 if (i % 2 == 0) else -1.0
			leg_nodes[i].rotation.x = swing * mult

		for wing in wing_nodes:
			wing.rotation.z = sin(walk_phase * 2.5) * 0.6
	else:
		walk_phase = 0.0
		for leg in leg_nodes:
			leg.rotation.x = lerp_angle(leg.rotation.x, 0.0, delta * 8.0)
		for wing in wing_nodes:
			wing.rotation.z = lerp_angle(wing.rotation.z, 0.0, delta * 8.0)
