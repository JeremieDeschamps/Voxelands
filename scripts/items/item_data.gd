class_name ItemData
extends RefCounted

## Données d'un objet (Arme, Armure, Anneau) avec rareté et statistiques procédurales.

enum ItemType {
	WEAPON = 0,
	ARMOR = 1,
	RING = 2,
}

enum Rarity {
	COMMON = 0,
	RARE = 1,
	EPIC = 2,
	LEGENDARY = 3,
}

const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.88),       # Commun (Gris clair)
	Color(0.25, 0.65, 0.98),       # Rare (Bleu azur)
	Color(0.72, 0.28, 0.96),       # Épique (Violet mystique)
	Color(1.0, 0.62, 0.12),        # Légendaire (Doré / Orange éclatant)
]

const RARITY_NAMES: Array[String] = [
	"Commun",
	"Rare",
	"Épique",
	"Légendaire",
]

var id: String = ""
var name: String = "Objet Inconnu"
var item_type: int = ItemType.WEAPON
var rarity: int = Rarity.COMMON
var level_req: int = 1

# Statistiques de combat
var attack_bonus: float = 0.0
var defense_bonus: float = 0.0
var health_bonus: float = 0.0
var stamina_bonus: float = 0.0


static func get_rarity_color(r: int) -> Color:
	if r >= 0 and r < RARITY_COLORS.size():
		return RARITY_COLORS[r]
	return Color.WHITE


static func get_rarity_name(r: int) -> String:
	if r >= 0 and r < RARITY_NAMES.size():
		return RARITY_NAMES[r]
	return "Commun"


## Génération procédurale d'un objet selon le niveau et l'éloignement
static func generate_random_item(target_level: int, distance: float) -> RefCounted:
	var script: GDScript = load("res://scripts/items/item_data.gd")
	var item: RefCounted = script.new()
	item.level_req = maxi(target_level, 1)

	# Type aléatoire : 40% Arme, 40% Armure, 20% Anneau
	var type_roll: float = randf()
	if type_roll < 0.4:
		item.item_type = ItemType.WEAPON
	elif type_roll < 0.8:
		item.item_type = ItemType.ARMOR
	else:
		item.item_type = ItemType.RING

	# Rareté influencée par la distance
	var rarity_roll: float = randf() + (minf(distance / 200.0, 0.35))
	if rarity_roll > 0.92:
		item.rarity = Rarity.LEGENDARY
	elif rarity_roll > 0.70:
		item.rarity = Rarity.EPIC
	elif rarity_roll > 0.38:
		item.rarity = Rarity.RARE
	else:
		item.rarity = Rarity.COMMON

	var mult: float = 1.0 + (float(item.rarity) * 0.6) + (float(item.level_req - 1) * 0.25)

	match item.item_type:
		ItemType.WEAPON:
			item.attack_bonus = roundf(randf_range(8.0, 14.0) * mult)
			if item.rarity >= Rarity.EPIC:
				item.stamina_bonus = roundf(randf_range(5.0, 15.0) * mult)
			item.name = _generate_weapon_name(item.rarity)

		ItemType.ARMOR:
			item.defense_bonus = roundf(randf_range(6.0, 12.0) * mult)
			item.health_bonus = roundf(randf_range(12.0, 25.0) * mult)
			item.name = _generate_armor_name(item.rarity)

		ItemType.RING:
			item.health_bonus = roundf(randf_range(10.0, 20.0) * mult)
			item.stamina_bonus = roundf(randf_range(10.0, 20.0) * mult)
			if item.rarity >= Rarity.RARE:
				item.attack_bonus = roundf(randf_range(4.0, 8.0) * mult)
				item.defense_bonus = roundf(randf_range(3.0, 7.0) * mult)
			item.name = _generate_ring_name(item.rarity)

	item.id = str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)
	return item


