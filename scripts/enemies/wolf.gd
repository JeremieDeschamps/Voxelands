class_name WolfEnemy
extends "res://scripts/enemies/enemy_base.gd"

## Ennemi loup quadrupède voxel (plaines, forêts, toundra) avec animation de course.

var leg_fl: Node3D = null
var leg_fr: Node3D = null
var leg_bl: Node3D = null
var leg_br: Node3D = null
var tail: Node3D = null
var anim_phase: float = 0.0


func _init() -> void:
	max_health = 40.0
	move_speed = 4.5
	chase_speed = 7.5
	attack_damage = 10.0
	attack_range = 1.6
	attack_cooldown = 1.0
	detection_range = 16.0
	enemy_name = "Loup Sauvage"
	death_color = Color(0.52, 0.52, 0.55)


func _ready() -> void:
	super._ready()
	_build_wolf_model()


func _get_height_offset() -> float:
	return 1.1


func _create_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var fresnel_shader = load("res://shaders/fresnel_character.gdshader")
	if fresnel_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = fresnel_shader
		sm.set_shader_parameter("albedo_color", color)
		sm.set_shader_parameter("fresnel_color", Color(1.0, 0.4, 0.4, 1.0))
		sm.set_shader_parameter("fresnel_intensity", 0.28)
		sm.set_shader_parameter("roughness", 0.85)
		box.material = sm
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		box.material = mat
	inst.mesh = box
	return inst


func _build_wolf_model() -> void:
	# Collision capsule horizontale / box
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.6, 0.8, 1.2)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.4, 0.0)
	add_child(col)

	var model := Node3D.new()
	model.name = "Model"
	add_child(model)

	var fur_color := Color(0.52, 0.52, 0.55)
	var muzzle_color := Color(0.38, 0.38, 0.40)
	var eye_color := Color(0.95, 0.15, 0.15)

	# Corps
	var body := _create_cube(Vector3(0.48, 0.45, 0.85), fur_color)
	body.position = Vector3(0.0, 0.48, 0.0)
	model.add_child(body)

	# Tête
	var head := _create_cube(Vector3(0.36, 0.36, 0.38), fur_color)
	head.position = Vector3(0.0, 0.65, -0.48)
	model.add_child(head)

	# Museau
	var muzzle := _create_cube(Vector3(0.22, 0.18, 0.28), muzzle_color)
	muzzle.position = Vector3(0.0, 0.58, -0.72)
	model.add_child(muzzle)

	# Yeux rouges
	var eye_l := _create_cube(Vector3(0.05, 0.05, 0.04), eye_color)
	eye_l.position = Vector3(-0.1, 0.72, -0.65)
	model.add_child(eye_l)

	var eye_r := _create_cube(Vector3(0.05, 0.05, 0.04), eye_color)
	eye_r.position = Vector3(0.1, 0.72, -0.65)
	model.add_child(eye_r)

	# Oreilles pointues
	var ear_l := _create_cube(Vector3(0.08, 0.14, 0.06), fur_color)
	ear_l.position = Vector3(-0.12, 0.88, -0.42)
	model.add_child(ear_l)

	var ear_r := _create_cube(Vector3(0.08, 0.14, 0.06), fur_color)
	ear_r.position = Vector3(0.12, 0.88, -0.42)
	model.add_child(ear_r)

	# 4 Pattes avec pivots
	leg_fl = _create_leg(fur_color, Vector3(-0.18, 0.35, -0.28), model)
	leg_fr = _create_leg(fur_color, Vector3(0.18, 0.35, -0.28), model)
	leg_bl = _create_leg(fur_color, Vector3(-0.18, 0.35, 0.28), model)
	leg_br = _create_leg(fur_color, Vector3(0.18, 0.35, 0.28), model)

	# Queue
	tail = Node3D.new()
	tail.position = Vector3(0.0, 0.6, 0.42)
	model.add_child(tail)
	var tail_mesh := _create_cube(Vector3(0.12, 0.12, 0.38), fur_color)
	tail_mesh.position = Vector3(0.0, -0.1, 0.18)
	tail_mesh.rotation.x = deg_to_rad(-30.0)
	tail.add_child(tail_mesh)


func _create_leg(color: Color, pivot_pos: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)

	var leg_cube := _create_cube(Vector3(0.14, 0.38, 0.14), color)
	leg_cube.position = Vector3(0.0, -0.18, 0.0)
	pivot.add_child(leg_cube)
	return pivot


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed > 0.2 and is_on_floor():
		anim_phase += speed * delta * 2.8
		var s: float = sin(anim_phase) * 0.65

		leg_fl.rotation.x = s
		leg_br.rotation.x = s
		leg_fr.rotation.x = -s
		leg_bl.rotation.x = -s

		if tail != null:
			tail.rotation.y = sin(anim_phase * 1.5) * 0.35
	else:
		leg_fl.rotation.x = lerp_angle(leg_fl.rotation.x, 0.0, delta * 10.0)
		leg_fr.rotation.x = lerp_angle(leg_fr.rotation.x, 0.0, delta * 10.0)
		leg_bl.rotation.x = lerp_angle(leg_bl.rotation.x, 0.0, delta * 10.0)
		leg_br.rotation.x = lerp_angle(leg_br.rotation.x, 0.0, delta * 10.0)
