class_name VoxelCharacter
extends Node3D

## Modèle procédural de personnage voxel haute fidélité (style Cube World)
## avec tête détaillée (yeux, mèches), torse, ceinture, cape, bras articulés avec gants,
## jambes avec bottes et planeur articulé.

# Noeuds d'articulation
var visuals_node: Node3D = null
var torso: Node3D = null
var head: Node3D = null
var left_arm_pivot: Node3D = null
var right_arm_pivot: Node3D = null
var left_leg_pivot: Node3D = null
var right_leg_pivot: Node3D = null
var cape_pivot: Node3D = null
var glider_node: Node3D = null

# Matériau de la tunique (pour changement de couleur de classe)
var tunic_mesh: MeshInstance3D = null

# Couleurs par défaut
const COLOR_SKIN := Color(0.96, 0.78, 0.65)
const COLOR_HAIR := Color(0.32, 0.20, 0.12)
const COLOR_HAIR_HIGHLIGHT := Color(0.45, 0.30, 0.18)
const COLOR_EYE_PUPIL := Color(0.12, 0.15, 0.22)
const COLOR_EYE_WHITE := Color(0.98, 0.98, 1.0)
const COLOR_TUNIC := Color(0.20, 0.45, 0.82)
const COLOR_BELT := Color(0.18, 0.14, 0.10)
const COLOR_BUCKLE := Color(0.92, 0.78, 0.25)
const COLOR_CAPE := Color(0.72, 0.18, 0.18)
const COLOR_PANTS := Color(0.25, 0.22, 0.18)
const COLOR_BOOTS := Color(0.16, 0.12, 0.08)
const COLOR_BOOTS_SOLE := Color(0.10, 0.08, 0.06)
const COLOR_GLIDER_FABRIC := Color(0.92, 0.28, 0.18)
const COLOR_GLIDER_STRUT := Color(0.22, 0.22, 0.25)

var walk_phase: float = 0.0


func _ready() -> void:
	_build_character_mesh()


func _create_voxel_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size

	var fresnel_shader = load("res://shaders/fresnel_character.gdshader")
	if fresnel_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = fresnel_shader
		sm.set_shader_parameter("albedo_color", color)
		sm.set_shader_parameter("fresnel_color", Color(1.0, 1.0, 1.0, 1.0))
		sm.set_shader_parameter("fresnel_intensity", 0.28)
		sm.set_shader_parameter("roughness", 0.85)
		box.material = sm
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		box.material = mat

	mesh_inst.mesh = box
	return mesh_inst


