class_name SlimeEnemy
extends "res://scripts/enemies/enemy_base.gd"

## Ennemi slime gélatineux cubique voxel (prairies, forêts, abords aquatiques) avec saut et écrasement.

var body_node: Node3D = null
var hop_timer: float = 0.0


func _init() -> void:
	max_health = 35.0
	move_speed = 3.2
	chase_speed = 5.0
	attack_damage = 8.0
	attack_range = 1.4
	attack_cooldown = 1.0
	detection_range = 15.0
	enemy_name = "Slime Vert"
	death_color = Color(0.25, 0.85, 0.35)


func _ready() -> void:
	super._ready()
	_build_slime_model()


func _get_height_offset() -> float:
	return 0.9


func _build_slime_model() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 0.65, 0.65)
	col.shape = box
	col.position = Vector3(0.0, 0.32, 0.0)
	add_child(col)

	body_node = Node3D.new()
	body_node.name = "Body"
	add_child(body_node)

	# Cube extérieur vert translucide
	var outer_cube := MeshInstance3D.new()
	var outer_box := BoxMesh.new()
	outer_box.size = Vector3(0.65, 0.65, 0.65)
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.25, 0.85, 0.35, 0.85)
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.roughness = 0.3
	outer_box.material = outer_mat
	outer_cube.mesh = outer_box
	outer_cube.position = Vector3(0.0, 0.32, 0.0)
	body_node.add_child(outer_cube)

	# Noyau intérieur sombre
	var core_cube := MeshInstance3D.new()
	var core_box := BoxMesh.new()
	core_box.size = Vector3(0.28, 0.28, 0.28)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.12, 0.48, 0.18)
	core_mat.roughness = 0.6
	core_box.material = core_mat
	core_cube.mesh = core_box
	core_cube.position = Vector3(0.0, 0.28, 0.0)
	body_node.add_child(core_cube)

	# Yeux cubiques
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.1, 0.15, 0.1)

	var eye_l := MeshInstance3D.new()
	var eye_box := BoxMesh.new()
	eye_box.size = Vector3(0.08, 0.08, 0.05)
	eye_box.material = eye_mat
	eye_l.mesh = eye_box
	eye_l.position = Vector3(-0.14, 0.36, -0.34)
	body_node.add_child(eye_l)

	var eye_r := MeshInstance3D.new()
	eye_r.mesh = eye_box
	eye_r.position = Vector3(0.14, 0.36, -0.34)
	body_node.add_child(eye_r)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	hop_timer += delta
	var speed: float = Vector2(velocity.x, velocity.z).length()

	# Animation de sautillement (Squash & Stretch)
	if is_on_floor():
		if speed > 0.2:
			# Saut périodique quand il avance
			if hop_timer >= 0.7:
				velocity.y = 5.5
				hop_timer = 0.0
			body_node.scale = Vector3(1.15, 0.85, 1.15)
		else:
			# Respiration au repos
			var breath: float = sin(hop_timer * 3.0) * 0.06
			body_node.scale = Vector3(1.0 + breath, 1.0 - breath, 1.0 + breath)
	else:
		# Étirement en l'air
		body_node.scale = Vector3(0.85, 1.25, 0.85)
