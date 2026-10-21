class_name GolemEnemy
extends "res://scripts/enemies/enemy_base.gd"

## Ennemi golem de pierre massif voxel (montagnes, déserts rocheux) avec yeux runiques luisants.

var arm_l: Node3D = null
var arm_r: Node3D = null
var leg_l: Node3D = null
var leg_r: Node3D = null
var anim_phase: float = 0.0


func _init() -> void:
	max_health = 130.0
	move_speed = 2.4
	chase_speed = 3.6
	attack_damage = 25.0
	attack_range = 2.4
	attack_cooldown = 1.8
	detection_range = 16.0
	enemy_name = "Golem Ancien"
	death_color = Color(0.45, 0.45, 0.48)


func _ready() -> void:
	super._ready()
	_build_golem_model()


func _get_height_offset() -> float:
	return 2.5


func _create_stone_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var fresnel_shader = load("res://shaders/fresnel_character.gdshader")
	if fresnel_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = fresnel_shader
		sm.set_shader_parameter("albedo_color", color)
		sm.set_shader_parameter("fresnel_color", Color(0.2, 0.85, 0.95, 1.0)) # Reflet cyan runique
		sm.set_shader_parameter("fresnel_intensity", 0.32)
		sm.set_shader_parameter("roughness", 0.92)
		box.material = sm
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		box.material = mat
	inst.mesh = box
	return inst


func _build_golem_model() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.2, 1.0)
	col.shape = box
	col.position = Vector3(0.0, 1.1, 0.0)
	add_child(col)

	var model := Node3D.new()
	model.name = "Model"
	add_child(model)

	var stone_color := Color(0.48, 0.48, 0.52)
	var dark_stone := Color(0.35, 0.35, 0.38)
	var glow_cyan := Color(0.2, 0.85, 0.95)

	# Torse massif
	var torso := _create_stone_cube(Vector3(1.0, 0.95, 0.65), stone_color)
	torso.position = Vector3(0.0, 1.4, 0.0)
	model.add_child(torso)

	# Tête robuste encastrée
	var head := _create_stone_cube(Vector3(0.55, 0.45, 0.5), dark_stone)
	head.position = Vector3(0.0, 1.95, -0.1)
	model.add_child(head)

	# Yeux runiques luisants
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = glow_cyan
	eye_mat.emission_enabled = true
	eye_mat.emission = glow_cyan
	eye_mat.emission_energy_multiplier = 2.0

	var eye_l := MeshInstance3D.new()
	var eye_box := BoxMesh.new()
	eye_box.size = Vector3(0.12, 0.08, 0.05)
	eye_box.material = eye_mat
	eye_l.mesh = eye_box
	eye_l.position = Vector3(-0.15, 1.95, -0.36)
	model.add_child(eye_l)

	var eye_r := MeshInstance3D.new()
	eye_r.mesh = eye_box
	eye_r.position = Vector3(0.15, 1.95, -0.36)
	model.add_child(eye_r)

	# Bras de pierre imposants
	arm_l = _create_golem_arm(stone_color, Vector3(-0.7, 1.7, 0.0), model)
	arm_r = _create_golem_arm(stone_color, Vector3(0.7, 1.7, 0.0), model)

	# Jambes épaisses
	leg_l = _create_golem_leg(dark_stone, Vector3(-0.3, 0.8, 0.0), model)
	leg_r = _create_golem_leg(dark_stone, Vector3(0.3, 0.8, 0.0), model)


func _create_golem_arm(color: Color, pivot_pos: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)

	var arm := _create_stone_cube(Vector3(0.36, 0.95, 0.36), color)
	arm.position = Vector3(0.0, -0.45, 0.0)
	pivot.add_child(arm)
	return pivot


func _create_golem_leg(color: Color, pivot_pos: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)

	var leg := _create_stone_cube(Vector3(0.38, 0.8, 0.38), color)
	leg.position = Vector3(0.0, -0.4, 0.0)
	pivot.add_child(leg)
	return pivot


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed > 0.2 and is_on_floor():
		anim_phase += speed * delta * 2.0
		var s: float = sin(anim_phase) * 0.5
		leg_l.rotation.x = s
		leg_r.rotation.x = -s
		arm_l.rotation.x = -s * 0.7
		arm_r.rotation.x = s * 0.7
	else:
		leg_l.rotation.x = lerp_angle(leg_l.rotation.x, 0.0, delta * 8.0)
		leg_r.rotation.x = lerp_angle(leg_r.rotation.x, 0.0, delta * 8.0)
		arm_l.rotation.x = lerp_angle(arm_l.rotation.x, 0.0, delta * 8.0)
		arm_r.rotation.x = lerp_angle(arm_r.rotation.x, 0.0, delta * 8.0)