static func _generate_weapon_name(r: int) -> String:
	var prefixes: Array[String] = ["Lame", "Épée", "Hache", "Masse", "Tranchant"]
	var suffixes_common: Array[String] = ["de Fer", "de Bois", "Ébréchée", "de Pierre"]
	var suffixes_rare: Array[String] = ["d'Acier Renforcé", "des Bois", "du Blizzard", "des Marais"]
	var suffixes_epic: Array[String] = ["de Cristal Voxel", "des Abîmes", "du Titan", "d'Ombre"]
	var suffixes_leg: Array[String] = ["d'Aurore Boréale", "du Roi Voxel", "de l'Infini", "Draconique"]

	var prefix: String = prefixes[randi() % prefixes.size()]
	var suffix: String = ""
	match r:
		Rarity.LEGENDARY:
			suffix = suffixes_leg[randi() % suffixes_leg.size()]
		Rarity.EPIC:
			suffix = suffixes_epic[randi() % suffixes_epic.size()]
		Rarity.RARE:
			suffix = suffixes_rare[randi() % suffixes_rare.size()]
		_:
			suffix = suffixes_common[randi() % suffixes_common.size()]

	return prefix + " " + suffix


static func _generate_armor_name(r: int) -> String:
	var prefixes: Array[String] = ["Plastron", "Cuirasse", "Cotte", "Armure"]
	var suffixes_common: Array[String] = ["de Cuir", "de Maille", "de Soldat"]
	var suffixes_rare: Array[String] = ["des Gardiens", "de Granit", "du Ranger"]
	var suffixes_epic: Array[String] = ["de Mithril", "des Géants", "Enchantée"]
	var suffixes_leg: Array[String] = ["du Phénix", "des Dieux Voxels", "de l'Astre"]

	var prefix: String = prefixes[randi() % prefixes.size()]
	var suffix: String = ""
	match r:
		Rarity.LEGENDARY:
			suffix = suffixes_leg[randi() % suffixes_leg.size()]
		Rarity.EPIC:
			suffix = suffixes_epic[randi() % suffixes_epic.size()]
		Rarity.RARE:
			suffix = suffixes_rare[randi() % suffixes_rare.size()]
		_:
			suffix = suffixes_common[randi() % suffixes_common.size()]

	return prefix + " " + suffix


static func _generate_ring_name(r: int) -> String:
	var prefixes: Array[String] = ["Anneau", "Sceau", "Bague", "Chevalière"]
	var suffixes_common: Array[String] = ["de Bronze", "d'Argent", "de Cuivre"]
	var suffixes_rare: Array[String] = ["de Jade", "de Saphir", "du Vagabond"]
	var suffixes_epic: Array[String] = ["d'Améthyste", "du Dragon", "des Rois"]
	var suffixes_leg: Array[String] = ["du Soleil Éternel", "du Destin", "Cosmique"]

	var prefix: String = prefixes[randi() % prefixes.size()]
	var suffix: String = ""
	match r:
		Rarity.LEGENDARY:
			suffix = suffixes_leg[randi() % suffixes_leg.size()]
		Rarity.EPIC:
			suffix = suffixes_epic[randi() % suffixes_epic.size()]
		Rarity.RARE:
			suffix = suffixes_rare[randi() % suffixes_rare.size()]
		_:
			suffix = suffixes_common[randi() % suffixes_common.size()]

	return prefix + " " + suffix


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"item_type": item_type,
		"rarity": rarity,
		"level_req": level_req,
		"attack_bonus": attack_bonus,
		"defense_bonus": defense_bonus,
		"health_bonus": health_bonus,
		"stamina_bonus": stamina_bonus,
	}


static func from_dict(dict: Dictionary) -> RefCounted:
	var script: GDScript = load("res://scripts/items/item_data.gd")
	var item: RefCounted = script.new()
	item.id = dict.get("id", "")
	item.name = dict.get("name", "Objet Inconnu")
	item.item_type = int(dict.get("item_type", 0))
	item.rarity = int(dict.get("rarity", 0))
	item.level_req = int(dict.get("level_req", 1))
	item.attack_bonus = float(dict.get("attack_bonus", 0.0))
	item.defense_bonus = float(dict.get("defense_bonus", 0.0))
	item.health_bonus = float(dict.get("health_bonus", 0.0))
	item.stamina_bonus = float(dict.get("stamina_bonus", 0.0))
	return item
