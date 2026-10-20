class_name TreasureChest
extends StaticBody3D

## Coffre au trésor voxel procédural avec ouverture articulée, butin brillant et XP.

const ItemData = preload("res://scripts/items/item_data.gd")
const LootDrop = preload("res://scripts/items/loot_drop.gd")
const DamageLabel3D = preload("res://scripts/ui/damage_label_3d.gd")

var is_opened: bool = false
var lid_node: Node3D = null
var overhead_label: Label3D = null
var open_angle: float = 0.0


func _ready() -> void:
	add_to_group("chests")
	_build_chest_mesh()
	_build_overhead_label()


func _create_voxel_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	box.material = mat
	inst.mesh = box
	return inst


func _build_chest_mesh() -> void:
	# 1. Base du coffre
	var base := _create_voxel_cube(Vector3(1.2, 0.6, 0.8), Color(0.42, 0.26, 0.14))
	base.position = Vector3(0, 0.3, 0)
	add_child(base)

	# Cerclages en métal doré
	var rim := _create_voxel_cube(Vector3(1.24, 0.62, 0.84), Color(0.85, 0.70, 0.22))
	rim.position = Vector3(0, 0.3, 0)
	add_child(rim)

	# 2. Couvercle articulé avec pivot à l'arrière
	lid_node = Node3D.new()
	lid_node.position = Vector3(0, 0.6, 0.4)
	add_child(lid_node)

	var lid_mesh := _create_voxel_cube(Vector3(1.22, 0.3, 0.82), Color(0.48, 0.30, 0.16))
	lid_mesh.position = Vector3(0, 0.15, -0.4)
	lid_node.add_child(lid_mesh)

	var lock := _create_voxel_cube(Vector3(0.2, 0.2, 0.08), Color(0.95, 0.82, 0.25))
	lock.position = Vector3(0, 0.08, -0.82)
	lid_node.add_child(lock)

	# 3. Collision physique
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.9, 0.9)
	col.shape = shape
	col.position = Vector3(0, 0.45, 0)
	add_child(col)


func _build_overhead_label() -> void:
	overhead_label = Label3D.new()
	overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_label.pixel_size = 0.007
	overhead_label.position = Vector3(0, 1.25, 0)
	overhead_label.text = "🪙 Coffre Antique [F: Ouvrir]"
	overhead_label.modulate = Color(0.95, 0.85, 0.25)
	add_child(overhead_label)


func _process(delta: float) -> void:
	if is_opened and open_angle < 1.3:
		open_angle = lerp(open_angle, 1.35, delta * 6.0)
		if lid_node != null:
			lid_node.rotation.x = -open_angle


## Interaction déclenchée par la touche F
func open_chest(player: CharacterBody3D) -> void:
	if is_opened:
		return
	is_opened = true

	if overhead_label != null:
		overhead_label.text = "✨ Ouvert"
		overhead_label.modulate = Color(0.6, 0.6, 0.65)

	# Progression des quêtes du joueur et son
	if player != null:
		if "sound_generator" in player and player.sound_generator != null:
			player.sound_generator.play_chest()
		if "quest_system" in player and player.quest_system != null:
			player.quest_system.notify_chest_opened()
		if "add_xp" in player:
			player.add_xp(120)

	# Génération de 2 à 3 pièces de butin de haute rareté (Épique ou Légendaire)
	var drops_count: int = randi_range(2, 3)
	for i in range(drops_count):
		var p_lvl: int = player.level if (player != null and "level" in player) else 1
		var item: RefCounted = ItemData.generate_random_item(p_lvl)
		# Assurer une rareté minimale Épique dans un coffre antique
		if item.rarity < ItemData.Rarity.EPIC:
			item.rarity = ItemData.Rarity.EPIC if randf() > 0.35 else ItemData.Rarity.LEGENDARY
			item.attack_bonus = int(round(item.attack_bonus * 1.5))
			item.defense_bonus = int(round(item.defense_bonus * 1.5))
			item.health_bonus = int(round(item.health_bonus * 1.5))

		var spawn_pos: Vector3 = global_position + Vector3(randf_range(-0.8, 0.8), 0.8, randf_range(-0.8, 0.8))
		LootDrop.spawn(get_parent(), spawn_pos, item)
