class_name Player
extends CharacterBody3D

## Contrôleur de joueur voxel avec caméra orbitale, saut, sprint, nage et planeur.

const VoxelCharacter = preload("res://scripts/player/voxel_character.gd")
const Chunk = preload("res://scripts/world/chunk.gd")

@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var swim_speed: float = 4.5
@export var jump_velocity: float = 8.0
@export var glide_fall_speed: float = -2.2
@export var mouse_sensitivity: float = 0.003

@export var min_zoom: float = 1.8
@export var max_zoom: float = 9.0
@export var zoom_step: float = 0.6

# Références aux sous-noeuds
var character_model: VoxelCharacter = null
var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null

# États du joueur
var is_gliding: bool = false
var is_swimming: bool = false
var is_mouse_captured: bool = false

# Orientation de la caméra
var cam_yaw: float = 0.0
var cam_pitch: float = -0.2

var gravity: float = 19.6


func _ready() -> void:
	_setup_inputs_if_missing()
	_build_player_components()
	_capture_mouse()


## Enregistre les actions d'entrée si non configurées
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


## Assemble la capsule de collision, le modèle voxel et la caméra troisième personne
func _build_player_components() -> void:
	# 1. Collision Capsule
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	col_shape.shape = capsule
	col_shape.position = Vector3(0.0, 0.88, 0.0)
	add_child(col_shape)

	# 2. Modèle voxel articulé
	character_model = VoxelCharacter.new()
	character_model.name = "CharacterModel"
	add_child(character_model)

	# 3. Pivot et bras de ressort pour la caméra orbitale
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_capture_mouse()

		# Zoom caméra à la molette
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


func _physics_process(delta: float) -> void:
	# 1. Détection de l'eau (niveau de la mer)
	var water_surface_y: float = float(Chunk.SEA_LEVEL) + 0.5
	var was_swimming: bool = is_swimming
	is_swimming = (global_position.y <= water_surface_y)

	if is_swimming or is_on_floor():
		is_gliding = false

	# 2. Gestion du planeur (Espace en l'air)
	if not is_on_floor() and not is_swimming:
		if Input.is_action_just_pressed("jump"):
			# Déploiement / repli du planeur
			is_gliding = not is_gliding

	# 3. Application de la gravité et poussée verticale
	if is_swimming:
		# Flottabilité et nage
		if Input.is_action_pressed("jump"):
			velocity.y = swim_speed
		elif Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C):
			velocity.y = -swim_speed
		else:
			# Légère flottabilité vers la surface
			velocity.y = lerp(velocity.y, 1.0, delta * 3.0)

	elif is_gliding:
		# Chute ralentie et planante
		velocity.y = lerp(velocity.y, glide_fall_speed, delta * 8.0)

	elif not is_on_floor():
		velocity.y -= gravity * delta

	# 4. Saut au sol
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# 5. Calcul de la direction de déplacement relatif à la caméra
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

	var cam_forward := -Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()
	var cam_right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw)).normalized()
	var move_direction := (cam_forward * -input_dir.y) + (cam_right * input_dir.x)

	# Vitesse horizontale selon sprint, nage ou planeur
	var target_speed: float = walk_speed
	if is_swimming:
		target_speed = swim_speed
	elif is_gliding:
		target_speed = sprint_speed * 1.15
	elif Input.is_action_pressed("sprint") and is_on_floor():
		target_speed = sprint_speed

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * target_speed
		velocity.z = move_direction.z * target_speed

		# Orientation douce du modèle vers la direction de marche
		var target_angle: float = atan2(-move_direction.x, -move_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_angle, delta * 12.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * delta * 8.0)

	# 6. Déplacement physique avec collisions du terrain
	move_and_slide()

	# 7. Animation des membres du modèle voxel
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if character_model != null:
		character_model.update_animation(horizontal_speed, delta, is_on_floor(), is_gliding, is_swimming)


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_mouse_captured = false
