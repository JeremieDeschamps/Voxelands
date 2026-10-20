class_name TalentTree
extends RefCounted

## Arbre de talents simple avec points allouables par niveau et bonus passifs.

signal talents_updated

var available_points: int = 0
var total_points_earned: int = 0

# Rangs des 5 talents (max 5 chacun)
var ranks: Array[int] = [0, 0, 0, 0, 0]

const MAX_RANK: int = 5

const TALENT_NAMES: Array[String] = [
	"Puissance Martiale / Arcanique",
	"Vitalité Renforcée",
	"Vigueur & Récupération",
	"Frappe Critique",
	"Hâte & Maîtrise des Sorts",
]

const TALENT_DESCRIPTIONS: Array[String] = [
	"+8% de dégâts sur toutes les attaques par rang.",
	"+15 points de vie max par rang.",
	"+10 endurance max et +12% de régénération par rang.",
	"+6% de chance de coup critique (x1.8 dégâts) par rang.",
	"+7% de réduction du temps de recharge des sorts par rang.",
]


func on_level_up(new_level: int) -> void:
	# 1 point gagné par niveau au-delà du niveau 1
	var expected_total: int = new_level - 1
	var points_to_add: int = expected_total - total_points_earned
	if points_to_add > 0:
		available_points += points_to_add
		total_points_earned = expected_total
		talents_updated.emit()


func can_upgrade(index: int) -> bool:
	if index < 0 or index >= ranks.size():
		return false
	return available_points > 0 and ranks[index] < MAX_RANK


func upgrade_talent(index: int) -> bool:
	if can_upgrade(index):
		ranks[index] += 1
		available_points -= 1
		talents_updated.emit()
		return true
	return false


func reset_talents() -> void:
	for i in range(ranks.size()):
		ranks[i] = 0
	available_points = total_points_earned
	talents_updated.emit()


func get_damage_multiplier() -> float:
	return 1.0 + (float(ranks[0]) * 0.08)


func get_bonus_health() -> float:
	return float(ranks[1]) * 15.0


func get_bonus_stamina() -> float:
	return float(ranks[2]) * 10.0


func get_stamina_regen_multiplier() -> float:
	return 1.0 + (float(ranks[2]) * 0.12)


func get_crit_chance() -> float:
	return float(ranks[3]) * 0.06


func get_cooldown_multiplier() -> float:
	return 1.0 - (float(ranks[4]) * 0.07)


func to_dict() -> Dictionary:
	return {
		"available_points": available_points,
		"total_points_earned": total_points_earned,
		"ranks": ranks.duplicate()
	}


func from_dict(data: Dictionary) -> void:
	available_points = int(data.get("available_points", 0))
	total_points_earned = int(data.get("total_points_earned", 0))
	var saved_ranks: Array = data.get("ranks", [0, 0, 0, 0, 0])
	for i in range(ranks.size()):
		if i < saved_ranks.size():
			ranks[i] = clampi(int(saved_ranks[i]), 0, MAX_RANK)
		else:
			ranks[i] = 0
	talents_updated.emit()
