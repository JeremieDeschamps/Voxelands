class_name DamageLabel3D
extends Label3D

## Texte 3D flottant affichant les dégâts infligés avec fondu et ascension.

var lifetime: float = 0.8
var age: float = 0.0
var velocity: Vector3 = Vector3(0.0, 2.2, 0.0)


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 32
	outline_size = 8
	outline_modulate = Color.BLACK
	modulate = Color(1.0, 0.25, 0.25, 1.0)


static func spawn(parent: Node, pos: Vector3, damage_amount: int, is_crit: bool = false) -> Label3D:
	var script: GDScript = load("res://scripts/ui/damage_label_3d.gd")
	var label: Label3D = script.new()
	label.text = str(damage_amount)
	label.position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3))

	if is_crit:
		label.modulate = Color(1.0, 0.85, 0.15, 1.0)
		label.font_size = 40
		label.text = str(damage_amount) + "!"

	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	velocity.y = maxf(velocity.y - (delta * 2.0), 0.5)

	# Fondu progressif vers la fin de vie
	var progress: float = age / lifetime
	if progress >= 0.5:
		var alpha: float = 1.0 - ((progress - 0.5) * 2.0)
		modulate.a = clampf(alpha, 0.0, 1.0)
		outline_modulate.a = clampf(alpha, 0.0, 1.0)

	if age >= lifetime:
		queue_free()
