class_name InventoryManager
extends Node

## Gestionnaire de l'inventaire en grille (20 emplacements) et de l'équipement (Arme, Armure, Anneau).

const ItemData = preload("res://scripts/items/item_data.gd")

signal inventory_changed
signal equipment_changed

const MAX_SLOTS: int = 20

var items: Array = []

var equipped_weapon: ItemData = null
var equipped_armor: ItemData = null
var equipped_ring: ItemData = null


func _ready() -> void:
	items.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		items[i] = null

	# Équipement initial de départ basique
	var starter_sword := ItemData.new()
	starter_sword.name = "Épée de Recrue"
	starter_sword.item_type = ItemData.ItemType.WEAPON
	starter_sword.rarity = ItemData.Rarity.COMMON
	starter_sword.attack_bonus = 6.0
	equipped_weapon = starter_sword

	var starter_tunic := ItemData.new()
	starter_tunic.name = "Tunique de Toile"
	starter_tunic.item_type = ItemData.ItemType.ARMOR
	starter_tunic.rarity = ItemData.Rarity.COMMON
	starter_tunic.defense_bonus = 4.0
	starter_tunic.health_bonus = 15.0
	equipped_armor = starter_tunic


func add_item(new_item: ItemData) -> bool:
	for i in range(MAX_SLOTS):
		if items[i] == null:
			items[i] = new_item
			inventory_changed.emit()
			return true
	return false # Inventaire plein


func remove_item(slot_idx: int) -> ItemData:
	if slot_idx >= 0 and slot_idx < MAX_SLOTS:
		var it: ItemData = items[slot_idx]
		items[slot_idx] = null
		inventory_changed.emit()
		return it
	return null


func equip_item(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS or items[slot_idx] == null:
		return

	var to_equip: ItemData = items[slot_idx]
	var current_equipped: ItemData = null

	match to_equip.item_type:
		ItemData.ItemType.WEAPON:
			current_equipped = equipped_weapon
			equipped_weapon = to_equip
		ItemData.ItemType.ARMOR:
			current_equipped = equipped_armor
			equipped_armor = to_equip
		ItemData.ItemType.RING:
			current_equipped = equipped_ring
			equipped_ring = to_equip

	items[slot_idx] = current_equipped
	inventory_changed.emit()
	equipment_changed.emit()


func unequip_item(item_type: int) -> bool:
	var first_free: int = -1
	for i in range(MAX_SLOTS):
		if items[i] == null:
			first_free = i
			break

	if first_free == -1:
		return false # Pas de place dans l'inventaire

	var unequipped: ItemData = null
	match item_type:
		ItemData.ItemType.WEAPON:
			unequipped = equipped_weapon
			equipped_weapon = null
		ItemData.ItemType.ARMOR:
			unequipped = equipped_armor
			equipped_armor = null
		ItemData.ItemType.RING:
			unequipped = equipped_ring
			equipped_ring = null

	if unequipped != null:
		items[first_free] = unequipped
		inventory_changed.emit()
		equipment_changed.emit()
		return true

	return false


func get_equipped_for_type(type: int) -> ItemData:
	match type:
		ItemData.ItemType.WEAPON:
			return equipped_weapon
		ItemData.ItemType.ARMOR:
			return equipped_armor
		ItemData.ItemType.RING:
			return equipped_ring
	return null


func get_total_attack_bonus() -> float:
	var bonus: float = 0.0
	if equipped_weapon != null:
		bonus += equipped_weapon.attack_bonus
	if equipped_armor != null:
		bonus += equipped_armor.attack_bonus
	if equipped_ring != null:
		bonus += equipped_ring.attack_bonus
	return bonus


func get_total_defense_bonus() -> float:
	var bonus: float = 0.0
	if equipped_weapon != null:
		bonus += equipped_weapon.defense_bonus
	if equipped_armor != null:
		bonus += equipped_armor.defense_bonus
	if equipped_ring != null:
		bonus += equipped_ring.defense_bonus
	return bonus


func get_total_health_bonus() -> float:
	var bonus: float = 0.0
	if equipped_weapon != null:
		bonus += equipped_weapon.health_bonus
	if equipped_armor != null:
		bonus += equipped_armor.health_bonus
	if equipped_ring != null:
		bonus += equipped_ring.health_bonus
	return bonus


func get_total_stamina_bonus() -> float:
	var bonus: float = 0.0
	if equipped_weapon != null:
		bonus += equipped_weapon.stamina_bonus
	if equipped_armor != null:
		bonus += equipped_armor.stamina_bonus
	if equipped_ring != null:
		bonus += equipped_ring.stamina_bonus
	return bonus


func to_dict() -> Dictionary:
	var items_arr := []
	for it in items:
		if it != null:
			items_arr.append(it.to_dict())
		else:
			items_arr.append(null)

	return {
		"items": items_arr,
		"weapon": equipped_weapon.to_dict() if equipped_weapon != null else null,
		"armor": equipped_armor.to_dict() if equipped_armor != null else null,
		"ring": equipped_ring.to_dict() if equipped_ring != null else null,
	}


func from_dict(data: Dictionary) -> void:
	var items_arr: Array = data.get("items", [])
	items.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		if i < items_arr.size() and items_arr[i] != null:
			items[i] = ItemData.from_dict(items_arr[i])
		else:
			items[i] = null

	var w = data.get("weapon", null)
	equipped_weapon = ItemData.from_dict(w) if w != null else null

	var a = data.get("armor", null)
	equipped_armor = ItemData.from_dict(a) if a != null else null

	var r = data.get("ring", null)
	equipped_ring = ItemData.from_dict(r) if r != null else null

	inventory_changed.emit()
	equipment_changed.emit()
