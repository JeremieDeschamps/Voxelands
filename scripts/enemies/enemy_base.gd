class_name EnemyBase
extends CharacterBody3D

## Classe de base pour les ennemis voxel avec IA (patrouille, poursuite, attaque) et barre de vie 3D.

const DamageLabel3D = preload("res://scripts/ui/damage_label_3d.gd")
const DeathParticles = preload("res://scripts/enemies/death_particles.gd")
const ItemData = preload("res://scripts/items/item_data.gd")
const LootDrop = preload("res://scripts/items/loot_drop.gd")

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	DEAD
}

@export var max_health: float = 50.0
@export var move_speed: float = 4.0
@export var chase_speed: float = 6.0
@export var attack_damage: float = 12.0
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2
@export var detection_range: float = 18.0
@export var patrol_radius: float = 8.0
@export var enemy_name: String = "Ennemi"
@export var death_color: Color = Color.WHITE

var level: int = 1
var current_health: float = 50.0
var current_state: State = State.IDLE
var target_player: CharacterBody3D = null

var state_timer: float = 0.0
var attack_timer: float = 0.0
var patrol_target: Vector3 = Vector3.ZERO
var spawn_origin: Vector3 = Vector3.ZERO
var knockback_velocity: Vector3 = Vector3.ZERO

# Barre de vie 3D au-dessus de l'ennemi
var health_bar_pivot: Node3D = null
var health_bar_fill: MeshInstance3D = null
var health_bar_bg: MeshInstance3D = null

var gravity: float = 19.6


func _ready() -> void:
	# Montée en puissance selon la distance à l'origine (0, 0, 0)
	var dist: float = global_position.length()
	level = 1 + int(dist / 38.0)
	max_health = roundf(max_health * (1.0 + float(level - 1) * 0.35))
	attack_damage = roundf(attack_damage * (1.0 + float(level - 1) * 0.22))
	current_health = max_health

	spawn_origin = global_position
	patrol_target = global_position
	add_to_group("enemies")

	_create_health_bar()
	_pick_new_patrol_point()


## Crée une barre de vie procédurale en cubes légers orientée vers la caméra
func _create_health_bar() -> void:
	health_bar_pivot = Node3D.new()
	health_bar_pivot.name = "HealthBar"
	health_bar_pivot.position = Vector3(0.0, _get_height_offset(), 0.0)
	add_child(health_bar_pivot)

	# Arrière-plan noir
	health_bar_bg = MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(1.0, 0.1, 0.04)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.12, 0.12, 0.14)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_box.material = bg_mat
	health_bar_bg.mesh = bg_box
	health_bar_pivot.add_child(health_bar_bg)

	# Jauge rouge de santé
	health_bar_fill = MeshInstance3D.new()
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(0.96, 0.08, 0.05)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.92, 0.22, 0.22)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_box.material = fill_mat
	health_bar_fill.mesh = fill_box
	health_bar_pivot.add_child(health_bar_fill)


func _get_height_offset() -> float:
	return 1.6


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Récupération du joueur
	if target_player == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0]

	attack_timer = maxf(attack_timer - delta, 0.0)
	state_timer += delta

	# Amortissement du recul
	if knockback_velocity.length_squared() > 0.01:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 20.0)

	# Machine à états IA
	_update_ai_state(delta)

	# Déplacement physique
	velocity.x += knockback_velocity.x
	velocity.z += knockback_velocity.z
	move_and_slide()

	# Mise à jour de l'affichage de la barre de vie
	_update_health_bar()


func _update_ai_state(delta: float) -> void:
	var dist_to_player: float = 999.0
	if target_player != null and is_instance_valid(target_player):
		dist_to_player = global_position.distance_to(target_player.global_position)

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
			if dist_to_player <= detection_range:
				current_state = State.CHASE
			elif state_timer >= 2.0:
				_pick_new_patrol_point()
				current_state = State.PATROL
				state_timer = 0.0

		State.PATROL:
			if dist_to_player <= detection_range:
				current_state = State.CHASE
			else:
				var to_patrol := (patrol_target - global_position)
				to_patrol.y = 0.0
				if to_patrol.length() < 0.8 or state_timer >= 5.0:
					current_state = State.IDLE
					state_timer = 0.0
				else:
					var move_dir := to_patrol.normalized()
					velocity.x = move_dir.x * move_speed
					velocity.z = move_dir.z * move_speed
					_look_towards(move_dir, delta)

		State.CHASE:
			if target_player == null or dist_to_player > detection_range * 1.5:
				current_state = State.IDLE
				state_timer = 0.0
			elif dist_to_player <= attack_range:
				current_state = State.ATTACK
			else:
				var to_target := (target_player.global_position - global_position)
				to_target.y = 0.0
				var chase_dir := to_target.normalized()
				velocity.x = chase_dir.x * chase_speed
				velocity.z = chase_dir.z * chase_speed
				_look_towards(chase_dir, delta)

		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)

			if dist_to_player > attack_range * 1.3:
				current_state = State.CHASE
			else:
				if attack_timer <= 0.0:
					_execute_attack()
					attack_timer = attack_cooldown


func _execute_attack() -> void:
	if target_player != null and is_instance_valid(target_player):
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage, global_position)


func _pick_new_patrol_point() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(2.0, patrol_radius)
	patrol_target = spawn_origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _look_towards(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.001:
		var target_yaw: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 10.0)


func _update_health_bar() -> void:
	if health_bar_pivot == null:
		return

	var cam := get_viewport().get_camera_3d()
	if cam != null:
		health_bar_pivot.look_at(cam.global_position, Vector3.UP)
		health_bar_pivot.rotate_y(PI) # Rectifie l'alignement face caméra

	var ratio: float = clampf(current_health / max_health, 0.0, 1.0)
	health_bar_fill.scale.x = ratio
	health_bar_fill.position.x = -(1.0 - ratio) * 0.48


## Réception des dégâts infligés par le joueur
func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount

	# Affichage flottant des dégâts
	DamageLabel3D.spawn(get_parent(), global_position + Vector3(0.0, _get_height_offset(), 0.0), int(amount))

	# Recul (Knockback)
	if from_position != Vector3.ZERO:
		var knock_dir := (global_position - from_position).normalized()
		knock_dir.y = 0.2
		knockback_velocity = knock_dir * 8.0

	# Passage immédiat en état de chasse si attaqué
	current_state = State.CHASE

	if current_health <= 0.0:
		die()


## Mort, don d'XP, butin au sol et apparition des particules de débris voxel
func die() -> void:
	current_state = State.DEAD

	# Don d'expérience et notification de quête au joueur
	if target_player != null and is_instance_valid(target_player):
		if target_player.has_method("add_xp"):
			target_player.add_xp(18 * level)
		if ("quest_system" in target_player) and target_player.quest_system != null:
			var et: String = "wolf"
			var nm: String = enemy_name.to_lower()
			if "squelette" in nm or "skeleton" in nm:
				et = "skeleton"
			elif "slime" in nm:
				et = "slime"
			elif "golem" in nm:
				et = "golem"
			target_player.quest_system.notify_kill(et)

	# Butin au sol (65% de chance)
	if randf() < 0.65:
		var item: ItemData = ItemData.generate_random_item(level, global_position.length())
		LootDrop.spawn(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), item)

	DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), death_color)
	queue_free()
