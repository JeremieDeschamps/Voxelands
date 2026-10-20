extends Label

## Affiche le nombre de trames par seconde (FPS) en temps réel.

func _ready() -> void:
	# Positionnement et style de base en haut à gauche
	offset_left = 10.0
	offset_top = 10.0
	offset_right = 150.0
	offset_bottom = 35.0


func _process(_delta: float) -> void:
	# Mise à jour du texte avec le compteur FPS du moteur
	var current_fps: int = Engine.get_frames_per_second()
	text = "FPS: %d" % current_fps
