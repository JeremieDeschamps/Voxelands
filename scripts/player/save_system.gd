class_name SaveSystem
extends RefCounted

## Système de sauvegarde et de chargement dans le fichier user://save.json.

const SAVE_PATH: String = "user://save.json"


## Sauvegarde l'état du joueur, son niveau, sa classe, son arbre de talents et son inventaire
static func save_game(player: CharacterBody3D, world_seed: int) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var inv = player.get_node_or_null("InventoryManager")
	var inv_data: Dictionary = inv.to_dict() if inv != null else {}

	var talents_data: Dictionary = {}
	if ("talent_tree" in player) and player.talent_tree != null:
		talents_data = player.talent_tree.to_dict()

	var p_class: int = 0
	if "player_class" in player:
		p_class = player.player_class

	var quests_data: Dictionary = {}
	if ("quest_system" in player) and player.quest_system != null:
		quests_data = player.quest_system.serialize()

	var pet_data: Dictionary = {}
	if ("active_companion" in player) and player.active_companion != null and is_instance_valid(player.active_companion):
		pet_data = {
			"species": player.active_companion.species_type,
			"level": player.active_companion.pet_level,
			"health": player.active_companion.current_health
		}

	var save_data := {
		"version": 3,
		"timestamp": Time.get_datetime_string_from_system(),
		"world_seed": world_seed,
		"player": {
			"class": p_class,
			"level": player.level,
			"current_xp": player.current_xp,
			"xp_to_next": player.xp_to_next_level,
			"current_health": player.current_health,
			"current_stamina": player.current_stamina,
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		},
		"talents": talents_data,
		"inventory": inv_data,
		"quests": quests_data,
		"companion": pet_data
	}

	var json_str: String = JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Impossible d'ouvrir le fichier de sauvegarde en écriture : ", SAVE_PATH)
		return false

	file.store_string(json_str)
	file.close()
	print("Partie sauvegardée avec succès dans : ", SAVE_PATH)
	return true


## Charge la sauvegarde existante et restaure les données du joueur
static func load_game(player: CharacterBody3D) -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var content: String = file.get_as_text()
	file.close()

	var test_json := JSON.new()
	var error: Error = test_json.parse(content)
	if error != OK:
		printerr("Erreur lors de la lecture du fichier JSON : ", error)
		return {}

	var data: Dictionary = test_json.data
	if player != null and is_instance_valid(player):
		var p_data: Dictionary = data.get("player", {})
		if "class" in p_data and player.has_method("set_player_class"):
			player.set_player_class(int(p_data["class"]), false)

		player.level = int(p_data.get("level", 1))
		player.current_xp = int(p_data.get("current_xp", 0))
		player.xp_to_next_level = int(p_data.get("xp_to_next", 100))
		player.current_health = float(p_data.get("current_health", player.max_health))
		player.current_stamina = float(p_data.get("current_stamina", player.max_stamina))

		var pos_arr: Array = p_data.get("position", [])
		if pos_arr.size() >= 3:
			player.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))

		if ("talent_tree" in player) and player.talent_tree != null and "talents" in data:
			player.talent_tree.from_dict(data["talents"])

		var inv = player.get_node_or_null("InventoryManager")
		if inv != null and "inventory" in data:
			inv.from_dict(data["inventory"])

		if ("quest_system" in player) and player.quest_system != null and "quests" in data:
			player.quest_system.deserialize(data["quests"])

		if "companion" in data and not data["companion"].is_empty() and player.has_method("spawn_saved_companion"):
			player.spawn_saved_companion(data["companion"])

	print("Sauvegarde chargée avec succès depuis : ", SAVE_PATH)
	return data
