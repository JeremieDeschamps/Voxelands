class_name VillageNPC
extends CharacterBody3D

## PNJ de village généré procéduralement avec dialogues et quêtes selon le biome.

const BlockTypes = preload("res://scripts/world/block_types.gd")
const QuestSystem = preload("res://scripts/player/quest_system.gd")

@export var npc_name: String = "Ancien du Village"
@export var npc_role: String = "Guide"
@export var biome: int = BlockTypes.Biome.PLAINS
@export var quest_index: int = 0

var quest_data: Dictionary = {}
var visuals_node: Node3D = null
var head_node: Node3D = null
var overhead_label: Label3D = null
var player_ref: CharacterBody3D = null


func _ready() -> void:
	add_to_group("npcs")
	quest_data = QuestSystem.create_procedural_quest(biome, quest_index)
	_build_visuals()
	_build_overhead_label()


func _create_voxel_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	box.material = mat
	inst.mesh = box
	return inst


func _build_visuals() -> void:
	visuals_node = Node3D.new()
	visuals_node.name = "Visuals"
	add_child(visuals_node)

	# Robe / Tunique selon biome
	var robe_color: Color = Color(0.25, 0.45, 0.75)
	match biome:
		BlockTypes.Biome.DESERT:
			robe_color = Color(0.85, 0.75, 0.45)
		BlockTypes.Biome.SNOW:
			robe_color = Color(0.35, 0.50, 0.55)
		BlockTypes.Biome.MOUNTAIN:
			robe_color = Color(0.55, 0.35, 0.25)
		BlockTypes.Biome.FOREST:
			robe_color = Color(0.25, 0.55, 0.30)

	# 1. Torse & Robe
	var body := _create_voxel_cube(Vector3(0.55, 0.9, 0.35), robe_color)
	body.position = Vector3(0, 0.75, 0)
	visuals_node.add_child(body)

	# 2. Tête
	head_node = Node3D.new()
	head_node.position = Vector3(0, 1.45, 0)
	visuals_node.add_child(head_node)

	var head_cube := _create_voxel_cube(Vector3(0.42, 0.42, 0.42), Color(0.96, 0.78, 0.65))
	head_node.add_child(head_cube)

	# Yeux
	var left_eye := _create_voxel_cube(Vector3(0.06, 0.06, 0.04), Color(0.12, 0.12, 0.15))
	left_eye.position = Vector3(-0.1, 0.02, -0.22)
	head_node.add_child(left_eye)

	var right_eye := _create_voxel_cube(Vector3(0.06, 0.06, 0.04), Color(0.12, 0.12, 0.15))
	right_eye.position = Vector3(0.1, 0.02, -0.22)
	head_node.add_child(right_eye)

	# Barbe blanche ou chapeau
	if quest_index % 2 == 0:
		var beard := _create_voxel_cube(Vector3(0.35, 0.28, 0.15), Color(0.92, 0.92, 0.92))
		beard.position = Vector3(0, -0.18, -0.2)
		head_node.add_child(beard)
	else:
		var hat := _create_voxel_cube(Vector3(0.52, 0.15, 0.52), robe_color * 1.2)
		hat.position = Vector3(0, 0.25, 0)
		head_node.add_child(hat)

	# 3. Collision
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)


func _build_overhead_label() -> void:
	overhead_label = Label3D.new()
	overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_label.pixel_size = 0.007
	overhead_label.position = Vector3(0, 2.05, 0)
	overhead_label.text = "📜 %s (%s)\n[F: Parler]" % [npc_name, npc_role]
	overhead_label.modulate = Color(0.95, 0.85, 0.35)
	add_child(overhead_label)


func _process(delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		var p_list: Array[Node] = get_tree().get_nodes_in_group("player")
		if not p_list.is_empty():
			player_ref = p_list[0] as CharacterBody3D
		return

	# Tourner la tête ou le corps vers le joueur s'il est proche
	var dist: float = global_position.distance_to(player_ref.global_position)
	if dist < 8.0:
		var dir: Vector3 = (player_ref.global_position - global_position).normalized()
		dir.y = 0.0
		var look_t := global_position + dir
		visuals_node.look_at(Vector3(look_t.x, global_position.y, look_t.z), Vector3.UP)


## Interaction quand le joueur appuie sur F
func interact(player: CharacterBody3D) -> void:
	if player == null:
		return
	var msg: String = "Bienvenue dans notre humble village, noble aventurier ! Des périls rôdent aux alentours..."
	var q_sys: QuestSystem = player.quest_system if "quest_system" in player else null

	if "dialog_ui" in player and player.dialog_ui != null:
		player.dialog_ui.open_dialog(self, "%s - %s" % [npc_name, npc_role], msg, quest_data, q_sys)
