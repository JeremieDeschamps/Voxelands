class_name Player
extends CharacterBody3D

## Contrôleur de joueur voxel complet : combat (attaque de base, compétence), jauges, i-frames, nage et planeur.

const VoxelCharacter = preload("res://scripts/player/voxel_character.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const PlayerHUD = preload("res://scripts/ui/player_hud.gd")
const DeathParticles = preload("res://scripts/enemies/death_particles.gd")

# Caractéristiques physiques
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var swim_speed: float = 4.5
@export var jump_velocity: float = 8.0
@export var glide_fall_speed: float = -2.2
@export var mouse_sensitivity: float = 0.003

# Statistiques RPG du joueur
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 18.0
@export var sprint_stamina_cost: float = 16.0
@export var skill_stamina_cost: float = 30.0

@export var min_zoom: float = 1.8
@export var max_zoom: float = 9.0
@export var zoom_step: float = 0.6

var current_health: float = 100.0
var current_stamina: float = 100.0

# Références aux sous-noeuds
var character_model: VoxelCharacter = null
var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null
var hud: PlayerHUD = null

# États du joueur
var is_gliding: bool = false
var is_swimming: bool = false
var is_mouse_captured: bool = false

# Invincibilité temporaire (i-frames)
var invincibility_timer: float = 0.0
var invincibility_duration: float = 0.55

# Cooldowns d'attaque
var basic_attack_cooldown: float = 0.0
var skill_attack_cooldown: float = 0.0

# Orientation de la caméra
var cam_yaw: float = 0.0
var cam_pitch: float = -0.2

var gravity: float = 19.6


func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	current_stamina = max_stamina

	_setup_inputs_if_missing()
	_build_player_components()
	_capture_mouse()


func _setup_inputs_if_missing() -> void:
	_register_key_action("move_forward", [KEY_W, KEY_Z, KEY_UP])
	_register_key_action("move_back", [KEY_S, KEY_DOWN])
	_register_key_action("move_left", [KEY_A, KEY_Q, KEY_LEFT])
	_register_key_action("move_right", [KEY_D, KEY_RIGHT])
	_register_key_action("jump", [KEY_SPACE])
	_register_key_action("sprint", [KEY_SHIFT])


func _register_key_action(action: String, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for code in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)


func _build_player_components() -> void:
	# 1. Capsule de collision
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	col_shape.shape = capsule
	col_shape.position = Vector3(0.0, 0.88, 0.0)
	add_child(col_shape)

	# 2. Modèle voxel
	character_model = VoxelCharacter.new()
	character_model.name = "CharacterModel"
	add_child(character_model)

	# 3. Pivot et caméra orbitale
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.4, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 5.0
	spring_arm.margin = 0.25
	camera_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	spring_arm.add_child(camera)

	# 4. HUD
	hud = PlayerHUD.new()
	hud.name = "PlayerHUD"
	add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_mouse_captured:
				_capture_mouse()
			elif event.pressed:
				_perform_basic_attack()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and is_mouse_captured:
			_perform_skill_attack()

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if spring_arm != null:
				spring_arm.spring_length = clampf(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if spring_arm != null:
				spring_arm.spring_length = clampf(spring_arm.spring_length + zoom_step, min_zoom, max_zoom)

	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_release_mouse()

	elif event is InputEventMouseMotion and is_mouse_captured:
		cam_yaw -= event.relative.x * mouse_sensitivity
		cam_pitch = clampf(cam_pitch - (event.relative.y * mouse_sensitivity), -deg_to_rad(75.0), deg_to_rad(65.0))
		_update_camera_rotation()


func _update_camera_rotation() -> void:
	if camera_pivot != null and spring_arm != null:
		camera_pivot.rotation.y = cam_yaw
		spring_arm.rotation.x = cam_pitch


## Clic Gauche : Attaque de base
func _perform_basic_attack() -> void:
	if basic_attack_cooldown > 0.0:
		return

	basic_attack_cooldown = 0.35

	# Animation du bras droit
	if character_model != null and character_model.right_arm_pivot != null:
		character_model.right_arm_pivot.rotation.x = -deg_to_rad(85.0)

	# Détection des ennemis face au joueur
	var cam_forward := -Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()
	var attack_range: float = 2.6
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if is_instance_valid(enemy):
			var to_enemy: Vector3 = enemy.global_position - global_position
			var dist: float = to_enemy.length()

			if dist <= attack_range:
				var dir_to_enemy := to_enemy.normalized()
				if cam_forward.dot(dir_to_enemy) > 0.1:
					if enemy.has_method("take_damage"):
						enemy.take_damage(22.0, global_position)


## Clic Droit : Compétence onde de choc circulaire (Whirlwind)
func _perform_skill_attack() -> void:
	if skill_attack_cooldown > 0.0 or current_stamina < skill_stamina_cost:
		return

	current_stamina -= skill_stamina_cost
	skill_attack_cooldown = 0.75

	# Déclenchement d'une onde de choc sur 360 degrés
	var skill_range: float = 4.2
	var enemies := get_tree().get_nodes_in_group("enemies")

	# Particules d'onde de choc
	DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), Color(0.2, 0.8, 0.95))

	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= skill_range:
				if enemy.has_method("take_damage"):
					enemy.take_damage(45.0, global_position)


