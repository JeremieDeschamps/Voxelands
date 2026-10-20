class_name SaveSystem
extends RefCounted

## Système de sauvegarde et de chargement dans le fichier user://save.json.

const SAVE_PATH: String = "user://save.json"


## Sauvegarde l'état du joueur, son niveau, son inventaire et sa position
static func save_game(player: CharacterBody3D, world_seed: int) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var inv = player.get_node_or_null("InventoryManager")
	var inv_data: Dictionary = inv.to_dict() if inv != null else {}

	var save_data := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"world_seed": world_seed,
		"player": {
			"level": player.level,
			"current_xp": player.current_xp,
			"xp_to_next": player.xp_to_next_level,
			"current_health": player.current_health,
			"current_stamina": player.current_stamina,
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		},
		"inventory": inv_data
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
		player.level = int(p_data.get("level", 1))
		player.current_xp = int(p_data.get("current_xp", 0))
		player.xp_to_next_level = int(p_data.get("xp_to_next", 100))
		player.current_health = float(p_data.get("current_health", player.max_health))
		player.current_stamina = float(p_data.get("current_stamina", player.max_stamina))

		var pos_arr: Array = p_data.get("position", [])
		if pos_arr.size() >= 3:
			player.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))

		var inv = player.get_node_or_null("InventoryManager")
		if inv != null:
			inv.from_dict(data.get("inventory", {}))

	print("Sauvegarde chargée avec succès depuis : ", SAVE_PATH)
	return data
