class_name VoxelCharacter
extends Node3D

## Modèle procédural de personnage voxel articulé (tête, corps, bras, jambes, planeur) avec animations en code.

# Noeuds d'articulation
var visuals_node: Node3D = null
var torso: MeshInstance3D = null
var head: Node3D = null
var left_arm_pivot: Node3D = null
var right_arm_pivot: Node3D = null
var left_leg_pivot: Node3D = null
var right_leg_pivot: Node3D = null
var glider_node: Node3D = null

# Couleurs du personnage
const COLOR_SKIN := Color(0.96, 0.78, 0.65)
const COLOR_HAIR := Color(0.32, 0.20, 0.12)
const COLOR_EYES := Color(0.15, 0.15, 0.20)
const COLOR_TUNIC := Color(0.20, 0.45, 0.82)
const COLOR_PANTS := Color(0.25, 0.22, 0.18)
const COLOR_BOOTS := Color(0.18, 0.14, 0.10)
const COLOR_GLIDER_FABRIC := Color(0.92, 0.28, 0.18)
const COLOR_GLIDER_STRUT := Color(0.22, 0.22, 0.25)

var walk_phase: float = 0.0


func _ready() -> void:
	_build_character_mesh()


## Crée un cube simple avec matériau de couleur uniforme
func _create_voxel_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	box.material = mat

	mesh_inst.mesh = box
	return mesh_inst


## Construction hiérarchique du modèle voxel en code
func _build_character_mesh() -> void:
	visuals_node = Node3D.new()
	visuals_node.name = "Visuals"
	add_child(visuals_node)

	# 1. Torse (Tunique d'aventurier bleue)
	torso = _create_voxel_cube(Vector3(0.5, 0.6, 0.3), COLOR_TUNIC)
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.75, 0.0)
	visuals_node.add_child(torso)
	# 2. Tête articulée
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.25, 0.0)
	visuals_node.add_child(head)

	# Visage
	var face_cube := _create_voxel_cube(Vector3(0.4, 0.4, 0.4), COLOR_SKIN)
	head.add_child(face_cube)

	# Cheveux
	var hair_cube := _create_voxel_cube(Vector3(0.42, 0.18, 0.42), COLOR_HAIR)
	hair_cube.position = Vector3(0.0, 0.15, 0.0)
	head.add_child(hair_cube)

	# Yeux (gauche et droit)
	var left_eye := _create_voxel_cube(Vector3(0.06, 0.06, 0.04), COLOR_EYES)
	left_eye.position = Vector3(-0.1, 0.02, -0.2)
	head.add_child(left_eye)

	var right_eye := _create_voxel_cube(Vector3(0.06, 0.06, 0.04), COLOR_EYES)
	right_eye.position = Vector3(0.1, 0.02, -0.2)
	head.add_child(right_eye)

	# 3. Bras gauche
	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	left_arm_pivot.position = Vector3(-0.35, 0.95, 0.0)
	visuals_node.add_child(left_arm_pivot)

	var left_arm := _create_voxel_cube(Vector3(0.2, 0.6, 0.2), COLOR_SKIN)
	left_arm.position = Vector3(0.0, -0.25, 0.0)
	left_arm_pivot.add_child(left_arm)

	# Manchette de tunique
	var left_sleeve := _create_voxel_cube(Vector3(0.22, 0.2, 0.22), COLOR_TUNIC)
	left_sleeve.position = Vector3(0.0, -0.05, 0.0)
	left_arm_pivot.add_child(left_sleeve)

	# 4. Bras droit
	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	right_arm_pivot.position = Vector3(0.35, 0.95, 0.0)
	visuals_node.add_child(right_arm_pivot)

	var right_arm := _create_voxel_cube(Vector3(0.2, 0.6, 0.2), COLOR_SKIN)
	right_arm.position = Vector3(0.0, -0.25, 0.0)
	right_arm_pivot.add_child(right_arm)

	var right_sleeve := _create_voxel_cube(Vector3(0.22, 0.2, 0.22), COLOR_TUNIC)
	right_sleeve.position = Vector3(0.0, -0.05, 0.0)
	right_arm_pivot.add_child(right_sleeve)

	# 5. Jambe gauche
	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(-0.14, 0.45, 0.0)
	visuals_node.add_child(left_leg_pivot)

	var left_leg := _create_voxel_cube(Vector3(0.2, 0.45, 0.2), COLOR_PANTS)
	left_leg.position = Vector3(0.0, -0.22, 0.0)
	left_leg_pivot.add_child(left_leg)

	var left_boot := _create_voxel_cube(Vector3(0.21, 0.15, 0.24), COLOR_BOOTS)
	left_boot.position = Vector3(0.0, -0.38, -0.02)
	left_leg_pivot.add_child(left_boot)

	# 6. Jambe droite
	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(0.14, 0.45, 0.0)
	visuals_node.add_child(right_leg_pivot)

	var right_leg := _create_voxel_cube(Vector3(0.2, 0.45, 0.2), COLOR_PANTS)
	right_leg.position = Vector3(0.0, -0.22, 0.0)
	right_leg_pivot.add_child(right_leg)

	var right_boot := _create_voxel_cube(Vector3(0.21, 0.15, 0.24), COLOR_BOOTS)
	right_boot.position = Vector3(0.0, -0.38, -0.02)
	right_leg_pivot.add_child(right_boot)

	# 7. Planeur / Parapente
	_build_glider()


