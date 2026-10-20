class_name CompanionData
extends RefCounted

## Définitions et statistiques des 24 espèces d'animaux apprivoisables réparties par biome.

const BlockTypes = preload("res://scripts/world/block_types.gd")

enum Species {
	# Prairie
	SHEPHERD_DOG,
	GIANT_RABBIT,
	MEADOW_FAWN,
	GOLDEN_ROOSTER,
	# Forêt
	BROWN_BEAR,
	WILD_BOAR,
	RED_FOX,
	SPIRIT_OWL,
	# Désert
	GOLDEN_SCARAB,
	SAND_FENNEC,
	DUNE_SCORPION,
	DESERT_BASILISK,
	# Neige
	ARCTIC_WOLF,
	POLAR_REINDEER,
	EMPEROR_PENGUIN,
	SNOW_LEOPARD,
	# Montagne
	STONE_FALCON,
	PEAK_RAM,
	MOUNTAIN_GOAT,
	PYGMY_GRYPHON,
	# Océan / Plage
	SEA_TURTLE,
	GIANT_KING_CRAB,
	AZURE_SALAMANDER,
	STORM_SEAGULL
}

const SPECIES_CONFIG: Dictionary = {
	Species.SHEPHERD_DOG: {
		"name": "Chien de Berger",
		"biome": BlockTypes.Biome.PLAINS,
		"hp": 90.0, "dmg": 18.0, "speed": 6.8, "range": 2.2, "cd": 1.1,
		"body_color": Color(0.72, 0.52, 0.32), "secondary_color": Color(0.95, 0.90, 0.82),
		"size": Vector3(0.5, 0.45, 0.8), "legs": 4, "flyer": false
	},
	Species.GIANT_RABBIT: {
		"name": "Lapin Géant",
		"biome": BlockTypes.Biome.PLAINS,
		"hp": 75.0, "dmg": 14.0, "speed": 7.5, "range": 1.8, "cd": 0.8,
		"body_color": Color(0.85, 0.82, 0.78), "secondary_color": Color(0.95, 0.70, 0.75),
		"size": Vector3(0.45, 0.5, 0.6), "legs": 4, "flyer": false
	},
	Species.MEADOW_FAWN: {
		"name": "Faon Sylvestre",
		"biome": BlockTypes.Biome.PLAINS,
		"hp": 85.0, "dmg": 16.0, "speed": 7.0, "range": 2.0, "cd": 1.0,
		"body_color": Color(0.68, 0.45, 0.25), "secondary_color": Color(0.92, 0.88, 0.80),
		"size": Vector3(0.48, 0.6, 0.75), "legs": 4, "flyer": false
	},
	Species.GOLDEN_ROOSTER: {
		"name": "Coq Hardi",
		"biome": BlockTypes.Biome.PLAINS,
		"hp": 65.0, "dmg": 15.0, "speed": 6.2, "range": 1.6, "cd": 0.75,
		"body_color": Color(0.88, 0.35, 0.15), "secondary_color": Color(0.95, 0.82, 0.18),
		"size": Vector3(0.35, 0.45, 0.4), "legs": 2, "flyer": false
	},
	Species.BROWN_BEAR: {
		"name": "Ours Brun",
		"biome": BlockTypes.Biome.FOREST,
		"hp": 160.0, "dmg": 28.0, "speed": 5.4, "range": 2.5, "cd": 1.6,
		"body_color": Color(0.38, 0.24, 0.14), "secondary_color": Color(0.28, 0.18, 0.10),
		"size": Vector3(0.85, 0.75, 1.2), "legs": 4, "flyer": false
	},
	Species.WILD_BOAR: {
		"name": "Sanglier Robuste",
		"biome": BlockTypes.Biome.FOREST,
		"hp": 130.0, "dmg": 24.0, "speed": 6.0, "range": 2.2, "cd": 1.3,
		"body_color": Color(0.42, 0.32, 0.26), "secondary_color": Color(0.88, 0.85, 0.80),
		"size": Vector3(0.6, 0.55, 0.95), "legs": 4, "flyer": false
	},
	Species.RED_FOX: {
		"name": "Renard Roux",
		"biome": BlockTypes.Biome.FOREST,
		"hp": 75.0, "dmg": 17.0, "speed": 7.4, "range": 1.9, "cd": 0.95,
		"body_color": Color(0.86, 0.40, 0.16), "secondary_color": Color(0.95, 0.95, 0.95),
		"size": Vector3(0.42, 0.4, 0.7), "legs": 4, "flyer": false
	},
	Species.SPIRIT_OWL: {
		"name": "Chouette Lunaire",
		"biome": BlockTypes.Biome.FOREST,
		"hp": 70.0, "dmg": 22.0, "speed": 6.5, "range": 3.8, "cd": 1.2,
		"body_color": Color(0.35, 0.32, 0.45), "secondary_color": Color(0.65, 0.80, 0.95),
		"size": Vector3(0.4, 0.45, 0.45), "legs": 2, "flyer": true
	},
	Species.GOLDEN_SCARAB: {
		"name": "Scarabée Doré",
		"biome": BlockTypes.Biome.DESERT,
		"hp": 140.0, "dmg": 20.0, "speed": 5.2, "range": 2.0, "cd": 1.4,
		"body_color": Color(0.88, 0.75, 0.22), "secondary_color": Color(0.35, 0.75, 0.65),
		"size": Vector3(0.65, 0.4, 0.75), "legs": 4, "flyer": false
	},
	Species.SAND_FENNEC: {
		"name": "Fennec des Sables",
		"biome": BlockTypes.Biome.DESERT,
		"hp": 70.0, "dmg": 18.0, "speed": 7.6, "range": 1.8, "cd": 0.9,
		"body_color": Color(0.92, 0.78, 0.52), "secondary_color": Color(0.96, 0.94, 0.88),
		"size": Vector3(0.38, 0.38, 0.65), "legs": 4, "flyer": false
	},
	Species.DUNE_SCORPION: {
		"name": "Scorpion des Dunes",
		"biome": BlockTypes.Biome.DESERT,
		"hp": 95.0, "dmg": 25.0, "speed": 6.2, "range": 2.4, "cd": 1.2,
		"body_color": Color(0.74, 0.55, 0.30), "secondary_color": Color(0.25, 0.65, 0.35),
		"size": Vector3(0.55, 0.35, 0.85), "legs": 4, "flyer": false
	},
	Species.DESERT_BASILISK: {
		"name": "Basilic du Désert",
		"biome": BlockTypes.Biome.DESERT,
		"hp": 120.0, "dmg": 26.0, "speed": 6.5, "range": 2.3, "cd": 1.3,
		"body_color": Color(0.60, 0.65, 0.32), "secondary_color": Color(0.85, 0.55, 0.18),
		"size": Vector3(0.5, 0.4, 1.1), "legs": 4, "flyer": false
	},
	Species.ARCTIC_WOLF: {
		"name": "Loup Arctique",
		"biome": BlockTypes.Biome.SNOW,
		"hp": 110.0, "dmg": 23.0, "speed": 7.0, "range": 2.3, "cd": 1.1,
		"body_color": Color(0.92, 0.94, 0.96), "secondary_color": Color(0.55, 0.72, 0.85),
		"size": Vector3(0.55, 0.5, 0.9), "legs": 4, "flyer": false
	},
	Species.POLAR_REINDEER: {
		"name": "Renne Polaire",
		"biome": BlockTypes.Biome.SNOW,
		"hp": 140.0, "dmg": 22.0, "speed": 6.4, "range": 2.6, "cd": 1.4,
		"body_color": Color(0.75, 0.72, 0.70), "secondary_color": Color(0.42, 0.34, 0.28),
		"size": Vector3(0.65, 0.8, 1.1), "legs": 4, "flyer": false
	},
	Species.EMPEROR_PENGUIN: {
		"name": "Manchot Empereur",
		"biome": BlockTypes.Biome.SNOW,
		"hp": 85.0, "dmg": 17.0, "speed": 5.8, "range": 1.8, "cd": 1.0,
		"body_color": Color(0.16, 0.18, 0.22), "secondary_color": Color(0.95, 0.80, 0.25),
		"size": Vector3(0.4, 0.6, 0.4), "legs": 2, "flyer": false
	},
	Species.SNOW_LEOPARD: {
		"name": "Léopard des Neiges",
		"biome": BlockTypes.Biome.SNOW,
		"hp": 105.0, "dmg": 27.0, "speed": 7.5, "range": 2.4, "cd": 1.0,
		"body_color": Color(0.85, 0.86, 0.88), "secondary_color": Color(0.45, 0.48, 0.52),
		"size": Vector3(0.55, 0.48, 1.0), "legs": 4, "flyer": false
	},
	Species.STONE_FALCON: {
		"name": "Faucon de Pierre",
		"biome": BlockTypes.Biome.MOUNTAIN,
		"hp": 75.0, "dmg": 24.0, "speed": 7.2, "range": 3.6, "cd": 1.1,
		"body_color": Color(0.48, 0.50, 0.54), "secondary_color": Color(0.88, 0.75, 0.30),
		"size": Vector3(0.42, 0.4, 0.45), "legs": 2, "flyer": true
	},
	Species.PEAK_RAM: {
		"name": "Bélier des Pics",
		"biome": BlockTypes.Biome.MOUNTAIN,
		"hp": 150.0, "dmg": 26.0, "speed": 6.2, "range": 2.4, "cd": 1.4,
		"body_color": Color(0.65, 0.62, 0.58), "secondary_color": Color(0.32, 0.28, 0.24),
		"size": Vector3(0.65, 0.65, 0.95), "legs": 4, "flyer": false
	},
	Species.MOUNTAIN_GOAT: {
		"name": "Chèvre des Cimes",
		"biome": BlockTypes.Biome.MOUNTAIN,
		"hp": 110.0, "dmg": 20.0, "speed": 6.8, "range": 2.1, "cd": 1.1,
		"body_color": Color(0.90, 0.92, 0.94), "secondary_color": Color(0.35, 0.32, 0.30),
		"size": Vector3(0.5, 0.58, 0.85), "legs": 4, "flyer": false
	},
	Species.PYGMY_GRYPHON: {
		"name": "Griffon Nain",
		"biome": BlockTypes.Biome.MOUNTAIN,
		"hp": 125.0, "dmg": 28.0, "speed": 7.0, "range": 2.8, "cd": 1.2,
		"body_color": Color(0.78, 0.62, 0.36), "secondary_color": Color(0.88, 0.32, 0.22),
		"size": Vector3(0.6, 0.6, 0.9), "legs": 4, "flyer": true
	},
	Species.SEA_TURTLE: {
		"name": "Tortue Cuirassée",
		"biome": BlockTypes.Biome.OCEAN,
		"hp": 180.0, "dmg": 18.0, "speed": 4.8, "range": 2.2, "cd": 1.6,
		"body_color": Color(0.28, 0.55, 0.38), "secondary_color": Color(0.78, 0.72, 0.45),
		"size": Vector3(0.85, 0.38, 1.05), "legs": 4, "flyer": false
	},
	Species.GIANT_KING_CRAB: {
		"name": "Crabe Royal Géant",
		"biome": BlockTypes.Biome.BEACH,
		"hp": 135.0, "dmg": 25.0, "speed": 5.5, "range": 2.2, "cd": 1.2,
		"body_color": Color(0.86, 0.28, 0.18), "secondary_color": Color(0.95, 0.85, 0.40),
		"size": Vector3(0.8, 0.4, 0.7), "legs": 4, "flyer": false
	},
	Species.AZURE_SALAMANDER: {
		"name": "Salamandre d'Azur",
		"biome": BlockTypes.Biome.OCEAN,
		"hp": 95.0, "dmg": 22.0, "speed": 6.8, "range": 2.4, "cd": 1.0,
		"body_color": Color(0.22, 0.62, 0.88), "secondary_color": Color(0.45, 0.92, 0.75),
		"size": Vector3(0.45, 0.35, 0.95), "legs": 4, "flyer": false
	},
	Species.STORM_SEAGULL: {
		"name": "Mouette des Tempêtes",
		"biome": BlockTypes.Biome.BEACH,
		"hp": 65.0, "dmg": 18.0, "speed": 7.4, "range": 3.2, "cd": 0.9,
		"body_color": Color(0.92, 0.94, 0.96), "secondary_color": Color(0.95, 0.75, 0.18),
		"size": Vector3(0.38, 0.35, 0.42), "legs": 2, "flyer": true
	}
}

static func get_species_for_biome(biome: int) -> Array[int]:
	var result: Array[int] = []
	for s_key in SPECIES_CONFIG.keys():
		var cfg: Dictionary = SPECIES_CONFIG[s_key]
		if cfg["biome"] == biome or (biome == BlockTypes.Biome.OCEAN and cfg["biome"] == BlockTypes.Biome.BEACH):
			result.append(int(s_key))
	if result.is_empty():
		result.append(int(Species.SHEPHERD_DOG))
	return result

static func get_config(s_type: int) -> Dictionary:
	if SPECIES_CONFIG.has(s_type):
		return SPECIES_CONFIG[s_type]
	return SPECIES_CONFIG[Species.SHEPHERD_DOG]
