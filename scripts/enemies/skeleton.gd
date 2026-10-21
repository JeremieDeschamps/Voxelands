class_name SkeletonEnemy
extends "res://scripts/enemies/enemy_base.gd"

## Ennemi squelette bipède voxel (déserts, plaines nocturnes, ruines).

var arm_l_pivot: Node3D = null
var arm_r_pivot: Node3D = null
var leg_l_pivot: Node3D = null
var leg_r_pivot: Node3D = null
var anim_phase: float = 0.0


func _init() -> void:
	max_health = 50.0
	move_speed = 3.8
	chase_speed = 5.2
	attack_damage = 14.0
	attack_range = 1.9
	attack_cooldown = 1.3
	detection_range = 18.0
	enemy_name = "Squelette Guerrier"
	death_color = Color(0.88, 0.88, 0.82)


func _ready() -> void:
	super._ready()
	_build_skeleton_model()


func _get_height_offset() -> float:
	return 1.8


func _create_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var fresnel_shader = load("res://shaders/fresnel_character.gdshader")
	if fresnel_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = fresnel_shader
		sm.set_shader_parameter("albedo_color", color)
		sm.set_shader_parameter("fresnel_color", Color(0.9, 0.4, 0.4, 1.0))
		sm.set_shader_parameter("fresnel_intensity", 0.25)
		sm.set_shader_parameter("roughness", 0.85)
		box.material = sm
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		box.material = mat
	inst.mesh = box
	return inst


func _build_skeleton_model() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	col.shape = capsule
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	var model := Node3D.new()
	model.name = "Model"
	add_child(model)

	var bone_color := Color(0.88, 0.88, 0.82)
	var dark_color := Color(0.12, 0.12, 0.14)

	# Crâne
	var skull := _create_cube(Vector3(0.36, 0.36, 0.36), bone_color)
	skull.position = Vector3(0.0, 1.35, 0.0)
	model.add_child(skull)

	# Cavités oculaires
	var eye_l := _create_cube(Vector3(0.07, 0.07, 0.05), dark_color)
	eye_l.position = Vector3(-0.09, 1.36, -0.18)
	model.add_child(eye_l)

	var eye_r := _create_cube(Vector3(0.07, 0.07, 0.05), dark_color)
	eye_r.position = Vector3(0.09, 1.36, -0.18)
	model.add_child(eye_r)

	# Colonne & Cage thoracique
	var ribcage := _create_cube(Vector3(0.42, 0.48, 0.22), bone_color)
	ribcage.position = Vector3(0.0, 0.86, 0.0)
	model.add_child(ribcage)

	# Bras gauche
	arm_l_pivot = Node3D.new()
	arm_l_pivot.position = Vector3(-0.3, 1.05, 0.0)
	model.add_child(arm_l_pivot)
	var arm_l := _create_cube(Vector3(0.1, 0.55, 0.1), bone_color)
	arm_l.position = Vector3(0.0, -0.25, 0.0)
	arm_l_pivot.add_child(arm_l)

	# Bras droit avec épée d'os
	arm_r_pivot = Node3D.new()
	arm_r_pivot.position = Vector3(0.3, 1.05, 0.0)
	model.add_child(arm_r_pivot)
	var arm_r := _create_cube(Vector3(0.1, 0.55, 0.1), bone_color)
	arm_r.position = Vector3(0.0, -0.25, 0.0)
	arm_r_pivot.add_child(arm_r)

	var sword := _create_cube(Vector3(0.08, 0.75, 0.12), Color(0.65, 0.65, 0.68))
	sword.position = Vector3(0.0, -0.5, -0.25)
	sword.rotation.x = deg_to_rad(45.0)
	arm_r_pivot.add_child(sword)

	# Jambes d'os
	leg_l_pivot = Node3D.new()
	leg_l_pivot.position = Vector3(-0.14, 0.55, 0.0)
	model.add_child(leg_l_pivot)
	var leg_l := _create_cube(Vector3(0.1, 0.55, 0.1), bone_color)
	leg_l.position = Vector3(0.0, -0.25, 0.0)
	leg_l_pivot.add_child(leg_l)

	leg_r_pivot = Node3D.new()
	leg_r_pivot.position = Vector3(0.14, 0.55, 0.0)
	model.add_child(leg_r_pivot)
	var leg_r := _create_cube(Vector3(0.1, 0.55, 0.1), bone_color)
	leg_r.position = Vector3(0.0, -0.25, 0.0)
	leg_r_pivot.add_child(leg_r)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed > 0.2 and is_on_floor():
		anim_phase += speed * delta * 2.4
		var s: float = sin(anim_phase) * 0.7
		leg_l_pivot.rotation.x = s
		leg_r_pivot.rotation.x = -s
		arm_l_pivot.rotation.x = -s
		arm_r_pivot.rotation.x = s * 0.5
	else:
		leg_l_pivot.rotation.x = lerp_angle(leg_l_pivot.rotation.x, 0.0, delta * 10.0)
		leg_r_pivot.rotation.x = lerp_angle(leg_r_pivot.rotation.x, 0.0, delta * 10.0)
		arm_l_pivot.rotation.x = lerp_angle(arm_l_pivot.rotation.x, 0.0, delta * 10.0)
		arm_r_pivot.rotation.x = lerp_angle(arm_r_pivot.rotation.x, 0.0, delta * 10.0)
