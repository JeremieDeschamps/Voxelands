class_name QuestSystem
extends RefCounted

## Gestionnaire de quêtes simples pour le joueur (Chasse, Exploration, Butin, Boss) avec récompenses.

const ItemData = preload("res://scripts/items/item_data.gd")

signal quest_added(quest: Dictionary)
signal quest_updated(quest: Dictionary)
signal quest_completed(quest: Dictionary)
signal quest_claimed(quest: Dictionary)

var active_quests: Array[Dictionary] = []
var completed_quest_ids: Array[String] = []


func accept_quest(q: Dictionary) -> bool:
	for active in active_quests:
		if active["id"] == q["id"]:
			return false
	if completed_quest_ids.has(q["id"]):
		return false

	var new_q: Dictionary = q.duplicate(true)
	new_q["current_count"] = 0
	new_q["is_completed"] = false
	new_q["is_claimed"] = false
	active_quests.append(new_q)
	quest_added.emit(new_q)
	return true


func notify_kill(enemy_type: String) -> void:
	for q in active_quests:
		if q["is_completed"]:
			continue
		if q["type"] == "HUNT" and (q["target"] == enemy_type or q["target"] == "any"):
			q["current_count"] = mini(q["current_count"] + 1, q["required_count"])
			quest_updated.emit(q)
			if q["current_count"] >= q["required_count"]:
				q["is_completed"] = true
				quest_completed.emit(q)


func notify_boss_killed() -> void:
	for q in active_quests:
		if q["is_completed"]:
			continue
		if q["type"] == "BOSS":
			q["current_count"] = mini(q["current_count"] + 1, q["required_count"])
			quest_updated.emit(q)
			if q["current_count"] >= q["required_count"]:
				q["is_completed"] = true
				quest_completed.emit(q)


func notify_chest_opened() -> void:
	for q in active_quests:
		if q["is_completed"]:
			continue
		if q["type"] == "CHEST":
			q["current_count"] = mini(q["current_count"] + 1, q["required_count"])
			quest_updated.emit(q)
			if q["current_count"] >= q["required_count"]:
				q["is_completed"] = true
				quest_completed.emit(q)


func claim_reward(quest_id: String, player: CharacterBody3D) -> Dictionary:
	for i in range(active_quests.size()):
		var q: Dictionary = active_quests[i]
		if q["id"] == quest_id and q["is_completed"] and not q["is_claimed"]:
			q["is_claimed"] = true
			completed_quest_ids.append(quest_id)
			active_quests.remove_at(i)

			# Récompenses joueur
			if player != null:
				if "add_xp" in player and q.has("reward_xp"):
					player.add_xp(q["reward_xp"])
				if "inventory" in player and player.inventory != null and q.has("reward_item"):
					var item: RefCounted = ItemData.generate_random_item(player.level if "level" in player else 1)
					player.inventory.add_item(item)

			quest_claimed.emit(q)
			return q
	return {}


func serialize() -> Dictionary:
	return {
		"active_quests": active_quests,
		"completed_quest_ids": completed_quest_ids
	}


func deserialize(data: Dictionary) -> void:
	if data.has("active_quests"):
		active_quests.clear()
		for q in data["active_quests"]:
			active_quests.append(q)
	if data.has("completed_quest_ids"):
		completed_quest_ids.clear()
		for id in data["completed_quest_ids"]:
			completed_quest_ids.append(str(id))


## Génère une quête procédurale adaptée au biome
static func create_procedural_quest(biome: int, quest_index: int) -> Dictionary:
	var q_id: String = "quest_%d_%d" % [biome, quest_index]
	var title: String = ""
	var desc: String = ""
	var q_type: String = "HUNT"
	var target: String = "wolf"
	var count: int = 3
	var xp: int = 150

	match biome:
		1, 2: # Plage / Désert
			if quest_index % 2 == 0:
				title = "Fléau des Squelettes"
				desc = "Éliminez 3 Squelettes qui rôdent dans les dunes."
				target = "skeleton"
				count = 3
				xp = 180
			else:
				title = "Chasseur de Scorpions"
				desc = "Terrassez 2 monstres du désert."
				target = "any"
				count = 2
				xp = 160
		3: # Prairie
			title = "Menace des Loups"
			desc = "Chassez 3 Loups qui terrorisent les troupeaux du village."
			target = "wolf"
			count = 3
			xp = 150
		4: # Forêt
			title = "Gelée Envahissante"
			desc = "Détruisez 4 Slimes bondissants dans la forêt."
			target = "slime"
			count = 4
			xp = 175
		5: # Neige
			title = "Terres Glacées"
			desc = "Abattez 3 prédateurs du grand froid."
			target = "wolf"
			count = 3
			xp = 200
		6: # Montagne
			title = "Le Colosse de Pierre"
			desc = "Triomphez d'un Golem ancestral des sommets."
			target = "golem"
			count = 1
			xp = 260
		_:
			title = "Purification du Donjon"
			desc = "Pénétrez dans un donjon souterrain et terrassez le Gardien."
			q_type = "BOSS"
			target = "boss"
			count = 1
			xp = 400

	return {
		"id": q_id,
		"title": title,
		"desc": desc,
		"type": q_type,
		"target": target,
		"required_count": count,
		"current_count": 0,
		"reward_xp": xp,
		"reward_item": true,
		"is_completed": false,
		"is_claimed": false
	}
