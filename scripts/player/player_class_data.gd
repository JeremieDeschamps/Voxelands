class_name PlayerClassData
extends RefCounted

## Définition des 4 classes jouables (Guerrier, Mage, Rôdeur, Voleur) et de leurs compétences.

enum ClassType {
	WARRIOR = 0,
	MAGE = 1,
	RANGER = 2,
	ROGUE = 3,
}

const CLASS_NAMES: Array[String] = [
	"Guerrier",
	"Mage",
	"Rôdeur",
	"Voleur",
]

const CLASS_DESCRIPTIONS: Array[String] = [
	"Maître du corps-à-corps et des armes lourdes. Robuste avec une armure et une santé élevées.",
	"Lanceur de sorts élémentaires. Déclenche des explosions arcaniques et de glace dévastatrices à distance.",
	"Tireur d'élite agile. Décoche des volées de flèches précises et traverse le champ de bataille avec rapidité.",
	"Assassin furtif et véloce. Spécialiste des attaques critiques fulgurantes et des ruées dans l'ombre.",
]

const CLASS_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.20), # Guerrier (Rouge acier)
	Color(0.25, 0.55, 0.95), # Mage (Bleu arcanique)
	Color(0.22, 0.75, 0.32), # Rôdeur (Vert émeraude)
	Color(0.65, 0.22, 0.85), # Voleur (Pourpre d'ombre)
]

const CLASS_TUNIC_COLORS: Array[Color] = [
	Color(0.75, 0.22, 0.18), # Tunique rouge
	Color(0.20, 0.35, 0.85), # Tunique bleue
	Color(0.22, 0.58, 0.24), # Tunique verte
	Color(0.25, 0.20, 0.32), # Tunique pourpre sombre
]


## Informations sur les compétences par classe
static func get_skills_for_class(c_type: int) -> Array[Dictionary]:
	match c_type:
		ClassType.WARRIOR:
			return [
				{
					"name": "Coup d'Épée",
					"key": "L-Clic",
					"cooldown": 0.35,
					"stamina": 0.0,
					"damage": 24.0,
					"range": 2.7,
					"desc": "Attaque tranchante de base en arc de cercle."
				},
				{
					"name": "Tourbillon",
					"key": "R-Clic",
					"cooldown": 3.0,
					"stamina": 25.0,
					"damage": 50.0,
					"range": 4.5,
					"desc": "Frappe circulaire à 360° repoussant tous les ennemis proches."
				},
				{
					"name": "Charge Fracassante",
					"key": "E",
					"cooldown": 5.0,
					"stamina": 30.0,
					"damage": 40.0,
					"range": 6.0,
					"desc": "Propulsion avant fulgurante qui percute et repousse la cible."
				},
				{
					"name": "Cri de Guerre",
					"key": "R",
					"cooldown": 10.0,
					"stamina": 35.0,
					"damage": 30.0,
					"range": 7.0,
					"desc": "Onde de choc sonore étourdissante qui régénère 25 PV."
				}
			]

		ClassType.MAGE:
			return [
				{
					"name": "Éclair Arcanique",
					"key": "L-Clic",
					"cooldown": 0.45,
					"stamina": 0.0,
					"damage": 22.0,
					"range": 16.0,
					"desc": "Projectile magique perforant lancé vers le réticule."
				},
				{
					"name": "Boule de Feu",
					"key": "R-Clic",
					"cooldown": 2.5,
					"stamina": 25.0,
					"damage": 55.0,
					"range": 18.0,
					"desc": "Orbe incandescent explosif qui inflige de lourds dégâts de zone."
				},
				{
					"name": "Nova de Givre",
					"key": "E",
					"cooldown": 4.5,
					"stamina": 25.0,
					"damage": 38.0,
					"range": 5.5,
					"desc": "Vague de glace radiale qui congèle et repousse les assaillants."
				},
				{
					"name": "Tempête d'Étoiles",
					"key": "R",
					"cooldown": 8.0,
					"stamina": 40.0,
					"damage": 75.0,
					"range": 10.0,
					"desc": "Déluge arcanique foudroyant de 6 météores d'énergie."
				}
			]

		ClassType.RANGER:
			return [
				{
					"name": "Tir Rapide",
					"key": "L-Clic",
					"cooldown": 0.38,
					"stamina": 0.0,
					"damage": 20.0,
					"range": 22.0,
					"desc": "Flèche rapide décochée en cloche vers la cible."
				},
				{
					"name": "Flèche Perforante",
					"key": "R-Clic",
					"cooldown": 2.2,
					"stamina": 20.0,
					"damage": 48.0,
					"range": 25.0,
					"desc": "Tir puissant supersonique transperçant les lignes ennemies."
				},
				{
					"name": "Pluie de Flèches",
					"key": "E",
					"cooldown": 5.0,
					"stamina": 30.0,
					"damage": 42.0,
					"range": 8.0,
					"desc": "Salve aérienne couvrant une large zone devant le tireur."
				},
				{
					"name": "Bond Évasif",
					"key": "R",
					"cooldown": 6.0,
					"stamina": 15.0,
					"damage": 25.0,
					"range": 5.0,
					"desc": "Saut acrobatique arrière projetant des pièges épineux."
				}
			]

		_: # ROGUE
			return [
				{
					"name": "Coup de Dague",
					"key": "L-Clic",
					"cooldown": 0.22,
					"stamina": 0.0,
					"damage": 18.0,
					"range": 2.2,
					"desc": "Estocade ultra-rapide à double tranchant."
				},
				{
					"name": "Frappe dans l'Ombre",
					"key": "R-Clic",
					"cooldown": 2.0,
					"stamina": 20.0,
					"damage": 52.0,
					"range": 5.0,
					"desc": "Téléportation instantanée dans le dos de l'ennemi le plus proche."
				},
				{
					"name": "Lames Empoisonnées",
					"key": "E",
					"cooldown": 4.0,
					"stamina": 25.0,
					"damage": 36.0,
					"range": 3.8,
					"desc": "Tourbillon de lames imprégnées de venin affaiblissant les cibles."
				},
				{
					"name": "Exécution Mortelle",
					"key": "R",
					"cooldown": 7.0,
					"stamina": 35.0,
					"damage": 85.0,
					"range": 2.8,
					"desc": "Coup fatal infligeant d'immenses dégâts critiques en cas de santé faible."
				}
			]