func _build_character_mesh() -> void:
	visuals_node = Node3D.new()
	visuals_node.name = "Visuals"
	add_child(visuals_node)

	# 1. Torse et accessoires
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.75, 0.0)
	visuals_node.add_child(torso)

	# Corps de tunique principal
	tunic_mesh = _create_voxel_cube(Vector3(0.48, 0.52, 0.28), COLOR_TUNIC)
	torso.add_child(tunic_mesh)

	# Col blanc de tunique
	var collar := _create_voxel_cube(Vector3(0.24, 0.08, 0.06), Color(0.95, 0.95, 0.95))
	collar.position = Vector3(0.0, 0.24, -0.13)
	torso.add_child(collar)

	# Ceinture en cuir avec boucle dorée
	var belt := _create_voxel_cube(Vector3(0.50, 0.10, 0.30), COLOR_BELT)
	belt.position = Vector3(0.0, -0.20, 0.0)
	torso.add_child(belt)

	var buckle := _create_voxel_cube(Vector3(0.12, 0.12, 0.04), COLOR_BUCKLE)
	buckle.position = Vector3(0.0, -0.20, -0.15)
	torso.add_child(buckle)

	# Cape d'aventurier à l'arrière
	cape_pivot = Node3D.new()
	cape_pivot.name = "CapePivot"
	cape_pivot.position = Vector3(0.0, 0.24, 0.15)
	torso.add_child(cape_pivot)

	var cape_cloth := _create_voxel_cube(Vector3(0.44, 0.58, 0.04), COLOR_CAPE)
	cape_cloth.position = Vector3(0.0, -0.28, 0.02)
	cape_pivot.add_child(cape_cloth)

	# 2. Tête détaillée (visage, yeux expressifs, cheveux en volume)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.25, 0.0)
	visuals_node.add_child(head)

	# Bloc visage
	var face_cube := _create_voxel_cube(Vector3(0.40, 0.40, 0.38), COLOR_SKIN)
	head.add_child(face_cube)

	# Cheveux en volume (dessus, arrière, mèches avant)
	var hair_top := _create_voxel_cube(Vector3(0.44, 0.14, 0.44), COLOR_HAIR)
	hair_top.position = Vector3(0.0, 0.18, 0.0)
	head.add_child(hair_top)

	var hair_back := _create_voxel_cube(Vector3(0.44, 0.32, 0.10), COLOR_HAIR)
	hair_back.position = Vector3(0.0, 0.02, 0.18)
	head.add_child(hair_back)

	var bangs := _create_voxel_cube(Vector3(0.42, 0.10, 0.06), COLOR_HAIR_HIGHLIGHT)
	bangs.position = Vector3(0.0, 0.16, -0.20)
	head.add_child(bangs)

	# Yeux (blanc + pupille foncée)
	for side in [-1.0, 1.0]:
		var eye_white := _create_voxel_cube(Vector3(0.09, 0.09, 0.03), COLOR_EYE_WHITE)
		eye_white.position = Vector3(side * 0.11, 0.02, -0.19)
		head.add_child(eye_white)

		var eye_pupil := _create_voxel_cube(Vector3(0.05, 0.07, 0.02), COLOR_EYE_PUPIL)
		eye_pupil.position = Vector3(side * 0.11, 0.015, -0.20)
		head.add_child(eye_pupil)

	# 3. Bras gauche (épaule, manche, avant-bras et gant)
	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	left_arm_pivot.position = Vector3(-0.34, 0.96, 0.0)
	visuals_node.add_child(left_arm_pivot)

	var left_sleeve := _create_voxel_cube(Vector3(0.20, 0.22, 0.20), COLOR_TUNIC)
	left_sleeve.position = Vector3(0.0, -0.05, 0.0)
	left_arm_pivot.add_child(left_sleeve)

	var left_arm := _create_voxel_cube(Vector3(0.18, 0.22, 0.18), COLOR_SKIN)
	left_arm.position = Vector3(0.0, -0.22, 0.0)
	left_arm_pivot.add_child(left_arm)

	var left_glove := _create_voxel_cube(Vector3(0.19, 0.14, 0.19), COLOR_BELT)
	left_glove.position = Vector3(0.0, -0.36, 0.0)
	left_arm_pivot.add_child(left_glove)

	# 4. Bras droit
	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	right_arm_pivot.position = Vector3(0.34, 0.96, 0.0)
	visuals_node.add_child(right_arm_pivot)

	var right_sleeve := _create_voxel_cube(Vector3(0.20, 0.22, 0.20), COLOR_TUNIC)
	right_sleeve.position = Vector3(0.0, -0.05, 0.0)
	right_arm_pivot.add_child(right_sleeve)

	var right_arm := _create_voxel_cube(Vector3(0.18, 0.22, 0.18), COLOR_SKIN)
	right_arm.position = Vector3(0.0, -0.22, 0.0)
	right_arm_pivot.add_child(right_arm)

	var right_glove := _create_voxel_cube(Vector3(0.19, 0.14, 0.19), COLOR_BELT)
	right_glove.position = Vector3(0.0, -0.36, 0.0)
	right_arm_pivot.add_child(right_glove)

	# 5. Jambe gauche (pantalon, botte, semelle)
	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(-0.13, 0.46, 0.0)
	visuals_node.add_child(left_leg_pivot)

	var left_pants := _create_voxel_cube(Vector3(0.19, 0.24, 0.19), COLOR_PANTS)
	left_pants.position = Vector3(0.0, -0.12, 0.0)
	left_leg_pivot.add_child(left_pants)

	var left_boot := _create_voxel_cube(Vector3(0.20, 0.20, 0.23), COLOR_BOOTS)
	left_boot.position = Vector3(0.0, -0.30, -0.02)
	left_leg_pivot.add_child(left_boot)

	var left_sole := _create_voxel_cube(Vector3(0.21, 0.05, 0.24), COLOR_BOOTS_SOLE)
	left_sole.position = Vector3(0.0, -0.41, -0.02)
	left_leg_pivot.add_child(left_sole)

	# 6. Jambe droite
	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(0.13, 0.46, 0.0)
	visuals_node.add_child(right_leg_pivot)

	var right_pants := _create_voxel_cube(Vector3(0.19, 0.24, 0.19), COLOR_PANTS)
	right_pants.position = Vector3(0.0, -0.12, 0.0)
	right_leg_pivot.add_child(right_pants)

	var right_boot := _create_voxel_cube(Vector3(0.20, 0.20, 0.23), COLOR_BOOTS)
	right_boot.position = Vector3(0.0, -0.30, -0.02)
	right_leg_pivot.add_child(right_boot)

	var right_sole := _create_voxel_cube(Vector3(0.21, 0.05, 0.24), COLOR_BOOTS_SOLE)
	right_sole.position = Vector3(0.0, -0.41, -0.02)
	right_leg_pivot.add_child(right_sole)

	# 7. Planeur / Parapente
	_build_glider()


