class_name LootDrop
extends Area3D

## Objet de butin 3D flottant et lumineux abandonné au sol par les ennemis.

const ItemData = preload("res://scripts/items/item_data.gd")
const DamageLabel3D = preload("res://scripts/ui/damage_label_3d.gd")

var item_data: ItemData = null
var mesh_inst: MeshInstance3D = null
var omni_light: OmniLight3D = null
var base_y: float = 0.0
var time_elapsed: float = 0.0


func _ready() -> void:
	base_y = position.y
	_build_visuals()

	# Détection de contact avec le joueur
	body_entered.connect(_on_body_entered)


static func spawn(parent: Node, spawn_pos: Vector3, item: ItemData) -> Area3D:
	var script: GDScript = load("res://scripts/items/loot_drop.gd")
	var loot: Area3D = script.new()
	loot.item_data = item
	loot.position = spawn_pos
	parent.add_child(loot)
	return loot


func _build_visuals() -> void:
	# Collision sphérique
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	add_child(col)

	var color: Color = Color.WHITE
	if item_data != null:
		color = ItemData.get_rarity_color(item_data.rarity)

	# Cristal / Cube voxel flottant lumineux
	mesh_inst = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.roughness = 0.2
	box.material = mat

	mesh_inst.mesh = box
	mesh_inst.rotation = Vector3(deg_to_rad(45.0), 0.0, deg_to_rad(45.0))
	add_child(mesh_inst)

	# Halo lumineux
	omni_light = OmniLight3D.new()
	omni_light.light_color = color
	omni_light.light_energy = 1.8
	omni_light.omni_range = 3.5
	add_child(omni_light)


func _process(delta: float) -> void:
	time_elapsed += delta

	# Rotation continue
	rotate_y(delta * 2.5)

	# Flottement vertical sinusoïdal
	position.y = base_y + (sin(time_elapsed * 3.0) * 0.15)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_node("InventoryManager"):
		var inv = body.get_node("InventoryManager")
		if inv.add_item(item_data):
			# Notification textuelle flottante au ramassage
			var label: Label3D = DamageLabel3D.spawn(get_parent(), global_position, 0)
			if item_data != null:
				label.text = "+ " + item_data.name
				label.modulate = ItemData.get_rarity_color(item_data.rarity)
			queue_free()