## Construit l'armature et la voilure du planeur
func _build_glider() -> void:
	glider_node = Node3D.new()
	glider_node.name = "Glider"
	glider_node.position = Vector3(0.0, 1.2, 0.1)
	glider_node.visible = false
	visuals_node.add_child(glider_node)

	# Voilure centrale
	var main_wing := _create_voxel_cube(Vector3(2.4, 0.05, 1.1), COLOR_GLIDER_FABRIC)
	main_wing.position = Vector3(0.0, 0.4, 0.0)
	glider_node.add_child(main_wing)

	# Bouts d'ailes inclinés
	var left_winglet := _create_voxel_cube(Vector3(0.4, 0.05, 0.9), COLOR_GLIDER_FABRIC)
	left_winglet.position = Vector3(-1.3, 0.5, 0.0)
	left_winglet.rotation.z = deg_to_rad(15.0)
	glider_node.add_child(left_winglet)

	var right_winglet := _create_voxel_cube(Vector3(0.4, 0.05, 0.9), COLOR_GLIDER_FABRIC)
	right_winglet.position = Vector3(1.3, 0.5, 0.0)
	right_winglet.rotation.z = deg_to_rad(-15.0)
	glider_node.add_child(right_winglet)

	# Barres de maintien / suspentes
	var left_strut := _create_voxel_cube(Vector3(0.05, 0.5, 0.05), COLOR_GLIDER_STRUT)
	left_strut.position = Vector3(-0.35, 0.15, -0.05)
	glider_node.add_child(left_strut)

	var right_strut := _create_voxel_cube(Vector3(0.05, 0.5, 0.05), COLOR_GLIDER_STRUT)
	right_strut.position = Vector3(0.35, 0.15, -0.05)
	glider_node.add_child(right_strut)

	# Barre transversale tenue par les mains
	var handle_bar := _create_voxel_cube(Vector3(0.8, 0.04, 0.04), COLOR_GLIDER_STRUT)
	handle_bar.position = Vector3(0.0, -0.08, -0.05)
	glider_node.add_child(handle_bar)


## Anime les membres selon l'état et la vitesse
func update_animation(horizontal_speed: float, delta: float, is_on_floor: bool, is_gliding: bool, is_swimming: bool) -> void:
	if glider_node != null:
		glider_node.visible = is_gliding

	if is_gliding:
		# Posture de vol : bras levés sur la barre, jambes en arrière
		left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, -deg_to_rad(140.0), delta * 12.0)
		right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, -deg_to_rad(140.0), delta * 12.0)
		left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, deg_to_rad(25.0), delta * 12.0)
		right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, deg_to_rad(25.0), delta * 12.0)
		visuals_node.rotation.x = lerp_angle(visuals_node.rotation.x, deg_to_rad(20.0), delta * 10.0)

	elif is_swimming:
		# Animation de brasse aquatique
		walk_phase += delta * 6.0
		var stroke: float = sin(walk_phase)
		left_arm_pivot.rotation.x = stroke * 0.8
		right_arm_pivot.rotation.x = stroke * 0.8
		left_leg_pivot.rotation.x = -stroke * 0.5
		right_leg_pivot.rotation.x = stroke * 0.5
		visuals_node.rotation.x = lerp_angle(visuals_node.rotation.x, deg_to_rad(35.0), delta * 8.0)

	elif is_on_floor and horizontal_speed > 0.1:
		# Animation de marche / course synchronisée
		walk_phase += horizontal_speed * delta * 2.2
		var swing: float = sin(walk_phase) * 0.75

		left_leg_pivot.rotation.x = swing
		right_leg_pivot.rotation.x = -swing
		left_arm_pivot.rotation.x = -swing
		right_arm_pivot.rotation.x = swing

		torso.position.y = 0.75 + (absf(sin(walk_phase * 2.0)) * 0.04)
		head.position.y = 1.25 + (absf(sin(walk_phase * 2.0)) * 0.04)
		visuals_node.rotation.x = lerp_angle(visuals_node.rotation.x, 0.0, delta * 15.0)

	else:
		# Retour au repos (Idle)
		walk_phase = 0.0
		left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, 0.0, delta * 12.0)
		right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, 0.0, delta * 12.0)
		left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, 0.0, delta * 12.0)
		right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, 0.0, delta * 12.0)
		torso.position.y = lerp(torso.position.y, 0.75, delta * 10.0)
		head.position.y = lerp(head.position.y, 1.25, delta * 10.0)
		visuals_node.rotation.x = lerp_angle(visuals_node.rotation.x, 0.0, delta * 15.0)


## Modifie la couleur de la tunique selon la classe du joueur
func set_tunic_color(col: Color) -> void:
	if torso != null and torso.mesh != null and torso.mesh.material != null:
		var mat: StandardMaterial3D = torso.mesh.material
		mat.albedo_color = col