func _physics_process(delta: float) -> void:
	# Timers de combat
	basic_attack_cooldown = maxf(basic_attack_cooldown - delta, 0.0)
	skill_attack_cooldown = maxf(skill_attack_cooldown - delta, 0.0)

	# Gestion de l'invincibilité
	if invincibility_timer > 0.0:
		invincibility_timer = maxf(invincibility_timer - delta, 0.0)
		# Effet de clignotement visuel
		if character_model != null:
			character_model.visible = (int(invincibility_timer * 20.0) % 2 == 0)
	else:
		if character_model != null:
			character_model.visible = true

	# 1. Eau & nage
	var water_surface_y: float = float(Chunk.SEA_LEVEL) + 0.5
	is_swimming = (global_position.y <= water_surface_y)

	if is_swimming or is_on_floor():
		is_gliding = false

	# 2. Planeur
	if not is_on_floor() and not is_swimming:
		if Input.is_action_just_pressed("jump"):
			is_gliding = not is_gliding

	# 3. Gravité & poussée
	if is_swimming:
		if Input.is_action_pressed("jump"):
			velocity.y = swim_speed
		elif Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C):
			velocity.y = -swim_speed
		else:
			velocity.y = lerp(velocity.y, 1.0, delta * 3.0)

	elif is_gliding:
		velocity.y = lerp(velocity.y, glide_fall_speed, delta * 8.0)

	elif not is_on_floor():
		velocity.y -= gravity * delta

	# 4. Saut
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# 5. Déplacement & Endurance
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var is_sprinting: bool = Input.is_action_pressed("sprint") and is_on_floor() and input_dir != Vector2.ZERO and current_stamina > 2.0

	if is_sprinting:
		current_stamina = maxf(current_stamina - (sprint_stamina_cost * delta), 0.0)
	else:
		current_stamina = minf(current_stamina + (stamina_regen * delta), max_stamina)

	var target_speed: float = walk_speed
	if is_swimming:
		target_speed = swim_speed
	elif is_gliding:
		target_speed = sprint_speed * 1.15
	elif is_sprinting:
		target_speed = sprint_speed

	var cam_forward := -Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()
	var cam_right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw)).normalized()
	var move_direction := (cam_forward * -input_dir.y) + (cam_right * input_dir.x)

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * target_speed
		velocity.z = move_direction.z * target_speed

		var target_angle: float = atan2(-move_direction.x, -move_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_angle, delta * 12.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * delta * 8.0)

	move_and_slide()

	# 6. Mise à jour de l'animation
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if character_model != null:
		character_model.update_animation(horizontal_speed, delta, is_on_floor(), is_gliding, is_swimming)

	# 7. Mise à jour du HUD
	if hud != null:
		hud.update_health(current_health, max_health)
		hud.update_stamina(current_stamina, max_stamina)


## Réception des dégâts avec invincibilité temporaire
func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if invincibility_timer > 0.0 or current_health <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	invincibility_timer = invincibility_duration

	if hud != null:
		hud.trigger_damage_flash()

	# Léger recul en arrière
	if from_position != Vector3.ZERO:
		var knock_dir := (global_position - from_position).normalized()
		knock_dir.y = 0.15
		velocity += knock_dir * 6.0

	if current_health <= 0.0:
		_respawn_player()


func _respawn_player() -> void:
	current_health = max_health
	current_stamina = max_stamina
	velocity = Vector3.ZERO
	global_position.y += 20.0 # Réapparition en hauteur avec planeur utilisable
	invincibility_timer = 1.0


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_mouse_captured = false