func _build_glider() -> void:
	glider_node = Node3D.new()
	glider_node.name = "Glider"
	glider_node.position = Vector3(0.0, 1.25, 0.1)
	glider_node.visible = false
	visuals_node.add_child(glider_node)

	# Voilure centrale aérodynamique
	var main_wing := _create_voxel_cube(Vector3(2.4, 0.06, 1.1), COLOR_GLIDER_FABRIC)
	main_wing.position = Vector3(0.0, 0.42, 0.0)
	glider_node.add_child(main_wing)

	# Nervures de voilure
	for ox in [-0.8, 0.0, 0.8]:
		var rib := _create_voxel_cube(Vector3(0.06, 0.08, 1.14), COLOR_GLIDER_STRUT)
		rib.position = Vector3(ox, 0.43, 0.0)
		glider_node.add_child(rib)

	# Bouts d'ailes inclinés
	var left_winglet := _create_voxel_cube(Vector3(0.42, 0.06, 0.9), COLOR_GLIDER_FABRIC)
	left_winglet.position = Vector3(-1.35, 0.52, 0.0)
	left_winglet.rotation.z = deg_to_rad(16.0)
	glider_node.add_child(left_winglet)

	var right_winglet := _create_voxel_cube(Vector3(0.42, 0.06, 0.9), COLOR_GLIDER_FABRIC)
	right_winglet.position = Vector3(1.35, 0.52, 0.0)
	right_winglet.rotation.z = deg_to_rad(-16.0)
	glider_node.add_child(right_winglet)

	# Haubans et poignée
	var left_strut := _create_voxel_cube(Vector3(0.05, 0.52, 0.05), COLOR_GLIDER_STRUT)
	left_strut.position = Vector3(-0.35, 0.16, -0.05)
	glider_node.add_child(left_strut)

	var right_strut := _create_voxel_cube(Vector3(0.05, 0.52, 0.05), COLOR_GLIDER_STRUT)
	right_strut.position = Vector3(0.35, 0.16, -0.05)
	glider_node.add_child(right_strut)

	var handle_bar := _create_voxel_cube(Vector3(0.8, 0.05, 0.05), COLOR_GLIDER_STRUT)
	handle_bar.position = Vector3(0.0, -0.08, -0.05)
	glider_node.add_child(handle_bar)


