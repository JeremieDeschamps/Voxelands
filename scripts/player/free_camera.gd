class_name FreeCamera
extends Camera3D

## Caméra libre de test (WASD + souris + élévation) avec capture du curseur.

@export var move_speed: float = 20.0
@export var fast_speed_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003

var yaw: float = 0.0
var pitch: float = 0.0
var is_mouse_captured: bool = false


func _ready() -> void:
	# Capture du curseur pour une navigation fluide
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_capture_mouse()

	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_release_mouse()

	elif event is InputEventMouseMotion and is_mouse_captured:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - (event.relative.y * mouse_sensitivity), -deg_to_rad(89.0), deg_to_rad(89.0))
		rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	var move_direction := Vector3.ZERO

	# Déplacements clavier relatifs à l'orientation de la caméra
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_Z):
		move_direction -= transform.basis.z
	if Input.is_physical_key_pressed(KEY_S):
		move_direction += transform.basis.z
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q):
		move_direction -= transform.basis.x
	if Input.is_physical_key_pressed(KEY_D):
		move_direction += transform.basis.x
	if Input.is_physical_key_pressed(KEY_SPACE):
		move_direction += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C):
		move_direction += Vector3.DOWN

	if move_direction != Vector3.ZERO:
		move_direction = move_direction.normalized()

		var speed: float = move_speed
		if Input.is_physical_key_pressed(KEY_SHIFT):
			speed *= fast_speed_multiplier

		global_position += move_direction * speed * delta


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_mouse_captured = false