func set_tunic_color(color: Color) -> void:
	if tunic_mesh != null and tunic_mesh.mesh != null and tunic_mesh.mesh.material != null:
		if tunic_mesh.mesh.material is ShaderMaterial:
			(tunic_mesh.mesh.material as ShaderMaterial).set_shader_parameter("albedo_color", color)
		elif tunic_mesh.mesh.material is StandardMaterial3D:
			(tunic_mesh.mesh.material as StandardMaterial3D).albedo_color = color


func set_glider_active(active: bool) -> void:
	if glider_node != null:
		glider_node.visible = active


func update_animation(horizontal_speed: float, delta: float, is_grounded: bool, is_gliding: bool, is_swimming: bool) -> void:
	set_glider_active(is_gliding)

	if is_gliding:
		if left_arm_pivot != null:
			left_arm_pivot.rotation.x = deg_to_rad(-135.0)
			left_arm_pivot.rotation.z = deg_to_rad(15.0)
		if right_arm_pivot != null:
			right_arm_pivot.rotation.x = deg_to_rad(-135.0)
			right_arm_pivot.rotation.z = deg_to_rad(-15.0)
		if left_leg_pivot != null:
			left_leg_pivot.rotation.x = deg_to_rad(20.0)
		if right_leg_pivot != null:
			right_leg_pivot.rotation.x = deg_to_rad(20.0)
		if cape_pivot != null:
			cape_pivot.rotation.x = deg_to_rad(65.0)
		return

	if is_swimming:
		walk_phase += delta * 4.0
		var swim_swing: float = sin(walk_phase) * 0.4
		if left_arm_pivot != null: left_arm_pivot.rotation.x = swim_swing
		if right_arm_pivot != null: right_arm_pivot.rotation.x = -swim_swing
		if left_leg_pivot != null: left_leg_pivot.rotation.x = -swim_swing * 0.7
		if right_leg_pivot != null: right_leg_pivot.rotation.x = swim_swing * 0.7
		if cape_pivot != null: cape_pivot.rotation.x = deg_to_rad(45.0) + swim_swing * 0.3
		return

	if not is_grounded:
		if left_arm_pivot != null: left_arm_pivot.rotation.x = deg_to_rad(-30.0)
		if right_arm_pivot != null: right_arm_pivot.rotation.x = deg_to_rad(-30.0)
		if left_leg_pivot != null: left_leg_pivot.rotation.x = deg_to_rad(25.0)
		if right_leg_pivot != null: right_leg_pivot.rotation.x = deg_to_rad(-15.0)
		if cape_pivot != null: cape_pivot.rotation.x = deg_to_rad(30.0)
		return

	if horizontal_speed > 0.3:
		walk_phase += delta * (horizontal_speed * 1.8)
		var swing: float = sin(walk_phase) * 0.65
		if left_arm_pivot != null: left_arm_pivot.rotation.x = swing
		if right_arm_pivot != null: right_arm_pivot.rotation.x = -swing
		if left_leg_pivot != null: left_leg_pivot.rotation.x = -swing
		if right_leg_pivot != null: right_leg_pivot.rotation.x = swing
		if cape_pivot != null: cape_pivot.rotation.x = deg_to_rad(15.0) + absf(swing) * 0.4
	else:
		walk_phase = 0.0
		if left_arm_pivot != null: left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, 0.0, delta * 10.0)
		if right_arm_pivot != null: right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, 0.0, delta * 10.0)
		if left_leg_pivot != null: left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, 0.0, delta * 10.0)
		if right_leg_pivot != null: right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, 0.0, delta * 10.0)
		if cape_pivot != null: cape_pivot.rotation.x = lerp_angle(cape_pivot.rotation.x, deg_to_rad(5.0), delta * 10.0)
